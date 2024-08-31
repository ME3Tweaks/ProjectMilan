// DONOR FOR: BioT_MPThes.Materials.Glass_Master
// EXPRESSION MaterialExpressionTextureSampleParameterCube_1
properties
{
    ExpressionGUID = {A = 1624892975, B = 1204689312, C = -645914986, D = 906655880}
    ParameterName = 'CubeMap'
    Coordinates = {Expression = None}
    Texture = TextureCube'BioG_MasterMats.Texture_Samples.Cubemap_05'
}
// EXPRESSION MaterialExpressionVectorParameter_0
properties
{
    DefaultValue = {R = 0.25, G = 0.25, B = 1.0, A = 1.0}
    ExpressionGUID = {A = 740161028, B = 1131338084, C = -194903394, D = -664628228}
    ParameterName = 'Normal Ammount'
}
// EXPRESSION MaterialExpressionTextureSampleParameterNormal_0
properties
{
    ExpressionGUID = {A = 1486573708, B = 1102072983, C = -893780594, D = 66673397}
    ParameterName = 'Displace_Normal'
    Coordinates = {Expression = None}
    Texture = Texture2D'BioT_Human_Space.Textures.Glass_Norm'
}
// EXPRESSION MaterialExpressionVectorParameter_2
properties
{
    DefaultValue = {R = 0.0382262953, G = 0.04809165, B = 0.056214191, A = 1.0}
    ExpressionGUID = {A = -822923006, B = 1342174453, C = -1592813128, D = -87885209}
    ParameterName = 'Color_Glow'
}
// EXPRESSION MaterialExpressionVectorParameter_36
properties
{
    DefaultValue = {R = 0.0382262953, G = 0.04809165, B = 0.056214191, A = 1.0}
    ExpressionGUID = {A = -1009175790, B = 1253599576, C = -2112201298, D = 1135032717}
    ParameterName = 'Color'
}
// EXPRESSION MaterialExpressionVectorParameter_8
properties
{
    DefaultValue = {R = 10.0, G = 10.0, B = 10.0, A = 1.0}
    ExpressionGUID = {A = -502603107, B = 1214563348, C = -1974353012, D = -2105467771}
    ParameterName = 'Cube_tint'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_145
properties
{
    A = {Expression = MaterialExpressionVectorParameter'BioT_MPThes_Milan.Materials.ThesGlassMaster.MaterialExpressionVectorParameter_36', Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    B = {Expression = MaterialExpressionVectorParameter'BioT_MPThes_Milan.Materials.ThesGlassMaster.MaterialExpressionVectorParameter_8', Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    DefaultValue = TRUE
    ExpressionGUID = {A = 69352993, B = 1189181573, C = -794411369, D = 340382297}
    ParameterName = 'Logo'
}
// EXPRESSION MaterialExpressionScalarParameter_0
properties
{
    DefaultValue = 5.0
    ExpressionGUID = {A = 677970418, B = 1137456055, C = 639774594, D = -73789089}
    ParameterName = 'Distortion'
}
// EXPRESSION MaterialExpressionTextureSampleParameter2D_30
properties
{
    ExpressionGUID = {A = 1839688795, B = 1093189343, C = -912180578, D = -814015044}
    ParameterName = 'Scratch_Map'
    Coordinates = {Expression = None}
    Texture = Texture2D'BioS_Grissom_Boyd.GlassMask_01_Diff'
}
// EXPRESSION MaterialExpressionScalarParameter_2
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = 1013260565, B = 1174712952, C = 1027735451, D = -1411045992}
    ParameterName = 'Scratch_Ammount'
}
// EXPRESSION MaterialExpressionVectorParameter_1
properties
{
    DefaultValue = {R = 0.5, G = 0.400000006, B = 0.300000012, A = 1.0}
    ExpressionGUID = {A = -1713057608, B = 1214341933, C = 27519644, D = 1862867794}
    ParameterName = 'Fresnel_Color'
}
// EXPRESSION MaterialExpressionScalarParameter_30
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = 1363008163, B = 1085514694, C = 825518728, D = -1406485177}
    ParameterName = 'ScratchTile'
}
// EXPRESSION MaterialExpressionScalarParameter_40
properties
{
    DefaultValue = 10.0
    ExpressionGUID = {A = 500400354, B = 1137898510, C = 180757380, D = -1879105154}
    ParameterName = 'Sratch_Opac_Strength'
}
// EXPRESSION MaterialExpressionScalarParameter_38
properties
{
    DefaultValue = 0.400000006
    ExpressionGUID = {A = -958673849, B = 1210205213, C = 1613102228, D = 290058786}
    ParameterName = 'Opacity'
}
// EXPRESSION MaterialExpressionScalarParameter_26
properties
{
    DefaultValue = 30.0
    ExpressionGUID = {A = -1345209359, B = 1203324484, C = -789464170, D = 1637325631}
    ParameterName = 'Spec_Power'
}
// EXPRESSION MaterialExpressionStaticSwitchParameter_0
properties
{
    A = {Expression = None}
    B = {Expression = None}
    ExpressionGUID = {A = 754804170, B = 1251726652, C = -1299981175, D = 775992870}
    ParameterName = 'Emissive_color'
}
// EXPRESSION MaterialExpressionScalarParameter_24
properties
{
    DefaultValue = 5.0
    ExpressionGUID = {A = 2060494100, B = 1173272595, C = -1128168320, D = 1379131905}
    ParameterName = 'Spec'
}
// EXPRESSION MaterialExpressionScalarParameter_28
properties
{
    DefaultValue = 1.0
    ExpressionGUID = {A = 1168168541, B = 1085994255, C = 1696748198, D = 1006453989}
    ParameterName = 'Cube_Strength'
}
// PROPERTIES
properties
{
    Normal = {Expression = None}
    Distortion = {Expression = None}
    DiffuseColor = {Expression = None}
    SpecularColor = {Expression = None}
    SpecularPower = {Expression = MaterialExpressionScalarParameter'BioT_MPThes_Milan.Materials.ThesGlassMaster.MaterialExpressionScalarParameter_26'}
    EmissiveColor = {Expression = MaterialExpressionStaticSwitchParameter'BioT_MPThes_Milan.Materials.ThesGlassMaster.MaterialExpressionStaticSwitchParameter_0'}
    Opacity = {Expression = None}
    PhysMaterial = PhysicalMaterial'BIOG_PHM_General_F.PHM_GEN_Glass_01'
    bUsedWithParticleSprites = TRUE
    bUsedWithStaticLighting = TRUE
    bUsedWithVectorLightMaps = TRUE
    bUsesDistortion = TRUE
    BlendMode = EBlendMode.BLEND_Translucent
    m_Guid = {A = 1613941722, B = 1160714011, C = 782791049, D = -243205230}
    LightingGuid = {A = 1139911298, B = 1129865807, C = -299714163, D = -1314613690}
}
// BINARY
{
  "SM3MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 1,
    "ID": "7d4dbda6-4c60-4367-8119-acd73adca284",
    "NumUserTexCoords": 1,
    "UniformExpressionTextures": [
      "Texture2D'BioT_Human_Space.Textures.Glass_Norm'",
      "TextureCube'BioG_MasterMats.Texture_Samples.Cubemap_05'",
      "Texture2D'BioS_Grissom_Boyd.GlassMask_01_Diff'"
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
    "ID": "df7f7fbd-b5a5-44cb-a387-b7422bd4a559",
    "NumUserTexCoords": 502,
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
