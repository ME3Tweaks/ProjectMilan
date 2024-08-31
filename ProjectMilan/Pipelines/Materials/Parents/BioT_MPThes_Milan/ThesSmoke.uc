// DONOR FOR: BioT_MPThes.Materials.Master_Smoke
// EXPRESSION MaterialExpressionVectorParameter_16
properties
{
    DefaultValue = {R = 0.867136002, G = 0.35374099, B = 0.113921002, A = 1.0}
    ExpressionGUID = {A = 304561543, B = 1208524174, C = 1600996756, D = 1070717563}
    ParameterName = 'Color_2'
}
// EXPRESSION MaterialExpressionVectorParameter_14
properties
{
    DefaultValue = {R = 0.30212599, G = 0.183549002, B = 0.0638149977, A = 1.0}
    ExpressionGUID = {A = -1977581757, B = 1336316905, C = 967755930, D = -1790498336}
    ParameterName = 'Color_1'
}
// EXPRESSION MaterialExpressionScalarParameter_0
properties
{
    DefaultValue = 2.0
    ExpressionGUID = {A = 363185617, B = 1239238930, C = -1346573160, D = 1305758128}
    ParameterName = 'Thickness'
}
// EXPRESSION MaterialExpressionScalarParameter_23
properties
{
    DefaultValue = 0.5
    ExpressionGUID = {A = 1597095617, B = 1179341490, C = -618533740, D = 86604645}
    ParameterName = 'Offset_Speed'
}
// EXPRESSION MaterialExpressionScalarParameter_1
properties
{
    DefaultValue = -100.0
    ExpressionGUID = {A = -1801566866, B = 1199246442, C = 1270947970, D = -380481043}
    ParameterName = 'Bias'
}
// EXPRESSION MaterialExpressionScalarParameter_21
properties
{
    ExpressionGUID = {A = 161406784, B = 1148096619, C = 1444858298, D = 1485121120}
    ParameterName = 'Offset_Time'
}
// EXPRESSION MaterialExpressionScalarParameter_5
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = 1412529157, B = 1235471227, C = -1386143332, D = -1245159457}
    ParameterName = 'Tile_U'
}
// EXPRESSION MaterialExpressionScalarParameter_7
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = -1058057835, B = 1202955671, C = 668330641, D = -504883212}
    ParameterName = 'Tile_V'
}
// PROPERTIES
properties
{
    Distortion = {Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    EmissiveColor = {Expression = None}
    Opacity = {Expression = None}
    TwoSided = TRUE
    bUsedWithStaticLighting = TRUE
    bUsedWithVectorLightMaps = TRUE
    BlendMode = EBlendMode.BLEND_Translucent
    LightingModel = EMaterialLightingModel.MLM_Unlit
    m_Guid = {A = 1220932758, B = 1267191474, C = -1338758513, D = -643650584}
    LightingGuid = {A = 1154158771, B = 1107088914, C = -76417138, D = 2102121720}
}
// BINARY
{
  "SM3MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 1,
    "ID": "9d1487de-a71c-479a-9b69-ddb1bbdfe18c",
    "NumUserTexCoords": 1,
    "UniformExpressionTextures": [
      "Texture2D'BioVFX_Z_TEXTURES.Fractals.Smoke_Fractal'",
      "Texture2D'BioVFX_Z_TEXTURES.Smoke_Tile'",
      "Texture2D'BioVFX_Z_TEXTURES.Gradients.Gradient_Clamped'",
      "Texture2D'BioVFX_Z_TEXTURES.env_smoke_trail'"
    ],
    "bUsesSceneColor": false,
    "bUsesSceneDepth": true,
    "bUsesDynamicParameter": true,
    "bUsesLightmapUVs": false,
    "bUsesMaterialVertexPositionOffset": false,
    "unkBool1": false,
    "UsingTransforms": 0,
    "TextureLookups": [
      {
        "TexCoordIndex": 0,
        "TextureIndex": 2,
        "UScale": 1,
        "VScale": 1,
        "Unk": 0
      }
    ],
    "DummyDroppedFallbackComponents": 0,
    "BlendModeOverrideValue": 0,
    "bIsBlendModeOverrided": false,
    "bIsMaskOverrideValue": false
  },
  "SM2MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 0,
    "ID": "a4f0b476-3648-4f58-8fb6-028344a46774",
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
    "DummyDroppedFallbackComponents": 0,
    "BlendModeOverrideValue": 0,
    "bIsBlendModeOverrided": false,
    "bIsMaskOverrideValue": false
  }
}
