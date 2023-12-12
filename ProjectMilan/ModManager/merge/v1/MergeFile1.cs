using System.Diagnostics;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using Newtonsoft.Json;
using ProjectMilan;

namespace ME3TweaksModManager.modmanager.objects.mod.merge.v1
{
    public class MergeFile1
    {
        [JsonProperty(@"filename")]
        public string FileName { get; set; }

        [JsonProperty(@"changes")]
        public List<MergeFileChange1> MergeChanges { get; set; }
        [JsonProperty(@"applytoalllocalizations")] public bool ApplyToAllLocalizations { get; set; }

        [JsonIgnore] public MergeMod1 Parent;

        [JsonIgnore]
        public MergeMod1 OwningMM => Parent;

        public void SetupParent(MergeMod1 mm)
        {
            Parent = mm;
            foreach (var mc in MergeChanges)
            {
                mc.SetupParent(this);
            }
        }

        private bool addMergeTarget(string fileName, CaseInsensitiveDictionary<string> loadedFiles,
            SortedSet<string> targetFiles, Action<int> mergeWeightDelegate)
        {
            if (loadedFiles.TryGetValue(fileName, out string fullpath))
            {
                targetFiles.Add(fullpath);
                return true;
            }
            MilanLog.Warning($@"File not found in game: {fileName}, skipping...");
            mergeWeightDelegate?.Invoke(GetMergeWeightSingle()); // Skip this weight
            return false;
        }

        public int GetMergeCount() => 1;


        /// <summary>
        /// Gets the merge weight for a single file (not to all localizations)
        /// </summary>
        /// <returns></returns>
        public int GetMergeWeightSingle()
        {
            var weight = 0;

            foreach (var v in MergeChanges)
            {
                weight += v.GetMergeWeight();
            }

            Debug.WriteLine($@"Single merge weight for {FileName}: weight");
            return weight;
        }

        public int GetMergeWeight()
        {
            // Merge weight is the number of files to merge multiplied by the amount of a single merge
            var multiplier = 1;
            return multiplier * GetMergeWeightSingle();
        }


        /// <summary>
        /// Validates this MergeFile. Throws an exception if the validation fails.
        /// </summary>
        public void Validate()
        {
            if (FileName == null) throw new Exception("Filename cannot be null in merge mod manifest");
            var safeFiles = MergeModLoader.GetAllowedMergeTargetFilenames(Parent.Game);

            if (!safeFiles.Any(x => FileName.StartsWith(Path.GetFileNameWithoutExtension(x), StringComparison.InvariantCultureIgnoreCase)))
            {
                // Does this catch DLC startups? 
                throw new Exception($"Cannot target non startup file: {FileName}");
            }

            foreach (var mc in MergeChanges)
            {
                mc.Validate();
            }
        }
    }
}
