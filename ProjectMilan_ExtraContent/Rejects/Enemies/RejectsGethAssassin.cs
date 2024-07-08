using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using ProjectMilan_ExtraContent.Shared;

namespace ProjectMilan_ExtraContent.Rejects.Enemies
{
    // Changes:
    // - Entire pawn pretty much is custom made
    internal class RejectsGethAssassin
    {
        public static void PrePort(RejectsPipeline.RejectVars vars, IMEPackage sourcePackage)
        {
            ChangeMesh(vars, sourcePackage);
        }

        private static void ChangeMesh(RejectsPipeline.RejectVars vars, IMEPackage sourcePackage)
        {
            var newAssetP = Path.Combine(SharedECPipelines.ECPipelineRoot, "Rejects", "Assets", "MeshPackages", "GethAssassin.pcc");

            var pyroAsset = new PortingAsset() { SourceFile = newAssetP, AssetIFP = "BIOG_GTH_ASS_NKD_R.NKDa.GTH_ASS_NKDa_MDL", PostPortingDelegate = SetupGethAssassin };
            SharedECPipelines.PortAsset(vars, pyroAsset, sourcePackage);
        }

        private static void SetupGethAssassin(RejectsPipeline.RejectVars vars, ExportEntry mdl)
        {
            var archetypeMesh = mdl.FileRef.FindExport("BioChar_Cat004.Archetypes.Nemesis_Legion.BioPawnSkeletalMeshComponent");
            archetypeMesh.RemoveProperty("Materials"); // Use the mesh one instead
            archetypeMesh.WriteProperty(new ObjectProperty(mdl, "SkeletalMesh"));

            mdl.FileRef.FindExport("BioChar_Cat004.Archetypes.Nemesis_Legion.HeadMesh0").RemoveProperty("SkeletalMesh"); // Remove legion's head
        }
    }
}
