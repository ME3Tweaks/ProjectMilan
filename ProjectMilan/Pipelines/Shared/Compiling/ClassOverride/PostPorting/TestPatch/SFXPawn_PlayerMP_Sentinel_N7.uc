// Source: ME3, Patch_SFXPawn_PlayerMP_Sentinel_N7
// Decompiled 11/17/2026 7:38:02 AM against N7_Sentinel_MP.pcc
Class SFXPawn_PlayerMP_Sentinel_N7 extends SFXPawn_PlayerMP_Sentinel
    placeable
    config(Game);

var Name Socket_Shield;
var SFXN7SentinelShield Actor_Shield;
var instanced StaticMeshComponent SMC_Shield;
var config float ShieldBreakForce;
var clearcrosslevel SFXCustomAction_N7SentinelShield N7SentinelSentinelShieldCA;
var BioCustomAction NextCustomAction;
var WwiseEvent ShieldsHitSound;
var bool bShieldActive;

public simulated function Destroyed()
{
    Super(SFXPawn_PlayerMP).Destroyed();
    if (bShieldActive && Actor_Shield != None)
    {
        Actor_Shield.PlayBurstVFX();
    }
    bShieldActive = FALSE;
}
public simulated function PostBeginPlay()
{
    local Object.Vector ShieldLocation;
    local Object.Rotator ShieldRotation;
    
    Super(SFXPawn_PlayerMP).PostBeginPlay();
    Mesh.GetSocketWorldLocationAndRotation(Socket_Shield, ShieldLocation, ShieldRotation);
    if (Role == ENetRole.ROLE_Authority)
    {
        Actor_Shield = Spawn(Class'SFXN7SentinelShield', Self, , ShieldLocation, ShieldRotation);
        if (Actor_Shield == None)
        {
            return;
        }
    }
    if (SMC_Shield != None)
    {
        Mesh.AttachComponentToSocket(SMC_Shield, Socket_Shield);
    }
    DeferredSetupShield();
}
public event simulated function bool StartCustomAction(int NewAction, optional Pawn Sync, optional bool bForced, optional int PowerCustomAction)
{
    if (NewAction == 132)
    {
        NextCustomAction = PowerCustomActions[PowerCustomAction];
    }
    else if (VerifyCAHasBeenInstanced(NewAction))
    {
        NextCustomAction = CustomActions[NewAction];
    }
    return Super(BioPawn).StartCustomAction(NewAction, Sync, bForced, PowerCustomAction);
}
public simulated function TakeDamage(float DamageAmount, Controller EventInstigator, Object.Vector HitLocation, Object.Vector Momentum, Class<DamageType> DamageType, optional Actor.TraceHitInfo HitInfo, optional Actor DamageCauser)
{
    local bool bShieldDepleted;
    local SFXCustomAction_N7SentinelBash N7SentinelBashCA;
    
    if (bShieldActive == TRUE && Actor_Shield != None)
    {
        if (HitInfo.HitComponent == SMC_Shield)
        {
            Actor_Shield.UpdateShieldDamage(DamageAmount);
            PlaySound(ShieldsHitSound, TRUE);
            DamageAmount = 0.0;
        }
        bShieldDepleted = Actor_Shield.ApplyDamage(DamageAmount, HitInfo, HitLocation, Momentum, DamageType, EventInstigator, DamageCauser);
    }
    if (bShieldDepleted)
    {
        if (Role == ENetRole.ROLE_Authority)
        {
            if (CurrentCustomAction == 149)
            {
                if (CustomActions.Length > 149)
                {
                    N7SentinelBashCA = SFXCustomAction_N7SentinelBash(CustomActions[149]);
                    if (N7SentinelBashCA != None)
                    {
                        N7SentinelBashCA.CancelByShieldDestruction();
                    }
                }
            }
            if (RequestReaction(2, EventInstigator, ShieldBreakForce * -Normal(Vector(Rotation))))
            {
                ReplicateAnimatedReaction(CurrentCustomAction);
            }
        }
    }
    else
    {
        Super(BioPawn).TakeDamage(DamageAmount, EventInstigator, HitLocation, Momentum, DamageType, HitInfo, DamageCauser);
    }
}
public simulated function TakeRadiusDamage(Controller instigatedBy, float BaseDamage, float DamageRadius, Class<DamageType> DamageType, float Momentum, Object.Vector HurtOrigin, bool bFullDamage, Actor DamageCauser, optional float DamageFalloffExponent = 1.0, optional Actor.TraceHitInfo HitInfo)
{
    if (bShieldActive == TRUE && Actor_Shield != None)
    {
        Actor_Shield.ApplyRadiusDamage(BaseDamage, HitInfo, HurtOrigin, Momentum, DamageType, instigatedBy, DamageCauser);
    }
    Super(SFXPawn).TakeRadiusDamage(instigatedBy, BaseDamage, DamageRadius, DamageType, Momentum, HurtOrigin, bFullDamage, DamageCauser, DamageFalloffExponent, HitInfo);
}
public simulated function Actor.EPowerResistance GetPowerResistance(Pawn Caster, Object.Vector HitLocation, Object.Vector HitNormal, out float Damage, out Object.Vector Force, Class<DamageType> DamageType, out Actor TargetOverride)
{
    local float DotAngle;
    
    if (bShieldActive)
    {
        DotAngle = Normal(HitLocation - location) Dot Vector(Rotation);
        if (DotAngle > Actor_Shield.ShieldArc)
        {
            return 0;
        }
    }
    return Super(SFXPawn_PlayerParty).GetPowerResistance(Caster, HitLocation, HitNormal, Damage, Force, DamageType, TargetOverride);
}
public function PossessedBy(Controller C, bool bVehicleTransition)
{
    Super(SFXPawn_PlayerMP).PossessedBy(C, bVehicleTransition);
}
public function PlayerCoverAcquired(CoverLink.CovPosInfo CovInfo, byte SlotIdx)
{
    local BioCustomAction CurrentAction;
    local SFXCustomAction_N7SentinelShield SentinelShieldAction;
    
    if (CurrentCustomAction == 58 || CurrentCustomAction == 73)
    {
        GetCurrentCustomAction(CurrentAction);
        SentinelShieldAction = SFXCustomAction_N7SentinelShield(CurrentAction);
        if (SentinelShieldAction != None)
        {
            SentinelShieldAction.InterruptThisCustomAction();
        }
    }
    Super(SFXPawn_Player).PlayerCoverAcquired(CovInfo, SlotIdx);
}
public simulated function StartShield()
{
    if (!bShieldActive && Actor_Shield != None)
    {
        Actor_Shield.StartShield();
    }
    bShieldActive = TRUE;
}
public simulated function DeferredSetupShield()
{
    if (PlayerReplicationInfo != None && Actor_Shield != None)
    {
        if (IsLocallyControlled() == FALSE)
        {
            Actor_Shield.SwitchToNonPlayerMaterial();
        }
    }
    else
    {
        SetTimer(0.100000001, FALSE, 'DeferredSetupShield', );
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=BioDynamicLightEnvironmentComponent Name=BioLightEnvComponent0
    End Template
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=CoverEnterSound0
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=FootstepShakeFF0
    End Template
    Begin Template Class=SFXCustomizationInstance_PlayerMP Name=AppInstanceMP0
    End Template
    Begin Template Class=SFXModule_AimAssistTarget Name=AimAssistMod
    End Template
    Begin Template Class=SFXModule_Audio Name=AudioModule
    End Template
    Begin Template Class=SFXModule_Conversation Name=ConvoMod01
    End Template
    Begin Template Class=SFXModule_DamagePlayer Name=DmgMod1
    End Template
    Begin Object Class=SFXModule_GameEffectManager_N7Sentinel Name=GEManager0
    End Object
    Begin Template Class=SFXModule_Gestures Name=GestMod01
        Begin Template Class=BioGestureAnimSetMgr Name=oAnimSetMgr
        End Template
        m_pAnimSetMgr = oAnimSetMgr
    End Template
    Begin Template Class=SFXModule_Locomotion Name=Locomotion0
    End Template
    Begin Template Class=SFXModule_LookAt Name=LookAtMod01
    End Template
    Begin Template Class=SFXModule_MarkerPlayer Name=SFXModule_MarkerObjective0
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
    Begin Object Class=StaticMeshComponent Name=ShieldComponent0
        StaticMesh = StaticMesh'BioVFX_MP3_OmniShield.Meshes.Omni_Shield'
        ReplacementPrimitive = None
        HiddenGame = TRUE
        BlockNonZeroExtent = FALSE
    End Object
    Socket_Shield = 'Socket_01'
    SMC_Shield = ShieldComponent0
    ShieldsHitSound = WwiseEvent'Wwise_Generic_Bullet_Impacts.Play_bullet_impact_closecall_impact_player'
    CustomizationMP = AppInstanceMP0
    CoverForceFeedback = CoverEnterSound0
    FootstepForceFeedback = FootstepShakeFF0
    HeadMesh = HeadMesh0
    m_oHairMesh = HairMesh0
    m_oHeadGearMesh = GearMesh0
    LightEnvironment = BioLightEnvComponent0
    PowerManager = PowerMgr
    Mesh = BioPawnSkeletalMeshComponent
    CylinderComponent = CollisionCylinder
    Components = (CollisionCylinder, None, BioLightEnvComponent0, BioPawnSkeletalMeshComponent, HeadMesh0, HairMesh0, GearMesh0)
    Modules = (RadarModule, 
               AimAssistMod, 
               GestMod01, 
               ConvoMod01, 
               LookAtMod01, 
               AudioModule, 
               TimelineMod0, 
               Locomotion0, 
               DmgMod1, 
               SFXModule_MarkerObjective0, 
               GEManager0
              )
    CollisionComponent = CollisionCylinder
}