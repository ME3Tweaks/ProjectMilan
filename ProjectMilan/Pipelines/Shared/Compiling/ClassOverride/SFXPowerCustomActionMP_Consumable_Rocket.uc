// Source: ME3, Patch_PowCustActionMPConsumRocket
// Decompiled 08/16/2025 3:20:32 PM
// MILAN CHANGE
// Change code for registering custom consumable rockets
Class SFXPowerCustomActionMP_Consumable_Rocket extends SFXPowerCustomActionMP_Consumable
    config(Game);

var int ServerConfirmedRocketCount;

public function bool CanUsePower(Actor oTarget)
{
    local SFXAI_Core AutobotAI;

    if (GetWeapon() == None)
    {
        return FALSE;
    }
    if (m_oPawn.Controller.IsLocalPlayerController() && !HasCharges() && m_oPawn.Weapon != GetWeapon())
    {
        return FALSE;
    }
    AutobotAI = SFXAI_Core(m_oPawn.Controller);
    if (AutobotAI != None && AutobotAI.bIsAutoBot == TRUE)
    {
        return FALSE;
    }
    return Super(SFXPowerCustomAction).CanUsePower(oTarget);
}
public function bool OnImpact(EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Vector HitLocation, Vector HitNormal)
{
    local SFXHeavyWeapon Launcher;
    local BioPlayerController PC;
    local SFXPawn_Player PlayerPawn;

    PlayerPawn = SFXPawn_Player(m_oPawn);
    if (PlayerPawn != None && PlayerPawn.Role == ENetRole.ROLE_Authority)
    {
        Launcher = GetWeapon();
        if (Launcher == None)
        {
            return FALSE;
        }
        PC = BioPlayerController(PlayerPawn.Controller);
        SetWeaponAmmoFromPower();
        if (PlayerPawn.Weapon != Launcher)
        {
            PC.SwitchWeapon(Launcher);
        }
        else
        {
            PC.SwitchWeapon(SFXWeapon(PlayerPawn.WeaponOnDeck));
        }
    }
    return TRUE;
}
public function OnPawnLoadedWeapons()
{
    // Kit loading is where heavy weapon creation happens now
}
public function RocketConfirmationFromServer()
{
    ServerConfirmedRocketCount++;
    if (ServerConfirmedRocketCount > UsedCount)
    {
        UseConsumable();
    }
}
private final function SetWeaponAmmoFromPower()
{
    local SFXHeavyWeapon Launcher;

    Launcher = GetWeapon();
    if (Launcher == None)
    {
        return;
    }
    Launcher.AmmoUsedCount = Launcher.GetMagazineSize();
    Launcher.AddHeavyAmmo(GetChargeCount());
}
public simulated function AddAvailableCharges(int Quantity)
{
    Super.AddAvailableCharges(Quantity);
    if (m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        SetWeaponAmmoFromPower();
    }
}
private final function SFXHeavyWeapon GetWeapon()
{
    local SFXHeavyWeapon oWeapon;

    foreach m_oPawn.InvManager.InventoryActors(Class'SFXHeavyWeapon', oWeapon)
    {
        return oWeapon;
    }
    return None;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    CapacityPlayerVariable = 'MPCapacity_Rocket'
    PowerName = 'Consumable_Rocket'
    PowerCustomActionID = 66
    DisplayName = $661166
    Description = $661167
    Icon = 94
    TalentDescription = $661167
    bClientPredictCustomAction = TRUE
}
