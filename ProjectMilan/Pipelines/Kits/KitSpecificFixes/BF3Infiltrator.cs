using LegendaryExplorerCore.Unreal;
using System;
using System.Collections.Generic;
using System.Text;
using LegendaryExplorerCore.Packages;
namespace ProjectMilan.Pipelines.Kits.KitSpecificFixes
{
    internal class BF3Infiltrator
    {
        public static void ApplyPostFixes(KitSpecificPipeline kit)
        {
            var mtr = kit.PortedPackage.FindExport("BioChar_MPPlayers.Archetypes.Infiltrator.HumanFemale_InfiltratorBF3");

            // Change the UIWorld pawn archetype
            var correctUiWorldArchetype = kit.PortedPackage.FindExport("BioChar_MPPlayers.Archetypes.UIWorld.HMF_InfiltratorBF3_UIWORLD");
            mtr.WriteProperty(new ObjectProperty(correctUiWorldArchetype, "UIWorldArchetype"));
        }
    }
}
