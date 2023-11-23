using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO.Compression;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using CliWrap;
using CliWrap.EventStream;
using CsvHelper;
using CsvHelper.Configuration;
using LegendaryExplorerCore.Audio;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using NAudio.Codecs;
using ProjectMilan.Pipelines.Audio.Extension;
using ProjectMilan.Utility;
using WwiseTools.Objects;
using WwiseTools.Src.Models.SoundBank;
using WwiseTools.Utils;
using WwiseTools.Utils.SoundBank;

namespace ProjectMilan.Pipelines.Audio
{
    /// <summary>
    /// Pipeline for extracting audio from ME3 and porting it to LE3 WwiseBanks
    /// </summary>
    internal class AudioRebuild
    {
        private const string LOG_CATEGORY = @"MILAN-Audio";

        // Expected pipeline:
        // 1. Go through ME3 package files and find all WwiseBanks that are not in LE (using object database?)
        // 2. Extract all WwiseBanks from them to disk.
        // 3. Extract all audio from WwiseBank and WwiseStreams to disk
        // 4. Decompile WwiseBank to gather information about what is needed to rebuild. Things like attenuation and stuff (this will probably be the worst step)
        // 5. Build new LE versions of banks using the Wwise Authoring API (WAAPI)
        // 6. Inject the new banks into the compiled mod files
        // This will probably be one of the later pipelines
        public static void RunPipeline()
        {
            ExtractWwiseBanks();
        }

        private static void ExtractWwiseBanks()
        {
            // Basegame
            // Figure out where to put this so it isn't in the repo.
            // Contains FRA and DEU audio as well as INT. Not sure where POL or ITA went
            var mpBasegameZip = Path.Combine(@"G:\My Drive\Mass Effect Legendary Modding\ProjectMilan", @"MPBasegame.zip");
            var archive = ZipFile.OpenRead(mpBasegameZip);
            foreach (var e in archive.Entries)
            {
                if (!e.Name.RepresentsPackageFilePath())
                    continue;

                var decomp = MEPackageHandler.OpenMEPackageFromStream(e.Decompress(), e.Name);
                foreach (var exp in decomp.Exports.Where(x => x.ClassName == @"WwiseBank"))
                {
                    var matchingObjects = MilanShared.LE3ObjectDB.GetFilesContainingObject(exp.InstancedFullPath);
                    if (matchingObjects == null)
                    {
                        // Needs extracted
                        ExtractWwiseBank(exp);
                    }
                }
            }
        }

        private static void PatchWwise()
        {
            // Patches Wwise to allow more than 200 items in project
            var patchedHash = "cc53c44bd910450e491ba58ad7cfbf23";
            var originalHash = "2047479374e10c4d49cb09d6cf233a73";

            var fileToPatch = Environment.ExpandEnvironmentVariables("%WWISEROOT%\\Authoring\\x64\\Release\\bin\\LicenceMgr.dll");
            var hash = Utilities.CalculateHash(fileToPatch);
            if (hash == patchedHash)
                return; // No need
            if (hash == originalHash)
            {
                MilanLog.Information($"Backing up {Path.GetFileName(fileToPatch)}", customPrefix: LOG_CATEGORY);
                var savePath = Path.Combine(MilanShared.PipelineRoot, "Audio", "WwiseBackup");
                Directory.CreateDirectory(savePath);
                File.Copy(fileToPatch, Path.Combine(savePath, Path.GetFileName(fileToPatch)));

                MilanLog.Information($"Patching {Path.GetFileName(fileToPatch)}", customPrefix: LOG_CATEGORY);
                var data = new MemoryStream(File.ReadAllBytes(fileToPatch));
                data.Seek(0x39DE, SeekOrigin.Begin);
                data.WriteInt32(100000);

                // May require admin rights for this operation to succeed.
                data.WriteToFile(fileToPatch);
            }
        }

        /// <summary>
        /// Extracts an ME3 WwiseBank to a .bnk file
        /// </summary>
        /// <param name="export"></param>
        private static void ExtractWwiseBank(ExportEntry export)
        {
            if (export.Game != MEGame.ME3)
                throw new Exception("This method is only for extracting ME3 WwiseBanks!");

            var outPath = Path.Combine(Program.Settings.OutputModPath, @"ME3", @"WwiseBanks", export.ObjectName);
            var outBankPath = Path.Combine(outPath, $"{export.ObjectName}.bnk");
            if (File.Exists(outBankPath))
                return;
            Directory.CreateDirectory(outPath);

            MilanLog.Information($"Extracting WwiseBank {export.ObjectName}", customPrefix: LOG_CATEGORY);
            // Taken from LEX Package Editor
            var data = new MemoryStream(export.GetBinaryData());
            if (export.Game.IsGame3())
            {
                data.Skip(0x10);
            }
            else if (export.Game.IsGame2())
            {
                data.Skip(0x18);
            }

            using FileStream fs = new FileStream(outBankPath, FileMode.Create);
            data.CopyToEx(fs, (int)data.Length - 0x10);
        }

        /// <summary>
        /// Information about ME3 sound bank that is being ported to LE3
        /// </summary>
        class MilanBankInfo
        {
            /// <summary>
            /// The bank export
            /// </summary>
            public ExportEntry BankEntry { get; set; }

            /// <summary>
            /// ME3 has one event map to one stream. LE3 lists all streams in every event.
            /// </summary>
            public Dictionary<ExportEntry, ExportEntry> EventToStreamMap { get; } = new();

            public string LogCategory => $"MILAN-Audio-{BankEntry.ObjectName}";

            // Eventually we will need additional information such as random containers.
        }

        public static void TestDecomp()
        {
            if (!VGMAudioStreamHelper.EnsureVGMStream())
            {
                MilanLog.Fatal("Could not ensure VGMStream is available. This should be automatically corrected by MilanSync.");
                Environment.Exit(1);
            }

            var me3P = MilanShared.GetME3Package("BioSimpleDlgContainer_Horde_LOC_INT.pcc");
            List<MilanBankInfo> bankInfos = new List<MilanBankInfo>();

            // 1. Find banks
            foreach (var bank in me3P.Exports.Where(x => x.ClassName == "WwiseBank"))
            {
                bankInfos.Add(new MilanBankInfo() { BankEntry = bank });
            }

            // Find events of banks
            foreach (var evt in me3P.Exports.Where(x => x.ClassName == "WwiseEvent"))
            {
                var bank = evt.GetProperty<StructProperty>("Relationships").GetProp<ObjectProperty>("Bank").ResolveToEntry(me3P) as ExportEntry;
                var bankInfo = bankInfos.First(x => x.BankEntry == bank);
                var wwiseBin = ObjectBinary.From<WwiseEvent>(evt);
                if (wwiseBin.Links != null && wwiseBin.Links.Count == 1 && wwiseBin.Links[0].WwiseStreams.Count == 1)
                {
                    bankInfo.EventToStreamMap[evt] = me3P.GetUExport(wwiseBin.Links[0].WwiseStreams[0]);
                }
            }

            // Decompile each bank
            var testPackage = MEPackageHandler.CreateAndOpenPackage(Path.Combine(Program.Settings.OutputModPath, Path.GetFileName(me3P.FilePath)), MEGame.LE3);
            foreach (var bank in bankInfos)
            {
                // DecompileME3WwiseBank(bank);
                CompileLE3WwiseBank(bank, testPackage);
            }
            testPackage.Save();
        }

        private static void DecompileME3WwiseBank(MilanBankInfo bankInfo)
        {
            MilanLog.Information($"Decompiling {bankInfo.BankEntry.InstancedFullPath}", customPrefix: bankInfo.LogCategory);
            var outDir = Path.Combine(GetDecompiledBanksFolder(), bankInfo.BankEntry.ObjectName);
            Directory.CreateDirectory(outDir);
            foreach (var se in bankInfo.EventToStreamMap)
            {
                MilanLog.Information($"  Extracting WwiseStream {se.Value.InstancedFullPath}", customPrefix: bankInfo.LogCategory);
                var wwstream = ObjectBinary.From<WwiseStream>(se.Value);
                var waveStream = wwstream.CreateWaveStream();
                var outPath = Path.Combine(outDir, se.Value.ObjectName.Name/*[..^4]*/ + ".wav"); // This removes _wav
                waveStream.WriteToFile(outPath);
            }
        }

        private static string GetDecompiledBanksFolder()
        {
            return Path.Combine(MilanShared.PipelineRoot, "Audio", "DecompiledBanks");
        }

        class WwiseImportRow
        {
            [CsvHelper.Configuration.Attributes.Name("Audio File")]
            public string AudioFile { get; set; }

            [CsvHelper.Configuration.Attributes.Name("Object Path")]
            public string ObjectPath => $@"\Actor-Mixer Hierarchy\Default Work Unit\<Sound SFX>{Path.GetFileNameWithoutExtension(AudioFile)}";

            [CsvHelper.Configuration.Attributes.Name("@OutputBus")]
            public string OutputBus { get; set; }

            [CsvHelper.Configuration.Attributes.Name("@IsStreamingEnabled")]
            public bool Stream { get; set; }

            [CsvHelper.Configuration.Attributes.Name("Event")]
            public string Event { get; set; }

            // Yes a duplicate column. What a stupid system.
            [CsvHelper.Configuration.Attributes.Name("Event")]
            public string Event2 { get; set; }

        }


        private static async void CompileLE3WwiseBank(MilanBankInfo bankInfo, IMEPackage destPackage)
        {
            MilanLog.Information($"Compiling WwiseBank {bankInfo.BankEntry.ObjectName}", customPrefix: bankInfo.LogCategory);
            var wwisePath = Environment.GetEnvironmentVariable("WWISEROOT");
            if (wwisePath == null || !Directory.Exists(wwisePath))
            {
                MilanLog.Error("This pipeline requires Wwise 7110 to be installed. Ensure WWISEROOT is set as an environment variable.", customPrefix: LOG_CATEGORY);
                Environment.Exit(1);
            }


            // Create template project ---------------------
            var wwiseProjectDir = Path.Combine(MilanShared.PipelineRoot, "Audio", "Wwise", "Projects", bankInfo.LogCategory);
            if (Directory.Exists(wwiseProjectDir))
            {
                Utilities.DeleteFilesAndFoldersRecursively(wwiseProjectDir);
            }

            // Extract template
            ZipFile.ExtractToDirectory(Path.Combine(MilanShared.PipelineRoot, "Audio", "Template", "Template.zip"), wwiseProjectDir);
            var wwiseProjectPath = Path.Combine(wwiseProjectDir, "LE3TemplateProject.wproj");

            // Generate CSV records
            var records = new List<WwiseImportRow>();
            foreach (var evtStream in bankInfo.EventToStreamMap)
            {
                var srcDir = Path.Combine(GetDecompiledBanksFolder(), bankInfo.BankEntry.ObjectName);
                var srcFile = Path.Combine(srcDir, evtStream.Value.ObjectName.Name/*[..^4]*/ + ".wav"); // This removes _wav

                var record = new WwiseImportRow()
                {
                    AudioFile = srcFile,
                    Event = $"{evtStream.Key.ObjectName}@Play",
                    OutputBus = @"\Master-Mixer Hierarchy\Default Work Unit\Master Audio Bus\Slowdown and Bleedout Affected\Enviromental\Env-VO\Env-VO-Conversation",
                    Stream = true
                };

                var existingRecord = records.FirstOrDefault(x => x.AudioFile == srcFile);
                if (existingRecord != null)
                {
                    existingRecord.Event2 = $"{evtStream.Key.ObjectName}@Play";
                }

                // Do not add duplicate audio samples
                if (existingRecord == null)
                {
                    records.Add(record);
                }
            }

            // Generate the input CSV - tab delimited
            var csvPath = Path.Combine(wwiseProjectDir, "input.csv");
            using (var writer = new StreamWriter(csvPath))
            {
                using (var csv = new CsvWriter(writer, new CsvConfiguration(CultureInfo.InvariantCulture) { Delimiter = "\t", Encoding = Encoding.UTF8 }))
                {
                    csv.WriteRecords(records);
                }
            }

            // Start WwiseAPI
            KillWwise();
            var cmd = Cli.Wrap(Environment.ExpandEnvironmentVariables("%WWISEROOT%\\Authoring\\x64\\Release\\bin\\WwiseCLI.exe"))
                .WithArguments(new[] { wwiseProjectPath, "-TabDelimitedImport", csvPath, "-ImportLanguage", "English(US)", "-TabDelimitedOperation", "ReplaceExisting", "-Save" });

            var exitCode = RunWwise(cmd, bankInfo.LogCategory).Result; // Do not await this. We want it to continue

            // Add soundbank so it can be generated
            // This has to be done through WwiseAPI, I think
            cmd = Cli.Wrap(Environment.ExpandEnvironmentVariables("%WWISEROOT%\\Authoring\\x64\\Release\\bin\\WwiseCLI.exe"))
                .WithArguments(new[] { wwiseProjectPath, "-Waapi" });
            var result = RunWwise(cmd, bankInfo.LogCategory);

            WwiseUtility.Instance.ConnectAsync().Wait(); // Connect to Wwise
            var parent = WwiseUtility.Instance.GetWwiseObjectByPathAsync(@"\SoundBanks\Default Work Unit").Result;
            var soundBank = WwiseUtility.Instance.CreateObjectAsync(bankInfo.BankEntry.ObjectName, WwiseObject.ObjectType.SoundBank, parent).Result;

            // Add events and sounds
            var StreamsObj = WwiseUtility.Instance.GetWwiseObjectByPathAsync(@"\Actor-Mixer Hierarchy\Default Work Unit").Result;
            var EventsObj = WwiseUtility.Instance.GetWwiseObjectByPathAsync(@"\Events\Default Work Unit").Result;


            WwiseUtility.Instance.AddSoundBankInclusionAsync(soundBank, new SoundBankInclusion() { Object = StreamsObj, Filter = SoundBankInclusionFilter.Everything }).Wait();
            WwiseUtility.Instance.AddSoundBankInclusionAsync(soundBank, new SoundBankInclusion() { Object = EventsObj, Filter = SoundBankInclusionFilter.Everything }).Wait();

            // (bankInfo.BankEntry.ObjectName, WwiseObject.ObjectType.SoundBank, parent);

            WwiseUtility.Instance.SaveWwiseProjectAsync().Wait();

            // Generate sound banks
            WwiseUtility.Instance.DisconnectAsync().Wait(); // Disconnect from Wwise

            // Terminate Wwapi
            KillWwise();


            // WwiseCLI: Generate banks
            cmd = Cli.Wrap(Environment.ExpandEnvironmentVariables("%WWISEROOT%\\Authoring\\x64\\Release\\bin\\WwiseCLI.exe"))
                .WithArguments(new[] { wwiseProjectPath, "-GenerateSoundBanks", "-Verbose" });
            exitCode = RunWwise(cmd, bankInfo.LogCategory).Result;

            // Import banks to package(s)
            var wwiseLang = "English(US)"; // This will have to support others later
            var wwiseBankPath = Path.Combine(wwiseProjectDir, "GeneratedSoundBanks", "Windows", wwiseLang, $"{bankInfo.BankEntry.ObjectName}.bnk");
            WwiseBankImport.ImportBank(wwiseBankPath, true, destPackage, wwiseLang);
        }

        private static void KillWwise()
        {
            var theTerminator = Process.GetProcesses().Where(pr => pr.ProcessName.ToLower() is "wwise" or "wwisecli"); // without '.exe'
            foreach (var process in theTerminator)
            {
                MilanLog.Information($"Terminating Wwise process {process.ProcessName}, PID {process.Id}");
                process.Kill();
            }
        }

        private static async Task<CommandResult> RunWwise(Command cmd, string logCategory)
        {
            cmd = cmd.WithStandardOutputPipe(PipeTarget.ToDelegate(x =>
            {
                MilanLog.Information($"WWISECLI: {x}", customPrefix: logCategory);
            })).WithStandardErrorPipe(PipeTarget.ToDelegate(x =>
            {
                MilanLog.Error($"WWISECLI: {x}", customPrefix: logCategory);
            }));

            return await cmd.ExecuteAsync();
        }
    }
}
