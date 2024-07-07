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
using LegendaryExplorerCore.TLK.ME2ME3;
using LegendaryExplorerCore.TLK;
using Serilog;
using ProjectMilan.Utility;

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
                MountPriority = GetMountPriority(content),
                TLKID = GetTLKID(content)
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
                strs.Add(new TLKStringRef(mf.TLKID + 1, GetDLCFolderName(content)));
                strs.Add(new TLKStringRef(mf.TLKID + 2, lang.ToString()));
                strs.Add(new TLKStringRef(mf.TLKID + 3, @"Male"));
                strs.Add(new TLKStringRef(mf.TLKID + 3, @"Female"));

                foreach (var str in strs)
                {
                    str.Data += '\0';
                }

                var tlk = Path.Combine(outDir, $@"{GetDLCFolderName(content)}_{lang}.tlk");
                HuffmanCompression.SaveToTlkFile(tlk, strs);
            }

            //Generate Coalesced.bin for mod
            MilanLog.Information($@"Compiling blank config file for {content}", customPrefix: LOG_CATEGORY);

            using var fs = File.OpenRead(Path.Combine(SharedECPipelines.ECPipelineRoot, "Shared", "Default_DLC_MOD_StarterKit.bin"));
            var files = CoalescedConverter.DecompileGame3ToMemory(fs);
            //Modify coal files for this mod.
            files[@"BioEngine.xml"] = files[@"BioEngine.xml"].Replace(@"StarterKit", GetDLCFolderName(content)[8..]); // Remove DLC_MOD_, update bioengine

            var newMemory = CoalescedConverter.CompileFromMemory(files);
            var outpath = Path.Combine(outDir, $@"Default_{GetDLCFolderName(content)}.bin");
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

        private static string GetDLCFolderName(EExtraContent content) => content switch
        {
            EExtraContent.Rejects => MilanShared.REJECTS_DLC_NAME,
            EExtraContent.Redemption => MilanShared.REDEMPTION_DLC_NAME,
            _ => throw new Exception($"Unknown content: {content}")
        };

        /// <summary>
        /// Gets developer DLC mount priority
        /// </summary>
        /// <param name="content"></param>
        /// <returns></returns>
        /// <exception cref="NotImplementedException"></exception>
        private static int GetMountPriority(EExtraContent content) => content switch
        {
            EExtraContent.Rejects => 12556,
            EExtraContent.Redemption => 12557,
            _ => 0,
        };

        /// <summary>
        /// Gets developer DLC TLK ID
        /// </summary>
        /// <param name="content"></param>
        /// <returns></returns>
        private static int GetTLKID(EExtraContent content) => content switch
        {
            // Random.
            EExtraContent.Rejects => 46578962,
            EExtraContent.Redemption => 58765561,
            _ => 0,
        };

        private static readonly Version CURRENT_VERSION = new Version(1, 0);

        private const string LOG_CATEGORY = @"MILAN-ExtraContent-INIT";
    }
}
