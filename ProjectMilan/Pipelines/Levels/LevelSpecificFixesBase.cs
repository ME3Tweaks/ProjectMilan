using LegendaryExplorerCore.Packages;
using ProjectMilanCore;
using ProjectMilanCore.Config;

namespace ProjectMilan.Pipelines.Levels
{
    /// <summary>
    /// Interface for level specific things in pipelines to make pipeline level list cleaner
    /// </summary>
    public abstract class LevelSpecificFixesBase
    {
        /// <summary>
        /// List of level names to not include in a lighting bake. Some levels have unused sublevels that we include but don't want to corrupt our lighting with.
        /// </summary>
        public virtual string[] IgnoredLightingLevels => null;

        /// <summary>
        /// Return true to keep a component's ported ME3 lighting (lightmap, shadow maps and IrrelevantLights) instead of
        /// installing the UDK bake on it. For components the bake lights in a way ME3 never did.
        /// </summary>
        /// <param name="component">Component in the LE3 level package being relit</param>
        public virtual bool KeepPortedLighting(ExportEntry component) => false;

        /// <summary>
        /// Ports the level in place of the generic level port. Return false to use the generic port, which is the one that runs
        /// <see cref="PreCorrect"/> and <see cref="PostCorrect"/>.
        /// </summary>
        /// <param name="pipeline"></param>
        /// <param name="parent">Cache to chain the level's own cache from</param>
        /// <returns>True if this ported the level</returns>
        public virtual bool PortLevel(LevelSpecificPipeline pipeline, TieredPackageCache parent) => false;

        /// <summary>
        /// Run before levels are ported over to LE3.
        /// </summary>
        /// <param name="pipeline"></param>
        public virtual void PreCorrect(LevelSpecificPipeline pipeline) { }

        /// <summary>
        /// Run after levels are ported over to LE3.
        /// </summary>
        /// <param name="pipeline"></param>
        public virtual void PostCorrect(LevelSpecificPipeline pipeline) { }

        /// <summary>
        /// Run after levels are ported to UDK files. This runs on each file.
        /// </summary>
        /// <param name="pipeline"></param>
        /// <param name="udk"></param>
        public virtual void CorrectUDKExport(LevelSpecificPipeline pipeline, IMEPackage udk) { }

        /// <summary>
        /// Run after shader installation has completed, in case the pipeline needs to make further corrections to the level
        /// </summary>
        /// <param name="pipeline"></param>
        public virtual void PostShaderCompileCorrections(LevelSpecificPipeline pipeline) { }

        /// <summary>
        /// Enables weapon flashlights on this map: lists its BioP in MilanWeaponFlashlight.FlashlightMaps in the current config bundle.
        /// </summary>
        /// <param name="pipeline"></param>
        protected static void UseFlashlightsForLevel(LevelSpecificPipeline pipeline)
        {
            MapListConfigWriter.RegisterFlashlightMap(pipeline.BioP);
            MilanLog.Information($"Weapon flashlights enabled on {pipeline.BioP}", customPrefix: pipeline.LogCategory);
        }
    }
}
