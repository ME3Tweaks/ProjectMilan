// Source: ME3, Patch_AICmdBaseGethPrimeShieldDrone
// Decompiled 11/17/2026 7:37:37 AM against BioD_Gth001_600Core.pcc
Class SFXAICmd_Base_GethPrimeShieldDrone extends SFXAICommand_Base_Combat within SFXAI_GethPrimeShieldDrone;

var transient Object.Vector MoveStartLocation;

public function PeriodicMoveCheck()
{
    Super(SFXAICommand).PeriodicMoveCheck();
    if (Outer.ShouldFireRocket() || CanSuppressTarget())
    {
        Outer.MoveTarget = None;
        Outer.bReachedMoveGoal = TRUE;
    }
}
public final function bool CanSuppressTarget()
{
    local int EnemyIdx;
    
    if (Outer.InRange(Outer.FireTarget.location, Outer.EnemyDistance_Short) || Outer.InRange(Outer.FireTarget.location, Outer.EnemyDistance_Medium) == FALSE)
    {
        return FALSE;
    }
    EnemyIdx = Outer.GetEnemyIndex(Pawn(Outer.FireTarget));
    if (EnemyIdx >= 0 && Outer.IsEnemyVisibleByIndex(EnemyIdx))
    {
        return TRUE;
    }
    return FALSE;
}

auto state Combat extends InCombat 
{
    
Begin:
    if (Outer.FireTarget == None)
    {
        while (Outer.SelectTarget() == FALSE)
        {
            Outer.Sleep(1.0);
        }
    }
    if (CanSuppressTarget() == FALSE)
    {
        MoveStartLocation = Outer.MyBP.location;
        Class'SFXAICmd_MoveToSuppressionPoint'.static.MoveToSuppressionPoint(Outer, Outer.FireTarget, 1, 600.0, 3000.0, TRUE);
        if (!Outer.bReachedMoveGoal)
        {
            MoveStartLocation = Outer.MyBP.location;
            Class'SFXAICmd_MoveToGoal'.static.MoveToGoal(Outer, Outer.FireTarget, 500.0, TRUE);
        }
        Outer.Sleep(0.100000001);
    }
    if (Outer.ShouldFireRocket())
    {
        Class'SFXAICmd_UsePower'.static.UsePower(Outer, Outer.RocketPowerName, Outer.FireTarget, , TRUE);
    }
    Outer.Sleep(0.200000003);
    goto 'Begin';
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}