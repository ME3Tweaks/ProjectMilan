// MILAN Weapon
// Source: TestPatch
Class SFXWeapon_SniperRifle_Turian extends SFXWeapon_SniperRifle_Base
    placeable
    config(Weapon);

// Variables
var(SFXWeapon_SniperRifle_Turian) InterpCurveFloat FOVInterpCurve;
var(SFXWeapon_SniperRifle_Turian) float ViewHeight;
var(SFXWeapon_SniperRifle_Turian) transient float CurrentInterpTime;
var(SFXWeapon_SniperRifle_Turian) float TotalInterpTime;
var(SFXWeapon_SniperRifle_Turian) float ShouldZoomTime;
var(SFXWeapon_SniperRifle_Turian) float FOVInterpRate;
var WwiseEvent LockedOnEvent;
var WwiseEvent LockedOffEvent;
var(SFXWeapon_SniperRifle_Turian) float ZoomedFOV;
var(SFXWeapon_SniperRifle_Turian) bool bLocked;
var(SFXWeapon_SniperRifle_Turian) bool bShouldAutoZoom;

// Functions
public simulated function FireAmmunition()
{
    if (Instigator.Controller != None && Instigator.Controller.IsLocalPlayerController())
    {
        bShouldAutoZoom = FALSE;
    }
    Super(SFXWeapon_NativeBase).FireAmmunition();
}
public simulated function Tick(float DeltaTime)
{
    local SFXPawn_Player Player;
    local SFXPlayerController PC;
    local float NewFOV;
    local bool LockChanged;
    
    Player = SFXPawn_Player(Instigator);
    if (Player == None)
    {
        return;
    }
    PC = SFXPlayerController(Player.Controller);
    if (PC == None || !PC.IsLocalPlayerController())
    {
        return;
    }
    CurrentInterpTime += DeltaTime;
    if (bShouldAutoZoom)
    {
        NewFOV = ZoomedFOV;
        if (!bLocked)
        {
            bLocked = TRUE;
            WeaponPlayWwiseEvent(LockedOnEvent);
            CurrentInterpTime = 0.0;
            LockChanged = TRUE;
        }
    }
    else
    {
        NewFOV = default.AimModes[0].ZoomFOV;
        if (bLocked)
        {
            CurrentInterpTime = 0.0;
            WeaponPlayWwiseEvent(LockedOffEvent);
            bLocked = FALSE;
            LockChanged = TRUE;
        }
    }
    if (CurrentInterpTime < TotalInterpTime)
    {
        Class'BioInterpolator'.static.InterpolateFloatCurve(NewFOV, FOVInterpCurve, AimModes[0].ZoomFOV, NewFOV, FClamp(CurrentInterpTime / TotalInterpTime, 0.0, 1.0));
    }
    else
    {
        Self.AimModes[0].ZoomFOV = Lerp(Self.AimModes[0].ZoomFOV, NewFOV, 1.0 - FClamp(2.71799994 ** (-FOVInterpRate * DeltaTime), 0.0, 1.0));
    }
    AimModes[0].ZoomFOV = NewFOV;
    if (LockChanged)
    {
        SetWeaponZoom(bLocked ? 10.0 : 2.0);
    }
}
public simulated function InitializeWeapon()
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
    
    Super(SFXWeapon).InitializeWeapon();
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
}
public simulated function SetRTPCPlayerPosition(EPlayerPositionRTPC NewPlayerPosition)
{
    RTPCPlayerPosition = NewPlayerPosition;
    Class'WwiseAudioComponent'.static.SetGlobalRTPCFromScript(RTPCName, float(RTPCPlayerPosition));
}
public simulated function StartChargeEffects()
{
    if (Instigator.Controller != None && Instigator.Controller.IsLocalPlayerController())
    {
        SetTimer(ShouldZoomTime, FALSE, 'ShouldZoom', );
    }
}
public simulated function StopChargeEffects()
{
    if (Instigator.Controller != None && Instigator.Controller.IsLocalPlayerController())
    {
        bShouldAutoZoom = FALSE;
        ClearTimer('ShouldZoom');
    }
}
public simulated function SetWeaponZoom(float fZoom)
{
    local SFXSFHandler_Reticle ReticleManager;
    local SFXGUIInteraction oGUI;
    local SFXPlayerController PC;
    local SFXPawn_Player Player;
    local SFXGUI_TurianSniperZoomReticle Reticle;
    
    Player = SFXPawn_Player(Instigator);
    PC = SFXPlayerController(Player.Controller);
    if (PC != None && PC.IsLocalPlayerController())
    {
        oGUI = Class'SFXGUIInteraction'.static.GetInstance();
        ReticleManager = oGUI == None ? None : oGUI.CastGetMovie(Class'SFXSFHandler_Reticle', PC, oGUI.MovieTag_Reticle);
        if (ReticleManager != None && ReticleManager.m_oCurrentWeaponReticle != None)
        {
            Reticle = SFXGUI_TurianSniperZoomReticle(ReticleManager.m_oCurrentWeaponReticle);
            if (Reticle != None)
            {
                Reticle.SetZoomValue(fZoom);
            }
        }
    }
}
public simulated function ShouldZoom()
{
    bShouldAutoZoom = TRUE;
    ClearTimer('ShouldZoom');
}

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
    Begin Template Class=ForceFeedbackWaveform Name=OutOfAmmoRumble0
    End Template
    Begin Template Class=ParticleSystemComponent Name=AmmoPowerHologram
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ParticleSystemComponent Name=AmmoPowerIconHologram
        ReplacementPrimitive = None
    End Template
    Begin Object Class=ParticleSystemComponent Name=MuzFlashPSC0
        Template = ParticleSystem'BioVFX_DLC_Wpn_SNPl_GUN01.Particles.Turian_Rifle_Muzzle' // MILAN CHANGE - Use GUN01 asset
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
    Begin Template Class=PointLightComponent Name=MuzFlashLight0 // MILAN CHANGE - Add flashlight component
    End Template
    Begin Object Class=SFXAnimSetCookSpec Name=tempAnimInfo
        AnimSet = AnimSet'BIOG_HMM_CB_A.HMM_CB_SniperAuto_AlternateSlow'
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
        SkeletalMesh = SkeletalMesh'BIOG_WPN_SNP_L_CON_GUN01.SNPl.WPN_SNPl_MDL' // MILAN CHANGE - Use GUN01 asset
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh // MILAN CHANGE - Use GUN01 assets
        SkeletalMesh = SkeletalMesh'BIOG_WPN_SNP_L_CON_GUN01.SNPl.WPN_SNPl_MDL'
        AnimTreeTemplate = AnimTree'BIOG_AnimTree_Weapon.BIOG_WPN_Main_O'
        PhysicsAsset = PhysicsAsset'BIOG_PHY_Weapons_F_CON_GUN01.PHY_WPN_SNPl'
        AnimSets = (AnimSet'BIOG_WPN_A_CON_GUN01.WPN_SNPl_Main')
        ReplacementPrimitive = None
    End Template
    FOVInterpCurve = {
                      Points = ({InVal = 0.0, OutVal = 0.0, ArriveTangent = 0.0, LeaveTangent = 0.0, InterpMode = EInterpCurveMode.CIM_CurveAuto}, 
                                {InVal = 0.330000013, OutVal = 0.100000001, ArriveTangent = 0.0, LeaveTangent = 0.0, InterpMode = EInterpCurveMode.CIM_CurveAuto}, 
                                {InVal = 0.666999996, OutVal = 0.899999976, ArriveTangent = 0.0, LeaveTangent = 0.0, InterpMode = EInterpCurveMode.CIM_CurveAuto}, 
                                {InVal = 1.0, OutVal = 1.0, ArriveTangent = 0.0, LeaveTangent = 0.0, InterpMode = EInterpCurveMode.CIM_CurveAuto}
                               ), 
                      InterpMethod = EInterpMethodType.IMT_UseFixedTangentEvalAndNewAutoTangents
                     }
    ViewHeight = 350.0
    TotalInterpTime = 1.0
    ShouldZoomTime = 0.25
    FOVInterpRate = 15.0
    LockedOnEvent = WwiseEvent'Wwise_Weapons_S_Turian_SP.Play_wep_p_turian_zoom_in_SP' // MILAN CHANGE - Use GUN01 asset
    LockedOffEvent = WwiseEvent'Wwise_Weapons_S_Turian_SP.Play_wep_p_turian_zoom_out_SP' // MILAN CHANGE - Use GUN01 asset
    ZoomedFOV = 8.0
    ActivateSniperZoomWwiseEvent = WwiseEvent'Wwise_Weapons_S_Turian_SP.Play_wep_p_turian_scope_in_SP' // MILAN CHANGE - Use GUN01 asset
    DeActivateSniperZoomWwiseEvent = WwiseEvent'Wwise_Weapons_S_Turian_SP.Play_wep_p_turian_scope_out_SP' // MILAN CHANGE - Use GUN01 asset
    SniperRifleDamagePenalty = 0.75
    GUIZoomReticleClass = Class'SFXGUI_TurianSniperZoomReticle'
    FiringShake = {
                   RotAmplitude = {X = 1100.0, Y = 200.0, Z = -1100.0}, 
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
    ReloadAnimInfo = tempAnimInfo
    PSC_OutOfAmmoEffect = OutOfAmmoEffect0
    OutOfAmmoRumble = OutOfAmmoRumble0
    WeaponFireWaveForm = ForceFeedbackWaveformBase
    EjectRumble = EjectRumble0
    PS_DefaultImpactEffect = ParticleSystem'BioVFX_C_Impacts.Generic.Particles.HeavySniper_Imp'
    ImpactScale = 2.0
    PSC_ShellCasing = ShellCasingPSC0
    PSC_ReloadVent = ReloadVent0
    PSC_MuzFlashEmitter = MuzFlashPSC0
    IconResource = GFxMovieInfo'GUI_SF_ME3_DLC_Krysae_GUN01.ME3_DLC_TurianSniper' // MILAN CHANGE - Use GUN01 asset
    FireSound = WwiseEvent'Wwise_Weapons_S_Turian_SP.Play_wep_np_turian_fire_SP' // MILAN CHANGE - Use GUN01 asset
    PlayerFireSound = WwiseEvent'Wwise_Weapons_S_Turian_SP.Play_wep_p_turian_fire_SP' // MILAN CHANGE - Use GUN01 asset
    WeaponReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_reload_sniper_heavy'
    WeaponExpandSound = WwiseEvent'Wwise_Weapons_S_Turian.Play_wep_s_turian_expand' // MILAN Note: Will have to be fixed in Audio pipeline (LE version removes this sound)
    WeaponCollapseSound = WwiseEvent'Wwise_Weapons_S_Turian.Play_wep_s_turian_collapse' // MILAN Note: Will have to be fixed in Audio pipeline (LE version removes this sound)
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    CameraSetup = CameraSetup0
	// MILAN CHANGE - Muzzle flashlight effects
	LC_MuzzleFlashLight = MuzFlashLight0
    MuzzleLightLifetime = 0.150000006
    MuzzleLightBrightness = 1.70000005
    MuzzleLightColor = {B = 255, G = 1, R = 70, A = 0}
    MuzzleLightFalloffExponent = 15.0
    MuzzleLightRadius = 600.0
    // END MILAN CHANGE
    // bNotRegularWeaponGUI = TRUE // MILAN NOTE: This is from LE version. Unsure if needed. Adding commented out in case we do.
    bScaleAnimDurationByFireRate = TRUE
    WeaponFireTypes = (EWeaponFireType.EWFT_InstantHit, EWeaponFireType.EWFT_Projectile, EWeaponFireType.EWFT_InstantHit, EWeaponFireType.EWFT_InstantHit, EWeaponFireType.EWFT_InstantHit)
    WeaponProjectiles = (None, Class'SFXProjectile_Turian')
    InstantHitMomentum = (0.0, 35.0, 1.0, 1.0) // MILAN NOTE: LE3 SP version uses 0 35 35 1 instead of 0 35 1 1. Maybe investigate if this should be used instead
    InstantHitDamageTypes = (None, Class'SFXDamageType_Turian', Class'SFXDamageType_Default', Class'SFXDamageType_Default')
    Mesh = WeaponMesh
    AIRating = 20.0
    DroppedPickupMesh = PickupMesh
    PickupFactoryMesh = PickupMesh
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
}