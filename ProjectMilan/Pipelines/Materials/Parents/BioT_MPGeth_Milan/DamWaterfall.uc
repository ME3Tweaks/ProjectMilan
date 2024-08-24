// New parent for MPGeth DamWaterfall with shaders that disable gradient mask
// Based on: BioT_Tropical.FX_lite.Waterfall_Base_Master_lite
// 08/05/2024 - Mgamerz

// DONOR FOR: BioT_NoDonor.NoDonor
// EXPRESSION MaterialExpressionScalarParameter_41
properties
{
    DefaultValue = 0.100000001
    ExpressionGUID = {A = -687539019, B = 1131397267, C = -1177386874, D = 785710524}
    ParameterName = 'Main_Tex_Pan_Speed'
}
// EXPRESSION MaterialExpressionScalarParameter_43
properties
{
    DefaultValue = 0.0500000007
    ExpressionGUID = {A = 1166165467, B = 1210705223, C = -1964472646, D = 517885957}
    ParameterName = 'Distortion'
}
// EXPRESSION MaterialExpressionVectorParameter_33
properties
{
    DefaultValue = {R = 1.60000002, G = 1.5, B = 1.29999995, A = 1.0}
    ExpressionGUID = {A = 371913400, B = 1077684872, C = -1192837471, D = -1063785200}
    ParameterName = 'Main_color'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_0
properties
{
    A = {Expression = MaterialExpressionVectorParameter'BioT_Tropical.FX_lite.Waterfall_Base_Master_lite.MaterialExpressionVectorParameter_33', Mask = 1, MaskA = 1}
    B = {Expression = None, Mask = 1, MaskR = 1}
    ExpressionGUID = {A = 1804747652, B = 1179899437, C = -1940500860, D = -1119797517}
    ParameterName = 'Falloff'
}
// EXPRESSION MaterialExpressionScalarParameter_38
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = -1383724048, B = 1152366942, C = 739975597, D = 1300984112}
    ParameterName = 'Main_Tex_Tile_V'
}
// EXPRESSION MaterialExpressionScalarParameter_39
properties
{
    DefaultValue = 4.0
    ExpressionGUID = {A = 349620842, B = 1141699784, C = -2140230007, D = -1734990261}
    ParameterName = 'Main_Tex_Tile_U'
}
// PROPERTIES
properties
{
    Expressions = (MaterialExpressionScalarParameter'BioT_Tropical.FX_lite.Waterfall_Base_Master_lite.MaterialExpressionScalarParameter_41', MaterialExpressionScalarParameter'BioT_Tropical.FX_lite.Waterfall_Base_Master_lite.MaterialExpressionScalarParameter_43', MaterialExpressionStaticSwitchParameter'BioT_Tropical.FX_lite.Waterfall_Base_Master_lite.MaterialExpressionStaticSwitchParameter_0', MaterialExpressionVectorParameter'BioT_Tropical.FX_lite.Waterfall_Base_Master_lite.MaterialExpressionVectorParameter_33', MaterialExpressionScalarParameter'BioT_Tropical.FX_lite.Waterfall_Base_Master_lite.MaterialExpressionScalarParameter_38', MaterialExpressionScalarParameter'BioT_Tropical.FX_lite.Waterfall_Base_Master_lite.MaterialExpressionScalarParameter_39')
    EmissiveColor = {Expression = None}
    Opacity = {Expression = None}
    bUsedWithStaticLighting = TRUE
    bUsedWithVectorLightMaps = TRUE
    BlendMode = EBlendMode.BLEND_Additive
    m_Guid = {A = -1564706526, B = 1180122139, C = -1404184389, D = 1761205867}
    LightingGuid = {A = -235755426, B = 1280564587, C = -1089311103, D = -944190951}
}
// BINARY
{
  "SM3MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 2,
    "ID": "623d33ac-bad3-44e5-97d4-09d6129aa24a",
    "NumUserTexCoords": 1,
    "UniformExpressionTextures": [
      "Texture2D'BioVFX_Env_Waterfalls.Textures.Waterfall_Thick'",
      "Texture2D'BioVFX_Z_TEXTURES.Gradients.Gradient_001'"
    ],
    "bUsesSceneColor": false,
    "bUsesSceneDepth": true,
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
    "ID": "2047199b-52f9-46e6-bbec-126669caabfa",
    "NumUserTexCoords": 6553695,
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
