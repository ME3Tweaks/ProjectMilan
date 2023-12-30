using LegendaryExplorerCore.Packages;

namespace ProjectMilan.Pipelines.MP4NewEnemies
{
    internal class MP4EnemySpecificPipeline
    {
        /// <summary>
        /// If this enemy should be ported
        /// </summary>
        public bool Enabled { get; set; } = true;

        /// <summary>
        /// Base ME3 that contains the enemy
        /// </summary>
        public string PackageName { get; set; }

        /// <summary>
        /// Name of the enemy class for MP
        /// </summary>
        public string EnemyClassName { get; set; }

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
        /// List of UC classes to add
        /// </summary>
        public string[] ExtraLinkedInClasses { get; init; }
    }
}
