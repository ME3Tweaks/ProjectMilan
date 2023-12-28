using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO.Compression;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Xml.Linq;
using CliWrap;
using CliWrap.EventStream;
using CsvHelper;
using CsvHelper.Configuration;
using LegendaryExplorerCore.Audio;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.UnrealScript.Language.Tree;
using NAudio.Codecs;
using ProjectMilan.Pipelines.Audio.Extension;
using ProjectMilan.Pipelines.Levels;
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
        private const string LOG_CATEGORY = @"MILAN-Audio-Rebuild";

        // Expected pipeline:
        // 1. Go through ME3 package files and find all WwiseBanks that are not in LE (using object database?)
        // 2. Extract all WwiseBanks from them to disk.
        // 3. Extract all audio from WwiseBank and WwiseStreams to disk
        // 4. Decompile WwiseBank to gather information about what is needed to rebuild. Things like attenuation and stuff (this will probably be the worst step)
        // 5. Build new LE versions of banks using the Wwise Authoring API (WAAPI)
        // 6. Inject the new banks into the compiled mod files
        // This will probably be one of the later pipelines
        public static void RunPipeline(List<MilanBankInfo> bankInventory, AudioVars vars)
        {
            MilanLog.Information("The following banks will be built into the WwiseProject:", customPrefix: LOG_CATEGORY);
            foreach (var lifp in bankInventory)
            {
                MilanLog.Information($"  {lifp?.LocalizedInfo}", customPrefix: LOG_CATEGORY);
            }
            
            // Step 0: Create the template project
            // Create template project ---------------------

            // Extract template
            ZipFile.ExtractToDirectory(Path.Combine(MilanShared.PipelineRoot, "Audio", "Template", "Template.zip"), vars.ProjectDir);
            vars.ProjectWPath = Path.Combine(vars.ProjectDir, "LE3TemplateProject.wproj");

            // Generate the WwiseProject
            BuildWwiseProject(vars, bankInventory);

            CompileWwiseBanks(vars);

            // Build banks package
            var generatedRoot = Path.Combine(vars.ProjectDir, "GeneratedSoundBanks", "Windows");
            var banksInfoFile = Path.Combine(generatedRoot, "SoundbanksInfo.xml");
            var bankInfoXml = XDocument.Load(banksInfoFile);

            PackageCache banksCache = new PackageCache();
            var soundBanks = bankInfoXml.Descendants("SoundBank");
            foreach (var soundBank in soundBanks)
            {
                var bankShortName = soundBank.Element("ShortName").Value;
                if (bankShortName == "Init")
                    continue; // Do not care
                var bankWwiseLoc = soundBank.Attribute("Language").Value;
                var bankPath = Path.Combine(generatedRoot, soundBank.Element("Path").Value);
                var bankLocalization = WwiseBankImport.GetMELocalizationFromWwiseLocalization(bankWwiseLoc);

                var bankPackage = GetOrCreateBankPackage(bankLocalization, banksCache);
                WwiseBankImport.ImportBank(bankPath, false, bankPackage, bankWwiseLoc, bankInfoXml,
                    bankInventory.FirstOrDefault(x => x.Export.ObjectName == bankShortName).Export.ParentName, "Int");

                //foreach (var exp in bankPackage.Exports.ToList())
                //{
                //    // This is a hack.
                //    if (exp.ObjectName.Name.EndsWith("_wav_wav"))
                //    {
                //        exp.ObjectName =
                //            new NameReference(exp.ObjectName.Name.Substring(0, exp.ObjectName.Name.Length - 4),
                //                exp.ObjectName.Number);
                //    }
                //}

                bankPackage.Save();
                MilanShared.RefreshMilanFiles = true;
            }

            // Non localized package
            // Todo

            // Finalize: Port banks in
            foreach (var pf in Directory.GetFileSystemEntries(Program.Settings.OutputModPath, "*.pcc", SearchOption.AllDirectories))
            {
                InstallWwiseBanksInto(pf, banksCache);
            }
        }

        private static void InstallWwiseBanksInto(string pf, PackageCache banksCache)
        {
            var packageName = Path.GetFileNameWithoutExtension(pf);
            if (packageName.StartsWith("WwiseBanks"))
                return;

            MilanLog.Information($"Updating Wwise exports in {packageName}", customPrefix: LOG_CATEGORY);
            var package = MEPackageHandler.OpenMEPackage(pf);
            var localizationPackageName = "WwiseBanks";
            if (package.Localization != MELocalization.None)
            {
                localizationPackageName += $"_LOC_{package.Localization}";
            }
            var updatedBanksPackage = banksCache.GetPackages().FirstOrDefault(x => x.FileNameNoExtension == localizationPackageName);
            if (updatedBanksPackage == null)
                return; // We don't have anything for this package right now
            foreach (var f in package.Exports.Where(x => x.ClassName is "WwiseBank" or "WwiseEvent" or "WwiseStream").ToList())
            {
                var matchingUpdate = updatedBanksPackage.FindExport(f.InstancedFullPath);
                if (matchingUpdate == null)
                {
                    // May be already in LE3 format or we goofedi tu p
                    Debug.WriteLine($"Not in converted: {f.InstancedFullPath}");
                    continue;
                }

                EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.ReplaceSingularWithRelink,
                    matchingUpdate, package, f, true,
                    new RelinkerOptionsPackage(), out _);
            }

            if (package.IsModified)
            {
                MilanLog.Information($"  Saving updated package {package.FileNameNoExtension}", customPrefix: LOG_CATEGORY);
                package.Save();
                MilanShared.RefreshMilanFiles = true;
            }
        }

        // Creates or opens the bank package that holds the single copy of localized audio
        private static IMEPackage GetOrCreateBankPackage(MELocalization bankLocalization, PackageCache packageCache)
        {
            var path = Path.Combine(Program.Settings.OutputModPath, "CookedPCConsole", "WwiseBanks");
            if (bankLocalization != MELocalization.None)
            {
                path += $"_LOC_{bankLocalization}";
            }

            path += ".pcc";

            IMEPackage returnPackage;
            if (File.Exists(path))
            {
                returnPackage = MEPackageHandler.OpenMEPackage(path);
            }
            else
            {
                returnPackage = MEPackageHandler.CreateAndOpenPackage(path, MEGame.LE3);
            }

            packageCache.InsertIntoCache(returnPackage);
            return returnPackage;
        }

        /// <summary>
        /// Wwise Language folders. Defined by our custom template.
        /// </summary>
        public static string[] WwiseVOLangs { get; } = new[]
        {
            "English(US)",
            "French(FR)",
            "German(DE)",
            "Italian(IT)"
        };

        private static void CompileWwiseBanks(AudioVars vars)
        {
            KillWwise();
            var cmd = Cli
                .Wrap(Environment.ExpandEnvironmentVariables("%WWISEROOT%\\Authoring\\x64\\Release\\bin\\WwiseCLI.exe"))
                .WithArguments(new[]
                {
                    vars.ProjectWPath, "-GenerateSoundBanks", "-Verbose"
                });
            RunWwise(cmd).Wait();
            Debug.WriteLine("hi");
        }

        /// <summary>
        /// Creates entries in the WwiseProject
        /// </summary>
        /// <param name="vars"></param>
        /// <param name="bankInventory"></param>
        /// <exception cref="NotImplementedException"></exception>
        private static void BuildWwiseProject(AudioVars vars, List<MilanBankInfo> bankInventory)
        {
            foreach (var bankInfo in bankInventory)
            {
                if (bankInfo.LocalizedInfo.Localization is MELocalization.None or MELocalization.INT) // Todo: Requires fixes to this method for locs
                    AddWwiseBankToProject(vars, bankInfo);
            }
        }

        //private static void ExtractWwiseBanks()
        //{
        //    // Basegame
        //    // Figure out where to put this so it isn't in the repo.
        //    // Contains FRA and DEU audio as well as INT. Not sure where POL or ITA went
        //    var mpBasegameZip = Path.Combine(@"G:\My Drive\Mass Effect Legendary Modding\ProjectMilan", @"MPBasegame.zip");
        //    var archive = ZipFile.OpenRead(mpBasegameZip);
        //    foreach (var e in archive.Entries)
        //    {
        //        if (!e.Name.RepresentsPackageFilePath())
        //            continue;

        //        var decomp = MEPackageHandler.OpenMEPackageFromStream(e.Decompress(), e.Name);
        //        ConvertBanks(decomp);

        //        //foreach (var exp in decomp.Exports.Where(x => x.ClassName == @"WwiseBank"))
        //        //{
        //        //    var matchingObjects = MilanShared.LE3ObjectDB.GetFilesContainingObject(exp.InstancedFullPath);
        //        //    if (matchingObjects == null)
        //        //    {
        //        //        // Needs extracted
        //        //        ConvertBanks(exp);
        //        //    }
        //        //}
        //    }
        //}

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

        class WwiseImportRow
        {
            [CsvHelper.Configuration.Attributes.Name("Audio File")]
            public string AudioFile { get; set; }

            [CsvHelper.Configuration.Attributes.Name("Object Path")]
            public string ObjectPath => $@"\Actor-Mixer Hierarchy\Default Work Unit\{BankName}\<{(IsLocalized ? "Sound Voice" : "Sound SFX")}>{Path.GetFileNameWithoutExtension(AudioFile)}";

            [CsvHelper.Configuration.Attributes.Name("@OutputBus")]
            public string OutputBus { get; set; }

            [CsvHelper.Configuration.Attributes.Name("@IsStreamingEnabled")]
            public bool Stream { get; set; }

            [CsvHelper.Configuration.Attributes.Name("Event")]
            public string Event { get; set; }

            // Yes a duplicate column. What a stupid system.
            [CsvHelper.Configuration.Attributes.Name("Event")]
            public string Event2 { get; set; }

            /// <summary>
            /// The name of the bank this is in. Used for sorting.
            /// </summary>
            [CsvHelper.Configuration.Attributes.Ignore()]
            public string BankName { get; set; }

            /// <summary>
            /// Is this audio file localized?
            /// </summary>
            [CsvHelper.Configuration.Attributes.Ignore()]
            public bool IsLocalized { get; set; }

        }

        public static bool EnsureWwise7110()
        {
            var wwisePath = Environment.GetEnvironmentVariable("WWISEROOT");
            if (wwisePath == null || !Directory.Exists(wwisePath))
            {
                MilanLog.Fatal("This pipeline requires Wwise 7110 to be installed. Ensure WWISEROOT is set as an environment variable.", customPrefix: LOG_CATEGORY);
                Environment.Exit(1);
                return false;
            }

            return true;
        }


        private static async void AddWwiseBankToProject(AudioVars vars, MilanBankInfo bankInfo)
        {

            if (bankInfo.EventToStreamMap.Count == 0)
            {
                MilanLog.Warning($"Skipping WwiseBank {bankInfo.Export.ObjectName} - it has no audio streams. Currently we can only port audio streams for banks", customPrefix: LOG_CATEGORY);
                return;
            }
            var wwiseFolderName = bankInfo.Export.ObjectName.Name;

            MilanLog.Information($"Adding WwiseBank {bankInfo.LocalizedInfo.InstancedFullPath} {bankInfo.LocalizedInfo.Localization} to WwiseProject", customPrefix: LOG_CATEGORY);

            // Create folders
            //var wwiseInfo = CreateStreamAndEventsFolder(vars, wwiseFolderName);

            // Generate CSV records for import.
            var records = new List<WwiseImportRow>();
            var srcDir = Path.Combine(AudioPipeline.GetDecompiledBanksFolder(), bankInfo.GetDecompiledFolderName());

            foreach (var evtStream in bankInfo.EventToStreamMap)
            {
                foreach (var wwiseStream in evtStream.Value)
                {
                    // Todo: For objects with multiple voice lines per event we probably need
                    // to put it in a random container.

                    var srcFile = Path.Combine(srcDir, wwiseStream.ObjectName.Name[..^4] + ".wav"); // This removes _wav

                    // Once we have Wwiser.NET up and running we can tune this
                    var record = new WwiseImportRow()
                    {
                        AudioFile = srcFile,
                        Event = $@"{wwiseFolderName}\{evtStream.Key.ObjectName}@Play",
                        OutputBus = @"\Master-Mixer Hierarchy\Default Work Unit\Master Audio Bus\Slowdown and Bleedout Affected\Enviromental\Env-VO\Env-VO-Conversation",
                        Stream = true,
                        BankName = bankInfo.Export.ObjectName.Name,
                        IsLocalized = bankInfo.LocalizedInfo.Localization != MELocalization.None,
                    };

                    var existingRecord = records.FirstOrDefault(x => x.AudioFile == srcFile);
                    if (existingRecord != null)
                    {
                        // Male/Female has a different voice line
                        existingRecord.Event2 = $@"{wwiseFolderName}\{evtStream.Key.ObjectName}@Play";
                    }

                    // Do not add duplicate audio samples
                    if (existingRecord == null)
                    {
                        records.Add(record);
                    }
                }
            }

            // Generate the input CSV - tab delimited
            var csvPath = Path.Combine(srcDir, "input.csv");
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
                .WithArguments(new[] { vars.ProjectWPath, "-TabDelimitedImport", csvPath, "-ImportLanguage", GetWwiseLanguage(bankInfo.LocalizedInfo.Localization), "-TabDelimitedOperation", "ReplaceExisting", "-Save" });

            var exitCode = RunWwise(cmd).Result; // Do not await this. We want it to continue

            // Add soundbank so it can be generated
            // This has to be done through WwiseAPI, I think
            RunWwiseWAAPI(vars);

            WwiseUtility.Instance.ConnectAsync().Wait(); // Connect to Wwise
            var parent = WwiseUtility.Instance.GetWwiseObjectByPathAsync(@"\SoundBanks\Default Work Unit").Result;
            var soundBank = WwiseUtility.Instance.CreateObjectAsync(bankInfo.Export.ObjectName, WwiseObject.ObjectType.SoundBank, parent).Result;

            // Add events and sounds
            var StreamsObj = WwiseUtility.Instance.GetWwiseObjectByPathAsync($@"\Actor-Mixer Hierarchy\Default Work Unit\{wwiseFolderName}").Result;
            var EventsObj = WwiseUtility.Instance.GetWwiseObjectByPathAsync($@"\Events\Default Work Unit\{wwiseFolderName}").Result;


            // Add to soundbank
            WwiseUtility.Instance.AddSoundBankInclusionAsync(soundBank, new SoundBankInclusion() { Object = StreamsObj, Filter = SoundBankInclusionFilter.Everything }).Wait();
            WwiseUtility.Instance.AddSoundBankInclusionAsync(soundBank, new SoundBankInclusion() { Object = EventsObj, Filter = SoundBankInclusionFilter.Everything }).Wait();

            // (bankInfo.BankEntry.ObjectName, WwiseObject.ObjectType.SoundBank, parent);
            // Save the project
            WwiseUtility.Instance.SaveWwiseProjectAsync().Wait();

            // Generate sound banks
            WwiseUtility.Instance.DisconnectAsync().Wait(); // Disconnect from Wwise

            // Terminate Wwapi
            KillWwise();
        }

        private static MilanWwiseProjInfo CreateStreamAndEventsFolder(AudioVars vars, string wwiseFolderName)
        {
            KillWwise();
            RunWwiseWAAPI(vars);
            WwiseUtility.Instance.ConnectAsync().Wait(); // Connect to Wwise

            var returnObj = new MilanWwiseProjInfo()
            {
                StreamsFolder = WwiseUtility.Instance.CreateObjectAtPathAsync($@"\Actor-Mixer Hierarchy\Default Work Unit\{wwiseFolderName}", WwiseObject.ObjectType.Folder).Result,
                EventsFolder = WwiseUtility.Instance.CreateObjectAtPathAsync($@"\Events\Default Work Unit\{wwiseFolderName}", WwiseObject.ObjectType.Folder).Result
            };

            WwiseUtility.Instance.SaveWwiseProjectAsync().Wait(); // Ensure save
            WwiseUtility.Instance.DisconnectAsync().Wait();

            return returnObj;
        }


        private static void GenerateWwiseBanks(AudioVars vars)
        {
            // WwiseCLI: Generate banks
            var cmd = Cli.Wrap(Environment.ExpandEnvironmentVariables(" % WWISEROOT%\\Authoring\\x64\\Release\\bin\\WwiseCLI.exe"))
                .WithArguments(new[] { vars.ProjectWPath, "-GenerateSoundBanks", "-Verbose" });
            var exitCode = RunWwise(cmd).Result;

            // Import banks to package(s)
            //var wwiseLang = "English(US)"; // This will have to support others later
            //var wwiseBankPath = Path.Combine(vars.ProjectDir, "GeneratedSoundBanks", "Windows", wwiseLang, $"{bankInfo.BankEntry.ObjectName}.bnk");
            //WwiseBankImport.ImportBank(wwiseBankPath, true, destPackage, wwiseLang);

        }

        /// <summary>
        /// Starts WwiseCLI in WAAPI mode.
        /// </summary>
        /// <param name="vars"></param>
        private static async void RunWwiseWAAPI(AudioVars vars)
        {
            var cmd = Cli.Wrap(Environment.ExpandEnvironmentVariables("%WWISEROOT%\\Authoring\\x64\\Release\\bin\\WwiseCLI.exe")).WithArguments(new[] { vars.ProjectWPath, "-Waapi" });
            await RunWwise(cmd); // Wait for process to start
        }

        private static string GetWwiseLanguage(MELocalization loc)
        {
            switch (loc)
            {
                // Reference language
                case MELocalization.INT:
                    return "English(US)";

                // These are added to the project
                case MELocalization.DEU:
                    return "German(DE)";
                case MELocalization.FRA:
                    return "German(DE)";
                case MELocalization.ITA:
                    return "Italian(IT)";
            }

            // I have no idea lol
            return "SFX";
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

        private static async Task<bool> RunWwise(Command cmd)
        {
            cmd = cmd.WithValidation(CommandResultValidation.None).WithStandardOutputPipe(PipeTarget.ToDelegate(x =>
            {
                MilanLog.Information($"WWISECLI: {x}", customPrefix: LOG_CATEGORY);
            })).WithStandardErrorPipe(PipeTarget.ToDelegate(x =>
            {
                MilanLog.Error($"WWISECLI: {x}", customPrefix: LOG_CATEGORY);
            }));

            var exitCode = await cmd.ExecuteAsync();
            if (exitCode.ExitCode is -1 or 0) // -1 means we killed the process. That's fine. 0 means OK
                return true;
            return false;
        }
    }

    /// <summary>
    /// Information cache about WwiseProject stuff.
    /// </summary>
    internal class MilanWwiseProjInfo
    {
        public WwiseObject StreamsFolder { get; set; }
        public WwiseObject EventsFolder { get; set; }
    }

    /// <summary>
    /// Represents an object path with respect to localization
    /// </summary>
    internal class LocalizedIFP
    {
        public string InstancedFullPath { get; set; }
        public MELocalization Localization { get; set; }

        public override bool Equals(object other)
        {
            var otherLIFP = other as LocalizedIFP;
            if (otherLIFP == null)
                return false;

            return otherLIFP.Localization == Localization && otherLIFP.InstancedFullPath == InstancedFullPath;
        }

        public override string ToString()
        {
            if (Localization == MELocalization.None)
            {
                return InstancedFullPath;
            }

            return $"{InstancedFullPath}({Localization})";
        }
    }
}
