using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Packages;

namespace ProjectMilan.Pipelines.Startups
{
    /// <summary>
    /// Pass-throughable settings for MPCommon pipelne
    /// </summary>
    class NonStartupPipelineVars
    {
        public string OutputPath { get; set; }

        /// <summary>
        /// Extra packages to port
        /// </summary>
        public readonly string[] PackageFiles = new[]
        {
            "BioSimpleDlgContainer_Horde",
            
            // OBJECTIVES
            "SFXEngagement_Annex_Hack",
            "SFXEngagement_Annex_Upload",
            "SFXEngagement_Assassination",
            "SFXEngagement_Disarm_Disable",
            "SFXEngagement_Disarm_Enable",
            "SFXEngagement_Extraction",
            // Todo: add MP2, MP3 objectives
            // "SFXEngagement_Retrieve" // I don't think this is used - this is basegame version which is broken. May leave however if ModMaker somehow is ported to LE.
            // "SFXEngagement_SupplyDrop" // This is a cut objective that has no implementation

            // GUI IMAGES (Basegame)
            "SFXMPCardImages",
            "SFXMPImagesCrates",
            "SFXMPImagesMaps1",
            "SFXMPImagesMaps2",
            "SFXMPImagesMatchSettings",
            "SFXMPImagesStore",
            "SFXMPKitImagesAdept",
            "SFXMPKitImagesEngineer",
            "SFXMPKitImagesInfiltrator",
            "SFXMPKitImagesOther1",
            "SFXMPKitImagesOther2",
            "SFXMPKitImagesSentinel",
            "SFXMPKitImagesSoldier",
            "SFXMPKitImagesVanguard",
            "SFXMPMedalImages",
            "SFXMPObjectives",
            "SFXMPObjectives_Special",
            "SFXMPSupplyCardImages",
        };

        // If other options are ever needed for pass through they will be defined here
    }

    /// <summary>
    /// Ports non-startup files, such as objectives, GUI images, etc
    /// </summary>
    internal class NonStartupPipeline
    {
        private const string LOG_CATEGORY = @"Milan-NonStartup";
        public static void RunPipeline()
        {
            var vars = new NonStartupPipelineVars()
            {
                OutputPath = Directory.CreateDirectory(Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole", "NonStartup")).FullName,
            };
            InternalRunPipeline(vars);
        }

        private static void InternalRunPipeline(NonStartupPipelineVars vars)
        {
            foreach (var packageBaseName in vars.PackageFiles)
            {
                var cache = new PackageCache();
                MilanLog.Information($"Porting file {packageBaseName}", customPrefix: LOG_CATEGORY);
                var packageName = $"{packageBaseName}.pcc";
                var me3File = MilanShared.GetME3Package(packageName);
                var le3File = MEPackageHandler.CreateAndOpenPackage(Path.Combine(vars.OutputPath, packageName), MEGame.LE3);
                le3File.LECLTagData.ImportHintFiles.Add("BIOP_MP_COMMON.pcc"); // Hint common package

                MilanShared.PortObjectReferencer(me3File, le3File, cache, LOG_CATEGORY);
                MilanShared.PortLocalizations(packageBaseName, vars.OutputPath, cache, LOG_CATEGORY);
            }
        }
    }
}
