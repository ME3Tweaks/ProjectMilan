using LegendaryExplorerCore.Coalesced;
using LegendaryExplorerCore.Coalesced.Config;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using System.Diagnostics;
using LegendaryExplorerCore.Shaders;
using System.Diagnostics;
using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Misc.ME3Tweaks;

namespace MilanShaderHost
{
    /// <summary>
    /// Handles building packages running the game, starting the game, and waiting for it to exit, so it can process the next batch
    /// of shaders.
    /// </summary>
    internal class MilanShaderBuilderFlow
    {
        private static List<string> PackageFilesToProcess = new List<string>();

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
            MilanShaderPackageBuilder.SourceFolders.Add(@"S:\Milan\UDK\MilanMaterialDecook_Merged_T3D");


            KillGame();
            SetupFileList();
            ShaderHost.NewShaderCacheGenerated += OnMaterialCompiled;
            foreach (var file in PackageFilesToProcess)
            {
                var outPath = Path.Combine(@"S:\Milan\ShaderResearch\CompiledShaderPackages", Path.GetFileNameWithoutExtension(file) + ".pcc");

                if (false)
                {
                    Console.WriteLine($"Building shaders for: {Path.GetFileNameWithoutExtension(file)}");

                    scPackage = MEPackageHandler.CreateMemoryEmptyPackage(Path.GetFileName(file), Program.Game);
                    scPackage.CreateShaderCache();

                    // Builds materials into the map
                    SetupEntry(file, false);

                    // Runs game, which builds shaders and feeds them back to us.
                    StartGameAndWaitForExit();

                    scPackage.Save(outPath);
                }

                // Once game exits, ShaderHost should have received the shader cache, and our OnShaderCacheUpdated() event should have triggered.
                Console.WriteLine($"Finished compiling shaders for {Path.GetFileNameWithoutExtension(file)}");

                // Test...
                if (true)
                {
                    Console.WriteLine($"Rebuilding with compiled shaders for previewing");
                    SetupEntry(outPath, true);
                    StartGameAndWaitForExit();
                }
            }


            Console.WriteLine($"Shader compiling complete.");
        }

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
                using var tPackage = MEPackageHandler.OpenMEPackage(sourcePath, forceLoadFromDisk: true);
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

        private static void OnMaterialCompiled(object? sender, CompileResult cr)
        {
            // Merge material into the package.
            var matchingMat = transientPackage.Exports.FirstOrDefault(x => x.ObjectNameString == cr.MaterialName && x.ClassName == "Material");
            if (matchingMat == null)
            {
                Console.WriteLine($"No matching material found for {cr.MaterialName} in transient package. Skipping.");
                return;
            }

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

        private static void SetupFileList()
        {
            PackageFilesToProcess.Add(@"S:\Milan\UDK\MilanMaterialDecook_Merged_T3D\BioT_MPJungle.pcc");
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

        private static void StartGameAndWaitForExit()
        {
            var process = Process.Start(LE3Directory.ExecutablePath, "-RESUME");
            process.WaitForExit();
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
