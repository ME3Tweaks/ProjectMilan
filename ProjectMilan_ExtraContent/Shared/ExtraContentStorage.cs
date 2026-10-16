using LegendaryExplorerCore.Audio;
using LegendaryExplorerCore.Coalesced;
using LegendaryExplorerCore.Coalesced.Config;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.TLK;
using LegendaryExplorerCore.TLK.ME2ME3;
using ProjectMilan;
using ProjectMilan.Utility;
using ProjectMilan_ExtraContent.Shared;
using ProjectMilanCore;
using ProjectMilanCore.Config;
using Serilog;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection.Metadata;
using System.Text;
using System.Threading.Tasks;

namespace ProjectMilan_ExtraContent.Shared
{
    /// <summary>
    /// Used to define what DLC is being built.
    /// </summary>
    public enum EExtraContent
    {
        None, // Invalid.
        Rejects,
        Redemption
    }

    internal static class ExtraContentStorage
    {
        /// <summary>
        /// The current building content. Only used in EC pipelines.
        /// </summary>
        internal static EExtraContent CurrentContent; 

        /// <summary>
        /// Sets up the mod folder with blank TLK/Config and a mount.dlc file. This only runs in EC mode.
        /// </summary>
        /// <param name="content"></param>
        internal static void PrepareContent(EExtraContent content)
        {
            if (content == EExtraContent.None)
                return;

            // Generate a basic working mod.
            CurrentContent = content;
            switch (content)
            {
                case EExtraContent.Rejects:
                    MilanLog.Information($@"Preparing Rejects content", customPrefix: LOG_CATEGORY);
                    MilanPipelinesShared.OutputModPath = Program.Settings.OutputModPathREJ;
                    MilanPipelinesShared.TLKStartIndex = 1000000;
                    break;
                case EExtraContent.Redemption:
                    MilanLog.Information($@"Preparing Redemption content", customPrefix: LOG_CATEGORY);
                    MilanPipelinesShared.OutputModPath = Program.Settings.OutputModPathRED;
                    MilanPipelinesShared.TLKStartIndex = 1002000;
                    break;
                default:
                    MilanLog.Fatal($@"Unknown content type {content}", customPrefix: LOG_CATEGORY);
                    Environment.Exit(1);
                    break;
            }

            var outDir = Directory.CreateDirectory(Path.Combine(MilanPipelinesShared.OutputModPath, @"CookedPCConsole")).FullName;

            // Write mount.dlc
            MilanLog.Information($@"Compiling mount.dlc", customPrefix: LOG_CATEGORY);
            MountFile mf = new MountFile()
            {
                Game = MEGame.LMP,
                MountFlags = new MountFlag(EME3MountFileFlag.LoadsInMultiplayer),
                MountPriority = SharedECPipelines.GetMountPriority(content),
                TLKID = SharedECPipelines.GetTLKID(content)
            };

            mf.WriteMountFile(Path.Combine(outDir, "mount.dlc"));

            // Prepare the TLK data.
            MilanPipelinesShared.InitializeTLKSet();

            //Generate Coalesced.bin for mod
            MilanLog.Information($@"Compiling blank config file for {content}", customPrefix: LOG_CATEGORY);

            using var fs = File.OpenRead(Path.Combine(SharedECPipelines.ECPipelineRoot, "Shared", "Default_DLC_MOD_StarterKit.bin"));
            var files = CoalescedConverter.DecompileGame3ToMemory(fs);

            //Modify coal files for this mod.
            files[@"BioEngine.xml"] = files[@"BioEngine.xml"].Replace(@"StarterKit", SharedECPipelines.GetDLCFolderName(content)[8..]); // Remove DLC_MOD_, update bioengine

            var newMemory = CoalescedConverter.CompileFromMemory(files);
            MilanPipelinesShared.ConfigBundle = ConfigAssetBundle.FromSingleStream(MEGame.LMP, newMemory);

            // Standalone EC output is only for development for performances - the final mod always gets these maps via the pipelines
            // rolled into ProjectMilan itself - but starting well above anything the main mod will ever
            // allocate on its own keeps a developer's standalone build from ever colliding if installed
            // side by side with it.
            MapIdAllocator.ResetCounter(60);

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
            var mdPath = Path.Combine(MilanPipelinesShared.OutputModPath, "..", "moddesc.ini");
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

        /// <summary>
        /// DLC Build version (EC only)
        /// </summary>
        private static readonly Version CURRENT_VERSION = new Version(1, 0);

        private const string LOG_CATEGORY = @"MILAN-ExtraContent-INIT";

        /// <summary>
        /// Since we are pulling in content from SP DLC we must compact the TFC or the texture data will not be valid.
        /// </summary>
        /// <param name="content"></param>
        public static void CompactTFC(EExtraContent content, bool lighting)
        {
            // Step 2: TFC Compactor
            var inputFolder = Path.Combine(MilanPipelinesShared.OutputModPath, @"CookedPCConsole");
            var staging = Directory.CreateDirectory(Path.Combine(inputFolder, "Staging")).FullName;

            // Source DLCs textures may be pulled in from. Lighting vs non-lighting is not determined by which of
            // these a texture currently lives in (a pack's lightmaps aren't guaranteed to live in a separate
            // Lighting_ TFC - e.g. Pack003_Base keeps them in its Textures_ TFC), so both prefixes are searched for
            // every source and the actual split is done below via RootTexturesOnly (root export == lightmap).
            var sourcePacks = new List<string>()
            {
                SharedECPipelines.GetDLCFolderName(content),
                "DLC_CON_GUN01",
                "DLC_CON_GUN02",
                "DLC_HEN_PR",
                "DLC_EXP_Pack001",
                "DLC_EXP_Pack002",
                "DLC_EXP_Pack003",
                "DLC_EXP_Pack003_Base",
                "DLC_METR_Patch01",
            };

            TFCCompactorInfoPackage info = new TFCCompactorInfoPackage()
            {
                Game = MEGame.LE3, // LE3 is fine here
                BaseCompactionPath = inputFolder,
                DLCName = SharedECPipelines.GetDLCFolderName(content),
                GamePath = LE3Directory.DefaultGamePath,
                TFCsToCompact = sourcePacks.SelectMany(p => new[] { $"Textures_{p}", $"Lighting_{p}" }).ToList(),
                UseIndexing = false,
                IncludeNumberedSourceTFCs = true,
                StagingPath = staging,
                TFCType = lighting ? "Lighting" : "Textures",
                RootTexturesOnly = lighting, // Milan-specific: split compaction into separate Lighting/Textures TFCs by root (lightmap) position
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
        }

        /// <summary>
        /// Since we are pulling in content from SP DLC we must compact the AFC or the audio data will not be valid.
        /// </summary>
        /// <param name="content"></param>
        public static void CompactAFC(EExtraContent content)
        {
            // Step 2: TFC Compactor
            var inputFolder = Path.Combine(MilanPipelinesShared.OutputModPath, @"CookedPCConsole");
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
                referencedAudio.availableAFCReferences.Where(x => x.AFCName.Contains("DLC_EXP", StringComparison.OrdinalIgnoreCase)).ToList(), null,
                (done, total) =>
            {
                MilanLog.Information($"Progress: {done}/{total}", customPrefix: LOG_CATEGORY);
            });
        }

        /// <summary>
        /// Saves TLK and the DLC config file
        /// </summary>
        internal static void SaveContent(bool mergeStaticTLK = false)
        {
            // Ensure this does not save any packages as this comes after the licensee pipeline is run.
            var outDir =  Path.Combine(MilanPipelinesShared.OutputModPath, @"CookedPCConsole");

            // Write TLK files
            TLKStarterKit.AssignAndAppend($"{CurrentContent} Developer DLC module", SharedECPipelines.GetDLCFolderName(CurrentContent));
            foreach(var tlkStrSet in MilanPipelinesShared.TLKSet)
            {
                var lang = tlkStrSet.Key;
                var strs = tlkStrSet.Value;

                foreach (var str in strs)
                {
                    str.Data += '\0';
                }
                var tlkOutPath = Path.Combine(outDir, $"{SharedECPipelines.GetDLCFolderName(CurrentContent)}_{lang}.tlk");
                HuffmanCompression.SaveToTlkFile(tlkOutPath, strs);
            }

            // Standalone Rejects creates its destination TLKs here. Merge its fixed XML refs only
            // after those files exist; the in-process ProjectMilan path merges them into its base TLKs.
            if (mergeStaticTLK)
            {
                SharedECPipelines.MergeTLK(CurrentContent);
            }


            // Write Config Bundle
            MilanPipelinesShared.CommitConfigBundle();

            // Reset so next users are forced to set it up properly
            MilanPipelinesShared.Reset();
            CurrentContent = EExtraContent.None;
        
        }
    }
}
