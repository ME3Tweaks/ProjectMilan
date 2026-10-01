using LegendaryExplorerCore.Gammtek.Paths;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using LegendaryExplorerCore;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;

namespace MilanShaderHost
{
    /// <summary>
    /// File that contains list of files to process.
    /// </summary>
    internal class ShaderCompileList
    {
        internal static List<string> PackageFilesToProcess = new List<string>();

        /// <summary>
        /// Packages whose compiler level takes long enough to prepare that waiting for the
        /// one-ahead prefetch leaves the game idle. Not an install list: a package here is only
        /// compiled if it is also in <see cref="PackageFilesToProcess"/>, in which case its level
        /// is prepared by a background worker from the start of the run, at its normal place in
        /// the order. Matched by package name, case-insensitively.
        /// </summary>
        internal static readonly HashSet<string> LongPreparePackages = new(StringComparer.OrdinalIgnoreCase)
        {
            "EffectsMaterials", // ~1800 materials, each ported twice; tens of minutes to prepare
        };

        /// <summary>
        /// Reads the --packagelist file, or null when the option was not supplied.
        /// </summary>
        private static string[] ReadPackageListFile()
        {
            var path = Program.ParsedOptions?.PackageListFile;
            if (string.IsNullOrWhiteSpace(path))
            {
                return null;
            }

            if (!File.Exists(path))
            {
                Console.Error.WriteLine($"Package list file not found: {path}");
                return null;
            }

            var lines = File.ReadAllLines(path)
                .Select(x => x.Trim())
                .Where(x => x.Length > 0 && !x.StartsWith("#"))
                .ToArray();

            Console.WriteLine($"Read {lines.Length} packages from {path}");
            return lines;
        }

        /// <summary>
        /// Generates the list of packages to compile shaders in.
        ///
        /// When --packagelist is given, the list is read from that file instead of the array below,
        /// one package name or package path per line (blank lines and # comments ignored). A direct
        /// path is useful for map-local assets such as Terrain: the package and its CookedPCConsole
        /// root are automatically made available to the relinker while that input is processed.
        /// </summary>
        internal static void SetupFileList()
        {
            PackageFilesToProcess.Clear();

            // Terrain packages are a focused, direct-input workflow. Do not accidentally combine
            // them with the hardcoded list or a package-list file: the compiler map must contain
            // only the terrain(s) requested by this invocation.
            var terrainPackagePath = Program.ParsedOptions?.TerrainPackagePath;
            if (!string.IsNullOrWhiteSpace(terrainPackagePath))
            {
                var explicitPath = NormalizeExplicitPackagePath(terrainPackagePath);
                if (!File.Exists(explicitPath))
                {
                    throw new FileNotFoundException("Terrain package was not found.", explicitPath);
                }

                AddSourceRootsForExplicitPackage(explicitPath);
                PackageFilesToProcess.Add(explicitPath);
                Console.WriteLine($"Terrain compile input: {explicitPath}");
                return;
            }

            string[] files = ReadPackageListFile() ?? [
                
                // LE1 Pinnacle Station
                //"BIOA_LAV60_T",
                //"BIOA_LAV70_T",
                //"BIOA_PRC2_T",
                //"BIOA_ICE60_T",
                //"BIOG_APL_CON_Cargo_Container_L",
                //"BIOA_STA60_T",
                ////"BIOA_PRC2_MatFX", // Do not do this one
                //"BIOG_V_Env_LavaSplash",
                //"BIOA_PRO20_T",
                //"BIOG_APL_STD_Work_Lamp_01_L",
                //"BIOA_LAV40_T",
                //"CROSSGENV",
                //"BIOG_APL_STD_Drill_01_L",
                //"BIOA_JUG80_T",
                //"BIOA_ICE20_T",
                //"BIOA_PRO10_T",
                //"BIOA_WAR20_T",
                //"BIOA_WAR40_T",
                //"BIOG_VEH_TTR_A",
                // "BIOA_APL_INT_ICE50_MiraBlock_L", // Used to create the LE1 version of the grid line walls mat. It uses 'Hologram_mat' with custom textures.
                //"BIOG_APL_PHY_Tire_01_L",
                //"BIOG_APL_Invisible_P",
                //"BIOA_DLC_UNC52_T",
                //"BIOA_ICE60_T",
                //"BIOG_V_Veh_Impact_Lava_Z",
                //"BIOG_V_B_Weaken_Z",
                //"BIOA_LOS10_T", // Audemus pod shader source for tropical
                //"BIOA_PRC2_S.Ships",
                //"BIOG_APL_PHY_Contain_Cells_01_L",
                //"BIOG_APL_STD_Geth_Bomb_L",
                //"BIOG_APL_INT_Pro_Terminal_01_L",
                //"BIOG_APL_INT_ElevConsole_02_L",
                //"BIOG_V_Env_VolumeLights_Z",
                // Tropical - requires some LE1 stuff set up.
                //"BIOA_NOR10_T.pcc",
                //"BIOA_STA60_T.pcc",
                //"BIOA_STA60_02_T.pcc",
                ////"BIOA_PRC2_MatFX.pcc", // Will require a special made donor that fits what we used for donors for LE1. We might just compile what we used for LE1 in LE3. Don't compile it this way
                //"BIOA_STA30_T.pcc",
                //"BIOA_JUG40_T.pcc",
                //"BIOA_Jug20_T.pcc",
                //"BIOA_JUG80_T.pcc",
                //"BIOA_JUG00_T.pcc",
                //"BIOG_APL_PHY_Crate_XLarge_01_L.pcc",
                //"BIOG__SKIES__.pcc",
                //"BIOA_FRE10_T.pcc",
                //"BIOA_LOS40_APL_DOR_FFDoor_L.pcc",
                //"BIOG_V_Env_Jug_WaveCrash_Z.pcc",
                //"VFX_zz_ME1_Global_METR.pcc",
                //"BIOG_V_Env_Hologram_Z.pcc",
                //"BIOA_LAV20_T.pcc"

                
                // Contain MICs
                "biot_krogru",
                "BioApl_Ind_Mining_Drill03",
                "bioapl_ind_mainframe01",
                "BioApl_Sea_Cake01",


                // Multiplayer Kits
                "BIOG_MP_HMF_MED_R",
                "BIOG_MP_HMM_HVY_R",
                "BIOG_MP_BF_HMM", // BF3 Soldier

                // MP1
                "BioVFX_DLC_MP1_BubbleShield",
                "BioVFX_DLC_MP1_Bat",
                "BioVFX_DLC_MP1_Bat_2",
                "BioVFX_DLC_MP1_BatMelee",
                "BioVFX_DLC_MP1_Geth",

                // MP2
                "BioVFX_DLC_CerberusOp",

                // MP3
                "BIOG_MP_Swords_01",
                "BioVFX_MP3_Annihilation",
                "BioVFX_MP3_PalmBlast",
                "BioVFX_MP3_Asari_Pistol",
                "BioVFX_MP3_Engineer",
                "BioVFX_MP3_ShadowStrike",
                "BioVFX_MP3_Sonic_Boom",
                "BioVFX_MP3_Sword",
                "BioVFX_MP3_Cone_Cold",
                "BioVFX_MP3_OmniShield",
                "BioVFX_DLC_Shared",
                "BioVFX_DLC_MaleQuarian",
                "BioVFX_DLC_OmniBlade",

                // MP4
                "BioVFX_MP4_Volus_Eng",
                // "BioVFX_MP4_Tur_Jets", // Produced no materials? Needs investigated. If left on the previous compiler level is leftover  and used

                // MP5
                "BioVFX_MP5_Prothean", // Collector Adept
                "EffectsMaterials_MP5", // Collector Adept // Contains Combined Effect

                "BIOG_MP5_GTH_PLY_R", // Geth Destroyer
                "BioVFX_MP5_GethPrime", // Geth Destroyer

                "BIOG_MP_INF_FBT", // Fembot Infiltrator
                "BioVFX_MP5_Cone_Cold", // Fembot Infiltrator
                "BioVFX_MP5_Fembot", // Fembot Infiltrator

                "BioVFX_MP5_Engineer", // UGH the Merc Engineer

                "BIOG_WPN_MLE_R_MP5", // Krogan Warlord // Contains Combined Effect
                "BioVFX_MP5_KroganWL", // Krogan Warlord

                "BioVFX_MP5_Vanguard", // Turian Female
                "BIOG_MP_VAN_TUF", // Turian Female

                "BioVFX_MP5_Gear", // Geth Vision Gear


                
                ////Multiplayer levels
                "BioApl_Lvl_Foliage",

                //// MPLobby
                "MPLobby", // Black material

                //// Hydra:
                "BioT_GthMP",
                "BioVFX_DLC_Env_MPGeth",

                //// Condor:
                "BioT_MPMoon",
                "BioVFX_DLC_Env_MPMoon",
                "BioT_RedRock_Ter", // MIC

                //// Jade:
                "BioS_MPJungle",
                "BioS_MPJungle_Trash", // Todo: Why does water_tint, Waterfall_Master_lite not compile into something?
                "BioT_MPJungle",
                "biot_salarian", // MICs used by BioA_MPJngl
                "BioT_Tropical",
                "BioVFX_DLC_Env_MPJngl",
                
                //// Thessia:
                "BioT_MPThes",
                "BioT_Thessia", // MICs used by BioA_MPThes_100/101/120_Lab

                //// Vancouver
                "BioVFX_MP3_MPHosp",
                "BioT_MPHosp",
                "BioT_SolMP", // Is this actually here?
                
                //// Rio
                "BioT_MPOcean",
                "BioVFX_MP3_MPOcean",
                "BioApl_Ind_KroHatch01", // MIC used by BioA_MPOcean_100

                //// London
                "BioS_MPLondon",
                "biot_london", // MIC used by BioA_MPRoad_vista

                //// Hazard Cer
                "BioT_MPCer2",
                
                //// Hazard Dish
                "BioT_MPDish2",

                //// Hazard Nov
                "BioT_MPNov2",
                
                //// Hazard Reactor
                "BioT_MPRctr2",

                //// Hazard Ghost
                "biot_humanslumACID", // May need more.
          ];

            // Dedupe it in case we goof it up
            files = files.Distinct(StringComparer.OrdinalIgnoreCase).ToArray();

            // Quick override for debugging -- but never over an explicit --packagelist. This sits after
            // the list has already been read and reported, so overriding it there turns a 164-package
            // recapture into a one-package run that still prints "Read 164 packages" and still exits 0.
            // The only visible trace is the single "Building shaders for:" line, which is easy to miss
            // in a run expected to take hours.
#if DEBUG
            if (string.IsNullOrWhiteSpace(Program.ParsedOptions?.PackageListFile))
            {
                //files = [
                //    "biot_krogru",
                //    "BioApl_Ind_Mining_Drill03",
                //    "bioapl_ind_mainframe01",
                //    "BioApl_Sea_Cake01",
                //];
            }
#endif

            Console.WriteLine($"Source folders:");
            foreach (var path in MilanShaderPackageBuilder.SourceFolders)
            {
                Console.WriteLine($"\t{path}");
            }

            // A package the caller explicitly asked for that cannot be found is a failed run, not a
            // skipped entry: the list is the definition of what this run is supposed to produce.
            // Warning and carrying on ends with "Shader compiling complete." and exit 0 over an
            // empty corpus, which is the same silent success the capture reporting exists to stop.
            var missing = new List<string>();

            foreach (var f in files)
            {
                // A package list may name an exact package outside the normal decooked source roots.
                // Keep the path intact so an LE3 map (including its local Terrain exports) can be
                // compiled directly rather than requiring a separately generated donor package.
                if (File.Exists(f))
                {
                    var explicitPath = NormalizeExplicitPackagePath(f);
                    AddSourceRootsForExplicitPackage(explicitPath);
                    PackageFilesToProcess.Add(explicitPath);
                    continue;
                }

                var realf = f.EndsWith(".pcc", StringComparison.OrdinalIgnoreCase) ? f : f + ".pcc";
                bool found = false;
                foreach (var path in MilanShaderPackageBuilder.SourceFolders)
                {
                    var testPath = Path.Combine(path, realf);
                    if (File.Exists(testPath))
                    {
                        found = true;
                        PackageFilesToProcess.Add(testPath);
                        break;
                    }
                }
                if (!found)
                {
                    Console.Error.WriteLine($"Could not find source package {realf} in any of the source folders.");
                    missing.Add(realf);
                }
            }

            if (missing.Count > 0)
            {
                Console.Error.WriteLine();
                Console.Error.WriteLine($"*** {missing.Count} requested package(s) were not found and nothing was run for them:");
                foreach (var m in missing) Console.Error.WriteLine($"      {m}");
                Console.Error.WriteLine("    Source folders searched:");
                foreach (var path in MilanShaderPackageBuilder.SourceFolders) Console.Error.WriteLine($"      {path}");
                Console.Error.WriteLine("    Note: --capture-root also moves the default source folder. Pass --sourcefolder to");
                Console.Error.WriteLine("    capture into an isolated root while still reading the normal decooked packages.");
                Environment.Exit(2);
            }
        }

        private static string NormalizeExplicitPackagePath(string path)
        {
            if (!Path.HasExtension(path))
            {
                path += ".pcc";
            }

            return Path.GetFullPath(path);
        }

        /// <summary>
        /// Adds lookup roots needed by a direct package-list entry. The package's own directory is
        /// tried first (for map-local assets), followed by its CookedPCConsole root when present.
        /// </summary>
        private static void AddSourceRootsForExplicitPackage(string packagePath)
        {
            AddSourceFolder(Path.GetDirectoryName(packagePath));

            // Custom terrain packages often live beside the game (for example Game\\BioA) rather
            // than under CookedPCConsole. Their TerrainLayerSetup references still need to resolve
            // stock LE3 materials/textures, so always include the selected target game's cooked root.
            if (Program.Game == MEGame.LE3)
            {
                AddSourceFolder(LE3Directory.CookedPCPath);
            }

            var directory = new DirectoryInfo(Path.GetDirectoryName(packagePath)!);
            while (directory != null)
            {
                if (directory.Name.Equals("CookedPCConsole", StringComparison.OrdinalIgnoreCase))
                {
                    AddSourceFolder(directory.FullName);
                    break;
                }

                directory = directory.Parent;
            }
        }

        private static void AddSourceFolder(string? path)
        {
            if (string.IsNullOrWhiteSpace(path) ||
                MilanShaderPackageBuilder.SourceFolders.Any(x => x.Equals(path, StringComparison.OrdinalIgnoreCase)))
            {
                return;
            }

            MilanShaderPackageBuilder.SourceFolders.Add(path);
            Console.WriteLine($"Added source lookup folder: {path}");
        }
    }
}
