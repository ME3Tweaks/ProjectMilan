// Source: ME3, Patch_SFXCustActnN7VanEvadeBase
// Decompiled 11/17/2026 7:37:45 AM against N7_Adept_MP.pcc
Class SFXCustomAction_N7VanguardEvadeBase extends SFXCustomAction_PlayerEvadeBase
    config(Game);

var Object.Guid CloakEffectGuid;
var Object.Vector TeleportLocation;
var(AnimControl) SFXAnimSetCookSpec AnimInfo;
var config float NavPointSearchRange;
var config float HeightNavCheckDistance;
var RvrClientEffectInterface CE_CloakEffect;
var float CameraTransitionTime;
var SFXCameraTransition_N7VanguardEvade CamTransition;
var config float MovementX;
var config float MovementY;
var(SFXCustomAction_N7VanguardEvadeBase) float Decay;
var config float BarrierReduction;
var bool bCloakEffectStarted;
var bool bFoundTeleportLocation;

public function StartCustomAction()
{
    local SFXShield_Base Shield;
    local float fCurrentShields;
    local float fUpdatedShields;
    local bool bCurrentShieldsBreached;
    
    if (m_oPawn.Role < ENetRole.ROLE_Authority && InternalCanDoCustomAction(None, TRUE) == FALSE)
    {
        InterruptThisCustomAction();
        return;
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
        bFoundTeleportLocation = FindTeleportLocation(TeleportLocation);
        if (!bFoundTeleportLocation)
        {
            TeleportLocation = vect(0.0, 0.0, 0.0);
        }
    }
    Super.StartCustomAction();
    m_oPawn.RegisterTemporaryAnim(AnimInfo.AnimSet);
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
    if (SFXPawn_Player(m_oPawn) != None && !SFXPawn_Player(m_oPawn).bCanRoll && !bForced)
    {
        return FALSE;
    }
    return Super(BioCustomAction).InternalCanDoCustomAction(SyncPawn, bForced);
}
public function Replicate()
{
    Super(BioCustomAction).Replicate();
    if (m_oPawn != None)
    {
        m_oPawn.ReplicatedCustomActionInfo.TargetLocation = TeleportLocation;
    }
}
public function StopCustomAction()
{
    m_oPawn.UnregisterTemporaryAnim(AnimInfo.AnimSet);
    StopTeleportVFX();
    Super(SFXCustomAction_SingleAnim).StopCustomAction();
}
public function RollOverride()
{
    InterruptThisCustomAction();
}
public function bool FindTeleportLocation(out Object.Vector NewLocation)
{
    local Object.Vector OriginalLoc;
    local NavigationPoint N;
    local Object.Vector X;
    local Object.Vector Y;
    local Object.Vector Z;
    local Actor PathFindResult;
    local PlayerController PC;
    
    PC = PlayerController(m_oPawn.Controller);
    if (PC == None)
    {
        return FALSE;
    }
    GetAxes(m_oPawn.Rotation, X, Y, Z);
    OriginalLoc = m_oPawn.location + X * MovementX + Y * MovementY;
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
    local Object.Vector NearestTeleportLoc;
    local SFXPlayerCamera Camera;
    local bool bSetLocationSuccess;
    
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
                CamTransition = new (PC.GetGameModeDefault()) Class'SFXCameraTransition_N7VanguardEvade';
            }
            Camera = SFXPlayerCamera(PC.PlayerCamera);
            if (Camera != None && Camera.CurrentCameraMode.GetActorCameraHook(CamOffset))
            {
                CamOffset = Camera.CameraCache.POV.location - m_oPawn.location;
                CamTransition.EndLocation = CamOffset + TeleportLocation;
                CamTransition.EndRotation = Camera.CameraCache.POV.Rotation;
            }
        }
        bSetLocationSuccess = m_oPawn.SetLocation(TeleportLocation, );
        if (!bSetLocationSuccess)
        {
            if (m_oPawn.FindNearestOpenLocation(TeleportLocation, NearestTeleportLoc))
            {
                bSetLocationSuccess = m_oPawn.SetLocation(NearestTeleportLoc, );
            }
        }
        if (bSetLocationSuccess)
        {
            if (Camera != None && CamTransition != None)
            {
                Camera.PlayCameraTransition(CamTransition, CameraTransitionTime);
            }
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    CE_CloakEffect = RvrClientEffect'BioVFX_MP3_BioticTeleport.VCFX.BioticTeleport_01_VCFX'
    CameraTransitionTime = 0.100000001
    bAllowAnimInterrupt = FALSE
    ERootMotionMode = ERootMotionMode.RMM_Accel
    MinTimeBetweenActions = 0.00999999978
    DamageReductionLength = 1.10000002
    DamageReductionAmount = 0.5
    bDisableLook = TRUE
    bHideWeapon = TRUE
    bAllowDamageReduction = TRUE
    bReplicateCustomAction = TRUE
    bForceLocalSimulation = TRUE
}