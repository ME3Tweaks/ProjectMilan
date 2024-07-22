Class SFXAICmd_Reaction_AgentHeal extends SFXAICommand_Base_Combat within SFXAI_Agent;

var transient NavigationPoint AgentShieldNav;

public function Popped()
{
    Super.Popped();
    if (Outer.MyBP != None)
    {
        Outer.MyBP.bCanStrafe = Outer.MyBP.default.bCanStrafe;
    }
    AgentShieldNav = None;
    // Once this attack is complete we unlock new ability to sync a target once
    Outer.bIsAttemptingSyncAttack = TRUE;
}
public function Pushed()
{
    local NavigationPoint Nav;
    local float Distance;
    
    Super.Pushed();
    // Agent will run at the player if it is near in order to use the heal as an attack
    if (Outer.FireTarget != None)
    {
        Distance = VSize(Outer.FireTarget.location - Outer.MyBP.location);
        if (Distance < 1000.0)
        {
            Nav = Class'NavigationPoint'.static.GetNearestNavToActor(Outer.FireTarget);
        }
    }
    if (Nav == None)
    {
        // No nav was chosen, too far away
        Nav = Class'NavigationPoint'.static.GetNearestNavToActor(Outer.Pawn);
    }
    AgentShieldNav = Nav;
    LogInternal("Regen START at Nav "$Nav);
    Outer.MyBP.StartCustomAction(56); // Roll foward
    if (Outer.MyBP != None)
    {
        Outer.MyBP.bCanStrafe = FALSE;
    }
    Outer.FireTarget = None;
    Outer.AgentState = EAgentState.Agent_Fleeing;
}

auto state RunToShield 
{
    
Begin:
    if (AgentShieldNav != None)
    {
        Outer.bReachedMoveGoal = FALSE;
        while (!Outer.bReachedMoveGoal)
        {
            Outer.Sleep(0.200000003);
            Class'SFXAICmd_MoveToGoal'.static.MoveToGoal(Outer, AgentShieldNav, 10.0);
        }
        Outer.MyBP.SetDesiredRotation(AgentShieldNav.Rotation);
        Outer.FinishRotation();
        Outer.MyBP.StartCustomAction(146);
        // Super Vortex
    }
    Outer.BeginCombatCommand(Class'SFXAICmd_Agent_Aggressive');
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}