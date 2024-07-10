Class SFXPawn_RampartMP extends SFXPawn
    placeable
    config(Game);

var Class<DamageType> BurnDamageType;
var Class<SFXRumble_MeleeHit> RumbleClass;
var Class<SFXCameraShakeBase> ScreenShakeClass;
var Guid MeleeBatonGUID;
var Guid AggressiveGuid;
var Guid ShieldGenGuid;
var Guid ShieldGUID;
var WwiseEvent BurnSound;
var WwiseEvent PlayDeathLoop;
var WwiseEvent StopDeathLoop;
var WwiseEvent ShieldsBreakSound;
var WwiseEvent ShieldsUpSound;
var RvrClientEffectInterface CE_DeathCrust;
var RvrClientEffectInterface CE_DeathImpact;
var RvrClientEffectInterface CE_MeleeBatonIn;
var RvrClientEffectInterface CE_MeleeBatonOut;
var RvrClientEffectInterface CE_AggressiveMode;
var WwiseEvent AggressiveSound;
var RvrClientEffectInterface CE_ShieldGenerator;
var editinline export StaticMeshComponent InvisShieldMesh;
var RvrClientEffectInterface CE_ShieldOn;
var Name ShieldSocket;
var float PlayerCooldown;
var float EnemyCooldown;
var float BurnDamage;
var float BurnAOERadius;
var float BurnTimeLeft;
var float BurnImpactInterval;
var float CoverDecayValue;
var transient float LastShieldTime;
var bool bIsBatonRetracted;
var bool bIsAggressive;
var transient bool bShieldActive;
var bool bDiedBySabotageExplode;
var bool bAggressive;
var bool bNeverTurnAggressive;

public event simulated function Destroyed()
{
    if (MeleeBatonGUID.A != 0 || MeleeBatonGUID.B != 0 || MeleeBatonGUID.C != 0 || MeleeBatonGUID.D != 0)
    {
        if (bIsBatonRetracted)
        {
            Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_MeleeBatonIn, MeleeBatonGUID, TRUE);
        }
        else
        {
            Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_MeleeBatonOut, MeleeBatonGUID, TRUE);
        }
    }
    if (AggressiveGuid.A != 0 || AggressiveGuid.B != 0 || AggressiveGuid.C != 0 || AggressiveGuid.D != 0)
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_AggressiveMode, AggressiveGuid, TRUE);
    }
}
public simulated function PlayHit(float Damage, Controller instigatedBy, Vector HitLocation, Class<DamageType> DamageType, Vector Momentum, TraceHitInfo HitInfo, Pawn DamageCauser)
{
    local float DamageVocProbMod;
    local SFXWeapon ChkWeapon;
    
    if (SFXGRI(WorldInfo.GRI) != None && GetHealthPct() < 0.200000003)
    {
        ChkWeapon = SFXWeapon(instigatedBy.Pawn.Weapon);
        if (ChkWeapon != None && ChkWeapon.__GetDamageVocProbabilityMod__Delegate != None)
        {
            DamageVocProbMod = ChkWeapon.__GetDamageVocProbabilityMod__Delegate();
        }
        else
        {
            DamageVocProbMod = 0.400000006;
        }
        SFXGRI(WorldInfo.GRI).TriggerVocalizationEvent(26, Self, BioPawn(instigatedBy.Pawn), 0.200000003, DamageVocProbMod);
    }
    Super.PlayHit(Damage, instigatedBy, HitLocation, DamageType, Momentum, HitInfo, DamageCauser);
}
public simulated function PostBeginPlay()
{
    local WwiseAudioComponent NewComp;
    
    Super.PostBeginPlay();
    bPreventPermanentDeath = TRUE;
    StartShieldGenerator();
    NewComp = Class'WwiseAudioComponent'.static.CreateComponentFromScript(Self, "_AnimNotify");
    if (NewComp != None)
    {
        SFXSetAudioComponentRTPCs(NewComp);
    }
}
public simulated function EPowerResistance GetPowerResistance(Pawn Caster, Vector HitLocation, Vector HitNormal, out float Damage, out Vector Force, Class<DamageType> DamageType, out Actor TargetOverride)
{
    if (bShieldActive)
    {
        return 0;
    }
    return Super.GetPowerResistance(Caster, HitLocation, HitNormal, Damage, Force, DamageType, TargetOverride);
}
public function bool Died(Controller Killer, Class<DamageType> DamageType, Vector HitLocation)
{
    if (SFXAI_Core(Controller) != None)
    {
        SFXAI_Core(Controller).SetCombatMood(3);
    }
    return Super.Died(Killer, DamageType, HitLocation);
}
public simulated function bool ModifyDamage(out float Damage, Vector Momentum, out DamageCalculationAlgorithm DamageCalc, const out TraceHitInfo HitInfo, Vector HitLocation, Class<SFXDamageType> DamageType, Controller instigatedBy, Actor DamageCauser)
{
    local SFXAI_RampartMP AI;
    
    if (Super(BioPawn).ModifyDamage(Damage, Momentum, DamageCalc, HitInfo, HitLocation, DamageType, instigatedBy, DamageCauser) == FALSE)
    {
        return FALSE;
    }
    if (Role == ENetRole.ROLE_Authority)
    {
        AI = SFXAI_RampartMP(Controller);
        if (AI != None)
        {
            if (bShieldActive && HitInfo.HitComponent == InvisShieldMesh)
            {
                Damage *= AI.ShieldDamageScalePct;
            }
            else if (HitInfo.HitComponent == Mesh && AI.CheckEvade(Damage, instigatedBy, DamageType))
            {
                Damage *= AI.EvadeDamageScalePct;
            }
        }
    }
    return TRUE;
}
public simulated function bool CanPlayDeathEffect()
{
    return FALSE;
}
public final simulated function AttachShieldMesh()
{
    if (Mesh != None)
    {
        Mesh.AttachComponent(InvisShieldMesh, ShieldSocket);
        ShieldGUID = Class'RvrClientEffectManager'.static.GetClientEffectManager().Start(CE_ShieldOn, Self);
    }
}
public simulated function BatonInFX()
{
    if (!IsDead())
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_MeleeBatonOut, MeleeBatonGUID, TRUE);
        MeleeBatonGUID = Class'RvrClientEffectManager'.static.GetClientEffectManager().Start(CE_MeleeBatonIn, Self);
        bIsBatonRetracted = TRUE;
    }
}
public simulated function BatonOutFX()
{
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_MeleeBatonIn, MeleeBatonGUID, TRUE);
    MeleeBatonGUID = Class'RvrClientEffectManager'.static.GetClientEffectManager().Start(CE_MeleeBatonOut, Self);
    bIsBatonRetracted = FALSE;
}
public simulated function CheckAIHacking()
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_AIHacking AIHack;
    
    Manager = GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        AIHack = SFXGameEffect_AIHacking(Manager.GetFirstEffectOfType(Class'SFXGameEffect_AIHacking'));
        if (AIHack != None && AIHack.bExplodeOnDeath)
        {
            bDiedBySabotageExplode = TRUE;
        }
    }
}
public final simulated function DetachShieldMesh()
{
    if (Mesh != None)
    {
        Mesh.DetachComponent(InvisShieldMesh);
        Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_ShieldOn, ShieldGUID, TRUE);
    }
}
public simulated function StartAggressiveFX()
{
    local MaterialInstanceConstant MIC;
    local MaterialInterface Parent;
    
    if (Mesh != None)
    {
        Parent = Mesh.SkeletalMesh.Materials[0];
        MIC = Mesh.CreateAndSetMaterialInstanceConstant(0);
        if (MIC != None)
        {
            MIC.SetParent(Parent);
            MIC.SetScalarParameterValue('Emissive_Override', 0.0);
            Mesh.m_aEffectsMaterialMICs.Length = 0;
        }
    }
    MeleeBatonGUID = Class'RvrClientEffectManager'.static.GetClientEffectManager().Start(CE_MeleeBatonIn, Self);
    AggressiveGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().Start(CE_AggressiveMode, Self);
    PlaySound(AggressiveSound);
    bIsAggressive = TRUE;
    bIsBatonRetracted = TRUE;
}
public simulated function StartDeathBurn()
{
    local RvrClientEffectTarget TargetInfo;
    local CoverSlotMarker CoverSlot;
    local SFXGame GameInfo;
    
    TargetInfo.SpawnValue.X = BurnTimeLeft;
    TargetInfo.Instigator = Self;
    Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(CE_DeathCrust, TargetInfo);
    PlaySound(PlayDeathLoop);
    foreach WorldInfo.RadiusNavigationPoints(Class'CoverSlotMarker', CoverSlot, location, BurnAOERadius)
    {
        GameInfo = SFXGame(WorldInfo.Game);
        if (GameInfo != None)
        {
            GameInfo.AddCoverDecay(CoverSlot, int(CoverDecayValue));
        }
    }
    SetTimer(BurnImpactInterval, FALSE, 'StartDeathImpacts', );
}

public simulated function StartDeathImpacts()
{
    local SFXPawn CollidingPawn;
    local SFXPlayerController PC;
    local bool bPawnCanBeImpacted;
    local Vector DoTParams;
    local SFXModule_GameEffectManager Manager;
    
    foreach WorldInfo.AllPawns(Class'SFXPawn', CollidingPawn, location, BurnAOERadius)
    {
        bPawnCanBeImpacted = TRUE;
        if (CollidingPawn != None)
        {
            if (Self == CollidingPawn || CollidingPawn.IsDead() || SFXPawn_Henchman(CollidingPawn) != None)
            {
                continue;
            }
            if (CollidingPawn != None && CollidingPawn.DrivenAtlas != None)
            {
                continue;
            }
            if (!FastTrace(CollidingPawn.location, location, , ))
            {
                continue;
            }
            if (SFXPawn_RampartMP(CollidingPawn) != None && SFXPawn_RampartMP(CollidingPawn).bAggressive)
            {
                continue;
            }
            Manager = CollidingPawn.GetModule(Class'SFXModule_GameEffectManager');
            if (Manager != None && Manager.HasEffectOfType(Class'SFXGameEffect_RampartBurn'))
            {
                bPawnCanBeImpacted = FALSE;
            }
            if (SFXGRI(WorldInfo.GRI).InCombat())
            {
                CollidingPawn.TakeDamage(BurnDamage, Controller, CollidingPawn.location, vect(0.0, 0.0, 0.0), BurnDamageType);
                if (bPawnCanBeImpacted)
                {
                    if (Manager != None)
                    {
                        if (SFXPawn_Player(CollidingPawn) != None)
                        {
                            Manager.CreateAndApplyEffect(Class'SFXGameEffect_RampartBurn', Name, PlayerCooldown, 1, 0.0, Controller);
                        }
                        else
                        {
                            Manager.CreateAndApplyEffect(Class'SFXGameEffect_RampartBurn', Name, EnemyCooldown, 1, 0.0, Controller);
                        }
                    }
                    PC = SFXPlayerController(CollidingPawn.Controller);
                    if (PC != None && PC.IsLocalPlayerController())
                    {
                        PC.ClientPlayForceFeedbackWaveform(RumbleClass.default.TheWaveForm);
                        if (PC.PlayerCamera != None)
                        {
                            SFXPlayerCamera(PC.PlayerCamera).AddScreenShake(ScreenShakeClass.default.TheShake);
                        }
                    }
                    CollidingPawn.PlaySound(BurnSound);
                    CollidingPawn.RequestReaction(0, Controller);
                    if (SFXPawn_Player(CollidingPawn) != None)
                    {
                        DoTParams.X = PlayerCooldown;
                    }
                    else
                    {
                        DoTParams.X = EnemyCooldown;
                    }
                    Class'RvrClientEffectManager'.static.GetClientEffectManager().Play(CE_DeathImpact, CollidingPawn, DoTParams);
                }
            }
        }
    }
    BurnTimeLeft -= BurnImpactInterval;
    if (BurnTimeLeft > 0.0)
    {
        SetTimer(BurnImpactInterval, FALSE, 'StartDeathImpacts', );
    }
    else
    {
        PlaySound(StopDeathLoop);
        bPreventPermanentDeath = FALSE;
    }
}
public final simulated function StartShield()
{
    if (Role == ENetRole.ROLE_Authority)
    {
        bShieldActive = TRUE;
    }
    AttachShieldMesh();
    PlaySound(ShieldsUpSound);
}
public simulated function StartShieldGenerator()
{
    ShieldGenGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().Start(CE_ShieldGenerator, Self);
}
public final simulated function StopShield()
{
    if (Role == ENetRole.ROLE_Authority)
    {
        bShieldActive = FALSE;
    }
    DetachShieldMesh();
    PlaySound(ShieldsBreakSound);
}
public simulated function StopShieldGenerator()
{
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_ShieldGenerator, ShieldGenGuid, TRUE);
}

simulated state Downed 
{
    
Begin:
    bAggressive = FALSE;
    CheckAIHacking();
    StopShieldGenerator();
    if (MeleeBatonGUID.A != 0 || MeleeBatonGUID.B != 0 || MeleeBatonGUID.C != 0 || MeleeBatonGUID.D != 0)
    {
        if (bIsBatonRetracted)
        {
            Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_MeleeBatonIn, MeleeBatonGUID, TRUE);
        }
        else
        {
            Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_MeleeBatonOut, MeleeBatonGUID, TRUE);
        }
        MeleeBatonGUID.A = 0;
        MeleeBatonGUID.B = 0;
        MeleeBatonGUID.C = 0;
        MeleeBatonGUID.D = 0;
    }
    if (AggressiveGuid.A != 0 || AggressiveGuid.B != 0 || AggressiveGuid.C != 0 || AggressiveGuid.D != 0)
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_AggressiveMode, AggressiveGuid, TRUE);
        AggressiveGuid.A = 0;
        AggressiveGuid.B = 0;
        AggressiveGuid.C = 0;
        AggressiveGuid.D = 0;
    }
    while (IsPlayingReaction())
    {
        Sleep(0.100000001);
    }
    InterruptCustomAction();
    if (Physics != EPhysics.PHYS_RigidBody && bCanRagdoll)
    {
        if (!InitRagdoll())
        {
            WarnInternal("BioPawn" @ Self @ "failed InitRagdoll in Downed state's Begin.");
        }
    }
    SetCollision(FALSE, FALSE, );
    Mesh.SetActorCollision(FALSE, FALSE);
    if (!bDiedBySabotageExplode)
    {
        SetTimer(2.0, FALSE, 'StartDeathBurn', );
    }
    ThrowWeaponOnDeath();
    while (bPreventPermanentDeath)
    {
        Sleep(1.0);
    }
    while (WorldInfo.Game == None || SFXGame(WorldInfo.Game).PreventPermanentDeath(Self))
    {
        Sleep(1.0);
    }
    bCanDropAmmo = FALSE;
    bCanRagdoll = FALSE;
    TearOffMomentum = vect(0.0, 0.0, 0.0);
    Global.Died(KilledBy, KilledByDamageType, KilledByHitLocation);
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    Begin Template Class=BioDynamicLightEnvironmentComponent Name=BioLightEnvComponent0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=BioPawnSkeletalMeshComponent
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=HeadMesh0
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
    Begin Template Class=SkeletalMeshComponent Name=GearMesh0
        ParentAnimComponent = BioPawnSkeletalMeshComponent
        ShadowParent = BioPawnSkeletalMeshComponent
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
    End Template
    Begin Object Class=StaticMeshComponent Name=ShieldMesh0
        StaticMesh = StaticMesh'biog_mch_lok_r.Shield.RampartShieldMesh'
        ReplacementPrimitive = None
        BlockActors = FALSE
        PhysMaterialOverride = PhysicalMaterial'biovfx_exp2_env_shields.Physics.PHM_GEN_Shields_Red'
        Scale3D = {X = 0.733299971, Y = 0.733299971, Z = 1.15180004}
    End Object
    Begin Template Class=ForceFeedbackWaveform Name=FootstepShakeFF0
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_Radar Name=RadarModule
    End Template
    Begin Template Class=SFXModule_AimAssistTarget Name=AimAssistMod
    End Template
    Begin Template Class=SFXModule_Damage Name=DmgMod0
        HealthType = EHealthType.HealthType_Armour
    End Template
    Begin Template Class=SFXModule_Gestures Name=GestMod01
        Begin Template Class=BioGestureAnimSetMgr Name=oAnimSetMgr
        End Template
        m_pAnimSetMgr = oAnimSetMgr
    End Template
    Begin Template Class=SFXModule_Conversation Name=ConvoMod01
        m_bDisableFacefx = TRUE
    End Template
    Begin Template Class=SFXModule_LookAt Name=LookAtMod01
    End Template
    Begin Template Class=SFXModule_Audio Name=AudioModule
    End Template
    Begin Template Class=SFXModule_Timeline Name=TimelineMod0
    End Template
    Begin Object Class=SFXModule_Armour Name=BattleDamage0
    End Object
    Begin Object Class=SFXLoadoutData Name=RampartLoadout0
        Weapons = (Class'SFXWeapon_AI_Katana')
    End Object
    Begin Template Class=SFXPowerManager Name=PowerMgr
    End Template
    BurnDamageType = Class'SFXDamageType_RampartBurn'
    RumbleClass = Class'SFXRumble_MeleeHit'
    ScreenShakeClass = Class'SFXShake_MeleeHit'
    BurnSound = WwiseEvent'Wwise_Crt_DLC_Omega_Rampart.Play_crt_rampart_overload_impact'
    PlayDeathLoop = WwiseEvent'Wwise_Crt_DLC_Omega_Rampart.Play_crt_rampart_overload_loop'
    StopDeathLoop = WwiseEvent'Wwise_Crt_DLC_Omega_Rampart.Play_crt_rampart_overload_loop_stop'
    ShieldsBreakSound = WwiseEvent'Wwise_Crt_DLC_Omega_Rampart.Play_crt_omega_rampart_shield_down'
    ShieldsUpSound = WwiseEvent'Wwise_Crt_DLC_Omega_Rampart.Play_crt_omega_rampart_shield_up'
    CE_DeathCrust = RvrClientEffect'biovfx_exp2_rampartmech_lok.VCFX.Shield_Plasma_Fire_VCFX'
    CE_DeathImpact = RvrClientEffect'biovfx_exp2_rampartmech_lok.VCFX.PlasmaFire_Dot_VCFX'
    CE_MeleeBatonIn = RvrClientEffect'biovfx_exp2_rampartmech_lok.VCFX.Lok_AggressiveMode_Baton_In_VCFX'
    CE_MeleeBatonOut = RvrClientEffect'biovfx_exp2_rampartmech_lok.VCFX.Lok_AggressiveMode_Baton_Out2_VCFX'
    CE_AggressiveMode = RvrClientEffectMulti'biovfx_exp2_rampartmech_lok.VCFX.Lok_AggressiveMode_M_VCFX'
    AggressiveSound = WwiseEvent'Wwise_Crt_DLC_Omega_Rampart.Play_crt_omega_rampart_agro_start'
    CE_ShieldGenerator = RvrClientEffect'biovfx_exp2_rampartmech_lok.VCFX.Lok_ShieldCharge_VCFX'
    InvisShieldMesh = ShieldMesh0
    CE_ShieldOn = RvrClientEffect'biovfx_exp2_rampartmech_lok.VCFX.Lok_Shielding_VCFX'
    ShieldSocket = 'God'
    PlayerCooldown = 1.5
    EnemyCooldown = 3.0
    BurnDamage = 25.0
    BurnAOERadius = 115.0
    BurnImpactInterval = 0.200000003
    CoverDecayValue = 5000.0
    PowerImpactNotifications = ({Label = 'BioticShield', TimeBeforeImpact = 0.75}
                               )
    PS_HeadGib = ParticleSystem'biovfx_exp2_rampartmech_lok.Particles.Rmp_MCH_HeadGib'
    MeleedVoc = WwiseEvent'Wwise_Crt_DLC_Omega_Rampart.Play_crt_rampart_pain'
    FootstepForceFeedback = FootstepShakeFF0
    CodexPlotState = 21718
    bCanPartialLean = TRUE
    bCanUseTurrets = TRUE
    bCanDriveAtlas = TRUE
    CustomActionClasses = (None, 
                           Class'SFXCustomAction_Ragdoll', 
                           None, 
                           Class'SFXCustomAction_SyncPawnPartner_Base', 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_Frozen', 
                           Class'SFXCustomAction_Reload', 
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
                           Class'SFXCustomAction_StandingGapJump', 
                           None, 
                           Class'SFXCustomAction_JumpDown', 
                           Class'SFXCustomAction_AIMantleOverCover', 
                           None, 
                           Class'SFXCustomAction_AIMantleUp', 
                           None, 
                           Class'SFXCustomAction_MoveAlongCover', 
                           Class'SFXCustomAction_CoverSlipLeft', 
                           Class'SFXCustomAction_CoverSlipLeftStanding', 
                           Class'SFXCustomAction_CoverSlipRight', 
                           Class'SFXCustomAction_CoverSlipRightStanding', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_AILadderClimbUp', 
                           Class'SFXCustomAction_AILadderClimbDown', 
                           Class'SFXCustomAction_BoostDown', 
                           Class'SFXCustomAction_BoostUp', 
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
                           Class'SFXCustomAction_StandardImpact', 
                           Class'SFXCustomAction_StandardImpactII', 
                           Class'SFXCustomAction_StandardImpactForward', 
                           Class'SFXCustomAction_StandardImpactLeft', 
                           Class'SFXCustomAction_StandardImpactRight', 
                           Class'SFXCustomAction_StandardImpactKnee', 
                           None, 
                           Class'SFXCustomAction_StaggerImpactII', 
                           Class'SFXCustomAction_StaggerImpactForward', 
                           Class'SFXCustomAction_StaggerImpactLeft', 
                           Class'SFXCustomAction_StaggerImpactRight', 
                           Class'SFXCustomAction_KnockbackImpact', 
                           Class'SFXCustomAction_KnockbackImpactForward', 
                           Class'SFXCustomAction_KnockbackImpactLeft', 
                           Class'SFXCustomAction_KnockbackImpactRight', 
                           Class'SFXCustomAction_Meleed', 
                           Class'SFXCustomAction_MeleedForward', 
                           Class'SFXCustomAction_MeleedLeft', 
                           Class'SFXCustomAction_MeleedRight', 
                           Class'SFXCustomAction_ShieldBreach', 
                           Class'SFXCustomAction_FlinchLight', 
                           Class'SFXCustomAction_FlinchHeavy', 
                           None, 
                           None, 
                           Class'SFXCustomAction_GreatPain', 
                           Class'SFXCustomAction_GreatPainII', 
                           Class'SFXCustomAction_Freezing', 
                           Class'SFXCustomAction_FreezingII', 
                           Class'SFXCustomAction_FreezingIII', 
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
                           Class'SFXCustomAction_RampartMPMelee', 
                           None, 
                           None, 
                           Class'SFXCustomAction_TrooperStomp', 
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
                           Class'SFXCustomAction_RampartMPShield', 
                           None, 
                           Class'SFXCustomAction_RampartMPAggressive', 
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
                           Class'SFXCustomAction_IdleStandGuard', 
                           Class'SFXCustomAction_IdleInspectWeapon', 
                           None, 
                           None, 
                           Class'SFXCustomAction_IdleUseConsole', 
                           Class'SFXCustomAction_IdleTalking', 
                           Class'SFXCustomAction_IdleTalking2', 
                           Class'SFXCustomAction_IdleTalking3', 
                           Class'SFXCustomAction_IdleListening', 
                           Class'SFXCustomAction_IdleListening2', 
                           Class'SFXCustomAction_IdleListening3'
                          )
    SupportedCustomReachSpecs = (Class'SFXBoostReachSpec', Class'SFXLadderReachSpec', Class'SFXJumpReachSpec', Class'SFXJumpDownReachSpec')
    SupportedSyncActions = ('AtlasSync', 'PhantomSync', 'KaiLengSync', 'HuskSync', 'BruteSync', 'BansheeSync')
    CombatVocVariants = (SFXVocalizationBank'aibarks_dlc_exp_pack002.ss_rampart')
    AimNodes = ('None', 
                'Head', 
                'LeftShoulder', 
                'RightShoulder', 
                'Chest2', 
                'Pelvis', 
                'LeftKnee', 
                'RightKnee'
               )
    ReactionBones = ({
                      BoneNames = ('LeftHip', 'LeftKnee'), 
                      BodyPart = 'LeftLeg'
                     }, 
                     {
                      BoneNames = ('RightHip', 'RightKnee'), 
                      BodyPart = 'RightLeg'
                     }, 
                     {
                      BoneNames = ('LeftShoulder', 'LeftElbow'), 
                      BodyPart = 'LeftArm'
                     }, 
                     {
                      BoneNames = ('RightShoulder', 'RightElbow'), 
                      BodyPart = 'RightArm'
                     }, 
                     {
                      BoneNames = ('Root', 'LowerBack', 'Chest'), 
                      BodyPart = 'Chest'
                     }, 
                     {
                      BoneNames = ('Neck'), 
                      BodyPart = 'Head'
                     }
                    )
    HeadMesh = HeadMesh0
    m_oHairMesh = HairMesh0
    m_oHeadGearMesh = GearMesh0
    LightEnvironment = BioLightEnvComponent0
    DyingSound = WwiseEvent'Wwise_Crt_DLC_Omega_Rampart.Play_crt_rampart_death_explode'
    Loadout = RampartLoadout0
    PowerManager = PowerMgr
    BloodColor = {B = 0, G = 0, R = 0, A = 255}
    bAffectedByRagdollPowers = FALSE
    bCanPortArms = FALSE
    RaceType = ERaceType.RaceType_Machine
    AffiliationType = EAffiliationType.AffiliationType_Cerberus
    ControllerClass = Class'SFXAI_RampartMP'
    Mesh = BioPawnSkeletalMeshComponent
    CylinderComponent = CollisionCylinder
    EyeHeight = 80.0
    bCanMantle = TRUE
    bCanClimbUp = TRUE
    bCanCoverSlip = TRUE
    Components = (CollisionCylinder, None, BioLightEnvComponent0, BioPawnSkeletalMeshComponent, HeadMesh0, HairMesh0, GearMesh0)
    Modules = (GEMod0, 
               RadarModule, 
               AimAssistMod, 
               DmgMod0, 
               GestMod01, 
               ConvoMod01, 
               LookAtMod01, 
               AudioModule, 
               TimelineMod0, 
               BattleDamage0
              )
    CollisionComponent = CollisionCylinder
}