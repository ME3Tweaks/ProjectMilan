Class SFXAICmd_AcquireCover_Executioner extends SFXAICmd_AcquireCover within SFXAI_Executioner;

public static function bool AcquireNewCover(SFXAI_Cover AI, Goal_AtCover GoalEvaluator, Actor GoalActor, optional bool bUsePeriodicCheck = TRUE, optional bool bAllowedToFire = TRUE)
{
    local SFXAICmd_AcquireCover_Executioner Cmd;
    
    if (AI != None && AI.MyBP != None && GoalEvaluator != None && GoalActor != None)
    {
        Cmd = new (SFXAI_Executioner(AI)) Class'SFXAICmd_AcquireCover_Executioner';
        if (Cmd != None)
        {
            Cmd.CoverEvaluator = GoalEvaluator;
            Cmd.CoverGoalActor = GoalActor;
            Cmd.bDoPeriodicCoverCheck = bUsePeriodicCheck;
            Cmd.bCanShoot = bAllowedToFire;
            if (AI != None)
            {
                AI.AILog_Internal("Looking for cover against " $ GoalActor $ ". Goal Evaluator: " $ GoalEvaluator $ ", Use Periodic Check: " $ bUsePeriodicCheck $ ", Can Shoot: " $ bAllowedToFire, 'Cover');
            }
            AI.PushCommand(Cmd);
            return TRUE;
        }
    }
    return FALSE;
}

auto state FindingCover 
{
    
Begin:
    if (Outer.WorldInfo.GameTimeSeconds - Outer.LastFailedPathTime < 0.5 && Outer.WorldInfo.GameTimeSeconds - Outer.MyBP.FindAnchorFailedTime < 0.5)
    {
        Outer.Sleep(0.25);
        Outer.PopCommand(Self);
    }
    Outer.MyCoverEval = CoverEvaluator;
    Outer.InitializeCoverConstraints(CoverEvaluator, CoverGoalActor);
    Outer.FindPathTowardIterative(CoverGoalActor, FALSE, 2000);
    if (Outer.MoveTarget == None)
    {
        if (Outer.WorldInfo.GameTimeSeconds - Outer.LastFailedPathTime < 1.0 && (Outer.WorldInfo.GameTimeSeconds - Outer.MyBP.LastValidAnchorTime > Outer.StuckTimeout || Outer.WorldInfo.GameTimeSeconds - Outer.LastSuccessfulPathTime > Outer.StuckTimeout))
        {
            Outer.NotifyStuck();
        }
        Outer.LastFailedPathTime = Outer.WorldInfo.GameTimeSeconds;
        Outer.AILog_Internal("Failed to find cover to goal actor: " $ CoverGoalActor, 'Cover');
        Outer.PopCommand(Self);
    }
    Outer.LastSuccessfulPathTime = Outer.WorldInfo.GameTimeSeconds;
    NewCoverGoal = CoverSlotMarker(Outer.RouteCache[Outer.RouteCache.Length - 1]).OwningSlot;
    if (Outer.IsValidCover(NewCoverGoal) == FALSE || NewCoverGoal.Link.Slots[NewCoverGoal.SlotIdx].SlotMarker == None)
    {
        Outer.PopCommand(Self);
    }
    if (Outer.MyBP.CurrentLink == NewCoverGoal.Link && Outer.MyBP.CurrentSlotIdx == NewCoverGoal.SlotIdx)
    {
        Outer.bReachedCover = TRUE;
        Outer.PopCommand(Self);
    }
    if (Outer.ClaimCover(NewCoverGoal) == FALSE)
    {
        Outer.PopCommand(Self);
    }
    Outer.CoverGoal = NewCoverGoal;
    Outer.m_bUsePeriodicCoverCheck = bDoPeriodicCoverCheck;
    Class'SFXAICmd_MoveToCover_Executioner'.static.MoveToCover(Outer, Outer.m_bUsePeriodicCoverCheck, bCanShoot);
    Outer.PopCommand(Self);
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}