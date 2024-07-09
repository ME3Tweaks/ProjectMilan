Class SFXAICmd_MoveToGoal_Executioner extends SFXAICmd_MoveToGoal within SFXAI_Executioner;

var transient Actor m_oTempGoalActor_Executioner;
var transient bool m_bMovingToFireTarget_Executioner;

public function UpdateMovementActions()
{
    local float fDist;
    local float fDot;
    local Vector vTargetVector;
    local Vector vMoveVector;
    local Actor OriginalFocus;
    
    if (ChildCommand != None)
    {
        return;
    }
    OriginalFocus = Outer.Focus;
    if (Outer.MyBP.bCanStrafe && Outer.HasValidTarget())
    {
        fDist = VSizeSq(Outer.MyBP.location - Outer.MoveTarget.location);
        if (IsSpecialMoveAfterCurrentMoveTarget() && fDist < 250000.0)
        {
            Outer.Focus = Outer.MoveTarget;
            if (Outer.FireTarget != None && Outer.IsFiringWeapon())
            {
                vTargetVector = Outer.FireTarget.location - Outer.MyBP.location;
                vMoveVector = Outer.MoveTarget.location - Outer.MyBP.location;
                fDot = vTargetVector Dot vMoveVector;
                if (fDot < Outer.m_fFiringArcAngle)
                {
                    StopFiringWeapon();
                }
            }
        }
        else
        {
            Outer.UpdateMovementFocus();
        }
    }
    else
    {
        Outer.Focus = Outer.MoveTarget;
    }
    if (OriginalFocus != Outer.Focus)
    {
        Outer.MyBP.ResetDesiredRotation();
    }
    if (FRand() < Outer.PowerToFiringRatio)
    {
        if (Outer.ShouldUsePower())
        {
            Outer.Focus = Outer.FireTarget;
            if (Normal(Outer.FireTarget.location - Outer.MyBP.location) Dot Vector(Outer.MyBP.Rotation) > Outer.GrenadeConeAngle)
            {
                Outer.LastPowerTime = Outer.WorldInfo.GameTimeSeconds;
                Class'SFXAICmd_UsePower'.static.UsePower(Outer, Outer.GetPowerName(), Outer.FireTarget, , TRUE);
            }
        }
    }
    else if (Outer.IsFiringWeapon() == FALSE && CanStartFiring())
    {
        StartFiringWeapon();
    }
    Outer.MyBP.DestinationOffset = GetMoveOffset();
}
public function bool ApplyPathConstraints()
{
    local bool bAppliedConstraints;
    local Vector LastMantleLocation;
    local Goal_AtActor oAtGoalEval;
    
    bAppliedConstraints = FALSE;
    if (Class'Goal_AtActor'.static.AtActor(Outer.MyBP, Outer.MoveGoal, Outer.MoveOffset, m_bUsePartialPaths))
    {
        oAtGoalEval = Goal_AtActor(Outer.MyBP.PathGoalList);
        m_oTempGoalActor_Executioner = oAtGoalEval.GoalActor;
        Class'Path_TowardGoal'.static.TowardGoal(Outer.MyBP, Outer.MoveGoal);
        Outer.ApplyBasePathConstraints();
        Class'SFXPath_AvoidClaimedCover'.static.AvoidClaimedCover(Outer.MyBP);
        if (Outer.WorldInfo.GameTimeSeconds - Outer.MyBP.LastMantleTime < 5.0)
        {
            LastMantleLocation = Outer.MyBP.LastMantleLocation;
        }
        if (Outer.MyBP.bCanMantle || Outer.MyBP.bCanClimbUp)
        {
            Class'Path_MinDistBetweenSpecsOfType'.static.EnforceMinDist(Outer.MyBP, 500.0, Class'MantleReachSpec', LastMantleLocation);
        }
        if (Outer.m_bAvoidDangerLinks)
        {
            Class'SFXPath_AvoidFireFromCover'.static.AvoidFireFromCover(Outer.MyBP, Outer.m_bAvoidFireFromPlayerOnly);
        }
        bAppliedConstraints = TRUE;
    }
    return bAppliedConstraints;
}
public function FinishPathGeneration()
{
    if (m_bMovingToFireTarget_Executioner && Outer.MoveGoal != Outer.FireTarget)
    {
        Outer.AILog_Internal("Cancelling Move.  AI has changed fire target while generating a path towards the old fire target", 'Move');
        Outer.MoveTarget = None;
    }
    else if (Outer.RouteGoal != m_oTempGoalActor_Executioner)
    {
        if (VSizeSq(Outer.RouteGoal.location - m_oTempGoalActor_Executioner.location) > Outer.MoveOffset * Outer.MoveOffset)
        {
            Outer.AILog_Internal("Using a partial path to move towards: " $ Outer.MoveGoal, 'Move');
        }
    }
}
public static function bool MoveToGoal(SFXAI_Core AI, Actor NewMoveGoal, optional float NewMoveOffset, optional bool bInAllowedToFire = TRUE, optional bool bInAllowPartialPath = TRUE, optional bool bInRotateBeforeMoving = FALSE)
{
    local SFXAICmd_MoveToGoal_Executioner Cmd;
    
    if (AI != None && NewMoveGoal != None)
    {
        Cmd = new (SFXAI_Executioner(AI)) Class'SFXAICmd_MoveToGoal_Executioner';
        if (Cmd != None)
        {
            if (Controller(NewMoveGoal) != None)
            {
                NewMoveGoal = Controller(NewMoveGoal).Pawn;
            }
            Cmd.Outer.MoveGoal = NewMoveGoal;
            Cmd.Outer.MoveOffset = NewMoveOffset;
            Cmd.m_bAllowedToFire = bInAllowedToFire;
            Cmd.m_bUsePartialPaths = bInAllowPartialPath;
            Cmd.m_bRotateBeforeMoving = bInRotateBeforeMoving;
            Cmd.m_bMovingToFireTarget_Executioner = AI.FireTarget != None && AI.FireTarget == NewMoveGoal;
            if (AI != None)
            {
                AI.AILog_Internal("Starting move to goal to " $ NewMoveGoal $ ". Offset: " $ NewMoveOffset $ ", Can Fire: " $ bInAllowedToFire $ ", Partial: " $ bInAllowPartialPath, 'Move');
            }
            AI.PushCommand(Cmd);
            return TRUE;
        }
    }
    return FALSE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}