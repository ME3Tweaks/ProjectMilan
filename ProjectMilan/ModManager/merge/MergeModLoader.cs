using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using ME3TweaksModManager.modmanager.objects.mod.merge.v1;
using ProjectMilan;

namespace ME3TweaksModManager.modmanager.objects.mod.merge
{
    public class MergeModLoader
    {
        private const string MERGEMOD_MAGIC = @"M3MM";
        public static IMergeMod LoadMergeMod(Stream mergeFileStream, string filename, bool loadAssets)
        {
            if (mergeFileStream.ReadStringASCII(4) != MERGEMOD_MAGIC)
            {
                throw new Exception("Merge mod has wrong header");
            }

            var version = mergeFileStream.ReadByte();
            switch (version)
            {
                case 1:
                    return MergeMod1.ReadMergeMod(mergeFileStream, filename, loadAssets);
                default:
                    return null;
            }
        }


        // How to specify version?
        public static void SerializeManifest(Stream fs, string inputJson, string inputDir)
        {
            MilanLog.Information($@"M3MCompiler: Serializing merge mod from {inputDir}");
            fs.WriteStringLatin1(MERGEMOD_MAGIC);
            fs.WriteByte((byte)1);
            IList<string> strs = MergeMod1.Serialize(fs, inputJson, inputDir);

            if (strs != null)
            {
                foreach (var str in strs)
                {
                    MilanLog.Error(str, customPrefix: "MILAN-MergeModCompiler");
                }
            }

            MilanLog.Information($@"M3MCompiler: Serialization complete");
        }


        /// <summary>
        /// Decompiles an m3m file into its components.
        /// </summary>
        /// <param name="file">Filepath to decompile</param>
        public static void DecompileM3M(string file)
        {
            using var fs = File.OpenRead(file);
            var mm = LoadMergeMod(fs, file, true);
            mm.ExtractToFolder(Directory.GetParent(file).FullName);
        }

        /// <summary>
        /// Gets the list of allowed files that a mergemod can target for a game.
        /// </summary>
        /// <returns>List of filanmes (with extensions). Startup may have _INT on the end!</returns>
        public static List<string> GetAllowedMergeTargetFilenames(MEGame game)
        {
            var safeFiles = EntryImporter.FilesSafeToImportFrom(game).ToList();
            if (game == MEGame.ME1)
            {
                safeFiles.Add(@"EntryMenu.SFM"); // ME1
            }
            else
            {
                safeFiles.Add(@"EntryMenu.pcc"); // ME2+
            }
            return safeFiles;
        }
    }
}
