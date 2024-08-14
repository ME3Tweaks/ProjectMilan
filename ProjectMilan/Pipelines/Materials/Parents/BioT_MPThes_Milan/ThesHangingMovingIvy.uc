// Needs shader update for moving effect. Probably in Vertex Shader.
// DONOR FOR: BioT_MPThes.Ivy_MAT_moving_REPL
// EXPRESSION MaterialExpressionAntialiasedTextureMask_0
properties
{
    Channel = ETextureColorChannel.TCC_Red
    ExpressionGUID = {A = 503987908, B = 1169382186, C = 1547140238, D = 1829502142}
    ParameterName = 'MaterialExpressionAntialiasedTextureMask_0'
    Texture = Texture2D'BioApl_Lvl_Foliage.Textures.Ivy_SPEC'
}
// PROPERTIES
properties
{
    Normal = {Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    WorldPositionOffset = {Expression = None}
    DiffuseColor = {Expression = None}
    SpecularColor = {Expression = None, Mask = 1, MaskR = 1}
    SpecularPower = {Expression = None}
    EmissiveColor = {Expression = None}
    Opacity = {Mask = 1, MaskA = 1}
    OpacityMask = {Expression = MaterialExpressionAntialiasedTextureMask'BioT_MPThes_Milan.Materials.ThesHangingMovingIvy.MaterialExpressionAntialiasedTextureMask_0'}
    PhysMaterial = PhysicalMaterial'BIOG_PHM_General_F.PHM_GEN_Leaves_01'
    TwoSided = TRUE
    bUsedWithStaticLighting = TRUE
    bIsMasked = TRUE
    BlendMode = EBlendMode.BLEND_Masked
    LightmassSettings = {EmissiveBoost = 0.0, DiffuseBoost = 0.5}
    m_Guid = {A = -1773934513, B = 1337577660, C = 215419017, D = -769536516}
    LightingGuid = {A = 1678229695, B = 1280965512, C = 1292853171, D = -1010097671}
}
// BINARY
{
  "SM3MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 1,
    "ID": "842a31dc-8aa3-406c-a9d4-39d20238b020",
    "NumUserTexCoords": 1,
    "UniformExpressionTextures": [
      "Texture2D'BioApl_Lvl_Foliage.Textures.Ivy_Diff'",
      "Texture2D'BioApl_Lvl_Foliage.Textures.Ivy_SPEC'"
    ],
    "bUsesSceneColor": false,
    "bUsesSceneDepth": false,
    "bUsesDynamicParameter": true,
    "bUsesLightmapUVs": false,
    "bUsesMaterialVertexPositionOffset": false,
    "unkBool1": true,
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
      }
    ],
    "unkUint1": 0,
    "udkUnk2": 0,
    "udkUnk3": 0,
    "udkUnk4": 0
  },
  "SM2MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 0,
    "ID": "2fdad1f2-6d33-48a4-9c77-b6019870f30d",
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
    "unkUint1": 0,
    "udkUnk2": 0,
    "udkUnk3": 0,
    "udkUnk4": 0
  }
}
