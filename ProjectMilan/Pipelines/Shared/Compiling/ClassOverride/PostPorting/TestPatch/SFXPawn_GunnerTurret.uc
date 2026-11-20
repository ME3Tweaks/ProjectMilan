// Source: ME3, Patch_SFXPawn_GunnerTurret
// Decompiled 11/17/2026 7:37:59 AM against BioD_Cat003_150DocksCombat.pcc
Class SFXPawn_GunnerTurret extends SFXPawn
    placeable
    config(Game);

var Object.Guid RepairGUID;
var RvrClientEffectInterface CE_Explosion;
var RvrClientEffectInterface CE_Active;
var RvrClientEffectInterface CE_Repair;
var transient BioSkelControlAdditiveLookAt LookAt;
var WwiseEvent ExplosionSound;
var WwiseEvent TankHit;
var transient SFXPawn_Gunner EngineerOwner;
var transient repnotify Actor FireTarget;

public simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    LookAt = BioSkelControlAdditiveLookAt(Mesh.FindSkelControl('TargetControl'));
    SetTimer(6.0, FALSE, 'ActivateLifetimeCrust', );
}
public simulated function ReplicatedEvent(Name VarName)
{
    if (VarName == 'FireTarget')
    {
        if (FireTarget != None)
        {
            LookAt.SetSkelControlActive(TRUE);
        }
        else
        {
            LookAt.SetSkelControlActive(FALSE);
        }
    }
    else
    {
        Super.ReplicatedEvent(VarName);
    }
}
public simulated function Tick(float DeltaTime)
{
    Super(BioPawn).Tick(DeltaTime);
    if (LookAt.ControlStrength > 0.0)
    {
        if (CurrentCustomAction == 0 && FireTarget != None)
        {
            LookAt.DesiredTargetLocation = FireTarget.location;
        }
        else
        {
            LookAt.DesiredTargetLocation = location + Vector(Rotation) * 100.0;
        }
        if (LookAt != None && LookAt.TargetLocation != LookAt.DesiredTargetLocation)
        {
            LookAt.InterpolateTargetLocation(DeltaTime);
        }
    }
}
public simulated function PlayDying(Class<DamageType> DamageType, Object.Vector HitLoc)
{
    local SFXAI_Gunner AI;
    local SFXNav_TurretPoint TP;
    
    PlaySound(ExplosionSound, TRUE);
    PlaySound(TankHit, TRUE);
    TP = SFXNav_TurretPoint(Anchor);
    if (TP != None)
    {
        TP.bClaimed = FALSE;
    }
    if (EngineerOwner != None)
    {
        AI = SFXAI_Gunner(EngineerOwner.Controller);
        if (AI != None)
        {
            AI.NotifyTurretDestroyed();
        }
        EngineerOwner = None;
    }
    PlayRepairEffects(FALSE);
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Play(CE_Explosion, Self);
    SetCollision(FALSE, FALSE, );
    Mesh.SetActorCollision(FALSE, FALSE);
    if (DamageType == Class'DmgType_Suicided')
    {
        SFXPawn_Gunner(ReplicatedDeathInfo.KillerPawn).DecrementSpawnedTurrets();
    }
    Super.PlayDying(DamageType, HitLoc);
}
public simulated function bool CanPlayDeathEffect()
{
    return FALSE;
}
public simulated function Actor GetPetOwner()
{
    return EngineerOwner;
}
public simulated function PlayRepairEffects(bool bActivate)
{
    if (bActivate)
    {
        if (RepairGUID.A == 0 && RepairGUID.B == 0 && RepairGUID.C == 0 && RepairGUID.D == 0)
        {
            RepairGUID = Class'RvrClientEffectManager'.static.GetClientEffectManager().Start(CE_Repair, Self);
        }
    }
    else
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(CE_Repair, RepairGUID, TRUE, Self);
        RepairGUID.A = 0;
        RepairGUID.B = 0;
        RepairGUID.C = 0;
        RepairGUID.D = 0;
    }
}
public simulated function ActivateLifetimeCrust()
{
    if (GetCurrentHealth() > 0.0)
    {
        SetLifeTimeCrust(CE_Active);
    }
}

replication
{
    if (bNetDirty && Role == ENetRole.ROLE_Authority && FireTarget != None)
        FireTarget;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=BioDynamicLightEnvironmentComponent Name=BioLightEnvComponent0
    End Template
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        CollisionHeight = 55.0
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=FootstepShakeFF0
    End Template
    Begin Object Class=SFXLoadoutData Name=CerbGunnerTurretLoadout0
        Weapons = (Class'SFXWeapon_AI_TurretMiniGun')
        ShieldLoadouts = ({
                           Shields = Class'SFXShield_Energy', 
                           ShieldLevelRange = {X = 0.0, Y = 0.0}, 
                           MaxShields = {X = 400.0, Y = 400.0}
                          }
                         )
    End Object
    Begin Template Class=SFXModule_AimAssistTarget Name=AimAssistMod
    End Template
    Begin Template Class=SFXModule_Audio Name=AudioModule
    End Template
    Begin Template Class=SFXModule_Conversation Name=ConvoMod01
        m_bDisableFacefx = TRUE
    End Template
    Begin Template Class=SFXModule_Damage Name=DmgMod0
        HealthType = EHealthType.HealthType_Armour
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_Gestures Name=GestMod01
        Begin Template Class=BioGestureAnimSetMgr Name=oAnimSetMgr
        End Template
        m_pAnimSetMgr = oAnimSetMgr
    End Template
    Begin Template Class=SFXModule_LookAt Name=LookAtMod01
    End Template
    Begin Template Class=SFXModule_Radar Name=RadarModule
    End Template
    Begin Template Class=SFXModule_Timeline Name=TimelineMod0
    End Template
    Begin Template Class=SFXPowerManager Name=PowerMgr
    End Template
    Begin Template Class=SkeletalMeshComponent Name=BioPawnSkeletalMeshComponent
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=GearMesh0
        ParentAnimComponent = BioPawnSkeletalMeshComponent
        ShadowParent = BioPawnSkeletalMeshComponent
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=HairMesh0
        ParentAnimComponent = BioPawnSkeletalMeshComponent
        ShadowParent = BioPawnSkeletalMeshComponent
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=HeadMesh0
        ParentAnimComponent = BioPawnSkeletalMeshComponent
        ShadowParent = BioPawnSkeletalMeshComponent
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
    End Template
    CE_Explosion = RvrClientEffect'BioVFX_C_Engineer.VCFX.Turret_Explosion_VCFX'
    CE_Active = RvrClientEffect'BioVFX_C_Engineer.VCFX.Turret_Lifetime_Crust_VCFX'
    CE_Repair = RvrClientEffect'BioVFX_C_Engineer.VCFX.Repair_Turret_Crust_VCFX'
    ExplosionSound = WwiseEvent'Wwise_Weapons_Heavy_Grenade.Play_weapon_heavy_grenade_impact'
    TankHit = WwiseEvent'Wwise_weapon_geth_flamethrower.Play_geth_flamethrower_critical_impact'
    MuzzleSocketName = 'Muzzle01'
    ShellCasingSocketName = 'ShellCasing01'
    DamageScoreBudget = 100.0
    KillBonusScore = 10.0
    PowerControlAssistBudget = 25.0
    FootstepForceFeedback = FootstepShakeFF0
    bSupportsVisibleWeapons = FALSE
    bCanBeRepaired = TRUE
    bIsPet = TRUE
    bCanDropAmmo = FALSE
    CustomActionClasses = (None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_SyncPawnPartner_Base', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_MountedGunReload', 
                           None, 
                           None, 
                           Class'SFXCustomAction_EnterMountedGun', 
                           Class'SFXCustomAction_ExitMountedGun', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_TurretDeployed'
                          )
    AimNodes = ('Turret', 
                'Turret', 
                'Turret', 
                'Turret', 
                'Turret', 
                'Turret', 
                'Turret', 
                'Turret'
               )
    RightHandSocketName = 'Muzzle01'
    HeadMesh = HeadMesh0
    m_oHairMesh = HairMesh0
    m_oHeadGearMesh = GearMesh0
    LightEnvironment = BioLightEnvComponent0
    Loadout = CerbGunnerTurretLoadout0
    PowerManager = PowerMgr
    bSpawnPHATInstance = FALSE
    bCanRagdoll = FALSE
    bCanPortArms = FALSE
    RaceType = ERaceType.RaceType_Machine
    AffiliationType = EAffiliationType.AffiliationType_Cerberus
    ControllerClass = Class'SFXAI_GunnerTurret'
    PeripheralVision = -1.0
    BaseEyeHeight = 40.0
    EyeHeight = 40.0
    Mesh = BioPawnSkeletalMeshComponent
    CylinderComponent = CollisionCylinder
    Components = (CollisionCylinder, None, BioLightEnvComponent0, BioPawnSkeletalMeshComponent, HeadMesh0, HairMesh0, GearMesh0)
    Modules = (GEMod0, 
               RadarModule, 
               AimAssistMod, 
               DmgMod0, 
               GestMod01, 
               ConvoMod01, 
               LookAtMod01, 
               AudioModule, 
               TimelineMod0
              )
    RotationRate = {Pitch = 0, Yaw = 0, Roll = 0}
    NetPriority = 1.79999995
    CollisionComponent = CollisionCylinder
    bIgnoreRigidBodyPawns = TRUE
}