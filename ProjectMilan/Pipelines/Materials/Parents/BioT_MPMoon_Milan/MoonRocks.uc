// DONOR FOR: BioT_MPMoon.Rocks_MAT
// EXPRESSION MaterialExpressionStaticSwitchParameter_5
properties
{
    A = {Expression = None}
    B = {Expression = None}
    ExpressionGUID = {A = 759261116, B = 1102421028, C = 1195813802, D = -1017062495}
    ParameterName = 'bUseMatTile'
}
// EXPRESSION MaterialExpressionTextureSampleParameter2D_20
properties
{
    ExpressionGUID = {A = 162776556, B = 1297629572, C = 1188059547, D = -2030462485}
    ParameterName = 'NORM'
    Coordinates = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPMoon_Milan.Materials.MoonRocks.MaterialExpressionStaticSwitchParameter_5'}
    Texture = Texture2D'BioT_HooDoo_Ter.Vista_Cliff_A_Norm'
}
// EXPRESSION MaterialExpressionScalarParameter_56
properties
{
    DefaultValue = 80.0
    ExpressionGUID = {A = -1455018949, B = 1283695015, C = -225246032, D = -874243466}
    ParameterName = 'Specular Power'
}
// EXPRESSION MaterialExpressionVectorParameter_0
properties
{
    DefaultValue = {R = 1.0, G = 1.0, B = 1.0, A = 1.0}
    ExpressionGUID = {A = 1370815662, B = 1104907909, C = -684886850, D = -2109107450}
    ParameterName = 'Diff_tint'
}
// EXPRESSION MaterialExpressionTextureSampleParameter2D_1
properties
{
    ExpressionGUID = {A = -2065454607, B = 1331497891, C = 1106396548, D = -473609540}
    ParameterName = 'Diff'
    Coordinates = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPMoon_Milan.Materials.MoonRocks.MaterialExpressionStaticSwitchParameter_5'}
    Texture = Texture2D'BioT_HooDoo_Ter.Vista_Cliff_A_DIFF'
}
// EXPRESSION MaterialExpressionVectorParameter_1
properties
{
    DefaultValue = {R = 0.631372571, G = 0.698039234, B = 0.776470661, A = 1.0}
    ExpressionGUID = {A = -1252690929, B = 1318658604, C = 1110139270, D = -367490840}
    ParameterName = 'Spec_Intensity'
}
// EXPRESSION MaterialExpressionScalarParameter_3
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = 87769433, B = 1330661153, C = 1253732528, D = -1980233800}
    ParameterName = 'Base_Mat_Tile_Y'
}
// EXPRESSION MaterialExpressionScalarParameter_2
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = 762520319, B = 1318509511, C = 1596369814, D = 1219311335}
    ParameterName = 'Base_Mat_Tile_X'
}
// EXPRESSION MaterialExpressionTextureSampleParameter2D_21
properties
{
    ExpressionGUID = {A = -1144183999, B = 1265777919, C = -1202943061, D = -1967546259}
    ParameterName = 'Diff'
    Coordinates = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPMoon_Milan.Materials.MoonRocks.MaterialExpressionStaticSwitchParameter_5'}
    Texture = Texture2D'BioT_HooDoo_Ter.Vista_Cliff_A_DIFF'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_2
properties
{
    A = {Expression = None}
    B = {Expression = MaterialExpressionTextureSampleParameter2D'BioT_MPMoon_Milan.Materials.MoonRocks.MaterialExpressionTextureSampleParameter2D_21', Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    ExpressionGUID = {A = -1651011631, B = 1225876983, C = 1915317641, D = 1172149687}
    ParameterName = 'bUseDiffuseTint'
}
// EXPRESSION MaterialExpressionScalarParameter_11
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = -85462405, B = 1181461651, C = -1196312148, D = -1568445328}
    ParameterName = 'Y_Pan'
}
// EXPRESSION MaterialExpressionScalarParameter_10
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = 826296543, B = 1152937645, C = -1055762795, D = 67262154}
    ParameterName = 'X_Pan'
}
// PROPERTIES
properties
{
    Normal = {Expression = MaterialExpressionTextureSampleParameter2D'BioT_MPMoon_Milan.Materials.MoonRocks.MaterialExpressionTextureSampleParameter2D_20', Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    DiffuseColor = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPMoon_Milan.Materials.MoonRocks.MaterialExpressionStaticSwitchParameter_2'}
    SpecularColor = {Expression = None}
    SpecularPower = {Expression = MaterialExpressionScalarParameter'BioT_MPMoon_Milan.Materials.MoonRocks.MaterialExpressionScalarParameter_56'}
    PhysMaterial = PhysicalMaterial'BIOG_PHM_General_F.PHM_GEN_Stone_01'
    bUsedWithFoliage = TRUE
    bUsedWithStaticLighting = TRUE
    bUsedWithVectorLightMaps = TRUE
    m_Guid = {A = -2073407352, B = 1160245657, C = -756035186, D = -1967708073}
    LightingGuid = {A = 408473079, B = 1134124603, C = -106884215, D = -254612282}
}
// BINARY
{
  "SM3MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 1,
    "ID": "8d045b57-0ef0-4b69-87b0-95360e08e269",
    "NumUserTexCoords": 1,
    "UniformExpressionTextures": [
      "Texture2D'BioT_HooDoo_Ter.Vista_Cliff_A_Norm'",
      "Texture2D'BioT_HooDoo_Ter.Vista_Cliff_A_DIFF'"
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
    "ID": "01bbd04f-0aba-4cb1-9791-47b016bac3ff",
    "NumUserTexCoords": 1140457472,
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
