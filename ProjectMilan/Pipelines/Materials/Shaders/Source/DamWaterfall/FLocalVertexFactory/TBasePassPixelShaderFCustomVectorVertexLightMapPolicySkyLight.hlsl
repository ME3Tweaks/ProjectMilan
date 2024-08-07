cbuffer _Globals : register(b0)
{
  float4x4 InvViewProjectionMatrix : packoffset(c0);
  float3 CameraWorldPos : packoffset(c4);
  float4 ObjectWorldPositionAndRadius : packoffset(c5);
  float3 ObjectOrientation : packoffset(c6);
  float3 ObjectPostProjectionPosition : packoffset(c7);
  float3 ObjectNDCPosition : packoffset(c8);
  float4 ObjectMacroUVScales : packoffset(c9);
  float3 FoliageImpulseDirection : packoffset(c10);
  float4 FoliageNormalizedRotationAxisAndAngle : packoffset(c11);
  float4 WindDirectionAndSpeed : packoffset(c12);
  float4 WrapLightingParameters : packoffset(c13);
  bool bEnableDistanceShadowFading : packoffset(c14);
  float2 DistanceFadeParameters : packoffset(c14.y);
  float3x3 LocalToWorldMatrix : packoffset(c15);
  float3x3 WorldToLocalMatrix : packoffset(c18);
  float3x3 WorldToViewMatrix : packoffset(c21);
  float4 UniformPixelVector_0 : packoffset(c24);
  float4 UniformPixelVector_1 : packoffset(c25);
  float4 UniformPixelVector_2 : packoffset(c26);
  float4 UniformPixelVector_3 : packoffset(c27);
  float4 UniformPixelVector_4 : packoffset(c28);
  float4 UniformPixelScalars_0 : packoffset(c29);
  float4 UniformPixelScalars_1 : packoffset(c30);
  float4 UniformPixelScalars_2 : packoffset(c31);
  float4 UniformPixelScalars_3 : packoffset(c32);
  float4x4 LocalToWorld : packoffset(c33);
  float4x4 PreviousLocalToWorld : packoffset(c37);
  float LocalToWorldRotDeterminantFlip : packoffset(c41);
  float3x3 WorldToLocal : packoffset(c42);
  float4 LightmapCoordinateScaleBias : packoffset(c45);
  float4 ShadowmapCoordinateScaleBias : packoffset(c46);
  float MotionBlurMask : packoffset(c47) = {0};
  float4 LightColorAndFalloffExponent : packoffset(c48);
  float3 SpotDirection : packoffset(c49);
  float2 SpotAngles : packoffset(c50);
  float3 DistanceFieldParameters : packoffset(c51);
  float3 UpperSkyColor : packoffset(c52);
  float3 LowerSkyColor : packoffset(c53);
  float CharacterMask : packoffset(c53.w) = {0};
  float4 TranslucencyDepthParameters : packoffset(c54) = {0,0,0,0};
  float4 AmbientColorAndSkyFactor : packoffset(c55);
}

cbuffer PSOffsetConstants : register(b2)
{
  float4 ScreenPositionScaleBias : packoffset(c0);
  float4 MinZ_MaxZRatio : packoffset(c1);
  float4 DynamicScale : packoffset(c2);
}

SamplerState SceneDepthTextureSampler : register(s0);
SamplerState Texture2D_0Sampler : register(s1);
SamplerState Texture2D_1Sampler : register(s2);
Texture2D<float4> SceneDepthTexture : register(t0);
Texture2D<float4> Texture2D_0 : register(t1);
Texture2D<float4> Texture2D_1 : register(t2);


// 3Dmigoto declarations
#define cmp -


void main(
  float4 v0 : TEXCOORD10,
  float4 v1 : TEXCOORD11,
  float4 v2 : COLOR0,
  float4 v3 : TEXCOORD0,
  float4 v4 : TEXCOORD2,
  float4 v5 : TEXCOORD3,
  float4 v6 : TEXCOORD4,
  float4 v7 : TEXCOORD5,
  float4 v8 : TEXCOORD6,
  float4 v9 : TEXCOORD7,
  uint v10 : SV_IsFrontFace0,
  out float4 o0 : SV_Target0,
  out float o1 : SV_Target1)
{
  float4 r0,r1;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xy = v7.xy / v7.ww;
  r0.xy = r0.xy * ScreenPositionScaleBias.xy + ScreenPositionScaleBias.wz;
  r0.x = SceneDepthTexture.Sample(SceneDepthTextureSampler, r0.xy).x;
  r0.x = r0.x * MinZ_MaxZRatio.z + -MinZ_MaxZRatio.w;
  r0.x = max(1.00000001e-07, r0.x);
  r0.x = 1 / r0.x;
  r0.x = -v7.w + r0.x;
  r0.x = saturate(0.000499750138 * r0.x);
  r0.yz = UniformPixelVector_2.xy * v3.xy;
  r0.yz = r0.yz * float2(0.5,0.5) + UniformPixelVector_4.xy;
  r0.y = Texture2D_0.Sample(Texture2D_0Sampler, r0.yz).x;
  r0.zw = v3.xy * UniformPixelVector_2.xy + UniformPixelVector_3.xy;
  r0.z = Texture2D_0.Sample(Texture2D_0Sampler, r0.zw).x;
  r0.y = r0.z + r0.y;
  r0.zw = r0.yy * UniformPixelScalars_3.zz + v3.xy;
  r1.xyz = UniformPixelVector_1.xyz * r0.yyy;
  r1.xyz = r1.xyz * v2.xyz + UniformPixelVector_0.xyz;
  r1.xyz = v6.www * r1.xyz;
  // ME3Tweaks: Disable gradient for waterfall.
  //r0.y = Texture2D_1.Sample(Texture2D_1Sampler, r0.zw).x;
  //r0.x = saturate(r0.y * r0.x);
  //r0.x = v2.w * r0.x;
  //r0.xyz = r1.xyz * r0.xxx;
  //o0.xyz = r0.xyz;
  r0.x = dot(r0.xyz, float3(0.212599993,0.715200007,0.0722000003));
  o0.w = 0;
  r0.y = max(9.99999975e-05, abs(r0.x));
  r0.x = saturate(TranslucencyDepthParameters.x + -r0.x);
  r0.y = log2(r0.y);
  r0.y = TranslucencyDepthParameters.z * r0.y;
  r0.y = exp2(r0.y);
  r0.y = TranslucencyDepthParameters.y * r0.y;
  r0.y = max(9.99999975e-05, r0.y);
  r0.x = r0.x / r0.y;
  r0.y = max(TranslucencyDepthParameters.w, v9.w);
  r0.x = saturate(r0.y * r0.x + v9.w);
  r0.y = cmp(0 < TranslucencyDepthParameters.x);
  o1.x = r0.y ? r0.x : 1;
  return;
}