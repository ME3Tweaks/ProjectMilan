// DONOR FOR: BioT_GthMP.Materials.LD_Metal_BUNKER01
properties
{
    ParentLightingGuid = {A = 2127490461, B = 1100188867, C = -609135202, D = 1877982505}
    Parent = Material'BioG_LevelDetails.Materials.LD_Hardsurfaces_MM'
    LightmassSettings = {EmissiveBoost = 0.0}
    m_Guid = {A = -560170483, B = 1127562480, C = 1878500754, D = 1855756627}
    LightingGuid = {A = -1381116357, B = 1244193631, C = 987175347, D = -1174306676}
    VectorParameterValues = ({
                              ParameterValue = {R = 1.0, G = 1.0, B = 1.0, A = 0.25}, 
                              ExpressionGUID = {A = -1735113891, B = 1290001279, C = 44018859, D = 2083394865}, 
                              ParameterName = 'Spec_Color_Intensity'
                             }, 
                             {
                              ParameterValue = {R = 0.208360001, G = 0.208360001, B = 0.208360001, A = 1.0}, 
                              ExpressionGUID = {A = 1485213532, B = 1205261266, C = -1710902372, D = 1204055150}, 
                              ParameterName = 'Mat_Tint_General'
                             }, 
                             {
                              ParameterValue = {R = 0.208360001, G = 0.208360001, B = 0.208360001, A = 1.0}, 
                              ExpressionGUID = {A = 1755396067, B = 1188964446, C = -1367353164, D = -4187132}, 
                              ParameterName = 'Mat_Tint_White'
                             }, 
                             {
                              ParameterValue = {R = 6.0, G = 6.0, B = 6.0, A = 1.0}, 
                              ExpressionGUID = {A = -1412059012, B = 1088008489, C = -193669468, D = -1250422499}, 
                              ParameterName = 'Cubemap_Color_Intensity'
                             }, 
                             {
                              ParameterValue = {R = 0.673048973, G = 0.344025999, B = 0.238828003, A = 0.0}, 
                              ExpressionGUID = {A = -1356280137, B = 1107257516, C = -1441108559, D = -603214018}, 
                              ParameterName = 'Detail_Diff_Tint'
                             }
                            )
    ScalarParameterValues = ({
                              ExpressionGUID = {A = -1366541955, B = 1077737305, C = 2108764598, D = -247146442}, 
                              ParameterName = 'Spec_Pwr', 
                              ParameterValue = 20.0
                             }, 
                             {
                              ExpressionGUID = {A = -1500679513, B = 1120144091, C = 1142686141, D = -488421768}, 
                              ParameterName = 'Detail_Tile', 
                              ParameterValue = 2.0
                             }
                            )
    TextureParameterValues = ({
                               ParameterName = 'Detail_Msk', 
                               ParameterValue = Texture2D'BioT_LevelMaster.Brushed_Metal_Diff', 
                               ExpressionGUID = {A = 0, B = 0, C = 0, D = 0}
                              }, 
                              {
                               ParameterName = 'CubeMap', 
                               ParameterValue = TextureCube'BioG_LevelDetails.Textures.LD_Cube_02', 
                               ExpressionGUID = {A = 0, B = 0, C = 0, D = 0}
                              }, 
                              {
                               ParameterName = 'Emis_Glass_Detail', 
                               ParameterValue = None, 
                               ExpressionGUID = {A = 0, B = 0, C = 0, D = 0}
                              }, 
                              {
                               ParameterName = 'Emis_Sheet', 
                               ParameterValue = Texture2D'BioG_LevelDetails.Textures.LD_Hardsurfaces_Sheet01_Emis', 
                               ExpressionGUID = {A = 0, B = 0, C = 0, D = 0}
                              }
                             )
}