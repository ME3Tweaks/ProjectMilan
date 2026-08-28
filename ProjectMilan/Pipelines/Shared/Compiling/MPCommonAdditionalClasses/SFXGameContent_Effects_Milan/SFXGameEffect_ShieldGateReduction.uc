// 08/27/2026 - Mgamerz
// Game effect that reduces the shield gate of the applied pawn
// Requires changes to SFXGame to work as AIEnergyShieldGatePct is not a scaled float in vanilla LE3
// Added to support Tactical Scan Rank 5A being terrible since headshots are heavily negated by shield gating
Class SFXGameEffect_ShieldGateReduction extends SFXGameEffect;

var BioPawn Pawn;
var SFXShield_Base Shield;

function OnApplied()
{
    Super.OnApplied();
    Pawn = BioPawn(Owner);
    if (Pawn != None)
    {
        Shield = Pawn.GetShields();
    }
    if (Shield != None)
    {
        Shield.AIEnergyShieldGatePct.Bonuses.AddItem(Self);
        Class'SFXGame'.static.ReCalculate(Shield.AIEnergyShieldGatePct);
    }
}
function OnRemoved()
{
    Super.OnRemoved();
    if (Shield != None)
    {
        Shield.AIEnergyShieldGatePct.Bonuses.RemoveItem(Self);
        Class'SFXGame'.static.ReCalculate(Shield.AIEnergyShieldGatePct);
    }
}

defaultproperties
{
}