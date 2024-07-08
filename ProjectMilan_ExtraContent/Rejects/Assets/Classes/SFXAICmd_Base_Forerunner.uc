Class SFXAICmd_Base_Forerunner extends SFXAICmd_Base_Cover within SFXAI_Forerunner;

public function bool ShouldAttack()
{
    if (Outer.MyBP.GetCurrentShields() > float(0))
    {
        return Super.ShouldAttack();
    }
    return FALSE;
}

auto state Combat 
{
    
Begin:
    Outer.FindDrivablePawn();
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
        Outer.AttemptCloak();
        Class'SFXAICmd_AcquireCover'.static.AcquireNewCover(Outer, Outer.AtCover_WeaponRange, Outer.FireTarget, , TRUE);
        Outer.SetTimer(Outer.GetCoverDelayTime(), FALSE, 'FindNewCover', );
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