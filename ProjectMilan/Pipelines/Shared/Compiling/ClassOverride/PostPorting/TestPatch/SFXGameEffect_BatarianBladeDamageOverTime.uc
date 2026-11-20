// Source: ME3, Patch_SFXGmEffctBataBladeDOTime
// Decompiled 11/17/2026 7:37:47 AM against Batarian_Soldier_MP.pcc
Class SFXGameEffect_BatarianBladeDamageOverTime extends SFXGameEffect_DamageOverTime;

var Class<SFXDamageType> ExplosionDamageType;
var float ExplosionDelay;
var SFXPowerCustomActionMP_BatarianAttack Power;
var SFXPawn Caster;
var RvrClientEffectInterface CE_ExplosionTemplate;
var WwiseEvent ExplosionSound;
var bool ShouldExplode;

public function DoAreaExplosionForActor(Actor oActor, int ImpactCount)
{
    if (Owner != None && Power != None)
    {
        Power.DoAreaExplosionForActor(oActor, Owner.location, ImpactCount, Power.ExplosionDamage.CurrentValue, ExplosionDamageType, Power.ExplosionForce.CurrentValue, Power.ExplosionParameters, 0, None);
    }
}
public function OnRemoved()
{
    Super.OnRemoved();
    Caster.ClearTimer('SpikeExplode', Self);
}
public function OnApplied()
{
    Super.OnApplied();
    if (ShouldExplode)
    {
        Caster.SetTimer(ExplosionDelay, FALSE, 'SpikeExplode', Self);
    }
}
public function SpikeExplode()
{
    local Object.Vector Params;
    
    Power.AreaExplosion(Owner.location, Power.ExplosionRadius.CurrentValue, Power.ExplosionDamage.CurrentValue, ExplosionDamageType, Power.ExplosionForce.CurrentValue, Power.ExplosionParameters, 0);
    Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayAtLocation(CE_ExplosionTemplate, Owner.location, vect(0.0, 0.0, 1.0), Params);
    Owner.PlaySound(ExplosionSound, TRUE);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    ExplosionDamageType = Class'SFXDamageType_BatarianBladeExplosion'
    CE_ExplosionTemplate = RvrClientEffect'BioVFX_C_Grenades.Generic.VCFX.FragGrenade_Imp_VCFX'
    ExplosionSound = WwiseEvent'Wwise_Power_Soldier_FragGren.Play_power_soldier_NP_fraggren_impact'
    DamageType = Class'SFXDamageType_BatarianBlade'
}