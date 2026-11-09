// MILAN CHANGE - Mgamerz - 2026-10-30
// Config-based rules for allowing forced ragdoll overrides
Class MilanRagdollRules extends Object
    config(Game);

// Damage type class names
var config array<Name> ForceRagdollDeathDamageTypes;

public static function bool ShouldForceDeathRagdoll(Class<DamageType> DamageType)
{
    return DamageType != None && default.ForceRagdollDeathDamageTypes.Find(DamageType.Name) != -1;
}
