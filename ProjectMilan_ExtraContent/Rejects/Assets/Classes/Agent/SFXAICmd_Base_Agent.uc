Class SFXAICmd_Base_Agent extends SFXAICommand_Base_Combat within SFXAI_Agent;

public function Pushed()
{
    Super.Pushed();
    Outer.AgentState = EAgentState.Agent_Normal;
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
    if (Outer.bAcquireNewCover)
    {
        Class'SFXAICmd_AcquireCover'.static.AcquireNewCover(Outer, Outer.AtCover_WeaponRange, Outer.FireTarget);
        if (Outer.bReachedCover)
        {
            Outer.SetTimer(Outer.GetCoverDelayTime(), FALSE, 'FindNewCover', );
        }
    }
    if (Outer.bAcquireNewCover == FALSE || Outer.bReachedCover)
    {
        Outer.bAcquireNewCover = FALSE;
        Outer.bReachedCover = FALSE;
        Class'SFXAICmd_FireWeapon'.static.FireWeapon(Outer, Outer.MyBP.GetMaxHealth() * Outer.CancelFirePct);
        Outer.Sleep(1.0 + FRand());
    }
    Outer.BeginCombatCommand(Class'SFXAICmd_Agent_Aggressive');
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}