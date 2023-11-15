Class SFXGameEffect_MatchConsumableBase extends SFXGameEffect
    config(Game);

// Variables
var config int VersionCount;
var int VersionIdx;
var SFXPawn OwnerPawn;

// Functions
public function OnApplied()
{
    if (Owner == None)
    {
        return;
    }
    OwnerPawn = SFXPawn(Owner);
    if (OwnerPawn == None)
    {
        return;
    }
    VersionIdx = int(EffectValue);
    if (VersionIdx >= VersionCount)
    {
        return;
    }
    Super.OnApplied();
}
public function Consume()
{
    local SFXEngine Engine;
    local int CurrentValue;
    
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Engine == None)
    {
        return;
    }
    CurrentValue = Engine.GetPlayerVariable(Name((PathName(Class) $ "_") $ VersionIdx));
    CurrentValue = Max(0, CurrentValue - 1);
    Engine.SetPlayerVariable(Name((PathName(Class) $ "_") $ VersionIdx), CurrentValue);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}