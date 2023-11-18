using System.IO.Compression;
using System.Net;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using Newtonsoft.Json;
using ProjectMilan.Utility;

namespace ProjectMilan.Pipelines.Init
{
    /// <summary>
    /// Handles data initialization for Project Milan, such as loading object databases and syncing data
    /// </summary>
    internal class MilanInit
    {
        private const string LOG_CATEGORY = @"MILAN-Sync";

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

            // Load object databases
            MilanShared.LE3ObjectDB = LoadObjectDB(MEGame.LE3);
            MilanShared.ME3ObjectDB = LoadObjectDB(MEGame.ME3);
            MilanSync();
        }

        private static void CheckSettings()
        {
            if (Program.Settings.OutputPath == null)
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
                var localFile = Path.Combine(Program.Settings.InputSyncPath, file.FileName);
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
