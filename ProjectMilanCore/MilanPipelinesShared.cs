using LegendaryExplorerCore.Coalesced.Config;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.TLK;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ProjectMilanCore
{
    /// <summary>
    /// Contains variables that are populated by the hosting project so that projects invoked by it can access them. Also allows redirecting output to a different DLC target if needed.
    /// </summary>
    public class MilanPipelinesShared
    {
        public static readonly MELocalization[] SupportedVOLanguages = new[]
        {
            MELocalization.INT,
            MELocalization.FRA,
            MELocalization.DEU,
            MELocalization.ITA,
            // Any other languages that had VO?
        };

        /// <summary>
        /// Output DLC folder path. Change if you need to redirect output to a different DLC.
        /// </summary>
        public static string OutputModPath { get; set; }

        /// <summary>
        /// Mapping of TLKs being built for the current DLC.
        /// </summary>
        public static Dictionary<MELocalization, List<TLKStringRef>> TLKSet { get; set; }

        /// <summary>
        /// The config bundle for the current DLC.
        /// </summary>
        public static ConfigAssetBundle ConfigBundle { get; set; }

        /// <summary>
        /// Path to the compiled coalesced config for whichever DLC is currently building, derived from
        /// <see cref="OutputModPath"/>'s own folder name - the same convention already used by
        /// SharedECPipelines.MergeConfig, generalized here so it works identically whether that's the main
        /// ProjectMilan mod's own output or ProjectMilan_ExtraContent's separate Redemption/Rejects output.
        /// </summary>
        public static string CurrentConfigBinPath =>
            Path.Combine(OutputModPath, "CookedPCConsole", $"Default_{Path.GetFileName(OutputModPath)}.bin");

        /// <summary>
        /// Loads <see cref="ConfigBundle"/> from whatever's currently compiled at <see cref="CurrentConfigBinPath"/>.
        /// </summary>
        public static void LoadConfigBundle()
        {
            ConfigBundle = ConfigAssetBundle.FromSingleFile(MEGame.LE3, CurrentConfigBinPath);
        }

        /// <summary>
        /// Commits <see cref="ConfigBundle"/>'s current state back to <see cref="CurrentConfigBinPath"/>.
        /// </summary>
        public static void CommitConfigBundle()
        {
            ConfigBundle?.CommitAssets(CurrentConfigBinPath, MELocalization.None);
        }

        /// <summary>
        /// The TLK to use when starting to build. Will throw if not set. Will start +1 from this value.
        /// </summary>
        public static int TLKStartIndex { get; set; }

        /// <summary>
        /// Assigns a set of TLK strings to the current building TLK set and returns the ID assigned to them.
        /// </summary>
        /// <param name="localizationData">A dictionary mapping localizations to their corresponding strings.</param>
        /// <returns>The ID assigned to the set of TLK strings.</returns>
        public static int AssignTLK(Dictionary<MELocalization, string> localizationData)
        {
            if (TLKSet == null)
                throw new Exception("TLKSet is not initialized. Ensure that TLKSet is set before calling AssignTLK.");

            if (TLKStartIndex == 0)
                throw new Exception("TLKStartIndex is not set. Ensure that TLKStartIndex is set before calling AssignTLK.");

            if (localizationData == null)
            {
                return 645785; // "I don't know. Not yet"
            }

            // Get the next highest string assignable ID by finding the maximum StringID in the current TLKSet and adding 1.
            var assignedStringId = TLKSet.Values.SelectMany(list => list).Select(tlk => tlk.StringID).DefaultIfEmpty(TLKStartIndex).Max() + 1;

            foreach (var loc in localizationData)
            {
                TLKSet[loc.Key].Add(new TLKStringRef(assignedStringId, loc.Value));
            }

            return assignedStringId;
        }

        /// <summary>
        /// Resets variables to ensure they are not reused
        /// </summary>
        public static void Reset()
        {
            OutputModPath = null;
            TLKSet = null;
            ConfigBundle = null;
            TLKStartIndex = 0;
        }
    }
}
