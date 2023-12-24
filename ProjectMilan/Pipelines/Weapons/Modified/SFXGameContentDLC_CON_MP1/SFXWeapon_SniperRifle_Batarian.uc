// MILAN Weapon
// Based on: MP1 class
Class SFXWeapon_SniperRifle_Batarian extends SFXWeapon_SniperRifle_Base
    placeable
    config(Weapon);

// Variables
var Guid ChargeEffectGuid;
var WwiseEvent ShellSound;
var(SFXWeapon_SniperRifle_Batarian) config float KishockDamageMultiplier;
var(SFXWeapon_SniperRifle_Batarian) config float KishockRecoilMultiplier;
var(SFXWeapon_SniperRifle_Batarian) WwiseEvent ChargePlayerFireSound;
var(SFXWeapon_SniperRifle_Batarian) WwiseEvent ChargeFireSound;
var(SFXWeapon_SniperRifle_Batarian) editinline export ParticleSystemComponent SmokeEffect;
var(SFXWeapon_SniperRifle_Batarian) RvrClientEffectInterface CE_ChargeUp;
var(SFXWeapon_SniperRifle_Batarian) ForceFeedbackWaveform ChargeRumble;
var editinline export ParticleSystemComponent PSC_Harpoon;

// Functions
public simulated function float GetWeaponRecoil()
{
    local float RecoilMultiplier;
    
    RecoilMultiplier = Super(SFXWeapon).GetWeaponRecoil();
    if (ChargeAmount >= float(1))
    {
        RecoilMultiplier = Recoil.Value * KishockRecoilMultiplier;
    }
    return RecoilMultiplier;
}
public simulated function InitializeWeapon()
{
    Super(SFXWeapon).InitializeWeapon();
    HackLoadWeaponMods();
}
public simulated function PlayOwnedFireEffects(byte FireModeNum, Vector HitLocation)
{
    if ((bForceSpawnTracer || ShouldSpawnTracerFX()) && IsZero(HitLocation) == FALSE)
    {
        if (Instigator != None)
        {
            SpawnTracerEffect(HitLocation, VSize(HitLocation - Instigator.location));
        }
        else
        {
            SpawnTracerEffect(HitLocation, VSize(HitLocation - GetMuzzleLoc()));
        }
    }
    if (WeaponPowerFireSound != None)
    {
        WeaponPlayWwiseEvent(WeaponPowerFireSound, 1.0);
    }
    if (Instigator != None)
    {
        if (Instigator.IsHumanControlled() && Instigator.IsLocallyControlled())
        {
            SetWeaponRecoil(GetWeaponRecoil() * 182.044449);
            if (ChargePlayerFireSound != None && PlayerFireSound != None)
            {
                if (ChargeAmount >= float(1))
                {
                    WeaponPlayWwiseEvent(ChargePlayerFireSound, WeaponLoudness, vect(0.0, 0.0, 0.0), 'NoiseType_WeaponFire');
                }
                else
                {
                    WeaponPlayWwiseEvent(PlayerFireSound, WeaponLoudness, vect(0.0, 0.0, 0.0), 'NoiseType_WeaponFire');
                }
            }
        }
        else if (ChargeFireSound != None && FireSound != None)
        {
            if (ChargeAmount >= float(1))
            {
                WeaponPlayWwiseEvent(ChargeFireSound, WeaponLoudness, vect(0.0, 0.0, 0.0), 'NoiseType_WeaponFire');
            }
            else
            {
                WeaponPlayWwiseEvent(FireSound, WeaponLoudness, vect(0.0, 0.0, 0.0), 'NoiseType_WeaponFire');
            }
        }
    }
}
public simulated function PlayReloadEject()
{
    if (SFXPawn_PlayerParty(Instigator) != None)
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_ChargeUp, ChargeEffectGuid, FALSE);
    }
    Super(SFXWeapon).PlayReloadEject();
}
public simulated function StartChargeEffects()
{
    local BioPlayerController PC;
    
    PC = BioPlayerController(Instigator.Controller);
    if (SFXPawn_Player(Instigator) != None)
    {
        ChargeEffectGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().Start(CE_ChargeUp, Instigator);
        PC.ClientPlayForceFeedbackWaveform(ChargeRumble);
    }
    Super(SFXWeapon).StartChargeEffects();
}
public simulated function StopChargeEffects()
{
    local BioPlayerController PC;
    
    PC = BioPlayerController(Instigator.Controller);
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_ChargeUp, ChargeEffectGuid, FALSE);
    PC.ClientStopForceFeedbackWaveform(ChargeRumble);
    Super(SFXWeapon).StopChargeEffects();
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

// States
state WeaponFiring 
{
    // State Functions
    public simulated function BeginState(Name PreviousStateName);
    
    
    // State code
Begin:
    WeaponPlayWwiseEvent(ShellSound);
    FireAmmunition();
    TimeWeaponFiring(CurrentFireMode);
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=ForceFeedbackWaveform Name=EjectRumble0
        Samples = ({Duration = 0.150000006, LeftAmplitude = 50, RightAmplitude = 50, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Constant}, 
                   {Duration = 0.25, LeftAmplitude = 0, RightAmplitude = 0, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Constant}, 
                   {Duration = 0.25, LeftAmplitude = 50, RightAmplitude = 50, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Constant}
                  )
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=ForceFeedbackWaveformBase
        Samples = ({Duration = 0.649999976, LeftAmplitude = 100, RightAmplitude = 100, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Constant}
                  )
    End Template
    Begin Object Class=ForceFeedbackWaveform Name=ForceFeedbackWaveformBaseCharge
        Samples = ({Duration = 2.0, LeftAmplitude = 75, RightAmplitude = 75, LeftFunction = EWaveformFunction.WF_LinearIncreasing, RightFunction = EWaveformFunction.WF_LinearIncreasing}, 
                   {Duration = 100.0, LeftAmplitude = 75, RightAmplitude = 75, LeftFunction = EWaveformFunction.WF_Noise, RightFunction = EWaveformFunction.WF_Noise}
                  )
        bIsLooping = TRUE
    End Object
    Begin Template Class=ForceFeedbackWaveform Name=OutOfAmmoRumble0
    End Template
    Begin Template Class=ParticleSystemComponent Name=AmmoPowerHologram
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ParticleSystemComponent Name=AmmoPowerIconHologram
        ReplacementPrimitive = None
    End Template
    Begin Object Class=ParticleSystemComponent Name=Harpoon
        Template = ParticleSystem'BioVFX_DLC_GUN02_Kishock.Particles.Batarian_Proj_Head' // MILAN - Change to new package and object path
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Object Class=ParticleSystemComponent Name=MuzFlashPSC0
        Template = ParticleSystem'BioVFX_DLC_GUN02_Kishock.Particles.Batarian_Muzzle' // MILAN - Change to new package and object path
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
        Template = ParticleSystem'BioVFX_C_Reload.Particles.Reload_HeatSinkEject'
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Template Class=SFXCameraSetup Name=CameraSetup0
        Begin Template Class=SFXCameraMode_Combat Name=Aimback0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=BlindLeftCrouch0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=BlindLeftStand0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=BlindRightCrouch0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=BlindRightStand0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=CombatCam0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=DefaultCrouch0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=DefaultStand0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PeekLeftCrouch0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PeekLeftStand0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PeekRightCrouch0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PeekRightStand0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PowerCover0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PowerCoverMidLeft0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PowerCoverMidRight0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PowerCoverStdLeft0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PowerCoverStdRight0
        End Template
        Begin Template Class=SFXCameraMode_CombatStorm Name=CombatStormCam0
        End Template
        Begin Template Class=SFXCameraMode_EnterCover Name=EnterCoverCam0
        End Template
        Begin Template Class=SFXCameraMode_Explore Name=ExploreCam0
        End Template
        Begin Template Class=SFXCameraMode_ExploreStorm Name=ExploreStormCam0
        End Template
        Begin Template Class=SFXCameraMode_HipAimCover Name=BlindUp0
        End Template
        Begin Template Class=SFXCameraMode_HitReaction Name=HitReact0
        End Template
        Begin Template Class=SFXCameraMode_LadderDown Name=LadderDown0
        End Template
        Begin Template Class=SFXCameraMode_LadderUp Name=LadderUp0
        End Template
        Begin Template Class=SFXCameraMode_Melee Name=MeleeCam0
        End Template
        Begin Template Class=SFXCameraMode_Roll Name=RollCam0
        End Template
        Begin Template Class=SFXCameraMode_SplitScreenCombat Name=SSCombatCam0
        End Template
        Begin Template Class=SFXCameraTransition_ZoomSnap Name=ZoomSnapTransition0
        End Template
        CombatCam = CombatCam0
        RollCam = RollCam0
        ExploreCam = ExploreCam0
        CombatStormCam = CombatStormCam0
        ExploreStormCam = ExploreStormCam0
        SSCombatCam = SSCombatCam0
        EnterCoverCam = EnterCoverCam0
        MeleeCam = MeleeCam0
        LadderUp = LadderUp0
        LadderDown = LadderDown0
        HitReact = HitReact0
        ZoomSnapTransition = ZoomSnapTransition0
        DefaultCrouch = DefaultCrouch0
        DefaultStand = DefaultStand0
        PeekLeftCrouch = PeekLeftCrouch0
        PeekLeftStand = PeekLeftStand0
        PeekRightCrouch = PeekRightCrouch0
        PeekRightStand = PeekRightStand0
        DefaultAimback = Aimback0
        BlindLeftCrouch = BlindLeftCrouch0
        BlindLeftStand = BlindLeftStand0
        BlindRightCrouch = BlindRightCrouch0
        BlindRightStand = BlindRightStand0
        BlindUp = BlindUp0
        PowerCoverPopup = PowerCover0
        PowerCoverMidLeanLeft = PowerCoverMidLeft0
        PowerCoverMidLeanRight = PowerCoverMidRight0
        PowerCoverStdLeanLeft = PowerCoverStdLeft0
        PowerCoverStdLeanRight = PowerCoverStdRight0
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_WeaponModManager Name=ModManager0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=PickupMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_SNP_K_CON_GUN02.WPN_SNPk_MDL' // MILAN - MP1 to GUN02
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_SNP_K_CON_GUN02.WPN_SNPk_MDL' // MILAN - MP1 to GUN02
        AnimTreeTemplate = AnimTree'biog_animtree_weapon.BIOG_WPN_Main_O'
        PhysicsAsset = PhysicsAsset'BIOG_PHY_Weapons_F_CON_GUN02.PHY_WPN_SNPk' // MILAN - MP1 to GUN02
        AnimSets = (AnimSet'BIOG_WPN_A_CON_GUN02.WPN_SNPk_Main') // MILAN - MP1 to GUN02
        ReplacementPrimitive = None
    End Template
    KishockDamageMultiplier = 1.5
    KishockRecoilMultiplier = 1.5
    ChargePlayerFireSound = WwiseEvent'Wwise_Weapons_S_Batarian.Play_wep_p_batarian_fire_high'
    ChargeFireSound = WwiseEvent'Wwise_Weapons_S_Batarian.Play_wep_np_batarian_fire_high'
    ChargeRumble = ForceFeedbackWaveformBaseCharge
    PSC_Harpoon = Harpoon
    ActivateSniperZoomWwiseEvent = WwiseEvent'Wwise_Weapons_S_Batarian.Play_wep_p_batarian_scope_in'
    DeActivateSniperZoomWwiseEvent = WwiseEvent'Wwise_Weapons_S_Batarian.Play_wep_p_batarian_scope_out'
    SniperRifleDamagePenalty = 1.0
    AI_AccCone_Min = {X = 1.04999995, Y = 1.04999995}
    AI_AccCone_Max = {X = 1.04999995, Y = 1.04999995}
    ReloadDuration = {X = 1.79999995, Y = 1.79999995}
    Damage = {X = 645.400024, Y = 806.799988}
    MaxSpareAmmo = {X = 15.0, Y = 25.0}
    MinAimError = {X = 1.60000002, Y = 1.60000002}
    MaxAimError = {X = 3.0999999, Y = 3.0999999}
    RateOfFire = {X = 70.0, Y = 70.0}
    EncumbranceWeight = {X = 2.0, Y = 1.39999998}
    Recoil = {X = 0.0, Y = 0.0}
    ZoomRecoil = {X = 3.0, Y = 3.0}
    AccFirePenalty = {X = 0.5, Y = 0.5}
    AccFireInterpSpeed = {X = 8.0, Y = 8.0}
    StatBarAccuracy = {X = 75.0, Y = 75.0}
    StatBarDamage = {X = 968.099976, Y = 1210.19995}
    StatBarRateOfFire = {X = 20.0, Y = 20.0}
    AimModes = ({ScopeResource = 'None', ZoomFOV = 30.0, FrictionMultiplier = 0.0, AdhesionMultiplier = 0.5, bScoped = TRUE}
               )
    GUIImage = "DLC_MPImages.Weapons.snp_batarian_512x256"
    NotificationImage = "DLC_MPImages.Weapons.snp_batarian_256x128"
    ZoomSnapList = ({OuterSnapAngle = 0.0, InnerSnapAngle = 0.0, SnapOffsetMag = 0.0, AimNode = EAimNodes.AimNode_Head}
                   )
    WeaponModBodyColours = ({R = 0.0399999991, G = 0.0399999991, B = 0.0399999991, A = 0.0}
                           )
    GUIZoomReticleClass = Class'SFXGUI_BatarianSniperReticle_GUN02' // MILAN - Change renamed GUI asset
    FiringShake = {
                   RotAmplitude = {X = 110.0, Y = 20.0, Z = -110.0}, 
                   RotFrequency = {X = 45.0, Y = 25.0, Z = 45.0}, 
                   LocAmplitude = {X = 25.0, Y = 0.0, Z = 0.0}, 
                   LocFrequency = {X = 25.0, Y = 0.0, Z = 0.0}, 
                   TimeDuration = 0.319999993
                  }
    TightAimFiringShake = {
                           RotAmplitude = {X = 145.0, Y = 65.0, Z = 105.0}, 
                           RotFrequency = {X = 100.0, Y = 50.0, Z = 50.0}, 
                           LocAmplitude = {X = 4.0, Y = 0.0, Z = 0.0}, 
                           TimeDuration = 0.300000012
                          }
    TracerInfo = {
                  Scale3D = {X = 2.5, Y = 1.0, Z = 1.0}, 
                  StaticMesh = StaticMesh'BioVFX_C_Weapons.Tracers.Meshes.Tracer_Cannon_Mesh', 
                  StandardPSTemplate = ParticleSystem'BioVFX_C_Weapons.Tracers.Particles.Tracer_Smoke_Trail_Sniper', 
                  PlayerPSTemplate = ParticleSystem'BioVFX_C_Weapons.Tracers.Particles.Tracer_Smoke_Trail_Sniper', 
                  AccelRate = 15000.0, 
                  Speed = 18000.0, 
                  MaxSpeed = 22000.0
                 }
    MuzzleIdlePosition = {X = 98.0, Y = 8.0, Z = 33.0}
    AI_BurstFireCount = {X = 1.0, Y = 1.0}
    AI_BurstFireDelay = {X = 0.25, Y = 0.349999994}
    PSC_OutOfAmmoEffect = OutOfAmmoEffect0
    OutOfAmmoRumble = OutOfAmmoRumble0
    WeaponFireWaveForm = ForceFeedbackWaveformBase
    EjectRumble = EjectRumble0
    PS_DefaultImpactEffect = ParticleSystem'BioVFX_C_Impacts.Generic.Particles.HeavySniper_Imp'
    ImpactScale = 2.0
    PSC_ShellCasing = ShellCasingPSC0
    PSC_ReloadVent = ReloadVent0
    PSC_MuzFlashEmitter = MuzFlashPSC0
    EjectShellCasingTimeRatio = 0.407999992
    NoAmmoFireSoundDelay = 1.0
    RateOfFireAI = 1.0
    RecoilInterpSpeed = 40.0
    RecoilZoomFadeSpeed = 3.0
    RecoilYawScale = 0.600000024
    IconResource = GFxMovieInfo'GUI_SF_ME3_DLC_Gun02.ME3_DLC_Batarian_Gun02' // MILAN - Change to GUN02 asset (it's the exact same)
    PrettyName = $728034
    ShortPrettyName = $728034
    ShortDescription = $728035
    GeneralDescription = $728036
    FireSound = WwiseEvent'Wwise_Weapons_S_Batarian.Play_wep_np_batarian_fire'
    PlayerFireSound = WwiseEvent'Wwise_Weapons_S_Batarian.Play_wep_p_batarian_fire'
    FireNoAmmoSound = WwiseEvent'Wwise_Weapons_Standard_LowAmmo.Play_weapon_dryfire_shotguns'
    WeaponWhipSoundLeft = WwiseEvent'Wwise_Weapons_S_Batarian.Play_wep_s_batarian_whiz_by'
    WeaponWhipSoundRight = WwiseEvent'Wwise_Weapons_S_Batarian.Play_wep_s_batarian_whiz_by'
    WeaponReloadSound = WwiseEvent'Wwise_Weapons_S_Batarian.Play_wep_s_batarian_reload'
    WeaponExpandSound = WwiseEvent'Wwise_Weapons_S_Batarian.Play_wep_s_batarian_expand'
    WeaponCollapseSound = WwiseEvent'Wwise_Weapons_S_Batarian.Play_wep_s_batarian_collapse'
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    CameraSetup = CameraSetup0
    PowerUpSound = WwiseEvent'Wwise_Weapons_S_Batarian.Play_wep_p_batarian_charge_start'
    PowerDownSound = WwiseEvent'Wwise_Weapons_S_Batarian.Play_wep_p_batarian_charge_stop'
    MaxChargeTime = 1.5
    bNotRegularWeaponGUI = TRUE
    bCanBlindUp = FALSE
    WeaponFireTypes = (EWeaponFireType.EWFT_InstantHit, EWeaponFireType.EWFT_Projectile, EWeaponFireType.EWFT_Projectile, EWeaponFireType.EWFT_InstantHit, EWeaponFireType.EWFT_InstantHit)
    WeaponProjectiles = (None, Class'SFXProjectile_BatarianSniperRound', Class'SFXProjectile_BatarianSniperRound') // MILAN NOTE- Use ME3 version as it has headshot changes
    InstantHitMomentum = (0.0, 100.0, 100.0, 1.0)
    InstantHitDamageTypes = (None, Class'SFXDamageType_Kishock', Class'SFXDamageType_Kishock', Class'SFXDamageType_Default')
    Mesh = WeaponMesh
    AIRating = 20.0
    DroppedPickupMesh = PickupMesh
    PickupFactoryMesh = PickupMesh
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
}