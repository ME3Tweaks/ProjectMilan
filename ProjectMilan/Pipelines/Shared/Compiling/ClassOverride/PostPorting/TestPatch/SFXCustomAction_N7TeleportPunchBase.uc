// Source: ME3, Patch_SFXCustActnN7TpPunchBase
// Decompiled 11/17/2026 7:37:44 AM against N7_Adept_MP.pcc
Class SFXCustomAction_N7TeleportPunchBase extends SFXCustomAction_PlayerHeavyMeleeBase
    config(Game);

var Object.Guid CloakEffectGuid;
var Object.Vector TeleportLocation;
var RvrClientEffectInterface CE_CloakEffect;
var float CameraTransitionMax;
var float CameraTransitionMin;
var SFXCameraTransition_N7VanguardPunch CamTransition;
var config float StopSyncTargetDuration;
var config float NoTargetTeleportDistance;
var config float NavPointSearchRange;
var config float HeightNavCheckDistance;
var config float BarrierReduction;
var config float ExtraDistFromTarget;
var bool bCloakEffectStarted;
var bool bFoundTeleportLocation;

public function StartCustomAction()
{
    local SFXModule_GameEffectManager Manager;
    local SFXShield_Base Shield;
    local float fCurrentShields;
    local float fUpdatedShields;
    local bool bCurrentShieldsBreached;
    
    if (m_oPawn.Role < ENetRole.ROLE_Authority && InternalCanDoCustomAction(None, TRUE) == FALSE)
    {
        InterruptThisCustomAction();
        return;
    }
    if (m_oPawn.SyncPawn != None)
    {
        SyncPartner = BioPawn(m_oPawn.SyncPawn);
    }
    Shield = m_oPawn.GetShields();
    if (Shield != None)
    {
        fCurrentShields = Shield.GetCurrentShields();
        bCurrentShieldsBreached = fCurrentShields <= 0.0;
        fUpdatedShields = FClamp(fCurrentShields - Shield.GetMaxShields() * BarrierReduction, bCurrentShieldsBreached ? 0.0 : 0.00999999978, Shield.GetMaxShields());
        Shield.SetCurrentShields(fUpdatedShields);
        Shield.ResetShieldRegenTimer();
    }
    if (m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        if (SyncPartner != None)
        {
            bFoundTeleportLocation = FindTeleportLocationWithTarget(SyncPartner, TeleportLocation);
            if (!bFoundTeleportLocation)
            {
                TeleportLocation = vect(0.0, 0.0, 0.0);
            }
        }
        else
        {
            bFoundTeleportLocation = FindTeleportLocation(TeleportLocation);
            if (!bFoundTeleportLocation)
            {
                TeleportLocation = vect(0.0, 0.0, 0.0);
            }
        }
    }
    if (SyncPartner != None)
    {
        Manager = SyncPartner.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None)
        {
            Manager.CreateAndApplyEffect(Class'SFXGameEffect_MovementSpeedBonus', Name, StopSyncTargetDuration, 1, -1.0, m_oPawn.Controller);
        }
    }
    Super.StartCustomAction();
}
public function bool CanInteractWithPawn(BioPawn OtherPawn)
{
    if (OtherPawn == None || OtherPawn.IsDead() || OtherPawn.Physics == EPhysics.PHYS_Falling || bAffectsFriendlies == FALSE && m_oPawn.IsHostile(OtherPawn) == FALSE)
    {
        return FALSE;
    }
    return TRUE;
}
public function ClientDoCustomAction(optional bool bForced)
{
    if (m_oPawn != None)
    {
        TeleportLocation = m_oPawn.ReplicatedCustomActionInfo.TargetLocation;
        bFoundTeleportLocation = TeleportLocation != vect(0.0, 0.0, 0.0);
    }
    Super(BioCustomAction).ClientDoCustomAction(bForced);
}
public function EndAction()
{
    InterruptThisCustomAction();
}
public function BioPawn GetVictimPawn()
{
    local BioPawn FoundPawn;
    local BioPawn BestSoFar;
    local Object.Vector VectToFoundPawn;
    
    BestSoFar = None;
    foreach m_oPawn.CollidingActors(Class'BioPawn', FoundPawn, MaxPartnerDistance, m_oPawn.location, , , )
    {
        if (FoundPawn != m_oPawn && CanInteractWithPawn(FoundPawn))
        {
            VectToFoundPawn = FoundPawn.location - m_oPawn.location;
            if (Normal(VectToFoundPawn) Dot Vector(m_oPawn.Rotation) >= SyncCone)
            {
                if (Abs(VectToFoundPawn.Z) < m_oPawn.CylinderComponent.CollisionHeight * 0.800000012 || Abs(VectToFoundPawn.Z) < 200.0 && Abs(Normal(VectToFoundPawn).Z) < m_oPawn.WalkableFloorZ)
                {
                    if (GetPawnScore(FoundPawn) > GetPawnScore(BestSoFar))
                    {
                        BestSoFar = FoundPawn;
                    }
                }
            }
        }
    }
    return BestSoFar;
}
protected function bool InternalCanDoCustomAction(BioPawn SyncPawn, bool bForced)
{
    if (m_oPawn == None || m_oPawn.IsDead() || m_oPawn.Physics == EPhysics.PHYS_RigidBody)
    {
        return FALSE;
    }
    if (m_oPawn.IsInState('InRagdoll', ) || m_oPawn.IsInState('RagdollRecovery', ))
    {
        return FALSE;
    }
    return Super(SFXCustomAction_ProceduralSync).InternalCanDoCustomAction(SyncPawn, bForced);
}
public function Replicate()
{
    Super(SFXCustomAction_ProceduralSync).Replicate();
    if (m_oPawn != None)
    {
        m_oPawn.ReplicatedCustomActionInfo.TargetLocation = TeleportLocation;
    }
}
public function StopCustomAction()
{
    StopTeleportVFX();
    Super.StopCustomAction();
}
public function StopMove()
{
    bStopOnImpact = TRUE;
}
public function bool FindTeleportLocation(out Object.Vector NewLocation)
{
    local Object.Vector OriginalLoc;
    local NavigationPoint N;
    local Actor PathFindResult;
    local PlayerController PC;
    
    PC = PlayerController(m_oPawn.Controller);
    if (PC == None)
    {
        return FALSE;
    }
    OriginalLoc = m_oPawn.location + Vector(m_oPawn.Rotation) * NoTargetTeleportDistance;
    NewLocation = OriginalLoc;
    N = GetNearestNavPoint(NewLocation);
    if (N == None || m_oPawn.FindNearestOpenLocation(NewLocation, NewLocation) == FALSE)
    {
        NewLocation = OriginalLoc;
        NewLocation.Z += HeightNavCheckDistance;
        N = GetNearestNavPoint(NewLocation);
        if (N == None || m_oPawn.FindNearestOpenLocation(NewLocation, NewLocation) == FALSE)
        {
            NewLocation = OriginalLoc;
            NewLocation.Z -= HeightNavCheckDistance;
            N = GetNearestNavPoint(NewLocation);
            if (N == None || m_oPawn.FindNearestOpenLocation(NewLocation, NewLocation) == FALSE)
            {
                return FALSE;
            }
        }
    }
    if (Class'Goal_AtActor'.static.AtActor(m_oPawn, N, 0.0, FALSE))
    {
        Class'Path_TowardGoal'.static.TowardGoal(m_oPawn, N);
        PathFindResult = PC.FindPathToward(N, , , );
        if (PathFindResult == None)
        {
            return FALSE;
        }
    }
    NewLocation = N.location;
    return TRUE;
}
public function bool FindTeleportLocationWithTarget(BioPawn oTarget, out Object.Vector NewLocation)
{
    local float fDistance;
    local Object.Vector HitLocation;
    local Object.Vector HitNormal;
    local Object.Vector TraceStart;
    local Object.Vector TraceEnd;
    local Object.Vector ToCaster;
    local Actor.TraceHitInfo HitInfo;
    local NavigationPoint TargetAnchor;
    local float fDist;
    local Actor PathFindResult;
    local PlayerController PC;
    
    if (oTarget == None)
    {
        return FALSE;
    }
    PC = PlayerController(m_oPawn.Controller);
    if (PC == None)
    {
        return FALSE;
    }
    if (!m_oPawn.IsHostile(oTarget))
    {
        return FALSE;
    }
    if (m_oPawn.Anchor == None)
    {
        TargetAnchor = m_oPawn.GetBestAnchor(m_oPawn, m_oPawn.location, TRUE, TRUE, fDist);
        if (TargetAnchor == None)
        {
            return FALSE;
        }
        m_oPawn.SetAnchor(TargetAnchor);
    }
    if (oTarget.Anchor == None)
    {
        TargetAnchor = oTarget.GetBestAnchor(oTarget, oTarget.location, TRUE, TRUE, fDist);
        if (TargetAnchor == None)
        {
            return FALSE;
        }
        oTarget.SetAnchor(TargetAnchor);
    }
    TargetAnchor = oTarget.Anchor;
    if (Class'Goal_AtActor'.static.AtActor(m_oPawn, TargetAnchor, 0.0, FALSE))
    {
        Class'Path_TowardGoal'.static.TowardGoal(m_oPawn, TargetAnchor);
        PathFindResult = PC.FindPathToward(TargetAnchor, , , );
        if (PathFindResult == None)
        {
            return FALSE;
        }
    }
    fDistance = oTarget.GetCollisionRadius() + m_oPawn.GetCollisionRadius() + ExtraDistFromTarget;
    ToCaster = m_oPawn.location - oTarget.location;
    ToCaster.Z = 0.0;
    ToCaster = Normal(ToCaster);
    NewLocation = oTarget.location + ToCaster * fDistance;
    NewLocation.Z -= oTarget.GetCollisionHeight() - m_oPawn.GetCollisionHeight();
    TraceStart = NewLocation;
    TraceEnd = NewLocation;
    TraceEnd.Z -= 200.0;
    if (m_oPawn.Trace(HitLocation, HitNormal, TraceEnd, TraceStart, TRUE, m_oPawn.GetCollisionExtent(), HitInfo, ) == None)
    {
        return FALSE;
    }
    if (m_oPawn.FindNearestOpenLocation(NewLocation, NewLocation, oTarget))
    {
        return TRUE;
    }
    else
    {
        return FALSE;
    }
}
public function NavigationPoint GetNearestNavPoint(Object.Vector vLocation)
{
    local NavigationPoint N;
    local NavigationPoint BestNav;
    local float Distance;
    local float BestDistance;
    
    foreach m_oPawn.WorldInfo.RadiusNavigationPoints(Class'NavigationPoint', N, vLocation, NavPointSearchRange)
    {
        if (N != None && N.IsUsableAnchorFor(m_oPawn))
        {
            Distance = VSize(N.location - vLocation);
            if (BestNav == None || Distance < BestDistance)
            {
                BestDistance = Distance;
                BestNav = N;
            }
        }
    }
    return BestNav;
}
public function StartTeleportVFX()
{
    local RvrClientEffectInterface.RvrClientEffectTarget Target;
    local SkeletalMeshComponent Comp;
    
    if (!bCloakEffectStarted)
    {
        bCloakEffectStarted = TRUE;
        foreach m_oPawn.Mesh.AttachedComponents(Class'SkeletalMeshComponent', Comp)
        {
            if (Comp.SkeletalMesh.Name == Name("Backpack01_MDL"))
            {
                m_oPawn.Mesh.DetachComponent(Comp);
            }
        }
        Target.Instigator = m_oPawn;
        CloakEffectGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_CloakEffect, Target);
    }
}
public function StopTeleportVFX()
{
    if (bCloakEffectStarted)
    {
        bCloakEffectStarted = FALSE;
        Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(None, CloakEffectGuid, TRUE);
    }
}
public function TeleportPawn()
{
    local BioPlayerController PC;
    local Object.Vector CamOffset;
    local Object.Rotator DesiredRot;
    local float fDistanceToTarget;
    local float fScaledDistToTarget;
    local float fCameraTransitionTime;
    local SFXPlayerCamera Camera;
    local Object.Vector CachedPlayerLocation;
    
    if (InternalCanDoCustomAction(None, TRUE) == FALSE)
    {
        InterruptThisCustomAction();
        return;
    }
    if (bFoundTeleportLocation)
    {
        PC = BioPlayerController(m_oPawn.Controller);
        if (PC != None)
        {
            if (CamTransition == None)
            {
                CamTransition = new (PC.GetGameModeDefault()) Class'SFXCameraTransition_N7VanguardPunch';
            }
            Camera = SFXPlayerCamera(PC.PlayerCamera);
            if (Camera != None && Camera.CurrentCameraMode.GetActorCameraHook(CamOffset))
            {
                if (SyncPartner != None)
                {
                    DesiredRot = Rotator(Normal(SyncPartner.location - TeleportLocation));
                    DesiredRot.Pitch = Camera.CameraCache.POV.Rotation.Pitch;
                }
                else
                {
                    DesiredRot = Camera.CameraCache.POV.Rotation;
                }
                CamOffset = Camera.CameraCache.POV.location - m_oPawn.location;
                CamOffset = TransformVectorByRotation(DesiredRot - Camera.CameraCache.POV.Rotation, CamOffset);
                CamTransition.EndLocation = CamOffset + TeleportLocation;
                CamTransition.EndRotation = DesiredRot;
            }
        }
        CachedPlayerLocation = m_oPawn.location;
        if (m_oPawn.SetLocation(TeleportLocation, ))
        {
            if (Camera != None && CamTransition != None)
            {
                if (SyncPartner != None)
                {
                    fDistanceToTarget = VSize(SyncPartner.location - CachedPlayerLocation);
                }
                else
                {
                    fDistanceToTarget = VSize(TeleportLocation - CachedPlayerLocation);
                }
                fScaledDistToTarget = FClamp(fDistanceToTarget / 4000.0, 0.0, 1.0);
                fCameraTransitionTime = Lerp(CameraTransitionMin, CameraTransitionMax, fScaledDistToTarget);
                Camera.PlayCameraTransition(CamTransition, fCameraTransitionTime);
            }
            if (SyncPartner != None)
            {
                DesiredRot = Rotator(Normal(SyncPartner.location - m_oPawn.location));
                m_oPawn.SetRotation(DesiredRot);
                if (PC != None)
                {
                    PC.SetRotation(DesiredRot);
                }
            }
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    CE_CloakEffect = RvrClientEffect'BioVFX_MP3_BioticTeleport.VCFX.BioticTeleport_01_VCFX'
    CameraTransitionMax = 1.0
    CameraTransitionMin = 0.5
    MaxPartnerDistance = 1400.0
    ERootMotionMode = ERootMotionMode.RMM_Accel
    PlayerCameraMode = Class'SFXCameraMode_KroganMelee'
    MinTimeBetweenActions = 0.0250000004
    DamageReductionLength = 1.0
    DamageReductionAmount = 0.5
    fCameraTransitionIn = 0.25
    fCameraTransitionOut = 0.449999988
    bAllowDamageReduction = TRUE
    bClientPredictCustomAction = FALSE
}