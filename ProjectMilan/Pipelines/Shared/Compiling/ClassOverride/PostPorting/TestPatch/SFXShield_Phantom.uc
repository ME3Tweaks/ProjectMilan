// Source: ME3, Patch_SFXShield_Phantom
// Decompiled 11/17/2026 7:38:45 AM against BioD_Cat002_600KLFight.pcc
Class SFXShield_Phantom extends SFXShield_Biotic
    config(Weapon);

public simulated function ApplyDamage(out float Damage, out Actor.TraceHitInfo HitInfo, out Object.Vector HitLocation, Object.Vector Momentum, Class<SFXDamageType> DamageType, Controller instigatedBy, Actor DamageCauser, out float TotalDamageDone)
{
    if (Instigator != None && HitInfo.HitComponent != None && HitInfo.HitComponent != Instigator.Mesh)
    {
        return;
    }
    Super(SFXShield_Base).ApplyDamage(Damage, HitInfo, HitLocation, Momentum, DamageType, instigatedBy, DamageCauser, TotalDamageDone);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}