// Source: ME3, Patch_ProjectilePowCustActionSeek
// Decompiled 11/17/2026 7:38:41 AM against BIOP_MP_COMMON.pcc
Class SFXProjectile_PowerCustomAction_Seeking extends SFXProjectile_PowerCustomAction
    config(Game);

var transient Object.Quat StartRotation;
var transient Object.Vector LastValidSeekLocation;
var transient float TimeAlive;
var const float CurveShape;
var const float UpperBound;
var transient float InterpRate;
var float PawnEvadedStopSeekingTime;
var transient bool bSeekingEnabled;
var transient bool bExplodeNextFrame;
var transient repnotify bool bPawnEvaded;
var BioPawn.EAimNodes SeekAimNode;

public simulated function Object.Vector GetAimLocation(Actor Target)
{
    local Object.Vector AimLocation;
    local BioPawn oPawn;
    local SFXPlaceable CP;
    local SFXSimpleUseModule UseModule;
    
    oPawn = BioPawn(Target);
    if (oPawn == None || oPawn.GetAimNodeLocation(SeekAimNode, AimLocation) == FALSE)
    {
        AimLocation = Target.location;
    }
    CP = SFXPlaceable(Target);
    if (CP != None)
    {
        UseModule = CP.GetModule(Class'SFXSimpleUseModule');
        if (UseModule != None)
        {
            AimLocation = UseModule.m_TargetOffset + CP.location;
        }
    }
    return AimLocation;
}
public simulated function Recycle()
{
    Super.Recycle();
    TimeAlive = default.TimeAlive;
    StartRotation = default.StartRotation;
    bExplodeNextFrame = default.bExplodeNextFrame;
    bSeekingEnabled = default.bSeekingEnabled;
    bPawnEvaded = default.bPawnEvaded;
    bReplicateMovement = default.bReplicateMovement;
    bUpdateSimulatedPosition = default.bUpdateSimulatedPosition;
}
public event simulated function ReplicatedEvent(Name VarName)
{
    switch (VarName)
    {
        case 'bPawnEvaded':
            bStopAiming = TRUE;
            break;
        default:
            Super.ReplicatedEvent(VarName);
            break;
    }
}
public simulated function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    if (!bStopAiming && bSeekingEnabled)
    {
        if (bExplodeNextFrame)
        {
            if (Role == ENetRole.ROLE_Authority && !IsShuttingDown())
            {
                SetTimer(0.00100000005, FALSE, , );
            }
            return;
        }
        TimeAlive += DeltaTime;
        if (!bClientPredictionActive)
        {
            Speed = MaxSpeed;
        }
        if (TargetActor != None)
        {
            LastValidSeekLocation = GetAimLocation(TargetActor);
        }
        TickAim(DeltaTime);
        Velocity = Vector(Rotation) * Speed;
    }
}
public function Timer()
{
    local Pawn PawnTarget;
    
    if (bExplodeNextFrame && IsShuttingDown() == FALSE && bClientPredictionActive == FALSE)
    {
        PawnTarget = Pawn(TargetActor);
        if (PawnTarget != None)
        {
            Touch(PawnTarget, PawnTarget.Mesh, PawnTarget.location, -Normal(Velocity));
            return;
        }
    }
    Super(SFXProjectile_Explosive).Timer();
}
public simulated function bool InitializePowerProjectile(Actor oCaster, float fTravelSpeed, float fRadius, SFXPowerCustomAction oPower)
{
    local Pawn oCasterPawn;
    
    oCasterPawn = Pawn(oCaster);
    if (oCasterPawn == None)
    {
        return FALSE;
    }
    if (TargetActor != None)
    {
        if (oCasterPawn.IsHumanControlled() && CanLockOn(TargetActor, oCasterPawn) == FALSE)
        {
            TargetActor = None;
        }
    }
    if (TargetActor == None)
    {
        bSeekingEnabled = FALSE;
    }
    else
    {
        bSeekingEnabled = TRUE;
        LastValidSeekLocation = TargetLocation;
    }
    InitializeRotation(oCasterPawn);
    StartRotation = QuatFromRotator(Rotation);
    return Super.InitializePowerProjectile(oCaster, fTravelSpeed, fRadius, oPower);
}
public function PawnEvadedPower(BioPawn Pawn, Name Label, float TimeBeforeImpact)
{
    Super.PawnEvadedPower(Pawn, Label, TimeBeforeImpact);
    TargetActor = None;
    bPawnEvaded = TRUE;
    bReplicateMovement = TRUE;
    bUpdateSimulatedPosition = TRUE;
}
public function Tick_Prediction(float DeltaTime)
{
    local SFXProjectile_PowerCustomAction_Seeking oTargetProjectile;
    local Object.Rotator NewRotation;
    
    Super(SFXProjectile_Explosive).Tick_Prediction(DeltaTime);
    oTargetProjectile = SFXProjectile_PowerCustomAction_Seeking(TargetProjectile);
    if (bGotAPredictionTarget && oTargetProjectile != None)
    {
        TargetActor = oTargetProjectile.TargetActor;
        if (oTargetProjectile.bPawnEvaded)
        {
            NewRotation = Rotator(oTargetProjectile.location - location);
            SetRotation(NewRotation);
            Velocity = Vector(NewRotation) * MaxSpeed;
            Acceleration = oTargetProjectile.Acceleration;
        }
    }
}
public simulated function bool CanLockOn(Actor Target, Pawn CasterPawn)
{
    local KActor oKActor;
    local SFXSelectionModule Module;
    local BioPawn oPawn;
    local SFXPlaceable oCP;
    
    oPawn = BioPawn(Target);
    if (oPawn != None)
    {
        if (oPawn.IsHostile(CasterPawn))
        {
            return TRUE;
        }
    }
    oCP = SFXPlaceable(Target);
    if (oCP != None)
    {
        return TRUE;
    }
    oKActor = KActor(Target);
    if (oKActor != None)
    {
        Module = oKActor.GetModule(Class'SFXSelectionModule');
        if (Module != None && Module.m_bCombatTargetable == TRUE)
        {
            return TRUE;
        }
    }
    return FALSE;
}
public function InitializeRotation(Pawn oCasterPawn);

public simulated function TickAim(float DeltaTime)
{
    local Object.Vector V;
    local float Dist;
    
    V = LastValidSeekLocation - location;
    Dist = VSize(V);
    if (TargetActor == None && Dist < MaxSpeed * PawnEvadedStopSeekingTime)
    {
        bSeekingEnabled = FALSE;
        return;
    }
    else if (Dist < MaxSpeed * DeltaTime || Dist < float(10))
    {
        Speed = Dist / DeltaTime;
        bExplodeNextFrame = TRUE;
        return;
    }
    TickAimRotation(DeltaTime, V);
}
public simulated function TickAimRotation(float DeltaTime, Object.Vector SeekVector)
{
    local Object.Quat Q;
    
    Q = QuatSlerp(StartRotation, QuatFromRotator(Rotator(SeekVector)), FClamp(InterpRate * TimeAlive, 0.0, UpperBound), TRUE);
    SetRotation(QuatToRotator(Q));
}

replication
{
    if (bNetDirty && Role == ENetRole.ROLE_Authority)
        bPawnEvaded;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    CurveShape = 2.0
    UpperBound = 1.0
    InterpRate = 10000.0
    PawnEvadedStopSeekingTime = 0.0149999997
    bSeekingEnabled = TRUE
    SeekAimNode = EAimNodes.AimNode_Chest
    TossZ = 2.5
    bClientPredictProjectile = TRUE
    CylinderComponent = CollisionCylinder
    Components = (CollisionCylinder)
    CollisionComponent = CollisionCylinder
}