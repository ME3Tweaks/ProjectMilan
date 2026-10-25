using LegendaryExplorerCore.Packages;

namespace ProjectMilan.Pipelines.Kits
{
    internal class KitSpecificPipeline
    {
        /// <summary>
        /// If this kit should be ported
        /// </summary>
        public bool Enabled { get; set; } = true;

        /// <summary>
        /// If this kit is known-broken and must not be forced on by <see cref="Settings.IMilanSettings.ProductionBuild"/>
        /// </summary>
        public bool ExcludeFromProduction { get; set; }

        /// <summary>
        /// If this kit should be ported this run: <see cref="Enabled"/>, or forced on by a production build
        /// </summary>
        public bool ShouldBuild => Enabled || (Program.Settings.ProductionBuild && !ExcludeFromProduction);

        /// <summary>
        /// Base package that contains primary kit
        /// </summary>
        public string PackageName { get; set; }

        /// <summary>
        /// Logging category
        /// </summary>
        public string LogCategory { get; set; }

        /// <summary>
        /// Cache for this pipeline
        /// </summary>
        public PackageCache Cache { get; set; }

        /// <summary>
        /// The ported package. Null once the pipeline for this kit has finished to prevent reference keeping
        /// </summary>
        public IMEPackage PortedPackage { get; set; }

        /// <summary>
        /// Delegate for making fixes after porting
        /// </summary>
        public Action<KitSpecificPipeline> PostCorrections { get; internal set; }
    }
}
