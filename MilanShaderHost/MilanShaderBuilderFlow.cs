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

        internal static void MarkCompileFailure(string errorMessage)
        {
            currentCompileSessionFailed = true;
            Console.Error.WriteLine($"ShaderClient reported a compile failure; writeback is disabled for this package: {errorMessage}");
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

                if (sp.Exports.Count(x => x.IsA("Material")) == 0 && !hasCompilableTerrain)
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

        static void SetupShaderCompileFlow()
        {
            var outDir = @"E:\CompiledShaderPackages";
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
                // Ensure SFXOnlineFoundation has Telemetry removed as it significantly slows down compile on game close.
                var sfxOnlineFoundation = MEPackageHandler.OpenMEPackage(Path.Combine(LE3Directory.CookedPCPath, "SFXOnlineFoundation.pcc"));
                var onlineSubsystem = sfxOnlineFoundation.FindExport("Default__SFXOnlineSubsystem");
                var componentsList = onlineSubsystem.GetProperty<ArrayProperty<StructProperty>>("ComponentClassList");
                var removed = componentsList.RemoveAll(x =>
                {
                    var className = x.GetProp<ObjectProperty>("ClassName");
                    var resolved = sfxOnlineFoundation.GetEntry(className.Value);
                    return resolved.ObjectName == "SFXOnlineCOmponentTelemetrySystem";
                });
                if (removed)
                {
                    onlineSubsystem.WriteProperty(componentsList);
                    sfxOnlineFoundation.Save();
                    Console.WriteLine("Patched out telemetry subsystem to improve shader compiling performance");
                }
            }

            var files = ShaderCompileList.PackageFilesToProcess;
            Task<PreparedLevel?>? nextLevelTask = null;

            for (int i = 0; i < files.Count; i++)
            {
                var file = files[i];
                var baseName = Path.GetFileNameWithoutExtension(file);
                /*if (!baseName.Equals("BIOG_PhotoModeFilters", StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }*/
                var outPath = Path.Combine(outDir, baseName + ".pcc");
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

                    // Use the pre-prepared level from the previous iteration if available, otherwise build now
                    PreparedLevel? current = nextLevelTask != null
                        ? nextLevelTask.GetAwaiter().GetResult()
                        : BuildShaderLevelInMemory(file, EShaderLevelMode.Compile);
                    nextLevelTask = null;

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

                    // While the game runs, prepare the next file in the background
                    if (i + 1 < files.Count)
                    {
                        var nextFile = files[i + 1];
                        Console.WriteLine($"Pre-preparing level for: {Path.GetFileNameWithoutExtension(nextFile)}");
                        nextLevelTask = Task.Run(() => BuildShaderLevelInMemory(nextFile, EShaderLevelMode.Compile));
                    }

                    // Runs game, which builds shaders and feeds them back to us.
                    StartGameAndWaitForExit(EShaderLevelMode.Compile, baseName, current.IsLE1SourcePackage);

                    if (Program.ParsedOptions.WriteBack)
                    {
                        if (currentCompileSessionFailed || Volatile.Read(ref mergedCompileResourceCount) == 0)
                        {
                            throw new InvalidOperationException($"Refusing to write back '{file}': " +
                                (currentCompileSessionFailed
                                    ? "ShaderClient reported at least one compilation failure."
                                    : "ShaderClient returned no material or terrain resources."));
                        }

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
                        Console.WriteLine($"Skipping save for '{baseName}': " +
                            (currentCompileSessionFailed
                                ? "ShaderClient reported at least one compilation failure."
                                : "ShaderClient returned no material or terrain resources.") +
                            (File.Exists(outPath) ? $" Leaving existing {outPath} untouched." : ""));
                    }
                    else
                    {
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
                    StartGameAndWaitForExit(EShaderLevelMode.Preview, baseName);
                }
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
                matExp = scPackage.Exports.FirstOrDefault(x => x.IsA("Material")
                    && x.InstancedFullPath.Equals(matchingMat.InstancedFullPath, StringComparison.OrdinalIgnoreCase))
                    ?? throw new InvalidOperationException($"Could not find source material '{matchingMat.InstancedFullPath}' for writeback in {scPackage.FileNameNoExtension}.");
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
            Console.WriteLine($"Merged {cr.MaterialName} into " +
                              (Program.ParsedOptions.WriteBack ? "the input package" : "the result package"));
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

        private static void StartGameAndWaitForExit(EShaderLevelMode buildMode, string builtFor, bool isLE1SourcePackage = false)
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

            try
            {
                var process = Process.Start(processPath, $"{bootArg} -NOHOMEDIR");
                process.WaitForExit();
                Console.WriteLine($"Game exited with code {process.ExitCode}");
            }
            finally
            {
                if (captureDebugPackages)
                {
                    ShaderHost.EndDebugCapture(builtFor);
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
