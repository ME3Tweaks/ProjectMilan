// MILAN CHANGE 10/20/2026
// Use higher LODs for sentinels
defaultproperties
{
    SkeletalMesh = SkeletalMesh'BIOG_MP_HMF_MED_R.Mesh.MP_HMF_MED_MUP_MDL'
    PhysicsAsset = PhysicsAsset'biog_phy_humanoid_f.PHY_HMF_HVYa'
    // MILAN CHANGE - Remove LOD override
    // MinAutoLODLevel = 1
    // END MILAN CHANGE
    Materials = (MaterialInstanceConstant'BIOG_MP_HMF_MED_R.MP_TNT_HIGH_MAT_INST_3', MaterialInstanceConstant'BIOG_MP_HMF_MED_R.MP_TNT_LOW_MAT_INST_3')
    ReplacementPrimitive = None
    LightEnvironment = BioDynamicLightEnvironmentComponent'SFXGameMPContent.Default__SFXPawn_PlayerMP_Sentinel.BioLightEnvComponent0'
}