// DONOR FOR: BioT_MPMoon.Crate_MAT
// EXPRESSION MaterialExpressionScalarParameter_10
properties
{
    ExpressionGUID = {A = -605512739, B = 1156419316, C = -1483872884, D = 1122987599}
    ParameterName = 'Damaged'
}
// EXPRESSION MaterialExpressionScalarParameter_5
properties
{
    ExpressionGUID = {A = -1987830205, B = 1140773657, C = 413254041, D = 1197001966}
    ParameterName = 'Diffuse_Override_Opacity'
}
// EXPRESSION MaterialExpressionVectorParameter_13
properties
{
    DefaultValue = {R = 4.0, G = 4.0, B = 4.0, A = 1.0}
    ExpressionGUID = {A = -1440415829, B = 1223853641, C = -116112746, D = 1634689393}
    ParameterName = 'Specular'
}
// EXPRESSION MaterialExpressionTextureSampleParameterNormal_1045
properties
{
    ExpressionGUID = {A = -440863398, B = 1295588777, C = 296183711, D = 1860377249}
    ParameterName = 'Damaged'
    Texture = Texture2D'BIOG_APL_MASTER_MATERIAL.Damaged'
}
// EXPRESSION MaterialExpressionVectorParameter_12
properties
{
    DefaultValue = {R = 0.827726007, G = 0.0, B = 0.0, A = 1.0}
    ExpressionGUID = {A = 629823432, B = 1264074092, C = 212299404, D = 1622403277}
    ParameterName = 'Diffuse_Color'
}
// EXPRESSION MaterialExpressionVectorParameter_11
properties
{
    DefaultValue = {R = 1.0, G = 1.0, B = 1.0, A = 1.0}
    ExpressionGUID = {A = -627255990, B = 1334185658, C = -1931523394, D = -832115964}
    ParameterName = 'Diffuse_Multiplier'
}
// PROPERTIES
properties
{
    Normal = {Expression = None}
    DiffuseColor = {Expression = None}
    SpecularColor = {Expression = None}
    SpecularPower = {Expression = None}
    PhysMaterial = PhysicalMaterial'BIOG_PHM_General_F.PHM_GEN_Metal_01'
    bUsedWithSkeletalMesh = TRUE
    bUsedWithStaticLighting = TRUE
    bUsedWithVectorLightMaps = TRUE
    m_Guid = {A = 1961161706, B = 1149047614, C = 862352318, D = 506664766}
    LightingGuid = {A = 315409116, B = 1124320407, C = 680228994, D = 629757931}
}
// BINARY
{
  "SM3MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 1,
    "ID": "2f66630c-9b21-45f2-9619-3d35dad9a6eb",
    "NumUserTexCoords": 1,
    "UniformExpressionTextures": [
      "Texture2D'bioapl_cra_crate01.Crate01_S.Crate_SM_Norm'",
      "Texture2D'BIOG_APL_MASTER_MATERIAL.Damaged'",
      "Texture2D'bioapl_cra_crate01.Crate01_S.Crate_SM_Diff'"
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
    "ID": "bdbd27f8-845e-4a43-9e17-845de3226662",
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
