// DONOR FOR: BioT_NoDonor.NoDonorConcreteStained
// EXPRESSION MaterialExpressionScalarParameter_3
properties
{
    ExpressionGUID = {A = -1000213671, B = 1085726949, C = 636555688, D = -1896845046}
    ParameterName = 'Diffuse_Override_Opacity'
}
// EXPRESSION MaterialExpressionVectorParameter_5
properties
{
    DefaultValue = {R = 0.827726007, G = 0.0, B = 0.0, A = 1.0}
    ExpressionGUID = {A = 136883261, B = 1224230341, C = -1380034918, D = 910376037}
    ParameterName = 'Diffuse_Color'
}
// EXPRESSION MaterialExpressionVectorParameter_7
properties
{
    DefaultValue = {R = 1.0, G = 1.0, B = 1.0, A = 1.0}
    ExpressionGUID = {A = -847467515, B = 1188232051, C = -851365227, D = 570976650}
    ParameterName = 'Diffuse_Multiplier'
}
// EXPRESSION MaterialExpressionVectorParameter_6
properties
{
    DefaultValue = {R = 4.0, G = 4.0, B = 4.0, A = 1.0}
    ExpressionGUID = {A = -898369884, B = 1277045922, C = 1560062336, D = -1513881159}
    ParameterName = 'Specular'
}
// PROPERTIES
properties
{
    Expressions = (MaterialExpressionScalarParameter'BioT_MPGeth_Milan.Materials.ConcreteStained.MaterialExpressionScalarParameter_3', MaterialExpressionVectorParameter'BioT_MPGeth_Milan.Materials.ConcreteStained.MaterialExpressionVectorParameter_5', MaterialExpressionVectorParameter'BioT_MPGeth_Milan.Materials.ConcreteStained.MaterialExpressionVectorParameter_7', MaterialExpressionVectorParameter'BioT_MPGeth_Milan.Materials.ConcreteStained.MaterialExpressionVectorParameter_6')
    Normal = {Expression = None, Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    DiffuseColor = {Expression = None}
    SpecularColor = {Expression = None}
    SpecularPower = {Expression = None}
    PhysMaterial = PhysicalMaterial'BIOG_PHM_General_F.PHM_GEN_Concrete_02'
    bUsedWithSkeletalMesh = TRUE
    bUsedWithStaticLighting = TRUE
    bUsedWithVectorLightMaps = TRUE
    bUsedWithSimpleLightMaps = TRUE
    m_Guid = {A = 375954724, B = 1255137665, C = -2126067832, D = 792123424}
    LightingGuid = {A = -351411013, B = 1090274605, C = 431211925, D = 1466493299}
}
// BINARY
{
  "SM3MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 1,
    "ID": "fa750128-ddd1-4390-a689-456b64690bd9",
    "NumUserTexCoords": 1,
    "UniformExpressionTextures": [
      "Texture2D'BioT_MPGeth_Milan.Textures.ConcreteDam_Norm'",
      "Texture2D'BioT_MPGeth_Milan.Textures.ConcreteDamStained_Diff'"
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
    "ID": "cc46c32f-6608-421f-a015-fad9fa20e606",
    "NumUserTexCoords": 860634497,
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