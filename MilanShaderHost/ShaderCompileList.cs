using LegendaryExplorerCore.Gammtek.Paths;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

namespace MilanShaderHost
{
    /// <summary>
    /// File that contains list of files to process.
    /// </summary>
    internal class ShaderCompileList
    {
        internal static List<string> PackageFilesToProcess = new List<string>();

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
        /// one package name per line (blank lines and # comments ignored). That is how the capture
        /// plan from ShaderResearchTool is fed in without editing this file for every run.
        /// </summary>
        internal static void SetupFileList()
        {
            string[] files = ReadPackageListFile() ?? [
                
                // LE1 Pinnacle Station
                //"BIOA_LAV60_T",
                //"BIOA_LAV70_T",
                //"BIOA_PRC2_T",
                //"BIOA_ICE60_T",
                //"BIOG_APL_CON_Cargo_Container_L",
                //"BIOA_STA60_T",
                //"BIOA_PRC2_MatFX",
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
                "BIOA_ICE60_T",

                // TEST
                //"EngineDebugMaterials",

                // Existing: For test comparison
                /*
                "BioS_CitApt_Alt.pcc",
                "BioS_CitCasino.pcc",
                "BioS_CitCouncil.pcc",
                "BioS_CitRestaurant.pcc",
                "BioS_CitSim.pcc",
                "BioS_CitSim_Alt.pcc",
                "BioS_CitStreets.pcc",
                "BioS_CitWards.pcc",
                "BioS_Cit_lev004.pcc",*/
                //"BioT_Arctic",
                //"biot_ancientcity.pcc",

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

                // Multiplayer Kits

                // MP1
                //"BioVFX_DLC_MP1_BubbleShield",
                //"BioVFX_DLC_MP1_Bat",
                //"BioVFX_DLC_MP1_Bat_2",
                //"BioVFX_DLC_MP1_BatMelee",
                //"BioVFX_DLC_MP1_Geth",

                //// MP2
                //"BioVFX_DLC_CerberusOp",

                //// MP3
                //"BIOG_MP_Swords_01",
                //"BioVFX_MP3_Annihilation",
                //"BioVFX_MP3_PalmBlast",
                //"BioVFX_MP3_Asari_Pistol",
                //"BioVFX_MP3_Engineer",
                //"BioVFX_MP3_ShadowStrike",
                //"BioVFX_MP3_Sonic_Boom",
                //"BioVFX_MP3_Sword",
                //"BioVFX_MP3_Cone_Cold",
                //"BioVFX_MP3_OmniShield",
                //"BioVFX_DLC_Shared",
                //"BioVFX_DLC_MaleQuarian",
                //"BioVFX_DLC_OmniBlade",

                //// MP4
                //"BioVFX_MP4_Volus_Eng",
                //"BioVFX_DLC_MaleQuarian",
                //"BioVFX_MP4_Tur_Jets", // Produced no materials? Needs investigated. If left on the previous compiler level is leftover  and used
                //"BioVFX_DLC_OmniBlade",

                //// MP5
                //"BioVFX_MP5_Prothean", // Collector Adept
                //"EffectsMaterials_MP5", // Collector Adept // Contains Combined Effect

                //"BIOG_MP5_GTH_PLY_R", // Geth Destroyer
                //"BioVFX_MP5_GethPrime", // Geth Destroyer

                //"BIOG_MP_INF_FBT", // Fembot Infiltrator
                //"BioVFX_MP5_Cone_Cold", // Fembot Infiltrator
                //"BioVFX_MP5_Fembot", // Fembot Infiltrator

                //"BioVFX_MP5_Engineer", // UGH the Merc Engineer

                //"BIOG_WPN_MLE_R_MP5", // Krogan Warlord // Contains Combined Effect
                //"BioVFX_MP5_KroganWL", // Krogan Warlord

                //"BioVFX_MP5_Vanguard", // Turian Female
                //"BIOG_MP_VAN_TUF", // Turian Female


                
                ////Multiplayer levels
                //"BioApl_Lvl_Foliage",

                //// MPLobby
                //"MPLobby", // Black material

                //// Hydra:
                //"BioT_GthMP",
                //"BioVFX_DLC_Env_MPGeth",

                //// Condor:
                //"BioT_MPMoon",
                //"BioVFX_DLC_Env_MPMoon",

                //// Jade:
                //"BioS_MPJungle",
                //"BioS_MPJungle_Trash", // Todo: Why does water_tint, Waterfall_Master_lite not compile into something?
                //"BioT_MPJungle",
                //"BioT_Tropical",
                //"BioVFX_DLC_Env_MPJngl",
                
                //// Thessia:
                //"BioT_MPThes",

                //// Vancouver
                //"BioVFX_MP3_MPHosp",
                //"BioT_MPHosp",
                //"BioT_SolMP", // Is this actually here?
                
                //// Rio
                //"BioT_MPOcean",
                //"BioVFX_MP3_MPOcean",

                //// London
                //"BioS_MPLondon",

                //// Hazard Cer
                //"BioT_MPCer2",
                
                //// Hazard Dish
                //"BioT_MPDish2",

                //// Hazard Nov
                //"BioT_MPNov2",
                
                //// Hazard Reactor
                //"BioT_MPRctr2",

                //// Hazard Ghost
                //"biot_humanslumACID", // May need more.


                // More test stuff.
                /*
                //"Biot_Normandy_Int.pcc",
                //"BioApl_Lvl_Foliage.pcc",
                //"BioS_MPJungle.pcc",
                //"BioS_MPLondon.pcc",
                //"BIOG_PhotoModeFilters.pcc",
                //"biot_humanslumACID.pcc",
                //"BioT_MPCer2.pcc",
                //"BioT_MPHosp.pcc",
                //"BioT_MPOcean.pcc",
                //"BioT_MPThes.pcc",
                //"BioT_MPThes_Milan.pcc",
                //"BioT_SolMP.pcc",
                //"BioVFX_DLC_MP1_BatMelee.pcc",
                //"BioVFX_DLC_MP1_Geth.pcc",
                //"BioVFX_MP3_MPHosp.pcc",
                //"BioVFX_MP3_MPOcean.pcc",
                //"BioVFX_MP5_Gear.pcc"
            */
          ];

            // Quick override for debugging
#if DEBUG
            // files = ["BioS_MPJungle_Trash"];
#endif

            Console.WriteLine($"Source folders:");
            foreach (var path in MilanShaderPackageBuilder.SourceFolders)
            {
                Console.WriteLine($"\t{path}");
            }

            foreach (var f in files)
            {
                var realf = f;
                if (!realf.EndsWith(".pcc"))
                {
                    realf += ".pcc";
                }

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
                }
            }
        }
    }
}
