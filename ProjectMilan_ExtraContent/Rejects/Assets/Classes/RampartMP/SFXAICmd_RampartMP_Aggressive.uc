Class SFXAICmd_RampartMP_Aggressive extends SFXAICmd_Base_Melee within SFXAI_RampartMP;

var Vector TargetInitialLoc;

public function PeriodicMoveCheck()
{
    Super(SFXAICommand).PeriodicMoveCheck();
    if (Outer.IsRampartInRange(Outer.EnemyDistance_Melee) && Outer.ShouldMelee(Outer.FireTarget))
    {
        Outer.MoveGoal = None;
        Outer.bReachedMoveGoal = TRUE;
    }
}
public function Popped()
{
    local SFXPawn_RampartMP AIPawn;
    
    AIPawn = SFXPawn_RampartMP(Outer.Pawn);
    Super(SFXAICommand_Base_Combat).Popped();
    if (AIPawn != None)
    {
        AIPawn.CombatGroundSpeed = AIPawn.default.CombatGroundSpeed;
    }
    Outer.LastAggressiveTime = Outer.WorldInfo.GameTimeSeconds;
}
public function Pushed()
{
    local SFXPawn_RampartMP AIPawn;
    local SFXModule_GameEffectManager Manager;
    local SFXDifficultyHandler DH;
    
    AIPawn = SFXPawn_RampartMP(Outer.Pawn);
    if (AIPawn != None && !AIPawn.bIsAggressive)
    {
        AIPawn.StartAggressiveFX();
        AIPawn.StopShieldGenerator();
        AIPawn.CombatGroundSpeed = 370.0;
        AIPawn.bAggressive = TRUE;
        Outer.m_bAvoidDangerLinks = FALSE;
        Manager = AIPawn.GetModule(Class'SFXModule_GameEffectManager');
        DH = SFXGRI(Outer.WorldInfo.GRI).DifficultyHandler;
        if (DH != None && Manager != None)
        {
            Manager.CreateAndApplyEffect(Class'SFXGameEffect_DamageTakenBonus', 'AggressiveRampart', 0.0, 2, -DH.GetFloat('AggressiveDamageReduction', 'RampartMP'), AIPawn.Controller, AIPawn);
        }
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
    if (Outer.InRange(Outer.FireTarget.location, Outer.EnemyDistance_Melee) == FALSE || IsProtectedByCover(Pawn(Outer.FireTarget)))
    {
        Outer.AILog_Internal("Enemy not in range or can't melee effectively (target protected by cover)", 'Combat');
        SetupTimeout();
        TargetInitialLoc = Outer.FireTarget.location;
        Class'SFXAICmd_MoveToGoal'.static.MoveToGoal(Outer, Outer.FireTarget, Outer.MeleeMoveOffset, , FALSE);
    }
    else if (Outer.Pawn.FastTrace(Outer.FireTarget.location, Outer.Pawn.location, , ) == FALSE)
    {
        Outer.AILog_Internal("No LOS to enemy, moving...", 'Combat');
        TargetInitialLoc = Outer.FireTarget.location;
        Class'SFXAICmd_MoveToGoal'.static.MoveToGoal(Outer, Outer.FireTarget, Outer.MeleeMoveOffset, , FALSE);
    }
    else
    {
        Outer.bReachedMoveGoal = TRUE;
    }
    if (Outer.bReachedMoveGoal)
    {
        if (Outer.IsRampartInRange(Outer.EnemyDistance_Melee) && Outer.ShouldMelee(Outer.FireTarget))
        {
            Outer.SetDesiredRotation(Rotator(Outer.FireTarget.location - Outer.Pawn.location));
            Outer.FinishRotation();
            if (SFXPawn(Outer.FireTarget) != None && SFXPawn(Outer.FireTarget).IsInvisible())
            {
                Outer.Focus = Outer.FireTarget;
            }
            Outer.MyBP.StartCustomAction(133);
            Outer.LastMeleeTime = Outer.WorldInfo.GameTimeSeconds;
        }
    }
    else
    {
        Outer.AILog_Internal("Failed to find path to attack enemy");
    }
    Outer.Sleep(0.100000001);
    goto 'Begin';
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}