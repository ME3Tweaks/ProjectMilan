using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Packages;
using ProjectMilanCore;

namespace ProjectMilan_ExtraContent.Rejects
{
    public static class RejectsPipeline
    {
        public static string CookedPCFolder => Path.Combine(BaseBuildSettings.OutputModPath, "CookedPCConsole");
        public static string MergedContentPath => Path.Combine(CookedPCFolder, "MergedContent.pcc");

        /// <summary>
        /// Variable container class for passing through. May have nothing in it - do not remove.
        /// </summary>
        public class RejectVars
        {
        }


        public static void RunPipeline()
        {
            var vars = new RejectVars();
            InternalRunPipeline(vars);
        }

        private static void InternalRunPipeline(RejectVars vars)
        {
            GenerateMergedContent(vars);
            SplitEnemyPackages(vars);
        }

        /// <summary>
        /// Generates a single package file that has all assets for all enemies, so that one change affects them all.
        /// </summary>
        /// <param name="vars"></param>
        private static void GenerateMergedContent(RejectVars vars)
        {
            var mergedPackage = MEPackageHandler.CreateAndOpenPackage(MergedContentPath, MEGame.LE3);
        }

        /// <summary>
        /// Makes individual enemy packages seek free
        /// </summary>
        /// <param name="vars"></param>
        private static void SplitEnemyPackages(RejectVars vars)
        {
        }
    }
}
