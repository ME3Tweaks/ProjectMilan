using System.Diagnostics;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;

namespace ProjectMilan.Pipelines
{
    /// <summary>
    /// Shared data for Milan Pipelines
    /// </summary>
    internal class MilanShared
    {
        private const string ROOT_FOLDER_NAME = @"ProjectMilan";
        public static ObjectInstanceDB LE3ObjectDB { get; set; }
        public static ObjectInstanceDB ME3ObjectDB { get; set; }

        private static string _pipelineRoot;

        /// <summary>
        /// Root path for Milan Pipelines - will be named 'Pipelines' under folder 'ProjectMilan'
        /// </summary>
        public static string PipelineRoot
        {
            get
            {
                if (_pipelineRoot != null) return _pipelineRoot;
                var dir = Directory.GetCurrentDirectory();
                while (Path.GetFileName(dir) != ROOT_FOLDER_NAME)
                {
                    dir = Directory.GetParent(dir).FullName;
                }

                _pipelineRoot = Path.Combine(dir, "Pipelines");
                return _pipelineRoot;
            }
        }

    }
}
