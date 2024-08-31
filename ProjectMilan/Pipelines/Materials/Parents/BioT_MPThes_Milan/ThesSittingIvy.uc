// DONOR FOR: BioT_MPThes.IvyB_Mat_REPL
// EXPRESSION MaterialExpressionAntialiasedTextureMask_0
properties
{
    Channel = ETextureColorChannel.TCC_Red
    ExpressionGUID = {A = 503987908, B = 1169382186, C = 1547140238, D = 1829502142}
    ParameterName = 'MaterialExpressionAntialiasedTextureMask_0'
    Texture = Texture2D'BioApl_Lvl_Foliage.Textures.IvyB_SPEC'
}
// PROPERTIES
properties
{
    Normal = {Expression = None, Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    DiffuseColor = {Expression = None, Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    SpecularColor = {Expression = None, Mask = 1, MaskG = 1}
    SpecularPower = {Expression = None}
    EmissiveColor = {Expression = None}
    Opacity = {Mask = 1, MaskA = 1}
    OpacityMask = {Expression = MaterialExpressionAntialiasedTextureMask'BioT_MPThes_Milan.Materials.ThesSittingIvy.MaterialExpressionAntialiasedTextureMask_0'}
    PhysMaterial = PhysicalMaterial'BIOG_PHM_General_F.PHM_GEN_Leaves_01'
    TwoSided = TRUE
    bUsedWithStaticLighting = TRUE
    bUsedWithVectorLightMaps = TRUE
    bIsMasked = TRUE
    BlendMode = EBlendMode.BLEND_Masked
    LightmassSettings = {EmissiveBoost = 0.0, DiffuseBoost = 0.5}
    m_Guid = {A = -1200950166, B = 1279560157, C = -601588293, D = 760994619}
    LightingGuid = {A = -1972592014, B = 1190244791, C = -2127837045, D = -301578973}
}
// BINARY
{
  "SM3MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 1,
    "ID": "5e55e767-098a-4b4c-a4f0-8403c4616146",
    "NumUserTexCoords": 1,
    "UniformExpressionTextures": [
      "Texture2D'BioApl_Lvl_Foliage.Textures.IvyB_NORM'",
      "Texture2D'BioApl_Lvl_Foliage.Textures.IvyB_DIFF'",
      "Texture2D'BioApl_Lvl_Foliage.Textures.IvyB_SPEC'"
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
        "TextureIndex": 3,
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
    "ID": "90f9693b-89c4-4f7a-b73c-79694e8eb0cb",
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
