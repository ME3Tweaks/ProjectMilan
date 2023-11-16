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
    /// Pass-throughable settings for MPCommon pipelne
    /// </summary>
    class MPCommonPipelineVars
    {
        public string OutputPath { get; set; }

        /// <summary>
        /// Package file being compiled
        /// </summary>
        public IMEPackage BuildingPackage { get; set; }
    }

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

        // Additional notes:
        // MP1, MP2, MP3 did not add much - MP2 added gear.
        // MP4 added challenges which changes a bunch of UIs. Collectors added a new UI that is not present in LE that replaces the cooldown timer
        //         Even in OT Citadel, they didn't properly port this UI so it doesn't properly show the bee swarm.
        // MP5 is a superset of MP4 but doesn't seem to activate the new features if MP4 is not installed... I think.
        // There are some startup files for each MP DLC. They probably will need loaded.


        public static void RunPipeline()
        {
            // Setup pipeline
            MPCommonPipelineVars vars = new MPCommonPipelineVars()
            {
                OutputPath = Path.Combine(Program.Settings.OutputPath, "LE3", "MPCommon")
            };

            InternalRunPipeline(vars);
        }

        private static void InternalRunPipeline(MPCommonPipelineVars vars)
        {
            // Actually run pipeline
            Directory.CreateDirectory(vars.OutputPath);
            vars.BuildingPackage = MEPackageHandler.CreateAndOpenPackage(Path.Combine(vars.OutputPath, "SFXGameMPContent.pcc"), MEGame.LE3);

            // Prepare classes for porting
            PrepareClasses();

            // Port SFXGameMPContent over so it keeps the GUID

            // Compile empty classes 

            // Recompile classes with variables

            // Recompile classes with scripts

            // Recompile classes with default properties

            // Profit

            vars.BuildingPackage.Save();
        }


        // These have now been dumped, so the code is no longer run... for now, anyways.
        // Mgamerz-specific.

        /// <summary>
        /// Prepares classes for porting by reading their data out of ME3
        /// </summary>
        private static void PrepareClasses()
        {
            // This only works in debug mode! As VS will put these in a specific folder.
            var outpath = Path.Combine(Program.Settings.OutputPath, "ME3", "Classes");
            Directory.CreateDirectory(outpath);

            var dlcInFile = Path.Combine(ME3Directory.DLCPath, "DLC_CON_MP5", MEGame.ME3.CookedDirName(), "Default.sfar");
            if (!File.Exists(dlcInFile))
            {
                throw new Exception("MP5 is not installed in ME3 (Reckoning DLC). Please install it. It does not need to be unpacked.");
            }

            MilanLog.Information($"Extracting MPLobby.pcc from {dlcInFile}");


            var dlc = new DLCPackage(dlcInFile);
            var dlcEntryIdx = dlc.FindFileEntry("MPLobby.pcc");

            IMEPackage mpLobbyP;
            if (dlcEntryIdx >= 0)
            {
                // File is in DLC
                mpLobbyP = MEPackageHandler.OpenMEPackageFromStream(dlc.DecompressEntry(dlcEntryIdx), "MPLobby.pcc");
            }
            else
            {
                // Probably decompressed.
                var filePath = Path.Combine(ME3Directory.DLCPath, "DLC_CON_MP5", MEGame.ME3.CookedDirName(), "MPLobby.pcc");
                if (!File.Exists(filePath))
                {
                    throw new Exception("Could not find MPLobby in SFAR or on disk!");
                }

                mpLobbyP = MEPackageHandler.OpenMEPackage(filePath);
            }

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

            // List of package level exports to port (ForcedExport)
            // These can be null depending on what package they resolve on. That's fine.
            var packagesToPort = new[]
            {
                mpLobbyP.FindExport("SFXGameMPContent"),
                mpLobbyP.FindExport("SFXGameMPContentDLC_Shared_MP") // This adds stuff for challenges in MP4. It is referenced by BioWorldInfo's game modes supported for Lobby DLC.
            };

            foreach (var classExp in mpLobbyP.Exports.Where(x => x.IsClass && x.Parent != null && packagesToPort.Contains(x.Parent)))
            {
                MilanLog.Information($"Decompiling {classExp.InstancedFullPath}");
                var packageOutputPath = Path.Combine(outpath, classExp.ParentName);
                Directory.CreateDirectory(packageOutputPath);
                var outName = Path.Combine(packageOutputPath, $"{classExp.ObjectName}.uc");
                (_, string functionText) = UnrealScriptCompiler.DecompileExport(classExp, fileLib);
                File.WriteAllText(outName, functionText);
            }
        }
    }
}
