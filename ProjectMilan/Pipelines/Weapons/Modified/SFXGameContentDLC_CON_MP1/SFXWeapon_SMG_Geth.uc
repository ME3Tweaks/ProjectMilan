// MILAN Weapon
// Based on: MP1 class
Class SFXWeapon_SMG_Geth extends SFXWeapon_SMG_Base
    placeable
    config(Weapon);

// Variables
var Guid ChargeEffectGuid;
var Guid ChargeDownEffectGuid;
var WwiseEvent PowerUpSound1;
var WwiseEvent PowerDownSound1;
var transient float FireStartTime;
var editinline export ParticleSystemComponent SteamMuzzle;
var editinline export ParticleSystemComponent ChargeRing;
var(SFXWeapon_SMG_Geth) RvrClientEffectInterface CE_ChargeUp;
var(SFXWeapon_SMG_Geth) RvrClientEffectInterface CE_ChargeDown;
var float MinROF;
var float RampTime;
var float DamageMultiplier;
var float GetHotTime;
var float FullyChargedTime;
var bool bIsHot;

// Functions
public event simulated function WeaponStoppedFiring(byte FiringMode)
{
    Super(SFXWeapon).WeaponStoppedFiring(FiringMode);
    WeaponAnimNode.StopCustomAnim(0.200000003);
    if (bDummyFireWeapon)
    {
        bIsHot = FALSE;
        WeaponPlayWwiseEvent(PowerDownSound1);
    }
}
public simulated function ConsumeAmmo(byte FireModeNum)
{
    if (bIsHot == TRUE && GetMagazineSize() - AmmoUsedCount > 1)
    {
        AmmoPerShot = 2.0;
    }
    else
    {
        AmmoPerShot = 1.0;
    }
    Super(SFXWeapon).ConsumeAmmo(FireModeNum);
    AmmoPerShot = 1.0;
}
public simulated function FireModeUpdated(byte FiringMode, bool bViaReplication)
{
    if (bViaReplication)
    {
        if (int(FiringMode) == 2)
        {
            PlayWindUpEffects();
        }
        else
        {
            PlayWindDownEffects();
        }
    }
    Super(SFXWeapon).FireModeUpdated(FiringMode, bViaReplication);
}
public simulated function TimeWeaponFiring(byte FireModeNum)
{
    if (!IsTimerActive('RefireCheckTimer'))
    {
        SetTimer(GetFireInterval(FireModeNum), FALSE, 'RefireCheckTimer', );
    }
}
public simulated function BeginDummyFire(byte FiringMode, optional Actor AttachedTo)
{
    Super(SFXWeapon).BeginDummyFire(FiringMode);
    WeaponPlayWwiseEvent(PowerUpSound1);
}
public simulated function float GetFireModeBaseDamage()
{
    local float BaseDamage;
    
    if (bIsHot)
    {
        BaseDamage = Damage.Value * DamageMultiplier;
    }
    else if (!bIsHot)
    {
        BaseDamage = Damage.Value;
    }
    return BaseDamage;
}
public simulated function float GetRateOfFire()
{
    local float fRateOfFire;
    
    fRateOfFire = Super(SFXWeapon).GetRateOfFire();
    fRateOfFire = FClamp(Lerp(0.0, fRateOfFire, (WorldInfo.GameTimeSeconds - FireStartTime) / RampTime), MinROF, fRateOfFire);
    return fRateOfFire;
}
public simulated function DecalComponent GetWeaponSpecificDecalData(SFXPhysicalMaterialDecals DecalEffects, out float FadeTime)
{
    return None;
}
public static simulated function ParticleSystem GetWeaponSpecificImpactEffect(SFXPhysicalMaterialImpactEffects ImpactEffects)
{
    return None;
}
public simulated function WwiseEvent GetWeaponSpecificImpactSound(SFXPhysicalMaterialImpactSounds ImpactSounds)
{
    return None;
}
public simulated function InitDefaultDecalProperties()
{
    DefaultDecalProperties = new (Self) Class'DecalComponent';
    DefaultDecalProperties.Width = 0.0;
    DefaultDecalProperties.Height = 0.0;
    DefaultDecalProperties.TileX = 0.0;
    DefaultDecalProperties.DepthBias = -0.0;
    DefaultDecalProperties.bNoClip = TRUE;
    DefaultDecalProperties.SetDecalMaterial(DefaultDecalMaterial);
}
public simulated function InitializeWeapon()
{
    Super(SFXWeapon).InitializeWeapon();
    HackLoadWeaponMods();
}
public simulated function PlayNoAmmoEffects()
{
    Super(SFXWeapon).PlayNoAmmoEffects();
    SteamMuzzle.SetActive(TRUE);
    SkeletalMeshComponent(Mesh).AttachComponentToSocket(SteamMuzzle, 'Flash_1');
}
public simulated function PlayReloadEject()
{
    local RvrClientEffectTarget CETarget;
    
    CETarget.Instigator = Instigator;
    CETarget.HitBone = 'Flash_2';
    if (SFXPawn_Player(Instigator) != None)
    {
        WeaponAnimNode.StopCustomAnim(0.200000003);
        WeaponAnimNode.PlayCustomAnim('WPN_ChargeRelease', 1.0);
        ChargeDownEffectGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_ChargeDown, CETarget);
        Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_ChargeUp, ChargeEffectGuid, FALSE);
    }
    Super(SFXWeapon).PlayReloadEject();
}
public simulated function FullyCharged()
{
    WeaponAnimNode.PlayCustomAnim('WPN_ChargeHold', 1.0, 1.0, 0.0, TRUE);
}
public simulated function GunIsHot()
{
    local float IntensityScalar;
    local float GlowIntensityScalar;
    
    bIsHot = TRUE;
    if (SFXPawn_Player(Instigator) != None)
    {
        WeaponAnimNode.PlayCustomAnim('WPN_ChargeUp', 1.0);
        SetTimer(FullyChargedTime, FALSE, 'FullyCharged', );
        IntensityScalar = 10.0;
        SteamMuzzle.SetFloatParameter('Rota_Speed', IntensityScalar);
        GlowIntensityScalar = 10.0;
        SteamMuzzle.SetFloatParameter('glow', GlowIntensityScalar);
    }
}
public simulated function HackLoadWeaponMods()
{
    local int idx;
    local int Idx2;
    local int WeaponModLevel;
    local SFXModule_WeaponModManager Manager;
    local Class<SFXWeaponMod> ModClass;
    local SFXPRIMP oPRI;
    local Name WeaponClassPath;
    local Name WeaponModClassPath;
    local SFXPawn_PlayerMP Player;
    
    if (Instigator == None || Instigator.IsPlayerOwned() && (SFXPRIMP(Instigator.PlayerReplicationInfo) == None || (SFXPRIMP(Instigator.PlayerReplicationInfo).bIsReplicationValid_CharacterWeapons == FALSE && Role == ENetRole.ROLE_SimulatedProxy) && Instigator.Role == ENetRole.ROLE_SimulatedProxy))
    {
        if (!bDummyFireWeapon)
        {
            SetTimer(0.100000001, FALSE, 'HackLoadWeaponMods', );
            return;
        }
    }
    Player = SFXPawn_PlayerMP(Instigator);
    if (Player == None)
    {
        return;
    }
    oPRI = SFXPRIMP(Player.PlayerReplicationInfo);
    if (oPRI == None)
    {
        return;
    }
    for (idx = 0; idx < 2; idx++)
    {
        oPRI.GetWeapon(idx, WeaponClassPath);
        if (Caps(PathName(Class)) == Caps(string(WeaponClassPath)))
        {
            Manager = GetModule(Class'SFXModule_WeaponModManager');
            if (Manager != None)
            {
                Manager.RemoveAllMods();
                for (Idx2 = 0; Idx2 < 2; ++Idx2)
                {
                    oPRI.GetWeaponMod(idx, Idx2, WeaponModClassPath, WeaponModLevel);
                    if (WeaponModClassPath != 'None')
                    {
                        ModClass = Class'SFXWeaponMod'.static.LoadModClass(string(WeaponModClassPath));
                        if (ModClass != None)
                        {
                            Manager.AddMod(ModClass, WeaponModLevel);
                        }
                        continue;
                    }
                    break;
                }
            }
        }
    }
    Manager = GetModule(Class'SFXModule_WeaponModManager');
    if (Manager != None)
    {
        Manager.SetWeaponModHidden(FALSE);
    }
}
public simulated function PlayWindDownEffects()
{
    local RvrClientEffectTarget CETarget;
    
    if (SFXPawn_Player(Instigator) != None && Instigator.IsLocallyControlled())
    {
        WeaponPlayWwiseEvent(PowerDownSound1);
    }
    CETarget.Instigator = Instigator;
    CETarget.HitBone = 'Flash_2';
    ClearTimer('GunIsHot');
    SteamMuzzle.SetActive(FALSE);
    ChargeRing.SetActive(FALSE);
    ClearTimer('GunIsHot');
    ClearTimer('FullyCharged');
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_ChargeUp, ChargeEffectGuid, FALSE);
    ChargeDownEffectGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_ChargeDown, CETarget);
    WeaponAnimNode.StopCustomAnim(0.200000003);
    if (bIsHot)
    {
        bIsHot = FALSE;
        WeaponAnimNode.PlayCustomAnim('WPN_ChargeRelease', 1.0);
    }
}
public simulated function PlayWindUpEffects()
{
    local float IntensityScalar;
    local float GlowIntensityScalar;
    local RvrClientEffectTarget CETarget;
    
    if (SFXPawn_Player(Instigator) != None && Instigator.IsLocallyControlled())
    {
        WeaponPlayWwiseEvent(PowerUpSound1);
    }
    SetTimer(GetHotTime, FALSE, 'GunIsHot', );
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_ChargeDown, ChargeEffectGuid, FALSE);
    ChargeRing.SetActive(TRUE);
    CETarget.Instigator = Instigator;
    CETarget.HitBone = 'Flash_2';
    ChargeEffectGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_ChargeUp, CETarget);
    SkeletalMeshComponent(Mesh).AttachComponentToSocket(ChargeRing, 'Charge_1');
    IntensityScalar = 1.0;
    SteamMuzzle.SetFloatParameter('Rota_Speed', IntensityScalar);
    GlowIntensityScalar = 1.0;
    SteamMuzzle.SetFloatParameter('glow', GlowIntensityScalar);
}

// States
state WeaponFiring 
{
    // State Functions
    public simulated function RefireCheckTimer()
    {
        if (bWeaponPutDown)
        {
            bIsHot = FALSE;
            PutDownWeapon();
            return;
        }
        if (ShouldRefire())
        {
            FireAmmunition();
            SetTimer(GetFireInterval(CurrentFireMode), FALSE, 'RefireCheckTimer', );
            return;
        }
        HandleFinishedFiring();
    }
    public simulated function EndState(Name NextStateName)
    {
        Super(SFXWeapon).EndState(NextStateName);
        SetCurrentFireMode(0);
        PlayWindDownEffects();
    }
    public simulated function BeginState(Name PreviousStateName)
    {
        FireStartTime = WorldInfo.GameTimeSeconds;
        Super(SFXWeapon).BeginState(PreviousStateName);
        SetCurrentFireMode(2);
        PlayWindUpEffects();
    }
    
    // State code
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=ForceFeedbackWaveform Name=EjectRumble0
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=ForceFeedbackWaveformBase
        Samples = ({Duration = 0.150000006, LeftAmplitude = 85, RightAmplitude = 85, LeftFunction = EWaveformFunction.WF_Sin90to180, RightFunction = EWaveformFunction.WF_Sin90to180}
                  )
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=OutOfAmmoRumble0
    End Template
    Begin Template Class=ParticleSystemComponent Name=AmmoPowerHologram
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ParticleSystemComponent Name=AmmoPowerIconHologram
        ReplacementPrimitive = None
    End Template
    Begin Object Class=ParticleSystemComponent Name=ChargePSC0
        Template = ParticleSystem'BioVFX_DLC_Wpn_PSTn_GUN01.Particles.SMG_Rota_Ring'  // MILAN - Use GUN01 asset
        ReplacementPrimitive = None
    End Object
    Begin Object Class=ParticleSystemComponent Name=MuzFlashPSC0
        Template = ParticleSystem'BioVFX_DLC_Wpn_PSTn_GUN01.Particles.SMG_Muzzle'  // MILAN - Use GUN01 asset
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Template Class=ParticleSystemComponent Name=OutOfAmmoEffect0
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ParticleSystemComponent Name=ReloadVent0
        ReplacementPrimitive = None
    End Template
    Begin Object Class=ParticleSystemComponent Name=ShellCasingPSC0
        Template = ParticleSystem'BioVFX_C_Reload.Particles.Reload_VentHeat'
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Object Class=ParticleSystemComponent Name=SteamChargePSC0
        Template = ParticleSystem'BioVFX_C_Reload.Particles.Reload_VentHeat_Geth_2'
        ReplacementPrimitive = None
    End Object
    Begin Template Class=PointLightComponent Name=MuzFlashLight0  // MILAN - Use GUN01 component not in ME3
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_WeaponModManager Name=ModManager0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=PickupMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_PST_N_CON_GUN01.PSTn.WPN_PSTn_MDL'  // MILAN - GUN01 asset
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh  // MILAN - Use GUN01 assets
        SkeletalMesh = SkeletalMesh'BIOG_WPN_PST_N_CON_GUN01.PSTn.WPN_PSTn_MDL' 
        AnimTreeTemplate = AnimTree'BIOG_AnimTree_Weapon.BIOG_WPN_Main_O'
        PhysicsAsset = PhysicsAsset'BIOG_PHY_Weapons_F_CON_GUN01.PHY_WPN_PSTn'
        AnimSets = (AnimSet'BIOG_WPN_A_CON_GUN01.WPN_PSTn_Main')
        ReplacementPrimitive = None
    End Template
    PowerUpSound1 = WwiseEvent'Wwise_Weapons_S_GethSMG_SP.Play_wep_p_gethsmg_fire_start_SP'  // MILAN - GUN01 asset
    PowerDownSound1 = WwiseEvent'Wwise_Weapons_S_GethSMG_SP.Play_wep_p_gethsmg_fire_stop_SP'  // MILAN - GUN01 asset
    SteamMuzzle = SteamChargePSC0
    ChargeRing = ChargePSC0
    CE_ChargeUp = RvrClientEffectMulti'BioVFX_DLC_Wpn_PSTn_GUN01.VCFX.Ear_Whole' // MILAN - GUN01 asset
    CE_ChargeDown = RvrClientEffectMulti'BioVFX_DLC_Wpn_PSTn_GUN01.VCFX.Ear_Shut_Down_Whole'  // MILAN - GUN01 asset
    MinROF = 250.0
    RampTime = 0.75
    DamageMultiplier = 2.5
    GetHotTime = 0.75
    FullyChargedTime = 1.5
    AI_AccCone_Min = {X = 1.20000005, Y = 1.20000005}
    AI_AccCone_Max = {X = 1.60000002, Y = 1.60000002}
    ReloadDuration = {X = 1.5, Y = 1.5}
    Damage = {X = 16.1000004, Y = 21.1000004}
    MagSize = {X = 100.0, Y = 100.0}
    MaxSpareAmmo = {X = 500.0, Y = 625.0}
    MinAimError = {X = 1.25, Y = 1.25}
    MaxAimError = {X = 3.0, Y = 3.0}
    MinZoomAimError = {X = 0.100000001, Y = 0.100000001}
    MaxZoomAimError = {X = 0.649999976, Y = 0.649999976}
    RateOfFire = {X = 800.0, Y = 800.0}
    EncumbranceWeight = {X = 0.75, Y = 0.349999994}
    Recoil = {X = 0.0359999985, Y = 0.0359999985}
    ZoomRecoil = {X = 0.136000007, Y = 0.136000007}
    AccFirePenalty = {X = 19.0, Y = 19.0}
    AccFireInterpSpeed = {X = 18.0, Y = 18.0}
    ZoomAccFirePenalty = {X = 37.0, Y = 37.0}
    ZoomAccFireInterpSpeed = {X = 35.0, Y = 35.0}
    MinZoomCrosshairRange = {X = 50.0, Y = 50.0}
    MaxZoomCrosshairRange = {X = 50.0, Y = 50.0}
    StatBarAccuracy = {X = 60.0, Y = 60.0}
    StatBarDamage = {X = 16.1000004, Y = 21.1000004}
    StatBarRateOfFire = {X = 800.0, Y = 800.0}
    GUIImage = "DLC_MPImages.Weapons.smg_geth_512x256"
    NotificationImage = "DLC_MPImages.Weapons.smg_geth_256x128"
    WeaponModGripColours = ({R = 0.00999999978, G = 0.00999999978, B = 0.00999999978, A = 0.0}
                           )
    WeaponModBodyColours = ({R = 0.00999999978, G = 0.00999999978, B = 0.00999999978, A = 0.0}
                           )
    GUIZoomReticleClass = Class'SFXGUI_WeaponReticleSimple'
    FiringShake = {
                   RotAmplitude = {X = 45.0, Y = 20.0, Z = 0.0}, 
                   RotFrequency = {X = 35.0, Y = 60.0, Z = 0.0}, 
                   LocAmplitude = {X = -1.0, Y = 0.0, Z = 0.0}, 
                   LocFrequency = {X = 6.0, Y = 0.0, Z = 0.0}, 
                   TimeDuration = 0.125
                  }
    TightAimFiringShake = {
                           RotAmplitude = {X = 45.0, Y = 20.0, Z = 0.0}, 
                           RotFrequency = {X = 35.0, Y = 60.0, Z = 0.0}, 
                           LocAmplitude = {X = -1.0, Y = 0.0, Z = 0.0}, 
                           LocFrequency = {X = 6.0, Y = 0.0, Z = 0.0}, 
                           TimeDuration = 0.125
                          }
    TracerInfo = {
                  Scale3D = {X = 1.0, Y = 1.0, Z = 1.0}, 
                  StaticMesh = StaticMesh'BioVFX_C_Weapons.Tracers.Meshes.Tracer_Geth_Minigun', 
                  StandardPSTemplate = ParticleSystem'BioVFX_C_Weapons.Tracers.Particles.Tracer_Smoke_Trail', 
                  PlayerPSTemplate = ParticleSystem'BioVFX_C_Weapons.Tracers.Particles.Tracer_Smoke_Trail', 
                  AccelRate = 15000.0, 
                  Speed = 13500.0, 
                  MaxSpeed = 15000.0
                 }
    AI_BurstFireCount = {X = 10.0, Y = 15.0}
    AI_BurstFireDelay = {X = 0.649999976, Y = 2.29999995}
    ShellCasingSocketName = 'CoolDown01'
    PSC_OutOfAmmoEffect = OutOfAmmoEffect0
    OutOfAmmoRumble = OutOfAmmoRumble0
    WeaponFireWaveForm = ForceFeedbackWaveformBase
    EjectRumble = EjectRumble0
    PS_DefaultImpactEffect = ParticleSystem'BioVFX_DLC_Wpn_PSTn_GUN01.Particles.SMG_Imp'  // MILAN - Use GUN01 asset
    PSC_ShellCasing = ShellCasingPSC0
    PSC_ReloadVent = ReloadVent0
    TracerSpawnOffset = 3.0
    PSC_MuzFlashEmitter = MuzFlashPSC0

	// MILAN CHANGE - GUN01 has some extra values here we're going to use
    LC_MuzzleFlashLight = MuzFlashLight0
    MuzzleLightLifetime = 0.0500000007
    MuzzleLightBrightness = 1.39999998
    MuzzleLightColor = {B = 255, G = 200, R = 1, A = 0}
    MuzzleLightFalloffExponent = 15.0
    MuzzleLightRadius = 300.0
    // END MILAN CHANGE
    
    FlashlightFireColor = {B = 255, G = 255, R = 100, A = 0}
    FlashlightFireBrightnessIncrease = 2.5
    FlashlightFireRadiusIncrease = 0.75
    EjectShellCasingTimeRatio = 0.558000028
    LowAmmoSoundThreshold = 10.0
    RateOfFireAI = 1.0
    RecoilYawScale = 0.25
    RecoilYawFrequency = 2.5
    IconResource = GFxMovieInfo'GUI_SF_ME3_DLC_GethSMG_GUN01.ME3_DLC_GethSMG' // Use GUN01 image asset
    IconRef = 2
    PrettyName = $728037
    ShortPrettyName = $728037
    ShortDescription = $728038
    GeneralDescription = $728039
    // Milan - Original
    //FireSound = WwiseEvent'Wwise_Weapons_S_GethSMG.Play_wep_np_gethsmg_fire'
    //PlayerFireSound = WwiseEvent'Wwise_Weapons_S_GethSMG.Play_wep_p_gethsmg_fire'
    // Milan - Use GUN01 sounds
    FireSound = WwiseEvent'Wwise_Weapons_S_GethSMG_SP.Play_wep_np_gethsmg_fire_SP'
    PlayerFireSound = WwiseEvent'Wwise_Weapons_S_GethSMG_SP.Play_wep_p_gethsmg_fire_SP'
    WeaponReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_reload_pistol_normal'
    WeaponSteamReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_noammo_small_alien_sweetener'
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    AnimType = WeaponAnimType.WeaponAnimType_AutoPistol
    InstantHitMomentum = (0.0, 1.0, 25.0, 1.0)
    InstantHitDamageTypes = (None, Class'SFXDamageType_Default', Class'SFXDamageType_GethPulseRifle', Class'SFXDamageType_Default')
    Mesh = WeaponMesh
    DroppedPickupMesh = PickupMesh
    PickupFactoryMesh = PickupMesh
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
}