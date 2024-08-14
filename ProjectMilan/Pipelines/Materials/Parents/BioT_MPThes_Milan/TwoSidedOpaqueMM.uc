// DONOR FOR: BioT_MPThes.2sided_OPAQUE_MM
// EXPRESSION MaterialExpressionTextureSampleParameterNormal_5
properties
{
    ExpressionGUID = {A = 832284228, B = 1086289547, C = 816512918, D = 49113717}
    ParameterName = 'Base_Normal'
    Texture = Texture2D'BioG_MasterMats.Texture_Samples.Panel_Norm_01'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_33
properties
{
    A = {Expression = MaterialExpressionTextureSampleParameterNormal'BioT_MPThes_Milan.Materials.TwoSidedOpaqueMM.MaterialExpressionTextureSampleParameterNormal_5', Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    B = {Expression = None}
    DefaultValue = TRUE
    ExpressionGUID = {A = 523552973, B = 1199603324, C = 921943996, D = 2039139121}
    ParameterName = 'Base_Norm_Switch'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_6
properties
{
    A = {Expression = None}
    B = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPThes_Milan.Materials.TwoSidedOpaqueMM.MaterialExpressionStaticSwitchParameter_33'}
    ExpressionGUID = {A = 65008407, B = 1240040902, C = 404692660, D = -1957800249}
    ParameterName = 'Detail_Norm_Switch'
}
// EXPRESSION MaterialExpressionVectorParameter_1
properties
{
    DefaultValue = {R = 0.980000019, G = 0.954453468, B = 0.899999976, A = 1.0}
    ExpressionGUID = {A = -1845211325, B = 1089600297, C = -1531505267, D = 199088249}
    ParameterName = 'Diff_tint'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_14
properties
{
    A = {Expression = None}
    B = {Expression = None}
    DefaultValue = TRUE
    ExpressionGUID = {A = 1715248399, B = 1205624954, C = -1536151151, D = 847390603}
    ParameterName = 'Base_Mat_NUT_switch'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_36
properties
{
    A = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPThes_Milan.Materials.TwoSidedOpaqueMM.MaterialExpressionStaticSwitchParameter_14'}
    B = {Expression = None}
    ExpressionGUID = {A = -818655256, B = 1117280249, C = 1899156365, D = 1920868158}
    ParameterName = 'Base_Mat_Tile_Switch'
}
// EXPRESSION MaterialExpressionTextureSampleParameter2D_2
properties
{
    ExpressionGUID = {A = 1539139102, B = 1111203196, C = -1203704146, D = 972364597}
    ParameterName = 'Spec_IMG_A'
    Coordinates = {Expression = None}
    Texture = Texture2D'BioG_MasterMats.Texture_Samples.Spec_HS_A'
}
// EXPRESSION MaterialExpressionTextureSampleParameter2D_0
properties
{
    ExpressionGUID = {A = 769254756, B = 1304560225, C = 1625558180, D = 1426810646}
    ParameterName = 'Diffuse'
    Coordinates = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPThes_Milan.Materials.TwoSidedOpaqueMM.MaterialExpressionStaticSwitchParameter_36'}
    Texture = Texture2D'BioG_MasterMats.Texture_Samples.Panel_Diff_01'
}
// EXPRESSION MaterialExpressionScalarParameter_15
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = -1556450856, B = 1297626587, C = 978721211, D = 1626861026}
    ParameterName = 'Base_Mat_Tile'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_22
properties
{
    A = {Expression = None}
    B = {Expression = None}
    ExpressionGUID = {A = -964588665, B = 1324695751, C = -933577305, D = 1471317720}
    ParameterName = 'Emis_Toggle_MSK/Diff_Alpha'
}
// EXPRESSION MaterialExpressionTextureSampleParameter2D_1
properties
{
    ExpressionGUID = {A = -1480489672, B = 1134296761, C = -504480326, D = -1710949414}
    ParameterName = 'Spec_RGB'
    Coordinates = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPThes_Milan.Materials.TwoSidedOpaqueMM.MaterialExpressionStaticSwitchParameter_36'}
    Texture = Texture2D'BioG_MasterMats.Texture_Samples.ME3_Noise01'
}
// EXPRESSION MaterialExpressionScalarParameter_9
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = -616324639, B = 1141131363, C = -285628764, D = -2044173274}
    ParameterName = 'Base_Mat_Tile_Y'
}
// EXPRESSION MaterialExpressionScalarParameter_7
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = 1537145308, B = 1214569919, C = -101596481, D = 402542840}
    ParameterName = 'Base_Mat_Tile_X'
}
// EXPRESSION MaterialExpressionVectorParameter_2
properties
{
    DefaultValue = {R = 1.0, G = 0.0, B = 0.0, A = 1.0}
    ExpressionGUID = {A = -143852173, B = 1285763397, C = 1001680062, D = 1124322935}
    ParameterName = 'Spec_RGB_Chooser'
}
// EXPRESSION MaterialExpressionVectorParameter_4
properties
{
    DefaultValue = {R = 1.0, G = 1.0, B = 1.0, A = 1.0}
    ExpressionGUID = {A = -220251332, B = 1334901526, C = 790766774, D = 770229680}
    ParameterName = 'Cubemap_Color_Intensity'
}
// EXPRESSION MaterialExpressionTextureSampleParameter2D_6
properties
{
    ExpressionGUID = {A = -94130491, B = 1210917904, C = -1545648715, D = -743129510}
    ParameterName = 'Emis_MSK'
    Coordinates = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPThes_Milan.Materials.TwoSidedOpaqueMM.MaterialExpressionStaticSwitchParameter_36'}
    Texture = Texture2D'BioG_MasterMats.Texture_Samples.Blank_Texture'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_10
properties
{
    A = {Expression = None}
    B = {Expression = None}
    DefaultValue = TRUE
    ExpressionGUID = {A = -971697141, B = 1173290154, C = 1841897089, D = 1084647836}
    ParameterName = 'Det_Norm_NUT_switch'
}
// EXPRESSION MaterialExpressionTextureSampleParameterNormal_7
properties
{
    ExpressionGUID = {A = -1984118487, B = 1141827405, C = -1245970758, D = -1034046933}
    ParameterName = 'Detail_Norm'
    Coordinates = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPThes_Milan.Materials.TwoSidedOpaqueMM.MaterialExpressionStaticSwitchParameter_10'}
    Texture = Texture2D'BioG_MasterMats.Texture_Samples.Detail_Norm_01'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_35
properties
{
    A = {Expression = None}
    B = {Expression = MaterialExpressionTextureSampleParameterNormal'BioT_MPThes_Milan.Materials.TwoSidedOpaqueMM.MaterialExpressionTextureSampleParameterNormal_7', Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    DefaultValue = TRUE
    ExpressionGUID = {A = -1510040537, B = 1178095590, C = -1807407942, D = 313301465}
    ParameterName = 'Detail_Norm_Intensity_Switch'
}
// EXPRESSION MaterialExpressionScalarParameter_14
properties
{
    DefaultValue = 0.600000024
    ExpressionGUID = {A = -1631132487, B = 1199822802, C = 894642078, D = -357168641}
    ParameterName = 'Det_Spec_Min_Clamp'
}
// EXPRESSION MaterialExpressionScalarParameter_6
properties
{
    DefaultValue = 5.0
    ExpressionGUID = {A = -945470169, B = 1313968245, C = 747995825, D = 1241772759}
    ParameterName = 'Detail_Norm_Tile'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_8
properties
{
    A = {Expression = None}
    B = {Expression = None}
    ExpressionGUID = {A = 1104754005, B = 1282018900, C = -313898070, D = -792333882}
    ParameterName = 'Detail_Norm_UV_Switch'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_7
properties
{
    A = {Expression = None}
    B = {Expression = None}
    DefaultValue = TRUE
    ExpressionGUID = {A = -666539676, B = 1288155199, C = -1985994054, D = -987650290}
    ParameterName = 'Det_Spec_NUT_switch'
}
// EXPRESSION MaterialExpressionTextureSampleParameterNormal_2
properties
{
    ExpressionGUID = {A = -1285972443, B = 1177081782, C = -1030234219, D = 496669779}
    ParameterName = 'Detail_Spec'
    Coordinates = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPThes_Milan.Materials.TwoSidedOpaqueMM.MaterialExpressionStaticSwitchParameter_7'}
    Texture = Texture2D'BioG_MasterMats.Texture_Samples.Spec_Tile_E'
}
// EXPRESSION MaterialExpressionVectorParameter_6
properties
{
    DefaultValue = {R = 1.0, G = 1.0, B = 1.0, A = 1.0}
    ExpressionGUID = {A = -677349650, B = 1324346417, C = -2114444113, D = -480468796}
    ParameterName = 'Emis_Color_Intensity'
}
// EXPRESSION MaterialExpressionScalarParameter_11
properties
{
    DefaultValue = 5.0
    ExpressionGUID = {A = -298854000, B = 1240733766, C = -1958801499, D = -1978873846}
    ParameterName = 'Detail_Spec_Tile'
}
// EXPRESSION MaterialExpressionScalarParameter_12
properties
{
    DefaultValue = 5.0
    ExpressionGUID = {A = 960142827, B = 1172426201, C = 121554847, D = -2115127279}
    ParameterName = 'Det_Norm_Tile_Y'
}
// EXPRESSION MaterialExpressionScalarParameter_13
properties
{
    DefaultValue = 8.0
    ExpressionGUID = {A = -1016931818, B = 1178996233, C = -151264882, D = -1388597343}
    ParameterName = 'Det_Norm_Tile_X'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_9
properties
{
    A = {Expression = None}
    B = {Expression = None}
    ExpressionGUID = {A = -86263100, B = 1197432156, C = -1466996096, D = -1552677415}
    ParameterName = 'Detail_Spec_UV_Switch'
}
// EXPRESSION MaterialExpressionTextureSampleParameterCube_4
properties
{
    ExpressionGUID = {A = 358677632, B = 1326787886, C = 1886185634, D = -219808426}
    ParameterName = 'CubeMap'
    Coordinates = {Expression = None}
    Texture = TextureCube'BioG_MasterMats.Texture_Samples.Cubemap_02'
}
// EXPRESSION MaterialExpressionScalarParameter_4
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = -460242515, B = 1137608852, C = 1298972606, D = 1964668344}
    ParameterName = 'Detail_Norm_Intensity'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_1
properties
{
    A = {Expression = None}
    B = {Expression = MaterialExpressionTextureSampleParameter2D'BioT_MPThes_Milan.Materials.TwoSidedOpaqueMM.MaterialExpressionTextureSampleParameter2D_0', Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    ExpressionGUID = {A = 1114590863, B = 1227739531, C = 1375042473, D = -1472884565}
    ParameterName = 'Diff_Tint_Switch'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_42
properties
{
    A = {Expression = None}
    B = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPThes_Milan.Materials.TwoSidedOpaqueMM.MaterialExpressionStaticSwitchParameter_1'}
    ExpressionGUID = {A = -197070651, B = 1297215704, C = -1049308012, D = -2127586642}
    ParameterName = 'Vert_Paint_Switch'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_32
properties
{
    A = {Expression = None}
    B = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPThes_Milan.Materials.TwoSidedOpaqueMM.MaterialExpressionStaticSwitchParameter_42'}
    DefaultValue = TRUE
    ExpressionGUID = {A = -16186699, B = 1318105302, C = 1381503159, D = 86355853}
    ParameterName = 'Cubemap_Switch'
}
// EXPRESSION MaterialExpressionVectorParameter_5
properties
{
    DefaultValue = {R = 0.486468971, G = 0.298555732, B = 0.17882131, A = 1.0}
    ExpressionGUID = {A = -112582001, B = 1275890814, C = 1865980339, D = -354222502}
    ParameterName = 'SSS_Color'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_2
properties
{
    A = {Expression = MaterialExpressionVectorParameter'BioT_MPThes_Milan.Materials.TwoSidedOpaqueMM.MaterialExpressionVectorParameter_5', Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    B = {Expression = None}
    ExpressionGUID = {A = 2000776475, B = 1169777203, C = -755978354, D = 1151312591}
    ParameterName = 'SSS_Switch'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_4
properties
{
    A = {Expression = None}
    B = {Expression = None}
    ExpressionGUID = {A = 2071476761, B = 1190374144, C = 299422909, D = -628192293}
    ParameterName = 'SSS_Switch'
}
// EXPRESSION MaterialExpressionScalarParameter_10
properties
{
    DefaultValue = 3.0
    ExpressionGUID = {A = -418819401, B = 1081092459, C = -1909455737, D = 138588182}
    ParameterName = 'Det_Spec_Tile_Y'
}
// EXPRESSION MaterialExpressionScalarParameter_8
properties
{
    DefaultValue = 3.0
    ExpressionGUID = {A = -84089199, B = 1269418457, C = -1230701654, D = -935187265}
    ParameterName = 'Det_Spec_Tile_X'
}
// EXPRESSION MaterialExpressionScalarParameter_3
properties
{
    DefaultValue = 3.0
    ExpressionGUID = {A = -1724319276, B = 1236227273, C = 1153226147, D = -219498830}
    ParameterName = 'SSS_Width'
}
// EXPRESSION MaterialExpressionVectorParameter_7
properties
{
    DefaultValue = {R = 1.0, G = 1.0, B = 1.0, A = 1.0}
    ExpressionGUID = {A = -1132826722, B = 1293633639, C = -1393058172, D = -108990786}
    ParameterName = 'Spec_Color_Intensity'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_17
properties
{
    A = {Expression = None}
    B = {Expression = None}
    ExpressionGUID = {A = -1419213122, B = 1090892793, C = 1952353696, D = 964704104}
    ParameterName = 'SpecIMG_Switch'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_34
properties
{
    A = {Expression = None}
    B = {Expression = None}
    ExpressionGUID = {A = -1605460810, B = 1112791602, C = 234728373, D = -1824197061}
    ParameterName = 'Cubemap_Detail_Spec_Switch'
}
// EXPRESSION MaterialExpressionScalarParameter_2
properties
{
    DefaultValue = 0.5
    ExpressionGUID = {A = 1303689333, B = 1223531492, C = 1068441269, D = 1628826190}
    ParameterName = 'Spec_IMG_A_Scale'
}
// EXPRESSION MaterialExpressionScalarParameter_53
properties
{
    DefaultValue = 25.0
    ExpressionGUID = {A = -806871047, B = 1118161387, C = 1452638620, D = -150387646}
    ParameterName = 'Spec_Pwr'
}
// EXPRESSION MaterialExpressionVectorParameter_3
properties
{
    DefaultValue = {R = 1.0, G = 1.0, B = 1.0, A = 1.0}
    ExpressionGUID = {A = 741009932, B = 1156271483, C = -211773771, D = 1797625613}
    ParameterName = 'SpecIMG_Color_Intensity'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_25
properties
{
    A = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPThes_Milan.Materials.TwoSidedOpaqueMM.MaterialExpressionStaticSwitchParameter_22'}
    B = {Expression = None}
    ExpressionGUID = {A = 810790853, B = 1254072231, C = -308056687, D = -630277303}
    ParameterName = 'Emis_Switch'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_0
properties
{
    A = {Expression = MaterialExpressionTextureSampleParameter2D'BioT_MPThes_Milan.Materials.TwoSidedOpaqueMM.MaterialExpressionTextureSampleParameter2D_0', Mask = 1, MaskA = 1}
    B = {Expression = None}
    ExpressionGUID = {A = 1360742550, B = 1245259438, C = -1105494863, D = 729455752}
    ParameterName = 'Spec_Alpha_Switch'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_3
properties
{
    A = {Expression = None}
    B = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPThes_Milan.Materials.TwoSidedOpaqueMM.MaterialExpressionStaticSwitchParameter_0'}
    ExpressionGUID = {A = -1221433, B = 1249560326, C = 612968076, D = -68615201}
    ParameterName = 'Spec_RBG_Switch'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_12
properties
{
    A = {Expression = None}
    B = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPThes_Milan.Materials.TwoSidedOpaqueMM.MaterialExpressionStaticSwitchParameter_3'}
    ExpressionGUID = {A = 881800873, B = 1148084610, C = 1958794678, D = -1517820569}
    ParameterName = 'Detail_Spec_Switch'
}

// PROPERTIES
properties
{
    Normal = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPThes_Milan.Materials.TwoSidedOpaqueMM.MaterialExpressionStaticSwitchParameter_6'}
    DiffuseColor = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPThes_Milan.Materials.TwoSidedOpaqueMM.MaterialExpressionStaticSwitchParameter_32'}
    SpecularColor = {Expression = None}
    SpecularPower = {Expression = MaterialExpressionScalarParameter'BioT_MPThes_Milan.Materials.TwoSidedOpaqueMM.MaterialExpressionScalarParameter_53'}
    EmissiveColor = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPThes_Milan.Materials.TwoSidedOpaqueMM.MaterialExpressionStaticSwitchParameter_25'}
    TwoSided = TRUE
    bUsedWithSkeletalMesh = TRUE
    bUsedWithStaticLighting = TRUE
    bUsedWithInstancedMeshes = TRUE
    bUsedWithSplineMeshes = TRUE
    bUsedWithVectorLightMaps = TRUE
    bUsedWithSimpleLightMaps = TRUE
    m_Guid = {A = 2043410789, B = 1262422410, C = 2144828843, D = -738316522}
    LightingGuid = {A = 461334796, B = 1304811755, C = -390491499, D = -1755231554}
}
// BINARY
{
  "SM3MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 1,
    "ID": "55921b68-3f62-44ff-bbe7-6f89e6197c05",
    "NumUserTexCoords": 1,
    "UniformExpressionTextures": [
      "Texture2D'BioG_MasterMats.Texture_Samples.Panel_Norm_01'",
      "Texture2D'BioG_MasterMats.Texture_Samples.Panel_Diff_01'",
      "TextureCube'BioG_MasterMats.Texture_Samples.Cubemap_02'"
    ],
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
  },
  "SM2MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 0,
    "ID": "ce856353-355b-46ee-863e-b54af28c9780",
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
    "unkUint1": 0,
    "udkUnk2": 0,
    "udkUnk3": 0,
    "udkUnk4": 0
  }
}
