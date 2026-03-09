using LegendaryExplorerCore.Coalesced;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using ProjectMilan;
using ProjectMilanCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Audio;
using LegendaryExplorerCore.TLK.ME2ME3;
using LegendaryExplorerCore.TLK;
using Serilog;
using ProjectMilan.Utility;
using LegendaryExplorerCore.Textures;

namespace ProjectMilan_ExtraContent.Shared
{
    /// <summary>
    /// Used to define content.
    /// </summary>
    public enum EExtraContent
    {
        None, // Invalid.
        Rejects,
        Redemption
    }

    internal static class ExtraContentInit
    {
        /// <summary>
        /// Sets up the mod folder with blank TLK/Config and a mount.dlc file.
        /// </summary>
        /// <param name="content"></param>
        internal static void PrepareContent(EExtraContent content)
        {
            if (content == EExtraContent.None)
                return;

            // Generate a basic working mod.
            var outDir = Directory.CreateDirectory(Path.Combine(BaseBuildSettings.OutputModPath, @"CookedPCConsole")).FullName;

            // Write mount.dlc
            MilanLog.Information($@"Compiling mount.dlc", customPrefix: LOG_CATEGORY);
            MountFile mf = new MountFile()
            {
                Game = MEGame.LE3,
                MountFlags = new MountFlag(EME3MountFileFlag.LoadsInMultiplayer),
                MountPriority = SharedECPipelines.GetMountPriority(content),
                TLKID = SharedECPipelines.GetTLKID(content)
            };

            mf.WriteMountFile(Path.Combine(outDir, "mount.dlc"));

            // Compile TLKs
            foreach (var lang in Enum.GetValues(typeof(MELocalization)).Cast<MELocalization>())
            {
                if (lang == MELocalization.None)
                    continue;

                MilanLog.Information($@"Compiling blank TLK for {content} - {lang}", customPrefix: LOG_CATEGORY);

                // From M3C DLCModGenerator
                List<TLKStringRef> strs = new List<TLKStringRef>();
                strs.Add(new TLKStringRef(mf.TLKID, content.ToString() + " Developer DLC module"));
                strs.Add(new TLKStringRef(mf.TLKID + 1, SharedECPipelines.GetDLCFolderName(content)));
                strs.Add(new TLKStringRef(mf.TLKID + 2, lang.ToString()));
                strs.Add(new TLKStringRef(mf.TLKID + 3, @"Male"));
                strs.Add(new TLKStringRef(mf.TLKID + 3, @"Female"));

                foreach (var str in strs)
                {
                    str.Data += '\0';
                }

                var tlk = Path.Combine(outDir, $@"{SharedECPipelines.GetDLCFolderName(content)}_{lang}.tlk");
                HuffmanCompression.SaveToTlkFile(tlk, strs);
            }

            //Generate Coalesced.bin for mod
            MilanLog.Information($@"Compiling blank config file for {content}", customPrefix: LOG_CATEGORY);

            using var fs = File.OpenRead(Path.Combine(SharedECPipelines.ECPipelineRoot, "Shared", "Default_DLC_MOD_StarterKit.bin"));
            var files = CoalescedConverter.DecompileGame3ToMemory(fs);
            //Modify coal files for this mod.
            files[@"BioEngine.xml"] = files[@"BioEngine.xml"].Replace(@"StarterKit", SharedECPipelines.GetDLCFolderName(content)[8..]); // Remove DLC_MOD_, update bioengine

            var newMemory = CoalescedConverter.CompileFromMemory(files);
            var outpath = Path.Combine(outDir, $@"Default_{SharedECPipelines.GetDLCFolderName(content)}.bin");
            File.WriteAllBytes(outpath, newMemory.ToArray());

            // Add precomputed files to the CookedPCConsole folders
            //foreach (var dir in Directory.GetDirectories(Path.Combine(MilanShared.PipelineRoot, @"Mod"))
            //             .Where(x => x.StartsWith("Precomputed")))
            //{
            //    var targetName = dir.Substring("Precomputed".Length);
            //    var targetDir = Path.Combine(outDir, targetName);
            //    var cookedOut = Path.Combine(targetDir, "CookedPCConsole");
            //    if (!Directory.Exists(cookedOut))
            //    {
            //        Directory.CreateDirectory(cookedOut);
            //    }

            //    foreach (var file in Directory.GetFiles(dir, "*.*", SearchOption.AllDirectories))
            //    {
            //        MilanLog.Information($"Copying precomputed file {Path.GetFileName(file)} to mod", customPrefix: LOG_CATEGORY);
            //        File.Copy(file, Path.Combine(cookedOut, Path.GetFileName(file)), true);
            //    }
            //}

            // This is here as it will be at point where mod should be deployable for templating.
            // Check moddesc version
            var mdPath = Path.Combine(BaseBuildSettings.OutputModPath, "..", "moddesc.ini");
            if (File.Exists(mdPath))
            {
                var di = DuplicatingIni.LoadIni(mdPath);
                var mdVer = di.GetOrAddSection("ModInfo")["modver"]; // getoradd prevents exceptions, we are not saving.
                if (mdVer.HasValue && Version.TryParse(mdVer.Value, out var actualVersion) && actualVersion < CURRENT_VERSION)
                {
                    MilanLog.Fatal($"moddesc.ini needs updated. Current version: {actualVersion}, Supported version: {CURRENT_VERSION}. Download a new templated version from #links in the Project Milan Discord", customPrefix: LOG_CATEGORY);
                    Environment.Exit(1);
                }
            }
        }


        private static readonly Version CURRENT_VERSION = new Version(1, 0);

        private const string LOG_CATEGORY = @"MILAN-ExtraContent-INIT";

        /// <summary>
        /// Since we are pulling in content from SP DLC we must compact the TFC or the texture data will not be valid.
        /// </summary>
        /// <param name="content"></param>
        public static void CompactTFC(EExtraContent content, bool rootTextures)
        {
            // Step 2: TFC Compactor
            var inputFolder = Path.Combine(BaseBuildSettings.OutputModPath, @"CookedPCConsole");
            var staging = Directory.CreateDirectory(Path.Combine(inputFolder, "Staging")).FullName;

            // This needs updated to split lighting and textures
            // right now it just packs everything into single Textures TFC.
            TFCCompactorInfoPackage info = new TFCCompactorInfoPackage()
            {
                Game = MEGame.LE3,
                BaseCompactionPath = inputFolder,
                DLCName = SharedECPipelines.GetDLCFolderName(content),
                GamePath = LE3Directory.DefaultGamePath,
                TFCsToCompact = new List<string>()
                {
                    $"Textures_{SharedECPipelines.GetDLCFolderName(content)}",
                    "Textures_DLC_CON_GUN01",
                    "Textures_DLC_CON_GUN02",
                    "Textures_DLC_HEN_PR",
                    "Textures_DLC_EXP_Pack001",
                    "Textures_DLC_EXP_Pack002",
                    "Textures_DLC_EXP_Pack003",
                    "Textures_DLC_EXP_Pack003_Base",
                },
                UseIndexing = false,
                StagingPath = staging,
                TFCType = rootTextures ? "Lighting" : "Textures",
            };

            MilanLog.Information("Compacting TFC", customPrefix: LOG_CATEGORY);
            TFCCompactor.CompactTFC(info, x => MilanLog.Error(x, customPrefix: LOG_CATEGORY), (text, done, total) =>
            {
                if (text != null)
                {
                    MilanLog.Information($"  {text}", customPrefix: LOG_CATEGORY);
                }
                if (total > 0)
                {
                    MilanLog.Information($"  Progress: {done}/{total}", customPrefix: LOG_CATEGORY);
                }
                else if (done == -1 && total == -1)
                {

                }
            });
            Directory.Delete(staging);
        }

        /// <summary>
        /// Since we are pulling in content from SP DLC we must compact the TFC or the texture data will not be valid.
        /// </summary>
        /// <param name="content"></param>
        public static void CompactAFC(EExtraContent content)
        {
            // Step 2: TFC Compactor
            var inputFolder = Path.Combine(BaseBuildSettings.OutputModPath, @"CookedPCConsole");
            var staging = Directory.CreateDirectory(Path.Combine(inputFolder, "Staging")).FullName;
            MilanLog.Information("Scanning for audio references", customPrefix: LOG_CATEGORY);
            var referencedAudio = AFCCompactor.GetReferencedAudio(MEGame.LE3, inputFolder,
            (done, total) =>
            {
                    MilanLog.Information($"Progress: {done}/{total}", customPrefix: LOG_CATEGORY);
                });

            MilanLog.Information("Compacting AFC", customPrefix: LOG_CATEGORY);
            // I don't know if it matters but technically to follow game this should be split up into localized files.
            AFCCompactor.CompactAFC(MEGame.LE3, inputFolder, $"{SharedECPipelines.GetDLCFolderName(content)}_Audio", 
                referencedAudio.availableAFCReferences.Where(x=>x.AFCName.Contains("DLC_EXP", StringComparison.OrdinalIgnoreCase)).ToList(), null, 
                (done, total) =>
            {
                MilanLog.Information($"Progress: {done}/{total}", customPrefix: LOG_CATEGORY);
            });
        }
    }
}
