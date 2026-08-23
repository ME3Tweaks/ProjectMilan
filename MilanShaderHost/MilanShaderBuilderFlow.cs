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
            var path = Path.Combine(DecookedPackagesPath, Game.ToString());
            // MilanShaderPackageBuilder.SourceFolders.Add(Path.Combine(DecookedPackagesPath, "LE1"));
            MilanShaderPackageBuilder.SourceFolders.Add(path);

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
                    StartGameAndWaitForExit(EShaderLevelMode.Compile, Path.GetFileNameWithoutExtension(file));

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
        }

        /// <summary>
        /// Builds the shader level package entirely in memory without saving to disk or touching
        /// any instance fields, so it can safely run on a background thread while the game is running.
        /// Returns null if the source package contains no materials.
        /// </summary>
        private static PreparedLevel? BuildShaderLevelInMemory(string sourcePath, EShaderLevelMode buildMode)
        {
            if (buildMode != EShaderLevelMode.SlashLevel)
            {
                using var sp = MEPackageHandler.UnsafePartialLoad(sourcePath, x => false);
                // Once we get normal materials working we can work on making this accept MaterialInstances.
                // Then we can pre-bake the bHasStaticPermutation version.
                if (sp.Exports.Count(x => x.IsA("Material")) == 0)
                {
                    // No materials to compile
                    return null;
                }
            }

            var mapName = GetMapName(buildMode) + ".pcc";

            var localTransient = MEPackageHandler.CreateMemoryEmptyPackage("Transient.pcc", Program.Game);
            var package = MilanShaderPackageBuilder.BuildMapPackage(mapName, sourcePath, localTransient, buildMode);
            if (buildMode == EShaderLevelMode.Preview)
            {
                // Copy SeekFreeShaderCache
                using var tPackage = MEPackageHandler.OpenMEPackage(sourcePath);
                var cache = tPackage.FindExport("SeekFreeShaderCache");
                EntryExporter.ExportExportToPackage(cache, package, out var cacheExport);
            }
            else if (buildMode == EShaderLevelMode.Compile)
            {
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
                foreach (var tex in package.Exports.Where(x => x.IsTexture()))
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

            return new PreparedLevel { TransientPackage = localTransient, MapPackage = package };
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

                    scPackage = MEPackageHandler.CreateMemoryEmptyPackage(Path.GetFileName(file), Program.Game);
                    scPackage.CreateShaderCache();

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
                    Console.WriteLine("Saving...");
                    var outGameDir = @"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\ME3\BioGame\CookedPCConsole";
                    current.MapPackage.Save(Path.Combine(outGameDir, GetMapName(EShaderLevelMode.Compile) + ".pcc"));

                    // While the game runs, prepare the next file in the background
                    if (i + 1 < files.Count)
                    {
                        var nextFile = files[i + 1];
                        Console.WriteLine($"Pre-preparing level for: {Path.GetFileNameWithoutExtension(nextFile)}");
                        nextLevelTask = Task.Run(() => BuildShaderLevelInMemory(nextFile, EShaderLevelMode.Compile));
                    }

                    // Runs game, which builds shaders and feeds them back to us.
                    StartGameAndWaitForExit(EShaderLevelMode.Compile, baseName);

                    scPackage.Save(outPath);
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
            Console.WriteLine("Saving...");
            var outDir = @"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\ME3\BioGame\CookedPCConsole";
            var mapName = GetMapName(buildMode) + ".pcc";
            var finalOut = Path.Combine(outDir, mapName);
            prepared.MapPackage.Save(finalOut);
            return finalOut;
        }

        private static void OnMaterialCompiled(object? sender, CompileResult cr)
        {
            // Merge material into the package.
            var matchingMat = transientPackage.FindExport(cr.MaterialName);
            if (!matchingMat.IsA("Material"))
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

            // Export matching material from transient package to final compiled package
            EntryExporter.ExportExportToPackage(matchingMat, scPackage, out var pMat);
            var matExp = (ExportEntry)pMat;

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

            // Merge shader cache into the package.
            var cache = scPackage.FindExport("SeekFreeShaderCache");
            ObjectBinary.EditBinary<ShaderCache>(cache, (x) =>
            {
                cr.Cache.MergeInto(x);
            });

            // We need to link up the guids.
            Console.WriteLine($"Merged {cr.MaterialName} into result package");
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

        private static void StartGameAndWaitForExit(EShaderLevelMode buildMode, string builtFor)
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
                EShaderLevelMode.Compile => "-ShaderCompile -NoSplash -ResX=640 -ResY=360",
                _ => throw new Exception("Unhandled build mode: " + buildMode)
            };

            if (buildMode == EShaderLevelMode.Compile && (Program.ParsedOptions.BuildDebugPackages || Program.ParsedOptions.CaptureOnly))
            {
                bootArg += " -SendDebugPackages";
            }

            if (buildMode == EShaderLevelMode.Compile && Program.ParsedOptions.CaptureOnly)
            {
                bootArg += " -CaptureOnly";
            }

            var processPath = MEDirectories.GetExecutablePath(Game);
            var process = Process.Start(processPath, $"{bootArg} -NOHOMEDIR");
            process.WaitForExit();
            Console.WriteLine($"Game exited with code {process.ExitCode}");
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
