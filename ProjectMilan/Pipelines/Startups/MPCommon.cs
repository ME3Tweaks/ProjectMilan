using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using LegendaryExplorerCore.UnrealScript;
using LegendaryExplorerCore.UnrealScript.Compiling.Errors;
using Serilog;

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
        private const string LOG_CATEGORY = @"MILAN-MPCommon";

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

            // Prepare classes for porting
            PrepareClasses(vars);

            // Port SFXGameMPContent over so it keeps the GUID

            // Compile empty classes 

            // Recompile classes with variables

            // Recompile classes with scripts

            // Recompile classes with default properties

            // Profit

            vars.BuildingPackage.Save();
        }


        private static string GetPackageName(string sourceFilePath)
        {
            return Directory.GetParent(sourceFilePath).Name;
        }

        // These have now been dumped, so the code is no longer run... for now, anyways.
        // Mgamerz-specific.

        /// <summary>
        /// returns true if a class was emitted that was decompiled from ME3
        /// </summary>
        /// <param name="classFolder"></param>
        /// <param name="packagePath"></param>
        /// <returns></returns>
        private static bool CompilePackage(string classFolder, string packagePath)
        {
            MilanLog.Information("Compiling loose classes", customPrefix: LOG_CATEGORY);
            var classes = new List<UnrealScriptCompiler.LooseClass>();
            foreach (string ucFilePath in Directory.EnumerateFiles(classFolder, "*.uc", SearchOption.AllDirectories).Concat(
                         Directory.EnumerateFiles(MilanShared.GetSharedLooseClassesPath(), "*.uc", SearchOption.AllDirectories)))
            {
                string source = File.ReadAllText(ucFilePath);
                //files must be named Classname.uc
                classes.Add(new UnrealScriptCompiler.LooseClass(Path.GetFileNameWithoutExtension(ucFilePath), source, ucFilePath));
            }

            using IMEPackage pcc = MEPackageHandler.CreateAndOpenPackage(packagePath, MEGame.LE3);

            // Different forced export packages
            var looseClassPackages = new List<UnrealScriptCompiler.LooseClassPackage>();
            foreach (var classEx in classes)
            {
                var packageFile = GetPackageName(classEx.SourceFilePath);
                var classList = looseClassPackages.Find(x => x.PackageName == packageFile);
                if (classList == null)
                {
                    classList = new UnrealScriptCompiler.LooseClassPackage(packageFile, new List<UnrealScriptCompiler.LooseClass>());
                    looseClassPackages.Add(classList);
                }
                classList.Classes.Add(classEx);
            }

            MilanLog.Information(@"Compiling LE3 class package", customPrefix: LOG_CATEGORY);
            MessageLog log = UnrealScriptCompiler.CompileLooseClasses(pcc, looseClassPackages, MissingObjectResolver);

            if (log.HasErrors)
            {
                if (AttemptToFindMissingClasses(log))
                    return true;
                MilanLog.Error("COMPILATION OF CUSTOM CLASSES FAILED: ", customPrefix: LOG_CATEGORY);
                foreach (var error in log.AllErrors)
                {
                    MilanLog.Error($"  {error.Message}", customPrefix: LOG_CATEGORY);
                }

                return false;
            }

            pcc.Save();
            return false;
        }

        private static bool AttemptToFindMissingClasses(MessageLog log)
        {
            var commonBasePackages = new[]
            {
                null,
                "SFXGameContent",
                "SFXGameMPContent",
            };
            // Code: Find class
            foreach (var m in log.AllErrors)
            {
                string className = null;

                // Pull missing class name out of error message
                if (m.Message.StartsWith("No class named '"))
                {
                    className = m.Message.Substring(16);
                }
                else if (m.Message.Contains("Unable to resolve class '"))
                {
                    className = m.Message.Substring(m.Message.IndexOf("Unable to resolve class '") + "Unable to resolve class '".Length);
                }
                else
                {
                    // It's something else...
                    return false;
                }

                className = className.Substring(0, className.IndexOf('\''));
                foreach (var cbp in commonBasePackages)
                {
                    string ifp;
                    if (cbp == null)
                    {
                        ifp = className;
                    }
                    else
                    {
                        ifp = $"{cbp}.{className}";
                    }

                    var foundObjs = MilanShared.ME3ObjectDB.GetFilesContainingObject(ifp);
                    if (foundObjs != null)
                    {
                        foreach (var foundObj in foundObjs)
                        {
                            var sourceFileName = Path.GetFileName(foundObj);
                            var package = MilanShared.GetME3Package(sourceFileName);

                            // DLC system Milan uses doesn't look in SP files
                            // So if obj database has SP stuff this will fail
                            // Just keep going.
                            if (package != null)
                            {
                                MilanLog.Information($@"Found missing class '{className}' in ME3: {foundObj}");
                                var export = package.FindExport(ifp);
                                DecompileClass(export, null, true);
                                return true;
                            }
                        }
                    }
                }
            }

            return false;
        }

        private static IEntry MissingObjectResolver(IMEPackage package, string ifp)
        {
            Debug.WriteLine($"Missing object: {ifp}");
            return null;
        }

        /// <summary>
        /// Prepares classes for porting by reading their data out of ME3
        /// </summary>
        private static void PrepareClasses(MPCommonPipelineVars vars)
        {
            // Todo: Change this over to look for specifically named files in ME3 and enumerate them to build a list of all classes to extract

            var dlcInFile = Path.Combine(ME3Directory.DLCPath, "DLC_CON_MP5", MEGame.ME3.CookedDirName(), "Default.sfar");
            if (!File.Exists(dlcInFile))
            {
                throw new Exception("MP5 is not installed in ME3 (Reckoning DLC). Please install it. It does not need to be unpacked.");
            }

            MilanLog.Information($"Sourcing MPLobby.pcc from {dlcInFile}", customPrefix: LOG_CATEGORY);


            var dlc = new DLCPackage(dlcInFile);
            var dlcEntryIdx = dlc.FindFileEntry("MPLobby.pcc");

            IMEPackage parsingPackage;
            if (dlcEntryIdx >= 0)
            {
                // File is in DLC
                parsingPackage = MEPackageHandler.OpenMEPackageFromStream(dlc.DecompressEntry(dlcEntryIdx), "MPLobby.pcc");
            }
            else
            {
                // Probably decompressed.
                var filePath = Path.Combine(ME3Directory.DLCPath, "DLC_CON_MP5", MEGame.ME3.CookedDirName(), "MPLobby.pcc");
                if (!File.Exists(filePath))
                {
                    throw new Exception("Could not find MPLobby in SFAR or on disk!");
                }

                parsingPackage = MEPackageHandler.OpenMEPackage(filePath);
            }

            //initing filelib is expensive, so we only want to do it for files that have script
            FileLib fileLib = new FileLib(parsingPackage);
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
                parsingPackage.FindExport("SFXGameMPContent"),
                parsingPackage.FindExport("SFXGameMPContentDLC_Shared_MP"), // This adds stuff for challenges in MP4. It is referenced by BioWorldInfo's game modes supported for Lobby DLC.
                
                // These are in startup files.
                parsingPackage.FindExport("SFXGameContentDLC_CON_MP2_Retrieve"), // Retrieve Objective was added in MP2
                parsingPackage.FindExport("SFXGameContentDLC_CON_MP3_MobileAnnex"), // Mobile Annex Objective was added in MP3. Oh, the PTSD from this thing...
                parsingPackage.FindExport("SFXGameContentDLC_CON_MP4_Horde"), // Adds CollectorHUDOverlay GUI class, Cerberus2/Geth2/Reaper2 faction classes (for config) and new collector faction class.
            };

            foreach (var classExp in parsingPackage.Exports.Where(x => x.IsClass && x.Parent != null && packagesToPort.Contains(x.Parent)))
            {
                DecompileClass(classExp, fileLib, false);
            }

            // Attempt compile
            var outPackage = Path.Combine(Program.Settings.OutputPath, Path.Combine(vars.OutputPath, "MPContent.pcc"));

            while (CompilePackage(GetMPClassesFolder(), outPackage))
            {

            }
        }

        private static void DecompileClass(ExportEntry classExp, FileLib fileLib, bool toShared)
        {
            var outpath = toShared ? MilanShared.GetSharedLooseClassesPath() : GetMPClassesFolder();

            MilanLog.Information($"Decompiling {classExp.InstancedFullPath}", customPrefix: LOG_CATEGORY);
            var packageOutputPath = Path.Combine(outpath, classExp.HasParent ? classExp.ParentName : classExp.FileRef.FileNameNoExtension);
            Directory.CreateDirectory(packageOutputPath);

            if (fileLib == null)
            {
                // Initialize filelib if it wasn't.
                try
                {
                    fileLib = new FileLib(classExp.FileRef);
                    fileLib.Initialize();
                }
                catch
                {
                    //we're not checking if it failed to initialize because we don't really care, since decompilation doesn't actually need an initialized filelib,
                    //it just makes the output a bit nicer (at the time of this writing all it does is resolve some integer literals into enum values)
                }
            }

            var outName = Path.Combine(packageOutputPath, $"{classExp.ObjectName}.uc");
            (_, string functionText) = UnrealScriptCompiler.DecompileExport(classExp, fileLib);
            File.WriteAllText(outName, functionText);
        }

        private static string GetMPClassesFolder()
        {
            return Path.Combine(Program.Settings.OutputPath, "ME3", "Classes");
        }
    }
}
