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
    }
}
