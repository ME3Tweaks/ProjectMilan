// DONOR FOR: BioT_MPMoon.Materials.Rubber_INST
properties
{
    VectorParameterValues = ({
                              ParameterValue = {R = 10.0, G = 10.0, B = 10.0, A = 1.0}, 
                              ExpressionGUID = {A = -1132826722, B = 1293633639, C = -1393058172, D = -108990786}, 
                              ParameterName = 'Spec_Color_Intensity'
                             }, 
                             {
                              ParameterValue = {R = 20.0, G = 20.0, B = 20.0, A = 1.0}, 
                              ExpressionGUID = {A = 741009932, B = 1156271483, C = -211773771, D = 1797625613}, 
                              ParameterName = 'SpecIMG_Color_Intensity'
                             }, 
                             {
                              ParameterValue = {R = 1.0, G = 1.0, B = 1.0, A = 1.0}, 
                              ExpressionGUID = {A = -677349650, B = 1324346417, C = -2114444113, D = -480468796}, 
                              ParameterName = 'Emis_Color_Intensity'
                             }, 
                             {
                              ParameterValue = {R = 1.42499995, G = 1.42919564, B = 1.5, A = 1.0}, 
                              ExpressionGUID = {A = -1845211325, B = 1089600297, C = -1531505267, D = 199088249}, 
                              ParameterName = 'Diff_tint'
                             }, 
                             {
                              ParameterValue = {R = 44.5, G = 47.0666656, B = 50.0, A = 16.0}, 
                              ExpressionGUID = {A = -220251332, B = 1334901526, C = 790766774, D = 770229680}, 
                              ParameterName = 'Cubemap_Color_Intensity'
                             }
                            )
    ScalarParameterValues = ({
                              ExpressionGUID = {A = -1556450856, B = 1297626587, C = 978721211, D = 1626861026}, 
                              ParameterName = 'Base_Mat_Tile', 
                              ParameterValue = 1.0
                             }, 
                             {
                              ExpressionGUID = {A = -945470169, B = 1313968245, C = 747995825, D = 1241772759}, 
                              ParameterName = 'Detail_Norm_Tile', 
                              ParameterValue = 0.25
                             }, 
                             {
                              ExpressionGUID = {A = -460242515, B = 1137608852, C = 1298972606, D = 1964668344}, 
                              ParameterName = 'Detail_Norm_Intensity', 
                              ParameterValue = 0.200000003
                             }, 
                             {
                              ExpressionGUID = {A = -806871047, B = 1118161387, C = 1452638620, D = -150387646}, 
                              ParameterName = 'Spec_Pwr', 
                              ParameterValue = 4.0
                             }, 
                             {
                              ExpressionGUID = {A = -1631132487, B = 1199822802, C = 894642078, D = -357168641}, 
                              ParameterName = 'Det_Spec_Min_Clamp', 
                              ParameterValue = 0.5
                             }, 
                             {
                              ExpressionGUID = {A = -298854000, B = 1240733766, C = -1958801499, D = -1978873846}, 
                              ParameterName = 'Detail_Spec_Tile', 
                              ParameterValue = 0.100000001
                             }, 
                             {
                              ExpressionGUID = {A = 1303689333, B = 1223531492, C = 1068441269, D = 1628826190}, 
                              ParameterName = 'Spec_IMG_A_Scale', 
                              ParameterValue = 20.0
                             }
                            )
    TextureParameterValues = ({
                               ExpressionGUID = {A = 832284228, B = 1086289547, C = 816512918, D = 49113717}, 
                               ParameterName = 'Base_Normal', 
                               ParameterValue = Texture2D'BioT_TurianArmy.Textures.RubberMat_NORM'
                              }, 
                              {
                               ExpressionGUID = {A = -1984118487, B = 1141827405, C = -1245970758, D = -1034046933}, 
                               ParameterName = 'Detail_Norm', 
                               ParameterValue = Texture2D'BioG_MasterMats.Texture_Samples.Detail_Norm_01'
                              }, 
                              {
                               ExpressionGUID = {A = 769254756, B = 1304560225, C = 1625558180, D = 1426810646}, 
                               ParameterName = 'Diffuse', 
                               ParameterValue = Texture2D'BioT_TurianArmy.Textures.RubberMat_DIFF'
                              }, 
                              {
                               ExpressionGUID = {A = -1285972443, B = 1177081782, C = -1030234219, D = 496669779}, 
                               ParameterName = 'Detail_Spec', 
                               ParameterValue = Texture2D'BioG_MasterMats.Texture_Samples.Spec_Tile_A'
                              }, 
                              {
                               ExpressionGUID = {A = 1539139102, B = 1111203196, C = -1203704146, D = 972364597}, 
                               ParameterName = 'Spec_IMG_A', 
                               ParameterValue = Texture2D'BioG_MasterMats.Texture_Samples.Spec_HS_H'
                              }, 
                              {
                               ExpressionGUID = {A = 358677632, B = 1326787886, C = 1886185634, D = -219808426}, 
                               ParameterName = 'CubeMap', 
                               ParameterValue = TextureCube'BioG_MasterMats.Texture_Samples.Cubemap_05'
                              }
                             )
    ParentLightingGuid = {A = -1694286093, B = 1131220765, C = 1978044079, D = 674962132}
    PhysMaterial = PhysicalMaterial'BIOG_PHM_General_F.PHM_GEN_Rubber_01'
    Parent = Material'BioG_MasterMats.Material_Parents.ME3_OPAQUE_MM'
    m_Guid = {A = 1872913192, B = 1276084224, C = 477408918, D = 979563329}
    LightingGuid = {A = -1635880772, B = 1226344366, C = -876935749, D = 680284367}
}