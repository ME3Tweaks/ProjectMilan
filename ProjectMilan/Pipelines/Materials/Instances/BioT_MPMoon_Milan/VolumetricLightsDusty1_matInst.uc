// DONOR FOR: BioT_MPMoon.Effects.Volumetric_DustBeamDefault_INST, BioT_MPThes.fX.Volumetric_DustBeamDefault_INST
properties
{
    VectorParameterValues = ({
                              ParameterValue = {R = 0.156751111, G = 0.156345516, B = 0.127828047, A = 1.0}, 
                              ExpressionGUID = {A = 1498021191, B = 1292946442, C = -1391696723, D = 600291158}, 
                              ParameterName = 'Color'
                             }, 
                             {
                              ParameterValue = {R = 1.0, G = 0.0, B = 0.0, A = 1.0}, 
                              ExpressionGUID = {A = -523975658, B = 1138198924, C = -1029565038, D = 418415290}, 
                              ParameterName = 'Texture Multiply Mixer (R G B)'
                             }, 
                             {
                              ParameterValue = {R = 1.0, G = 0.0, B = 0.0, A = 1.0}, 
                              ExpressionGUID = {A = -472770525, B = 1215781676, C = 923123341, D = -2027957418}, 
                              ParameterName = 'FalloffMask_Mixer (R G B)'
                             }
                            )
    ScalarParameterValues = ({
                              ExpressionGUID = {A = -1913087254, B = 1163313132, C = -1021327948, D = -365093825}, 
                              ParameterName = 'FadeNear', 
                              ParameterValue = 5.0
                             }, 
                             {
                              ExpressionGUID = {A = 729298166, B = 1274397539, C = 234052998, D = 839684316}, 
                              ParameterName = 'TextureScaleX', 
                              ParameterValue = 5.0
                             }, 
                             {
                              ExpressionGUID = {A = -1361418949, B = 1122254858, C = -559939196, D = 757584855}, 
                              ParameterName = 'TextureScaleY', 
                              ParameterValue = 3.0
                             }, 
                             {
                              ExpressionGUID = {A = 1896759581, B = 1104523303, C = 201274546, D = 745628730}, 
                              ParameterName = 'TextureContrast', 
                              ParameterValue = 0.600000024
                             }, 
                             {
                              ExpressionGUID = {A = -1802390974, B = 1150854860, C = 1813585833, D = 1965223370}, 
                              ParameterName = 'PanningSpeed', 
                              ParameterValue = 0.5
                             }, 
                             {
                              ExpressionGUID = {A = -1315764639, B = 1075613378, C = -696398682, D = 2120409756}, 
                              ParameterName = 'Bias', 
                              ParameterValue = -300.0
                             }
                            )
    TextureParameterValues = ({
                               ExpressionGUID = {A = 718908847, B = 1143181041, C = 621320835, D = 1635372705}, 
                               ParameterName = 'Falloff Mask', 
                               ParameterValue = Texture2D'BioG_Volumetric.Textures.Lightbeam_Mask01'
                              }
                             )
    ParentLightingGuid = {A = 2110565532, B = 1340790743, C = -412857980, D = 610782}
    Parent = MaterialInstanceConstant'BioG_Volumetric.Instances.Volumetric_DustBeamDefault_INST'
    m_Guid = {A = -1432444913, B = 1333956831, C = -250730578, D = 453810686}
    LightingGuid = {A = -1121019372, B = 1155167229, C = 1116826041, D = 1975342115}
}