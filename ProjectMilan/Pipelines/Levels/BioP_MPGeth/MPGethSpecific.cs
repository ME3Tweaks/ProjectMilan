using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilan.Utility;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Levels.BioP_MPGeth
{
    internal class MPGethSpecific
    {
        public static void PreCorrect(LevelSpecificPipeline pipeline)
        {
            // Fix Dread walkway 04 not having a rigid body by porting one from identical mesh in SP.
            var mp100 = pipeline.ME3Packages.FirstOrDefault(x => x.Key.CaseInsensitiveEquals("BioA_MPGeth_100"));
            var dreadRBPackage = MilanShared.GetME3Package("BioA_GthLeg_100.pcc");
            var dreadRB = dreadRBPackage.FindExport("bios_quarian.Dread_Walkway_04.RB_BodySetup_4");
            var dreadGeth = mp100.Value.FindExport("BioS_GthMP.Dread_Walkway_04");
            EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, dreadRB, mp100.Value, dreadGeth, true, new RelinkerOptionsPackage(), out var newRb);

            var bin = ObjectBinary.From<StaticMesh>(dreadGeth);
            bin.BodySetup = newRb.UIndex;
            dreadGeth.WriteBinary(bin);
        }
    }
}
