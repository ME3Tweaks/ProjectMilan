using ProjectMilan.Pipelines.Startups;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ProjectMilan.Pipelines.Texture
{
    /// <summary>
    /// Pipeline for extracting audio from ME3 and porting it to LE3 WwiseBanks
    /// </summary>
    internal class TFCBuild
    {
        private const string LOG_CATEGORY = @"MILAN-Texture";
        // Expected pipeline:
        // 1. Go through ME3 package files and find all used Texture2Ds that are not in LE (using object database?). Hopefully things did not get renamed.
        // 2. Make LE3 package file that will be the 'host' for all textures during build (LE1R/LE2R uses this and it works well) - called TFCPackage
        // 3. Stub out all texture exports that will be ported into TFCPackage
        // 4. Extract and port textures - substituting from other sources, such as ALOT, if possible, since these textures will look worse than LE
        //        -> During this step it will build the TFC
        // 5. Run a pass over the compiled DLC and replace all stubbed textures with versions from TFCPackage.
        // This pipeline must be run after level and kit compiler

        public static void RunPipeline()
        {
            InternalRunPipeline();
        }

        private static void InternalRunPipeline()
        {
            // Setup pipeline
            MPCommonPipelineVars vars = new MPCommonPipelineVars()
            {
                OutputPath = Path.Combine(Program.Settings.OutputModPath, "LE3", "MPCommon")
            };
        }
    }
}
