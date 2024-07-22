Class SFXPowerCustomAction_MIRVBomb extends SFXPowerCustomAction_EnemyGrenade
    config(Game);


public static function PrecacheVFX(SFXObjectPool ObjectPool, RvrClientEffectManager ClientEffects)
{
    local Class<SFXProjectile_PowerCustomAction_MIRVBomb> ProjClass;
    
    Super(SFXPowerCustomAction).PrecacheVFX(ObjectPool, ClientEffects);
    ProjClass = Class<SFXProjectile_PowerCustomAction_MIRVBomb>(default.ProjectileClass);
    if (ProjClass != None)
    {
        ObjectPool.PrecacheProjectile(ProjClass.default.ShardClass);
    }
}


//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_CRB_ATA_CB_Atlas
        m_nmOrigSetName = 'CRB_ATA_CB_Atlas'
        Sequences = (AnimSequence'BIOG_CBT_A.CRB.CRB_ATA_CB_Atlas_CB_LaunchRocket')
        m_pBioAnimSetData = BioAnimSetData'BIOG_CBT_A.CRB.BioAnimSetData_0'
    End Object
    BS_StartCastAnimation = {
                             AnimName = ('CB_LaunchRocket', 
                                         'None', 
                                         'None', 
                                         'None', 
                                         'None', 
                                         'None', 
                                         'None', 
                                         'None', 
                                         'None', 
                                         'None', 
                                         'None', 
                                         'BC_Start'
                                        )
                            }
    DefaultDamageType = Class'SFXDamageType_AtlasWeapon'
    ProjectileClass = Class'SFXProjectile_PowerCustomAction_MIRVBomb'
    DetonationRumbleClass = Class'SFXRumble_Power_HeavyImpact'
    DetonationScreenShakeClass = Class'SFXShake_Power_HeavyImpact'
    ProjectileAttachPoint = 'Socket_cannon'
    CastAnimSet = MY_DYN_CRB_ATA_CB_Atlas
    ReleaseEffectBoneName = 'Socket_cannon'
    CE_ReleaseEffectTemplate = RvrClientEffect'BioVFX_Crt_Atlas.VCFX.Atlas_Rocket_Muzzle_VCFX'
    CE_ImpactTemplate = RvrClientEffect'BioVFX_Crt_Atlas.VCFX.Missile_Imp_Crt_VCFX'
    ReleaseSound = WwiseEvent'Wwise_Weapons_Heavy_Missile.Play_weapon_heavy_missile_fire'
    CastSound = WwiseEvent'Wwise_Weapons_Atlas.Play_wep_p_atlas_rocket_fire_1'
    HenchmanReleaseSound = WwiseEvent'Wwise_Weapons_Heavy_Missile.Play_weapon_heavy_missile_fire'
    HenchmanCastSound = WwiseEvent'Wwise_Weapons_Atlas.Play_wep_np_atlas_rocket_fire_1'
    ReleaseTime = 1.81500006
    bDynamicLoadAnimSet = FALSE
    bPlayEndCastAnim = FALSE
    Discipline = EBioCapMode.BIO_CAPMODE_TECH
    MinimumRange = {BaseValue = 100.0}
    MaximumRange = {BaseValue = 4000.0}
    ImpactRadius = {BaseValue = 400.0}
    Damage = {BaseValue = 400.0}
    Force = {BaseValue = 600.0}
    PowerName = 'MIRVBomb'
    PowerCustomActionID = 53
    AimingIgnoresObstructions = true
    Rank = 1.0
    Icon = 97
    UsesSharedCooldown = FALSE
    PowerType = EPowerType.PowerType_Projectile
}