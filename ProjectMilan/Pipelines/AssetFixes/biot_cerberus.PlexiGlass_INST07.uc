properties
{
    VectorParameterValues = ({
                              ParameterValue = {R = 1.0, G = 1.0, B = 1.0, A = 1.0}, 
                              ExpressionGUID = {A = 1642270471, B = 1266695784, C = -1855940419, D = -543527407}, 
                              ParameterName = 'ReflectionColor'
                             }, 
                             {
                              ParameterValue = {R = 0.0342149846, G = 0.0488104746, B = 0.0494505502, A = 1.0}, 
                              ExpressionGUID = {A = 1689443186, B = 1095340717, C = 2052265905, D = -658580926}, 
                              ParameterName = 'Tint'
                             }
                            )
    ScalarParameterValues = ({
                              ExpressionGUID = {A = 526891017, B = 1109865140, C = -2142804330, D = -801435699}, 
                              ParameterName = 'Reflection Intensity', 
                              ParameterValue = 2.0
                             }, 
                             {
                              ExpressionGUID = {A = 273079472, B = 1129371107, C = -946254662, D = -1239176888}, 
                              ParameterName = 'Cubemap Distortion', 
                              ParameterValue = 0.100000001
                             }, 
                             {
                              ExpressionGUID = {A = -1709399418, B = 1268408759, C = 1249097100, D = -1544544318}, 
                              ParameterName = 'ScratchTile', 
                              // MILAN CHANGE - 11/16/2026 - Mgamerz
                              // Change from 3.0 to 1.0 to make glass less ugly. ME3 used 0.3 but 1.0 looks OK
                              ParameterValue = 1.0
                              // END MILAN CHANGE                             }
                            )
    TextureParameterValues = ({
                               ExpressionGUID = {A = 792883467, B = 1322613627, C = -1945957198, D = 276641014}, 
                               ParameterName = 'CubeMap', 
                               ParameterValue = TextureCube'BioG_MasterMats.Texture_Samples.Cubemap_05'
                              }
                             )
    ParentLightingGuid = {A = -958699441, B = 1230066730, C = 27653765, D = 1047238138}
    PhysMaterial = PhysicalMaterial'BIOG_PHM_General_F.PHM_GEN_Glass_01'
    Parent = Material'BioG_MasterMats.PlexiGlass_MM'
    m_Guid = {A = 1880917309, B = 1261054549, C = 714047143, D = 541510662}
    LightingGuid = {A = 1000527057, B = 1222628075, C = 567615127, D = -2014374996}
}