
namespace ProjectMilan.Pipelines.Shared.GlobalDonors.Material
{
    /// <summary>
    /// Donors for all materials ME3 -> LE3
    /// </summary>
    public class GlobalMaterial
    {
        public static Dictionary<Guid, Guid> GetMapping()
        {
            var mapping = new Dictionary<string, string>()
            {
                // Format is 2 lines:
                // // OT NAME -> LE NAME AND FUNCTION
                // {ME3GUID, LE3GUID},
                
                // Null values are not returned.
                // Only set values if you have a direct LE shader you can use,
                // otherwise use a donor object.

                // MPGETH ------------------------------------------------------------------------------
                // BioT_GthMP.Sky_Mat -> BioT_Thessia.Clouds (MPGeth Sky)
                { "f4246b68-9887-4b6f-a721-d6cdec74a9b0", "4b35607b-4dd1-4734-ac37-1a88acf2607a" },
                // BioVFX_DLC_Env_MPGeth.Materials.Smoke_Misty -> BioT_Archives.Smoke_Misty ()
                {"8bab4e80-efe4-496b-9737-c60cb0b271de", "26c4c5cb-6cbd-46aa-844c-1d0d5fba346e"}, // Might need some work

                // BioT_GthMP.Materials.Mat.MPG_ConcreteDam -> ??? (??)
                {"9c4ea809-311c-4d52-a316-57266fe8958e", null},
                // BioT_GthMP.Materials.Inst.MPG_ConcreteTrims_INST -> ??? (??)
                {"64acf75d-f141-4173-a268-402627cbe128", null},
                // BioT_GthMP.Materials.Waterfall_Dam_02 -> ??? (??)
                {"d5462c3d-2b30-4387-95ca-cf9c3577b12e", null},
                // BioT_GthMP.Mountain_MAT -> ??? (??)
                {"a3007f06-7f12-488f-b317-da543c11a364", null},
                // BioVFX_DLC_Env_MPGeth.Materials.Water_Dam_Card -> ??? (??)
                {"8da4fce1-ebaa-45c9-a86d-1513dde2c024", null},
                // BioT_GthMP.Materials.Mat.MPG_DamLights_MAT -> ??? (??)
                {"6fb6d9d4-bea6-4d6c-b607-95c73ad7e3e7", null},
                // BioT_GthMP.Materials.Inst.MPG_Concrete_INST -> ??? (??)
                {"214fd2da-4c3a-4669-815b-3f9dfedd3c87", null},
                // BioT_GthMP.Materials.Inst.GthMP_AlienText_Ins -> ??? (??)
                {"3e6cd148-7272-4fc5-a155-955f6c61b735", null},
                // biot_krogru.MatlInstances.KroGru_Blend_Ground_INST04 -> ??? (??)
                {"1e6fd986-9a85-48b4-b76c-50ddf4c3bf79", null},
                // BioVFX_DLC_Env_MPGeth.Materials.Dam_WaterSpout_mat -> ??? (??)
                {"2e62a719-e920-4b04-aaba-8a802fc2b8f6", null},
                // BioT_GthMP.Atmospheric_Mist02 -> ??? (??)
                {"53c14f39-087e-41f3-8712-ad4684804a72", null},
                // BioVFX_DLC_Env_MPGeth.Materials.Water_Impact -> ??? (??)
                {"7849c514-3d26-4b94-9724-310d20909195", null},
                // BioVFX_DLC_Env_MPGeth.Materials.Ripple_3 -> ??? (??)
                {"f44d89f4-df68-41fe-9461-778ad254cd3f", null},
                // BioT_GthMP.LIGHT_GLOW -> ??? (??)
                {"9f57e90a-dc62-4041-a070-ae77017cd1a2", null},
                // BioT_GthMP.Crate01_Dirty_M_MatInst -> ??? (??)
                {"0a8051a8-3a62-43f7-a383-0041cf6e0e58", null},
                // BioT_GthMP.Ocean_GthMP -> ??? (??)
                {"f9485609-6ef7-43a1-98eb-e657a6556ac4", null},
                // BioT_GthMP.Materials.Waterfall_Dam_01 -> ??? (??)
                {"404716f4-be47-4af4-a902-aa05d7924a2d", null},
                // BioT_GthMP.Materials.Geth_Pod01_Frame_MatInst -> ??? (??)
                {"673ea243-c3f2-43aa-a601-c08e00de9ac5", null},
                // BioT_GthMP.LIGHT_GLOW_TUNNEL -> ??? (??)
                {"dad43532-fa20-4d11-bae6-9c88c0f118e6", null},
                // BioT_GthMP.Materials.LD_Metal_BUNKER01 -> ??? (??)
                {"9070a708-8925-4657-bed0-50b52f4e5b0c", null},
                // BioT_GthMP.Materials.Mat.MPG_ConcreteDam02 -> ??? (??)
                {"f271306e-5805-462b-b7d0-ed85d367a3ef", null},
                // BioT_GthMP.Materials.Mat.MPG_ConcreteBasebunker -> ??? (??)
                {"d95d45b5-258c-4ebd-a326-b7ccaf15ef44", null},
                // BioT_GthMP.Materials.Concrete_trimsA -> ??? (??)
                {"e5864299-444b-4500-b60e-583bb76b1362", null},
                // BioT_GthMP.Materials.Mat.MPG_ConcreteBase -> ??? (??)
                {"ddf99df9-0ab0-42af-9026-3783a7959c99", null},
                // BioVFX_DLC_Env_MPGeth.Materials.Generator_EMP_Wave -> ??? (??)
                {"d39c8dbb-479f-4591-a3ff-a969a5235948", null},

            };

            // Map to guid mapping. Do not map null values
            return mapping.Where(x => x.Value != null).ToDictionary(x => new Guid(x.Key), x => new Guid(x.Value));
        }
    }
}