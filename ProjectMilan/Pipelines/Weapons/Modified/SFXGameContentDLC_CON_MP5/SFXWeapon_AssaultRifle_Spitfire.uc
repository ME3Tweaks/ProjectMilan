// MILAN Weapon
// Source: MP5
// Note: The SP version of this weapon is a heavy weapon so it's not same base class.
// This is a best guess at what it would actually look like with LE assets.
Class SFXWeapon_AssaultRifle_Spitfire extends SFXWeapon_AssaultRifle_Base
    placeable
    config(Weapon);

// Types
struct RetrieveMoveSpeedOverride 
{
    var Name CharacterClass;
    var float MovementSpeedDecrease;
};

// Variables
var config array<RetrieveMoveSpeedOverride> MovementSpeedOverrides;
var WwiseEvent PowerUpSound1;
var WwiseEvent PowerDownSound1;
var WwiseEvent NPCPowerUpSound1;
var WwiseEvent NPCPowerDownSound1;
var transient float FireStartTime;
var editinline export ParticleSystemComponent SteamMuzzle;
var config float MinROF;
var config float RampTime;
var config float IsHotDamageMultiplier;
var config float MovementSpeedDecrease;
var bool bIsHot;
var bool bSlowed;

// Functions
public simulated function Destroyed()
{
    local SFXModule_GameEffectManager GEManager;
    
    GEManager = Instigator.GetModule(Class'SFXModule_GameEffectManager');
    if (GEManager != None)
    {
        GEManager.RemoveEffectsByCategory(Name);
        bSlowed = FALSE;
    }
    Super(SFXWeapon).Destroyed();
}
public event simulated function WeaponStoppedFiring(byte FiringMode)
{
    Super(SFXWeapon).WeaponStoppedFiring(FiringMode);
    if (bDummyFireWeapon)
    {
        bIsHot = FALSE;
        if (SFXPawn_Player(Instigator) != None && Instigator.IsLocallyControlled())
        {
            WeaponPlayWwiseEvent(PowerDownSound1);
        }
        else
        {
            WeaponPlayWwiseEvent(NPCPowerDownSound1);
        }
    }
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
    if (SFXPawn_Player(Instigator) != None && Instigator.IsLocallyControlled())
    {
        WeaponPlayWwiseEvent(PowerUpSound1);
    }
    else
    {
        WeaponPlayWwiseEvent(NPCPowerUpSound1);
    }
}
public simulated function float GetFireModeBaseDamage()
{
    local float BaseDamage;
    
    if (bIsHot)
    {
        BaseDamage = Damage.Value * IsHotDamageMultiplier;
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
public function GunIsHot()
{
    bIsHot = TRUE;
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
    if (SFXPawn_Player(Instigator) != None && Instigator.IsLocallyControlled())
    {
        WeaponPlayWwiseEvent(PowerDownSound1);
    }
    else
    {
        WeaponPlayWwiseEvent(NPCPowerDownSound1);
    }
}
public simulated function PlayWindUpEffects()
{
    if (SFXPawn_Player(Instigator) != None && Instigator.IsLocallyControlled())
    {
        WeaponPlayWwiseEvent(PowerUpSound1);
    }
    else
    {
        WeaponPlayWwiseEvent(NPCPowerUpSound1);
    }
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
        local SFXPawn_Player Player;
        
        Player = SFXPawn_Player(Owner);
        if (SFXPawn_Player(Instigator) != None)
        {
            BioPlayerController(Player.Controller).m_bPermanentWalk = FALSE;
        }
        bIsHot = FALSE;
        SteamMuzzle.SetActive(FALSE);
        WeaponAnimNode.StopCustomAnim(0.200000003);
        WeaponAnimNode.PlayCustomAnim('WPN_ChargeRelease', 1.0);
        Super(SFXWeapon).EndState(NextStateName);
        PlayWindDownEffects();
    }
    public simulated function BeginState(Name PreviousStateName)
    {
        local SFXPawn_Player Player;
        
        Player = SFXPawn_Player(Owner);
        if (SFXPawn_Player(Instigator) != None)
        {
            BioPlayerController(Player.Controller).m_bPermanentWalk = TRUE;
        }
        FireStartTime = WorldInfo.GameTimeSeconds;
        Super(SFXWeapon).BeginState(PreviousStateName);
        WeaponAnimNode.PlayCustomAnim('WPN_ChargeUp', 1.0);
        WeaponAnimNode.PlayCustomAnim('WPN_ChargeHold', 1.0, 1.0, 0.0, TRUE);
        SetTimer(2.0, FALSE, 'GunIsHot', );
        PlayWindUpEffects();
    }
    
    // State code
    stop;
};
simulated state Inactive 
{
    // State Functions
    public simulated function BeginState(Name PreviousStateName)
    {
        local SFXModule_GameEffectManager GEManager;
        
        GEManager = Instigator.GetModule(Class'SFXModule_GameEffectManager');
        if (GEManager != None)
        {
            GEManager.RemoveEffectsByCategory(Name);
            bSlowed = FALSE;
        }
        Super(SFXWeapon).BeginState(PreviousStateName);
    }
    
    // State code
    stop;
};
simulated state Active 
{
    // State Functions
    public simulated function BeginState(Name PreviousStateName)
    {
        local SFXModule_GameEffectManager Manager;
        local SFXPawn_Player Player;
        local int idx;
        local float fMoveSpeedDecrease;
        
        Player = SFXPawn_Player(Owner);
        Manager = Player.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None && bSlowed == FALSE)
        {
            fMoveSpeedDecrease = MovementSpeedDecrease;
            bSlowed = TRUE;
            if (Player.PlayerClass != None)
            {
                for (idx = 0; idx < MovementSpeedOverrides.Length; idx++)
                {
                    if (Player.PlayerClass.IsA(MovementSpeedOverrides[idx].CharacterClass))
                    {
                        fMoveSpeedDecrease = MovementSpeedOverrides[idx].MovementSpeedDecrease;
                        break;
                    }
                }
            }
            if (fMoveSpeedDecrease < float(0))
            {
                Manager.CreateAndApplyEffect(Class'SFXGameEffect_MovementSpeedBonus', Name, 0.0, 2, fMoveSpeedDecrease, Player.Controller);
            }
        }
        Super(SFXWeapon).BeginState(PreviousStateName);
    }
    
    // State code
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=ForceFeedbackWaveform Name=EjectRumble0
        Samples = ({Duration = 0.150000006, LeftAmplitude = 50, RightAmplitude = 50, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Constant}, 
                   {Duration = 0.579999983, LeftAmplitude = 0, RightAmplitude = 0, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Constant}, 
                   {Duration = 0.150000006, LeftAmplitude = 50, RightAmplitude = 50, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Constant}
                  )
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
    Begin Object Class=ParticleSystemComponent Name=MuzFlashPSC0
        Template = ParticleSystem'BioVFX_C_Wpn_Spitfire.Particles.Spitfire_Minigun_Muzzle'
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
        Template = ParticleSystem'BioVFX_C_Reload.Particles.Reload_VentHeat_Geth_2'
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Object Class=ParticleSystemComponent Name=SteamChargePSC0
        Template = ParticleSystem'BioVFX_C_Reload.Particles.Reload_VentHeat_Geth_2'
        ReplacementPrimitive = None
    End Object
    Begin Template Class=PointLightComponent Name=MuzFlashLight0 // MILAN CHANGE - Add muzzle component
    End Template
    Begin Object Class=SFXAnimSetCookSpec Name=tempAnimInfo
        AnimSet = AnimSet'BIOG_HMM_CB_A.HMM_CB_RifleAuto_SlowAlternate'
    End Object
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_WeaponModManager Name=ModManager0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=PickupMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_HVY_R.HVYj.WPN_HVYj_MDL' // MILAN CHANGE - Use EXPPack_003 asset
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_HVY_R.HVYj.WPN_HVYj_MDL' // MILAN CHANGE - Use EXPPack_003 assets
        AnimTreeTemplate = AnimTree'BIOG_AnimTree_Weapon.BIOG_WPN_Main_O'
        PhysicsAsset = PhysicsAsset'BIOG_PHY_Weapons_F.PHY_WPN_HVYj'
        AnimSets = (AnimSet'BIOG_WPN_A.WPN_HVYj_Main')
        ReplacementPrimitive = None
    End Template
    MovementSpeedOverrides = ({CharacterClass = 'SFXCharacterClassMP_Soldier_GethDestroyer', MovementSpeedDecrease = 0.0}, 
                              {CharacterClass = 'SFXCharacterClassMP_Sentinel_KroganWarlord', MovementSpeedDecrease = 0.0}, 
                              {CharacterClass = 'SFXCharacterClassMP_Soldier_Krogan', MovementSpeedDecrease = 0.0}, 
                              {CharacterClass = 'SFXCharacterClassMP_Vanguard_Krogan', MovementSpeedDecrease = 0.0}, 
                              {CharacterClass = 'SFXCharacterClassMP_Soldier_N7', MovementSpeedDecrease = -0.25}, 
                              {CharacterClass = 'SFXCharacterClassMP_Adept_Krogan', MovementSpeedDecrease = 0.0}, 
                              {CharacterClass = 'SFXCharacterClassMP_N7Infiltrator_Turian', MovementSpeedDecrease = -0.25}, 
                              {CharacterClass = 'SFXCharacterClassMP_N7Soldier_Turian', MovementSpeedDecrease = -0.25}, 
                              {CharacterClass = 'SFXCharacterClassMP_Soldier_Turian', MovementSpeedDecrease = -0.25}, 
                              {CharacterClass = 'SFXCharacterClassMP_Sentinel_Turian', MovementSpeedDecrease = -0.25}, 
                              {CharacterClass = 'SFXCharacterClassMP_Vanguard_Batarian', MovementSpeedDecrease = -0.25}, 
                              {CharacterClass = 'SFXCharacterClassMP_Engineer_Turian', MovementSpeedDecrease = -0.25}, 
                              {CharacterClass = 'SFXCharacterClassMP_Adept_Batarian', MovementSpeedDecrease = -0.25}, 
                              {CharacterClass = 'SFXCharacterClassMP_Soldier_Batarian', MovementSpeedDecrease = -0.25}, 
                              {CharacterClass = 'SFXCharacterClassMP_Sentinel_Batarian', MovementSpeedDecrease = -0.25}
                             )
    PowerUpSound1 = WwiseEvent'Wwise_Weapons_NP_MP5_Spitfire.Play_wep_p_spitfire_MP5_fire_start' // MILAN NOTE: Using OT banks. Will need to have these fixed via Audio pipeline
    PowerDownSound1 = WwiseEvent'Wwise_Weapons_NP_MP5_Spitfire.Play_wep_p_spitfire_MP5_fire_stop'
    NPCPowerUpSound1 = WwiseEvent'Wwise_Weapons_NP_MP5_Spitfire.Play_wep_MP5_np_spitfire_fire_start'
    NPCPowerDownSound1 = WwiseEvent'Wwise_Weapons_NP_MP5_Spitfire.Play_wep_MP5_np_spitfire_fire_stop'
    SteamMuzzle = SteamChargePSC0
    MinROF = 250.0
    RampTime = 0.75
    IsHotDamageMultiplier = 1.0
    MovementSpeedDecrease = -0.349999994
    AI_AccCone_Min = {X = 1.5, Y = 1.5}
    AI_AccCone_Max = {X = 1.5, Y = 1.5}
    ReloadDuration = {X = 2.9000001, Y = 2.9000001}
    Damage = {X = 53.7999992, Y = 67.3000031}
    MagSize = {X = 220.0, Y = 220.0}
    MaxSpareAmmo = {X = 600.0, Y = 750.0}
    MinAimError = {X = 1.20000005, Y = 1.20000005}
    MaxAimError = {X = 2.75, Y = 2.75}
    MinZoomAimError = {X = 0.5, Y = 0.5}
    MaxZoomAimError = {X = 1.0, Y = 1.0}
    RateOfFire = {X = 650.0, Y = 650.0}
    EncumbranceWeight = {X = 3.0, Y = 2.5}
    Recoil = {X = 0.100000001, Y = 0.100000001}
    ZoomRecoil = {X = 0.150000006, Y = 0.150000006}
    AccFirePenalty = {X = 12.6999998, Y = 12.6999998}
    AccFireInterpSpeed = {X = 12.0, Y = 12.0}
    ZoomAccFirePenalty = {X = 37.0, Y = 37.0}
    ZoomAccFireInterpSpeed = {X = 35.0, Y = 35.0}
    MinZoomCrosshairRange = {X = 25.0, Y = 25.0}
    MaxZoomCrosshairRange = {X = 40.0, Y = 40.0}
    StatBarDamage = {X = 53.7999992, Y = 67.3000031}
    StatBarRateOfFire = {X = 800.0, Y = 800.0}
    GUIImage = "GUI_Codex_Weapons_Images.Weapons.hvy_spitfire_512x256" // MILAN CHANGE - Use EXPPack_003 asset
    NotificationImage = "GUI_Icons.Weapons.hvy_spitfire_256x128" // MILAN CHANGE - Use EXPPack_003 asset
    GUIZoomReticleClass = Class'SFXGUI_WeaponReticleSimple'
    FiringShake = {
                   RotAmplitude = {X = 85.0, Y = 40.0, Z = 0.0}, 
                   RotFrequency = {X = 65.0, Y = 90.0, Z = 0.0}, 
                   LocAmplitude = {X = -1.5, Y = 0.0, Z = 0.0}, 
                   LocFrequency = {X = 12.0, Y = 0.0, Z = 0.0}, 
                   TimeDuration = 0.25
                  }
    TightAimFiringShake = {
                           RotAmplitude = {X = 85.0, Y = 40.0, Z = 0.0}, 
                           RotFrequency = {X = 65.0, Y = 90.0, Z = 0.0}, 
                           LocAmplitude = {X = -1.5, Y = 0.0, Z = 0.0}, 
                           LocFrequency = {X = 12.0, Y = 0.0, Z = 0.0}, 
                           TimeDuration = 0.25
                          }
    TracerInfo = {
                  Scale3D = {X = 2.0, Y = 2.0, Z = 2.0}, 
                  StaticMesh = StaticMesh'BioVFX_C_Weapons.Tracers.Meshes.Tracer_Geth_Minigun', 
                  StandardPSTemplate = ParticleSystem'BioVFX_C_Wpn_Spitfire.Particles.Spitfire_Smoke_Trail_Enemies', 
                  PlayerPSTemplate = ParticleSystem'BioVFX_C_Wpn_Spitfire.Particles.Spitfire_Smoke_Trail', 
                  AccelRate = 15000.0, 
                  Speed = 13500.0, 
                  MaxSpeed = 15000.0
                 }
    AI_BurstFireCount = {X = 30.0, Y = 50.0}
    AI_BurstFireDelay = {X = 1.25, Y = 2.25}
    ShellCasingSocketName = 'CoolDown01'
    ReloadAnimInfo = tempAnimInfo
    PSC_OutOfAmmoEffect = OutOfAmmoEffect0
    OutOfAmmoRumble = OutOfAmmoRumble0
    WeaponFireWaveForm = ForceFeedbackWaveformBase
    EjectRumble = EjectRumble0
    ImpactRelevanceDistance = 100000.0
    // PS_DefaultImpactEffect = ParticleSystem'BioVFX_C_Impacts.Generic.Particles.Generic_Imp_Gth' // MILAN NOTE: MP5 version
    PS_DefaultImpactEffect = ParticleSystem'BioVFX_C_Wpn_Spitfire.Particles.SpitFire_Impact' // MILAN CHANGE - Use EXPPack_003 version
    PSC_ShellCasing = ShellCasingPSC0
    PSC_ReloadVent = ReloadVent0
    PSC_MuzFlashEmitter = MuzFlashPSC0
    EjectShellCasingTimeRatio = 0.460000008
    // MILAN CHANGE - Use muzzle flashlight component and properties
    LC_MuzzleFlashLight = MuzFlashLight0
    MuzzleLightLifetime = 0.0500000007
    MuzzleLightBrightness = 0.300000012
    MuzzleLightColor = {B = 255, G = 200, R = 1, A = 0}
    MuzzleLightFalloffExponent = 15.0
    MuzzleLightRadius = 600.0
    // END MILAN CHANGE
    LowAmmoSoundThreshold = 20.0
    SteamSoundThreshold = 1.0
    NoAmmoFireSoundDelay = 0.5
    RateOfFireAI = 1.0
    RecoilInterpSpeed = 0.0
    RecoilYawScale = 0.0250000004
    RecoilYawFrequency = 0.0250000004
    TraceRange = 100000.0
    IconRef = 41
    PrettyName = $814438
    ShortPrettyName = $814438
    ShortDescription = $814604
    GeneralDescription = $814439
    DefaultImpactSound = WwiseEvent'Wwise_Weapons_S_Spitfire.Play_wep_s_spitfire_impact'
    FireSound = WwiseEvent'Wwise_Weapons_NP_Spitfire.Play_wep_np_spitfire_fire'
    PlayerFireSound = WwiseEvent'Wwise_Weapons_NP_MP5_Spitfire.Play_wep_p_spitfire_MP5_fire'
    FireNoAmmoSound = WwiseEvent'Wwise_Weapons_Geth.Play_weapon_dryfire_geth'
    WeaponReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_reload_assault_heavy'
    WeaponSteamReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_noammo_large_alien_sweetener'
    WeaponExpandSound = WwiseEvent'Wwise_Generic_Gameplay.Play_foley_weapon_assault_expand'
    WeaponCollapseSound = WwiseEvent'Wwise_Generic_Gameplay.Play_foley_weapon_assault_collapse'
    SteamReloadNotifySound = WwiseEvent'Wwise_Weapon_Flamethrower.play_weapon_flamethrower_steam_release'
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    bLoopingFlashEmitter = TRUE
    bNotRegularWeaponGUI = TRUE
    bCanBlindUp = FALSE
    InstantHitMomentum = (0.0, 1.0, 50.0, 1.0)
    InstantHitDamageTypes = (None, Class'SFXDamageType_Default', Class'SFXDamageType_Spitfire', Class'SFXDamageType_Default')
    Mesh = WeaponMesh
    DroppedPickupMesh = PickupMesh
    PickupFactoryMesh = PickupMesh
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
}