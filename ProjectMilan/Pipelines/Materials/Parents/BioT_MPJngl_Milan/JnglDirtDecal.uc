// DONOR FOR: BioS_MPJungle.Materials.DirtDecal_Unlit_MM
// EXPRESSION MaterialExpressionTextureSampleParameter2D_2
properties
{
    ExpressionGUID = {A = -521014697, B = 1165244729, C = 1494592938, D = -272683449}
    ParameterName = 'Diffuse Texture'
    Texture = Texture2D'BioT_Thessia_Monastery.Decal_Concrete_01_Diff' // This might need changed to MP texture as it might be slightly colorized?
}
// EXPRESSION MaterialExpressionScalarParameter_5
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = -442371621, B = 1294625325, C = 738094515, D = -540291227}
    ParameterName = 'Opacity'
}
// EXPRESSION MaterialExpressionScalarParameter_3
properties
{
    DefaultValue = 0.5
    ExpressionGUID = {A = -352693581, B = 1275249341, C = 1664920733, D = -1719051510}
    ParameterName = 'Mask Sharpness'
}
// EXPRESSION MaterialExpressionVectorParameter_1
properties
{
    ExpressionGUID = {A = -501744982, B = 1195252076, C = -203842920, D = -637302531}
    ParameterName = 'Diffuse Tint'
}
// PROPERTIES
properties
{
    EmissiveColor = {Expression = None}
    Opacity = {Expression = None}
    OpacityMask = {Mask = 1, MaskA = 1}
    bUsedWithStaticLighting = TRUE
    bUsedWithDecals = TRUE
    BlendMode = EBlendMode.BLEND_Translucent
    LightingModel = EMaterialLightingModel.MLM_Unlit
    m_Guid = {A = 1677820071, B = 1174804159, C = 1065700246, D = 935334718}
    LightingGuid = {A = 923178478, B = 1076668585, C = 405342905, D = 1378159254}
}
// BINARY
{
  "SM3MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 1,
    "ID": "6a50788b-851b-4de6-bb4f-ed0555c76327",
    "NumUserTexCoords": 2,
    "UniformExpressionTextures": [
      "Texture2D'BioT_Thessia_Monastery.Decal_Concrete_01_Diff'"
    ],
    "bUsesSceneColor": false,
    "bUsesSceneDepth": false,
    "bUsesDynamicParameter": false,
    "bUsesLightmapUVs": false,
    "bUsesMaterialVertexPositionOffset": false,
    "unkBool1": false,
    "UsingTransforms": 0,
    "TextureLookups": [
      {
        "TexCoordIndex": 0,
        "TextureIndex": 0,
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
    "ID": "0b536a73-d3f6-4650-89f6-2b1a9b7cf43e",
    "NumUserTexCoords": 4325443,
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
