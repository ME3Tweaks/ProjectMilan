using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.UnrealScript;

namespace ProjectMilan.Pipelines.Startups
{
    /// <summary>
    /// Pipeline that converts the 'BIOP_MP_COMMON' package from ME3 to LE3.
    /// </summary>
    internal class MPCommon
    {
        // Some notes about MPCommon from ME3.
        // 1. This package is overriden via config files for every MP DLC. They always repoint to MPLobby.pcc which exists in every DLC.
        // 2. Some classes in this are overriden by DLC_TestPatch. We must use those classes instead as they will be patched. 
        // 3. A few of these changes were for native code. We will need to analyze how they changed and make adjustments as necessary.
        // 4. For all ported package exports, we should strive to keep the original GUID on the package. If we 
        //         ever make it to actual MP - e.g. replication - this will be vital as that's how Unreal sends package info
        //         across the network. And it's horrible, nearly impossible to debug. Top level packages must use the same GUID
        //         as OT.


        public static void RunPipeline()
        {
            MilanLog.Information(@"Starting SFXGameMPContent pipeline");



            MilanLog.Information(@"SFXGameMPContent pipeline has completed");
        }



        // These have now been dumped, so the code is no longer run... for now, anyways.
        // Mgamerz-specific.

        /// <summary>
        /// Prepares classes for porting by reading their data out of ME3
        /// </summary>
        private static void PrepareClasses()
        {
            var outpath = @"B:\UserProfile\source\repos\ME3Tweaks\ProjectMilan\ProjectMilan\ME3\Classes\SFXGameMPContent";
            var dlcInFile = Path.Combine(ME3Directory.DLCPath, "DLC_CON_MP5", MEGame.ME3.CookedDirName(), "Default.sfar");
            MilanLog.Information($"Extracting MPLobby.pcc from {dlcInFile}");
            var dlc = new DLCPackage(dlcInFile);
            var mpLobbyP = MEPackageHandler.OpenMEPackageFromStream(dlc.DecompressEntry(dlc.FindFileEntry("MPLobby.pcc")), "MPLobby.pcc");
            var sfxGameMPContent = mpLobbyP.FindExport("SFXGameMPContent");

            //initing filelib is expensive, so we only want to do it for files that have script
            FileLib fileLib = new FileLib(mpLobbyP);
            try
            {
                fileLib.Initialize();
            }
            catch
            {
                //we're not checking if it failed to initialize because we don't really care, since decompilation doesn't actually need an initialized filelib,
                //it just makes the output a bit nicer (at the time of this writing all it does is resolve some integer literals into enum values)
            }



            foreach (var classExp in mpLobbyP.Exports.Where(x => x.IsClass && x.Parent == sfxGameMPContent))
            {
                MilanLog.Information($"Decompilng {classExp.InstancedFullPath}");
                var outName = Path.Combine(outpath, $"{classExp.ObjectName}.uc");
                (_, string functionText) = UnrealScriptCompiler.DecompileExport(classExp, fileLib);
                File.WriteAllText(outName, functionText);
            }
        }
    }
}
