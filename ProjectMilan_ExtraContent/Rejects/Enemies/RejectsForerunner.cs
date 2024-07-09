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
            ChangeMesh(vars, sourcePackage);
            ChangePawnClass(vars, sourcePackage);
        }

        /// <summary>
        /// Changes the archetype over to the new pawn class.
        /// </summary>
        /// <param name="vars"></param>
        /// <param name="sourcePackage"></param>
        private static void ChangePawnClass(RejectsPipeline.RejectVars vars, IMEPackage sourcePackage)
        {
            var sfxgcEXP = sourcePackage.FindExport($"{MilanPackages.SFXGameContentMilan}.SFXPawn_Forerunner");

            // Change archetype class up one from CloneShepard_Male to just CloneShepard (now Executioner)
            var spawnArchetype = sourcePackage.FindExport("Char_Enemies_Citadel.Bosses.FemmeFatale");
            spawnArchetype.Class = sfxgcEXP;

            RejectsShared.ChangeoverArchetype(spawnArchetype, sfxgcEXP);

        }

        private static void ChangeMesh(RejectsPipeline.RejectVars vars, IMEPackage sourcePackage)
        {
            var newAssetP = Path.Combine(SharedECPipelines.ECPipelineRoot, "Rejects", "Assets", "MeshPackages", "Forerunner.pcc");

            var meshAsset = new PortingAsset() { SourceFile = newAssetP, AssetIFP = "BIOG_HMF_ARM_NBK_R.NBKa.HMF_ARM_NBKa_MDL", PostPortingDelegate = SetupForerunnerMesh };
            SharedECPipelines.PortAsset(vars, meshAsset, sourcePackage);
        }

        private static void SetupForerunnerMesh(RejectsPipeline.RejectVars vars, ExportEntry mdl)
        {
            var archetypeMesh = mdl.FileRef.FindExport("Char_Enemies_Citadel.Bosses.FemmeFatale.BioPawnSkeletalMeshComponent");
            archetypeMesh.RemoveProperty("Materials"); // Use the mesh one instead
            archetypeMesh.WriteProperty(new ObjectProperty(mdl, "SkeletalMesh"));

            mdl.FileRef.FindExport("Char_Enemies_Citadel.Bosses.FemmeFatale.HeadMesh0").RemoveProperty("SkeletalMesh"); // Remove brooks head, as it is part of body mesh
            mdl.FileRef.FindExport("Char_Enemies_Citadel.Bosses.FemmeFatale.HairMesh0").RemoveProperty("SkeletalMesh"); // Remove brooks hair, as it is part of body mesh
        }
    }
}