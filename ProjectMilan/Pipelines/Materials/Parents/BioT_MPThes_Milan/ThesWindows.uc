// TODO: Needs Mask in shader
// DONOR FOR: BioT_MPThes.Materials.FrameWindow_Mat
// EXPRESSION MaterialExpressionVectorParameter_2
properties
{
    DefaultValue = {R = 0.426924288, G = 0.629612148, B = 0.631868124, A = 1.0}
    ExpressionGUID = {A = 755618383, B = 1243625157, C = 309101224, D = -747615229}
    ParameterName = 'lightson'
}
// EXPRESSION MaterialExpressionVectorParameter_10
properties
{
    DefaultValue = {R = 0.464848101, G = 0.150467977, B = 0.0678570047, A = 1.0}
    ExpressionGUID = {A = 845833352, B = 1133567034, C = 23301765, D = 1339602337}
    ParameterName = 'ReflectionColor'
}
// EXPRESSION MaterialExpressionTextureSampleParameterCube_1
properties
{
    ExpressionGUID = {A = -1126080677, B = 1206372565, C = -1736716634, D = -1059048227}
    ParameterName = 'Cube'
    Coordinates = {Expression = None}
    Texture = TextureCube'BioG_MasterMats.Texture_Samples.Cubemap_02'
}
// PROPERTIES
properties
{
    Expressions = (MaterialExpressionVectorParameter'BioT_Thessia.FrameWindow_Mat.MaterialExpressionVectorParameter_2', MaterialExpressionVectorParameter'BioT_Thessia.FrameWindow_Mat.MaterialExpressionVectorParameter_10', MaterialExpressionTextureSampleParameterCube'BioT_Thessia.FrameWindow_Mat.MaterialExpressionTextureSampleParameterCube_1')
    Normal = {Expression = None}
    DiffuseColor = {Expression = None, Mask = 1, MaskR = 1}
    SpecularColor = {Expression = None}
    SpecularPower = {Expression = None}
    EmissiveColor = {Expression = None}
    PhysMaterial = PhysicalMaterial'BIOG_PHM_General_F.PHM_GEN_Glass_01'
    bUsedWithStaticLighting = TRUE
    bUsedWithVectorLightMaps = TRUE
    m_Guid = {A = -975447217, B = 1239847465, C = -288424300, D = 542154378}
    LightingGuid = {A = 924143283, B = 1196495054, C = 306778267, D = -259356681}
}
// BINARY
{
  "SM3MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 1,
    "ID": "034e2b2c-bdc9-4b2b-99c8-ae655b83974f",
    "NumUserTexCoords": 1,
    "UniformExpressionTextures": [
      "Texture2D'BioT_Thessia.Building_Face01_Norm'",
      "Texture2D'BioT_Thessia.Building_Face01'",
      "Texture2D'BioT_Thessia.Env_Materials.BlackGlass_Norm3'",
      "TextureCube'BioG_MasterMats.Texture_Samples.Cubemap_02'"
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
        "TextureIndex": 2,
        "UScale": 0.25,
        "VScale": 0.25,
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
    "ID": "98ece223-d43c-4429-ae11-c6ecab35787c",
    "NumUserTexCoords": 7667758,
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
