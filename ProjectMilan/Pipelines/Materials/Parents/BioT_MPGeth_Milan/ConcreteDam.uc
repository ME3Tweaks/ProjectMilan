// DONOR FOR: BioT_GthMP.Materials.Mat.MPG_ConcreteDam
// EXPRESSION MaterialExpressionScalarParameter_2
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = 762520319, B = 1318509511, C = 1596369814, D = 1219311335}
    ParameterName = 'Base_Mat_Tile_X'
}
// EXPRESSION MaterialExpressionTextureSampleParameterCube_1
properties
{
    ExpressionGUID = {A = 1491436459, B = 1132673789, C = -1769471303, D = -657883314}
    ParameterName = 'Reflection_Cubemap'
    Coordinates = {Expression = None}
    Texture = TextureCube'BIOG_APL_MASTER_MATERIAL.PLC_MM_Cubemap'
}
// EXPRESSION MaterialExpressionScalarParameter_56
properties
{
    DefaultValue = 100.0
    ExpressionGUID = {A = -1455018949, B = 1283695015, C = -225246032, D = -874243466}
    ParameterName = 'Specular Power'
}
// EXPRESSION MaterialExpressionScalarParameter_0
properties
{
    DefaultValue = 0.200000003
    ExpressionGUID = {A = 2144588205, B = 1195399220, C = -961311304, D = -1750191542}
    ParameterName = 'Gradient Intensity'
}
// EXPRESSION MaterialExpressionScalarParameter_29
properties
{
    DefaultValue = 1.20000005
    ExpressionGUID = {A = 2001292781, B = 1278619440, C = -1951916653, D = -1031040486}
    ParameterName = 'NormalMapIntensity'
}
// EXPRESSION MaterialExpressionScalarParameter_55
properties
{
    DefaultValue = 2.0999999
    ExpressionGUID = {A = -2014421176, B = 1109205405, C = 701853058, D = -2108434295}
    ParameterName = 'Specular Contrast'
}
// EXPRESSION MaterialExpressionVectorParameter_1
properties
{
    DefaultValue = {R = 0.365969479, G = 0.761910975, B = 1.0, A = 0.5}
    ExpressionGUID = {A = 1259443005, B = 1134240898, C = -900769895, D = -644544923}
    ParameterName = 'Reflection_Color'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_4
properties
{
    A = {Expression = None}
    B = {Expression = None}
    DefaultValue = TRUE
    ExpressionGUID = {A = -2096353866, B = 1276254096, C = 352176314, D = -1314211116}
    ParameterName = 'bUse Gradient'
}
// EXPRESSION MaterialExpressionScalarParameter_3
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = 87769433, B = 1330661153, C = 1253732528, D = -1980233800}
    ParameterName = 'Base_Mat_Tile_Y'
}
// PROPERTIES
properties
{
    Expressions = (MaterialExpressionScalarParameter'BioT_MPGeth_Milan.Materials.ConcreteDam.MaterialExpressionScalarParameter_2', 
                   MaterialExpressionTextureSampleParameterCube'BioT_MPGeth_Milan.Materials.ConcreteDam.MaterialExpressionTextureSampleParameterCube_1', 
                   MaterialExpressionScalarParameter'BioT_MPGeth_Milan.Materials.ConcreteDam.MaterialExpressionScalarParameter_56', 
                   MaterialExpressionScalarParameter'BioT_MPGeth_Milan.Materials.ConcreteDam.MaterialExpressionScalarParameter_0', 
                   MaterialExpressionScalarParameter'BioT_MPGeth_Milan.Materials.ConcreteDam.MaterialExpressionScalarParameter_29', 
                   MaterialExpressionScalarParameter'BioT_MPGeth_Milan.Materials.ConcreteDam.MaterialExpressionScalarParameter_55', 
                   MaterialExpressionVectorParameter'BioT_MPGeth_Milan.Materials.ConcreteDam.MaterialExpressionVectorParameter_1', 
                   MaterialExpressionStaticSwitchParameter'BioT_MPGeth_Milan.Materials.ConcreteDam.MaterialExpressionStaticSwitchParameter_4', 
                   MaterialExpressionScalarParameter'BioT_MPGeth_Milan.Materials.ConcreteDam.MaterialExpressionScalarParameter_3'
                  )
    Normal = {Expression = None}
    DiffuseColor = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPGeth_Milan.Materials.ConcreteDam.MaterialExpressionStaticSwitchParameter_4'}
    SpecularColor = {Expression = None}
    SpecularPower = {Expression = MaterialExpressionScalarParameter'BioT_MPGeth_Milan.Materials.ConcreteDam.MaterialExpressionScalarParameter_56'}
    PhysMaterial = PhysicalMaterial'BIOG_PHM_General_F.PHM_GEN_Stone_01'
    bUsedWithFoliage = TRUE
    bUsedWithStaticLighting = TRUE
    bForceFullPrecision = TRUE
    m_Guid = {A = -1973856319, B = 1180112675, C = 1460461715, D = 1255145866}
    LightingGuid = {A = 443539694, B = 1182267352, C = 1661686687, D = -769562408}
}
// BINARY
{
  "SM3MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 1,
    "ID": "19c37c59-9148-4ed6-96dd-a4c89bf6fd60",
    "NumUserTexCoords": 1,
    "UniformExpressionTextures": [
      "Texture2D'BioT_MPGeth_Milan.Textures.ConcreteDam_Norm'",
      "Texture2D'BioT_MPGeth_Milan.Textures.ConcreteDam_Gradient'",
      "Texture2D'BioT_MPGeth_Milan.Textures.ConcreteDam_Diff'"
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
    "ID": "06980fe4-b5e7-4114-a228-2e47591022c4",
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
