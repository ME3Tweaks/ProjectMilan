// Source: ME3, Patch_SFXGameEffectPenDamageBonus
// Decompiled 11/17/2026 7:37:49 AM against BIOP_MP_COMMON.pcc
Class SFXGameEffect_PenetrationDamageBonus extends SFXGameEffect_WeaponMod;

public function OnRemoved()
{
    Super(SFXGameEffect).OnRemoved();
    if (MyWeapon != None && MyWeapon.DistancePenetrated == float(0))
    {
        MyWeapon.PenetrationDamageBonus.Bonuses.RemoveItem(Self);
        MyWeapon.ScaleWeapon();
    }
}
public function ComputeCustomEffectValue(out float Value)
{
    if (Value < 1.0)
    {
        Value = FMax(Value, 1.0 + EffectValue);
    }
    else
    {
        Value = 1.0 + EffectValue;
    }
}
public function OnApplied()
{
    Super.OnApplied();
    if (MyWeapon != None && MyWeapon.DistancePenetrated == float(0))
    {
        MyWeapon.PenetrationDamageBonus.Bonuses.AddItem(Self);
        MyWeapon.ScaleWeapon();
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    BonusFormula = EBonusFormula.BonusFormula_Custom
}