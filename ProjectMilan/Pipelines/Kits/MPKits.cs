using System.Diagnostics;
using JetBrains.Profiler.Api;
using JetBrains.Profiler.SelfApi;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using LegendaryExplorerCore.UnrealScript;

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
            Parallel.ForEach(vars.KitPipelines, new ParallelOptions() { MaxDegreeOfParallelism = Program.Settings.MaxThreads }, kit =>
            {
                // Uncomment this to port everything
                if (/*false &&*/ !kit.Enabled)
                {
                    // This level is not marked for porting currently.
                    MilanLog.Information($"Skipping kit {kit.PackageName}, pipeline is not enabled", customPrefix: LOG_CATEGORY);
                    return;
                }

                BeginPorting(kit);
            });
            // }
        }

        private static void BeginPorting(KitSpecificPipeline kitPipeline)
        {
            kitPipeline.LogCategory = $"{LOG_CATEGORY}-{kitPipeline.PackageName}";

            // Initialize cache
            kitPipeline.Cache = new PackageCache();

            var outputPath = Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole", @"Kits");
            Directory.CreateDirectory(outputPath);

            var finalPackagePath = Path.Combine(outputPath, kitPipeline.PackageName + ".pcc");
            var kitDestPackage = MEPackageHandler.CreateAndOpenPackage(finalPackagePath, MEGame.LE3);
            kitDestPackage.LECLTagData.ImportHintFiles.Add(MilanShared.MP_STARTUP_FILENAME); // Hint this for importing.

            var kitSourcePackage = MilanShared.GetME3Package(kitPipeline.PackageName + ".pcc");

            // Port classes first - this works around weird issue in tools where you're porting across games
            // an entirely new class which doesn't exist in the destination game

            //foreach (var cls in kitSourcePackage.Exports.Where(x => x.IsClass))
            //{
            //    if (kitDestPackage.FindExport(cls.InstancedFullPath) == null)
            //    {
            //        var rop2 = new RelinkerOptionsPackage() { Cache = kitPipeline.Cache, TargetGameDonorDB = MilanShared.LE3ObjectDB };
            //        var results2 = EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, cls,
            //            kitDestPackage, null, true,
            //            rop2,
            //            out var newEntry2);
            //    }
            //}



            MilanShared.PortObjectReferencer(kitSourcePackage, kitDestPackage, kitPipeline.Cache, kitPipeline.LogCategory);
            MilanShared.PortLocalizations(kitPipeline.PackageName, outputPath, kitPipeline.Cache, kitPipeline.LogCategory);

            kitPipeline.Cache.Dispose();
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
                                    kits.Add($"new KitSpecificPipeline() {{ PackageName = \"{package.FileNameNoExtension}\", Enabled = true}},");
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
            new KitSpecificPipeline() { PackageName = "Asari_Adept_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Asari_Vanguard_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Drell_Adept_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Drell_Vanguard_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "HumanFemale_Adept_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "HumanFemale_Engineer_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "HumanFemale_Infiltrator_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "HumanFemale_Sentinel_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "HumanFemale_Soldier_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "HumanFemale_Vanguard_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "HumanMale_Adept_MP", Enabled  = true}, // Default option
            new KitSpecificPipeline() { PackageName = "HumanMale_Engineer_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "HumanMale_Infiltrator_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "HumanMale_Sentinel_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "HumanMale_SoldierBF3_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "HumanMale_Soldier_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "HumanMale_Vanguard_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Krogan_Sentinel_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Krogan_Soldier_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Quarian_Engineer_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Quarian_Infiltrator_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Salarian_Infiltrator_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Salar_Engineer_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Turian_Sentinel_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Turian_Soldier_MP", Enabled  = false},

            // MP1
            new KitSpecificPipeline() { PackageName = "AsariCommando_Adept_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Batarian_Soldier_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Geth_Engineer_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Batarian_Sentinel_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Geth_Infiltrator_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Krogan_Vanguard_MP", Enabled  = false},

            // MP2
            new KitSpecificPipeline() { PackageName = "Cerberus_Adept_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Vorcha_Soldier_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "QuarianMale_Engineer_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Vorcha_Sentinel_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "QuarianMale_Infiltrator_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Cerberus_Vanguard_MP", Enabled  = false},

            // MP3
            new KitSpecificPipeline() { PackageName = "N7_Vanguard_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "N7_Soldier_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "N7_Adept_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "N7_Sentinel_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "N7_Infiltrator_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "N7_Engineer_MP", Enabled  = false},

            // MP4
            new KitSpecificPipeline() { PackageName = "Krogan_Adept_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Volus_Adept2_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Batarian_Adept_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "MQuarian_Soldier_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "N7Turian_Soldier_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Geth_Soldier_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Vorcha_Engineer_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Turian_Engineer_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Volus_Engineer_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Asari_Sentinel_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Volus_Sentinel_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Asari_Infiltrator_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "N7Turian_Infiltrator_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Drell_Infiltrator_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Batarian_Vanguard_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Volus_Vanguard_MP", Enabled  = false},


            // MP5
            new KitSpecificPipeline() { PackageName = "Merc_Engineer_MP", Enabled  = false}, // This kit is soooo broken due to him using different input system
            new KitSpecificPipeline() { PackageName = "Collector_Adept_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "Fembot_Infiltrator_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "GethDest_Soldier_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "KroganWarlord_Sentinel_MP", Enabled  = false},
            new KitSpecificPipeline() { PackageName = "TurianFemale_Vanguard_MP", Enabled  = false},


            // This kit is broken and will require manual fixes. BioWare chickened out of making a female BF3 soldier
            new KitSpecificPipeline() { PackageName = "HumanFemale_InfBF3_MP", Enabled = false},

        };
    }
}
