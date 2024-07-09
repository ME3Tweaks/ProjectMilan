using LegendaryExplorerCore.Packages;
using ProjectMilan_ExtraContent.Shared;
using ProjectMilanCore;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Unreal;

namespace ProjectMilan_ExtraContent.Rejects.Enemies
{
    // Changes:
    // - Remove sync attack (?)
    // - Setup with power usages
    // - Set meshes for theming, including missing head.
    // - Add execution move that kills players if it causes them to go down.
    // - Change weapon
    internal class RejectsExecutioner
    {
        /// <summary>
        /// Changes the executioner's AI to allow them to die, change powers and loadouts.
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


            // Change dmgmodule to standard one
            sourcePackage.FindExport("BIOG_CSM_Appr_L.CloneShepardMale_ARC.DmgMod1").Class = sourcePackage.FindEntry("SFXGame.SFXModule_Damage");
            sourcePackage.FindExport("Char_Enemies_Citadel.Bosses.CloneShepardMale.DmgMod1").Class = sourcePackage.FindEntry("SFXGame.SFXModule_Damage");

            // Rearchetype
            var sfxgcEXP = sourcePackage.FindExport($"{MilanPackages.SFXGameContentMilan}.SFXPawn_Executioner");
            // Change over classes of archetypes.
            var spawnableArchetype = sourcePackage.FindExport("Char_Enemies_Citadel.Bosses.CloneShepardMale");
            RejectsShared.ChangeoverArchetype(spawnableArchetype, sfxgcEXP);


        }

        public static void PrePort(RejectsPipeline.RejectVars vars, IMEPackage package)
        {
            ChangeMesh(vars, package);
            ChangeAI(vars, package);

            // Debug: Save package for inspection.
            var debug = Directory.CreateDirectory(Path.Combine(SharedECPipelines.ECPipelineRoot, EExtraContent.Rejects.ToString(), "Debugging")).FullName;
            package.Save(Path.Combine(debug, "Clone-PrePort.pcc"));
        }

        private static void ChangeMesh(RejectsPipeline.RejectVars vars, IMEPackage package)
        {
        }
    }
}
