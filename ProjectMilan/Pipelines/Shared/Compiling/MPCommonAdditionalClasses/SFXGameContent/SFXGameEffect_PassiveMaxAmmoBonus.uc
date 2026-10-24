// Gear version is being promoted to addin so it can be used more widely without
// requiring cloning 
Class SFXGameEffect_PassiveMaxAmmoBonus extends SFXGameEffect_PassiveWeaponBonus;

public function ApplyBonus(SFXWeapon Weapon, optional bool bRemove)
{
    if (Weapon == None)
    {
        return;
    }
    if (!bRemove && Weapon.MaxSpareAmmo.Bonuses.Find(Self) == -1)
    {
        Weapon.MaxSpareAmmo.Bonuses.AddItem(Self);
        Class'SFXGame'.static.ReCalculate(Weapon.MaxSpareAmmo);
    }
    else if (bRemove && Weapon.MaxSpareAmmo.Bonuses.Find(Self) != -1)
    {
        Weapon.MaxSpareAmmo.Bonuses.RemoveItem(Self);
        Class'SFXGame'.static.ReCalculate(Weapon.MaxSpareAmmo);
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}
