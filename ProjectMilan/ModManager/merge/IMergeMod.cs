using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;

namespace ME3TweaksModManager.modmanager.objects.mod.merge
{
    public interface IMergeMod
    {
        /// <summary>
        /// Name of the merge mod file, relative to the root of the MergeMods folder in the mod directory
        /// </summary>
        public string MergeModFilename { get; set; }

        /// <summary>
        /// Game this merge mod is for
        /// </summary>
        public MEGame Game { get; set; }

        /// <summary>
        /// List of asset files that are part of this merge mod
        /// </summary>
        public CaseInsensitiveDictionary<MergeAsset> Assets { get; set; }

        /// <summary>
        /// Get the number of total merge operations this mod can apply
        /// </summary>
        /// <returns></returns>
        public int GetMergeCount();
        /// <summary>
        /// Get the weight of all merges for this merge mod for accurate progress tracking.
        /// </summary>
        /// <returns></returns>
        public int GetMergeWeight();

        /// <summary>
        /// Extracts this m3m file to the specified folder
        /// </summary>
        /// <param name="outputfolder"></param>
        public void ExtractToFolder(string outputfolder);

        /// <summary>
        /// Returns a list of strings of files that will be modified by this merge file.
        /// </summary>
        /// <returns></returns>
        IEnumerable<string> GetMergeFileTargetFiles();
    }
}
