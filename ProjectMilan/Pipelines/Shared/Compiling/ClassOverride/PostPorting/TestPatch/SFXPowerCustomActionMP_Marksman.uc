// Source: ME3, Patch_SFXPwrCustActnMPMarksman
// Decompiled 11/17/2026 7:38:22 AM against MQuarian_Soldier_MP.pcc
Class SFXPowerCustomActionMP_Marksman extends SFXPowerCustomAction_Marksman
    config(Game);

public function ReleasePower()
{
    local SFXWeapon oWeapon;
    
    Super(SFXPowerCustomAction).ReleasePower();
    oWeapon = SFXWeapon(m_oPawn.Weapon);
    if (oWeapon != None && SFXHeavyWeapon(oWeapon) == None)
    {
        oWeapon.DoReload();
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    RateOfFireIncrease = {BaseValue = 0.25}
    AccuracyIncrease = {BaseValue = 0.349999994}
    Evolve_AccuracyBonus = 0.150000006
    Evolve_RateOfFireBonus = 0.150000006
    Evolve_AccuracyAndRoFBonus = 0.100000001
}