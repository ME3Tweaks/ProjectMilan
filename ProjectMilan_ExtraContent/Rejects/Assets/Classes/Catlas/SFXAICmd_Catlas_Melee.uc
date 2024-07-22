Class SFXAICmd_Catlas_Melee extends SFXAICmd_Base_Melee within SFXAI_Catlas;

var transient bool bMeleed;

public function PeriodicMoveCheck()
{
    Super(SFXAICommand).PeriodicMoveCheck();
    if (Outer.IsAtlasInRange(Outer.EnemyDistance_Melee) && Outer.ShouldMelee(Outer.FireTarget))
    {
        Outer.MoveGoal = None;
        Outer.bReachedMoveGoal = TRUE;
    }
}

auto state Melee 
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
    if (Outer.InRange(Outer.Enemy.location, Outer.EnemyDistance_Melee) == FALSE || IsProtectedByCover(Outer.Enemy))
    {
        Outer.AILog_Internal("Enemy not in range or can't melee effectively (target protected by cover)", 'Combat');
        SetupTimeout();
        Class'SFXAICmd_MoveToGoal'.static.MoveToGoal(Outer, Outer.Enemy, Outer.MeleeMoveOffset, , FALSE);
    }
    else if (Outer.Pawn.FastTrace(Outer.Enemy.location, Outer.Pawn.location, , ) == FALSE)
    {
        Outer.AILog_Internal("No LOS to enemy, moving...", 'Combat');
        Class'SFXAICmd_MoveToGoal'.static.MoveToGoal(Outer, Outer.Enemy, Outer.MeleeMoveOffset, , FALSE);
    }
    else
    {
        Outer.bReachedMoveGoal = TRUE;
    }
    if (Outer.bReachedMoveGoal)
    {
        if (Outer.IsAtlasInRange(Outer.EnemyDistance_Melee) && Outer.ShouldMelee(Outer.FireTarget))
        {
            Outer.SetDesiredRotation(Rotator(Outer.FireTarget.location - Outer.Pawn.location));
            Outer.FinishRotation();
            bMeleed = Outer.MyBP.StartCustomAction(FRand() > 0.5 ? 133 : 134);
            if (bMeleed)
            {
                Outer.Sleep(0.5);
            }
        }
        Outer.LastMeleeTime = Outer.WorldInfo.GameTimeSeconds;
        if (bMeleed && FRand() <= Outer.SyncKillChance && Outer.IsAtlasInRange(Outer.EnemyDistance_Melee) && Outer.ShouldSyncMelee(Outer.FireTarget))
        {
            Outer.MyBP.StartCustomAction(135, BioPawn(Outer.FireTarget));
            Outer.LastSyncMeleeTime = Outer.WorldInfo.GameTimeSeconds;
        }
    }
    else
    {
        Outer.AILog_Internal("Failed to find path to attack enemy");
    }
    Outer.BeginDefaultCommand();
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}