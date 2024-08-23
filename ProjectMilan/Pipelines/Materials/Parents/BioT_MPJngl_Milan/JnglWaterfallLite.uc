// DONOR FOR: BioS_MPJungle_Trash.Waterfall_Base_Master_lite_INST01
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
    A = {Expression = MaterialExpressionVectorParameter'BioT_MPJngl_Milan.Materials.JnglWaterfallLite.MaterialExpressionVectorParameter_33', Mask = 1, MaskA = 1}
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
    EmissiveColor = {Expression = None}
    Opacity = {Expression = None}
    bUsedWithStaticLighting = TRUE
    bUsedWithVectorLightMaps = TRUE
    BlendMode = EBlendMode.BLEND_Translucent
    m_Guid = {A = 972273109, B = 1209743907, C = -549410636, D = -1408786763}
    LightingGuid = {A = -1713930193, B = 1229792094, C = 935978641, D = 1045812614}
}
// BINARY
{
  "SM3MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 2,
    "ID": "ab03fc08-83ae-4184-831d-d6cab9717aef",
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
    "ID": "cabfb5c9-011b-4396-9716-f4866e306d1f",
    "NumUserTexCoords": 0,
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
