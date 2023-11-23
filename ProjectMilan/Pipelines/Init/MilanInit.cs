using System.IO.Compression;
using System.Net;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using Newtonsoft.Json;
using ProjectMilan.Utility;

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
            // InventoryCustomPackages(); // Not currently used

            // Load object databases
            MilanShared.LE3ObjectDB = LoadObjectDB(MEGame.LE3);
            MilanShared.ME3ObjectDB = LoadObjectDB(MEGame.ME3);

            // Sync files from ME3Tweaks so developers are all on the same fileset.
            MilanSync();

            // Add global donors
            foreach (var donorF in Directory.GetFiles(Path.Combine(MilanShared.PipelineRoot, "Shared", "GlobalDonors"), "*.pcc", SearchOption.AllDirectories))
            {
                MilanLog.Information($"Inventorying donor package {Path.GetFileName(donorF)}");
                var donorP = MEPackageHandler.UnsafePartialLoad(donorF, x => false);
                MilanShared.LE3ObjectDB.AddFileToDB(donorP, donorF);
            }
        }

        /// <summary>
        /// Gets the path of a file located in the specific sync directory
        /// </summary>
        /// <param name="filename"></param>
        /// <returns></returns>
        public static string GetSyncFile(string filename)
        {
            return Path.Combine(Program.Settings.InputSyncPath, filename);
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
            if (Program.Settings.InputSyncPath == null)
            {
                MilanLog.Error(@"You must specify an input sync path in your settings class.");
                Environment.Exit(1);
                return;
            }
        }

        private const string PROJECT_ENDPOINT = @"https://me3tweaks.com/projects/qB45ZdqYTdve7T7eUjgb";

        private static void MilanSync()
        {
            // Get manifest
            MilanLog.Information(@"Performing MilanSync");
            var manifest = Utilities.GetJsonStringFromEndpoint(PROJECT_ENDPOINT + @"/getinfo");
            if (manifest == null)
            {
                MilanLog.Warning(@"Unable to get manifest from ME3Tweaks. Skipping MilanSync");
            }

            Directory.CreateDirectory(Program.Settings.InputSyncPath);
            var files = JsonConvert.DeserializeObject<List<SyncFile>>(manifest);
            foreach (var file in files)
            {
                var localFile = GetSyncFile(file.FileName);
                bool shouldSync = !File.Exists(localFile);
                if (!shouldSync)
                {
                    shouldSync = new FileInfo(localFile).Length != file.FileSize;
                }

                var filetime = DateTimeOffset.FromUnixTimeSeconds(file.FileTime);
                if (!shouldSync)
                {
                    shouldSync = new FileInfo(localFile).LastWriteTimeUtc != filetime;
                }

                if (!shouldSync)
                {
                    MilanLog.Information($@"Synced file is up to date: {file.FileName}", customPrefix: LOG_CATEGORY);
                    continue;
                }

                MilanLog.Information($@"Updating synced file: {file.FileName}", customPrefix: LOG_CATEGORY);
                using (var client = new WebClient())
                {
                    client.DownloadFile(PROJECT_ENDPOINT + "/files/" + file.FileName, localFile);
                    File.SetLastWriteTimeUtc(localFile, filetime.DateTime);
                }
            }
        }

        private static ObjectInstanceDB LoadObjectDB(MEGame game)
        {
            MilanLog.Information($"Loading {game} object database");
            using var zip = ZipFile.OpenRead(Path.Combine(MilanShared.PipelineRoot, @"Init", $@"{game}ObjectDatabase.zip"));
            var dbStream = zip.GetEntry($"{game}.bin").Open();
            var memStr = new MemoryStream();
            dbStream.CopyTo(memStr);
            memStr.Position = 0;
            return ObjectInstanceDB.Deserialize(game, memStr);

        }
    }
}
