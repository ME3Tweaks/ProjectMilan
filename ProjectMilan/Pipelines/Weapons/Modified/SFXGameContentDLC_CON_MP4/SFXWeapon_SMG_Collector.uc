// MILAN Weapon
// Source: MP4
// Note: LE changes were made from BioD_CitSim_CllctrB - as this weapon does not exist for the player
// Note: This class is shared with CollectorTrooper and will be linked in with it
Class SFXWeapon_SMG_Collector extends SFXWeapon_SMG_Base
    placeable
    config(Weapon);

// Variables
var Guid ClientEffectFiringGuid;
var RvrClientEffectInterface CE_SteamVent;
var RvrClientEffectInterface CE_HeatVent;
var WwiseEvent WeaponReloadRechargeSound;
var config float RechargeRatePerSecond;
var config float PartialRechargeDelay;
var config float FullRechargeDelay;
var float AccumulatedAmmo;
var transient int CollectorAmmoUsedCount;
var float SteamDelay;
var float HeatDelay;
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
    if (GetMagazineSize() - CollectorAmmoUsedCount > 1)
    {
        AmmoPerShot = 2.0;
    }
    else
    {
        AmmoPerShot = 1.0;
    }
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
public simulated function DecalComponent GetWeaponSpecificDecalData(SFXPhysicalMaterialDecals DecalEffects, out float FadeTime)
{
    local int DecalLength;
    
    FadeTime = DecalEffects.SMGFadeTime;
    DecalLength = DecalEffects.SMG.Length;
    if (DecalLength > 0)
    {
        return DecalEffects.SMG[Rand(DecalLength)];
    }
    return None;
}
public static simulated function ParticleSystem GetWeaponSpecificImpactEffect(SFXPhysicalMaterialImpactEffects ImpactEffects);

public simulated function WwiseEvent GetWeaponSpecificImpactSound(SFXPhysicalMaterialImpactSounds ImpactSounds)
{
    if (SFXPawn_Player(Instigator) != None && Instigator.IsLocallyControlled())
    {
        return ImpactSounds.SMG_Player;
    }
    return ImpactSounds.SMG;
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
public simulated function bool IsMuzzleFlashRelevant()
{
    if (Instigator == None || Instigator.IsHumanControlled())
    {
        return TRUE;
    }
    if (WorldInfo.bAggressiveLOD)
    {
        return FALSE;
    }
    return TRUE;
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
        Samples = ({Duration = 0.25, LeftAmplitude = 65, RightAmplitude = 65, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Constant}
                  )
    End Template
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_PST_Q_CON_MP4.WPN_PSTq_MDL'
        AnimTreeTemplate = AnimTree'BIOG_AnimTree_Weapon.BIOG_WPN_Main_O' // MILAN CHANGE - Use EXP_Pack003 Asset
        PhysicsAsset = PhysicsAsset'BIOG_PHY_Weapons_F_CON_DLC.WPN_PHY_PSTq' // MILAN CHANGE - Use EXP_Pack003 Asset
        AnimSets = (AnimSet'BIOG_WPN_A_CON_DLC.WPN_PSTq_Main') // MILAN CHANGE - Use EXP_Pack003 Asset
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SkeletalMeshComponent Name=PickupMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_PST_Q_CON_MP4.WPN_PSTq_MDL'
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ParticleSystemComponent Name=ReloadVent0
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=OutOfAmmoRumble0
    End Template
    Begin Template Class=PointLightComponent Name=MuzFlashLight0 // MILAN CHANGE - Add muzzle flashlight component
    End Template
    Begin Template Class=ParticleSystemComponent Name=AmmoPowerHologram
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ParticleSystemComponent Name=AmmoPowerIconHologram
        ReplacementPrimitive = None
    End Template
    Begin Object Class=ParticleSystemComponent Name=MuzFlashPSC0
        Template = ParticleSystem'BioVFX_MP4_ColSMG.Particles.ColSMG_Muzzle'
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Template Class=ParticleSystemComponent Name=OutOfAmmoEffect0
        Template = ParticleSystem'BioVFX_C_Reload.Particles.Reload_VentHeat'
        ReplacementPrimitive = None
    End Template
    Begin Object Class=ParticleSystemComponent Name=ShellCasingPSC0
        Template = ParticleSystem'BioVFX_C_Reload.Particles.Reload_VentHeat'
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Object Class=SFXAnimSetCookSpec Name=tempAnimInfo
        Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_CB_ProtheanRifleReload
            m_nmOrigSetName = 'HMM_CB_ProtheanRifleReload'
            Sequences = (AnimSequence'BIOG_DLC_MP4_CBT_A.HMM_CB_ProtheanRifleReload_CB_Reload', AnimSequence'BIOG_DLC_MP4_CBT_A.HMM_CB_ProtheanRifleReload_CB_ReloadCover', AnimSequence'BIOG_DLC_MP4_CBT_A.HMM_CB_ProtheanRifleReload_CB_ReloadCover_Mid')
            m_pBioAnimSetData = BioAnimSetData'BIOG_DLC_MP4_CBT_A.HMM_CB_ProtheanRifleReload_BioAnimSetData'
        End Object
        AnimSet = MY_DYN_HMM_CB_ProtheanRifleReload
    End Object
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_WeaponModManager Name=ModManager0
    End Template
    RechargeRatePerSecond = 0.300000012
    PartialRechargeDelay = 1.0
    FullRechargeDelay = 3.0
    CE_SteamVent = RvrClientEffect'BioVFX_MP4_ColSMG.VCFX.ColSMG_Overheat_2'
    CE_HeatVent = RvrClientEffect'BioVFX_MP4_ColSnipe.VCFX.ColSnipe_Overheat'
    SteamDelay = 0.25
    HeatDelay = 0.699999988
    WeaponReloadRechargeSound = WwiseEvent'Wwise_Weapons_S_ColSniper.Play_wep_s_colsniper_recharge'
    RechargeSoundDelay = 2.5
    bCanPlayRechargeSound = TRUE
    AI_AccCone_Min = {X = 1.39999998, Y = 1.39999998}
    AI_AccCone_Max = {X = 2.9000001, Y = 2.9000001}
    ReloadDuration = {X = 5.0, Y = 5.0}
    Damage = {X = 75.1999969, Y = 94.0999985}
    MagSize = {X = 20.0, Y = 30.0}
    MaxSpareAmmo = {X = 1000000.0, Y = 1000000.0}
    MinAimError = {X = 1.89999998, Y = 1.89999998}
    MaxAimError = {X = 3.0, Y = 3.0}
    MinZoomAimError = {X = 0.200000003, Y = 0.200000003}
    MaxZoomAimError = {X = 1.5, Y = 1.5}
    RateOfFire = {X = 800.0, Y = 800.0}
    NoAmmoUseChance = {X = 0.25, Y = 0.25}
    EncumbranceWeight = {X = 0.75, Y = 0.349999994}
    Recoil = {X = 0.100000001, Y = 0.100000001}
    ZoomRecoil = {X = 0.150000006, Y = 0.150000006}
    AccFirePenalty = {X = 6.5, Y = 6.5}
    AccFireInterpSpeed = {X = 5.0, Y = 5.0}
    ZoomAccFirePenalty = {X = 12.0, Y = 12.0}
    ZoomAccFireInterpSpeed = {X = 12.5, Y = 12.5}
    MinZoomCrosshairRange = {X = 15.0, Y = 15.0}
    MaxZoomCrosshairRange = {X = 45.0, Y = 45.0}
    StatBarAccuracy = {X = 35.0, Y = 35.0}
    StatBarDamage = {X = 75.1999969, Y = 94.0999985}
    StatBarRateOfFire = {X = 800.0, Y = 800.0}
    GUIImage = "GUI_MPImages_MP4.smg_collector_512x256" // MILAN NOTE: May need upscaled
    NotificationImage = "GUI_MPImages_MP4.smg_collector_256x128" // MILAN NOTE: May need upscaled
    WeaponModBodyColours = ({R = 0.0299999993, G = 0.0299999993, B = 0.0299999993, A = 0.0}
                           )
    GUIZoomReticleClass = Class'SFXGUI_WeaponReticleSimple'
    FiringShake = {
                   RotAmplitude = {X = 45.0, Y = 22.0, Z = 11.25}, 
                   RotFrequency = {X = 80.0, Y = 50.0, Z = 20.0}, 
                   TimeDuration = 0.150000006
                  }
    TightAimFiringShake = {
                           RotAmplitude = {X = 45.0, Y = 22.0, Z = 11.25}, 
                           RotFrequency = {X = 80.0, Y = 50.0, Z = 20.0}, 
                           TimeDuration = 0.075000003
                          }
    TracerInfo = {
                  Scale3D = {X = 1.14999998, Y = 1.14999998, Z = 1.14999998}, 
                  StandardPSTemplate = ParticleSystem'BioVFX_C_Weapons.Tracers.Particles.Tracer_Smoke_Trail', 
                  PlayerPSTemplate = ParticleSystem'BioVFX_C_Weapons.Tracers.Particles.Tracer_Smoke_Trail', 
                  AccelRate = 8000.0, 
                  Speed = 18000.0, 
                  MaxSpeed = 20000.0
                 }
    AI_BurstFireCount = {X = 15.0, Y = 25.0}
    AI_BurstFireDelay = {X = 0.649999976, Y = 2.29999995}
    ReloadAnimInfo = tempAnimInfo
    PSC_OutOfAmmoEffect = OutOfAmmoEffect0
    OutOfAmmoRumble = OutOfAmmoRumble0
    WeaponFireWaveForm = ForceFeedbackWaveformBase
    EjectRumble = EjectRumble0
    PS_DefaultImpactEffect = ParticleSystem'BioVFX_MP4_ColSMG.Particles.ColSMG_Imp'
    DefaultDecalMaterial = None
    PSC_ShellCasing = ShellCasingPSC0
    PSC_ReloadVent = ReloadVent0
    TracerSpawnOffset = 3.0
    PSC_MuzFlashEmitter = MuzFlashPSC0
    LC_MuzzleFlashLight = MuzFlashLight0 // MILAN CHANGE - Add Muzzle Flashlight
    EjectShellCasingTimeRatio = 0.800000012
    LowAmmoSoundThreshold = 12.0
    SteamSoundThreshold = 1.0
    NoAmmoFireSoundDelay = 0.5
    LazyRateOfFire = 0.00999999978
    RateOfFireAI = 1.0
    RoundsPerBurst = 10.0
    RecoilYawScale = 0.200000003
    RecoilYawFrequency = 4.0
    IconResource = GFxMovieInfo'GUI_SF_ME3_DLC_CollctSMG.ME3_DLC_CollctSMG'
    PrettyName = $766347
    ShortPrettyName = $766347
    ShortDescription = $766348
    GeneralDescription = $766349
    FireSound = WwiseEvent'Wwise_Weapons_S_ColSMG.wep_np_colsmg_fire'
    PlayerFireSound = WwiseEvent'Wwise_Weapons_S_ColSMG.wep_p_colsmg_fire'
    FireNoAmmoSound = WwiseEvent'Wwise_Weapons_Standard_LowAmmo.Play_weapon_dryfire_pistols'
    WeaponReloadSound = WwiseEvent'Wwise_Weapons_S_ColSMG.Play_wep_p_colsmg_overheat'
    WeaponSteamReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_noammo_large_alien_sweetener'
    SteamReloadNotifySound = WwiseEvent'Wwise_Weapons_Standard_LowAmmo.Play_weapon_reload_air_release'
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    bLoopingFlashEmitter = TRUE
    AnimType = WeaponAnimType.WeaponAnimType_AutoPistol
    bInfiniteAmmo = TRUE
    InstantHitMomentum = (0.0, 1.0, 25.0, 1.0)
    InstantHitDamageTypes = (None, Class'SFXDamageType_Default', Class'SFXDamageType_SMG_Collector', Class'SFXDamageType_Default')
    FireOffset = {X = 19.0, Y = 0.5, Z = 4.0}
    Mesh = WeaponMesh
    AIRating = 20.0
    DroppedPickupMesh = PickupMesh
    PickupFactoryMesh = PickupMesh
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
}