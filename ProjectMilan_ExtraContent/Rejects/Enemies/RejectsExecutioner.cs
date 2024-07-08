using LegendaryExplorerCore.Packages;
using ProjectMilan_ExtraContent.Shared;
using ProjectMilanCore;
using System;
using System.Collections.Generic;
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
            var sfxgcMilan = ExportCreator.CreatePackageExport(sourcePackage, MilanPackages.SFXGameContentMilan);
            var sfxgcEXAI = MilanShared.MoveExport(sourcePackage, "SFXGameContentDLC_EXP_Pack003.SFXAI_CloneShepard", sfxgcMilan, "SFXAI_Executioner");
            var sfxgcEXP = MilanShared.MoveExport(sourcePackage, "SFXGameContentDLC_EXP_Pack003.SFXPawn_CloneShepard", sfxgcMilan, "SFXPawn_Executioner");
            var sfxgcEXBC = MilanShared.MoveExport(sourcePackage, "SFXGameContentDLC_EXP_Pack003.SFXAICmd_Base_CloneShepard", sfxgcMilan, "SFXAICmd_Base_Executioner");


            // Compile new class data
            SharedECPipelines.CompileClassOn(sfxgcEXP, null, vars.Cache, EExtraContent.Rejects, "Executioner");
            SharedECPipelines.CompileClassOn(sfxgcEXAI, null, vars.Cache, EExtraContent.Rejects, "Executioner");
            SharedECPipelines.CompileClassOn(sfxgcEXBC, null, vars.Cache, EExtraContent.Rejects, "Executioner");

            // Change archetype class up one from CloneShepard_Male to just CloneShepard (now Executioner)
            sourcePackage.FindExport("Char_Enemies_Citadel.Bosses.CloneShepardMale").Class = sfxgcEXP;

            // Archetype for looks needs class changed and moved for uniqueness
            var arc = sourcePackage.FindExport("BIOG_CSM_Appr_L.CloneShepardMale_ARC");
            arc.Class = sfxgcEXP;
            arc.WriteProperty(new NameProperty("None", "Tag"));
            var apprMilan = ExportCreator.CreatePackageExport(sourcePackage, MilanPackages.BIOG_Milan_Appearances);
            MilanShared.MoveExport(sourcePackage, arc.InstancedFullPath, apprMilan, "Executioner_ARC");

            // We need to change archetypes on this to archetype onto our pawn and not the subclass that existed or it will try to bring that in as well. We also need to retype the damage module.
            ChangeoverArchetype(arc);
        }

        /// <summary>
        /// Converts archetypes from Default__SFXPawn_CloneShepard_Male -> Default__SFXPawn_Executioner
        /// </summary>
        /// <param name="export"></param>
        /// <exception cref="NotImplementedException"></exception>
        private static void ChangeoverArchetype(ExportEntry export)
        {
            if (export.HasArchetype && export.Archetype.InstancedFullPath.Contains("Default__SFXPawn_CloneShepard_Male"))
            {
                var newArchetype = export.Archetype.InstancedFullPath.Replace("Default__SFXPawn_CloneShepard_Male", "Default__SFXPawn_Executioner");
                export.Archetype = export.FileRef.FindExport(newArchetype);
            }

            // Check for sub objects.
            var properties = export.GetProperties();
            foreach (var prop in properties)
            {
                if (prop is ObjectProperty { Value: > 0 } op)
                {
                    ChangeoverArchetype(export.FileRef.GetUExport(op.Value));
                    continue;
                }

                if (prop is ArrayProperty<ObjectProperty> ops)
                {
                    foreach (var op2 in ops.Where(x => x.Value > 0))
                    {
                        ChangeoverArchetype(export.FileRef.GetUExport(op2.Value));
                    }
                }
            }

            // Also fix the damage module here for simplicity
            if (export.ClassName == "SFXModule_Damage_Clone")
                export.Class = export.FileRef.FindEntry("SFXGame.SFXModule_Damage");
        }

        public static void PrePort(RejectsPipeline.RejectVars vars, IMEPackage package)
        {
            ChangeMesh(vars, package);
            ChangeAI(vars, package);
        }

        private static void ChangeMesh(RejectsPipeline.RejectVars vars, IMEPackage package)
        {
        }
    }
}
