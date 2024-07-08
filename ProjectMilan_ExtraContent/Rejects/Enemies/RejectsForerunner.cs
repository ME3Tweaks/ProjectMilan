using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using ProjectMilan_ExtraContent.Shared;
using ProjectMilanCore;

namespace ProjectMilan_ExtraContent.Rejects.Enemies
{
    // Changes:
    // - Mesh changed for theming.
    // - Cloak ability adjusted for MP use
    // - Weapon stats lowered
    // - Cloak runs on pawn for replication.
    // - Pawn can die now
    internal class RejectsForerunner
    {
        public static void PrePort(RejectsPipeline.RejectVars vars, IMEPackage sourcePackage)
        {
            //ChangeMesh(vars, sourcePackage);
            ChangeAI(vars, sourcePackage);
        }

        /// <summary>
        /// Changes Brooks AI so she can die.
        /// </summary>
        /// <param name="vars"></param>
        /// <param name="sourcePackage"></param>
        private static void ChangeAI(RejectsPipeline.RejectVars vars, IMEPackage sourcePackage)
        {
            // Create memory unique package and move memory unique objects under it.
            var sfxgcMilan = ExportCreator.CreatePackageExport(sourcePackage, MilanPackages.SFXGameContentMilan);
            var sfxgcFFAI = MilanShared.MoveExport(sourcePackage, "SFXGameContentDLC_EXP_Pack003.SFXAI_FemmeFatale", sfxgcMilan, "SFXAI_Forerunner");
            var sfxgcFFP = MilanShared.MoveExport(sourcePackage, "SFXGameContentDLC_EXP_Pack003.SFXPawn_FemmeFatale", sfxgcMilan, "SFXPawn_Forerunner");
            var sfxgcFFBC = MilanShared.MoveExport(sourcePackage, "SFXGameContentDLC_EXP_Pack003.SFXAICmd_Base_FemmeFatale", sfxgcMilan, "SFXAICmd_Base_Forerunner");
            var sfxgcFFFC = MilanShared.MoveExport(sourcePackage, "SFXGameContentDLC_EXP_Pack003.SFXAICmd_Reaction_FemmeFlee", sfxgcMilan, "SFXAICmd_Reaction_ForerunnerFlee");


            // Compile new class data
            SharedECPipelines.CompileClassOn(sfxgcFFP, null, vars.Cache, EExtraContent.Rejects, "Forerunner");
            SharedECPipelines.CompileClassOn(sfxgcFFAI, null, vars.Cache, EExtraContent.Rejects, "Forerunner");
            SharedECPipelines.CompileClassOn(sfxgcFFBC, null, vars.Cache, EExtraContent.Rejects, "Forerunner");
            SharedECPipelines.CompileClassOn(sfxgcFFFC, null, vars.Cache, EExtraContent.Rejects, "Forerunner");
        }

        private static void ChangeMesh(RejectsPipeline.RejectVars vars, IMEPackage sourcePackage)
        {
            var newAssetP = Path.Combine(SharedECPipelines.ECPipelineRoot, "Rejects", "Assets", "MeshPackages", "Forerunner.pcc");

            var pyroAsset = new PortingAsset() { SourceFile = newAssetP, AssetIFP = "BIOG_GTH_ASS_NKD_R.NKDa.GTH_ASS_NKDa_MDL", PostPortingDelegate = SetupForerunnerMesh };
            SharedECPipelines.PortAsset(vars, pyroAsset, sourcePackage);
        }

        private static void SetupForerunnerMesh(RejectsPipeline.RejectVars vars, ExportEntry mdl)
        {
            var archetypeMesh = mdl.FileRef.FindExport("Char_Enemies_Citadel.Bosses.FemmeFatale.BioPawnSkeletalMeshComponent");
            archetypeMesh.RemoveProperty("Materials"); // Use the mesh one instead
            archetypeMesh.WriteProperty(new ObjectProperty(mdl, "SkeletalMesh"));

            mdl.FileRef.FindExport("Char_Enemies_Citadel.Bosses.FemmeFatale.HeadMesh0").RemoveProperty("SkeletalMesh"); // Remove brooks head, as it is part of body mesh
        }
    }
}