// Needs checked against OT to see what the difference is from BioT_Tropical.Plant_PalmLeafA_MAT (used here)
// DONOR FOR: BioS_MPJungle.Materials.Plant_PalmLeafA_MAT
// EXPRESSION MaterialExpressionVectorParameter_7
properties
{
    DefaultValue = {R = 0.548063874, G = 0.741758227, B = 0.373515934, A = 1.0}
    ExpressionGUID = {A = 1149663827, B = 1288913769, C = -1866305603, D = 1036767469}
}
// EXPRESSION MaterialExpressionAntialiasedTextureMask_0
properties
{
    Channel = ETextureColorChannel.TCC_Red
    ExpressionGUID = {A = 503987908, B = 1169382186, C = 1547140238, D = 1829502142}
    ParameterName = 'MaterialExpressionAntialiasedTextureMask_0'
    Texture = Texture2D'BioT_Tropical.Plant_PalmLeafA_SPEC'
}
// PROPERTIES
properties
{
    Normal = {Expression = None, Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    DiffuseColor = {Expression = None, Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    SpecularColor = {Expression = None, Mask = 1, MaskG = 1}
    SpecularPower = {Expression = None}
    Opacity = {Mask = 1, MaskA = 1}
    TwoSidedLightingMask = {Expression = None}
    TwoSidedLightingColor = {Expression = MaterialExpressionVectorParameter'BioT_MPJngl_Milan.Materials.JnglPalmLeaf.MaterialExpressionVectorParameter_7', Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    PhysMaterial = PhysicalMaterial'BIOG_PHM_General_F.PHM_GEN_Leaves_01'
    TwoSided = TRUE
    bUsedWithStaticLighting = TRUE
    bUsedWithVectorLightMaps = TRUE
    LightmassSettings = {EmissiveBoost = 0.0, DiffuseBoost = 0.5}
    m_Guid = {A = -45398342, B = 1258507034, C = -1937602920, D = 710913147}
    LightingGuid = {A = 1721031234, B = 1204244702, C = 1882143151, D = -59585795}
}
// BINARY
{
  "SM3MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 1,
    "ID": "3eecbebd-1348-434a-a442-bc6989aa7505",
    "NumUserTexCoords": 1,
    "UniformExpressionTextures": [
      "Texture2D'BioT_Tropical.Plant_PalmLeafA_NORM'",
      "Texture2D'BioT_Tropical.Plant_PalmLeafA_DIFF'",
      "Texture2D'BioT_Tropical.Plant_PalmLeafA_SPEC'"
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
        "TextureIndex": 1,
        "UScale": 1,
        "VScale": 1,
        "Unk": 0
      },
      {
        "TexCoordIndex": 0,
        "TextureIndex": 0,
        "UScale": 1,
        "VScale": 1,
        "Unk": 0
      },
      {
        "TexCoordIndex": 0,
        "TextureIndex": 2,
        "UScale": 1,
        "VScale": 1,
        "Unk": 0
      },
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
    "ID": "e0447b36-a673-4f07-a6c6-e494e82b5cf6",
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
