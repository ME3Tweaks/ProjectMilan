using LegendaryExplorerCore.Coalesced;
using LegendaryExplorerCore.Coalesced.Config;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
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
            KillGame();
            SetupFileList();
            ShaderHost.ShaderCacheUpdated += OnShaderCacheUpdated;
            foreach (var file in PackageFilesToProcess)
            {
                Console.WriteLine($"Building shaders for: {Path.GetFileNameWithoutExtension(file)}");

                scPackage = MEPackageHandler.CreateAndOpenPackage(Path.Combine(MEDirectories.GetDLCPath(Program.Game), @"DLC_MOD_MorePhotoFilters1\CookedPCConsole\ShaderCompiler.pcc"), Program.Game);

                // Builds materials into the map
                SetupEntry(file);

                // Runs game, which builds shaders and feeds them back to us.
                StartGameAndWaitForExit();

                // Once game exits, ShaderHost should have received the shader cache, and our OnShaderCacheUpdated() event should have triggered.
                Console.WriteLine($"Finished compiling shaders for {Path.GetFileNameWithoutExtension(file)}");
            }


            Console.WriteLine($"Shader compiling complete.");
        }

        private static void SetupEntry(string sourcePath)
        {
            // Have to figure this out for LE2 as it doesn't have entry map.
            var inPath = Path.Combine(ME3TweaksBackups.GetGameBackupPath(Program.Game), "BioGame", "CookedPCConsole", "entry.pcc");
            var outPath = Path.Combine(MEDirectories.GetCookedPath(Program.Game), "entry.pcc");

            var package = MilanShaderPackageBuilder.BuildIntoExistingPackage(inPath, sourcePath);
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

        private static void OnShaderCacheUpdated(object? sender, EventArgs e)
        {
            // Merge materials from scPackage into the shader cache package so they stay linked up, as the guids are randomly generated.
            foreach (var exp in scPackage.Exports.Where(x => x.ClassName == "Material"))
            {
            }
        }

        private static void SetupFileList()
        {
            PackageFilesToProcess.Add(@"S:\Milan\UDK\MilanMaterialDecook_Merged_T3D\BioT_MPJungle.pcc");
        }

        /// <summary>
        /// Current shader cache package that the game is using to build
        /// </summary>
        private static IMEPackage scPackage;
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
