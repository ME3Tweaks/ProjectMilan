// MILAN CHANGE - 09/27/2026
// By Mgamerz
// Add some None checks to prevent huge game stalls when paired with DebugLogger as some memory on cover 'slots' throws tons of minidump creating exceptions and logs
Class SFXGameModeDefault extends SFXGameModeBase within BioPlayerController
    config(Input);

var(SFXGameModeDefault) WwiseEvent UseSucceeded;
var(SFXGameModeDefault) WwiseEvent UseFailed;
var(SFXGameModeDefault) SFXCameraSetup CameraSetup;
var(SFXGameModeDefault) config float InputDelayStormExit;
var(SFXGameModeDefault) config float InputDelayTightAimExit;
var(SFXGameModeDefault) float CoverCamAlign;

public function Initialize()
{
    bIsActive = TRUE;
    CameraSetup.ExploreCam.Input.m_bUseExplorationSensitivity = TRUE;
    CameraSetup.ZoomSnapTransition.Curve = CameraSetup.ZoomSnapCurve;
    if (CameraSetup.Outer != Self)
    {
        CameraSetup = new (Self) CameraSetup.@Class (CameraSetup);
    }
    Super.Initialize();
}
public exec function UsePower(Name PowerName, SFXPawn User)
{
    local SFXWeapon Weapon;
    local bool bPerformingBlockingAction;
    local BioCustomAction CurrentAction;
    
    Weapon = SFXWeapon(User.Weapon);
    if (Weapon != None)
    {
        Weapon.CancelReload();
    }
    bPerformingBlockingAction = User != None ? User.IsPerformingBlockingAction() : FALSE;
    if (bPerformingBlockingAction && SFXGRI(Outer.WorldInfo.GRI).bMultiplayer == TRUE)
    {
        return;
    }
    if (bPerformingBlockingAction)
    {
        User.GetCurrentCustomAction(CurrentAction);
        if (CurrentAction == None || !CurrentAction.bDisableCustomActionQueuing)
        {
            Outer.SquadOrderUsePower(PowerName, User, 1, FALSE);
        }
    }
    else
    {
        Outer.SquadOrderUsePower(PowerName, User, 0, FALSE);
    }
    Outer.ApplyTacticalOrders();
}
public exec function NextWeapon()
{
    local SFXWeapon Weapon;
    local BioPawn ChkPawn;
    
    if (BioPlayerInput(Outer.PlayerInput).IsCombatEnabled() == FALSE)
    {
        return;
    }
    ChkPawn = BioPawn(Outer.Pawn);
    if (ChkPawn == None)
    {
        return;
    }
    if (ChkPawn.IsPerformingBlockingAction() || ChkPawn.IsUsingPower())
    {
        return;
    }
    if (ChkPawn.IsInCoverLeaning())
    {
        return;
    }
    Weapon = SFXWeapon(Outer.Pawn.Weapon);
    if (Weapon != None)
    {
        if (Weapon.IsInState('WeaponEquipping', ) || Weapon.IsInState('WeaponPuttingDown', ))
        {
            return;
        }
        if (Outer.Pawn.InvManager != None)
        {
            Outer.Pawn.InvManager.NextWeapon();
        }
    }
}
public exec function PrevWeapon()
{
    local SFXWeapon Weapon;
    local BioPawn ChkPawn;
    
    if (BioPlayerInput(Outer.PlayerInput).IsCombatEnabled() == FALSE)
    {
        return;
    }
    ChkPawn = BioPawn(Outer.Pawn);
    if (ChkPawn == None)
    {
        return;
    }
    if (ChkPawn.IsPerformingBlockingAction() || ChkPawn.IsUsingPower())
    {
        return;
    }
    if (ChkPawn.IsInCoverLeaning())
    {
        return;
    }
    Weapon = SFXWeapon(Outer.Pawn.Weapon);
    if (Weapon != None)
    {
        if (Weapon.IsInState('WeaponEquipping', ) || Weapon.IsInState('WeaponPuttingDown', ))
        {
            return;
        }
        if (Outer.Pawn.InvManager != None)
        {
            Outer.Pawn.InvManager.PrevWeapon();
        }
    }
}
public exec function CanEnterCover()
{
    Outer.bNoCoverFromStorm = FALSE;
}
public function CanLeaveCover()
{
    Outer.bNoLeaveCover = TRUE;
}
public function ClimbCover()
{
    local SFXWeapon PlayerWeapon;
    
    PlayerWeapon = SFXWeapon(Outer.Pawn.Weapon);
    if (!Outer.IsLocalPlayerController())
    {
        LogInternal(GetFuncName() @ "has to be called from local player!", );
        ScriptTrace();
        return;
    }
    if (PlayerWeapon != None)
    {
        PlayerWeapon.CancelReload();
    }
    Outer.GenerateTutorialEvent(17);
    Outer.StartCustomAction(33);
}
public exec function DisableWalking()
{
    Outer.m_bToggledWalk = FALSE;
}
public exec function EnableWalking()
{
    Outer.m_bToggledWalk = TRUE;
}
public function bool FindCover(out CovPosInfo FoundCover, bool bWideCheck)
{
    // MILAN CHANGE - Mgamerz - 2026-10-20
    // Keep Talon bow interruption in the base mode
    // Using the override in the subclass screws stuff up
    local BioPawn MercPawn;
    local BioCustomAction MercAction;
    // END MILAN CHANGE

    if (!Outer.IsLocalPlayerController())
    {
        return FALSE;
    }
    if (FindPlayerCover_Internal(FoundCover, bWideCheck) == FALSE)
    {
        return FALSE;
    }
    // MILAN CHANGE - Mgamerz - 2026-10-20
    // Interrupt the bow only after the Talon successfully finds cover.
    MercPawn = BioPawn(Outer.Pawn);
    if (MercPawn != None && MercPawn.IsA('SFXPawn_PlayerMP_Engineer_Merc'))
    {
        if (MercPawn.GetCurrentCustomAction(MercAction) && MercAction != None && MercAction.IsA('SFXCustomAction_MercBowBase'))
        {
            MercAction.InterruptThisCustomAction();
        }
    }
    // END MILAN CHANGE
    return TRUE;
}
public function bool FindPlayerCover_Internal(out CovPosInfo FoundCover, bool bWideCheck)
{
    local Vector Direction;
    
    if (BioPlayerInput(Outer.PlayerInput).MoveStickMag > 0.800000012)
    {
        if (Outer.PlayerInput.bUsingGamepad)
        {
            Direction = Vector(Outer.Rotation + Rotator(BioPlayerInput(Outer.PlayerInput).MoveStick));
        }
        else
        {
            Direction = Vector(Outer.Rotation);
        }
        Direction.Z = 0.0;
        Direction = Normal(Direction);
        if (!bWideCheck && SFXPawn(Outer.Pawn).bStorming)
        {
            return Outer.FindPlayerCover(FoundCover, Direction, Outer.DirectionalCoverAcquireParams.MaxDist, Outer.DirectionalCoverAcquireParams.MinCameraDotCover, Outer.DirectionalCoverAcquireParams.MinSlotDotPlayer, Outer.DirectionalCoverAcquireParams.MinPlayerDotCoverOffset, Outer.DirectionalCoverAcquireParams.MaxCoverHeightFactor);
        }
        else
        {
            return Outer.FindPlayerCover(FoundCover, Direction, Outer.DirectionalCoverAcquireParams.MaxDist, 0.707000017, Outer.CoverAcquireParams.MinSlotDotPlayer, Outer.CoverAcquireParams.MinPlayerDotCoverOffset, Outer.DirectionalCoverAcquireParams.MaxCoverHeightFactor);
        }
    }
    else
    {
        Direction = Vector(Outer.Rotation);
        Direction.Z = 0.0;
        Direction = Normal(Direction);
        return Outer.FindPlayerCover(FoundCover, Direction, Outer.CoverAcquireParams.MaxDist, Outer.CoverAcquireParams.MinCameraDotCover, Outer.CoverAcquireParams.MinSlotDotPlayer, Outer.CoverAcquireParams.MinPlayerDotCoverOffset, Outer.DirectionalCoverAcquireParams.MaxCoverHeightFactor);
    }
}
public function SFXCameraMode GetCameraMode(SFXCameraMode OldCameraMode, out int PreserveTarget, out float TransitionTime, out SFXCameraMode_Interpolate Transition)
{
    local SFXCameraSetup Setup;
    
    Setup = CameraSetup;
    if (Outer.Pawn != None && SFXWeapon(Outer.Pawn.Weapon) != None && SFXWeapon(Outer.Pawn.Weapon).CameraSetup != None)
    {
        Setup = SFXWeapon(Outer.Pawn.Weapon).CameraSetup;
        if (Setup.Outer != Self)
        {
            SFXWeapon(Outer.Pawn.Weapon).CameraSetup = new (Self) Setup.@Class (Setup);
        }
    }
    return Setup.GetCameraMode(Outer, OldCameraMode, PreserveTarget, TransitionTime, Transition);
}
public function bool GetSnapTarget(optional out int TargetSlotIdx, optional out float TargetSlotPct, optional out ECoverDirection TargetDir)
{
    local BioPawn BP;
    local int TargetLeftSlotIdx;
    local int TargetRightSlotIdx;
    local bool bLeftSnapAvailable;
    local bool bRightSnapAvailable;
    
    BP = BioPawn(Outer.Pawn);
    if (BP.CurrentSlotPct > 0.5)
    {
        TargetRightSlotIdx = BP.CurrentSlotIdx;
    }
    else
    {
        TargetRightSlotIdx = BP.CurrentSlotIdx + 1;
        if (TargetRightSlotIdx >= BP.CurrentLink.Slots.Length)
        {
            TargetRightSlotIdx = BP.CurrentLink.Slots.Length - 1;
        }
    }
    if (BP.CurrentLink.Slots[TargetRightSlotIdx].bLeanRight && VSize(BP.location - BP.CurrentLink.GetSlotLocation(TargetRightSlotIdx)) < Outer.EdgeCoverSlotSnapRange)
    {
        bRightSnapAvailable = TRUE;
    }
    if (BP.CurrentSlotPct < 0.5)
    {
        TargetLeftSlotIdx = BP.CurrentSlotIdx;
    }
    else
    {
        TargetLeftSlotIdx = BP.CurrentSlotIdx - 1;
        if (TargetLeftSlotIdx < 0)
        {
            TargetLeftSlotIdx = 0;
        }
    }
    if (BP.CurrentLink.Slots[TargetLeftSlotIdx].bLeanLeft && VSize(BP.location - BP.CurrentLink.GetSlotLocation(TargetLeftSlotIdx)) < Outer.EdgeCoverSlotSnapRange)
    {
        bLeftSnapAvailable = TRUE;
    }
    if (!bLeftSnapAvailable && !bRightSnapAvailable)
    {
        return FALSE;
    }
    if (bLeftSnapAvailable && bRightSnapAvailable)
    {
        if (BP.CoverDirection == ECoverDirection.CD_Right)
        {
            bLeftSnapAvailable = FALSE;
        }
        else
        {
            bRightSnapAvailable = FALSE;
        }
    }
    if (bRightSnapAvailable)
    {
        TargetSlotIdx = TargetRightSlotIdx;
        TargetSlotPct = 1.0;
        TargetDir = ECoverDirection.CD_Right;
    }
    else
    {
        TargetSlotIdx = TargetLeftSlotIdx;
        TargetSlotPct = 0.0;
        TargetDir = ECoverDirection.CD_Left;
    }
    return TRUE;
}
public function bool HasCoverTurn()
{
    local BioPawn BP;
    local CoverLink OriginalCoverLink;
    local int OriginalCoverSlotIdx;
    local CoverInfo CoverTurnInfo;
    
    BP = BioPawn(Outer.Pawn);
    OriginalCoverLink = BP.CurrentLink;
    OriginalCoverSlotIdx = BP.CurrentSlotIdx;
    if (Outer != None)
    {
        if (OriginalCoverLink.GetCoverTurnTarget(OriginalCoverSlotIdx, 1, CoverTurnInfo) || OriginalCoverLink.GetCoverTurnTarget(OriginalCoverSlotIdx, -1, CoverTurnInfo))
        {
            return TRUE;
        }
    }
    return FALSE;
}
public exec function HoldAction()
{
    TryAcquireCover();
}
public function MantleCover()
{
    local SFXWeapon PlayerWeapon;
    
    PlayerWeapon = SFXWeapon(Outer.Pawn.Weapon);
    if (!Outer.IsLocalPlayerController())
    {
        LogInternal(GetFuncName() @ "has to be called from local player!", );
        ScriptTrace();
        return;
    }
    if (PlayerWeapon != None)
    {
        PlayerWeapon.CancelReload();
    }
    Outer.GenerateTutorialEvent(2);
    Outer.StartCustomAction(31);
}
public exec function bool PressAction()
{
    if (TryAcquireCover(FALSE, TRUE))
    {
        return FALSE;
    }
    if (TryCoverAction())
    {
        return TRUE;
    }
    return TryRoll();
}
public function ResetSelectionMaterialParams()
{
    Outer.m_oPlayerSelection.SetSelectionIconMaterialParam('Select_ok', 0);
    Outer.m_oPlayerSelection.SetSelectionIconMaterialParam('Select_nodice', 0);
}
public function bool ShouldAllowTightAim(Pawn inPawn)
{
    local BioPawn BP;
    local CoverSlot Slot;
    
    BP = BioPawn(inPawn);
    if (BP != None)
    {
        if (BP.IsInCover())
        {
            Slot = BP.CurrentLink.Slots[BP.CurrentSlotIdx];
            if (!BP.IsAtRightEdgeSlot() && !BP.IsAtLeftEdgeSlot() && !Slot.bCanPopUp)
            {
                return FALSE;
            }
        }
    }
    return TRUE;
}
public function bool ShouldUseScope(Pawn inPawn)
{
    local SFXWeapon Weapon;
    local BioPawn BP;
    
    BP = BioPawn(inPawn);
    if (BP != None)
    {
        Weapon = SFXWeapon(BP.Weapon);
        if (Weapon != None && Weapon.CurrentAimMode >= 0 && Weapon.CurrentAimMode < Weapon.AimModes.Length)
        {
            return Weapon.AimModes[Weapon.CurrentAimMode].bScoped && !BP.IsUsingPower();
        }
    }
    return FALSE;
}
public exec function StopTightAim()
{
    SetTimer(InputDelayTightAimExit, FALSE, 'TurnOffTightAim');
}
public exec function StormOff()
{
    Outer.bNoCoverFromStorm = TRUE;
    SetTimer(InputDelayStormExit, FALSE, 'TurnStormOff');
}
public exec function StormOn()
{
    local ECoverAction CoverAction;
    local BioPawn MyBP;
    local BioPlayerInput Input;
    
    if (Outer.IsStormDisabled())
    {
        return;
    }
    Outer.bNoCoverFromStorm = TRUE;
    Outer.bCancelStorm = FALSE;
    SetTimer(0.25, , 'CanEnterCover');
    MyBP = BioPawn(Outer.Pawn);
    Input = BioPlayerInput(Outer.PlayerInput);
    if (BioPlayerInput(Outer.PlayerInput).MoveStickMag > 0.800000012 && Input.RawJoyUp > 0.707000017)
    {
        if (Outer.IsInCoverState() && Outer.IsCameraAlignedWithCoverSlot(Outer.CoverSlipCamAlign))
        {
            CoverAction = MyBP.CoverAction;
            if (CoverAction == ECoverAction.CA_PeekLeft || CoverAction == ECoverAction.CA_PeekRight)
            {
                if (MyBP.CoverType == ECoverType.CT_Standing)
                {
                    if (MyBP.CoverDirection == ECoverDirection.CD_Left && MyBP.IsAtLeftEdgeSlot())
                    {
                        Outer.GenerateTutorialEvent(13);
                        Outer.StartCustomAction(37);
                    }
                    else if (MyBP.CoverDirection == ECoverDirection.CD_Right && MyBP.IsAtRightEdgeSlot())
                    {
                        Outer.GenerateTutorialEvent(13);
                        Outer.StartCustomAction(39);
                    }
                }
                else if (MyBP.CoverDirection == ECoverDirection.CD_Left && MyBP.IsAtLeftEdgeSlot())
                {
                    Outer.GenerateTutorialEvent(13);
                    Outer.StartCustomAction(36);
                }
                else if (MyBP.CoverDirection == ECoverDirection.CD_Right && MyBP.IsAtRightEdgeSlot())
                {
                    Outer.GenerateTutorialEvent(13);
                    Outer.StartCustomAction(38);
                }
            }
            else if (CoverAction == ECoverAction.CA_LeanLeft || CoverAction == ECoverAction.CA_LeanRight)
            {
                Outer.BreakFromCover();
            }
            Outer.bWantsToStorm = 1;
        }
        else
        {
            Outer.bWantsToStorm = 1;
            ClearTimer('TurnStormOff');
            Outer.GenerateTutorialEvent(0);
        }
    }
    if (Outer.IsInCoverState() && Input.RawJoyRight > 0.707000017 || Input.RawJoyRight > -0.707000017)
    {
        Outer.bWantsToStorm = 1;
    }
    else
    {
        Outer.bWantsToStorm = 0;
    }
}
public exec function SwitchToBackup()
{
    if (Outer.Pawn == None || Outer.Pawn.Weapon == None || SFXWeapon(Outer.Pawn.Weapon) == None)
    {
        return;
    }
    if (SFXWeapon(Outer.Pawn.Weapon).OutOfAmmo() == FALSE)
    {
        return;
    }
    SFXPawn_Player(Outer.Pawn).SwitchToBackupWeapon();
}
public exec function TapAction()
{
    if (TryAcquireCover())
    {
        return;
    }
    TryCoverSlip();
    TryForwardRoll();
    TryExitCover();
}
public exec function TightAim()
{
    local BioPawn BP;
    local SFXWeapon Weapon;
    
    Weapon = SFXWeapon(Outer.Pawn.Weapon);
    BP = BioPawn(Outer.Pawn);
    if (BioPlayerInput(Outer.PlayerInput).IsCombatEnabled() == FALSE)
    {
        return;
    }
    if (Weapon.GetAmmoCountInMagazine() == 0)
    {
        TryReload();
    }
    if (ShouldAllowTightAim(BP) == FALSE)
    {
        return;
    }
    ClearTimer('TurnOffTightAim');
    BioPlayerInput(Outer.PlayerInput).bWantsToZoom = 1;
    if (BioPawn(Outer.Pawn).IsInCover() && BP.CoverType == ECoverType.CT_Standing)
    {
        TrySnap();
    }
}
public function TransitionToFutureSlot(float Time, CoverSlotMarker Target)
{
    local CoverSlot Slot;
    local SFXPlayerCamera Cam;
    local SFXCameraMode TargetMode;
    
    Slot = Target.OwningSlot.Link.Slots[Target.OwningSlot.SlotIdx];
    Cam = SFXPlayerCamera(Outer.PlayerCamera);
    // MILAN CHANGE
    // None Check Cam - it was observed null occassionally in network mode
    if (Cam == None) {
        return;
    }
    // END MILAN CHANGE
    Cam.FaceTargetTransition.TargetLocation = Target.GetSlotLocation() + Vector(Target.GetSlotRotation()) * 1000.0;
    switch (Slot.CoverType)
    {
        case ECoverType.CT_MidLevel:
            if (Slot.bLeanRight)
            {
                TargetMode = CameraSetup.PeekRightCrouch;
            }
            else if (Slot.bLeanLeft)
            {
                TargetMode = CameraSetup.PeekLeftCrouch;
            }
            else
            {
                TargetMode = CameraSetup.DefaultCrouch;
            }
            break;
        case ECoverType.CT_Standing:
            if (Slot.bLeanRight)
            {
                TargetMode = CameraSetup.PeekRightStand;
            }
            else if (Slot.bLeanLeft)
            {
                TargetMode = CameraSetup.PeekLeftStand;
            }
            else
            {
                TargetMode = CameraSetup.DefaultStand;
            }
            break;
        default:
    }
    TargetMode.LastHookPos = Target.GetSlotLocation();
    Cam.SetBehavior(TargetMode, Cam.FaceTargetTransition, Time, FALSE);
    Cam.bCurrentTransitionIsModal = TRUE;
}
public final exec function bool TryAcquireCover(optional bool bWideCheck, optional bool bTestOnly)
{
    local CovPosInfo FoundCover;
    local BioRemoteLogger GLogger;
    local SFXWeapon PlayerWeapon;
    local BioPawn BioPawn;
    local SFXPawn_Player ChkPawn;
    
    BioPawn = BioPawn(Outer.Pawn);
    PlayerWeapon = SFXWeapon(Outer.Pawn.Weapon);
    if (BioPawn.IsInAnimatedTransition())
    {
        return FALSE;
    }
    ChkPawn = SFXPawn_Player(Outer.Pawn);
    if (ChkPawn.bCannotUseCover == TRUE)
    {
        return FALSE;
    }
    if (BioPlayerInput(Outer.PlayerInput).MoveStickMag > 0.100000001 && Outer.PlayerInput.RawJoyUp < 0.100000001)
    {
        return FALSE;
    }
    if (Outer.CanPerformEnterCover() == FALSE)
    {
        return FALSE;
    }
    if (FindCover(FoundCover, bWideCheck))
    {
        if (!bTestOnly)
        {
            PlayerWeapon.CancelReload();
            Outer.bNoLeaveCover = FALSE;
            SetTimer(0.649999976, , 'CanLeaveCover');
            Outer.AcquireCover(FoundCover);
            GLogger = Class'BioRemoteLogger'.static.GetLogger();
            if (GLogger != None)
            {
            }
        }
        return TRUE;
    }
    return FALSE;
}
public exec function bool TryCoverAction()
{
    local CovPosInfo CoverInfo;
    local BioPawn BP;
    local BioPlayerInput Input;
    local MantleInfo MyMantleInfo;
    
    BP = BioPawn(Outer.Pawn);
    Input = BioPlayerInput(Outer.PlayerInput);
    if (BP.IsInCover())
    {
        CoverInfo.Link = BP.CurrentLink;
        CoverInfo.LtSlotIdx = BP.LeftSlotIdx;
        CoverInfo.RtSlotIdx = BP.RightSlotIdx;
        CoverInfo.LtToRtPct = BP.CurrentSlotPct;
        if (Input.RawJoyUp > 0.800000012 && Outer.CanPerformClimb(CoverInfo))
        {
            ClimbCover();
            return TRUE;
        }
        else if (Input.RawJoyUp > 0.800000012 && Outer.CanPerformMantle(CoverInfo) && BP.CanPerformMantleSlow(MyMantleInfo))
        {
            MantleCover();
            return TRUE;
        }
        else if (BP.CoverAction == ECoverAction.CA_PeekLeft && Input.RawJoyRight < -0.879999995 || BP.CoverAction == ECoverAction.CA_PeekRight && Input.RawJoyRight > 0.879999995)
        {
            if (TrySwatTurn())
            {
                return TRUE;
            }
            else
            {
                TryRoll();
                return TRUE;
            }
        }
        else
        {
            return FALSE;
        }
    }
    return FALSE;
}
public exec function TryCoverSlip()
{
    local BioPawn oPawn;
    local ECoverAction CoverAction;
    local BioPlayerInput Input;
    
    if (Outer.IsMoveInputIgnored())
    {
        return;
    }
    CoverAction = BioPawn(Outer.Pawn).CoverAction;
    oPawn = BioPawn(Outer.Pawn);
    Input = BioPlayerInput(Outer.PlayerInput);
    if (oPawn.IsInAnimatedTransition())
    {
        return;
    }
    if (CoverAction != ECoverAction.CA_Default && Input.RawJoyUp > 0.879999995)
    {
        if (oPawn.CoverType == ECoverType.CT_Standing)
        {
            if (oPawn.CoverDirection == ECoverDirection.CD_Left && oPawn.IsAtLeftEdgeSlot())
            {
                Outer.GenerateTutorialEvent(13);
                Outer.StartCustomAction(37);
            }
            else if (oPawn.CoverDirection == ECoverDirection.CD_Right && oPawn.IsAtRightEdgeSlot())
            {
                Outer.GenerateTutorialEvent(13);
                Outer.StartCustomAction(39);
            }
        }
        else if (oPawn.CoverDirection == ECoverDirection.CD_Left && oPawn.IsAtLeftEdgeSlot())
        {
            Outer.GenerateTutorialEvent(13);
            Outer.StartCustomAction(36);
        }
        else if (oPawn.CoverDirection == ECoverDirection.CD_Right && oPawn.IsAtRightEdgeSlot())
        {
            Outer.GenerateTutorialEvent(13);
            Outer.StartCustomAction(38);
        }
    }
}
public exec function bool TryCoverTurn()
{
    local BioPawn BP;
    
    BP = BioPawn(Outer.Pawn);
    if (BP != None && BP.IsInCover() && HasCoverTurn())
    {
        if (!BP.IsInAnimatedTransition())
        {
            if (BP.CoverAction == ECoverAction.CA_PeekLeft)
            {
                Outer.GenerateTutorialEvent(15);
                if (BP.CoverType == ECoverType.CT_Standing)
                {
                    return Outer.StartCustomAction(43);
                }
                else
                {
                    return Outer.StartCustomAction(42);
                }
            }
            else if (BP.CoverAction == ECoverAction.CA_PeekRight)
            {
                Outer.GenerateTutorialEvent(15);
                if (BP.CoverType == ECoverType.CT_Standing)
                {
                    return Outer.StartCustomAction(41);
                }
                else
                {
                    return Outer.StartCustomAction(40);
                }
            }
        }
        return FALSE;
    }
    return FALSE;
}
public exec function bool TryExitCover()
{
    local BioPawn BP;
    
    BP = BioPawn(Outer.Pawn);
    if (BP == None || BP.IsInAnimatedTransition())
    {
        return FALSE;
    }
    if (SFXWeapon_SniperRifle_Base(Outer.Pawn.Weapon) != None && Outer.IsZoomed())
    {
        return FALSE;
    }
    if (BP.IsInCover() && Outer.bNoLeaveCover == TRUE)
    {
        BP.LeaveCover();
        Outer.bNoLeaveCover = FALSE;
    }
    return FALSE;
}
public exec function bool TryExitLadder()
{
    local BioPawn BP;
    
    BP = BioPawn(Outer.Pawn);
    if (BP == None)
    {
        return FALSE;
    }
    if (BP.CurrentCustomAction == 46)
    {
        BP.InterruptCustomAction();
        BP.SetPhysics(2);
        BP.StartFall();
        return TRUE;
    }
    else if (BP.CurrentCustomAction == 47)
    {
        BP.InterruptCustomAction();
        return TRUE;
    }
    else if (BioPawn(Outer.Pawn).CurrentCustomAction == 30)
    {
        BP.InterruptCustomAction();
        return TRUE;
    }
    return FALSE;
}
// MILAN CHANGE - UP3 - Allow aimed melee and rolls with non-sniper weapons
public exec function bool TryForwardRoll()
{
    local SFXWeapon Weapon;
    local BioPlayerInput Input;
    local BioPawn oPawn;
    local ECoverAction CoverAction;
    local ECoverType CoverType;
    
    if (Outer.IsMoveInputIgnored())
    {
        return FALSE;
    }
    CoverAction = BioPawn(Outer.Pawn).CoverAction;
    CoverType = BioPawn(Outer.Pawn).CoverType;
    oPawn = BioPawn(Outer.Pawn);
    if (Outer.Pawn != None && Outer.Pawn.Weapon != None && (Outer.IsZoomed() == FALSE || SFXWeapon_SniperRifle_Base(Outer.Pawn.Weapon) == None) && Outer.Pawn.Physics != EPhysics.PHYS_Falling)
    {
        Input = BioPlayerInput(Outer.PlayerInput);
        if (Input != None)
        {
            Weapon = SFXWeapon(Outer.Pawn.Weapon);
            if (Weapon != None && oPawn.bCombatPawn)
            {
                Weapon.CancelReload();
                if (Weapon.IsInState('WeaponEquipping', ) == FALSE && Weapon.IsInState('WeaponPuttingDown', ) == FALSE)
                {
                    if (oPawn.bStorming && Input.RawJoyUp > 0.707000017)
                    {
                        TryAcquireCover(FALSE);
                    }
                    else if (Input.RawJoyUp > 0.707000017 && (CoverAction == ECoverAction.CA_Default && CoverType != ECoverType.CT_MidLevel && CoverType != ECoverType.CT_Standing || CoverAction == ECoverAction.CA_Aimback))
                    {
                        Outer.StartCustomAction(56);
                        return TRUE;
                    }
                }
            }
        }
    }
    return FALSE;
}
// END MILAN CHANGE
// MILAN CHANGE - UP3 - Allow aimed melee and rolls with non-sniper weapons
public exec function TryHeavyMelee()
{
    local SFXWeapon Weapon;
    local BioPlayerInput Input;
    local ECoverAction CoverAction;
    local ECoverType CoverType;
    local BioPawn oPawn;
    // MILAN CHANGE - Mgamerz - 2026-10-20
    // Talon's bow and batarian gauntlet code brought up to this superclass
    local BioPawn TargetPawn;
    local SFXModule_GameEffectManager Manager;
    local int idx;
    local bool bHasGauntlet;

    if (Outer.Pawn != None && Outer.Pawn.IsA('SFXPawn_PlayerMP_Engineer_Merc') && Outer.IsLocalPlayerController())
    {
        Manager = Outer.Pawn.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None)
        {
            for (idx = 0; idx < Manager.GameEffects.Length; idx++)
            {
                if (Manager.GameEffects[idx].IsA('SFXGameEffect_MatchConsumable_Gear_BatarianGauntlet'))
                {
                    bHasGauntlet = TRUE;
                    break;
                }
            }
        }
        if (!bHasGauntlet)
        {
            if (Outer.IsMoveInputIgnored())
            {
                return;
            }
            oPawn = BioPawn(Outer.Pawn);
            if (oPawn.Weapon != None && BioPlayerInput(Outer.PlayerInput) != None)
            {
                Weapon = SFXWeapon(oPawn.Weapon);
                if (Weapon != None)
                {
                    Weapon.CancelReload();
                }
                if (oPawn.CoverType == ECoverType.CT_MidLevel && oPawn.CoverAction == ECoverAction.CA_Default)
                {
                    if (oPawn.VerifyCAHasBeenInstanced(62))
                    {
                        TargetPawn = oPawn.CustomActions[62].GetVictimPawn();
                        if (TargetPawn != None)
                        {
                            Outer.StartCustomActionWithSyncPartner(62);
                            Outer.GenerateTutorialEvent(3);
                            return;
                        }
                    }
                }
                Outer.StartCustomAction(132, , , 64);
            }
            return;
        }
    }
    // END MILAN CHANGE
    if (Outer.IsMoveInputIgnored())
    {
        return;
    }
    oPawn = BioPawn(Outer.Pawn);
    CoverAction = BioPawn(Outer.Pawn).CoverAction;
    CoverType = BioPawn(Outer.Pawn).CoverType;
    if (Outer.Pawn != None && Outer.Pawn.Weapon != None && (Outer.IsZoomed() == FALSE || SFXWeapon_SniperRifle_Base(Outer.Pawn.Weapon) == None))
    {
        Input = BioPlayerInput(Outer.PlayerInput);
        if (Input != None)
        {
            Weapon = SFXWeapon(oPawn.Weapon);
            if (Weapon != None)
            {
                Weapon.CancelReload();
            }
            if (CoverType == ECoverType.CT_MidLevel && CoverAction == ECoverAction.CA_Default)
            {
                Outer.StartCustomActionWithSyncPartner(62);
                Outer.GenerateTutorialEvent(3);
                return;
            }
            if (CoverAction == ECoverAction.CA_PeekRight && CoverType == ECoverType.CT_Standing)
            {
                Outer.StartCustomActionWithSyncPartner(69);
                Outer.GenerateTutorialEvent(12);
                return;
            }
            if (CoverAction == ECoverAction.CA_PeekRight)
            {
                Outer.StartCustomActionWithSyncPartner(70);
                Outer.GenerateTutorialEvent(12);
                return;
            }
            if (CoverAction == ECoverAction.CA_PeekLeft && CoverType == ECoverType.CT_Standing)
            {
                Outer.StartCustomActionWithSyncPartner(68);
                Outer.GenerateTutorialEvent(12);
                return;
            }
            if (CoverAction == ECoverAction.CA_PeekLeft)
            {
                Outer.StartCustomActionWithSyncPartner(71);
                Outer.GenerateTutorialEvent(12);
                return;
            }
            if (Outer.IsInCoverState() == FALSE)
            {
                if (Weapon != None)
                {
                    if (BioPawn(Outer.Pawn).bStorming == TRUE)
                    {
                        Outer.StartCustomActionWithSyncPartner(73);
                        return;
                    }
                    else if (CoverAction == ECoverAction.CA_Default && Outer.IsInState('PlayerInAimBack', ) == FALSE)
                    {
                        Outer.StartCustomActionWithSyncPartner(58);
                    }
                    Outer.HintSystem.HintEvent('Melee', Weapon.MeleePowerName);
                    Outer.GenerateTutorialEvent(3);
                }
            }
        }
    }
}
// END MILAN CHANGE
public exec function TryHolster()
{
    local BioPawn ChkPawn;
    
    ChkPawn = BioPawn(Outer.Pawn);
    if (ChkPawn != None && ChkPawn.IsReloading(TRUE) == FALSE)
    {
        if (ChkPawn.InCombat())
        {
            return;
        }
        if (ChkPawn.IsUsingPower() || ChkPawn.IsInAnimatedTransition())
        {
            return;
        }
        if (Outer.IsInCoverState())
        {
            Outer.BreakFromCover();
        }
    }
}
// MILAN CHANGE - UP3 - Allow aimed melee and rolls with non-sniper weapons
public exec function TryMelee()
{
    local SFXWeapon Weapon;
    local BioPlayerInput Input;
    local BioPawn oPawn;
    local ECoverType CoverType;
    local ECoverAction CoverAction;
    
    // MILAN CHANGE - Mgamerz - 2026-10-20
    // Talon's bow and batarian gauntlet code brought up to this superclass
    if (Outer.Pawn != None && Outer.Pawn.IsA('SFXPawn_PlayerMP_Engineer_Merc') && Outer.IsLocalPlayerController())
    {
        if (Outer.IsMoveInputIgnored())
        {
            return;
        }
        oPawn = BioPawn(Outer.Pawn);
        if (oPawn.Weapon != None && BioPlayerInput(Outer.PlayerInput) != None)
        {
            Weapon = SFXWeapon(oPawn.Weapon);
            if (Weapon != None)
            {
                Weapon.CancelReload();
                Outer.StartCustomAction(132, , , 63);
            }
        }
        return;
    }
    // END MILAN CHANGE
    if (Outer.IsMoveInputIgnored())
    {
        return;
    }
    oPawn = BioPawn(Outer.Pawn);
    if (oPawn != None)
    {
        CoverType = oPawn.CoverType;
        CoverAction = oPawn.CoverAction;
    }
    if (oPawn != None && oPawn.Weapon != None && (Outer.IsZoomed() == FALSE || SFXWeapon_SniperRifle_Base(Outer.Pawn.Weapon) == None))
    {
        Input = BioPlayerInput(Outer.PlayerInput);
        if (Input != None)
        {
            Weapon = SFXWeapon(oPawn.Weapon);
            if (Weapon != None)
            {
                Weapon.CancelReload();
                if (oPawn.IsInCover())
                {
                    if (CoverType == ECoverType.CT_MidLevel && CoverAction == ECoverAction.CA_Default)
                    {
                        Outer.StartCustomActionWithSyncPartner(62);
                        Outer.GenerateTutorialEvent(3);
                        return;
                    }
                }
                if (oPawn.bStorming == TRUE)
                {
                    Outer.StartCustomActionWithSyncPartner(73);
                    Outer.GenerateTutorialEvent(4);
                    return;
                }
                if (CoverAction == ECoverAction.CA_PeekRight && CoverType == ECoverType.CT_Standing)
                {
                    Outer.StartCustomActionWithSyncPartner(65);
                    Outer.GenerateTutorialEvent(12);
                    return;
                }
                if (CoverAction == ECoverAction.CA_PeekRight)
                {
                    Outer.StartCustomActionWithSyncPartner(66);
                    Outer.GenerateTutorialEvent(12);
                    return;
                }
                if (CoverAction == ECoverAction.CA_PeekLeft && CoverType == ECoverType.CT_Standing)
                {
                    Outer.StartCustomActionWithSyncPartner(64);
                    Outer.GenerateTutorialEvent(12);
                    return;
                }
                if (CoverAction == ECoverAction.CA_PeekLeft)
                {
                    Outer.StartCustomActionWithSyncPartner(67);
                    Outer.GenerateTutorialEvent(12);
                    return;
                }
                if (Weapon.IsInState('WeaponEquipping', ) == FALSE && Weapon.IsInState('WeaponPuttingDown', ) == FALSE)
                {
                    if (SFXWeapon_SMG_Base(Weapon) != None || SFXWeapon_Pistol_Base(Weapon) != None)
                    {
                        Outer.StartCustomActionWithSyncPartner(78);
                    }
                    else
                    {
                        Outer.StartCustomActionWithSyncPartner(75);
                    }
                    Outer.HintSystem.HintEvent('Melee', Weapon.MeleePowerName);
                    Outer.GenerateTutorialEvent(4);
                }
            }
        }
    }
}
// END MILAN CHANGE
public exec function TryReload()
{
    local SFXWeapon Weapon;
    local BioPawn m_oPawn;
    
    m_oPawn = BioPawn(Outer.Pawn);
    if (BioPlayerInput(Outer.PlayerInput).IsCombatEnabled() == FALSE)
    {
        return;
    }
    if (m_oPawn.CurrentCustomAction == 20 || m_oPawn.CurrentCustomAction == 21 || m_oPawn.CurrentCustomAction == 22 || m_oPawn.CurrentCustomAction == 23 || m_oPawn.CurrentCustomAction == 24)
    {
        m_oPawn.InterruptCustomAction();
    }
    if (Outer.Pawn != None)
    {
        Weapon = SFXWeapon(Outer.Pawn.Weapon);
        if (Weapon != None && Weapon.CanReload())
        {
            Weapon.TryReload();
        }
    }
}
// MILAN CHANGE - UP3 - Allow aimed melee and rolls with non-sniper weapons
public exec function bool TryRoll()
{
    local SFXWeapon Weapon;
    local BioPlayerInput Input;
    local BioPawn oPawn;
    local ECoverAction CoverAction;
    
    if (Outer.IsMoveInputIgnored())
    {
        return FALSE;
    }
    CoverAction = BioPawn(Outer.Pawn).CoverAction;
    oPawn = BioPawn(Outer.Pawn);
    if (Outer.Pawn != None && Outer.Pawn.Weapon != None && (Outer.IsZoomed() == FALSE || SFXWeapon_SniperRifle_Base(Outer.Pawn.Weapon) == None) && Outer.Pawn.Physics != EPhysics.PHYS_Falling)
    {
        Input = BioPlayerInput(Outer.PlayerInput);
        if (Input != None)
        {
            Weapon = SFXWeapon(Outer.Pawn.Weapon);
            if (Weapon != None && oPawn.bCombatPawn)
            {
                Weapon.CancelReload();
                if (Weapon.IsInState('WeaponEquipping', ) == FALSE && Weapon.IsInState('WeaponPuttingDown', ) == FALSE)
                {
                    if (Input.RawJoyRight > 0.707000017)
                    {
                        Outer.StartCustomAction(55);
                        return TRUE;
                    }
                    else if (Input.RawJoyRight < -0.707000017)
                    {
                        Outer.StartCustomAction(54);
                        return TRUE;
                    }
                    else if (Input.RawJoyUp < -0.707000017 && CoverAction != ECoverAction.CA_Aimback)
                    {
                        Outer.StartCustomAction(57);
                        return TRUE;
                    }
                }
            }
        }
    }
    return FALSE;
}
// END MILAN CHANGE
public exec function TrySnap()
{
    local BioPawn BP;
    local int TargetSlotIdx;
    local float TargetSlotPct;
    local ECoverDirection TargetDir;
    
    if (GetSnapTarget(TargetSlotIdx, TargetSlotPct, TargetDir))
    {
        BP = BioPawn(Outer.Pawn);
        BP.SetCoverDirection(TargetDir);
        BP.CurrentSlotPct = TargetSlotPct;
        BP.ReachedCoverSlot(TargetSlotIdx);
    }
}
public final exec function bool TryStandingJump()
{
    local SFXJumpReachSpec JumpSpec;
    
    if (Outer.FindJumpPoint(JumpSpec))
    {
        Outer.CurrentPath = JumpSpec;
        Outer.StartCustomAction(29);
        return TRUE;
    }
    return FALSE;
}
public exec function TrySwapWeapon()
{
    local SFXPawn_Player ChkPawn;
    
    ChkPawn = SFXPawn_Player(Outer.Pawn);
    if (ChkPawn != None)
    {
        if (ChkPawn.SwitchToBackupWeapon())
        {
            Outer.GenerateTutorialEvent(8);
        }
    }
}
public function bool TrySwatTurn()
{
    if (Outer.PlayerInput.RawJoyRight > 0.879999995)
    {
        if (Outer.StartCustomAction(45))
        {
            Outer.GenerateTutorialEvent(14);
            return TRUE;
        }
    }
    else if (Outer.PlayerInput.RawJoyRight < -0.879999995)
    {
        if (Outer.StartCustomAction(44))
        {
            Outer.GenerateTutorialEvent(14);
            return TRUE;
        }
    }
    return FALSE;
}
public exec function TryUsePower(int Power)
{
    local BioPlayerInput Input;
    local Name PowerName;
    local SFXPawn_Player PlayerPawn;
    local SFXPowerCustomActionBase oPower;
    
    Input = BioPlayerInput(Outer.PlayerInput);
    if (Input != None)
    {
        switch (Power)
        {
            case 0:
                PowerName = Input.m_nmMappedPower;
                break;
            case 1:
                PowerName = Input.m_nmMappedPower2;
                break;
            case 2:
                PowerName = Input.m_nmMappedPower3;
                break;
            case 3:
                PowerName = Input.m_nmMappedPower4;
                break;
            case 4:
                PowerName = Input.m_nmMappedPower5;
                break;
            case 6:
                PowerName = Input.m_nmMappedPower7;
                break;
            default:
        }
        PlayerPawn = SFXPawn_Player(Outer.Pawn);
        if (PlayerPawn.PowerManager == None)
        {
            return;
        }
        oPower = PlayerPawn.FindPower(PowerName);
        if (oPower != None)
        {
            UsePower(oPower.PowerName, PlayerPawn);
            Outer.HintSystem.HintEvent('UseMappedPower', oPower.@Class.Name);
            Outer.GenerateTutorialEvent(10);
        }
    }
}
public function TurnOffTightAim()
{
    BioPlayerInput(Outer.PlayerInput).bWantsToZoom = 0;
}
public function TurnStormOff()
{
    Outer.bWantsToStorm = 0;
}
public exec function UseAbility(int Ability)
{
    local SFXGUIInteraction oGUI;
    local SFXSFHandler_PowerWheel oPowerWheel;
    
    if (BioPlayerInput(Outer.PlayerInput).IsCombatEnabled() == FALSE)
    {
        return;
    }
    oGUI = Class'SFXGUIInteraction'.static.GetInstance();
    oPowerWheel = oGUI.CastGetMovie(Class'SFXSFHandler_PowerWheel', Outer, oGUI.MovieTag_PowerWheel);
    oPowerWheel.doHotKey(Ability);
    Outer.GenerateTutorialEvent(10);
}
public exec function bool Used()
{
    local SFXSimpleUseModule UseMod;
    local SFXDroppedPickup Pickup;
    local SFXWeaponFactory WeaponPickUp;
    local BioPawn MyBP;
    
    MyBP = BioPawn(Outer.Pawn);
    if (Outer.m_oPlayerSelection.m_oCurrentSelectionTarget == None)
    {
        return FALSE;
    }
    if (MyBP.IsInAnimatedTransition() || MyBP.CurrentCustomAction != 0)
    {
        return FALSE;
    }
    if (MyBP.IsInCover() == FALSE || SFXPawn_PlayerParty(Outer.m_oPlayerSelection.m_oCurrentSelectionTarget) != None)
    {
        ClearTimer('ResetSelectionMaterialParams', Self);
        SetTimer(0.25, FALSE, 'ResetSelectionMaterialParams', Self);
        if (Outer.TryUse(Outer.m_oPlayerSelection.m_oCurrentSelectionTarget))
        {
            SFXGRI(Outer.WorldInfo.GRI).PlayTransientSound(UseSucceeded, Outer.Pawn.location);
            Outer.m_oPlayerSelection.SetSelectionIconMaterialParam('Select_ok', 1);
            UseMod = Outer.m_oPlayerSelection.m_oCurrentSelectionTarget.GetModule(Class'SFXSimpleUseModule');
            if (BioPawn(Outer.m_oPlayerSelection.m_oCurrentSelectionTarget) == None && SFXStuntActor(Outer.m_oPlayerSelection.m_oCurrentSelectionTarget) == None && SFXSkeletalMeshActor(Outer.m_oPlayerSelection.m_oCurrentSelectionTarget) == None && MyBP.bStorming == FALSE && MyBP.bCombatPawn == TRUE && (UseMod == None || UseMod.bPlayUseAnimation == TRUE))
            {
                Pickup = SFXDroppedPickup(Outer.m_oPlayerSelection.m_oCurrentSelectionTarget);
                if (Pickup == None || ClassIsChildOf(Pickup.InventoryClass, Class'SFXHeavyWeapon') == FALSE)
                {
                    WeaponPickUp = SFXWeaponFactory(Outer.m_oPlayerSelection.m_oCurrentSelectionTarget);
                    if (WeaponPickUp == None || ClassIsChildOf(WeaponPickUp.InventoryType, Class'SFXHeavyWeapon') == FALSE)
                    {
                        Outer.StartCustomAction(4);
                    }
                }
            }
            return TRUE;
        }
        else
        {
            SFXGRI(Outer.WorldInfo.GRI).PlayTransientSound(UseFailed, Outer.Pawn.location);
            Outer.m_oPlayerSelection.SetSelectionIconMaterialParam('Select_nodice', 1);
            return FALSE;
        }
    }
    return FALSE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=SFXCameraSetup Name=CamSetup0
        Begin Template Class=SFXCameraMode_Combat Name=Aimback0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=BlindLeftCrouch0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=BlindLeftStand0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=BlindRightCrouch0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=BlindRightStand0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=CombatCam0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=DefaultCrouch0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=DefaultStand0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PeekLeftCrouch0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PeekLeftStand0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PeekRightCrouch0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PeekRightStand0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PowerCover0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PowerCoverMidLeft0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PowerCoverMidRight0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PowerCoverStdLeft0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PowerCoverStdRight0
        End Template
        Begin Template Class=SFXCameraMode_CombatStorm Name=CombatStormCam0
        End Template
        Begin Template Class=SFXCameraMode_EnterCover Name=EnterCoverCam0
        End Template
        Begin Template Class=SFXCameraMode_Explore Name=ExploreCam0
        End Template
        Begin Template Class=SFXCameraMode_ExploreStorm Name=ExploreStormCam0
        End Template
        Begin Template Class=SFXCameraMode_HipAimCover Name=BlindUp0
        End Template
        Begin Template Class=SFXCameraMode_HitReaction Name=HitReact0
        End Template
        Begin Template Class=SFXCameraMode_LadderDown Name=LadderDown0
        End Template
        Begin Template Class=SFXCameraMode_LadderUp Name=LadderUp0
        End Template
        Begin Template Class=SFXCameraMode_Melee Name=MeleeCam0
        End Template
        Begin Template Class=SFXCameraMode_Roll Name=RollCam0
        End Template
        Begin Template Class=SFXCameraMode_SplitScreenCombat Name=SSCombatCam0
        End Template
        Begin Template Class=SFXCameraMode_TightAim Name=AimbackTightAim0
        End Template
        Begin Template Class=SFXCameraMode_TightAim Name=CombatTightAim0
        End Template
        Begin Template Class=SFXCameraMode_TightAim Name=LeanLeftCrouch0
        End Template
        Begin Template Class=SFXCameraMode_TightAim Name=LeanLeftStand0
        End Template
        Begin Template Class=SFXCameraMode_TightAim Name=LeanRightCrouch0
        End Template
        Begin Template Class=SFXCameraMode_TightAim Name=LeanRightStand0
        End Template
        Begin Template Class=SFXCameraMode_TightAim Name=PopUp0
        End Template
        Begin Template Class=SFXCameraTransition_ZoomSnap Name=ZoomSnapTransition0
        End Template
        CombatCam = CombatCam0
        RollCam = RollCam0
        CombatTightAim = CombatTightAim0
        ExploreCam = ExploreCam0
        CombatStormCam = CombatStormCam0
        ExploreStormCam = ExploreStormCam0
        SSCombatCam = SSCombatCam0
        EnterCoverCam = EnterCoverCam0
        MeleeCam = MeleeCam0
        LadderUp = LadderUp0
        LadderDown = LadderDown0
        HitReact = HitReact0
        ZoomSnapTransition = ZoomSnapTransition0
        DefaultCrouch = DefaultCrouch0
        DefaultStand = DefaultStand0
        PeekLeftCrouch = PeekLeftCrouch0
        PeekLeftStand = PeekLeftStand0
        PeekRightCrouch = PeekRightCrouch0
        PeekRightStand = PeekRightStand0
        DefaultAimback = Aimback0
        AimbackTightAim = AimbackTightAim0
        BlindLeftCrouch = BlindLeftCrouch0
        BlindLeftStand = BlindLeftStand0
        BlindRightCrouch = BlindRightCrouch0
        BlindRightStand = BlindRightStand0
        BlindUp = BlindUp0
        PopUp = PopUp0
        LeanLeftCrouch = LeanLeftCrouch0
        LeanLeftStand = LeanLeftStand0
        LeanRightCrouch = LeanRightCrouch0
        LeanRightStand = LeanRightStand0
        PowerCoverPopup = PowerCover0
        PowerCoverMidLeanLeft = PowerCoverMidLeft0
        PowerCoverMidLeanRight = PowerCoverMidRight0
        PowerCoverStdLeanLeft = PowerCoverStdLeft0
        PowerCoverStdLeanRight = PowerCoverStdRight0
    End Object
    CameraSetup = CamSetup0
    InputDelayStormExit = 0.25
    InputDelayTightAimExit = 0.100000001
    CoverCamAlign = 0.699999988
    Bindings = ({
                 Command = "Console_Strafe", 
                 Name = 'XboxTypeS_LeftX', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Console_Movement", 
                 Name = 'XboxTypeS_LeftY', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Console_LookX", 
                 Name = 'XboxTypeS_RightX', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Console_LookY", 
                 Name = 'XboxTypeS_RightY', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Console_Aim", 
                 Name = 'XboxTypeS_LeftTrigger', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Console_Shoot", 
                 Name = 'XboxTypeS_RightTrigger', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Console_WeaponWheelAndQuickPower1", 
                 Name = 'XboxTypeS_LeftShoulder', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Console_PowerWheelAndQuickPower2", 
                 Name = 'XboxTypeS_RightShoulder', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Console_Menu", 
                 Name = 'XboxTypeS_Start', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Console_QuickSave", 
                 Name = 'XboxTypeS_Back', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Console_Action", 
                 Name = 'XboxTypeS_A', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Console_Melee", 
                 Name = 'XboxTypeS_B', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Console_Weapon", 
                 Name = 'XboxTypeS_X', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Console_UsePower3", 
                 Name = 'XboxTypeS_Y', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Console_SquadAttackAndPower4", 
                 Name = 'XboxTypeS_DPad_Up', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Console_SquadMove2AndPower5", 
                 Name = 'XboxTypeS_DPad_Right', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Console_SquadFollowAndPower6", 
                 Name = 'XboxTypeS_DPad_Down', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Console_SquadMove1AndPower7", 
                 Name = 'XboxTypeS_DPad_Left', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Console_NavAssistanceOrCoverTurn", 
                 Name = 'XboxTypeS_LeftThumbstick', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Console_NavAssistanceOrCoverTurn", 
                 Name = 'XboxTypeS_RightThumbstick', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Walking", 
                 Name = 'LeftControl', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_Shoot", 
                 Name = 'LeftMouseButton', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_Aim", 
                 Name = 'RightMouseButton', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_LookX", 
                 Name = 'MouseX', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_LookY", 
                 Name = 'MouseY', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_Action", 
                 Name = 'SpaceBar', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_PrevWeapon", 
                 Name = 'MouseScrollUp', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_NextWeapon", 
                 Name = 'MouseScrollDown', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_Menu", 
                 Name = 'Escape', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_HotKey1", 
                 Name = 'One', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_HotKey2", 
                 Name = 'Two', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_HotKey3", 
                 Name = 'Three', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_HotKey4", 
                 Name = 'Four', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_HotKey5", 
                 Name = 'Five', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_HotKey6", 
                 Name = 'Six', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_HotKey7", 
                 Name = 'Seven', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_HotKey8", 
                 Name = 'Eight', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_QuickSave", 
                 Name = 'F5', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_QuickLoad", 
                 Name = 'F9', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_EnterCommandMenu", 
                 Name = 'LeftShift', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_CoverTurn", 
                 Name = 'MiddleMouseButton', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_PushToTalk", 
                 Name = 'Tab', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }
               )
    bShowHUD = TRUE
    bShowSelection = TRUE
    bShowDamageIndicators = TRUE
    bShowRadar = TRUE
    bAllowRotationUpdate = TRUE
    bAllowMovement = TRUE
    bAllowCamera = TRUE
    bAllowCameraMods = TRUE
    bAllowSave = TRUE
    bAllowPauseMenu = TRUE
    bAllowHints = TRUE
    bShowSubtitle = TRUE
    bMergeNotifications = TRUE
    bShowReticles = TRUE
    bPlayVocalizations = TRUE
    bAllowMessageUI = TRUE
    bNuiSpeechGlobal = TRUE
    bNuiSpeechExplore = TRUE
    bNuiSpeechCombat = TRUE
    bAllowPowerWeaponUI = TRUE
}