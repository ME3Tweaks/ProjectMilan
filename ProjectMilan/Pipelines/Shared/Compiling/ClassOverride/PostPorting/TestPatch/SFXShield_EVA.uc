// Source: ME3, Patch_SFXShield_EVA
// Decompiled 11/17/2026 7:38:44 AM against BioD_ProMar_710Chase.pcc
Class SFXShield_EVA extends SFXShield_Energy
    config(Weapon);

public simulated function PostBeginPlay()
{
    Super(SFXShield_Base).PostBeginPlay();
    bRechargeable = TRUE;
    ShieldRegenDelay.X = 2.0;
    ShieldRegenDelay.Y = 2.0;
    ShieldRegenPct = 50.0;
    ScaleShields();
}
protected simulated function ApplyDamageToShields(out float Damage, Class<SFXDamageType> DamageType, Object.Vector Momentum, Object.Vector HitLocation, Actor.TraceHitInfo HitInfo, Controller instigatedBy, out float TotalDamageDone)
{
    local float ShieldDamage;
    local float DamageResistance;
    local float ShieldPct;
    
    DamageResistance = GetDamageResistance(DamageType);
    ShieldDamage = Damage * DamageResistance;
    ShieldPct = GetCurrentShields() / GetMaxShields();
    ShieldDamage = FMin(GetMaxShields() * 0.200000003, ShieldDamage * ShieldPct);
    SetCurrentShields(FMax(1.0, GetCurrentShields() - ShieldDamage));
    Damage = 0.0;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}