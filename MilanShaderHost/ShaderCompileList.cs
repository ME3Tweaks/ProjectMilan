using System;
using System.Collections.Generic;
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
        /// Generates the list of packages to compile shaders in.
        /// </summary>
        internal static void SetupFileList()
        {
            string[] files = [
                
                // TEST
                "EngineMaterials",

                // Existing: For test comparison
                //"BioS_CitApt_Alt.pcc",
                //"BioS_CitCasino.pcc",
                //"BioS_CitCouncil.pcc",
                //"BioS_CitRestaurant.pcc",
                //"BioS_CitSim.pcc",
                //"BioS_CitSim_Alt.pcc",
                //"BioS_CitStreets.pcc",
                //"BioS_CitWards.pcc",
                //"BioS_Cit_lev004.pcc"
                //"BioT_Arctic",
                //"biot_ancientcity.pcc",

                // Tropical:
                //"BIOA_NOR10_T.pcc",
                //"BIOA_STA60_T.pcc",
                //"BIOA_STA60_02_T.pcc",
                ////"BIOA_PRC2_MatFX.pcc",
                //"BIOA_STA30_T.pcc",
                //"BIOA_JUG40_T.pcc",
                //"BIOA_Jug20_T.pcc",
                //"BIOA_JUG80_T.pcc",
                //"BIOA_JUG00_T.pcc",
                ////"BIOG_APL_PHY_Crate_XLarge_01_L.pcc",
                //"BIOG__SKIES__.pcc",
                ////"BIOA_FRE10_T.pcc",
                ////"BIOA_LOS40_APL_DOR_FFDoor_L.pcc",
                //"BIOG_V_Env_Jug_WaveCrash_Z.pcc",
                ////"VFX_zz_ME1_Global_METR.pcc",
                ////"BIOG_V_Env_Hologram_Z.pcc",
                ////"BIOA_LAV20_T.pcc"

                //Multiplayer levels
                /*
                "BioApl_Lvl_Foliage",

                // MPLobby
                "MPLobby", // Black material

                // Hydra:
                "BioT_GthMP",
                "BioVFX_DLC_Env_MPGeth",

                // Condor:
                "BioT_MPMoon",
                "BioVFX_DLC_Env_MPMoon",

                // Jade:
                "BioS_MPJungle",
                "BioS_MPJungle_Trash",
                "BioT_MPJungle",
                "BioT_Tropical",
                "BioVFX_DLC_Env_MPJngl",
                
                // Thessia:
                "BioT_MPThes",

                // Hazard Ghost
                "biot_humanslumACID", // May need more. */



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
            ];

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
