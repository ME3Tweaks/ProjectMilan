Class SFXAICmd_Agent_Aggressive extends SFXAICmd_Base_Melee within SFXAI_Agent;

var float AggressiveDuration;
var transient bool bMeleed;

public function PeriodicMoveCheck()
{
    Super(SFXAICommand).PeriodicMoveCheck();
    if (ShouldUsePowerSlash())
    {
        Outer.MoveTarget = None;
        Outer.bReachedMoveGoal = TRUE;
    }
}
public function Popped()
{
    Outer.ClearTimer('AggressiveTimeout', Self);
    Super(SFXAICommand_Base_Combat).Popped();
}
public function Pushed()
{
    Super(SFXAICommand_Base_Combat).Pushed();
    Outer.SetTimer(AggressiveDuration, FALSE, 'AggressiveTimeout', Self);
    bMeleed = FALSE;
    Outer.AgentState = EAgentState.Agent_Aggressive;
}
public function AggressiveTimeout()
{
    Outer.BeginCombatCommand(Class'SFXAICmd_Base_Agent');
}
public final function bool ShouldUsePowerSlash()
{
    local SFXPowerCustomActionBase Power;
    
    if (Outer.bIsAttemptingSyncAttack == FALSE && Outer.MyBP.CurrentCustomAction == 0 && Outer.WorldInfo.GameTimeSeconds - Outer.LastPowerSlashTime > Outer.PowerSlashInterval)
    {
        Power = Outer.MyBP.PowerManager.GetPower(Outer.KaiLengSlashPowerName);
        if (Power != None)
        {
            return Power.CanUsePower(Outer.FireTarget);
        }
    }
    return FALSE;
}

auto state Melee 
{
    
Begin:
    if (Outer.FireTarget == None || Pawn(Outer.FireTarget) != None && Pawn(Outer.FireTarget).IsDead())
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
    if (ShouldUsePowerSlash())
    {
        Outer.SetFocalPoint(Outer.FireTarget.location);
        Class'SFXAICmd_UsePower'.static.UsePower(Outer, Outer.KaiLengSlashPowerName, Outer.FireTarget, , TRUE);
        Outer.LastPowerSlashTime = Outer.WorldInfo.GameTimeSeconds;
    }
    if (Outer.bReachedMoveGoal)
    {
        if (SFXPawn_Player(Outer.Enemy) != None && Outer.MyBP.IsValidTargetFor(Outer.Enemy.Controller) && Outer.InRange(Outer.Enemy.location, Outer.EnemyDistance_Short) && Outer.ShouldSyncMelee(Outer.Enemy) && Outer.bIsAttemptingSyncAttack == TRUE)
        {
            // SyncAttack
            Outer.MyBP.StartCustomAction(135, Outer.Enemy);
        }
        if (Outer.MyBP.IsValidTargetFor(Outer.Enemy.Controller) && Outer.InRange(Outer.Enemy.location, Outer.EnemyDistance_Short) && Outer.ShouldMelee(Outer.Enemy))
        {
            Outer.MyBP.StartCustomAction(134);
            bMeleed = TRUE;
        }
        if (Outer.MyBP.IsValidTargetFor(Outer.Enemy.Controller) && Outer.InRange(Outer.Enemy.location, Outer.EnemyDistance_Melee) && Outer.ShouldMelee(Outer.Enemy))
        {
            Outer.MyBP.StartCustomAction(133);
            bMeleed = TRUE;
        }
        if (Outer.MyBP.IsValidTargetFor(Outer.Enemy.Controller) && Outer.InRange(Outer.Enemy.location, Outer.EnemyDistance_Melee))
        {
            Outer.MyBP.StartCustomAction(147);
            Outer.LastMeleeTime = Outer.WorldInfo.GameTimeSeconds;
            bMeleed = TRUE;
        }
        if (bMeleed)
        {
            Outer.MyBP.StartCustomAction(57);
            AggressiveTimeout();
        }
    }
    else
    {
        Outer.AILog_Internal("Failed to find path to attack enemy");
    }
    Outer.Sleep(0.200000003);
    goto 'Begin';
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    AggressiveDuration = 20.0
}