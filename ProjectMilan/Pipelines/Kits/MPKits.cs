using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using ProjectMilan.Pipelines.Kits.KitSpecificFixes;
using ProjectMilanCore;
using System.Diagnostics;

namespace ProjectMilan.Pipelines.Kits
{
    /// <summary>
    /// Pipeline for porting MP characters (kits)
    /// </summary>
    internal class MPKits
    {
        private const string LOG_CATEGORY = "MILAN-MPKit";
        public static void RunPipeline()
        {
            var vars = new MPKitVars();
            InternalRunPipeline(vars);
        }

        private static void InternalRunPipeline(MPKitVars vars)
        {
            //DotTrace.EnsurePrerequisite();
            //DotTrace.Attach();
            // foreach (var kit in vars.KitPipelines)

            // Chained to the long-lived MPCommon tier so files hit repeatedly within this pipeline (but not
            // globally hot enough to be in MPCommon) get promoted here instead of reopened per-kit. Disposed
            // once every kit is done, so nothing here outlives the Kits pipeline.
            using var pipelineCache = MilanShared.GetMPCommonTieredPackageCache().ChainNewCache(canPromoteInto: true, debugName: "MPKits pipeline cache");

            var kits = vars.KitPipelines.OrderBy(x => x.ShouldBuild); // Frontload enabled ones for multithread
            Parallel.ForEach(kits.AsParallel().AsOrdered(), new ParallelOptions() { MaxDegreeOfParallelism = Program.Settings.MaxThreads }, kit =>
            {
                // Uncomment this to port everything
                // or to filter to a specific kit
                if (/*false && */!kit.ShouldBuild /*|| !kit.PackageName.Contains("Collector")*/)
                {
                    // This level is not marked for porting currently.
                    MilanLog.Information($"Skipping kit {kit.PackageName}, pipeline is not enabled", customPrefix: LOG_CATEGORY);
                    return;
                }

                BeginPorting(kit, pipelineCache);
            });
            // }
        }


        private static void BeginPorting(KitSpecificPipeline kitPipeline, TieredPackageCache pipelineCache)
        {
            kitPipeline.LogCategory = $"{LOG_CATEGORY}-{kitPipeline.PackageName}";

            // Initialize cache
            kitPipeline.Cache = pipelineCache.ChainNewCache(debugName: $"MPKits kit cache ({kitPipeline.PackageName})");

            var outputPath = Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole", @"Kits");
            Directory.CreateDirectory(outputPath);

            var finalPackagePath = Path.Combine(outputPath, kitPipeline.PackageName + ".pcc");
            var kitDestPackage = MEPackageHandler.CreateAndOpenPackage(finalPackagePath, MEGame.LE3);
            kitPipeline.PortedPackage = kitDestPackage;
            
            kitDestPackage.LECLTagData.ImportHintFiles.Add(MilanShared.MP_STARTUP_FILENAME); // Hint this for importing.
            kitDestPackage.LECLTagData.IsPostLoadFile = false; // Do not allow using BIO_COMMON

            var kitSourcePackage = MilanShared.GetME3Package(kitPipeline.PackageName + ".pcc");

            // Before we port object referencer, we port loose classes found in the package from our catalog of classes
            // This way we can pre-apply fixes in source rather than in post which makes for a cleaner build
            // Literally does nothing 09/26/2026
            // MilanShared.PrePortClasses(kitSourcePackage, kitSourcePackage, kitPipeline.Cache, kitPipeline.LogCategory);
            MilanShared.PortObjectReferencer(kitSourcePackage, kitDestPackage, kitPipeline.Cache, kitPipeline.LogCategory, postPortModifier: ApplyKitChanges);
            MilanShared.PortLocalizations(kitPipeline.PackageName, outputPath, kitPipeline.Cache, kitPipeline.LogCategory);

            // Apply post corrections
            kitPipeline.PostCorrections?.Invoke(kitPipeline);
            if (kitPipeline.PortedPackage?.IsModified == true)
            {
                // Package needs saved
                kitPipeline.PortedPackage.Save();
            }

            // Lose refernce
            kitPipeline.PortedPackage = null;
            kitPipeline.Cache.Dispose();
        }

        private static void ApplyKitChanges(IMEPackage package)
        {
            return; 
            var referencer = package.CreateObjectReferencer(); // Returns it
            var archetype = referencer.GetProperty<ArrayProperty<ObjectProperty>>("ReferencedObjects")[0].ResolveToEntry(package) as ExportEntry;
            var pawnClass = archetype.Class as ExportEntry;
            var pawnDefaults = pawnClass.GetDefaults();
            
            // Too lazy to do this the right way so we just search the children
            var module = package.Exports.FirstOrDefault(x => x.Parent == pawnDefaults && x.ClassName == "SFXModule_MarkerPlayer");

            var markerClass = EntryImporter.EnsureClassIsInFile(package, "SFXGUIValue_MarkerPlayerHealth", new RelinkerOptionsPackage() { DestinationCustomImportFileResolver = MilanShared.LE3PackageResolver });
        }

        // Used to find kits
        public static void BuildKitPipelineCode()
        {
            MilanShared.LoadME3DLCTOCs();
            var kits = new List<string>();
            foreach (var f in MilanShared.ME3DLCFileMap)
            {
                if (f.Key.StartsWith("Bio") || !f.Key.RepresentsPackageFilePath())
                    continue;

                MilanLog.Information($"Loading {f.Key}");
                var package = MilanShared.GetME3Package(f.Key);
                var references = package.Exports.Where(x => x.ClassName == "ObjectReferencer");
                foreach (var reference in references)
                {
                    var objRefs = reference.GetProperty<ArrayProperty<ObjectProperty>>("ReferencedObjects");
                    if (objRefs != null)
                    {
                        foreach (var objRef in objRefs)
                        {
                            if (package.TryGetUExport(objRef.Value, out var exp))
                            {
                                if (exp.IsA("SFXPawn_PlayerMP"))
                                {
                                    // Got one
                                    kits.Add($"new KitSpecificPipeline() {{ PackageName = \"{package.FileNameNoExtension}\", Enabled = false}},");
                                }
                            }
                        }
                    }
                }
            }

            foreach (var kit in kits)
            {
                Debug.WriteLine(kit);
            }
        }
    }



    internal class MPKitVars
    {
        public readonly List<KitSpecificPipeline> KitPipelines = new()
        {
            // Basegame
            new KitSpecificPipeline() { PackageName = "Asari_Adept_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Asari_Vanguard_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Drell_Adept_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Drell_Vanguard_MP", Enabled = true },
            new KitSpecificPipeline() { PackageName = "HumanFemale_Adept_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "HumanFemale_Engineer_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "HumanFemale_Infiltrator_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "HumanFemale_Sentinel_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "HumanFemale_Soldier_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "HumanFemale_Vanguard_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "HumanMale_Adept_MP"}, // Default option
            new KitSpecificPipeline() { PackageName = "HumanMale_Engineer_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "HumanMale_Infiltrator_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "HumanMale_Sentinel_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "HumanMale_SoldierBF3_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "HumanMale_Soldier_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "HumanMale_Vanguard_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Krogan_Sentinel_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Krogan_Soldier_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Quarian_Engineer_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Quarian_Infiltrator_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Salarian_Infiltrator_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Salar_Engineer_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Turian_Sentinel_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Turian_Soldier_MP", Enabled = true},
            // BioWare chickened out of making a female BF3 soldier
            new KitSpecificPipeline() { PackageName = "HumanFemale_InfBF3_MP", Enabled = true, PostCorrections = BF3Infiltrator.ApplyPostFixes},

            // MP1
            new KitSpecificPipeline() { PackageName = "AsariCommando_Adept_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Batarian_Soldier_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Geth_Engineer_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Batarian_Sentinel_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Geth_Infiltrator_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Krogan_Vanguard_MP", Enabled = true},

            // MP2
            new KitSpecificPipeline() { PackageName = "Cerberus_Adept_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Vorcha_Soldier_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "QuarianMale_Engineer_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Vorcha_Sentinel_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "QuarianMale_Infiltrator_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Cerberus_Vanguard_MP", Enabled = true},

            // MP3
            new KitSpecificPipeline() { PackageName = "N7_Vanguard_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "N7_Soldier_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "N7_Adept_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "N7_Sentinel_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "N7_Infiltrator_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "N7_Engineer_MP", Enabled = true},

            // MP4
            new KitSpecificPipeline() { PackageName = "Krogan_Adept_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Volus_Adept2_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Batarian_Adept_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "MQuarian_Soldier_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "N7Turian_Soldier_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Geth_Soldier_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Vorcha_Engineer_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Turian_Engineer_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Volus_Engineer_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Asari_Sentinel_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Volus_Sentinel_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Asari_Infiltrator_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "N7Turian_Infiltrator_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Drell_Infiltrator_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Batarian_Vanguard_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Volus_Vanguard_MP", Enabled = true},


            // MP5
            new KitSpecificPipeline() { PackageName = "Merc_Engineer_MP", Enabled = true}, // This kit is soooo broken due to him using different input system
            new KitSpecificPipeline() { PackageName = "Collector_Adept_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "Fembot_Infiltrator_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "GethDest_Soldier_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "KroganWarlord_Sentinel_MP", Enabled = true},
            new KitSpecificPipeline() { PackageName = "TurianFemale_Vanguard_MP", Enabled = true},

        };
    }
}
