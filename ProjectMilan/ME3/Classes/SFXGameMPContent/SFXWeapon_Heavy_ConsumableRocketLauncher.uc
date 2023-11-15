Class SFXWeapon_Heavy_ConsumableRocketLauncher extends SFXHeavyWeapon
    placeable
    config(Weapon);

// Variables
var Guid ChargeEffectGuid;
var Guid ShotEffectGuid;
var transient SFXPowerCustomActionMP_Consumable Power;
var ForceFeedbackWaveform NukeRumble;
var RvrClientEffectInterface CE_ChargeUp;
var RvrClientEffectInterface CE_Shot;
var config float DamageRadius;
var config float CappedDamageRadius;
var config float FarDamage;

// Functions
public simulated function FireAmmunition()
{
    local RvrClientEffectTarget CETarget;
    
    CETarget.Instigator = Instigator;
    CETarget.HitBone = 'Flash_2';
    ShotEffectGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_Shot, CETarget);
    if (SFXPawn_Player(Instigator) != None)
    {
        WeaponAnimNode.StopCustomAnim(0.200000003);
        WeaponAnimNode.PlayCustomAnim('WPN_ChargeRelease', 1.0);
    }
    Super(SFXWeapon_NativeBase).FireAmmunition();
}
public simulated function ConsumeAmmo(byte FireModeNum)
{
    if (Instigator.IsLocallyControlled() && Instigator.IsHumanControlled())
    {
        if (Power == None || !Power.HasCharges())
        {
            return;
        }
        Power.UseConsumable();
    }
}
public simulated function bool HasAmmo(byte FireModeNum, optional int Amount)
{
    Amount = int(FMax(float(Amount), 1.0));
    return Amount <= GetAmmoCountInMagazine();
}
public simulated function PutDownWeapon()
{
    Super(Weapon).PutDownWeapon();
}
public simulated function StartFire(byte FireModeNum)
{
    if (int(CurrentFireMode) == int(FireModeNum))
    {
        return;
    }
    if (Instigator == None || !Instigator.bNoWeaponFiring)
    {
        if (Role < ENetRole.ROLE_Authority)
        {
            if (HasAmmo(FireModeNum))
            {
                ServerStartFire(FireModeNum);
            }
            else
            {
                ServerPlayNoAmmoEffects();
            }
        }
        BeginFire(FireModeNum);
    }
}
public function DropGun();

public simulated function int GetAmmoCountInMagazine()
{
    if (Instigator.IsLocallyControlled() && Instigator.IsHumanControlled())
    {
        if (Power == None)
        {
            return 0;
        }
        else
        {
            return Power.GetChargeCount();
        }
    }
    else
    {
        return GetMagazineSize();
    }
}
public simulated function InitializeWeapon()
{
    if (Instigator != None && Instigator.IsLocallyControlled())
    {
        Power = SFXPowerCustomActionMP_Consumable(SFXPawn_Player(Instigator).FindPower('SFXPowerCustomActionMP_Consumable_Rocket'));
        if (Power == None)
        {
        }
    }
    Super(SFXWeapon).InitializeWeapon();
    AmmoUsedCount = GetMagazineSize();
}
public simulated function ShutOffAllEmitters()
{
    local BioPlayerController PC;
    
    Super(SFXWeapon).ShutOffAllEmitters();
    PC = BioPlayerController(Instigator.Controller);
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_ChargeUp, ChargeEffectGuid, FALSE);
    if (PC.IsLocalPlayerController())
    {
        PC.ClientStopForceFeedbackWaveform(NukeRumble);
    }
}
public simulated function StartChargeEffects()
{
    local BioPlayerController PC;
    local RvrClientEffectTarget CETarget;
    
    Super(SFXWeapon).StartChargeEffects();
    CETarget.Instigator = Instigator;
    CETarget.HitBone = 'Flash_2';
    if (SFXPawn_Player(Instigator) != None)
    {
        WeaponAnimNode.PlayCustomAnim('WPN_ChargeUp', 1.0);
        WeaponAnimNode.PlayCustomAnim('WPN_ChargeHold', 1.0, 1.0, 0.0, TRUE);
    }
    PC = BioPlayerController(Instigator.Controller);
    ChargeEffectGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_ChargeUp, CETarget);
    if (PC != None)
    {
        if (PC.IsLocalPlayerController())
        {
            PC.ClientPlayForceFeedbackWaveform(NukeRumble);
        }
    }
}
public simulated function StopChargeEffects()
{
    local BioPlayerController PC;
    
    Super(SFXWeapon).StopChargeEffects();
    PC = BioPlayerController(Instigator.Controller);
    if (PC != None && PC.IsLocalPlayerController())
    {
        PC.ClientStopForceFeedbackWaveform(NukeRumble);
    }
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_ChargeUp, ChargeEffectGuid, FALSE);
    WeaponAnimNode.StopCustomAnim(0.200000003);
}
public unreliable server function ServerPlayNoAmmoEffects()
{
    IncrementFizzleCount();
    PlayNoAmmoEffects();
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=ForceFeedbackWaveform Name=ForceFeedbackWaveformBase
        Samples = ({Duration = 0.449999988, LeftAmplitude = 75, RightAmplitude = 75, LeftFunction = EWaveformFunction.WF_LinearIncreasing, RightFunction = EWaveformFunction.WF_LinearIncreasing}
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
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_WeaponModManager Name=ModManager0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=PickupMesh
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh
        SkeletalMesh = SkeletalMesh'biog_wpn_hvy_r.HVYn.WPN_HVYn_MDL'
        AnimTreeTemplate = AnimTree'biog_animtree_weapon.BIOG_WPN_Main_O'
        PhysicsAsset = PhysicsAsset'BIOG_PHY_Weapons_F.PHY_WPN_HVYn'
        AnimSets = (AnimSet'biog_wpn_a.WPN_HVYn_Main')
        ReplacementPrimitive = None
    End Template
    CE_ChargeUp = RvrClientEffectMulti'BioVFX_C_Wpn_Titan.VCFX.Hydra_Charge_M_VCFX'
    CE_Shot = RvrClientEffectMulti'BioVFX_C_Wpn_Titan.VCFX.Hydra_Muzzle_M_VCFX'
    DamageRadius = 750.0
    CappedDamageRadius = 200.0
    FarDamage = 5000.0
    Damage = {X = 50000.0, Y = 50000.0}
    MagSize = {X = 25.0, Y = 25.0}
    MinAimError = {X = 0.200000003, Y = 0.200000003}
    MaxAimError = {X = 0.400000006, Y = 0.400000006}
    MinZoomAimError = {X = 0.00999999978, Y = 0.00999999978}
    MaxZoomAimError = {X = 0.100000001, Y = 0.100000001}
    RateOfFire = {X = 140.0, Y = 140.0}
    Recoil = {X = 0.300000012, Y = 0.300000012}
    ZoomRecoil = {X = 0.100000001, Y = 0.100000001}
    AccFirePenalty = {X = 3.29999995, Y = 3.29999995}
    AccFireInterpSpeed = {X = 3.0, Y = 3.0}
    ZoomAccFirePenalty = {X = 10.3999996, Y = 10.3999996}
    ZoomAccFireInterpSpeed = {X = 10.0, Y = 10.0}
    MinCrosshairRange = {X = 40.0, Y = 40.0}
    MaxCrosshairRange = {X = 100.0, Y = 100.0}
    MinZoomCrosshairRange = {X = 25.0, Y = 25.0}
    MaxZoomCrosshairRange = {X = 80.0, Y = 80.0}
    GUIImage = "gui_codex_images.Weapons.hvy_missile_512x256"
    NotificationImage = "GUI_Icons.Weapons.hvy_missile_256x128"
    GUIReticleClass = Class'SFXGUI_HeavyWeaponReticle'
    GUIZoomReticleClass = Class'SFXGUI_HeavyWeaponReticle'
    TracerInfo = {
                  Scale3D = {X = 2.0, Y = 1.0, Z = 1.0}, 
                  AccelRate = 7500.0, 
                  Speed = 3500.0, 
                  MaxSpeed = 9000.0
                 }
    MuzzleIdlePosition = {X = 87.0, Y = 7.0, Z = 38.0}
    PSC_OutOfAmmoEffect = OutOfAmmoEffect0
    OutOfAmmoRumble = OutOfAmmoRumble0
    WeaponFireWaveForm = ForceFeedbackWaveformBase
    PSC_ShellCasing = ShellCasingPSC0
    PSC_ReloadVent = ReloadVent0
    NoAmmoFireSoundDelay = 1.0
    LazyRateOfFire = 0.00999999978
    IconRef = 19
    PrettyName = $661166
    ShortPrettyName = $340356
    ShortDescription = $661351
    GeneralDescription = $661351
    FireSound = WwiseEvent'Wwise_Weapons_NP_Titan.Play_wep_np_titan_fire'
    PlayerFireSound = WwiseEvent'Wwise_Weapons_P_Titan.Play_wep_p_titan_fire'
    FireNoAmmoSound = WwiseEvent'Wwise_Weapons_Standard_LowAmmo.Play_weapon_dryfire_machineguns'
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    PowerUpSound = WwiseEvent'Wwise_Weapons_S_Titan.Play_wep_s_titan_charge_start'
    PowerDownSound = WwiseEvent'Wwise_Weapons_S_Titan.Play_wep_s_titan_charge_stop'
    MinChargeTime = 0.800000012
    MaxChargeTime = 0.800000012
    bWeaponCanBeReloaded = TRUE
    bZoomSnapEnabled = FALSE
    bForceFireAfterCharge = TRUE
    bQuickSwitchEligible = FALSE
    DefaultFireMode = FireModes.FireMode_SemiAuto
    AnimType = WeaponAnimType.WeaponAnimType_MissileLauncher
    WeaponFireTypes = (EWeaponFireType.EWFT_InstantHit, EWeaponFireType.EWFT_Projectile, EWeaponFireType.EWFT_InstantHit, EWeaponFireType.EWFT_InstantHit, EWeaponFireType.EWFT_InstantHit)
    WeaponProjectiles = (None, Class'SFXProjectile_ConsumableRocket')
    InstantHitMomentum = (0.0, 10.0, 1.0, 1.0)
    InstantHitDamageTypes = (None, Class'SFXDamageType_ConsumableRocket', Class'SFXDamageType_Default', Class'SFXDamageType_Default')
    FireOffset = {X = 77.25, Y = 0.0, Z = 4.25}
    Mesh = WeaponMesh
    DroppedPickupMesh = WeaponMesh
    PickupFactoryMesh = WeaponMesh
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
}