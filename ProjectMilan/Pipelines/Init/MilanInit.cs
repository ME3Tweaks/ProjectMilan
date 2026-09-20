using System.IO.Compression;
using System.Net;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using Newtonsoft.Json;
using ProjectMilan.Pipelines.Shared;
using ProjectMilan.Utility;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Init
{
    /// <summary>
    /// Handles data initialization for Project Milan, such as loading object databases and syncing data
    /// </summary>
    internal class MilanInit
    {
        private const string LOG_CATEGORY = @"MILAN-Init";

        /// <summary>
        /// JSON Definition that is served by project server endpoint
        /// </summary>
        class SyncFile
        {
            [JsonProperty("name")]
            public string FileName { get; set; }

            [JsonProperty("size")]
            public int FileSize { get; set; }

            [JsonProperty("time")]
            public long FileTime { get; set; }
        }

        public static void Init()
        {
            CheckSettings();
            // Install all custom classes that are used for porting
            InventoryCustomPackages();

            // Load object databases

            MilanShared.LE3ObjectDB = MilanInitShared.LoadObjectDB(MEGame.LE3);
            MilanShared.ME3ObjectDB = MilanInitShared.LoadObjectDB(MEGame.ME3);

            WriteDonorOutputPath(); // For development
            SharedMaterialDonor.RegisterSharedDonors();
        }

        /// <summary>
        /// Writes the location of the global donor folder for use in LEX - so it is not stored in a repo visible to people.
        /// Hello someone from the future reading this
        /// </summary>
        public static void WriteDonorOutputPath()
        {
            try
            {
                Utilities.WriteRegistryKey(@"HKEY_CURRENT_USER\Software\ME3Tweaks", @"DonorOutputPath", SharedMaterialDonor.GetGlobalDonorPath());
            }
            catch (Exception e)
            {
                MilanLog.Error($@"Could not write donor output location to registry: {e.Message}");
            }
        }

        /// <summary>
        /// Loads custom made packages e.g. premade assets
        /// </summary>
        public static void InventoryCustomPackages()
        {
            foreach (var packagePath in Directory.GetFiles(Path.Combine(MilanShared.PipelineRoot, @"Shared", @"Compiling"), "*.pcc", SearchOption.AllDirectories))
            {
                MilanLog.Information($"Inventorying custom package {packagePath}");
                using var p = MEPackageHandler.OpenMEPackage(packagePath);
                foreach (var ex in p.Exports.Where(x => x.IsClass))
                {
                    var classInfo = GlobalUnrealObjectInfo.generateClassInfo(ex);
                    MilanLog.Information($@"  Inventorying class {ex.InstancedFullPath}");
                    GlobalUnrealObjectInfo.InstallCustomClassInfo(ex.ObjectName, classInfo, ex.Game);

                    if (ex.InheritsFrom("SequenceObject"))
                    {
                        var defaults = p.GetUExport(ObjectBinary.From<UClass>(ex).Defaults);
                        GlobalUnrealObjectInfo.GenerateSequenceObjectInfoForClassDefaults(defaults);
                    }
                }
            }
        }

        private static void CheckSettings()
        {
            if (Program.Settings.OutputModPath == null)
            {
                MilanLog.Error(@"You must specify an output path in your settings class.");
                Environment.Exit(1);
                return;
            }
        }
    }
}
