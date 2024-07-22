using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Packages;
using ProjectMilanCore;

namespace ProjectMilan_ExtraContent.Rejects.Enemies
{
    // Changes:
    // - Change rocket attack to MIRV Bunker Buster. Possibly have it:
    //     - Drop less grenades on impact than a normal MIRV
    //     - Drop grenades in-flight so the area under is also bombed (few)
    //     - Drop different bomb types that do different things
    //     - Do friendly damage because he is pretty OP with lots of grenades.
    internal class RejectsCatlas
    {
        public static void PrePort(RejectsPipeline.RejectVars vars, IMEPackage package)
        {
            ChangeAI(vars, package);
        }

        /// <summary>
        /// Changes the Catlas AI to remove the driver mechanic, use MIRV bomb attack
        /// </summary>
        /// <param name="vars"></param>
        /// <param name="sourcePackage"></param>
        private static void ChangeAI(RejectsPipeline.RejectVars vars, IMEPackage sourcePackage)
        {
            // Create memory unique package and move memory unique objects under it.
            //var sfxgcEXAI = MilanShared.MoveExport(sourcePackage, "SFXGameContentDLC_EXP_Pack003.SFXAI_CloneShepard", sfxgcMilan, "SFXAI_Executioner");
            ///xvvar sfxgcEXP = MilanShared.MoveExport(sourcePackage, "SFXGameContentDLC_EXP_Pack003.SFXPawn_CloneShepard", sfxgcMilan, "SFXPawn_Executioner");
            //var sfxgcEXBC = MilanShared.MoveExport(sourcePackage, "SFXGameContentDLC_EXP_Pack003.SFXAICmd_Base_CloneShepard", sfxgcMilan, "SFXAICmd_Base_Executioner");


            //// Compile new class data
            //SharedECPipelines.CompileClassOn(sfxgcEXP, null, vars.Cache, EExtraContent.Rejects, "Executioner");
            //SharedECPipelines.CompileClassOn(sfxgcEXAI, null, vars.Cache, EExtraContent.Rejects, "Executioner");
            //SharedECPipelines.CompileClassOn(sfxgcEXBC, null, vars.Cache, EExtraContent.Rejects, "Executioner");


            // Rearchetype
            var sfxgcEXP = sourcePackage.FindExport($"{MilanPackages.SFXGameContentMilan}.SFXPawn_Catlas");
            // Change over classes of archetypes.
            var spawnableArchetype = sourcePackage.FindExport("Char_Enemies_Citadel.Atlas");
            RejectsShared.ChangeoverArchetype(spawnableArchetype, sfxgcEXP);
        }
    }
}
