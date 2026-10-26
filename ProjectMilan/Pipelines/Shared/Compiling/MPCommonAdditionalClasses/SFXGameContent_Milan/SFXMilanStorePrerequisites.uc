// MILAN CHANGE - Mgamerz
// Store prerequesites allows filtering out cards based on if you have acquired another
class SFXMilanStorePrerequisites extends Object 
    config(Game);

struct CardRequirement
{
    var string CardName;
    var name RequiredVariable;
};
var config array<CardRequirement> Requirements;

public static final function bool CanAward(string CardName)
{
    local int Index;
    local SFXEngine Engine;

    Index = default.Requirements.Find('CardName', CardName);
    if (Index == -1)
    {
        return TRUE;
    }
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    return Engine != None && Engine.GetPlayerVariable(default.Requirements[Index].RequiredVariable) > 0;
}

defaultproperties
{
}