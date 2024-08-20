// DONOR FOR: BioS_MPJungle.Materials.MPLabGlass_02
// EXPRESSION MaterialExpressionTextureSampleParameterNormal_20
properties
{
    ExpressionGUID = {A = -230582581, B = 1075129173, C = -483305063, D = 790744863}
    ParameterName = 'MaterialExpressionTextureSampleParameterNormal_20'
    Texture = Texture2D'biot_salarian.LowerGlass_Norm'
}
// EXPRESSION MaterialExpressionTextureSampleParameterCube_1
properties
{
    ExpressionGUID = {A = 1251027589, B = 1124888664, C = -1528558173, D = -1712569305}
    ParameterName = 'MaterialExpressionTextureSampleParameterCube_1'
    Coordinates = {Expression = None}
    Texture = TextureCube'BioG_MasterMats.Texture_Samples.Cubemap_05'
}
// EXPRESSION MaterialExpressionTextureSampleParameter2D_48
properties
{
    ExpressionGUID = {A = 1489918605, B = 1258738865, C = 1032685953, D = 780150968}
    ParameterName = 'MaterialExpressionTextureSampleParameter2D_38'
    Texture = Texture2D'biot_salarian.Grunge_Streak01_Diff'
}
// EXPRESSION MaterialExpressionTextureSampleParameter2D_38
properties
{
    ExpressionGUID = {A = -1526706184, B = 1137008158, C = -985152855, D = -1011280297}
    ParameterName = 'MaterialExpressionTextureSampleParameter2D_38'
    Coordinates = {Expression = None}
    Texture = Texture2D'biot_salarian.Grunge_Streak01_Diff'
}
// EXPRESSION MaterialExpressionVectorParameter_38
properties
{
    DefaultValue = {R = 1.0, G = 0.579286814, B = 0.385799825, A = 1.0}
    ExpressionGUID = {A = 1264090367, B = 1319850238, C = 691327671, D = 1622175147}
}
// PROPERTIES
properties
{
    Normal = {Expression = MaterialExpressionTextureSampleParameterNormal'BioT_MPJngl_Milan.Materials.JnglLabGlass.MaterialExpressionTextureSampleParameterNormal_20', Mask = 1, MaskR = 1, MaskG = 1, MaskB = 1}
    Distortion = {Mask = 1, MaskG = 1}
    EmissiveColor = {Expression = None}
    Opacity = {Expression = None}
    PhysMaterial = PhysicalMaterial'BIOG_PHM_General_F.PHM_GEN_Glass_01'
    bUsedWithSkeletalMesh = TRUE
    bUsedWithStaticLighting = TRUE
    bUsedWithVectorLightMaps = TRUE
    BlendMode = EBlendMode.BLEND_Translucent
    LightingModel = EMaterialLightingModel.MLM_Unlit
    m_Guid = {A = -428457326, B = 1244925656, C = 1719867034, D = -841904901}
    LightingGuid = {A = -1610566709, B = 1215593340, C = -179079778, D = 1110725889}
}
// BINARY
{
  "SM3MaterialResource": {
    "CompileErrors": [],
    "TextureDependencyLengthMap": {},
    "MaxTextureDependencyLength": 1,
    "ID": "41e1b469-68a8-4a95-93d7-e09154864e79",
    "NumUserTexCoords": 1,
    "UniformExpressionTextures": [
      "Texture2D'biot_salarian.LowerGlass_Norm'",
      "Texture2D'biot_salarian.Grunge_Streak01_Diff'",
      "TextureCube'BioG_MasterMats.Texture_Samples.Cubemap_05'"
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
      },
      {
        "TexCoordIndex": 0,
        "TextureIndex": 1,
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
    "ID": "abc8d0ea-b0ff-4ef5-b65e-18f8eb33503b",
    "NumUserTexCoords": 7209071,
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
