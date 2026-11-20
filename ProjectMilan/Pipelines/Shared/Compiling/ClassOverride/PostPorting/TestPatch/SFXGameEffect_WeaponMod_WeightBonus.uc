// Source: ME3, Patch_SFXGameEffectWpnModWeightBns
// Decompiled 11/17/2026 7:37:51 AM against BioD_Gth002_200ReaperRing.pcc
Class SFXGameEffect_WeaponMod_WeightBonus extends SFXGameEffect_WeaponMod;

public function OnRemoved()
{
    local SFXPawn_Player PlayerPawn;
    
    Super(SFXGameEffect).OnRemoved();
    if (MyWeapon == None)
    {
        return;
    }
    PlayerPawn = SFXPawn_Player(MyWeapon.Owner);
    if (PlayerPawn == None)
    {
        return;
    }
    MyWeapon.EncumbranceWeight.Bonuses.RemoveItem(Self);
    MyWeapon.ScaleWeapon();
    PlayerPawn.UpdateWeaponEncumbrance();
}
public function OnApplied()
{
    local SFXPawn_Player PlayerPawn;
    
    Super.OnApplied();
    if (MyWeapon == None)
    {
        return;
    }
    PlayerPawn = SFXPawn_Player(MyWeapon.Owner);
    if (PlayerPawn == None)
    {
        return;
    }
    MyWeapon.EncumbranceWeight.Bonuses.AddItem(Self);
    MyWeapon.ScaleWeapon();
    PlayerPawn.UpdateWeaponEncumbrance();
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    ModStat = EWeaponStatBars.EWeaponStatBarWeight
}