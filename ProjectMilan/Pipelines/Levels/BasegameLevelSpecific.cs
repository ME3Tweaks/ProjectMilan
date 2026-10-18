using LegendaryExplorerCore.Packages;

namespace ProjectMilan.Pipelines.Levels
{
    /// <summary>
    /// Shared by the basegame MP maps that ship with LE. These aren't ported from ME3; LE3's own copy is fixed up instead.
    /// </summary>
    internal class BasegameLevelSpecific : LevelSpecificFixesBase
    {
        public override bool PortLevel(LevelSpecificPipeline pipeline, TieredPackageCache parent)
        {
            MPLevels.BasegameMapPorting(pipeline, parent);
            return true;
        }
    }
}
