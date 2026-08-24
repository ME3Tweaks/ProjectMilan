using System.ComponentModel;
using System.Diagnostics;
using System.Text.RegularExpressions;
using UDKInj;
using LegendaryExplorerCore.GameFilesystem;

namespace ProjectMilan.Pipelines.StaticLighting
{
    /// <summary>
    /// Builds static lighting in UDK in an automated fashion. This process is VERY slow, should only really ever be used on final builds.
    /// </summary>
    public static class StaticLightingCompute
    {
        private const string LOG_CATEGORY = @"MILAN-StaticLightingCompute";

        private static Injector injector;
        private static FileInfo module;

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

        /// <summary>Package names (no extension) of every .udk under the content root - i.e.
        /// every package SaveMapFiles could possibly write. Built lazily since it walks the
        /// content tree; a real UDK content set is small enough for this to be cheap.</summary>
        private static HashSet<string> _mapPackageNames;

        /// <summary>
        /// Runs UDK and builds lighting, importing the results afterwards.
        /// </summary>
        /// <param name="mapName">The extensionless name of the map. Should already be in the UDK maps folder</param>
        internal static void ComputeLighting(string mapName)
        {
            var path = UDKDirectory.GetUDKGamePath();
            var userSettingsPath = Path.Combine(path, "Config", "UDKEditorUserSettings.ini");

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

            using var configOverride = new EditorConfigOverride(userSettingsPath, EditorConfigOverride.AutomationProfile);

            // Boot UDK.
            var udkInfo = new ProcessStartInfo()
            {
                FileName = UDKDirectory.GetExecutablePath(Program.Settings.MilanUDKPath),
                Arguments = $"editor {mapName}.udk -log",
            };

            MilanLog.Information("Starting UDK for lighting build", customPrefix: LOG_CATEGORY);
            var udkProcess = Process.Start(udkInfo);
            int udkPid = udkProcess.Id;

            try
            {
                // Once stable, we should bundle this into ProjectMilan.
                module ??= new FileInfo(@"B:\UserProfile\source\repos\ME3Tweaks\UdkInj\x64\Debug\UDKAgent.asi");

                // AttachWithRetry sets up `injector`. Deliberately not using ProcessHandle in a
                // `using` here -- disposing it disposes the Process object it wraps, which would
                // invalidate udkProcess before the finally block below can kill it by PID.
                AttachWithRetry(udkProcess, TimeSpan.FromMinutes(3));
                ResolveRemoteViews();

                WaitForUDKReady(TimeSpan.FromMinutes(10));
                MilanLog.Information("UDK is ready", customPrefix: LOG_CATEGORY);

                var mapPath = StaticLightingExport.GetMapOutputPath(mapName);
                var masterMap = Path.Combine(mapPath, $"{mapName}.udk");

                BakeLighting(masterMap, 1);

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
                }
                catch (ArgumentException) { /* already gone */ }
                catch (InvalidOperationException) { /* already gone */ }
                catch (Exception ex)
                {
                    MilanLog.Warning($"Could not stop UDK: {ex.Message}", customPrefix: LOG_CATEGORY);
                }
                // configOverride.Restore() runs via the `using` above, after UDK has exited.
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
        private static void BakeLighting(string masterMapPath, int qualityLevel)
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

            RunLightmass(qualityLevel);
            SaveMapFiles();
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

        private static void RunLightmass(int qualityLevel) =>
            RunAction(MailboxActionType.BuildLighting,
                input => input.WriteInt32(0, qualityLevel),
                // Production bakes on a big level can run for hours.
                timeout: TimeSpan.FromHours(12),
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
            var before = GetStatus();

            // Don't queue on top of something already running.
            if (!before.IsIdle)
                WaitUntil(s => s.IsIdle, TimeSpan.FromMinutes(5), $"agent idle before {label}");

            var completedBefore = GetStatus().CompletedActions;

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

        private static void WaitForUDKReady(TimeSpan timeout)
        {
            var deadline = DateTime.UtcNow + timeout;
            var lastReport = DateTime.UtcNow;

            while (DateTime.UtcNow < deadline)
            {
                if (IsUDKReady()) return;

                // Don't stall silently -- a wait with no visible state is what made the previous
                // readiness race so hard to tell apart from "UDK is just slow today".
                if (DateTime.UtcNow - lastReport > TimeSpan.FromSeconds(15))
                {
                    lastReport = DateTime.UtcNow;
                    MilanLog.Information($"  waiting for UDK... {GetStatus()}", customPrefix: LOG_CATEGORY);
                }

                Thread.Sleep(TimeSpan.FromSeconds(1));
            }

            throw new TimeoutException($"UDK was not ready within {timeout} (last status: {GetStatus()})");
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
        }

        private static bool IsUDKReady()
        {
            var status = GetStatus();
            return status.EngineTickCount >= 5 && status.SlowTaskDepth == 0;
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
                last = GetStatus();
                if (predicate(last)) return;
                Thread.Sleep(PollInterval);
            }

            throw new TimeoutException($"{label} did not complete within {timeout} (last status: {last})");
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
