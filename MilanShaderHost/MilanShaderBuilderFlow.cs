using LegendaryExplorerCore.Coalesced;
using LegendaryExplorerCore.Coalesced.Config;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using System.Diagnostics;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Misc.ME3Tweaks;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using MilanShaderHost.Old;
using ProjectMilanCore;

namespace MilanShaderHost
{
    /// <summary>
    /// Handles building packages running the game, starting the game, and waiting for it to exit, so it can process the next batch
    /// of shaders.
    /// </summary>
    internal class MilanShaderBuilderFlow
    {
        public static string DecookedPackagesPath = @"E:\Decooked";

        public static MEGame Game;

        /// <summary>
        /// Package the final shader cache will be saved into. Materials will be transferred into this as well once compiling is complete and then linked up.
        /// </summary>
        private static IMEPackage scPackage;

        /// <summary>
        /// A transient package that we copy assets into that are also copied into the level package. This package is where we pull data from to build the shader cache package result.
        /// </summary>
        private static IMEPackage transientPackage;

        /// <summary>
        /// The package object name the current package is being compiled under, and the name it must
        /// be restored to before anything is written back out. These differ only for a package the
        /// game loads at boot — see <see cref="CapturePackageNaming"/>. The rename exists purely to
        /// win the load; every artifact that leaves this process carries the original name.
        /// </summary>
        private static string currentSourceRoot = "";
        private static string currentCaptureRoot = "";

        /// <summary>
        /// The package object name to compile <paramref name="sourcePath"/> under. Every stage that
        /// needs this name — the port step, the debug-capture ownership filter, and the un-rename
        /// before save — derives it from here so they cannot drift apart.
        /// </summary>
        internal static string CaptureRootNameFor(string sourcePath)
            => Program.ParsedOptions is { NoAutoRename: true }
                ? Path.GetFileNameWithoutExtension(sourcePath)
                : CapturePackageNaming.CaptureRootName(sourcePath);

        /// <summary>
        /// Renames a result package's root package object back to the package's real name, undoing
        /// the capture rename. No-op when the package was not renamed.
        /// </summary>
        private static void RestoreSourceRootName(IMEPackage package)
        {
            if (currentCaptureRoot == currentSourceRoot) return;

            var renamedRoot = package.Exports.FirstOrDefault(x =>
                x.Parent == null && x.ObjectName.Instanced.Equals(currentCaptureRoot, StringComparison.Ordinal));
            if (renamedRoot == null)
            {
                // Nothing compiled under the renamed root, so there is nothing to undo. Saying so is
                // better than silently writing a package whose contents are not what was asked for.
                Console.WriteLine($"Note: no '{currentCaptureRoot}' package object in the result for {currentSourceRoot}; nothing to un-rename.");
                return;
            }

            renamedRoot.ObjectName = currentSourceRoot;
            Console.WriteLine($"Restored package object name '{currentCaptureRoot}' -> '{currentSourceRoot}' before saving.");
        }

        /// <summary>
        /// Terrain shader compilation is a rebuild, rather than an incremental merge with the
        /// source package's cache. Tracks which output terrains have had their old caches removed
        /// for the current package so every subsequently returned mask can accumulate normally.
        /// </summary>
        private static readonly HashSet<string> resetTerrainCaches = new(StringComparer.OrdinalIgnoreCase);

        // ShaderClient sends failures independently from material-resource payloads. Do not replace
        // an input package in writeback mode unless its whole in-game compile session completed and
        // actually yielded at least one resource to merge.
        private static volatile bool currentCompileSessionFailed;
        private static int mergedCompileResourceCount;

        /// <summary>
        /// Material resource names merged during the current package's compile, used only to detect
        /// a name arriving twice.
        /// </summary>
        /// <remarks>
        /// This is a tripwire for one specific hazard. A MaterialInstance permutation is expected to
        /// arrive named <c>&lt;parent&gt;#&lt;hash&gt;</c>, which routes to MergeInstancePermutation. If the
        /// ASI ever sends a permutation's resource under the parent's *plain* name instead, it is
        /// indistinguishable from the parent's own resource and would overwrite it -- silently
        /// corrupting the parent material, with no error anywhere.
        ///
        /// A repeated name is the symptom, but it is not proof: the engine also compiles the same base
        /// material more than once within a package quite legitimately, and each of those merges writes
        /// the same material's own resource, so the overwrite is harmless. That is what the first real
        /// writeback run showed -- BioT_CitCasino on 2026-09-20 hit this five times, all base-material
        /// recompiles, none of them permutations. So report it as something to check, not as damage.
        /// </remarks>
        private static readonly HashSet<string> mergedMaterialNamesThisPackage = new(StringComparer.OrdinalIgnoreCase);

        internal static void MarkCompileFailure(string errorMessage)
        {
            currentCompileSessionFailed = true;
            Console.Error.WriteLine($"ShaderClient reported a compile failure for {currentSourceRoot}; output replacement is disabled for this package: {errorMessage}");
        }

        public static void KillGame()
        {
            // Kill existing game processes.
            foreach (var exeName in MEDirectories.ExecutableNames(Program.Game))
            {
                foreach (var exe in Process.GetProcessesByName(Path.GetFileNameWithoutExtension(exeName)))
                {
                    Console.WriteLine($"Killing process {exe.Id} {exe.ProcessName}");
                    exe.Kill();
                }
            }
        }



        /// <summary>
        /// Starts the game start/stop loop for the shader host.
        /// </summary>
        public static void StartFlow()
        {
            Game = MEGame.LE3;
            if (!string.IsNullOrWhiteSpace(Program.ParsedOptions?.CaptureRoot))
            {
                DecookedPackagesPath = Path.GetFullPath(Program.ParsedOptions.CaptureRoot);
            }
            var path = Path.Combine(DecookedPackagesPath, Game.ToString());
            
            // Donor imports are resolved by walking SourceFolders in order and taking the first
            // folder that holds a package of the matching name. 96 package names exist in both the
            // LE1 and LE3 decooked sets (BioEngineMaterials, BioBaseResources, ...), so the folder
            // for the game actually being compiled has to come first or a capture silently picks up
            // the other game's materials.
            var explicitSourceFolders = Program.ParsedOptions?.SourceFolders?.ToList() ?? [];
            if (explicitSourceFolders.Count > 0)
            {
                foreach (var folder in explicitSourceFolders)
                {
                    MilanShaderPackageBuilder.SourceFolders.Add(Path.GetFullPath(folder));
                }
            }
            else
            {
                // LE3 decooked data only. Pass --sourcefolder to compile from another game's
                // decooked set (LE1 -> LE3, ME3 -> LE3); do not add one here alongside this, or
                // whichever is listed first wins for every package name the two sets share.
                MilanShaderPackageBuilder.SourceFolders.Add(path);
            }

            // Dump HLSL for package
            if (Program.ParsedOptions.DumpHLSL)
            {
                SetupHLSLDumpFlow();
            }

            // Compile in-game
            if (Program.ParsedOptions.CompileShaders || Program.ParsedOptions.PreviewShaders)
            {
                SetupShaderCompileFlow();
            }
        }

        static void SetupHLSLDumpFlow()
        {
            // Check that the ShaderClient is installed
            // If it isn't installed the game simply crashes out on startup.

            foreach (var folder in MilanShaderPackageBuilder.SourceFolders)
            {
                var files = Directory.GetFiles(folder);
                files.Sort();
                foreach (var file in files)
                {
                    if (!file.RepresentsPackageFilePath())
                    {
                        continue;
                    }

                    // Check output folder
                    var outFiles = Directory.EnumerateFiles("Z:\\Decooked\\HLSL\\LE3");
                    if (outFiles.Any(x => Path.GetFileNameWithoutExtension(x).StartsWith(Path.GetFileNameWithoutExtension(file), StringComparison.OrdinalIgnoreCase)))
                    {
                        Console.WriteLine($"Already dumped HLSL for package {Path.GetFileNameWithoutExtension(file)}, skipping.");
                        continue;
                    }


                    // Builds materials into the map
                    if (SetupShaderLevel(file, EShaderLevelMode.Compile) == null)
                    {
                        Console.WriteLine($"Skipping package {Path.GetFileNameWithoutExtension(file)}");
                        continue;
                    }

                    Console.WriteLine($"Dumping HLSL for package {Path.GetFileNameWithoutExtension(file)}");

                    // Runs game, which builds shaders and feeds them back to us.
                    StartGameAndWaitForExit(EShaderLevelMode.Compile, Path.GetFileNameWithoutExtension(file), IsLE1SourcePackage(file));

                    // Once game exits, ShaderHost should have received the shader cache, and our OnShaderCacheUpdated() event should have triggered.
                    Console.WriteLine($"  Finished dumping HLSL for {Path.GetFileNameWithoutExtension(file)}");

                    // Thread.Sleep(100000000);
                }
            }
        }

        /// <summary>
        /// Holds an in-memory prepared level ready to be saved for the next game run.
        /// </summary>
        private sealed class PreparedLevel
        {
            public required IMEPackage TransientPackage { get; init; }
            public required IMEPackage MapPackage { get; init; }
            public required bool IsLE1SourcePackage { get; init; }
        }

        /// <summary>
        /// Exit code ShaderClient uses when it terminates the game itself once the load screen comes
        /// down, having already written every payload to the pipe. Must match k_shaderClientExitCode
        /// in LExASIs/ShaderClient/Hooks.hpp.
        /// </summary>
        private const int ShaderClientExitCode = 0x4D49;

        /// <summary>
        /// Exit code ShaderClient's idle backstop uses when the load screen never came down. Must
        /// match k_shaderClientIdleExitCode in the same header.
        /// </summary>
        private const int ShaderClientIdleExitCode = 0x4D57;

        /// <summary>
        /// Annotates the raw exit code so a deliberate kill is not mistaken for a crash, and so a
        /// plain 0 is not mistaken for the fast path having worked.
        /// </summary>
        private static string DescribeGameExitCode(int exitCode) => exitCode switch
        {
            ShaderClientExitCode => " (ShaderClient exited at the load screen -- expected)",
            ShaderClientIdleExitCode => " (ShaderClient idle backstop fired: the load screen never came down, so this compile likely wedged)",
            0 => " (game exited through its own returntolauncher path; the ShaderClient fast exit did not fire)",
            _ => " (unexpected -- 0xC0000005 here means the game crashed)"
        };

        private static bool IsLE1SourcePackage(string sourcePath)
        {
            using var sourcePackage = MEPackageHandler.UnsafePartialLoad(sourcePath, x => false);
            return sourcePackage.Game == MEGame.LE1;
        }

        /// <summary>
        /// Builds the shader level package entirely in memory without saving to disk or touching
        /// any instance fields, so it can safely run on a background thread while the game is running.
        /// Returns null if the source package contains no materials.
        /// </summary>
        private static PreparedLevel? BuildShaderLevelInMemory(string sourcePath, EShaderLevelMode buildMode)
        {
            var isLE1SourcePackage = false;
            if (buildMode != EShaderLevelMode.SlashLevel)
            {
                using var sp = MEPackageHandler.UnsafePartialLoad(sourcePath, x => false);
                isLE1SourcePackage = sp.Game == MEGame.LE1;
                if (!string.IsNullOrWhiteSpace(Program.ParsedOptions.TerrainPackagePath) && sp.Game != MEGame.LE3)
                {
                    throw new InvalidOperationException($"--terrain requires an LE3 package; '{sourcePath}' is {sp.Game}.");
                }
                // Once we get normal materials working we can work on making this accept MaterialInstances.
                // Then we can pre-bake the bHasStaticPermutation version.
                var hasCompilableTerrain = sp.Exports.Any(x => x.IsA("Terrain"));
                if (!string.IsNullOrWhiteSpace(Program.ParsedOptions.TerrainPackagePath) && !hasCompilableTerrain)
                {
                    throw new InvalidOperationException($"Terrain package '{sourcePath}' contains no Terrain exports.");
                }

                // A package can carry MaterialInstanceConstants whose parents are imported from
                // elsewhere, so it has permutations to compile without owning a single Material
                // export. Checking only for Material silently skipped those.
                // Class name only. `sp` is an UnsafePartialLoad with an x => false predicate, so no
                // export has its data loaded and GetProperty throws on every one of them -- which is
                // why the Material check above is also class-only. Whether an instance actually owns a
                // permutation is settled in BuildMapPackage, where the package is fully loaded; at
                // worst this lets a package through that turns out to have nothing to compile.
                var hasCompilableInstances = !Program.ParsedOptions.NoInstances
                    && sp.Exports.Any(x => x.IsA("MaterialInstance"));

                if (sp.Exports.Count(x => x.IsA("Material")) == 0 && !hasCompilableTerrain && !hasCompilableInstances)
                {
                    // Nothing to compile
                    return null;
                }
            }

            var mapName = GetMapName(buildMode) + ".pcc";

            var localTransient = MEPackageHandler.CreateMemoryEmptyPackage("Transient.pcc", Program.Game);
            var package = MilanShaderPackageBuilder.BuildMapPackage(mapName, sourcePath, localTransient, buildMode);
            if (buildMode == EShaderLevelMode.Preview)
            {
                Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Copying source shader cache into preview level.");
                // Copy SeekFreeShaderCache
                using var tPackage = MEPackageHandler.OpenMEPackage(sourcePath);
                var cache = tPackage.FindExport("SeekFreeShaderCache");
                EntryExporter.ExportExportToPackage(cache, package, out var cacheExport);
            }
            else if (buildMode == EShaderLevelMode.Compile)
            {
                Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Installing automatic shader-compile exit sequence.");
                // Install auto exit sequence
                var flowPackagePath = $"EntryMenu/entry_{Program.Game}.pcc"; // copied to output path by compile step.
                var flowPackage = MEPackageHandler.OpenMEPackage(flowPackagePath);
                var seq = flowPackage.FindExport("ShaderCompilerSequence");
                EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, seq, package, package.GetLevel(), true, new RelinkerOptionsPackage(), out var portedSeq);
                var level = package.GetLevelBinary();
                level.GameSequences = [portedSeq.UIndex];
                package.GetLevel().WriteBinary(level);
            }

            // Remove unused mips
            if (true)
            {
                var textures = package.Exports.Where(x => x.IsTexture()).ToList();
                Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Removing empty mips from {textures.Count:N0} compiler-level texture(s).");
                foreach (var tex in textures)
                {
                    var t2d = (UTexture2D)ObjectBinary.From(tex);
                    t2d.Mips.RemoveAll(x => x.StorageType == StorageTypes.empty); // Remove empty mips
                    tex.WriteBinary(t2d);

                    /*if (numRemoved > 0)
                    {
                        Console.WriteLine($"Removed {numRemoved} empty mips from {tex.InstancedFullPath}");
                        tex.WriteBinary(bin);
                    }*/
                }
            }

            Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Compiler level prepared in memory ({package.Exports.Count:N0} exports).");
            return new PreparedLevel { TransientPackage = localTransient, MapPackage = package, IsLE1SourcePackage = isLE1SourcePackage };
        }

        /// <summary>
        /// Starts preparing the compiler levels of every file in <paramref name="files"/> named in
        /// <see cref="ShaderCompileList.LongPreparePackages"/>, so they are ready (or close to it) by
        /// the time the compile loop reaches them instead of stalling it with the game idle.
        /// </summary>
        /// <remarks>
        /// One dedicated worker prepares them one at a time in list order, each held in memory until
        /// its turn: preparing them all at once would hold several large levels and compete with the
        /// one-ahead prefetch for CPU. The first file is skipped, since the loop builds it immediately
        /// anyway. A faulted prepare does not stop the ones after it; its exception surfaces when the
        /// loop reaches that file, as a failed one-ahead prefetch would.
        /// </remarks>
        /// <returns>The pending prepares, keyed by file path.</returns>
        private static Dictionary<string, Task<PreparedLevel?>> StartLongPrepares(List<string> files)
        {
            var prepares = new Dictionary<string, Task<PreparedLevel?>>(StringComparer.OrdinalIgnoreCase);

            // Builds resolve textures through this lazily filled, unlocked cache; fill it here, before
            // two builds can race to.
            MELoadedFiles.GetFilesLoadedInGame(Program.Game);

            Task previous = Task.CompletedTask;
            foreach (var file in files.Skip(1).Where(x => ShaderCompileList.LongPreparePackages.Contains(Path.GetFileNameWithoutExtension(x))))
            {
                Console.WriteLine($"Preparing long-running package {Path.GetFileNameWithoutExtension(file)} in the background (position {files.IndexOf(file) + 1} of {files.Count}).");
                var prepare = previous.ContinueWith(_ =>
                {
                    Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Background prepare started: {Path.GetFileNameWithoutExtension(file)}");
                    var prepared = BuildShaderLevelInMemory(file, EShaderLevelMode.Compile);
                    Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Background prepare finished: {Path.GetFileNameWithoutExtension(file)}");
                    return prepared;
                }, CancellationToken.None, TaskContinuationOptions.LongRunning, TaskScheduler.Default);
                prepares[file] = prepare;
                previous = prepare;
            }
            return prepares;
        }

        static void SetupShaderCompileFlow()
        {
            var outDir = string.IsNullOrWhiteSpace(Program.ParsedOptions.CompiledOutputFolder)
                ? @"E:\CompiledShaderPackages" : Path.GetFullPath(Program.ParsedOptions.CompiledOutputFolder);
            Directory.CreateDirectory(outDir);

            KillGame();
            ShaderCompileList.SetupFileList();
            ShaderHost.NewShaderCacheGenerated += OnMaterialCompiled;

            if (Program.ParsedOptions.SlashRefShaderCache && !ShaderCacheTools.IsCacheSlashed(Program.Game))
            {
                Console.WriteLine($"Slashing shader cache for {Program.Game} before compiling");

                // Build slash level first
                var slashPath = SetupShaderLevel(null, EShaderLevelMode.SlashLevel);

                ShaderCacheTools.SlashShaderCache(Program.Game);
            }

            if (Program.Game == MEGame.LE3)
            {
                // Commented out - it breaks BaseDelta install MilanBaseInstaller
                // Ensure SFXOnlineFoundation has Telemetry removed as it significantly slows down compile on game close.
                //var sfxOnlineFoundation = MEPackageHandler.OpenMEPackage(Path.Combine(LE3Directory.CookedPCPath, "SFXOnlineFoundation.pcc"));
                //var onlineSubsystem = sfxOnlineFoundation.FindExport("Default__SFXOnlineSubsystem");
                //var componentsList = onlineSubsystem.GetProperty<ArrayProperty<StructProperty>>("ComponentClassList");
                //var removed = componentsList.RemoveAll(x =>
                //{
                //    var className = x.GetProp<ObjectProperty>("ClassName");
                //    var resolved = sfxOnlineFoundation.GetEntry(className.Value);
                //    return resolved.ObjectName == "SFXOnlineCOmponentTelemetrySystem";
                //});
                //if (removed)
                //{
                //    onlineSubsystem.WriteProperty(componentsList);
                //    sfxOnlineFoundation.Save();
                //    Console.WriteLine("Patched out telemetry subsystem to improve shader compiling performance");
                //}
            }

            var files = ShaderCompileList.PackageFilesToProcess;

            // The one-ahead prefetch below, and the file it is for. It is not always files[i + 1]:
            // a file the long-prepare worker owns is skipped over.
            Task<PreparedLevel?>? nextLevelTask = null;
            string? nextLevelFile = null;
            var longPrepares = Program.ParsedOptions.CompileShaders ? StartLongPrepares(files) : new();

            // Packages whose compile session produced nothing. A package can run to completion with
            // the game exiting 0 and still capture zero jobs, and every per-package signal looks
            // like success when it does, so collect them and say so loudly at the end rather than
            // leaving a silent empty result.
            //
            // The known cause -- the object name already belonging to a package the game loaded at
            // boot -- is now handled automatically by the capture rename (CapturePackageNaming), so
            // anything that still lands here is either a package run with --noautorename or a cause
            // we have not identified yet. Either way it is worth stopping for.
            var producedNothing = new List<string>();
            var reportedFailure = new List<string>();

            for (int i = 0; i < files.Count; i++)
            {
                var file = files[i];
                var baseName = Path.GetFileNameWithoutExtension(file);
                /*if (!baseName.Equals("BIOG_PhotoModeFilters", StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }*/
                var outPath = Path.Combine(outDir, baseName + ".pcc");

                // Set before the game starts: the pipe thread reads these while it runs.
                currentSourceRoot = baseName;
                currentCaptureRoot = CaptureRootNameFor(file);

                if (Program.ParsedOptions.CompileShaders) // Shader compile
                {
                    Console.WriteLine($"Building shaders for: {baseName}");
                    var outputGame = MilanLicensee.GetGame(file);
                    if (Program.ParsedOptions.WriteBack)
                    {
                        if (outputGame == MEGame.LMP)
                        {
                            // Temporarily change to LE3
                            MilanLicensee.SetGame(file, MEGame.LE3);
                        }
                        scPackage = MEPackageHandler.OpenMEPackage(file);
                        if (scPackage.Game != Program.Game)
                        {
                            throw new InvalidOperationException($"--writeback only supports {Program.Game} input packages; '{file}' is {scPackage.Game}.");
                        }

                        // Writeback keeps the original authored exports instead of re-exporting the
                        // transient compile graph. Persist the same material invariant here too:
                        // an otherwise correctly compiled foliage material would still be rejected
                        // by LE3's runtime static-lighting usage check if this remained false.
                        MilanShaderPackageBuilder.EnableStaticLightingForAllMaterials(scPackage);

                        Console.WriteLine($"Writeback enabled: compiled resources will be saved into {file}");
                    }
                    else
                    {
                        scPackage = MEPackageHandler.CreateMemoryEmptyPackage(Path.GetFileName(file), Program.Game);
                    }

                    scPackage.CreateShaderCache();
                    resetTerrainCaches.Clear();
                    currentCompileSessionFailed = false;
                    Interlocked.Exchange(ref mergedCompileResourceCount, 0);
                    lock (mergedMaterialNamesThisPackage) mergedMaterialNamesThisPackage.Clear();

                    // Use a level prepared in the background if there is one, otherwise build now
                    PreparedLevel? current;
                    if (longPrepares.Remove(file, out var longPrepare))
                    {
                        if (!longPrepare.IsCompleted)
                        {
                            Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Waiting for the background prepare of {baseName} to finish.");
                        }
                        current = longPrepare.GetAwaiter().GetResult();
                    }
                    else if (nextLevelTask != null && nextLevelFile == file)
                    {
                        current = nextLevelTask.GetAwaiter().GetResult();
                        nextLevelTask = null;
                        nextLevelFile = null;
                    }
                    else
                    {
                        current = BuildShaderLevelInMemory(file, EShaderLevelMode.Compile);
                    }

                    if (current == null)
                    {
                        Console.WriteLine($"Skipping {baseName}: no materials to compile.");
                        continue;
                    }

                    // Apply the prepared level: set instance state and save to disk
                    transientPackage = current.TransientPackage;
                    var outGameDir = @"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\ME3\BioGame\CookedPCConsole";
                    var compilerMapPath = Path.Combine(outGameDir, GetMapName(EShaderLevelMode.Compile) + ".pcc");
                    Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Saving compiler map ({current.MapPackage.Exports.Count:N0} exports) to {compilerMapPath}.");
                    var saveTimer = Stopwatch.StartNew();
                    current.MapPackage.Save(compilerMapPath);
                    Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Saved compiler map in {saveTimer.Elapsed.TotalSeconds:F1}s.");

                    // While the game runs, prepare the next file in the background -- the next one
                    // the long-prepare worker isn't already handling. If a prefetch is still in
                    // flight (this iteration consumed a long prepare), it is already that file.
                    if (nextLevelTask == null)
                    {
                        var nextFile = files.Skip(i + 1).FirstOrDefault(x => !longPrepares.ContainsKey(x));
                        if (nextFile != null)
                        {
                            Console.WriteLine($"Pre-preparing level for: {Path.GetFileNameWithoutExtension(nextFile)}");
                            nextLevelFile = nextFile;
                            nextLevelTask = Task.Run(() => BuildShaderLevelInMemory(nextFile, EShaderLevelMode.Compile));
                        }
                    }

                    // Runs game, which builds shaders and feeds them back to us. The capture root is
                    // what ShaderClient will report every material under, so it is also what the
                    // capture's ownership filter has to be keyed on -- passing baseName here would
                    // make a renamed package's own payloads look foreign and discard all of them.
                    StartGameAndWaitForExit(EShaderLevelMode.Compile, currentCaptureRoot, current.IsLE1SourcePackage,
                        progressDone: i + 1, progressTotal: files.Count, currentPackage: baseName);

                    if (Program.ParsedOptions.WriteBack)
                    {
                        if (currentCompileSessionFailed || Volatile.Read(ref mergedCompileResourceCount) == 0)
                        {
                            throw new InvalidOperationException($"Refusing to write back '{file}': " +
                                (currentCompileSessionFailed
                                    ? "ShaderClient reported at least one compilation failure."
                                    : "ShaderClient returned no material or terrain resources."));
                        }

                        BootResidentMaterials.RestoreNames(scPackage);
                        ReportBrokenMaterials(scPackage, file);
                        scPackage.Save(file);
                        MilanLicensee.SetGame(file, outputGame);
                        Console.WriteLine($"Wrote {Volatile.Read(ref mergedCompileResourceCount)} compiled resource(s) and shader cache back to {file}");
                    }
                    else if (currentCompileSessionFailed || Volatile.Read(ref mergedCompileResourceCount) == 0)
                    {
                        // A failed or empty compile session must never overwrite a prior good result:
                        // scPackage here is a bare in-memory package (just SeekFreeShaderCache, no
                        // materials), and saving it over an existing outPath silently destroys whatever
                        // compiled resources that file already held. --writeback already refuses this
                        // above; the default output path needs the identical guard.
                        // A capture-only run's product is the debug payloads, not merged compile
                        // resources -- those can be zero while the capture itself is complete, so
                        // judging the run by the merge count alone reports false failures.
                        var capturedPayloads = ShaderHost.LastCaptureRetainedPayloadCount;
                        var captureOnly = Program.ParsedOptions.CaptureOnly;

                        if (currentCompileSessionFailed) reportedFailure.Add(baseName);
                        else if (!captureOnly || capturedPayloads == 0) producedNothing.Add(baseName);

                        if (currentCompileSessionFailed)
                        {
                            Console.WriteLine($"*** NO OUTPUT for '{baseName}': ShaderClient reported at least one compilation failure." +
                                (File.Exists(outPath) ? $" Leaving existing {outPath} untouched." : ""));
                        }
                        else if (captureOnly && capturedPayloads > 0)
                        {
                            Console.WriteLine($"No compiled resources merged for '{baseName}', but the capture retained " +
                                $"{capturedPayloads:N0} debug payload(s) -- expected for --captureonly.");
                        }
                        else
                        {
                            // Only claim a boot-package collision when this package is actually one.
                            //
                            // The unconditional version of this cost an evening on 2026-09-21:
                            // BioVFX_MP4_Tur_Jets produced nothing and was reported as "the game's own
                            // copy of these objects likely loaded first", for a package LE3 does not
                            // contain at all -- it exists only in ME3's DLC_CON_MP4. The real cause was
                            // in ShaderClient's own log: its single material failed to compile because
                            // two TextureSample nodes had no texture, so there was nothing to send.
                            // A guess stated as a cause is worse than no cause at all, because it is
                            // the one thing the reader stops looking past.
                            //
                            // "Never asked for" is also a legitimate outcome, not only a failure:
                            // BioApl_Ind_Mining_Drill03's only content is a MIC parented to
                            // BIOG_APL_MASTER_MATERIAL.Placeable_MM, which LE3 ships in SFXGame. The engine
                            // keys the permutation by the live (SFXGame) parent's resource ID, finds it in
                            // RefShaderCache, and compiles nothing (2026-09-23).
                            var collisionHint = currentCaptureRoot != currentSourceRoot
                                ? $" This ran under the capture rename ('{currentCaptureRoot}'), so a boot-package collision is not the explanation."
                                : CapturePackageNaming.RequiresRename(baseName)
                                    ? " This package is loaded by the game at boot and the capture rename was disabled (--noautorename), so the game's copy won the load."
                                    : " This package is not one the game loads at boot, so a name collision is NOT the explanation:" +
                                      " every material in it either failed to compile, or the game already had its shader map and" +
                                      " never asked for one. The second is not a fault: typically an instance whose parent ships" +
                                      " in LE3, whose permutation is already in RefShaderCache.";

                            // ShaderClient writes its log relative to the game process's working
                            // directory, which it inherits from this host -- not into the game folder,
                            // where it is natural to look for it and where a stale copy may sit.
                            var shaderClientLog = Path.Combine(AppContext.BaseDirectory, "Logs", "ShaderClient.log");
                            // Compile failures are logged at error level, which ShaderClient flushes
                            // immediately. Info lines are flushed every 5s and the process is killed at
                            // the load screen, so a log that ends early does not mean the game stopped.
                            var logHint = File.Exists(shaderClientLog)
                                ? $" ShaderClient's own log records per-material compile failures (its info lines may be cut short by the exit): {shaderClientLog}"
                                : " Check ShaderClient's log for per-material compile failures.";

                            Console.WriteLine($"*** NO OUTPUT for '{baseName}': ShaderClient returned no material or terrain " +
                                "resources and captured no debug payloads." + collisionHint + logHint +
                                (File.Exists(outPath) ? $" Leaving existing {outPath} untouched." : ""));
                        }
                    }
                    else
                    {
                        // The rename exists only to win the load inside the game. The compiled
                        // package that leaves this process must carry the real name, or it is not a
                        // drop-in replacement for the package it was built from.
                        RestoreSourceRootName(scPackage);
                        BootResidentMaterials.RestoreNames(scPackage);
                        ReportBrokenMaterials(scPackage, outPath);
                        scPackage.Save(outPath);
                    }

                }

                // Once game exits, ShaderHost should have received the shader cache, and our OnShaderCacheUpdated() event should have triggered.
                Console.WriteLine($"Finished compiling shaders for {Path.GetFileNameWithoutExtension(file)}");

                // Preview shader level.
                if (Program.ParsedOptions.PreviewShaders)
                {
                    Console.WriteLine($"Generating preview level for {baseName}'s shaders");
                    var shaderPreviewLevelPath = SetupShaderLevel(outPath, EShaderLevelMode.Preview);
                    if (Program.ParsedOptions.OutputPathForResults != null)
                    {
                        var savePath = Path.Combine(Program.ParsedOptions.OutputPathForResults, $"shaderpreview_{baseName}.pcc");
                        Console.WriteLine($"Saving preview level to {savePath}");
                        File.Copy(shaderPreviewLevelPath, savePath, true);
                    }
                    StartGameAndWaitForExit(EShaderLevelMode.Preview, baseName,
                        progressDone: i + 1, progressTotal: files.Count);
                }
            }


            // A run is not "complete" in any useful sense if packages captured nothing. Report that
            // before the success line, and exit non-zero, so a batch run cannot pass an audit that
            // only checks the trailing message and the exit code.
            if (producedNothing.Count > 0 || reportedFailure.Count > 0)
            {
                Console.WriteLine();
                Console.WriteLine($"*** {producedNothing.Count + reportedFailure.Count} of {files.Count} package(s) produced NO output:");
                foreach (var p in reportedFailure)
                {
                    Console.WriteLine($"      {p}  (compilation failure reported)");
                }
                foreach (var p in producedNothing)
                {
                    Console.WriteLine($"      {p}  (no resources -- see its NO OUTPUT line above for the likely cause)");
                }
                Console.WriteLine();
                Console.WriteLine($"Shader compiling finished with {producedNothing.Count + reportedFailure.Count} empty package(s).");
                Environment.Exit(2);
            }

            Console.WriteLine($"Shader compiling complete.");
            Environment.Exit(0);
        }

#if OLD
        private static void SetupEntry(string sourcePath, bool buildWithMeshes)
        {
            // Have to figure this out for LE2 as it doesn't have entry map.
            var inPath = Path.Combine(ME3TweaksBackups.GetGameBackupPath(Program.Game), "BioGame", "CookedPCConsole", "entry.pcc");
            var outPath = Path.Combine(MEDirectories.GetCookedPath(Program.Game), "entry.pcc");
            transientPackage = MEPackageHandler.CreateMemoryEmptyPackage("Transient.pcc", Program.Game);
            var package = MilanShaderPackageBuilder.BuildIntoExistingPackage(inPath, sourcePath, transientPackage, buildWithMeshes);
            if (buildWithMeshes)
            {
                // Copy SeekFreeShaderCache
                using var tPackage = MEPackageHandler.OpenMEPackage(sourcePath);
                var cache = tPackage.FindExport("SeekFreeShaderCache");
                EntryExporter.ExportExportToPackage(cache, package, out var cacheExport);
            }

            package.Save(outPath);
            return;

            var level = package.GetLevelBinary();
            if (level.GameSequences.Length == 1 && level.GameSequences[0] == 0)
            {
                Console.WriteLine($"Setting up entry.pcc for automated shader compiling.");
                // Install our sequence
                var flowPackagePath = $"EntryMenu/entry_{Program.Game}.pcc"; // copied to output path by compile step.
                var flowPackage = MEPackageHandler.OpenMEPackage(flowPackagePath);
                var seq = flowPackage.FindExport("ShaderCompilerSequence");
                EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, seq, package, package.GetLevel(), true, new RelinkerOptionsPackage(), out var portedSeq);
                level.GameSequences = [portedSeq.UIndex];
                package.GetLevel().WriteBinary(level);
                package.Save(outPath);
            }
        }
#endif
        private static string SetupShaderLevel(string sourcePath, EShaderLevelMode buildMode)
        {
            var prepared = BuildShaderLevelInMemory(sourcePath, buildMode);
            if (prepared == null)
                return null;

            transientPackage = prepared.TransientPackage;
            var outDir = @"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\ME3\BioGame\CookedPCConsole";
            var mapName = GetMapName(buildMode) + ".pcc";
            var finalOut = Path.Combine(outDir, mapName);
            Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Saving compiler map ({prepared.MapPackage.Exports.Count:N0} exports) to {finalOut}.");
            var saveTimer = Stopwatch.StartNew();
            prepared.MapPackage.Save(finalOut);
            Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Saved compiler map in {saveTimer.Elapsed.TotalSeconds:F1}s.");
            return finalOut;
        }

        private static void OnMaterialCompiled(object? sender, CompileResult cr)
        {
            // Merge the shader cache first and unconditionally: it's a generic, key-based store (keyed by
            // FStaticParameterSet / shader Guid, not by which export owns it), so it's valid to merge in
            // even when we can't yet find or build the specific export the resource metadata belongs to
            // below. Doing this before the "no matching export" early-outs means the actual compiled
            // shader bytecode is never silently discarded, terrain included.
            Console.WriteLine($"Merging shader cache for {cr.MaterialName}");
            var cache = scPackage.FindExport("SeekFreeShaderCache");
            ObjectBinary.EditBinary<ShaderCache>(cache, (x) =>
            {
                cr.Cache.MergeInto(x);
            });

            if (cr.IsTerrainResource)
            {
                MergeTerrainMaterialResource(cr);
                return;
            }

            // A MaterialInstance permutation arrives named <parent path>#<static parameter set hash>,
            // because the resource it was compiled through points at the *parent* UMaterial and the
            // key is the only thing distinguishing one instance's permutation from another's. It has
            // to be handled before the Material path below: that path resolves the name to an export
            // and overwrites SM3MaterialResource, so a permutation falling through it would either
            // resolve to nothing, or -- if the name ever arrives unsuffixed -- overwrite the parent
            // material's own compiled resource with the instance's. See MergeInstancePermutation.
            var (permutationBasePath, permutationKey) = StaticPermutationNaming.Split(cr.MaterialName);
            if (permutationKey != null)
            {
                MergeInstancePermutation(cr, permutationBasePath, permutationKey);
                return;
            }

            // Merge material into the package.
            var matchingMat = transientPackage.FindExport(cr.MaterialName);
            // FindExport returns null when the name does not resolve at all, so the null check has
            // to happen here and not just at the "no matching material" early-out below -- the pipe
            // reader runs on one thread, so an exception here kills the host and every debug package
            // that would have followed.
            if (matchingMat == null || !matchingMat.IsA("Material"))
            {
                // Bad naming...
                matchingMat = transientPackage.Exports.FirstOrDefault(x => x.InstancedFullPath == cr.MaterialName && x.IsA("Material"));
            }

            if (matchingMat == null)
            {
                Console.WriteLine($"No matching material found for {cr.MaterialName} in transient package. Skipping.");
                return;
            }

            Console.WriteLine($"Serializing material resource {cr.MaterialName}");

            ExportEntry matExp;
            if (Program.ParsedOptions.WriteBack)
            {
                // In writeback mode scPackage is the original input file. Keep its existing
                // material export and replace only the freshly compiled resource below; exporting
                // the transient material would duplicate authored graph exports in the source.
                //
                // The input file on disk was never renamed -- only the in-memory copy the compiler
                // level was built from -- so a renamed capture has to be matched by the original
                // path or nothing here resolves.
                var writebackPath = CapturePackageNaming.DeRenameInstancedPath(
                                        matchingMat.InstancedFullPath, currentCaptureRoot, currentSourceRoot)
                                    ?? matchingMat.InstancedFullPath;
                matExp = scPackage.Exports.FirstOrDefault(x => x.IsA("Material")
                    && x.InstancedFullPath.Equals(writebackPath, StringComparison.OrdinalIgnoreCase))
                    ?? throw new InvalidOperationException($"Could not find source material '{writebackPath}' for writeback in {scPackage.FileNameNoExtension}.");
            }
            else
            {
                // Export matching material from transient package to final compiled package.
                EntryExporter.ExportExportToPackage(matchingMat, scPackage, out var pMat);
                matExp = (ExportEntry)pMat;
            }

            // Replace the final package material resource with the one we got from the game.
            var ms = new MemoryStream(cr.MaterialResource);
            var matSerializer = new PackagelessWithObjectsSerializingContainer(ms, scPackage, true);
            matSerializer.SetGame(transientPackage.Game);
            var sm3r = new MaterialResource();
            matSerializer.Serialize(ref sm3r);

            // Also need to copy in the binary for the material resource. Not sure how to do that.
            ObjectBinary.EditBinary<Material>(matExp, (x) =>
            {
                x.SM3MaterialResource = sm3r;
            });

            // We need to link up the guids.
            Interlocked.Increment(ref mergedCompileResourceCount);

            bool firstTime;
            lock (mergedMaterialNamesThisPackage) firstTime = mergedMaterialNamesThisPackage.Add(cr.MaterialName);
            if (!firstTime)
            {
                // See mergedMaterialNamesThisPackage. Usually benign -- the same base material
                // compiled twice writes its own resource both times. Only harmful in the case this
                // watches for: an instance permutation that lost its key, whose resource would then
                // land on the parent.
                Console.WriteLine($"NOTE: material resource '{cr.MaterialName}' merged more than once for this package; " +
                                  "the later merge overwrote the earlier one. Expected for a base material compiled " +
                                  "more than once. If this name belongs to an instance permutation that arrived without " +
                                  "its '#' key, the parent material's resource is now the instance's -- check before shipping.");
            }

            Console.WriteLine($"Merged {cr.MaterialName} into " +
                              (Program.ParsedOptions.WriteBack ? "the input package" : "the result package"));
        }

        /// <summary>
        /// Merges one compiled MaterialInstance static permutation into the result package.
        ///
        /// <para>The shader bytecode is already in by the time this runs -- <see cref="OnMaterialCompiled"/>
        /// merges the cache unconditionally, keyed by FStaticParameterSet. What is missing is the
        /// *export* that points at it: an instance only reaches its permutation's shader map when it
        /// carries <c>bHasStaticPermutationResource</c>, a matching <c>SM3StaticParameterSet</c> and
        /// the compiled <c>SM3StaticPermutationResource</c>. Without this the map sits in the cache
        /// unreferenced and the instance renders its parent's defaults -- exactly the appearance bug
        /// the whole MIC effort exists to fix.</para>
        ///
        /// <para>Instances are matched by hashing their own parameter set rather than by name,
        /// because the name identifies the parent. Several instances can share one permutation (that
        /// is the point of keying on the set), so every match is updated, not just the first.</para>
        /// </summary>
        /// <param name="parentPath">Instanced full path of the parent UMaterial the resource compiled through.</param>
        /// <param name="permutationKey">The <c>#&lt;16 hex&gt;</c> static parameter set key.</param>
        /// <summary>
        /// Reports every material in a package the host is about to write whose shader map cannot be
        /// found, by the same test the consumers use.
        /// </summary>
        /// <remarks>
        /// A compiled package can be structurally fine and still be useless: a material whose resource
        /// never arrived keeps an all-zero resource id, and an instance can hold a StaticParameterSet
        /// that keys into no map in the cache. Neither shows up as an error while compiling -- the
        /// payloads that did arrive merged cleanly -- so the package looks finished and the damage is
        /// only discovered much later, as a black material in a built mod or as Project Milan's
        /// texture pipeline stripping the permutation again.
        ///
        /// Both of those cost days to trace back to this point (HANDOFF sections 37 and 38), so say it
        /// here, where the package is still in hand and the compile that produced it is on screen.
        /// This reports and does not throw: a package with some broken materials is still worth
        /// writing, and which ones matter is the caller's call.
        ///
        /// <see cref="ShaderCacheManipulator.GetBrokenMaterials"/> is deliberately the same check
        /// Project Milan's installer and TFCBuild apply, so a package that passes here is one they
        /// will accept.
        /// </remarks>
        private static void ReportBrokenMaterials(IMEPackage package, string destination)
        {
            List<ExportEntry> broken;
            try
            {
                broken = ShaderCacheManipulator.GetBrokenMaterials(package, Program.ParsedOptions.GamePath);
            }
            catch (Exception e)
            {
                // Never let a diagnostic stop a package being written.
                Console.WriteLine($"Could not check {Path.GetFileName(destination)} for broken materials: {e.Message}");
                return;
            }

            if (broken.Count == 0)
            {
                Console.WriteLine($"Shader map check: every material in {Path.GetFileName(destination)} resolves.");
                return;
            }

            Console.WriteLine($"WARNING: {broken.Count} material(s) in {Path.GetFileName(destination)} have no reachable " +
                              "shader map. They will render the engine's fallback, and Project Milan will not install them:");
            foreach (var export in broken.Take(25))
            {
                Console.WriteLine($"    {export.ClassName,-25} {export.InstancedFullPath}");
            }
            if (broken.Count > 25)
            {
                Console.WriteLine($"    ... and {broken.Count - 25} more.");
            }
        }

        private static void MergeInstancePermutation(CompileResult cr, string parentPath, string permutationKey)
        {
            // Candidates are instances that own a permutation; anything else shares the parent's map
            // and has nothing to install.
            var matches = new List<ExportEntry>();
            foreach (var export in transientPackage.Exports)
            {
                if (!export.IsA("MaterialInstance")) continue;
                if (export.GetProperty<BoolProperty>("bHasStaticPermutationResource")?.Value != true) continue;

                StaticParameterSet? set;
                try
                {
                    set = ObjectBinary.From<MaterialInstance>(export).SM3StaticParameterSet;
                }
                catch
                {
                    continue; // Unreadable instance binary; it cannot be the one that asked for this.
                }

                if (set != null && StaticPermutationNaming.RawKey(set) == permutationKey)
                {
                    matches.Add(export);
                }
            }

            if (matches.Count == 0)
            {
                // Not fatal: the permutation may belong to an instance in another package that this
                // compile pulled in as a dependency. The bytecode is already merged either way.
                Console.WriteLine($"No instance in the transient package matches permutation {permutationKey} of {parentPath}. Shader cache merged; no export updated.");
                return;
            }

            var ms = new MemoryStream(cr.MaterialResource);
            var serializer = new PackagelessWithObjectsSerializingContainer(ms, scPackage, true);
            serializer.SetGame(transientPackage.Game);
            var permutationResource = new MaterialResource();
            serializer.Serialize(ref permutationResource);

            foreach (var sourceInstance in matches)
            {
                ExportEntry targetInstance;
                if (Program.ParsedOptions.WriteBack)
                {
                    // scPackage is the original input file here. Match by the pre-rename path, since
                    // only the in-memory copy the compiler level was built from was ever renamed.
                    var writebackPath = CapturePackageNaming.DeRenameInstancedPath(
                                            sourceInstance.InstancedFullPath, currentCaptureRoot, currentSourceRoot)
                                        ?? sourceInstance.InstancedFullPath;
                    var found = scPackage.Exports.FirstOrDefault(x => x.IsA("MaterialInstance")
                        && x.InstancedFullPath.Equals(writebackPath, StringComparison.OrdinalIgnoreCase));
                    if (found == null)
                    {
                        Console.WriteLine($"Could not find source instance '{writebackPath}' for writeback in {scPackage.FileNameNoExtension}; skipping.");
                        continue;
                    }
                    targetInstance = found;
                }
                else
                {
                    var existing = scPackage.Exports.FirstOrDefault(x => x.IsA("MaterialInstance")
                        && x.InstancedFullPath.Equals(sourceInstance.InstancedFullPath, StringComparison.OrdinalIgnoreCase));
                    if (existing != null)
                    {
                        targetInstance = existing;
                    }
                    else
                    {
                        EntryExporter.ExportExportToPackage(sourceInstance, scPackage, out var ported);
                        if (ported is not ExportEntry portedInstance)
                        {
                            Console.WriteLine($"Failed to port instance '{sourceInstance.InstancedFullPath}' into the result package; skipping.");
                            continue;
                        }
                        targetInstance = portedInstance;
                    }
                }

                // Use the set the engine actually filed the shader map under, taken from the payload's
                // own cache, rather than the transient instance's copy.
                //
                // This used to copy the transient instance's set on the reasoning that it was already
                // identical to the map's key. It is not. StaticParameterSet carries BaseMaterialId,
                // which is the *parent material's resource id*; the transient instance is the decooked
                // copy, so it holds the id from before this compile, while the game recompiled the
                // parent and filed the instance's map under the parent's new runtime id. The instance
                // then asked for a key no map in the package used, and the permutation read as
                // "no shader map" everywhere downstream -- which is what made Project Milan's texture
                // pipeline strip it again. Measured 2026-09-21 on BioS_MPJungle: both instances'
                // BaseMaterialId appeared in none of the package cache's 11 keys.
                //
                // RawKey is what routed this payload here and it deliberately ignores BaseMaterialId,
                // so it identifies the right map without being confused by the very field that is wrong.
                var sourceSet = ObjectBinary.From<MaterialInstance>(sourceInstance).SM3StaticParameterSet;
                var compiledSet = sourceSet;
                bool foundCompiledSet = false;
                foreach ((StaticParameterSet key, MaterialShaderMap _) in cr.Cache.MaterialShaderMaps)
                {
                    if (StaticPermutationNaming.RawKey(key) == permutationKey)
                    {
                        compiledSet = key;
                        foundCompiledSet = true;
                        break;
                    }
                }

                if (!foundCompiledSet)
                {
                    // Fall back to the transient set rather than inventing an id. The permutation may
                    // still be unreachable, so say which one, instead of leaving it to be discovered as
                    // a missing map in a built mod.
                    Console.WriteLine($"WARNING: no shader map keyed {permutationKey} in the payload for " +
                                      $"{targetInstance.InstancedFullPath}; keeping the transient parameter set, " +
                                      "which may key into nothing.");
                }

                ObjectBinary.EditBinary<MaterialInstance>(targetInstance, x =>
                {
                    x.SM3StaticParameterSet = compiledSet;
                    x.SM3StaticPermutationResource = permutationResource;
                });

                // The installed map is only reachable while the instance still asks for one.
                targetInstance.WriteProperty(new BoolProperty(true, "bHasStaticPermutationResource"));

                Interlocked.Increment(ref mergedCompileResourceCount);
                Console.WriteLine($"Merged permutation {permutationKey} into {targetInstance.InstancedFullPath} " +
                                  (Program.ParsedOptions.WriteBack ? "(input package)" : "(result package)"));
            }
        }

        /// <summary>
        /// Merges one native <c>FTerrainMaterialResource</c> into the exact terrain actor that
        /// generated it. Terrain resources are keyed by their material mask, not their serialized
        /// array index: the latter is regenerated whenever the terrain's components change.
        /// </summary>
        private static void MergeTerrainMaterialResource(CompileResult cr)
        {
            if (string.IsNullOrWhiteSpace(cr.TerrainPath))
            {
                throw new InvalidOperationException($"Terrain compile result '{cr.MaterialName}' did not identify its owning terrain.");
            }

            var sourceTerrain = FindTerrainByRuntimePath(transientPackage, cr.TerrainPath);
            if (sourceTerrain == null)
            {
                throw new InvalidOperationException($"Could not match compiled terrain '{cr.TerrainPath}' to an input terrain in {transientPackage.FileNameNoExtension}.");
            }

            // Bring the owning terrain and its linked authored data into the result before resolving
            // the packageless resource's texture/object references.
            var targetTerrain = scPackage.Exports.FirstOrDefault(x => x.IsA("Terrain")
                && x.InstancedFullPath.Equals(sourceTerrain.InstancedFullPath, StringComparison.OrdinalIgnoreCase));
            if (targetTerrain == null)
            {
                EntryExporter.ExportExportToPackage(sourceTerrain, scPackage, out var portedTerrain);
                targetTerrain = portedTerrain as ExportEntry
                    ?? throw new InvalidOperationException($"Failed to port terrain '{sourceTerrain.InstancedFullPath}' into the shader result package.");
            }

            var stream = new MemoryStream(cr.MaterialResource, writable: false);
            var serializer = new PackagelessWithObjectsSerializingContainer(stream, scPackage, true);
            serializer.SetGame(Program.Game);
            var compiledResource = new TerrainMaterialResource();
            serializer.Serialize(ref compiledResource);

            // The terrain translator should have filled the common FMaterial texture table before
            // ShaderClient serializes the resource. Keep this at the receive boundary so a capture
            // immediately distinguishes a native compile failure from a wire/writeback failure.
            Console.WriteLine($"Received terrain resource {compiledResource.Mask.BitMask:X}: " +
                              $"ID={compiledResource.ID}, UniformExpressionTextures={compiledResource.UniformExpressionTextures?.Length ?? 0}, " +
                              $"MaterialIds={compiledResource.MaterialIds?.Length ?? 0}");
            if (compiledResource.UniformExpressionTextures is not { Length: > 0 })
            {
                Console.WriteLine("WARNING: Terrain resource arrived without uniform-expression textures.");
            }
            else
            {
                for (var textureIndex = 0; textureIndex < compiledResource.UniformExpressionTextures.Length; textureIndex++)
                {
                    var textureUIndex = compiledResource.UniformExpressionTextures[textureIndex];
                    var textureEntry = scPackage.GetEntry(textureUIndex);
                    Console.WriteLine($"  Terrain texture [{textureIndex}]: {textureUIndex} -> " +
                                      (textureEntry == null
                                          ? "<unresolved>"
                                          : $"{textureEntry.ClassName} {textureEntry.InstancedFullPath}"));
                }
            }

            // Set terrain of the resource to the in-package terrain
            compiledResource.Terrain = targetTerrain.UIndex;

            ObjectBinary.EditBinary<Terrain>(targetTerrain, terrain =>
            {
                // A terrain capture is a complete rebuild of this terrain's compiled data. Do this
                // once per target terrain, before the first returned resource is merged. Clearing
                // during every callback would leave only the final mask-specific resource behind.
                if (resetTerrainCaches.Add(targetTerrain.InstancedFullPath))
                {
                    terrain.CachedTerrainMaterials = [];
                    terrain.CachedTerrainMaterials2 = [];
                    Console.WriteLine($"Cleared existing terrain material caches for {targetTerrain.InstancedFullPath}");
                }

                // LE3's ATerrain::GetCachedMaterial (MassEffect3.exe+0x807C70) maps the active
                // SM5 platform (5) to cache index 0. This is the first serialized terrain cache
                // array, matching stock LE3 terrain packages.
                var cache = terrain.CachedTerrainMaterials ?? [];
                var replacementIndex = Array.FindIndex(cache, x => x.Mask.NumBits == compiledResource.Mask.NumBits
                    && x.Mask.BitMask == compiledResource.Mask.BitMask);

                if (replacementIndex >= 0)
                {
                    cache[replacementIndex] = compiledResource;
                }
                else
                {
                    Array.Resize(ref cache, cache.Length + 1);
                    cache[^1] = compiledResource;
                }

                // Resources are keyed by mask rather than their transient cache array index.
                terrain.CachedTerrainMaterials = cache;
            });

            Interlocked.Increment(ref mergedCompileResourceCount);
            Console.WriteLine($"Merged terrain resource {compiledResource.Mask.BitMask:X} ({compiledResource.Mask.NumBits} bits) into LE3 terrain cache for {targetTerrain.InstancedFullPath}");
        }

        /// <summary>
        /// The runtime compiler map has its own package name, while the source terrain is retained
        /// under its original package in <see cref="transientPackage"/>. Match the full local export
        /// path as a suffix so we do not depend on the compiler-map's generated package name.
        /// </summary>
        private static ExportEntry? FindTerrainByRuntimePath(IMEPackage package, string runtimePath)
        {
            var matches = package.Exports.Where(x => x.IsA("Terrain")
                    && (runtimePath.Equals(x.InstancedFullPath, StringComparison.OrdinalIgnoreCase)
                        || runtimePath.EndsWith($".{x.InstancedFullPath}", StringComparison.OrdinalIgnoreCase)))
                .ToList();

            return matches.Count switch
            {
                0 => null,
                1 => matches[0],
                _ => throw new InvalidOperationException($"Runtime terrain path '{runtimePath}' is ambiguous in {package.FileNameNoExtension}: {string.Join(", ", matches.Select(x => x.InstancedFullPath))}")
            };
        }


        private static void BuildShaders(string inputFile)
        {
            // Find source objects    
            using IMEPackage sourcePackage = MEPackageHandler.OpenMEPackage(inputFile);
            // @todo Make this dynamic
            scPackage = MEPackageHandler.CreateAndOpenPackage(Path.Combine(MEDirectories.GetDLCPath(Program.Game), @"DLC_MOD_MorePhotoFilters1\CookedPCConsole\ShaderCompiler.pcc"), Program.Game);

            ConfigAssetBundle dlcMod = ConfigAssetBundle.FromDLCFolder(MEGame.LE3, Path.Combine(MEDirectories.GetDLCPath(Program.Game), @"DLC_MOD_MorePhotoFilters1\CookedPCConsole"), @"DLC_MOD_MorePhotoFilters1");
            var bioInput = dlcMod.GetAsset("BioInput");
            var photo = bioInput.GetOrAddSection("sfxgame.sfxgamemodephoto");
            photo.Clear(); // remove any existing entries.
            foreach (var sourceMat in sourcePackage.Exports.Where(x => x.ClassName == "Material"))
            {
                // Build the package file.
                EntryExporter.ExportExportToPackage(sourceMat, scPackage, out var pMat);
                var buildingMat = (ExportEntry)pMat;
                // Don't move it up; this way we can just unset flag in later version
                //var buildingMat = pMat as ExportEntry;
                //buildingMat.idxLink = 0;
                SetForcedExportFlag(buildingMat, false); // This just helps if above doesn't work

                ObjectBinary.EditBinary<Material>(buildingMat, (x) =>
                {
                    // Set new guid so it can't find in ref shader map and is not invalid
                    x.SM3MaterialResource.ID = Guid.NewGuid();
                });

                // Create matinst
                var mic = GenerateMaterialInstanceConstantFromMaterial(buildingMat);
                // Add to config file so it loads in photo mode
                photo.AddEntry(new CoalesceProperty("filtermaterialpaths", new CoalesceValue($"ShaderCompiler.{mic.InstancedFullPath}", CoalesceParseAction.AddUnique)));
            }

            scPackage.Save();
            dlcMod.CommitDLCAssets();

            // Game is now ready.
        }

        /// <summary>
        /// Boots the game for one package and waits for it to exit.
        /// </summary>
        /// <param name="progressDone">1-based position of this package in the run, for the loading
        /// screen's counter. Null leaves the counter off.</param>
        /// <param name="progressTotal">How many packages the run covers. Null leaves the counter off.</param>
        /// <param name="currentPackage">Package name to show on the loading screen. Defaults to
        /// <paramref name="builtFor"/>, which for a capture is the renamed capture root rather than the
        /// readable source name, so callers that have the latter should pass it.</param>
        private static void StartGameAndWaitForExit(EShaderLevelMode buildMode, string builtFor, bool isLE1SourcePackage = false,
            int? progressDone = null, int? progressTotal = null, string currentPackage = null)
        {
            Console.WriteLine($"Starting game for {(buildMode == EShaderLevelMode.Compile ? "compilation" : "preview")} of {builtFor}");
            TOCCreator.CreateTOCForGame(Game);
            if (buildMode == EShaderLevelMode.SlashLevel)
            {
                throw new Exception("Can't start game for shader slash level");
            }

            var bootArg = buildMode switch
            {
                EShaderLevelMode.Preview => "-ShaderPreview -NoShaderCompile",
                // LE3 refuses to create a 640x360 render surface on current systems. Keep
                // shader compilation lightweight while using a reliably supported mode.
                EShaderLevelMode.Compile => "-ShaderCompile -NoSplash -ResX=1280 -ResY=720",
                _ => throw new Exception("Unhandled build mode: " + buildMode)
            };

            var captureDebugPackages = buildMode == EShaderLevelMode.Compile
                && (Program.ParsedOptions.BuildDebugPackages || Program.ParsedOptions.CaptureOnly);
            if (captureDebugPackages)
            {
                bootArg += " -SendDebugPackages";
            }

            if (buildMode == EShaderLevelMode.Compile && Program.ParsedOptions.CaptureOnly)
            {
                bootArg += " -CaptureOnly";
            }

            if (buildMode == EShaderLevelMode.Compile && Program.ParsedOptions.TraceRvrMaterialResolution)
            {
                bootArg += " -TraceRvrMaterialResolution";
            }

            if (buildMode == EShaderLevelMode.Compile && Program.ParsedOptions.TraceMaterialTranslation)
            {
                bootArg += " -TraceMaterialTranslation";
            }

            // Repoints both traces above at another material family. ShaderClient reads the value up to
            // the next space, so a filter containing one would silently truncate; reject it here rather
            // than let the trace quietly follow the wrong materials.
            var traceFilter = Program.ParsedOptions.TraceMaterialFilter;
            if (buildMode == EShaderLevelMode.Compile && !string.IsNullOrWhiteSpace(traceFilter))
            {
                if (traceFilter.Contains(' '))
                {
                    throw new Exception("--tracematerialfilter cannot contain a space: " + traceFilter);
                }
                bootArg += $" -TraceMaterialFilter={traceFilter}";
            }

            // Progress for the compiler level's loading screen. One game process runs per package, so
            // without this the window opens and closes with no indication of where the run is. Both
            // counts are needed for the counter to mean anything, so they travel together.
            if (progressDone.HasValue && progressTotal.HasValue)
            {
                bootArg += $" --numdone={progressDone.Value} --numtotal={progressTotal.Value}";
            }

            // ShaderClient reads this up to the next space, and a package name cannot contain one.
            var displayPackage = currentPackage ?? builtFor;
            if (!string.IsNullOrWhiteSpace(displayPackage) && !displayPackage.Contains(' '))
            {
                bootArg += $" --currentpackage={displayPackage}";
            }

            if (buildMode == EShaderLevelMode.Compile && isLE1SourcePackage)
            {
                Console.WriteLine("Enabling legacy opaque SceneDepth compatibility mode for an LE1 source package");
                bootArg += " -AllowLegacyOpaqueSceneDepthTest";
            }

            var processPath = MEDirectories.GetExecutablePath(Game);
            Console.WriteLine($"Process.Start(): \"{processPath}\" {bootArg} -NOHOMEDIR");
            if (captureDebugPackages)
            {
                ShaderHost.BeginDebugCapture(builtFor);
            }

            var launchedUtc = DateTime.UtcNow;
            Process? process = null;
            try
            {
                process = Process.Start(processPath, $"{bootArg} -NOHOMEDIR");
                process.WaitForExit();
                Console.WriteLine($"Game exited with code {process.ExitCode}{DescribeGameExitCode(process.ExitCode)}");
            }
            finally
            {
                try
                {
                    if (process != null && process.HasExited)
                    {
                        var clientLog = Path.Combine(Environment.CurrentDirectory, "Logs", "ShaderClient.log");
                        var diagnostics = ShaderRunDiagnostics.Current?.ArchiveClientLog(clientLog, displayPackage, buildMode.ToString(), process.Id, launchedUtc);
                        if (buildMode == EShaderLevelMode.Compile && diagnostics?.MaterialCompileFailed == true && !currentCompileSessionFailed)
                        {
                            MarkCompileFailure($"Material translation failed; see archived ShaderClient log: {diagnostics.Path}");
                        }
                    }
                }
                finally
                {
                    if (captureDebugPackages)
                    {
                        ShaderHost.EndDebugCapture(builtFor);
                    }
                    process?.Dispose();
                }
            }
        }

        private static string GetMapName(EShaderLevelMode buildMode)
        {
            switch (buildMode)
            {
                case EShaderLevelMode.Preview:
                    return "shaderpreview";
                case EShaderLevelMode.Compile:
                    return "shadercompiler";
                case EShaderLevelMode.SlashLevel:
                    return "shaderslash";
            }
            throw new Exception("Unhandled build mode: " + buildMode);
        }

        // From LEX ExperimentsM
        public static ExportEntry GenerateMaterialInstanceConstantFromMaterial(ExportEntry matExp, string suffix = "_matInst")
        {
            var matExpProps = matExp.GetProperties();

            // Create the export
            var matInstConst = ExportCreator.CreateExport(matExp.FileRef, matExp.ObjectName.Name + suffix, "MaterialInstanceConstant", matExp.Parent);
            matInstConst.indexValue--; // Decrement it by one so it starts at 0

            var matInstConstProps = matInstConst.GetProperties();
            var lightingParent = matExpProps.GetProp<StructProperty>("LightingGuid");
            if (lightingParent != null)
            {
                lightingParent.Name = "ParentLightingGuid"; // we aren't writing to parent so this is fine
                matInstConstProps.AddOrReplaceProp(lightingParent);
            }

            matInstConstProps.AddOrReplaceProp(new ObjectProperty(matExp.UIndex, "Parent"));
            matInstConstProps.AddOrReplaceProp(CommonStructs.GuidProp(Guid.NewGuid(), "m_Guid")); // IDK if this is used but we're gonna do it anyways

            ArrayProperty<StructProperty> vectorParameters =
                new ArrayProperty<StructProperty>("VectorParameterValues");
            ArrayProperty<StructProperty> scalarParameters =
                new ArrayProperty<StructProperty>("ScalarParameterValues");
            ArrayProperty<StructProperty> textureParameters =
                new ArrayProperty<StructProperty>("TextureParameterValues");

            var expressions = matExpProps.GetProp<ArrayProperty<ObjectProperty>>("Expressions");
            if (expressions != null)
            {
                foreach (var expressionOP in expressions)
                {
                    if (expressionOP.Value <= 0)
                        continue; // It's null
                    var expression = expressionOP.ResolveToEntry(matExp.FileRef) as ExportEntry;
                    switch (expression.ClassName)
                    {
                        case "MaterialExpressionScalarParameter":
                            {
                                var spvP = expression.GetProperties();
                                var paramValue = spvP.GetProp<FloatProperty>("DefaultValue");
                                if (paramValue == null)
                                {
                                    spvP.Add(new FloatProperty(0, "ParameterValue"));
                                }
                                else
                                {
                                    paramValue.Name = "ParameterValue";
                                    spvP.RemoveAt(0);
                                    spvP.AddOrReplaceProp(paramValue); // This value goes on the end
                                }

                                scalarParameters.Add(new StructProperty("ScalarParameterValue", spvP));
                            }
                            break;
                        case "MaterialExpressionVectorParameter":
                            {
                                var vpvP = expression.GetProperties();
                                var paramValue = vpvP.GetProp<StructProperty>("DefaultValue");
                                if (paramValue == null)
                                {
                                    vectorParameters.Add(CommonStructs.Vector3Prop(0, 0, 0, "DefaultValue"));
                                }
                                else
                                {
                                    paramValue.Name = "ParameterValue";
                                    vectorParameters.Add(new StructProperty("VectorParameterValue", vpvP));
                                }
                            }
                            break;
                        case "MaterialExpressionTextureSampleParameter2D":
                            {
                                var tpvP = expression.GetProperties();
                                var paramValue = tpvP.GetProp<ObjectProperty>("Texture");
                                paramValue.Name = "ParameterValue";
                                textureParameters.Add(new StructProperty("TextureParameterValue", tpvP));
                            }
                            break;
                    }
                }
            }

            if (vectorParameters.Any()) matInstConstProps.AddOrReplaceProp(vectorParameters);
            if (scalarParameters.Any()) matInstConstProps.AddOrReplaceProp(scalarParameters);
            if (textureParameters.Any()) matInstConstProps.AddOrReplaceProp(textureParameters);

            matInstConst.WriteProperties(matInstConstProps);
            return matInstConst;
        }

        public static void SetForcedExportFlag(ExportEntry exp, bool set)
        {

            List<IEntry> entries = exp.GetAllDescendants();
            entries.Add(exp);

            foreach (IEntry entry in entries)
            {
                if (entry is not ExportEntry export) { continue; }

                if (export.ClassName == "ObjectReferencer") { continue; }

                if (set)
                {
                    // Set
                    export.ExportFlags |= UnrealFlags.EExportFlags.ForcedExport;
                }
                else
                {
                    // Strip
                    export.ExportFlags &= ~UnrealFlags.EExportFlags.ForcedExport;
                }
            }
        }
    }
}
