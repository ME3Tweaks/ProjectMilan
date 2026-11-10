using System.ComponentModel;
using System.Diagnostics;
using System.Text.RegularExpressions;
using UDKInj;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using ProjectMilanCore;
using ProjectMilan.Utility;
using ProjectMilan.Pipelines.Levels;

namespace ProjectMilan.Pipelines.StaticLighting
{
    /// <summary>
    /// Lightmass build quality, matching UDK's own Lighting Build Quality dropdown. Each step up
    /// scales shadow ray counts, hemisphere samples, and photon counts (see the
    /// DevOptions.StaticLighting*Quality sections in UDKLightmass.ini) - Production is dramatically
    /// slower than Medium, so reserve it for final builds.
    /// </summary>
    public enum LightmassBuildQuality
    {
        Preview = 0,
        Medium = 1,
        High = 2,
        Production = 3,
    }

    /// <summary>
    /// Which Lightmass solves a lighting build. Either way UDK runs the build and imports the
    /// result exactly the same - the only difference is which UnrealLightmass.exe UDK's Swarm job
    /// launches from Binaries\Win64.
    /// </summary>
    public enum LightmassSolver
    {
        /// <summary>UDK's own UE3 Lightmass.</summary>
        UE3,

        /// <summary>
        /// UE4.27 Lightmass through the UdkInj Lightmass bridge (UdkInj docs/LIGHTMASS_BRIDGE.md). The
        /// bridge translates UDK's exported scene to UE4, solves it at the same quality level, and
        /// hands the lightmaps back to UDK. Volume samples, mesh area lights, precomputed visibility
        /// and dominant shadow maps are not produced yet, and BSP/terrain maps fail the build.
        /// </summary>
        UE4,
    }

    /// <summary>
    /// Builds static lighting in UDK in an automated fashion. This process is VERY slow, should only really ever be used on final builds.
    /// </summary>
    public static class StaticLightingCompute
    {
        private const string LOG_CATEGORY = @"MILAN-StaticLightingCompute";

        private static Injector injector;
        private static FileInfo module;

        /// <summary>The UDK this build started, so a failed status read can tell "UDK is gone" apart
        /// from a real memory-access failure.</summary>
        private static int udkPid;

        /// <summary>
        /// Longest a single lighting build may take before UDK is treated as hung and killed. Production
        /// bakes of the largest maps take about 30 minutes; a build has also been seen to finish solving
        /// and then never return to the editor tick, which used to wait out the old 12-hour limit.
        /// </summary>
        private static readonly TimeSpan LightingBuildTimeout = TimeSpan.FromHours(1);

        private static readonly TimeSpan PollInterval = TimeSpan.FromMilliseconds(500);

        /// <summary>
        /// Mirror of AgentDispatchStatus in UDKAgent/CommonHooks.hpp. Keep the two in sync.
        /// </summary>
        private readonly struct AgentStatus
        {
            public const int SizeBytes = 32;

            public bool IsIdle { get; init; }
            public int PendingActions { get; init; }
            public int CompletedActions { get; init; }
            public int SlowTaskDepth { get; init; }
            public bool IsDispatching { get; init; }
            public int TicksRemaining { get; init; }
            public int EngineTickCount { get; init; }
            public int LoadErrorEvents { get; init; }

            public override string ToString() =>
                $"idle={IsIdle} pending={PendingActions} completed={CompletedActions} " +
                $"slowTask={SlowTaskDepth} dispatching={IsDispatching} ticks={TicksRemaining} " +
                $"engineTicks={EngineTickCount}";
        }

        /// <summary>
        /// Mirror of LoadErrorEntryWire in UDKAgent/CommonHooks.hpp. Keep the two in sync.
        /// </summary>
        private readonly struct LoadErrorEntry
        {
            public const int SizeBytes = 4 + 4 + 256 * 2;

            public bool Found { get; init; }

            /// <summary>FEdLoadError::TYPE_FILE (0) - a totally missing file/package - or TYPE_RESOURCE (1).</summary>
            public int Type { get; init; }
            public string Desc { get; init; }
        }

        /// <summary>
        /// Mirror of LightmassProgressStatus in UDKAgent/CommonHooks.hpp. Keep the two in sync.
        /// </summary>
        private readonly struct LightmassProgressStatus
        {
            public const int SizeBytes = 256 * 2 + 4 + 4 + 4;

            /// <summary>Empty when no slow task (map load, package save, lighting build, ...) is running.</summary>
            public string StatusText { get; init; }

            /// <summary>0/0 outside of a StatusUpdatef call (e.g. "Encoding light-maps (N of M)") - not
            /// every status message carries real progress.</summary>
            public int Numerator { get; init; }
            public int Denominator { get; init; }

            /// <summary>EngineTickCount snapshot at the last update - lets a poller tell "still the
            /// same message" apart from "stopped updating".</summary>
            public int UpdateTick { get; init; }
        }

        /// <summary>Mirrors MailboxActionType in UDKAgent/CommonHooks.hpp. Keep the two in sync.</summary>
        private enum MailboxActionType
        {
            LoadMap = 1,
            BuildLighting = 2,
            SavePackages = 3,
            RunFaceFXCommand = 4,
            CloseSubWindows = 5,
        }

        // Resolved once right after injection (see ResolveRemoteViews) and read/written for the
        // rest of the run with plain ReadProcessMemory/WriteProcessMemory - no remote thread.
        // Replaces the old CallWithParams-based LoadMap/BuildLighting/SavePackages/IsUDKReady/
        // GetAgentStatus exports, which were removed from UDKAgent.asi: doing a
        // VirtualAllocEx+CreateRemoteThread cycle on every status poll (every 500ms) and every
        // dispatched action started intermittently failing with ERROR_ACCESS_DENIED partway
        // through a real bake.
        private static Allocation agentStatusView;
        private static Allocation actionMailboxHeaderView; // ActionMailbox.State/ActionType
        private static Allocation actionMailboxPayloadView; // ActionMailbox.Payload, zero-based
        private static Allocation lightmassProgressView;

        /// <summary>Package names (no extension) of every .udk under the content root - i.e.
        /// every package SaveMapFiles could possibly write. Built lazily since it walks the
        /// content tree; a real UDK content set is small enough for this to be cheap.</summary>
        private static HashSet<string> _mapPackageNames;

        /// <summary>
        /// Runs UDK and builds lighting, importing the results afterwards.
        /// </summary>
        /// <param name="mapName">The extensionless name of the map. Should already be in the UDK maps folder</param>
        /// <param name="allowLightmapCompression">Overrides DevOptions.StaticLighting.bAllowLightmapCompression
        /// in UDKLightmass.ini for just this build. Always applied: compressed lightmaps are DXT1, which
        /// bands badly, so bakes are uncompressed unless a caller explicitly opts back in.</param>
        /// <param name="defaultStaticMeshLightingRes">Overrides DevOptions.StaticLighting.DefaultStaticMeshLightingRes
        /// in UDKLightmass.ini for just this build (e.g. a one-off 256 test bake). Null leaves the
        /// file's existing setting alone.</param>
        /// <param name="qualityLevel">Lightmass build quality. See <see cref="LightmassBuildQuality"/>. Forced to
        /// <see cref="LightmassBuildQuality.Production"/> on a production build.</param>
        /// <param name="keepPreBakeMaps">Keep a copy of the exported maps before UDK modifies them.</param>
        /// <param name="ue4Lightmass">This level's UE4 Lightmass settings; null uses the defaults. Whether UE4
        /// Lightmass is used at all is decided before each run, see <see cref="UseLightmass"/>.</param>
        /// <param name="keepQuality">Use <paramref name="qualityLevel"/> even on a production build (test bakes).</param>
        internal static void ComputeLighting(string mapName, bool allowLightmapCompression = false, int? defaultStaticMeshLightingRes = null, LightmassBuildQuality qualityLevel = LightmassBuildQuality.Medium, bool keepPreBakeMaps = false, UE4LightmassSettings ue4Lightmass = null, bool keepQuality = false)
        {
            if (Program.Settings.ProductionBuild && qualityLevel != LightmassBuildQuality.Production && !keepQuality)
            {
                MilanLog.Information($"Production build: overriding lighting quality {qualityLevel} -> {LightmassBuildQuality.Production} for {mapName}", customPrefix: LOG_CATEGORY);
                qualityLevel = LightmassBuildQuality.Production;
                // qualityLevel = LightmassBuildQuality.Preview; // For not actual production lighting!
                //MilanLog.Fatal(@"NOTE - BUILDILNG LIGHTING AT MEDIUM QUALITY, NOT ACTUALLY PRODUCTION!----------");
            }

            var path = UDKDirectory.GetUDKGamePath();
            var userSettingsPath = Path.Combine(path, "Config", "UDKEditorUserSettings.ini");
            var lightmassIniPath = Path.Combine(path, "Config", "UDKLightmass.ini");

            // Kill any UDK left over from a previous run before touching its config or starting a
            // new one. A stray process holds the ini's config-on-exit rewrite hostage until it
            // dies, and if it's still around when we start a new one, Process.GetProcesses() name
            // lookups elsewhere in the pipeline can latch onto the wrong instance.
            foreach (var stale in Process.GetProcessesByName("UDK"))
            {
                MilanLog.Warning($"Killing stale UDK process {stale.Id} before starting a new build", customPrefix: LOG_CATEGORY);
                try
                {
                    stale.Kill();
                    stale.WaitForExit(10_000);
                }
                catch (Exception ex)
                {
                    MilanLog.Warning($"Could not kill stale UDK process {stale.Id}: {ex.Message}", customPrefix: LOG_CATEGORY);
                }
            }

            // After the stale-UDK kill: a leftover bridge exits once its UDK is gone, and a running
            // UnrealLightmass.exe can't be replaced. Disposed at method exit, after the finally below
            // has killed UDK, so the bridge is removed however the build ends.
            var solver = UseLightmass(ue4Lightmass ?? new UE4LightmassSettings(), mapName);
            using var lightmassRestore = new UE3LightmassRestore(solver);

            if (keepPreBakeMaps)
                KeepPreBakeMaps(mapName);

            using var configOverride = new EditorConfigOverride(userSettingsPath, EditorConfigOverride.AutomationProfile);

            // Same whole-file restore-on-exit pattern as configOverride above, just against
            // UDKLightmass.ini and only for the keys we actually need to control - everything else in
            // the file (photon counts, shadow rays, ...) is left exactly as the user tuned it.
            // Compression is read once per build by FStaticLightingSystem, straight from GConfig, so
            // writing it before UDK boots is enough.
            var lightmassOverrides = new List<(string Section, string Key, string Value)>
            {
                ("DevOptions.StaticLighting", "bAllowLightmapCompression", allowLightmapCompression ? "True" : "False"),
            };
            if (defaultStaticMeshLightingRes is { } res)
                lightmassOverrides.Add(("DevOptions.StaticLighting", "DefaultStaticMeshLightingRes", res.ToString()));

            using var lightmassOverride = new EditorConfigOverride(lightmassIniPath, lightmassOverrides);

            // Uncompressed lightmaps routinely push a big sublevel past 300 MB, and UObject::SavePackage then
            // puts up a modal "Package X was successfully saved and is N MByte in size. This exceeds the
            // recommended package size" box (Core.int PackageBiggerThanSoftLimit) that stalls the save
            // until someone clicks OK. The save itself already succeeded - it's purely advisory - and the
            // check is `size > PackageSizeSoftLimit << 20` in 32-bit math (UDK.exe SavePackage, RVA
            // 0x1BF8D4), so 2047 is the largest limit that doesn't overflow; the package format caps
            // out at 2 GB anyway (see LightmapResolutionOverrides.MaxTexelsPerPackage).
            using var engineOverride = new EditorConfigOverride(Path.Combine(path, "Config", "UDKEngine.ini"),
                [("Core.System", "PackageSizeSoftLimit", "2047")]);

            // Boot UDK.
            var udkInfo = new ProcessStartInfo()
            {
                FileName = UDKDirectory.GetExecutablePath(Program.Settings.MilanUDKPath),
                // Add -unattended if startup messages are getting in the way.
                // -forcelogflush: Launch.log is otherwise buffered, so a hung or killed UDK loses its last minutes of log.
                // -nosound - UDK is dumb
                Arguments = $"editor -log -forcelogflush -nosound",
                // Arguments = $"editor {mapName}.udk -log", // commented out; we control map load now.
            };

            MilanLog.Information("Starting UDK for lighting build", customPrefix: LOG_CATEGORY);
            var udkProcess = Process.Start(udkInfo);
            udkPid = udkProcess.Id;
            var bakeSucceeded = false;

            try
            {
                module ??= new FileInfo(UdkAgentPath);

                // AttachWithRetry sets up `injector`. Deliberately not using ProcessHandle in a
                // `using` here -- disposing it disposes the Process object it wraps, which would
                // invalidate udkProcess before the finally block below can kill it by PID.
                AttachWithRetry(udkProcess, TimeSpan.FromMinutes(3));
                ResolveRemoteViews();

                WaitForUDKReady(udkProcess, TimeSpan.FromMinutes(10));
                MilanLog.Information("UDK is ready", customPrefix: LOG_CATEGORY);

                var mapPath = StaticLightingExport.GetMapOutputPath(mapName);
                var masterMap = Path.Combine(mapPath, $"{mapName}.udk");

                BakeLighting(masterMap, qualityLevel, solver);
                bakeSucceeded = true;

                MilanLog.Information("UDK lighting build is complete", customPrefix: LOG_CATEGORY);
            }
            finally
            {
                // Dispose the injector's own remote allocations *before* killing UDK, so
                // VirtualFreeEx still has a live process to free from - freeing after the kill
                // below is what turned "failed to deallocate virtual memory" into a crash here.
                // Still wrapped in try/catch: UDK may already be gone by this point (e.g. it
                // crashed mid-bake), and once the process is dead there's nothing left to leak -
                // Windows reclaims all of its memory automatically on exit regardless of whether
                // VirtualFreeEx got to run.
                try
                {
                    injector?.Dispose();
                }
                catch (Win32Exception ex)
                {
                    MilanLog.Warning($"Could not clean up injector (UDK likely already exited): {ex.Message}", customPrefix: LOG_CATEGORY);
                }
                injector = null;

                // UDK rewrites its own ini on a clean exit, so it has to be gone before
                // EditorConfigOverride restores the original -- otherwise that shutdown write
                // lands on top of what we're putting back. Look the process up by pid rather than
                // using udkProcess: AttachWithRetry's ProcessHandle may already have disposed it.
                try
                {
                    using var live = Process.GetProcessById(udkPid);
                    if (!live.HasExited)
                    {
                        live.Kill();
                        live.WaitForExit(15_000);
                    }

                    MilanLog.Information($"MilanUDK has exited", customPrefix: LOG_CATEGORY);
                }
                catch (ArgumentException) { /* already gone */ }
                catch (InvalidOperationException) { /* already gone */ }
                catch (Exception ex)
                {
                    MilanLog.Warning($"Could not stop UDK: {ex.Message}", customPrefix: LOG_CATEGORY);
                }

                // Only a finished, saved bake is worth keeping. After a timeout, a crash or a killed
                // UDK, the UDK maps are the unbaked export (or a half-saved one), and copying them
                // over StaticLighting\Levels would throw away the last good lighting for this level.
                if (!bakeSucceeded)
                {
                    MilanLog.Warning($"Not copying {mapName} back from UDK because its lighting build did not finish; " +
                        $"{StaticLightingCache.GetLevelFolder(mapName)} keeps its previous lighting", customPrefix: LOG_CATEGORY);
                }
                else try
                {
                    // Wait for other processes that UDK spawns
                    // Would be good to just have a way to test what is holding onto a file. But this hopefully is enough.
                    Thread.Sleep(1000);

                    MilanLog.Information($"Copying computed lighting assets to Milan Pipelines", customPrefix: LOG_CATEGORY);


                    // Copy back the .udk files to the static lighting folder
                    var staticLightingFolder = StaticLightingCache.GetLevelFolder(mapName);
                    // The previous bake's encoded lightmap mips stay until the new bake is in place (see below)
                    LightmapMipCache.DeleteBakeKeepingCache(staticLightingFolder);
                    Directory.CreateDirectory(staticLightingFolder);

                    var udkOutputFolder = StaticLightingExport.GetMapOutputPath(mapName);
                    if (Directory.Exists(udkOutputFolder))
                    {
                        var files = Directory.GetFiles(udkOutputFolder, "*.udk");
                        foreach (var file in files)
                        {
                            MilanLog.Information($"Copying computed lighting for {Path.GetFileNameWithoutExtension(file)}", customPrefix: LOG_CATEGORY);
                            var dest = Path.Combine(staticLightingFolder, Path.GetFileName(file));
                            CopyWithLockRetry(file, dest);
                        }

                        // The new bake is in place, so the encoded lightmap mips made from the previous one are no use any more.
                        // This folder is this build's Lightmass's (UE3 or UE4); the other one's cache is not touched.
                        LightmapMipCache.Clear(staticLightingFolder);

                        // Now that the baked results are safely copied back to Milan, clear the UDK
                        // output folder - it might result in ambiguous packages on next boot
                        MilanLog.Information($"Cleaning up UDK map output folder for {mapName}", customPrefix: LOG_CATEGORY);
                        Utilities.DeleteFilesAndFoldersRecursively(udkOutputFolder, deleteDirectoryItself: false);
                    }
                    else
                    {
                        MilanLog.Warning($"UDK output folder not found: {staticLightingFolder}");
                    }
                }
                catch (Exception ex)
                {
                    // Only reached after a successful bake, so nothing else is in flight to be replaced.
                    throw new IOException($"Could not copy the baked {mapName} maps back from UDK: {ex.Message}", ex);
                }
            }
        }

        // The UdkInj submodule, built alongside ProjectMilan in the same configuration (see ProjectMilan.slnx).
        private static string UdkInjRoot => Path.GetFullPath(Path.Combine(MilanShared.PipelineRoot, "..", "..", "UdkInj"));
#if DEBUG
        private const string UdkInjConfiguration = "Debug";
#else
        private const string UdkInjConfiguration = "Release";
#endif
        private static string UdkAgentPath => Path.Combine(UdkInjRoot, "x64", UdkInjConfiguration, "UDKAgent.asi");
        private static string UdkInjShellPath => Path.Combine(UdkInjRoot, "UDKInj.Shell", "bin", UdkInjConfiguration, "net9.0", "UDKInj.Shell.exe");

        /// <summary>Checks lighting runtime dependencies before a build changes any output.</summary>
        internal static void VerifyBuildDependencies()
        {
            var requiredFiles = new[]
            {
                UdkAgentPath,
                UdkInjShellPath,
                Path.Combine(Path.GetDirectoryName(UdkInjShellPath)!, "LightmassBridge", "UnrealLightmass.exe"),
            };
            var missingFiles = requiredFiles.Where(path => !File.Exists(path)).ToArray();
            if (missingFiles.Length > 0)
                throw new FileNotFoundException(
                    $"Static lighting cannot start: required {UdkInjConfiguration} UdkInj files are missing:" +
                    Environment.NewLine + string.Join(Environment.NewLine, missingFiles) +
                    Environment.NewLine + "Build ProjectMilan.csproj with Visual Studio MSBuild and the C++ toolchain " +
                    $"in {UdkInjConfiguration}|x64 before running a static lighting build.");

            MilanLog.Information($"Verified {UdkInjConfiguration} UdkInj lighting dependencies", customPrefix: LOG_CATEGORY);
        }

        /// <summary>
        /// Milan's UE4 reference bakes, one per quality level (Preview/Medium/High/Production). The
        /// bridge takes each UE4 solver-quality header from the one matching the UDK build's quality.
        /// Only each bake's logical scene is kept - UdkInj docs/LIGHTMASS_BRIDGE.md covers re-baking them.
        /// </summary>
        private static string UE4ReferencePath => Path.Combine(MilanShared.PipelineRoot, "StaticLighting", "UE4Lightmass", "Reference");

        /// <summary>
        /// Decides, before each UDK run, which Lightmass solves this build, and puts it in UDK's
        /// Binaries\Win64 via the UdkInj Shell's install-/uninstall-lightmass-bridge commands. UE4 is used
        /// unless the level asks for UE3 or anything the bridge needs is missing on this machine (UE4
        /// Lightmass, the UdkInj Shell, Milan's UE4 reference bakes), in which case the build falls
        /// back to UE3 with a warning rather than failing. A UE3 build
        /// (<see cref="Program.Lightmass"/>) uses UE3 for every level. Every UE4 build reinstalls the bridge from
        /// Milan's reference bakes with this level's tuning (keeping the bridge's own Ue4Threads cap);
        /// every UE3 build removes a bridge left behind by an interrupted run.
        /// </summary>
        /// <returns>The solver UDK now has; UE4 must be undone with <see cref="RestoreUE3Lightmass"/>.</returns>
        private static LightmassSolver UseLightmass(UE4LightmassSettings settings, string mapName)
        {
            if (Program.Lightmass == LightmassSolver.UE3)
                MilanLog.Information("Lightmass: UE3 (this build bakes with UE3, --lightmass UE3)", customPrefix: LOG_CATEGORY);
            else if (settings.UseUE3)
                MilanLog.Information("Lightmass: UE3 (this level sets UE4Lightmass.UseUE3)", customPrefix: LOG_CATEGORY);
            else if (FindUE4Lightmass(out var reason) is not { } ue4Lightmass)
                MilanLog.Warning($"Lightmass: UE3, because UE4 Lightmass can't be used: {reason}", customPrefix: LOG_CATEGORY);
            else
            {
                settings = Program.UE4LightmassOverrides.ApplyTo(settings);
                MilanLog.Information($"Lightmass: UE4 ({ue4Lightmass}; environment color x{settings.EnvironmentColorScale}, " +
                    $"sun indirect x{settings.DirectionalIndirectLightingScale}, point/spot indirect x{settings.LocalIndirectLightingScale}, " +
                    $"point/spot brightness x{settings.LocalLightBrightnessScale}, point/spot radius x{settings.LocalLightRadiusScale}, " +
                    $"diffuse boost x{settings.DiffuseBoostScale}, bounces {settings.IndirectLightingBounces?.ToString() ?? "as exported"})", customPrefix: LOG_CATEGORY);
                var culture = System.Globalization.CultureInfo.InvariantCulture;
                var importanceBox = "";
                if (settings.ImportanceBox is { Length: 6 } box)
                {
                    importanceBox = " --importance-box " + string.Join(",", box.Select(v => v.ToString("0.###", culture)));
                    MilanLog.Information($"Importance volume ({box[0]:0},{box[1]:0},{box[2]:0})-({box[3]:0},{box[4]:0},{box[5]:0}) as given", customPrefix: LOG_CATEGORY);
                }
                else if (settings.AddImportanceVolume && GameplayImportanceVolume.Compute(StaticLightingExport.GetMapOutputPath(mapName), settings.ImportanceVolumeMargin) is var (min, max))
                    importanceBox = " --importance-box " + string.Join(",", new[] { min.X, min.Y, min.Z, max.X, max.Y, max.Z }.Select(v => v.ToString("0.###", culture)));
                RunUdkInjShell($"install-lightmass-bridge \"{Program.Settings.MilanUDKPath}\" \"{UE4ReferencePath}\" \"{ue4Lightmass}\" " +
                    $"--environment-color-scale {settings.EnvironmentColorScale.ToString(culture)} " +
                    $"--directional-indirect-scale {settings.DirectionalIndirectLightingScale.ToString(culture)} " +
                    $"--local-indirect-scale {settings.LocalIndirectLightingScale.ToString(culture)} " +
                    $"--local-brightness-scale {settings.LocalLightBrightnessScale.ToString(culture)} " +
                    $"--local-radius-scale {settings.LocalLightRadiusScale.ToString(culture)} " +
                    $"--diffuse-boost-scale {settings.DiffuseBoostScale.ToString(culture)}" +
                    (settings.IndirectLightingBounces is { } bounces ? $" --indirect-bounces {bounces.ToString(culture)}" : "") + importanceBox,
                    "install the UE4 Lightmass bridge");
                return LightmassSolver.UE4;
            }

            RestoreUE3Lightmass();
            return LightmassSolver.UE3;
        }

        /// <summary>
        /// Puts UDK's own UE3 Lightmass back if the bridge is installed; a no-op otherwise. Milan does
        /// this after every UE4 build so a hand-run UDK is never left on the bridge.
        /// </summary>
        private static void RestoreUE3Lightmass()
        {
            // Without the Shell the bridge can't have been installed here, so UDK already has UE3.
            if (File.Exists(UdkInjShellPath))
                RunUdkInjShell($"uninstall-lightmass-bridge \"{Program.Settings.MilanUDKPath}\"", "restore UDK's UE3 Lightmass");
        }

        /// <summary>Runs <see cref="RestoreUE3Lightmass"/> on dispose after a UE4 build. A failure is only
        /// logged: the next UE3 build (or the next UE4 install) replaces the bridge anyway.</summary>
        private sealed class UE3LightmassRestore(LightmassSolver solver) : IDisposable
        {
            public void Dispose()
            {
                if (solver != LightmassSolver.UE4)
                    return;
                try
                {
                    RestoreUE3Lightmass();
                }
                catch (Exception ex)
                {
                    MilanLog.Warning($"Could not restore UDK's UE3 Lightmass: {ex.Message}", customPrefix: LOG_CATEGORY);
                }
            }
        }

        /// <summary>
        /// Whether the UE4 bridge solved the lighting build started at <paramref name="buildStartUtc"/>:
        /// each bridge job keeps a work directory (under WorkRoot in the bridge's config.json) whose
        /// bridge-job.json is written when the job starts and bridge-result.json only once every
        /// mapping has been handed back to UDK.
        /// </summary>
        private static bool UE4BridgeSucceeded(DateTime buildStartUtc, out string failure)
        {
            failure = null;
            var configPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "UdkInj", "LightmassBridge", "config.json");
            string workRoot;
            try
            {
                using var config = System.Text.Json.JsonDocument.Parse(File.ReadAllText(configPath));
                workRoot = config.RootElement.GetProperty("WorkRoot").GetString();
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or System.Text.Json.JsonException
                                           or KeyNotFoundException or InvalidOperationException)
            {
                failure = $"could not read the bridge's WorkRoot from {configPath}: {ex.Message}";
                return false;
            }

            var jobs = Directory.Exists(workRoot)
                ? new DirectoryInfo(workRoot).EnumerateDirectories()
                    .Where(d => d.CreationTimeUtc >= buildStartUtc && File.Exists(Path.Combine(d.FullName, "bridge-job.json")))
                    .ToList()
                : [];
            if (jobs.Count == 0)
                failure = "no bridge job ran";
            else if (jobs.FirstOrDefault(d => !File.Exists(Path.Combine(d.FullName, "bridge-result.json"))) is { } failed)
                failure = $"bridge job {failed.FullName} has no result; see its log in UDK's Launch.log ([UdkInj bridge] lines)";
            else
                MilanLog.Information($"UE4 Lightmass solved the build ({string.Join(", ", jobs.Select(d => d.Name))})", customPrefix: LOG_CATEGORY);
            return failure == null;
        }

        private static void RunUdkInjShell(string arguments, string what)
        {
            using var shell = Process.Start(new ProcessStartInfo(UdkInjShellPath, arguments)
            {
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true,
            }) ?? throw new InvalidOperationException($"Could not start {UdkInjShellPath}");
            var output = shell.StandardOutput.ReadToEndAsync();
            var error = shell.StandardError.ReadToEndAsync();
            shell.WaitForExit();
            foreach (var line in (output.Result + error.Result).Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
                MilanLog.Information($"  [UdkInj] {line}", customPrefix: LOG_CATEGORY);
            if (shell.ExitCode != 0)
                throw new InvalidOperationException($"Could not {what} (UdkInj exit code {shell.ExitCode}); see the [UdkInj] lines above.");
        }

        /// <summary>
        /// UE4.27's UnrealLightmass.exe if the bridge can use it on this machine, else null with
        /// <paramref name="reason"/>. <see cref="Settings.IMilanSettings.UE4LightmassPath"/> wins when set;
        /// otherwise the Epic launcher's UE_4.27 install is looked up (registry, then the launcher's
        /// install list, then its default Program Files\Epic Games\UE_4.27 layout on each fixed drive,
        /// since the first two are not always kept up to date).
        /// </summary>
        private static string FindUE4Lightmass(out string reason)
        {
            reason = null;
            if (!File.Exists(UdkInjShellPath))
                reason = $"the UdkInj Shell is not at {UdkInjShellPath}";
            else if (!Directory.Exists(UE4ReferencePath))
                reason = $"Milan's UE4 reference bakes are missing ({UE4ReferencePath})";
            if (reason != null)
                return null;

            var configured = Program.Settings.UE4LightmassPath;
            if (!string.IsNullOrWhiteSpace(configured))
            {
                if (File.Exists(configured))
                    return Path.GetFullPath(configured);
                reason = $"UE4LightmassPath {configured} does not exist";
                return null;
            }

            const string relativeExe = @"Engine\Binaries\Win64\UnrealLightmass.exe";
            foreach (var root in UE427InstallCandidates())
            {
                var exe = Path.Combine(root, relativeExe);
                if (File.Exists(exe))
                    return exe;
            }
            reason = "UE4LightmassPath is not set and no UE_4.27 install was found";
            return null;
        }

        private static IEnumerable<string> UE427InstallCandidates()
        {
            if (Microsoft.Win32.Registry.GetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\EpicGames\Unreal Engine\4.27", "InstalledDirectory", null) is string installed)
                yield return installed;

            var launcherList = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
                "Epic", "UnrealEngineLauncher", "LauncherInstalled.dat");
            var listed = new List<string>();
            try
            {
                using var json = System.Text.Json.JsonDocument.Parse(File.ReadAllText(launcherList));
                foreach (var app in json.RootElement.GetProperty("InstallationList").EnumerateArray())
                    if (app.GetProperty("AppName").GetString() == "UE_4.27")
                        listed.Add(app.GetProperty("InstallLocation").GetString());
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or System.Text.Json.JsonException
                                           or KeyNotFoundException or InvalidOperationException)
            {
                // No launcher, or a list in an unexpected shape: fall through to the default layout.
            }
            foreach (var path in listed)
                yield return path;

            foreach (var drive in DriveInfo.GetDrives().Where(x => x.DriveType == DriveType.Fixed))
                yield return Path.Combine(drive.RootDirectory.FullName, "Program Files", "Epic Games", "UE_4.27");
        }

        /// <summary>
        /// Bakes one map again from the pre-bake UDK maps an earlier build kept (--keep-prebake-maps), without porting
        /// or exporting anything - for trying solver settings on a single map. The result replaces the map's folder in
        /// this build's Lightmass's bakes (<see cref="StaticLightingCache"/>), which is first copied to StaticLighting\Backup.
        /// Nothing is imported into the mod.
        /// </summary>
        internal static void BakeFromPreBakeMaps(string mapName, LightmassBuildQuality quality, int defaultStaticMeshLightingRes)
        {
            // Standalone bakes bypass ExportLevelToUDK/UDKSetup, which normally select Milan's UDK.
            // Keep the working maps, config overrides, bridge, and launched editor in the same install.
            LegendaryExplorerCore.LegendaryExplorerCoreLibSettings.Instance.UDKCustomDirectory = Program.Settings.MilanUDKPath;
            // Accessing Instance can initialize settings and reload the globally configured paths.
            UDKDirectory.DefaultGamePath = Program.Settings.MilanUDKPath;

            var preBake = Path.Combine(MilanShared.PipelineRoot, "StaticLighting", "PreBake", mapName);
            var maps = Directory.Exists(preBake) ? Directory.GetFiles(preBake, "*.udk") : [];
            if (!maps.Any(f => Path.GetFileNameWithoutExtension(f).Equals(mapName, StringComparison.OrdinalIgnoreCase)))
                throw new FileNotFoundException($"No pre-bake maps for {mapName}; run a lighting build with --keep-prebake-maps first", preBake);

            var levels = StaticLightingCache.GetLevelFolder(mapName);
            if (Directory.Exists(levels) && Directory.EnumerateFiles(levels).Any())
            {
                var backup = Directory.CreateDirectory(Path.Combine(MilanShared.PipelineRoot, "StaticLighting", "Backup", $"{mapName}_{Program.Lightmass}_{DateTime.Now:yyyyMMdd_HHmmss}")).FullName;
                foreach (var file in Directory.GetFiles(levels))
                    File.Copy(file, Path.Combine(backup, Path.GetFileName(file)));
                MilanLog.Information($"Backed up the current {mapName} bake to {backup}", customPrefix: LOG_CATEGORY);
            }

            var mapOutput = StaticLightingExport.GetMapOutputPath(mapName);
            Utilities.DeleteFilesAndFoldersRecursively(mapOutput, deleteDirectoryItself: false);
            foreach (var map in maps)
                File.Copy(map, Path.Combine(mapOutput, Path.GetFileName(map)));
            // Older snapshots may predate the correction. Apply it to the working copies, leaving
            // the preserved snapshot and gameplay packages intact.
            var pipeline = MPLevels.FindLevelPipeline(mapName);
            if (pipeline != null)
                StaticLightingExport.ApplyExportCorrections(pipeline, Directory.GetFiles(mapOutput, "*.udk"));

            // 11/02/2026 - Add support for a custom lightmass setup
            if (pipeline?.WorldLightmass != null)
            {
                using var persistent = MEPackageHandler.OpenUDKPackage(Path.Combine(mapOutput, $"{mapName}.udk"));
                pipeline.WorldLightmass.ApplyTo(persistent.Exports.First(exp => exp.ClassName == "WorldInfo"), LOG_CATEGORY);
                if (persistent.IsModified)
                {
                    persistent.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
                }
            }
            MilanLog.Information($"Baking {mapName} at {quality} from {maps.Length} pre-bake maps into the {Program.Lightmass} bakes", customPrefix: LOG_CATEGORY);
            ComputeLighting(mapName, allowLightmapCompression: false, defaultStaticMeshLightingRes: defaultStaticMeshLightingRes,
                qualityLevel: quality, ue4Lightmass: pipeline?.UE4Lightmass, keepQuality: true);
        }

        private static void KeepPreBakeMaps(string mapName)
        {
            var mapPath = StaticLightingExport.GetMapOutputPath(mapName);
            var sourceMaps = Directory.GetFiles(mapPath, "*.udk", SearchOption.TopDirectoryOnly);
            if (!sourceMaps.Any(file => Path.GetFileNameWithoutExtension(file).Equals(mapName, StringComparison.OrdinalIgnoreCase)))
                throw new FileNotFoundException($"Cannot preserve pre-bake maps: master map {mapName}.udk was not exported", Path.Combine(mapPath, $"{mapName}.udk"));

            // Keep this outside StaticLighting/Levels: the post-bake copy clears the level's folder there.
            var snapshotPath = Path.Combine(MilanShared.PipelineRoot, "StaticLighting", "PreBake", mapName);
            Directory.CreateDirectory(snapshotPath);
            foreach (var oldMap in Directory.GetFiles(snapshotPath, "*.udk", SearchOption.TopDirectoryOnly))
                File.Delete(oldMap);
            foreach (var sourceMap in sourceMaps)
                File.Copy(sourceMap, Path.Combine(snapshotPath, Path.GetFileName(sourceMap)));

            MilanLog.Information($"Preserved {sourceMaps.Length} pre-bake UDK maps at {snapshotPath}", customPrefix: LOG_CATEGORY);
        }

        private static readonly TimeSpan LockRetryInterval = TimeSpan.FromSeconds(2);
        private static readonly TimeSpan LockRetryTimeout = TimeSpan.FromMinutes(2);

        /// <summary>
        /// Copies a file, retrying while it's locked by another process. UDK can take a moment to
        /// fully release its output files after exit (or a spawned child process may still be
        /// holding one), so on an IOException we identify who's holding the lock via Restart
        /// Manager and keep retrying until it clears or we time out.
        /// </summary>
        private static void CopyWithLockRetry(string source, string destination)
        {
            var start = DateTime.UtcNow;
            while (true)
            {
                try
                {
                    File.Copy(source, destination, true);
                    return;
                }
                catch (IOException) when (DateTime.UtcNow - start < LockRetryTimeout)
                {
                    var lockedBy = FileLockUtils.DescribeLockingProcesses(source);
                    MilanLog.Warning($"Waiting for {lockedBy} to release {Path.GetFileName(source)}...", customPrefix: LOG_CATEGORY);
                    Thread.Sleep(LockRetryInterval);
                }
            }
        }

        /// <summary>
        /// Loads a map, rebuilds its lighting and saves it. Each step waits for the agent to
        /// actually go idle before the next is queued, so a synchronous action can't run inside
        /// another one.
        ///
        /// Deliberately no CloseSubWindows() calls between steps here. Closing popups after the
        /// fact cannot work for a *modal* dialog: the action queue is drained from the engine
        /// tick, and a modal blocks that very thread, so a queued CloseSubWindows action can never
        /// be dispatched to dismiss it. The Load Errors dialog this used to try to dismiss is
        /// suppressed at the hook level instead (UDKAgent's CBDisplayLoadErrors_Hook), and the
        /// journal/browser-pane popups are suppressed via ini in EditorConfigOverride.
        /// </summary>
        private static void BakeLighting(string masterMapPath, LightmassBuildQuality qualityLevel, LightmassSolver solver)
        {
            var loadErrorsBefore = GetLoadErrorCount();

            LoadMap(masterMapPath);

            // The Load Errors dialog we suppress is UDK's own guard against exactly this: saving
            // with unresolved package references writes them out as NULL, permanently stripping
            // content from the map. Suppressing the dialog without replacing the check would turn
            // a warning into silent data loss - but a naive "any error at all -> refuse" version
            // of that check is too blunt: LoadMap pulls in everything a level references
            // transitively, including plain content packages nobody is about to save, and an
            // unrelated texture failing to resolve one of *its* dependencies shouldn't block a
            // save that never touches that package. So classify each error by which package was
            // actually being deserialized when it fired, and only block on ones that land in a
            // package SaveMapFiles could actually write.
            var loadErrorsAfter = GetLoadErrorCount();
            if (loadErrorsAfter > loadErrorsBefore)
            {
                var blocking = new List<string>();

                for (int i = loadErrorsBefore; i < loadErrorsAfter; i++)
                {
                    var entry = GetLoadErrorEntry(i);
                    var kind = entry.Type == 0 ? "FILE" : "RESOURCE";
                    var line = $"[{kind}] {entry.Desc}";

                    if (IsKnownBenignLoadError(entry.Desc))
                    {
                        MilanLog.Information($"  (ignoring - known benign UDK load-error quirk) {line}", customPrefix: LOG_CATEGORY);
                        continue;
                    }

                    var referencingPackage = ExtractReferencingPackage(entry.Desc);

                    if (referencingPackage == null)
                    {
                        // Couldn't identify who owns the bad reference - treat that as blocking
                        // rather than silently letting it through.
                        blocking.Add($"{line} (referencing package unknown)");
                    }
                    else if (IsMapPackage(referencingPackage))
                    {
                        blocking.Add($"{line} (in '{referencingPackage}', which will be saved)");
                    }
                    else
                    {
                        MilanLog.Information(
                            $"  (ignoring - '{referencingPackage}' is not a map package, won't be saved) {line}",
                            customPrefix: LOG_CATEGORY);
                    }
                }

                if (blocking.Count > 0)
                {
                    throw new InvalidOperationException(
                        $"'{Path.GetFileName(masterMapPath)}' has {blocking.Count} unresolved " +
                        "reference(s) in package(s) that would be saved. Saving would write those " +
                        "references out as NULL and strip content from the map:\n  " +
                        string.Join("\n  ", blocking) + "\nRefusing to build or save.");
                }
            }

            var buildStartUtc = DateTime.UtcNow;
            using (new LightmassProgressReporter())
                RunLightmass(qualityLevel);

            // A failed Lightmass build still returns here, and saving would write the map out
            // without its lighting. UDK only logs a failed UE4 bridge job, so check the bridge's own
            // result marker, and rebuild with UE3 in the same editor session if it didn't finish.
            if (solver == LightmassSolver.UE4 && !UE4BridgeSucceeded(buildStartUtc, out var failure))
            {
                MilanLog.ErrorWithSummary($"UE4 Lightmass did not finish the {Path.GetFileNameWithoutExtension(masterMapPath)} build ({failure}); rebuilt it with UE3 Lightmass", customPrefix: LOG_CATEGORY);
                RestoreUE3Lightmass();
                using (new LightmassProgressReporter())
                    RunLightmass(qualityLevel);
            }

            // Sleep for a few seconds.
            // Thread.Sleep(TimeSpan.FromSeconds(60));
            // Debugger.Break();


            SaveMapFiles();
        }

        /// <summary>
        /// Polls g_LightmassProgress and logs the Lightmass build-progress dialog's own status
        /// text ("Running Lightmass...", "Encoding light-maps (N of M)", ...) - see
        /// EnsureLightmassProgressHooksInstalled in UDKAgent/CommonHooks.cpp for how that text
        /// gets there; nothing else ever surfaces it anywhere (not even Launch.log).
        ///
        /// g_LightmassProgress is refreshed by every slow task in the editor, not just Lightmass
        /// (BeginSlowTask/StatusUpdatef/EndSlowTask are shared machinery), so this is deliberately
        /// scoped to just the RunLightmass call rather than left running for the whole bake -
        /// logging a stale map-load status while a save is happening would be more confusing than
        /// useful.
        ///
        /// Logs on every change immediately, and otherwise on a fixed heartbeat so a long
        /// "Running Lightmass..." stretch (no progress ratio - Lightmass reports back to GWarn
        /// through Swarm in bursts, not continuously) doesn't look hung in the Milan log.
        /// </summary>
        private sealed class LightmassProgressReporter : IDisposable
        {
            private static readonly TimeSpan HeartbeatInterval = TimeSpan.FromSeconds(5);
            private static readonly Regex StatusRatioRegex = new(@"\(\d+\s+of\s+\d+\)\s*$", RegexOptions.Compiled);

            private readonly Thread _thread;
            private volatile bool _stop;

            public LightmassProgressReporter()
            {
                _thread = new Thread(Pump) { IsBackground = true, Name = "Lightmass progress" };
                _thread.Start();
            }

            private void Pump()
            {
                string lastText = null;
                DateTime lastLog = DateTime.MinValue;

                while (!_stop)
                {
                    LightmassProgressStatus status;
                    try
                    {
                        status = GetLightmassProgress();
                    }
                    catch (Exception)
                    {
                        // UDK exited or was killed. This is a background thread, so an exception here
                        // would take the whole process down; the build's own wait reports what happened.
                        return;
                    }

                    if (!string.IsNullOrEmpty(status.StatusText))
                    {
                        bool changed = status.StatusText != lastText;
                        if (changed || DateTime.UtcNow - lastLog > HeartbeatInterval)
                        {
                            // Some StatusUpdatef callers bake "(%d of %d)" into the format string
                            // itself (e.g. "Encoding light-maps (8 of 105)"); others reuse a
                            // static message ("Running Lightmass...") and rely on Numerator/
                            // Denominator alone for the ratio. Appending unconditionally double-
                            // prints the former, so only append when the text doesn't already end
                            // in one.
                            var alreadyHasRatio = StatusRatioRegex.IsMatch(status.StatusText);
                            var progress = (!alreadyHasRatio && status.Denominator > 0)
                                ? $" ({status.Numerator} of {status.Denominator})"
                                : "";
                            MilanLog.Information($"  [Lightmass] {status.StatusText}{progress}", customPrefix: LOG_CATEGORY);
                            lastText = status.StatusText;
                            lastLog = DateTime.UtcNow;
                        }
                    }

                    Thread.Sleep(TimeSpan.FromSeconds(1));
                }
            }

            public void Dispose()
            {
                _stop = true;
                _thread.Join(TimeSpan.FromSeconds(2));
            }
        }

        // This UDK build's own error text already names the referencing package - e.g.
        // "Texture2D BioT_Collector_MtL.MetalPanel01_Norm in BioT_LevelMaster" (import-verify
        // failure) or "Can't find file for package 'CubeIn_temp' while loading
        // ..\..\UDKGame\Content\Shared\Decooked\LE3\biot_jail_int.upk" (missing file entirely).
        // Order matters: check the file-load form first, since its trailing "...\Name.upk" would
        // not match the "in Name$" pattern anyway, but being explicit avoids relying on that.
        private static readonly Regex WhileLoadingPackageRegex =
            new(@"while loading .*[\\/]([A-Za-z0-9_]+)\.\w+\s*$", RegexOptions.Compiled);
        private static readonly Regex ReferencedInPackageRegex =
            new(@"\sin\s+([A-Za-z0-9_]+)\s*$", RegexOptions.Compiled);

        /// <summary>
        /// UDK regularly raises "Can't find file 'None'" - a load error whose "file" is the
        /// engine's own null-name sentinel (NAME_None), not a real missing reference. It has no
        /// owning package to check against SaveMapFiles' output, and is a common, confirmed-
        /// harmless UDK quirk rather than a genuine unresolved reference, so it's never worth
        /// blocking on regardless of context.
        /// </summary>
        private static bool IsKnownBenignLoadError(string desc) =>
            desc.StartsWith("Can't find file 'None'", StringComparison.Ordinal);

        private static string ExtractReferencingPackage(string desc)
        {
            var match = WhileLoadingPackageRegex.Match(desc);
            if (match.Success) return match.Groups[1].Value;

            match = ReferencedInPackageRegex.Match(desc);
            return match.Success ? match.Groups[1].Value : null;
        }

        /// <summary>True if a .udk with this package name exists anywhere under the content root -
        /// i.e. it's a level package SaveMapFiles could write, not plain content.</summary>
        private static bool IsMapPackage(string packageName)
        {
            _mapPackageNames ??= Directory
                .EnumerateFiles(Path.Combine(UDKDirectory.GetUDKGamePath(), "Content"), "*.udk", SearchOption.AllDirectories)
                .Select(Path.GetFileNameWithoutExtension)
                .Where(name => !string.IsNullOrEmpty(name))
                .ToHashSet(StringComparer.OrdinalIgnoreCase);

            return _mapPackageNames.Contains(packageName);
        }

        #region Actions

        private static void LoadMap(string persistentPackagePath) =>
            RunAction(MailboxActionType.LoadMap,
                input => input.WriteStringUTF16(0, persistentPackagePath),
                timeout: TimeSpan.FromMinutes(15),
                label: $"LoadMap({Path.GetFileName(persistentPackagePath)})");

        // Quality levels:
        // 1 = ?
        private static void RunLightmass(LightmassBuildQuality qualityLevel) =>
            RunAction(MailboxActionType.BuildLighting,
                input => input.WriteInt32(0, (int)qualityLevel),
                timeout: LightingBuildTimeout,
                label: $"BuildLighting(quality={qualityLevel})");

        private static void SaveMapFiles(bool promptUser = false, bool saveMaps = true, bool saveContent = false) =>
            RunAction(MailboxActionType.SavePackages,
                input =>
                {
                    input.WriteInt32(0, promptUser ? 1 : 0);
                    input.WriteInt32(4, saveMaps ? 1 : 0);
                    input.WriteInt32(8, saveContent ? 1 : 0);
                },
                timeout: TimeSpan.FromMinutes(30),
                label: "SavePackages");

        #endregion

        #region Dispatch plumbing

        /// <summary>
        /// Queues an action on the agent and blocks until it has actually completed.
        ///
        /// Completion is detected by watching the agent's monotonic CompletedActions counter
        /// together with IsIdle, rather than by polling IsSlowTaskRunning directly: LoadMap /
        /// BuildLighting / SavePackages are all queued and dispatched from UDK's engine tick, so
        /// GSlowTaskRunning can still read 0 for a moment after queuing, before the action has
        /// actually started. Watching for CompletedActions to advance rules that race out.
        /// </summary>
        private static void RunAction(MailboxActionType actionType, Action<Allocation> writeInput, TimeSpan timeout, string label)
        {
            var before = ReadStatus(label);

            // Don't queue on top of something already running.
            if (!before.IsIdle)
                WaitUntil(s => s.IsIdle, TimeSpan.FromMinutes(5), $"agent idle before {label}");

            var completedBefore = ReadStatus(label).CompletedActions;

            MilanLog.Information($"-> {label}", customPrefix: LOG_CATEGORY);
            var sw = Stopwatch.StartNew();

            // Dispatch is a WriteProcessMemory into g_ActionMailbox, not a remote thread - see
            // ActionMailbox in UDKAgent/CommonHooks.hpp. State flips last: ServiceActionMailbox
            // only reads ActionType/Payload once it observes State=1, and this method never
            // writes a new request until the previous one's completion is observed below, so
            // there is nothing else to synchronize.
            writeInput?.Invoke(actionMailboxPayloadView);
            actionMailboxHeaderView.WriteInt32(4, (int)actionType);
            actionMailboxHeaderView.WriteInt32(0, 1);

            WaitUntil(s => s.CompletedActions > completedBefore && s.IsIdle, timeout, label);

            MilanLog.Information($"<- {label} ({sw.Elapsed:hh\\:mm\\:ss})", customPrefix: LOG_CATEGORY);
        }

        /// <summary>
        /// Opens a handle to the freshly-started UDK and injects the agent, retrying until it
        /// takes. There is no reliable "ready to be injected" signal: a fixed sleep is a race,
        /// because how long UDK needs before it will accept a remote thread depends on how much
        /// content it has to load. So retry on the actual failure instead of guessing a delay.
        /// </summary>
        private static void AttachWithRetry(Process udkProcess, TimeSpan timeout)
        {
            // Injection has to land inside a window: late enough that UDK will accept a remote
            // thread, but early enough that the agent's UIInit hook is installed before OnInit
            // returns -- that hook is one of two signals WaitForUDKReady watches for (the other,
            // IsEditorReady, is derived from the engine tick and catches late injection too).
            Thread.Sleep(TimeSpan.FromSeconds(3));

            var deadline = DateTime.UtcNow + timeout;
            Win32Exception lastError = null;

            for (int attempt = 1; DateTime.UtcNow < deadline; attempt++)
            {
                if (udkProcess.HasExited)
                    throw new InvalidOperationException($"UDK exited during startup (code {udkProcess.ExitCode})");

                try
                {
                    var handle = new ProcessHandle(udkProcess);
                    var probe = new Injector(handle, bDisposeProcess: false);
                    probe.Inject(module);

                    injector = probe;
                    MilanLog.Information($"Injected agent (attempt {attempt})", customPrefix: LOG_CATEGORY);
                    return;
                }
                catch (Win32Exception ex)
                {
                    lastError = ex;
                    MilanLog.Information($"  attach attempt {attempt} failed (win32 {ex.NativeErrorCode}: {ex.Message}); retrying", customPrefix: LOG_CATEGORY);
                    Thread.Sleep(TimeSpan.FromSeconds(2));
                }
            }

            throw new TimeoutException(
                $"could not inject within {timeout} " +
                $"(last win32 {lastError?.NativeErrorCode}: {lastError?.Message})");
        }

        private static void WaitForUDKReady(Process udkProcess, TimeSpan timeout)
        {
            var deadline = DateTime.UtcNow + timeout;
            var lastReport = DateTime.UtcNow;

            while (DateTime.UtcNow < deadline)
            {
                var status = GetStatusOrThrowIfUDKExited(udkProcess, "waiting for UDK to become ready");
                if (status.EngineTickCount >= 5 && status.SlowTaskDepth == 0) return;

                // Don't stall silently -- a wait with no visible state is what made the previous
                // readiness race so hard to tell apart from "UDK is just slow today".
                if (DateTime.UtcNow - lastReport > TimeSpan.FromSeconds(15))
                {
                    lastReport = DateTime.UtcNow;
                    MilanLog.Information($"  waiting for UDK... {status}", customPrefix: LOG_CATEGORY);
                }

                Thread.Sleep(TimeSpan.FromSeconds(1));
            }

            var lastStatus = GetStatusOrThrowIfUDKExited(udkProcess, "checking UDK readiness after timeout");
            throw new TimeoutException($"UDK was not ready within {timeout} (last status: {lastStatus})");
        }

        /// <summary>
        /// Resolves g_AgentStatus/g_ActionMailbox's remote addresses once, right after injection.
        /// Safe to call immediately: the RVA comes from the .asi's own on-disk export table (see
        /// PEExportReader), not from anything that needs the agent to have run yet - the globals
        /// just read as zero-initialized until the first engine tick refreshes them, which
        /// IsUDKReady's EngineTickCount/SlowTaskDepth-based check already accounts for.
        /// </summary>
        private static void ResolveRemoteViews()
        {
            agentStatusView = injector.WrapRemoteExport(module, "g_AgentStatus", AgentStatus.SizeBytes);
            actionMailboxHeaderView = injector.WrapRemoteExport(module, "g_ActionMailbox", fieldOffset: 0, size: 8);
            actionMailboxPayloadView = injector.WrapRemoteExport(module, "g_ActionMailbox", fieldOffset: 8, size: 1024);
            lightmassProgressView = injector.WrapRemoteExport(module, "g_LightmassProgress", LightmassProgressStatus.SizeBytes);
        }

        /// <summary>Reads g_LightmassProgress directly - only meaningful while
        /// EnsureLightmassProgressHooksInstalled (UDKAgent/CommonHooks.cpp, called lazily right
        /// before the first BuildLighting) has actually run, so don't rely on this before that.</summary>
        private static LightmassProgressStatus GetLightmassProgress() => new()
        {
            StatusText = lightmassProgressView.ReadStringUTF16(0, 256),
            Numerator = lightmassProgressView.ReadInt32(512),
            Denominator = lightmassProgressView.ReadInt32(516),
            UpdateTick = lightmassProgressView.ReadInt32(520),
        };

        /// <summary>
        /// Reads the agent's status only while the UDK process is still alive. A pre-read
        /// <see cref="Process.HasExited"/> check gives the real failure cause when UDK quits
        /// during startup; the ERROR_PARTIAL_COPY fallback closes the small race where it exits
        /// between that check and ReadProcessMemory.
        /// </summary>
        private static AgentStatus GetStatusOrThrowIfUDKExited(Process udkProcess, string operation)
        {
            ThrowIfUDKExited(udkProcess, operation);

            try
            {
                return GetStatus();
            }
            catch (Win32Exception ex) when (ex.NativeErrorCode == 299)
            {
                // ERROR_PARTIAL_COPY normally means the remote address was unmapped because
                // UDK exited. Refresh before checking so Process has current exit state.
                udkProcess.Refresh();
                ThrowIfUDKExited(udkProcess, operation);

                // The process did not exit, so this is a genuine injector/memory-access
                // failure rather than misreporting a UDK shutdown as one.
                throw new InvalidOperationException(
                    $"Could not read the UDK agent status while {operation}, even though UDK " +
                    $"(PID {udkProcess.Id}) is still running.", ex);
            }
        }

        private static void ThrowIfUDKExited(Process udkProcess, string operation)
        {
            udkProcess.Refresh();
            if (!udkProcess.HasExited) return;

            throw new InvalidOperationException(
                $"UDK (PID {udkProcess.Id}) exited with code {udkProcess.ExitCode} while {operation}. " +
                "See UDKGame\\Logs\\Launch.log for its shutdown reason.");
        }

        /// <summary>Total load errors captured since injection. Monotonic - callers diff it
        /// around a LoadMap to find the ones that map load raised.</summary>
        private static int GetLoadErrorCount()
        {
            using var input = injector.MakeAllocation(16);
            using var output = injector.MakeAllocation(4);

            CallWithRetry("GetLoadErrorLogCount", input, output);
            return output.ReadInt32(0);
        }

        /// <summary>Fetches load error [index], where index is 0-based into the same sequence
        /// GetLoadErrorCount counts.</summary>
        private static LoadErrorEntry GetLoadErrorEntry(int index)
        {
            using var input = injector.MakeAllocation(16);
            using var output = injector.MakeAllocation(LoadErrorEntry.SizeBytes);

            input.WriteInt32(0, index);
            CallWithRetry("GetLoadErrorLogEntry", input, output);

            return new LoadErrorEntry
            {
                Found = output.ReadInt32(0) != 0,
                Type = output.ReadInt32(4),
                Desc = output.ReadStringUTF16(8, 256),
            };
        }

        /// <summary>
        /// GetLoadErrorLogCount/GetLoadErrorLogEntry are the only remaining exports that still go
        /// through a manufactured remote thread (they're called a handful of times per bake,
        /// right after LoadMap, not in a tight polling loop, so migrating them to the mailbox/RPM
        /// scheme wasn't worth the churn). Retry with backoff as a safety net against the same
        /// transient ERROR_ACCESS_DENIED that motivated moving everything else off remote threads.
        /// </summary>
        private static void CallWithRetry(string export, Allocation input, Allocation output, int maxAttempts = 5)
        {
            for (int attempt = 1; ; attempt++)
            {
                try
                {
                    injector.CallWithParams(module, export, input, output);
                    return;
                }
                catch (Win32Exception) when (attempt < maxAttempts)
                {
                    Thread.Sleep(TimeSpan.FromMilliseconds(200 * attempt));
                }
            }
        }

        /// <summary>Polls the agent until <paramref name="predicate"/> holds, or throws.</summary>
        private static void WaitUntil(Func<AgentStatus, bool> predicate, TimeSpan timeout, string label)
        {
            var deadline = DateTime.UtcNow + timeout;
            AgentStatus last = default;

            while (DateTime.UtcNow < deadline)
            {
                last = ReadStatus(label);
                if (predicate(last)) return;
                Thread.Sleep(PollInterval);
            }

            // The status only refreshes on an engine tick, so a UDK stuck in a modal dialog looks the
            // same as one still working. Name its windows so the cause is in the log.
            throw new TimeoutException($"{label} did not complete within {timeout} (last status: {last}; " +
                $"UDK windows: {UDKWindowProbe.Describe(udkPid)})");
        }

        /// <summary>
        /// <see cref="GetStatus"/>, reporting a UDK that has exited (crashed or killed) as such rather
        /// than as the raw ERROR_PARTIAL_COPY a read of its unmapped memory fails with.
        /// </summary>
        private static AgentStatus ReadStatus(string operation)
        {
            try
            {
                return GetStatus();
            }
            catch (Win32Exception ex) when (!IsUDKRunning())
            {
                throw new InvalidOperationException($"UDK (PID {udkPid}) exited while {operation}. " +
                    @"See UDKGame\Logs\Launch.log for how far it got.", ex);
            }
        }

        private static bool IsUDKRunning()
        {
            try
            {
                using var udk = Process.GetProcessById(udkPid);
                return !udk.HasExited;
            }
            catch (ArgumentException)
            {
                return false;
            }
        }

        /// <summary>Reads g_AgentStatus directly - refreshed every engine tick, no remote call.</summary>
        private static AgentStatus GetStatus() => new()
        {
            IsIdle = agentStatusView.ReadInt32(0) != 0,
            PendingActions = agentStatusView.ReadInt32(4),
            CompletedActions = agentStatusView.ReadInt32(8),
            SlowTaskDepth = agentStatusView.ReadInt32(12),
            IsDispatching = agentStatusView.ReadInt32(16) != 0,
            TicksRemaining = agentStatusView.ReadInt32(20),
            EngineTickCount = agentStatusView.ReadInt32(24),
            LoadErrorEvents = agentStatusView.ReadInt32(28),
        };

        #endregion
    }
}
