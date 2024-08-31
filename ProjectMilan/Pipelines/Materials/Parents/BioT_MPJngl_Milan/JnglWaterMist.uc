// DONOR FOR: BioVFX_DLC_Env_MPJngl.Materials.Smoke_Misty
// EXPRESSION MaterialExpressionVectorParameter_65
properties
{
    DefaultValue = {R = 0.62310046, G = 0.682820976, B = 0.600000024, A = 1.5}
    ExpressionGUID = {A = 2122981587, B = 1133418570, C = -867104876, D = -2096281415}
    ParameterName = 'Color'
}
// EXPRESSION MaterialExpressionScalarParameter_2
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = 1766594369, B = 1088748126, C = 314811273, D = 1484049762}
    ParameterName = 'Tile'
}
// EXPRESSION MaterialExpressionScalarParameter_40
properties
{
    DefaultValue = 0.5
    ExpressionGUID = {A = 1290698043, B = 1333800651, C = 1811558539, D = -428280305}
    ParameterName = 'Distrotion'
}
// EXPRESSION MaterialExpressionScalarParameter_0
properties
{
    DefaultValue = -200.0
    ExpressionGUID = {A = 1073695385, B = 1213158608, C = -324035956, D = -924369095}
    ParameterName = 'DepthBiaded_Bias'
}
// EXPRESSION MaterialExpressionScalarParameter_1
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = -1218662016, B = 1117230037, C = 929317801, D = 691756754}
    ParameterName = 'PeterPan'
}
// PROPERTIES
properties
{
    EmissiveColor = {Expression = None}
    Opacity = {Expression = None}
    bUsedWithParticleSprites = TRUE
    bUsedWithParticleSubUV = TRUE
    BlendMode = EBlendMode.BLEND_Translucent
    LightingModel = EMaterialLightingModel.MLM_Unlit
    m_Guid = {A = 1200552102, B = 1219911338, C = 623313327, D = 1766184044}
    LightingGuid = {A = -1034177047, B = 1207553335, C = -383715166, D = -1878643854}
}
// BINARY
{
  "SM3MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 2,
    "ID": "26c4c5cb-6cbd-46aa-844c-1d0d5fba346e",
    "NumUserTexCoords": 1,
    "UniformExpressionTextures": [
      "Texture2D'BioVFX_Z_TEXTURES.Distortion.fx_Distort'",
      "Texture2D'BioVFX_Z_TEXTURES.Fractals.Smoke_Fractal'",
      "Texture2D'BioVFX_Z_TEXTURES.Generic.Smoke_Sprite'"
    ],
    "bUsesSceneColor": false,
    "bUsesSceneDepth": true,
    "bUsesDynamicParameter": true,
    "bUsesLightmapUVs": false,
    "bUsesMaterialVertexPositionOffset": false,
    "unkBool1": false,
    "UsingTransforms": 0,
    "TextureLookups": [],
    "DummyDroppedFallbackComponents": 0,
    "BlendModeOverrideValue": 0,
    "bIsBlendModeOverrided": false,
    "bIsMaskOverrideValue": false
  },
  "SM2MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 0,
    "ID": "a2f542b2-d1ef-40a8-8c47-371a2531f8f4",
    "NumUserTexCoords": 1,
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
