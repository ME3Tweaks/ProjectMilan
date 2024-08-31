// Changes the shader id to restore material shader for material that was not present in game files but was in source files of LE3.
// DONOR FOR: BioT_NoDonor.NoDonor3
// FLAGS: NoMaterialsPackage
// EXPRESSION MaterialExpressionAntialiasedTextureMask_0
properties
{
    Channel = ETextureColorChannel.TCC_Red
    ExpressionGUID = {A = 503987908, B = 1169382186, C = 1547140238, D = 1829502142}
    ParameterName = 'MaterialExpressionAntialiasedTextureMask_0'
    Texture = Texture2D'BioT_Tropical.Ivy_SPEC'
}
// PROPERTIES
properties
{
    Expressions = (MaterialExpressionAntialiasedTextureMask'BioT_Tropical.Ivy_MAT_moving.MaterialExpressionAntialiasedTextureMask_0')
    Normal = {Expression = None, Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    DiffuseColor = {Expression = None, Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    SpecularColor = {Expression = None}
    EmissiveColor = {Expression = None}
    Opacity = {Mask = 1, MaskA = 1}
    OpacityMask = {Expression = MaterialExpressionAntialiasedTextureMask'BioT_Tropical.Ivy_MAT_moving.MaterialExpressionAntialiasedTextureMask_0'}
    PhysMaterial = PhysicalMaterial'BIOG_PHM_General_F.PHM_GEN_Leaves_01'
    bUsedWithStaticLighting = TRUE
    bUsedWithVectorLightMaps = TRUE
    bIsMasked = TRUE
    BlendMode = EBlendMode.BLEND_Masked
    LightmassSettings = {EmissiveBoost = 0.0, DiffuseBoost = 0.5}
    m_Guid = {A = -245549576, B = 1275933917, C = 749819529, D = 1203187402}
    LightingGuid = {A = -1707123403, B = 1209981666, C = 635440522, D = 1791670394}
}
// BINARY
{
  "SM3MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 1,
    "ID": "4741ab2f-6049-431b-a26b-e8e5469ccb3b",
    "NumUserTexCoords": 1,
    "UniformExpressionTextures": [
      "Texture2D'BioT_Tropical.Ivy_NORM'",
      "Texture2D'BioT_Tropical.Ivy_Diff'",
      "Texture2D'BioT_Tropical.Ivy_SPEC'"
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
        "TextureIndex": 2,
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
    "ID": "3bae7673-5bd2-4a0f-b45c-5c6070306f4c",
    "NumUserTexCoords": 587,
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
