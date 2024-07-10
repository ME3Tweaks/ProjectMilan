Class SFXAICmd_Base_RampartMP extends SFXAICmd_Base_Cover within SFXAI_RampartMP;

public function bool IsCombatStale()
{
    return FALSE;
}
public function NotifyFriendDied(BioPawn FriendPawn)
{
    if (SFXPawn_RampartMP(FriendPawn) != None && CheckAggressiveTransition())
    {
        Outer.SetCombatMood(4);
    }
}
public function PeriodicMoveCheck()
{
    Super(SFXAICommand).PeriodicMoveCheck();
    if (CheckAggressiveTransition())
    {
        Outer.MoveTarget = None;
        Outer.bReachedMoveGoal = TRUE;
    }
}
public final function bool CheckAggressiveTransition()
{
    local SFXAI_RampartMP AI;
    local int NumAggressive;
    local PlayerController PC;
    
    if (SFXPawn_RampartMP(Outer.MyBP) != None && !SFXPawn_RampartMP(Outer.MyBP).bAggressive && !SFXPawn_RampartMP(Outer.MyBP).bNeverTurnAggressive)
    {
        foreach Outer.WorldInfo.AllControllers(Class'SFXAI_RampartMP', AI)
        {
            if (AI != None && SFXPawn_RampartMP(AI.MyBP) != None && SFXPawn_RampartMP(AI.MyBP).bAggressive)
            {
                NumAggressive++;
            }
        }
        if (NumAggressive < SFXGRI(Outer.WorldInfo.GRI).NumPlayersInGame())
        {
            foreach Outer.LocalPlayerControllers(Class'PlayerController', PC)
            {
                if (VSize(PC.Pawn.location - Outer.Pawn.location) < Outer.AggroDistanceThreshold)
                {
                    return TRUE;
                }
                return FALSE;
            }
        }
    }
    return FALSE;
}

auto state Combat 
{
    
Begin:
    if (Outer.FireTarget == None)
    {
        Outer.AILog_Internal("Lost enemy.  Re-acquiring target", 'Combat');
        while (Outer.SelectTarget() == FALSE)
        {
            Outer.Sleep(1.0);
        }
    }
    if (Outer.bAcquireNewCover)
    {
        if (SFXPawn(Outer.Pawn) != None)
        {
            SFXPawn(Outer.Pawn).PlayMoveToCoverSound();
        }
        if (SFXPawn_RampartMP(Outer.MyBP) != None && !SFXPawn_RampartMP(Outer.MyBP).bAggressive && !Outer.IsTargetStealthed())
        {
            Class'SFXAICmd_AcquireCover'.static.AcquireNewCover(Outer, Outer.AtCover_Aggressive, Outer.FireTarget);
        }
        else
        {
            Class'SFXAICmd_AcquireCover'.static.AcquireNewCover(Outer, Outer.AtCover_WeaponRange, Outer.FireTarget);
        }
        if (Outer.bReachedCover == FALSE && SFXPawn_RampartMP(Outer.MyBP) != None && SFXPawn_RampartMP(Outer.MyBP).bAggressive && !Outer.IsTargetStealthed())
        {
            Class'SFXAICmd_MoveToGoal'.static.MoveToGoal(Outer, Outer.FireTarget, 100.0);
            Outer.bAcquireNewCover = FALSE;
        }
        Outer.SetTimer(Outer.GetCoverDelayTime(), FALSE, 'FindNewCover', );
    }
    if (CheckAggressiveTransition())
    {
        Outer.SetCombatMood(4);
    }
    if (Outer.bAcquireNewCover == FALSE || Outer.bReachedCover)
    {
        Outer.bAcquireNewCover = FALSE;
        Outer.bReachedCover = FALSE;
        if (ShouldAttack())
        {
            Outer.ShootWeaponAtFireTarget(Outer.MyBP.GetMaxHealth() * Outer.CancelFirePct);
            if (!Outer.bAcquireNewCover)
            {
                Outer.Sleep(Outer.GetActionDelayTime());
            }
        }
    }
    Outer.Sleep(0.100000001);
    goto 'Begin';
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}