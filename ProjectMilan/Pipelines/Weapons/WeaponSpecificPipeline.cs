using LegendaryExplorerCore.Packages;

namespace ProjectMilan.Pipelines.Weapons
{
    internal class WeaponSpecificPipeline
    {
        /// <summary>
        /// If this weapon should be ported
        /// </summary>
        public bool Enabled { get; set; } = true;

        /// <summary>
        /// If this weapon is known-broken and must not be forced on by <see cref="Settings.IMilanSettings.ProductionBuild"/>
        /// </summary>
        public bool ExcludeFromProduction { get; set; }

        /// <summary>
        /// If this weapon should be ported this run: <see cref="Enabled"/>, or forced on by a production build
        /// </summary>
        public bool ShouldBuild => Enabled || (Program.Settings.ProductionBuild && !ExcludeFromProduction);

        /// <summary>
        /// Base package that contains weapon
        /// </summary>
        public string PackageName { get; set; }

        /// <summary>
        /// Name of the weapon class in the file
        /// </summary>
        public string WeaponClassName { get; set; }

        /// <summary>
        /// Logging category
        /// </summary>
        public string LogCategory { get; set; }

        /// <summary>
        /// Cache for this pipeline
        /// </summary>
        public PackageCache Cache { get; set; }
        /// <summary>
        /// The LE3 SP package
        /// </summary>
        public string LE3PackageName { get; set; }

        public List<string> BaseObjectPaths { get; } = new List<string>();

        /// <summary>
        /// Delegate to invoke after porting to perform any corrections or adjustments
        /// </summary>
        public Action<IMEPackage, WeaponSpecificPipeline> ApplyPostPortingCorrections { get; init; }
    }
}
