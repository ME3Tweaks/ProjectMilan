// Source: ME3, Patch_PowCustActionMPConsumRocket
// Decompiled 08/16/2025 3:20:32 PM
// MILAN CHANGE
// Change code for registering custom consumable rockets
Class SFXPowerCustomActionMP_Consumable_Rocket extends SFXPowerCustomActionMP_Consumable
    config(Game);

var int ServerConfirmedRocketCount;

// MILAN CHANGE - Mgamerz - 11/19/2026
// Heavy weapon ammo scaling

struct ScaledHeavyAmmoState
{
    var name WeaponFamily;
    var int PaidRoundsLeft;
    var int PredictedShots;
    var int AcceptedShots;
};

var transient array<ScaledHeavyAmmoState> ScaledAmmo;
var transient int ScaledChargesUsed;
var transient int RemoteChargeAllowance;

public final delegate function OnHeavyAmmoGranted();

private final simulated function int GetScaledAmmoSlot(SFXHeavyWeapon Launcher, optional bool bCreate)
{
    local int Slot;

    if (Launcher == None || !Launcher.UsesScaledHeavyAmmo())
    {
        return -1;
    }
    Slot = ScaledAmmo.Find('WeaponFamily', Launcher.ScaledHeavyAmmoFamily);
    if (Slot < 0 && bCreate)
    {
        Slot = ScaledAmmo.Length;
        ScaledAmmo.Length = Slot + 1;
        ScaledAmmo[Slot].WeaponFamily = Launcher.ScaledHeavyAmmoFamily;
    }
    return Slot;
}

public final simulated function int GetScaledChargeAllowance()
{
    return Max(0, GetChargeCount()) + ScaledChargesUsed;
}

public final function SetRemoteScaledChargeAllowance(SFXHeavyWeapon Launcher, int Allowance)
{
    if (m_oPawn.Role == ENetRole.ROLE_Authority && !m_oPawn.IsLocallyControlled() && GetWeapon() == Launcher)
    {
        RemoteChargeAllowance = Clamp(Allowance, 0, 999);
    }
}

// Get amount of rounds a single charge gets you
public final simulated function int GetScaledRounds(SFXHeavyWeapon Launcher)
{
    local int Slot;
    local int Charges;
    local int PendingShots;
    local int PaidRoundsLeft;

    if (Launcher == None || !Launcher.UsesScaledHeavyAmmo())
    {
        return 0;
    }
    if (m_oPawn.IsLocallyControlled())
    {
        Charges = Clamp(GetChargeCount(), 0, 999);
    }
    else
    {
        Charges = Max(0, RemoteChargeAllowance - ScaledChargesUsed);
    }
    Slot = GetScaledAmmoSlot(Launcher);
    if (Slot >= 0)
    {
        PaidRoundsLeft = ScaledAmmo[Slot].PaidRoundsLeft;
        PendingShots = Max(0, ScaledAmmo[Slot].PredictedShots - ScaledAmmo[Slot].AcceptedShots);
    }
    return Max(0, Charges * Launcher.GetHeavyAmmoRoundsPerCharge() + PaidRoundsLeft - PendingShots);
}

// Server/client verification of charge spending ------
public final simulated function PredictScaledShot(SFXHeavyWeapon Launcher)
{
    local int Slot;

    Slot = GetScaledAmmoSlot(Launcher, TRUE);
    if (Slot >= 0)
    {
        ScaledAmmo[Slot].PredictedShots = Max(ScaledAmmo[Slot].PredictedShots, ScaledAmmo[Slot].AcceptedShots) + 1;
    }
}

public final simulated function int GetAcceptedScaledShots(SFXHeavyWeapon Launcher)
{
    local int Slot;

    Slot = GetScaledAmmoSlot(Launcher);
    return Slot >= 0 ? ScaledAmmo[Slot].AcceptedShots : 0;
}

private final simulated function bool SpendScaledRound(int Slot, int RoundsPerCharge, bool bLocal)
{
    if (ScaledAmmo[Slot].PaidRoundsLeft == 0)
    {
        if (bLocal)
        {
            if (!HasCharges())
            {
                return FALSE;
            }
            UseConsumable();
        }
        else if (ScaledChargesUsed >= RemoteChargeAllowance)
        {
            return FALSE;
        }
        ScaledChargesUsed++;
        ScaledAmmo[Slot].PaidRoundsLeft = RoundsPerCharge;
    }
    ScaledAmmo[Slot].PaidRoundsLeft--;
    ScaledAmmo[Slot].AcceptedShots++;
    return TRUE;
}

public final simulated function bool AcceptScaledShot(SFXHeavyWeapon Launcher)
{
    local int Slot;

    Slot = GetScaledAmmoSlot(Launcher, TRUE);
    return Slot >= 0 && SpendScaledRound(Slot, Launcher.GetHeavyAmmoRoundsPerCharge(), m_oPawn.IsLocallyControlled());
}

public final simulated function ConfirmScaledShots(SFXHeavyWeapon Launcher, int AcceptedShots, bool bStopped)
{
    local int Slot;

    Slot = GetScaledAmmoSlot(Launcher, TRUE);
    if (Slot < 0)
    {
        return;
    }
    while (ScaledAmmo[Slot].AcceptedShots < AcceptedShots)
    {
        if (!SpendScaledRound(Slot, Launcher.GetHeavyAmmoRoundsPerCharge(), TRUE))
        {
            break;
        }
    }
    if (bStopped)
    {
        ScaledAmmo[Slot].PredictedShots = ScaledAmmo[Slot].AcceptedShots;
    }
}
// END spend verification -----
// END MILAN CHANGE

// MILAN CHANGE
// Allow drawing weapon if you have any ammo in weapon, since no charges doesn't mean you have no remaining ammo to consume (if scaled)
public function bool CanUsePower(Actor oTarget)
{
    local SFXAI_Core AutobotAI;
    local SFXHeavyWeapon Launcher;

    Launcher = GetWeapon();
    if (Launcher == None)
    {
        return FALSE;
    }
    if (m_oPawn.Controller.IsLocalPlayerController() && m_oPawn.Weapon != Launcher)
    {
        if (Launcher.UsesScaledHeavyAmmo() ? GetScaledRounds(Launcher) == 0 : !HasCharges())
        {
            return FALSE;
        }
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
        SetWeaponAmmoFromPower(Launcher);
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
    if (ServerConfirmedRocketCount > UsedCount - ScaledChargesUsed)
    {
        UseConsumable();
    }
}
private final function SetWeaponAmmoFromPower(SFXHeavyWeapon Launcher)
{
    if (Launcher == None || Launcher.UsesScaledHeavyAmmo())
    {
        return;
    }
    Launcher.AmmoUsedCount = Launcher.GetMagazineSize();
    Launcher.AddHeavyAmmo(GetChargeCount());
}

// MILAN CHANGE
// Scale up weapon ammo based on charges
public simulated function AddAvailableCharges(int Quantity)
{
    local SFXHeavyWeapon Launcher;

    Super.AddAvailableCharges(Quantity);
    Launcher = GetWeapon();
    if (m_oPawn.IsLocallyControlled() && Launcher != None && Launcher.UsesScaledHeavyAmmo())
    {
        OnHeavyAmmoGranted();
    }
    if (m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        SetWeaponAmmoFromPower(Launcher);
    }
}
private final simulated function SFXHeavyWeapon GetWeapon()
{
    local SFXHeavyWeapon oWeapon;

    if (m_oPawn == None || m_oPawn.InvManager == None)
    {
        return None;
    }
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
