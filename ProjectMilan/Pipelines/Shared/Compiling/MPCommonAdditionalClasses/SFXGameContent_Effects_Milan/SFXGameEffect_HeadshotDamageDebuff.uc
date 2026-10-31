// 08/27/2026 - Mgamerz
// Game effect that applies a headshot damage multiplier onto the host
// Requires changes to SFXGame to work as HeadshotDamageTakenMultiplier does not exist in vanilla LE3.
// Created for supporting the Rank 5A headshot damage effect of Tactical Scan that appears was abandoned mid development due to lack of the necessary support in the base game.
Class SFXGameEffect_HeadshotDamageDebuff extends SFXGameEffect;

public function OnRemoved()
{
    local SFXModule_Damage DmgModule;
    
    Super.OnRemoved();
    if (Owner != None)
    {
        DmgModule = Owner.GetModule(Class'SFXModule_Damage');
        if (DmgModule != None)
        {
            // Register the headshot effect on the headshot bonus list
            DmgModule.HeadshotDamageTakenMultiplier.Bonuses.RemoveItem(Self);
            Class'SFXGame'.static.ReCalculate(DmgModule.HeadshotDamageTakenMultiplier);
        }
    }
}
public function OnApplied()
{
    local SFXModule_Damage DmgModule;
    
    Super.OnApplied();
    if (Owner != None)
    {
        DmgModule = Owner.GetModule(Class'SFXModule_Damage');
        if (DmgModule != None)
        {
            // Register the headshot effect on the headshot bonus list
            DmgModule.HeadshotDamageTakenMultiplier.Bonuses.AddItem(Self);
            Class'SFXGame'.static.ReCalculate(DmgModule.HeadshotDamageTakenMultiplier);
        }
    }
}

defaultproperties
{
}