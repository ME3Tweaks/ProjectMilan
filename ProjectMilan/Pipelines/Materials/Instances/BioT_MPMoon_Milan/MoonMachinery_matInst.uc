// DONOR FOR: BioT_MPMoon.Materials.Machinery03_MatInst
properties
{
    VectorParameterValues = ({
                              ParameterValue = {R = 0.982825994, G = 0.75189501, B = 0.541797996, A = 1.20000005}, 
                              ExpressionGUID = {A = 696420813, B = 1233371789, C = -1757967698, D = 708982370}, 
                              ParameterName = 'Simple_Specular_color'
                             }, 
                             {
                              ParameterValue = {R = 1.0, G = 1.0, B = 1.0, A = 1.0}, 
                              ExpressionGUID = {A = -1839293441, B = 1324156877, C = 46767293, D = 1822514065}, 
                              ParameterName = 'Reflection_Color'
                             }, 
                             {
                              ParameterValue = {R = 0.5, G = 0.0, B = 1.0, A = 1.0}, 
                              ExpressionGUID = {A = -1389658645, B = 1147359236, C = -300800588, D = -1906116495}, 
                              ParameterName = 'Cubemap_Mixer'
                             }
                            )
    ScalarParameterValues = ({
                              ExpressionGUID = {A = 305610584, B = 1145734160, C = -1882679669, D = 204104427}, 
                              ParameterName = 'WhiteRange', 
                              ParameterValue = 80.0
                             }
                            )
    TextureParameterValues = ({
                               ExpressionGUID = {A = -1163050871, B = 1099654973, C = -2134475603, D = 1506491243}, 
                               ParameterName = 'NormalMap', 
                               ParameterValue = Texture2D'bioapl_ind_machinery03.Machinery03_Norm'
                              }, 
                              {
                               ExpressionGUID = {A = -454777832, B = 1311717803, C = -803461702, D = -2140455119}, 
                               ParameterName = 'MSK3 Red- Spec Green - Emis/Relfc Blue -Sppwr', 
                               ParameterValue = Texture2D'bioapl_ind_machinery03.Machinery03_Msk3'
                              }, 
                              {
                               ExpressionGUID = {A = -2142146212, B = 1077609301, C = 264735657, D = -1496597784}, 
                               ParameterName = 'Reflection_Cubemap', 
                               ParameterValue = TextureCube'BIOG_APL_MASTER_MATERIAL.PLC_MM_Cubemap'
                              }, 
                              {
                               ExpressionGUID = {A = -1587788694, B = 1175598233, C = 304702363, D = 1252390773}, 
                               ParameterName = 'Simple Diffuse', 
                               ParameterValue = Texture2D'bioapl_ind_machinery03.Machinery03_Diff'
                              }
                             )
    ParentLightingGuid = {A = 640129124, B = 1164234618, C = -406985026, D = -989642345}
    PhysMaterial = PhysicalMaterial'BIOG_PHM_General_F.PHM_GEN_DenseMetal_01'
    Parent = Material'BIOG_APL_MASTER_MATERIAL.Placeable_MM'
    m_Guid = {A = -1902423762, B = 1247477650, C = 190857093, D = -490424139}
    LightingGuid = {A = 1988627247, B = 1303657807, C = -730970470, D = -823414710}
}