Class SFXAICmd_Base_Catlas extends SFXAICommand_Base_Combat within SFXAI_Catlas;

public function PeriodicMoveCheck()
{
    Super(SFXAICommand).PeriodicMoveCheck();
    if (Outer.MyBP.CurrentCustomAction == 0 && (Outer.ShouldFireRocket() || Outer.ShouldSmokeTarget()))
    {
        Outer.MoveTarget = None;
        Outer.bReachedMoveGoal = TRUE;
    }
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
    Class'SFXAICmd_MoveToGoal'.static.MoveToGoal(Outer, Outer.FireTarget, 100.0, TRUE);
    if (Outer.ShouldSmokeTarget())
    {
        Class'SFXAICmd_Catlas_SmokeTarget'.static.SmokeBetweenUs(Outer, Outer.FireTarget);
        Outer.LastSmokeTime = Outer.WorldInfo.GameTimeSeconds;
    }
    else if (Outer.ShouldFireRocket())
    {
        Outer.Focus = Outer.FireTarget;
        if (Normal(Outer.FireTarget.location - Outer.MyBP.location) Dot Vector(Outer.MyBP.Rotation) > Outer.RocketConeAngle)
        {
            Class'SFXAICmd_UsePower'.static.UsePower(Outer, Outer.RocketAttack, Outer.FireTarget, , TRUE);
            Outer.LastRocketTime = Outer.WorldInfo.GameTimeSeconds;
            Outer.Sleep(1.5 + FRand());
        }
    }
    else
    {
        Outer.ShootWeaponAtFireTarget();
    }
    Outer.Sleep(0.100000001);
    goto 'Begin';
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}