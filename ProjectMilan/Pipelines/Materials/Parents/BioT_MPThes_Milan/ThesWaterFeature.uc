// DONOR FOR: BioT_MPThes.Water_Cheap_Monastery_MAT2
// EXPRESSION MaterialExpressionStaticSwitchParameter_1
properties
{
    A = {Expression = None}
    B = {Expression = None}
    DefaultValue = TRUE
    ExpressionGUID = {A = 1401513223, B = 1296452600, C = -1687230019, D = -1366361266}
    ParameterName = 'MEGA_Only'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_5
properties
{
    A = {Expression = None}
    B = {Expression = None}
    DefaultValue = TRUE
    ExpressionGUID = {A = 1528668192, B = 1164738390, C = 894223513, D = 89328441}
    ParameterName = 'MEGA_Only'
}
// EXPRESSION MaterialExpressionTextureSampleParameterCube_3
properties
{
    ExpressionGUID = {A = -1241024490, B = 1097166223, C = -1690389878, D = 407761265}
    ParameterName = 'CubeMap'
    Coordinates = {Expression = None}
    Texture = TextureCube'BioG_MasterMats.Texture_Samples.Cubemap_06'
}
// EXPRESSION MaterialExpressionVectorParameter_3
properties
{
    DefaultValue = {R = 1.0, G = 0.78586638, B = 0.559270918, A = 8.0}
    ExpressionGUID = {A = -1923068098, B = 1203663771, C = -61748345, D = -577536975}
    ParameterName = 'Sun'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_4
properties
{
    A = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPThes_Milan.Materials.ThesWaterFeature.MaterialExpressionStaticSwitchParameter_1'}
    B = {Expression = None}
    ExpressionGUID = {A = 48788203, B = 1205664756, C = 1812930737, D = -910334049}
    ParameterName = 'MEGASWITCH'
}
// EXPRESSION MaterialExpressionVectorParameter_4
properties
{
    DefaultValue = {R = 0.0680833235, G = 0.0744166598, B = 0.0759999976, A = 0.200000018}
    ExpressionGUID = {A = 274021884, B = 1211366234, C = 1365282451, D = -896040353}
    ParameterName = 'Tint'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_3
properties
{
    A = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPThes_Milan.Materials.ThesWaterFeature.MaterialExpressionStaticSwitchParameter_5'}
    B = {Expression = None}
    ExpressionGUID = {A = 1341567556, B = 1083811838, C = -448986447, D = -2093382021}
    ParameterName = 'MEGASWITCH'
}
// EXPRESSION MaterialExpressionScalarParameter_0
properties
{
    DefaultValue = 3.0
    ExpressionGUID = {A = 1853984020, B = 1193083550, C = -1845145693, D = 2081157285}
    ParameterName = 'CubeBright'
}
// PROPERTIES
properties
{
    Normal = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPThes_Milan.Materials.ThesWaterFeature.MaterialExpressionStaticSwitchParameter_3'}
    Distortion = {Expression = None}
    DiffuseColor = {Expression = None}
    SpecularColor = {Expression = None}
    SpecularPower = {Expression = None}
    EmissiveColor = {Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    Opacity = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPThes_Milan.Materials.ThesWaterFeature.MaterialExpressionStaticSwitchParameter_4'}
    PhysMaterial = PhysicalMaterial'BIOG_PHM_General_F.PHM_GEN_Water_01'
    bUsedWithStaticLighting = TRUE
    bUsedWithVectorLightMaps = TRUE
    bUsesDistortion = TRUE
    BlendMode = EBlendMode.BLEND_Translucent
    m_Guid = {A = 279651702, B = 1209393212, C = -1083543903, D = 944718951}
    LightingGuid = {A = -922048788, B = 1124420873, C = -1472217436, D = -1981387335}
}
// BINARY
{
  "SM3MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 1,
    "ID": "7d4660a5-0bd3-4935-98f1-381f1e4daccc",
    "NumUserTexCoords": 1,
    "UniformExpressionTextures": [
      "Texture2D'BioT_Thessia.Water_Norm'",
      "Texture2D'BioT_Thessia.Water_Diff'",
      "TextureCube'BioG_MasterMats.Texture_Samples.Cubemap_06'"
    ],
    "bUsesSceneColor": false,
    "bUsesSceneDepth": false,
    "bUsesDynamicParameter": true,
    "bUsesLightmapUVs": false,
    "bUsesMaterialVertexPositionOffset": false,
    "unkBool1": false,
    "UsingTransforms": 0,
    "TextureLookups": [],
    "unkUint1": 0,
    "udkUnk2": 0,
    "udkUnk3": 0,
    "udkUnk4": 0
  },
  "SM2MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 0,
    "ID": "34d601a3-f9b8-492a-910d-7448d3196597",
    "NumUserTexCoords": 765086416,
    "UniformExpressionTextures": [],
    "bUsesSceneColor": false,
    "bUsesSceneDepth": false,
    "bUsesDynamicParameter": false,
    "bUsesLightmapUVs": false,
    "bUsesMaterialVertexPositionOffset": false,
    "unkBool1": false,
    "UsingTransforms": 0,
    "TextureLookups": [],
    "unkUint1": 0,
    "udkUnk2": 0,
    "udkUnk3": 0,
    "udkUnk4": 0
  }
}
