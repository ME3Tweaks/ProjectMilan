using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal.BinaryConverters;

namespace MilanCoverHost.Classes
{
    /// <summary>
    /// Data for serializing pathfinding information in a level.
    /// </summary>
    public class LevelSerializer
    {
        /// <summary>
        /// The level package
        /// </summary>
        public IMEPackage package;

        /// <summary>
        /// The ID of the pathfinding network
        /// </summary>
        public int networkId;

        /// <summary>
        /// Parsed level binary
        /// </summary>
        public Level levelBin;

        internal void Init()
        {
            levelBin = ObjectBinary.From<Level>(package.FindExport("TheWorld.PersistentLevel"));
        }
    }
}
