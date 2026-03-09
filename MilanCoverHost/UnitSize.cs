using System;
using System.Collections.Generic;
using System.Text;

namespace MilanCoverHost
{
    /// <summary>
    /// Simple record pair representing Radius/Height for unit types.
    /// </summary>
    public readonly record struct UnitSize(int Radius, int Height);

    internal static class UnitSizes
    {
        // Radius / Height
        public static readonly UnitSize MOOK = new(34, 90);
        public static readonly UnitSize MINIBOSS = new(105, 145);
        public static readonly UnitSize BRUTE = new(115, 145); // use miniboss height for brute
        public static readonly UnitSize BOSS = new(140, 195); // Biggest size
        public static readonly UnitSize BANSHEE = new(50, 125); // Thin and tall
        // public static readonly UnitSize HARVESTER = new(500, 500); // Not used for standard pathing.

        private static UnitSize[] _allUnitSizes = null;
        public static UnitSize[] AllUnitSizes
        {
            get
            {
                if (_allUnitSizes != null)
                {
                    return _allUnitSizes;
                }

                var tempAllUnitSizes = new List<UnitSize>();
                tempAllUnitSizes.Add(MOOK);
                tempAllUnitSizes.Add(MINIBOSS);
                tempAllUnitSizes.Add(BRUTE);
                tempAllUnitSizes.Add(BOSS);
                tempAllUnitSizes.Add(BANSHEE);
                // tempAllUnitSizes.Add(HARVESTER);

                _allUnitSizes = tempAllUnitSizes.ToArray();
                return _allUnitSizes;
            }
        }


        private static UnitSize[] _largestToSmallest = null;
        public static UnitSize[] LargestToSmallest
        {
            get
            {
                if (_largestToSmallest != null)
                    return _largestToSmallest;

                _largestToSmallest = AllUnitSizes.OrderByDescending(x => x.Radius).ThenByDescending(x => x.Height).ToArray();
                return _largestToSmallest;
            }
        }
    }
}
