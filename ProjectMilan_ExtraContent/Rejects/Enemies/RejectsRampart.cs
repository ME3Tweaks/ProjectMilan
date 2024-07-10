using LegendaryExplorerCore.Packages;
using ProjectMilan_ExtraContent.Shared;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilanCore;

namespace ProjectMilan_ExtraContent.Rejects.Enemies
{
    // Changes:
    // - Textures changed for theming.
    // - Death effects replicated to clients by moving to pawn.
    internal class RejectsRampart
    {
        public static void PrePort(RejectsPipeline.RejectVars vars, IMEPackage sourcePackage)
        {
            ChangeLook(sourcePackage);

            var archetype = sourcePackage.FindExport("Char_Omega_Enemies.Archetypes.Rampart_Combat");
            var pawnClass = sourcePackage.FindExport($"{MilanPackages.SFXGameContentMilan}.SFXPawn_RampartMP");
            RejectsShared.ChangeoverArchetype(archetype, pawnClass);
        }

        private static void ChangeLook(IMEPackage sourcePackage)
        {
            // Change look. Create unique memory assets.
            // Port mesh with new name, and use a new named material that references our new textures.
            // Compared to just making a mat override, this doesn't port in textures that then go unused, taking time to async load before wave start.
            var biog = ExportCreator.CreatePackageExport(sourcePackage, MilanPackages.BIOG_RampartMP);
            SharedECPipelines.InstallTextures(EExtraContent.Rejects, "Enemies", "RampartMP", sourcePackage, biog);

            var mat1a = MilanShared.MoveExport(sourcePackage, "biog_mch_lok_r.LOKb.BIOG_MCH_LOKb_R_Mat1a", biog);
            mat1a.ObjectName = $"{MilanPackages.BIOG_RampartMP}.Mat1aCAT6";

            var mdl = MilanShared.MoveExport(sourcePackage, "biog_mch_lok_r.BIOG_MCH_LOK_MDL", biog, "BIOG_MCH_LOK_MDL_CAT6");
        }

        private static void ChangeMesh(RejectsPipeline.RejectVars vars, IMEPackage sourcePackage)
        {
            //var newAssetP = Path.Combine(SharedECPipelines.ECPipelineRoot, "Rejects", "Assets", "Textures", "Enemies", "Rampart");

            //var meshAsset = new PortingAsset() { SourceFile = newAssetP, AssetIFP = "BIOG_HMF_ARM_NBK_R.NBKa.HMF_ARM_NBKa_MDL", PostPortingDelegate = SetupForerunnerMesh };
            //SharedECPipelines.PortAsset(vars, meshAsset, sourcePackage);
        }

    }
}
