Class SFXAICmd_Reaction_ForerunnerFlee extends SFXAICommand_Base_Combat within SFXAI_Forerunner;

var(SFXAICmd_Reaction_ForerunnerFlee) Actor FleeTarget;
var(SFXAICmd_Reaction_ForerunnerFlee) transient bool bReacted;

public function NotifyPendingPowerImpact(Name Label, float TimeBeforeImpact, SFXPowerCustomAction Power, SFXProjectile_PowerCustomAction Projectile)
{
    local EAICustomAction EvadeAction;
    
    Super(SFXAICommand).NotifyPendingPowerImpact(Label, TimeBeforeImpact, Power, Projectile);
    if (Outer.MyBP.CurrentCustomAction == 0)
    {
        if (Label == 'CombatRoll')
        {
            if (Outer.WorldInfo.GameTimeSeconds - Outer.LastEvadeTime >= Outer.EvadeFrequency && Outer.ShouldPowerEvade())
            {
                EvadeAction = Outer.GetBestEvadeDir(Projectile.location, Projectile);
                if (EvadeAction != EAICustomAction.CA_None)
                {
                    Outer.MyBP.StartCustomAction(int(EvadeAction));
                    Outer.LastEvadeTime = Outer.WorldInfo.GameTimeSeconds;
                    if (Projectile != None)
                    {
                        Projectile.PawnEvadedPower(Outer.MyBP, Label, TimeBeforeImpact);
                    }
                }
            }
        }
    }
}
public function Popped()
{
    Super.Popped();
    if (Outer.MyBP != None)
    {
        Outer.MyBP.bCanStrafe = Outer.MyBP.default.bCanStrafe;
    }
    Outer.SetTimer(0.5 + FRand() * 0.200000003, TRUE, 'SelectTarget', );
    Outer.Decloak();
}
public function Pushed()
{
    Super.Pushed();
    if (Outer.MyBP != None)
    {
        Outer.MyBP.bCanStrafe = FALSE;
    }
    FleeTarget = Outer.FireTarget;
    Outer.FireTarget = None;
    Outer.ClearTimer('SelectTarget');
    Outer.AttemptCloak();
}

auto state RunAway extends InCombat 
{
    
Begin:
    if (!bReacted)
    {
        bReacted = TRUE;
        Outer.Sleep(Outer.FlankReactionTime);
    }
    Outer.FindNewCover();
    Class'SFXAICmd_AcquireCover'.static.AcquireNewCover(Outer, Outer.AtCover_WeaponRange, FleeTarget, , FALSE);
    if (Outer.bReachedCover)
    {
        Outer.SetTimer(Outer.GetCoverDelayTime(), FALSE, 'FindNewCover', );
        Outer.bAcquireNewCover = FALSE;
        Outer.PopCommand(Self);
    }
    Outer.Sleep(0.100000001);
    goto 'Begin';
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}