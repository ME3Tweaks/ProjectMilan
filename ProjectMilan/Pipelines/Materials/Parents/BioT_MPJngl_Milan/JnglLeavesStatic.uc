// DONOR FOR: BioS_MPJungle.Materials.Leaves_static_MAT
// EXPRESSION MaterialExpressionStaticSwitchParameter_3
properties
{
    A = {Expression = None}
    B = {Expression = None}
    DefaultValue = TRUE
    ExpressionGUID = {A = 1465056234, B = 1199861379, C = 404232344, D = -684858759}
    ParameterName = 'VertAnim_Switch'
}
// EXPRESSION MaterialExpressionScalarParameter_28
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = -2000008579, B = 1230289090, C = -1020180566, D = -1840135974}
    ParameterName = 'Amplitude_01'
}
// EXPRESSION MaterialExpressionScalarParameter_26
properties
{
    DefaultValue = 5.0
    ExpressionGUID = {A = -1928877012, B = 1075947556, C = 1596636823, D = -462486625}
    ParameterName = 'Variation_Strength_01'
}
// EXPRESSION MaterialExpressionScalarParameter_27
properties
{
    ExpressionGUID = {A = 1766422990, B = 1206443753, C = 988624527, D = -1940078865}
    ParameterName = 'Wind_Direction'
}
// EXPRESSION MaterialExpressionScalarParameter_31
properties
{
    ExpressionGUID = {A = 1399489982, B = 1170762800, C = 356473532, D = -899909582}
    ParameterName = 'Offset_02'
}
// EXPRESSION MaterialExpressionScalarParameter_40
properties
{
    ExpressionGUID = {A = 629286021, B = 1100844097, C = 616116632, D = -1298774185}
    ParameterName = 'Brightness'
}
// EXPRESSION MaterialExpressionScalarParameter_25
properties
{
    DefaultValue = 0.200000003
    ExpressionGUID = {A = -179416950, B = 1144367158, C = 285226687, D = -749747009}
    ParameterName = 'Frequency_01'
}
// EXPRESSION MaterialExpressionScalarParameter_29
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = 1344016085, B = 1221489572, C = 1646018229, D = -1076422232}
    ParameterName = 'Wind_Effect_Strength'
}
// EXPRESSION MaterialExpressionScalarParameter_30
properties
{
    DefaultValue = 0.200000003
    ExpressionGUID = {A = -2061485573, B = 1241415484, C = -1570576745, D = 337534587}
    ParameterName = 'Frequency_02'
}
// EXPRESSION MaterialExpressionVectorParameter_5
properties
{
    DefaultValue = {R = 0.267557919, G = 0.267557919, B = 0.535115838, A = 1.0}
    ExpressionGUID = {A = 347907138, B = 1182022141, C = -36706894, D = 620832445}
    ParameterName = 'Emissive'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_2
properties
{
    A = {Expression = None}
    B = {Expression = None}
    ExpressionGUID = {A = 1039389635, B = 1275660961, C = 812488599, D = -1663545704}
    ParameterName = 'VertAnim_2nd_Wave'
}
// EXPRESSION MaterialExpressionScalarParameter_32
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = 2047436649, B = 1223708037, C = 1691997320, D = -1026230776}
    ParameterName = 'Amplitude_02'
}
// PROPERTIES
properties
{

    Normal = {Expression = None, Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    WorldPositionOffset = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPJngl_Milan.Materials.JnglLeavesStatic.MaterialExpressionStaticSwitchParameter_3'}
    DiffuseColor = {Expression = None}
    SpecularColor = {Expression = None}
    SpecularPower = {Expression = None}
    EmissiveColor = {Expression = None}
    OpacityMask = {Expression = None, Mask = 1, MaskA = 1}
    bUsedWithStaticLighting = TRUE
    bIsMasked = TRUE
    BlendMode = EBlendMode.BLEND_Masked
    m_Guid = {A = 1266445635, B = 1189531273, C = 144037760, D = -334787440}
    LightingGuid = {A = 2041183997, B = 1203350386, C = -1631901537, D = -1411621482}
}
// BINARY
{
  "SM3MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 1,
    "ID": "c83591f0-2dac-4e63-9fea-5793436afbe6",
    "NumUserTexCoords": 1,
    "UniformExpressionTextures": [
      "Texture2D'BioT_Tropical.Leaf_Norm_Alt'",
      "None",
      "None",
      "Texture2D'BioT_Tropical.Leaf_Diff_Alt'"
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
        "TextureIndex": 0,
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
    "ID": "93fcbe3f-bb22-42a6-918a-837200390ba6",
    "NumUserTexCoords": 6619239,
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
