using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace ProjectMilan.Utility
{
    public static class BioTier
    {
        // From ME2R/LE2R
        private static Regex isPersistentPackage = new Regex("BioP_[A-Za-z0-9]+.pcc", RegexOptions.Compiled | RegexOptions.IgnoreCase);
        private static Regex isMasterTierPackage = new Regex("Bio([ADS]|Snd)_[A-Za-z0-9]+.pcc", RegexOptions.Compiled | RegexOptions.IgnoreCase);
        private static Regex isSublevelPackage = new Regex("Bio([ADPS]|Snd)_[A-Za-z0-9]+_[A-Za-z0-9_]+.pcc", RegexOptions.Compiled | RegexOptions.IgnoreCase);

        /// <summary>
        /// Is this a BioP file?
        /// </summary>
        /// <param name="pName"></param>
        /// <returns></returns>
        public static bool IsPersistentPackage(string pName)
        {
            return isPersistentPackage.IsMatch(pName);
        }

        /// <summary>
        /// Is this a top level master file (BioS/D/A/Snd ?)
        /// </summary>
        /// <param name="pName"></param>
        /// <returns></returns>
        public static bool IsMasterTierPackage(string pName)
        {
            return isMasterTierPackage.IsMatch(pName);
        }

        /// <summary>
        /// Is this a sub file?
        /// </summary>
        /// <param name="pName"></param>
        /// <returns></returns>
        public static bool IsLevelSubfile(string pName)
        {
            return isSublevelPackage.IsMatch(pName);
        }

        /// <summary>
        /// Is this a localization file?
        /// </summary>
        /// <param name="pName"></param>
        /// <returns></returns>
        public static bool IsLocalizationPackage(string pName)
        {
            return pName.Contains("_LOC_");
        }

        /// <summary>
        /// Is this an SFX[something] package?
        /// </summary>
        /// <param name="pName"></param>
        /// <returns></returns>
        public static bool IsSFXPackage(string pName)
        {
            return pName.StartsWith("SFX");
        }
    }


    class ObjectSourceTierComparer : Comparer<string>
    {
        public override int Compare(string file1, string file2)
        {
            // Higher score means it rates further down the list.
            return GetScore(file1).CompareTo(GetScore(file2));
        }

        private int GetScore(string file)
        {
            if (BioTier.IsSFXPackage(file)) return 0;
            if (BioTier.IsPersistentPackage(file)) return 1;
            if (BioTier.IsMasterTierPackage(file)) return 2;
            if (BioTier.IsLocalizationPackage(file)) return 3;
            return 3;
        }
    }
}
