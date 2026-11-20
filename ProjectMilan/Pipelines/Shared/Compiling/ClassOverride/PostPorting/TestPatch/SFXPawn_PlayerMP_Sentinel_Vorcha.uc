// Source: ME3, Patch_SFXPawnPlayerMPSentinelVorcha
// Decompiled 11/17/2026 7:38:03 AM against Vorcha_Sentinel_MP.pcc
Class SFXPawn_PlayerMP_Sentinel_Vorcha extends SFXPawn_PlayerMP_Sentinel
    placeable
    config(Game);

var array<SFXPawn> PawnsKilled;
var config float PollFrequency;
var SFXPowerCustomActionMP_Bloodlust PowerBloodlust;

public simulated function PostBeginPlay()
{
    Super(SFXPawn_PlayerMP).PostBeginPlay();
    PowerBloodlust = SFXPowerCustomActionMP_Bloodlust(PowerManager.GetPowerByClass(Class'SFXPowerCustomActionMP_Bloodlust'));
    if (PowerBloodlust != None && Role == ENetRole.ROLE_Authority)
    {
        SetTimer(PollFrequency, TRUE, 'CheckForKills', );
    }
}
public function PlayerCoverAcquired(CoverLink.CovPosInfo CovInfo, byte SlotIdx)
{
    if (CurrentCustomAction == 132 && CurrentPowerCustomAction == 6 && PowerManager != None)
    {
        InterruptCustomAction();
    }
    Super(SFXPawn_Player).PlayerCoverAcquired(CovInfo, SlotIdx);
}
public simulated function bool StartPowerCustomAction(int PowerCustomAction, Object Target, Object.Vector TargetLocation, optional bool bForced)
{
    local SFXPowerCustomActionMP_Flamer FLAMER;
    
    FLAMER = SFXPowerCustomActionMP_Flamer(PowerCustomActions[PowerCustomAction]);
    if (FLAMER != None)
    {
        if (IsPerformingCustomAction() == TRUE && CurrentCustomAction == 132 && CurrentPowerCustomAction == 6)
        {
            InterruptCustomAction();
            return FALSE;
        }
    }
    return Super(BioPawn).StartPowerCustomAction(PowerCustomAction, Target, TargetLocation, bForced);
}
public function CheckForKills()
{
    local SFXPawn oPawn;
    
    PawnsKilled.RemoveItem(None);
    foreach WorldInfo.AllPawns(Class'SFXPawn', oPawn)
    {
        if (PawnsKilled.Find(oPawn) != -1 || oPawn.bIsPet)
        {
            continue;
        }
        if (oPawn.IsDead() && oPawn.ReplicatedDeathInfo.KillerPawn == Self)
        {
            PawnsKilled.AddItem(oPawn);
            if (PowerBloodlust != None && PowerBloodlust.IsActive)
            {
                PowerBloodlust.IncreaseBloodlustCount();
            }
        }
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
        MaxHealth = {X = 750.0, Y = 750.0}
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
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
    Modules = (GEMod0, 
               RadarModule, 
               AimAssistMod, 
               GestMod01, 
               ConvoMod01, 
               LookAtMod01, 
               AudioModule, 
               TimelineMod0, 
               Locomotion0, 
               DmgMod1, 
               SFXModule_MarkerObjective0
              )
    CollisionComponent = CollisionCylinder
}