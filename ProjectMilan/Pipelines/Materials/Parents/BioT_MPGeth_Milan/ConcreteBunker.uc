// DONOR FOR: BioT_GthMP.Materials.Mat.MPG_ConcreteBaseBunker_Milan
// EXPRESSION MaterialExpressionScalarParameter_11
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = 397796833, B = 1245033275, C = -1735542904, D = -422497726}
    ParameterName = 'Diff_A_Mat_Tile_Y'
}
// EXPRESSION MaterialExpressionTextureSampleParameter2D_0
properties
{
    ExpressionGUID = {A = 1610650128, B = 1139854670, C = 2127652259, D = 323105261}
    ParameterName = 'Diff B'
    Coordinates = {Expression = None}
    Texture = Texture2D'BioT_MPGeth_Milan.Textures.ConcreteDamStained_Diff'
}
// EXPRESSION MaterialExpressionScalarParameter_10
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = 90615681, B = 1284950715, C = -622622794, D = -1203859798}
    ParameterName = 'Diff_A_Mat_Tile_X'
}
// EXPRESSION MaterialExpressionScalarParameter_7
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = 1593585839, B = 1121968984, C = 1349554874, D = -959083367}
    ParameterName = 'Diff_B_Mat_Tile_Y'
}
// EXPRESSION MaterialExpressionScalarParameter_6
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = -895466773, B = 1284579429, C = -1221575039, D = -1501932473}
    ParameterName = 'Diff_B_Mat_Tile_X'
}
// EXPRESSION MaterialExpressionScalarParameter_17
properties
{
    DefaultValue = 1.5
    ExpressionGUID = {A = 748227753, B = 1076296894, C = 2138173075, D = -1392050750}
    ParameterName = 'Specular Contrast'
}
// EXPRESSION MaterialExpressionTextureSampleParameter2D_1
properties
{
    ExpressionGUID = {A = -233414533, B = 1161614534, C = -1283985534, D = -1669967959}
    ParameterName = 'Diff A'
    Coordinates = {Expression = None}
    Texture = Texture2D'BioT_MPGeth_Milan.Textures.ConcreteGround_Diff'
}
// EXPRESSION MaterialExpressionScalarParameter_14
properties
{
    DefaultValue = 0.5
    ExpressionGUID = {A = -259281073, B = 1306782261, C = -1512598633, D = -368861406}
    ParameterName = 'Mask B UV Tile'
}
// EXPRESSION MaterialExpressionScalarParameter_16
properties
{
    DefaultValue = 1.29999995
    ExpressionGUID = {A = 1250343297, B = 1314911914, C = -200332893, D = -103992186}
    ParameterName = 'NormalMapIntensity'
}
// EXPRESSION MaterialExpressionScalarParameter_12
properties
{
    DefaultValue = 0.5
    ExpressionGUID = {A = -819798755, B = 1292109219, C = 1835366818, D = -78801756}
    ParameterName = 'Mask A UV Tile'
}
// PROPERTIES
properties
{
    Expressions = (MaterialExpressionScalarParameter'BioT_MPGeth_Milan.Materials.ConcreteBunker.MaterialExpressionScalarParameter_11', 
                   MaterialExpressionTextureSampleParameter2D'BioT_MPGeth_Milan.Materials.ConcreteBunker.MaterialExpressionTextureSampleParameter2D_0', 
                   MaterialExpressionScalarParameter'BioT_MPGeth_Milan.Materials.ConcreteBunker.MaterialExpressionScalarParameter_10', 
                   MaterialExpressionScalarParameter'BioT_MPGeth_Milan.Materials.ConcreteBunker.MaterialExpressionScalarParameter_7', 
                   MaterialExpressionScalarParameter'BioT_MPGeth_Milan.Materials.ConcreteBunker.MaterialExpressionScalarParameter_6', 
                   MaterialExpressionScalarParameter'BioT_MPGeth_Milan.Materials.ConcreteBunker.MaterialExpressionScalarParameter_17', 
                   MaterialExpressionTextureSampleParameter2D'BioT_MPGeth_Milan.Materials.ConcreteBunker.MaterialExpressionTextureSampleParameter2D_1', 
                   MaterialExpressionScalarParameter'BioT_MPGeth_Milan.Materials.ConcreteBunker.MaterialExpressionScalarParameter_14', 
                   MaterialExpressionScalarParameter'BioT_MPGeth_Milan.Materials.ConcreteBunker.MaterialExpressionScalarParameter_16', 
                   MaterialExpressionScalarParameter'BioT_MPGeth_Milan.Materials.ConcreteBunker.MaterialExpressionScalarParameter_12'
                  )
    Normal = {Expression = None}
    DiffuseColor = {Expression = None}
    SpecularColor = {Expression = None}
    PhysMaterial = PhysicalMaterial'BIOG_PHM_General_F.PHM_GEN_Stone_01'
    bUsedWithStaticLighting = TRUE
    bUsedWithVectorLightMaps = TRUE
    m_Guid = {A = -1148870358, B = 1224478686, C = -520355425, D = 221484696}
    LightingGuid = {A = -1170703023, B = 1255769351, C = 330486936, D = -1828042184}
}
// BINARY
{
  "SM3MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 1,
    "ID": "1bb8e2f8-dda9-446f-9ff0-653b77d8a67f",
    "NumUserTexCoords": 1,
    "UniformExpressionTextures": [
      "Texture2D'BioT_MPGeth_Milan.Textures.ConcreteGround_Norm'",
      "Texture2D'BioG_Skies.Cloud_msk01'",
      "Texture2D'BioT_MPGeth_Milan.Textures.ConcreteGround_Diff'",
      "Texture2D'BioT_MPGeth_Milan.Textures.ConcreteDamStained_Diff'"
    ],
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
  },
  "SM2MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 0,
    "ID": "45e88ac9-a010-43e2-8db5-7075b8da41bc",
    "NumUserTexCoords": 3475175324,
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
