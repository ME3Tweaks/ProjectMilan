// MILAN Weapon
// Source: MP5
Class SFXWeapon_AssaultRifle_Lancer_MP extends SFXWeapon_AssaultRifle_Base
    placeable
    config(Weapon);

// Variables
var config float RechargeRatePerSecond;
var config float PartialRechargeDelay;
var config float FullRechargeDelay;
var float AccumulatedAmmo;
var transient int CollectorAmmoUsedCount;
var RvrClientEffectInterface CE_HeatVent;
var RvrClientEffectInterface CE_SteamVent;
var float SteamDelay;
var float HeatDelay;
var WwiseEvent WeaponReloadRechargeSound;
var transient float ClientDoReloadTriggerReplicationTime;
var transient repnotify int ClientDoReloadTrigger;
var float RechargeSoundDelay;
var bool bCanPlayRechargeSound;

// Functions
public event simulated function ReplicatedEvent(Name VarName)
{
    if (VarName == 'ClientDoReloadTrigger')
    {
        StopMuzzleFlashEffect();
        Super(Weapon).SendToFiringState(4);
    }
    Super(SFXWeapon).ReplicatedEvent(VarName);
}
public simulated function Tick(float DeltaTime)
{
    Super(Actor).Tick(DeltaTime);
    if (CollectorAmmoUsedCount == GetMagazineSize())
    {
        bWeaponCanBeReloaded = TRUE;
    }
    else if (WorldInfo.GameTimeSeconds - LastFireTime >= PartialRechargeDelay)
    {
        bWeaponCanBeReloaded = FALSE;
        RechargeAmmo(DeltaTime);
    }
}
public simulated function ConsumeAmmo(byte FireModeNum)
{
    ConsumeAmmoCollector(FireModeNum);
    AmmoPerShot = 1.0;
}
public simulated function FireModeUpdated(byte FiringMode, bool bViaReplication)
{
    if (int(FiringMode) == 4)
    {
        return;
    }
    Super(SFXWeapon).FireModeUpdated(FiringMode, bViaReplication);
}
public simulated function bool HasAmmo(byte FireModeNum, optional int Amount)
{
    local int MagazineSize;
    
    if (int(FireModeNum) == 4)
    {
        return TRUE;
    }
    if (!Instigator.IsHumanControlled())
    {
        return TRUE;
    }
    if (!Instigator.IsLocallyControlled())
    {
        return TRUE;
    }
    if (float(Amount) < AmmoPerShot)
    {
        Amount = int(AmmoPerShot);
    }
    MagazineSize = GetMagazineSize();
    if (MagazineSize >= 0 && CollectorAmmoUsedCount + Amount > MagazineSize)
    {
        return FALSE;
    }
    return TRUE;
}
public simulated function SendToFiringState(byte FireModeNum)
{
    if (int(FireModeNum) == 4)
    {
        if (Instigator != None && Instigator.IsLocallyControlled())
        {
            if (Instigator.Role == ENetRole.ROLE_Authority)
            {
                ClientDoReloadTrigger++;
                ClientDoReloadTriggerReplicationTime = WorldInfo.TimeSeconds + 3.0;
            }
            else
            {
                ServerDoReload();
            }
        }
        else
        {
            return;
        }
    }
    Super(Weapon).SendToFiringState(FireModeNum);
}
public simulated function WeaponFired(byte FiringMode, bool bViaReplication, optional Vector HitLocation)
{
    Super(SFXWeapon).WeaponFired(FiringMode, bViaReplication, HitLocation);
    LastFireTime = WorldInfo.GameTimeSeconds;
}
public simulated function bool CanReload()
{
    local BioPawn Pawn;
    
    Pawn = BioPawn(Instigator);
    if (Pawn != None && Pawn.CanReload() == FALSE)
    {
        return FALSE;
    }
    return (bWeaponCanBeReloaded && CollectorAmmoUsedCount > 0) && HasSpareAmmo();
}
public simulated function DoReload()
{
    __OnWeaponReload__Delegate(Self);
    UpdateCollectorAmmoUsedCount(CollectorAmmoUsedCount - 1);
    PlayReloadEject();
    if (SFXPawn_Player(Owner) != None)
    {
        SFXPawn_Player(Owner).bIsFullAmmo = FALSE;
    }
    if (SFXPawn_Player(Owner) != None)
    {
        SFXPawn_Player(Owner).OutOfAmmoTimestamp = 0.0;
    }
}
public simulated function int GetAmmoCountInMagazine()
{
    return GetMagazineSize() - CollectorAmmoUsedCount;
}
public simulated function int GetAmmoRestoredPerReload()
{
    return int(float(GetCurrentSpareAmmo()) - FMax(float(GetCurrentSpareAmmo() - CollectorAmmoUsedCount), 0.0));
}
public simulated function int GetCurrentSpareAmmo()
{
    return 0;
}
public simulated function InitializeWeapon()
{
    Super(SFXWeapon).InitializeWeapon();
    HackLoadWeaponMods();
}
public simulated function bool OutOfAmmo()
{
    return FALSE;
}
public simulated function ResetAmmoOnHolster()
{
    if (bInfiniteAmmo)
    {
        UpdateCollectorAmmoUsedCount(0);
    }
}
public simulated function bool ShouldAutoReload()
{
    if (!Instigator.IsLocallyControlled())
    {
        return FALSE;
    }
    return (CanReload() && GetMagazineSize() > 0) && CollectorAmmoUsedCount >= GetMagazineSize();
}
public simulated function ConsumeAmmoCollector(byte FireModeNum)
{
    local int MagazineSize;
    local int OldAmmoUsedCount;
    local BioRemoteLogger GLogger;
    local BioPlayerController PC;
    
    if (NoAmmoUseChance.Value - 1.0 > float(0) && FRand() < NoAmmoUseChance.Value - 1.0)
    {
        return;
    }
    MagazineSize = GetMagazineSize();
    OldAmmoUsedCount = CollectorAmmoUsedCount;
    UpdateCollectorAmmoUsedCount(int(float(CollectorAmmoUsedCount) + AmmoPerShot));
    if (Instigator != None && Instigator.IsHumanControlled())
    {
        PC = BioPlayerController(Instigator.Controller);
        if (PC != None && PC.IsLocalPlayerController())
        {
            PC.HintSystem.HintEvent('Fire', Class.Name);
        }
        Class'WwiseAudioComponent'.static.SetGlobalRTPCFromScript(AmmoRTPCName, 1.0 - float(CollectorAmmoUsedCount / GetMagazineSize()));
    }
    if (float(MagazineSize - CollectorAmmoUsedCount) <= LowAmmoSoundThreshold && Instigator.IsHumanControlled())
    {
        if (float(MagazineSize - OldAmmoUsedCount) >= LowAmmoSoundThreshold)
        {
            WeaponPlayWwiseEvent(NeedReloadNotifySound, 0.0);
            if ((Instigator.Role == ENetRole.ROLE_Authority && Instigator.IsHumanControlled()) && CurrentSpareAmmo == 0)
            {
                SFXGRI(WorldInfo.GRI).TriggerVocalizationEvent(105, BioPawn(Instigator), , , , TRUE);
            }
        }
        if (MagazineSize - CollectorAmmoUsedCount == 0 && CurrentSpareAmmo == 0)
        {
            SFXGRI(WorldInfo.GRI).TriggerVocalizationEvent(106, BioPawn(Instigator));
        }
    }
    if (float(GetMagazineSize() - CollectorAmmoUsedCount) < SteamSoundThreshold && Instigator.IsHumanControlled())
    {
        if (float(GetMagazineSize() - OldAmmoUsedCount) >= SteamSoundThreshold)
        {
            WeaponPlayWwiseEvent(SteamReloadNotifySound, 0.0);
        }
    }
    if (MagazineSize >= 0 && float(CollectorAmmoUsedCount) + AmmoPerShot > float(MagazineSize))
    {
        if (SFXPawn_Player(Owner) != None && SFXPawn_Player(Owner).OutOfAmmoTimestamp == 0.0)
        {
            SFXPawn_Player(Owner).OutOfAmmoTimestamp = WorldInfo.GameTimeSeconds;
        }
        if (Instigator.IsHumanControlled() && OutOfAmmo())
        {
            GLogger = Class'BioRemoteLogger'.static.GetLogger();
            if (GLogger != None)
            {
                GLogger.SendPlayerEvent(69, "", "", "", "", 0, 0, 0, 0);
            }
        }
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
public simulated function PlayRechargeSound()
{
    bCanPlayRechargeSound = TRUE;
}
public simulated function PlayReloadHeat()
{
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Play(CE_HeatVent, Instigator);
}
public simulated function PlayReloadSteam()
{
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Play(CE_SteamVent, Instigator);
}
public simulated function RechargeAmmo(float DeltaTime)
{
    local int AmmoRounded;
    local float fMagSize;
    
    fMagSize = float(GetMagazineSize());
    AccumulatedAmmo += (RechargeRatePerSecond * DeltaTime) * fMagSize;
    AccumulatedAmmo = FClamp(AccumulatedAmmo, 0.0, float(CollectorAmmoUsedCount));
    if (AccumulatedAmmo >= 1.0)
    {
        AmmoRounded = int(AccumulatedAmmo);
        UpdateCollectorAmmoUsedCount(CollectorAmmoUsedCount - AmmoRounded);
        AccumulatedAmmo -= float(AmmoRounded);
        if (CollectorAmmoUsedCount == 0 && bCanPlayRechargeSound == TRUE)
        {
            WeaponPlayWwiseEvent(WeaponReloadRechargeSound, 0.0);
            bCanPlayRechargeSound = FALSE;
            SetTimer(RechargeSoundDelay, FALSE, 'PlayRechargeSound', );
        }
    }
}
public reliable server function ServerDoReload()
{
    ClientDoReloadTrigger++;
    ClientDoReloadTriggerReplicationTime = WorldInfo.TimeSeconds + 3.0;
    StopMuzzleFlashEffect();
    Super(Weapon).SendToFiringState(4);
}
public simulated function UpdateCollectorAmmoUsedCount(int Count)
{
    CollectorAmmoUsedCount = Count;
    AmmoUsedCount = CollectorAmmoUsedCount;
}

// States
simulated state Reloading 
{
    // State Functions
    public simulated function DoAReload()
    {
        Super(SFXWeapon).DoAReload();
        SetTimer(SteamDelay, FALSE, 'PlayReloadSteam', );
        SetTimer(HeatDelay, FALSE, 'PlayReloadHeat', );
    }
    
    // State code
    stop;
};

replication
{
    if ((((!bNetInitial && !bNetOwner) && bNetDirty) && Role == ENetRole.ROLE_Authority) && WorldInfo.TimeSeconds < ClientDoReloadTriggerReplicationTime)
        ClientDoReloadTrigger;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=ForceFeedbackWaveform Name=EjectRumble0
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=ForceFeedbackWaveformBase
        Samples = ({Duration = 0.125, LeftAmplitude = 55, RightAmplitude = 55, LeftFunction = EWaveformFunction.WF_Sin90to180, RightFunction = EWaveformFunction.WF_Sin90to180}
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
        Template = ParticleSystem'Biovfx_C_Wpn_Rifle.Particles.Cobra_Rifle_Muzzle'
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Template Class=ParticleSystemComponent Name=OutOfAmmoEffect0
        Template = ParticleSystem'BioVFX_C_Reload.Particles.Reload_VentHeat'
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
    Begin Template Class=PointLightComponent Name=MuzFlashLight0 // MILAN CHANGE - Add muzzle flash component
    End Template
    Begin Object Class=SFXAnimSetCookSpec Name=tempAnimInfo
        AnimSet = AnimSet'BIOG_DLC_EXP003_HMM_A.HMM_CB_ProtheanRifleReload' // MILAN CHANGE - Use EXP_Pack003 asset
    End Object
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_WeaponModManager Name=ModManager0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=PickupMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_ASLr_R.ASLr.WPN_ASLr_MDL'
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_ASLr_R.ASLr.WPN_ASLr_MDL'
        AnimTreeTemplate = AnimTree'BIOG_AnimTree_Weapon.BIOG_WPN_Main_O'
        PhysicsAsset = PhysicsAsset'BIOG_PHY_Weapons_F.PHY_WPN_ASLa'
        AnimSets = (AnimSet'BIOG_WPN_A_CON_EXP003.WPN_ASLr_Main')
        ReplacementPrimitive = None
    End Template
    RechargeRatePerSecond = 0.349999994
    PartialRechargeDelay = 1.0
    FullRechargeDelay = 3.0
    CE_HeatVent = RvrClientEffect'BioVFX_Exp3_CitGlobal.VCFX.Lancer_Overheat'
    CE_SteamVent = RvrClientEffect'BioVFX_Exp3_CitGlobal.VCFX.Lancer_Overheat_2'
    SteamDelay = 0.25
    HeatDelay = 0.699999988
    RechargeSoundDelay = 2.5
    bCanPlayRechargeSound = TRUE
    AI_AccCone_Min = {X = 1.20000005, Y = 1.20000005}
    AI_AccCone_Max = {X = 1.79999995, Y = 1.79999995}
    ReloadDuration = {X = 5.0, Y = 5.0}
    Damage = {X = 67.9000015, Y = 84.8000031}
    MagSize = {X = 38.0, Y = 57.0}
    MaxSpareAmmo = {X = 1000000.0, Y = 1000000.0}
    MinAimError = {X = 2.0, Y = 2.0}
    MaxAimError = {X = 6.19999981, Y = 6.19999981}
    MinZoomAimError = {X = 0.200000003, Y = 0.200000003}
    MaxZoomAimError = {X = 1.0, Y = 1.0}
    RateOfFire = {X = 600.0, Y = 600.0}
    EncumbranceWeight = {X = 1.29999995, Y = 0.800000012}
    Recoil = {X = 0.150000006, Y = 0.150000006}
    ZoomRecoil = {X = 0.425000012, Y = 0.425000012}
    AccFirePenalty = {X = 10.6999998, Y = 10.6999998}
    AccFireInterpSpeed = {X = 12.0, Y = 12.0}
    ZoomAccFirePenalty = {X = 22.3500004, Y = 22.3500004}
    ZoomAccFireInterpSpeed = {X = 28.0, Y = 28.0}
    MinZoomCrosshairRange = {X = 28.0, Y = 28.0}
    MaxZoomCrosshairRange = {X = 48.0, Y = 48.0}
    StatBarAccuracy = {X = 20.0, Y = 20.0}
    StatBarDamage = {X = 67.9000015, Y = 84.8000031}
    StatBarRateOfFire = {X = 500.0, Y = 500.0}
    GUIImage = "DLC_MPImages.Weapons.asl_lancer_512x256" // MILAN CHANGE - Use EXPPack_003 asset
    NotificationImage = "DLC_MPImages.Weapons.asl_lancer_256x128" // MILAN CHANGE - Use EXPPack_003 asset
    FiringShake = {
                   RotAmplitude = {X = 45.0, Y = 22.5, Z = 11.25}, 
                   RotFrequency = {X = 80.0, Y = 50.0, Z = 20.0}, 
                   TimeDuration = 0.200000003
                  }
    TightAimFiringShake = {
                           RotAmplitude = {X = 55.0, Y = 33.5, Z = 22.25}, 
                           RotFrequency = {X = 90.0, Y = 60.0, Z = 30.0}, 
                           TimeDuration = 0.125
                          }
    TracerInfo = {
                  Scale3D = {X = 2.0, Y = 2.0, Z = 2.0}, 
                  StaticMesh = StaticMesh'BioVFX_C_Weapons.Tracers.Meshes.Tracer_SMG_Mesh', 
                  StandardPSTemplate = ParticleSystem'BioVFX_C_Weapons.Tracers.Particles.Tracer_Smoke_Trail', 
                  PlayerPSTemplate = ParticleSystem'BioVFX_C_Weapons.Tracers.Particles.Tracer_Smoke_Trail', 
                  AccelRate = 8000.0, 
                  Speed = 15000.0, 
                  MaxSpeed = 17500.0
                 }
    AI_BurstFireCount = {X = 12.0, Y = 18.0}
    AI_BurstFireDelay = {X = 0.649999976, Y = 1.0}
    ReloadAnimInfo = tempAnimInfo
    PSC_OutOfAmmoEffect = OutOfAmmoEffect0
    OutOfAmmoRumble = OutOfAmmoRumble0
    WeaponFireWaveForm = ForceFeedbackWaveformBase
    EjectRumble = EjectRumble0
    PSC_ShellCasing = ShellCasingPSC0
    PSC_ReloadVent = ReloadVent0
    TracerSpawnOffset = 1.0
    PSC_MuzFlashEmitter = MuzFlashPSC0
    // MILAN CHANGE - Muzzle lights
    LC_MuzzleFlashLight = MuzFlashLight0 // MILAN CHANGE - Add muzzleflash asset
    MuzzleLightLifetime = 0.0500000007
    MuzzleLightBrightness = 0.300000012
    MuzzleLightColor = {B = 255, G = 70, R = 1, A = 0}
    MuzzleLightFalloffExponent = 15.0
    MuzzleLightRadius = 600.0
    // END MILAN CHANGE
    EjectShellCasingTimeRatio = 0.800000012
    LowAmmoSoundThreshold = 5.0
    SteamSoundThreshold = 1.0
    NoAmmoFireSoundDelay = 0.5
    MinRefireTime = 0.00999999978
    LazyRateOfFire = 0.00999999978
    RateOfFireAI = 1.0
    RecoilInterpSpeed = 0.0
    RecoilYawScale = 0.25
    RecoilYawFrequency = 0.5
    IconResource = GFxMovieInfo'GUI_SF_ME3_DLC_LancerASL.ME3_DLC_LancerASL' // MILAN CHANGE - Use EXP_Pack003 asset
    PrettyName = $793101
    ShortPrettyName = $793101
    ShortDescription = $793102
    GeneralDescription = $793145
    FireSound = WwiseEvent'Wwise_Weapons_S_Lancer.Play_wep_np_lancer_fire'
    PlayerFireSound = WwiseEvent'Wwise_Weapons_S_Lancer.Play_wep_p_m7_shot'
    FireNoAmmoSound = WwiseEvent'Wwise_Weapons_Standard_LowAmmo.Play_weapon_dryfire_machineguns'
    WeaponReloadSound = WwiseEvent'Wwise_Weapons_S_Lancer.Play_wep_s_m7_overheat'
    WeaponSteamReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_noammo_large_alien_sweetener'
    WeaponExpandSound = WwiseEvent'Wwise_Weapons_S_Lancer.Play_wep_s_lancer_expand_01'
    WeaponCollapseSound = WwiseEvent'Wwise_Weapons_S_Lancer.Play_wep_s_lancer_collapse_01'
    SteamReloadNotifySound = WwiseEvent'Wwise_Weapons_Standard_LowAmmo.Play_overheat'
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    bLoopingFlashEmitter = TRUE
    bWeaponCanBeReloaded = FALSE
    bInfiniteAmmo = TRUE
    InstantHitMomentum = (0.0, 1.0, 7.5, 1.0)
    InstantHitDamageTypes = (None, Class'SFXDamageType_Default', Class'SFXDamageType_AssaultRifle', Class'SFXDamageType_Default')
    FireOffset = {X = 61.0, Y = -0.5, Z = 7.25}
    Mesh = WeaponMesh
    AIRating = 1.0
    DroppedPickupMesh = PickupMesh
    PickupFactoryMesh = PickupMesh
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
}