// DONOR FOR: BioT_MPMoon.CliffBlend
// EXPRESSION MaterialExpressionVectorParameter_21
properties
{
    DefaultValue = {R = 1.0, G = 1.0, B = 1.0, A = 1.0}
    ExpressionGUID = {A = 405707372, B = 1260580778, C = -620270963, D = -519031070}
    ParameterName = 'SpecMult'
}
// EXPRESSION MaterialExpressionScalarParameter_44
properties
{
    DefaultValue = 5.0
    ExpressionGUID = {A = -1685189162, B = 1122681854, C = 2883747, D = -1278449649}
    ParameterName = 'SpecPower'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_0
properties
{
    A = {Expression = None}
    B = {Expression = None, Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    DefaultValue = TRUE
    ExpressionGUID = {A = -876675574, B = 1175843897, C = 1785501617, D = 1503270494}
    ParameterName = 'TextureBlend'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_2
properties
{
    A = {Expression = None}
    B = {Expression = None, Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    DefaultValue = TRUE
    ExpressionGUID = {A = -838034789, B = 1274870857, C = -681976656, D = 205316017}
    ParameterName = 'TextureBlend'
}
// PROPERTIES
properties
{
    Normal = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPMoon_Milan.Materials.CliffBlend.MaterialExpressionStaticSwitchParameter_2'}
    DiffuseColor = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPMoon_Milan.Materials.CliffBlend.MaterialExpressionStaticSwitchParameter_0'}
    SpecularColor = {Expression = None}
    SpecularPower = {Expression = MaterialExpressionScalarParameter'BioT_MPMoon_Milan.Materials.CliffBlend.MaterialExpressionScalarParameter_44'}
    OpacityMask = {Expression = None}
    PhysMaterial = PhysicalMaterial'BIOG_PHM_General_F.PHM_GEN_Stone_01'
    bUsedWithStaticLighting = TRUE
    bUsedWithVectorLightMaps = TRUE
    bIsMasked = TRUE
    BlendMode = EBlendMode.BLEND_Masked
    m_Guid = {A = -1060519874, B = 1313241990, C = -76785019, D = 1213926022}
    LightingGuid = {A = 1190913386, B = 1101423566, C = 1549638834, D = 1338527468}
}
// BINARY
{
  "SM3MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 1,
    "ID": "62145bc0-36c9-4d36-9ad1-baeec7f7e3b3",
    "NumUserTexCoords": 1,
    "UniformExpressionTextures": [
      "Texture2D'BioT_RedRock_Ter.Textures.NORM.CliffBlend_NORM'",
      "Texture2D'BioT_RedRock_Ter.Textures.NORM.CliffTiled_NORM'",
      "Texture2D'BioT_RedRock_Ter.Textures.Diff.CliffBlend_DIFF'",
      "Texture2D'BioT_RedRock_Ter.Textures.Diff.CliffTiled_DIFF'"
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
        "UScale": 3,
        "VScale": 3,
        "Unk": 0
      },
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
        "TextureIndex": 3,
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
    "ID": "46ffc587-f7da-455c-9700-6eb93bf7e359",
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
