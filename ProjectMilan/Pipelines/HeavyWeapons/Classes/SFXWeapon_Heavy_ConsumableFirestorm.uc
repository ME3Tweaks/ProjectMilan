// NEW to MILAN - 11/19/2026 - Mgamerz
// Consumable Flamethrower
Class SFXWeapon_Heavy_ConsumableFirestorm extends SFXWeapon_Heavy_Flamethrower_Player
    placeable
    config(Weapon);

var transient SFXPowerCustomActionMP_Consumable_Rocket Power;
var transient int FireSerial;

private final simulated function SFXPowerCustomActionMP_Consumable_Rocket GetAmmoPower()
{
    local SFXPawn_Player Player;

    if (Power == None && (Role == ENetRole.ROLE_Authority || (Instigator != None && Instigator.IsLocallyControlled())))
    {
        Player = SFXPawn_Player(Instigator);
        if (Player != None)
        {
            Power = SFXPowerCustomActionMP_Consumable_Rocket(Player.FindPower('SFXPowerCustomActionMP_Consumable_Rocket'));
        }
    }
    return Power;
}

public simulated function InitializeWeapon()
{
    GetAmmoPower();
    Super(SFXWeapon).InitializeWeapon();
}

public simulated function FireAmmunition()
{
    if (!HasAmmo(CurrentFireMode))
    {
        return;
    }
    if (Role == ENetRole.ROLE_Authority)
    {
        if (GetAmmoPower() == None || !Power.AcceptScaledShot(Self))
        {
            return;
        }
    }
    else if (GetAmmoPower() != None)
    {
        Power.PredictScaledShot(Self);
    }

    Super.FireAmmunition();
    if (Role == ENetRole.ROLE_Authority && Instigator != None && !Instigator.IsLocallyControlled())
    {
        ClientConfirmScaledShots(Power.GetAcceptedScaledShots(Self), 0);
    }
}

public simulated function ConsumeAmmo(byte FireModeNum);

public simulated function bool HasAmmo(byte FireModeNum, optional int Amount)
{
    return Max(1, Amount) <= GetAmmoCountInMagazine();
}

public simulated function int GetAmmoCountInMagazine()
{
    if (GetAmmoPower() != None)
    {
        return Power.GetScaledRounds(Self);
    }
    return Role == ENetRole.ROLE_Authority || (Instigator != None && Instigator.IsLocallyControlled()) ? 0 : GetMagazineSize();
}

public simulated function PutDownWeapon()
{
    Super(Weapon).PutDownWeapon();
}

public function DropGun();

public simulated function StartFire(byte FireModeNum)
{
    if (CurrentFireMode == FireModeNum || Instigator == None || Instigator.bNoWeaponFiring)
    {
        return;
    }
    if (Role < ENetRole.ROLE_Authority)
    {
        if (!HasAmmo(FireModeNum))
        {
            ServerPlayNoAmmoEffects();
            BeginFire(FireModeNum);
            return;
        }
        FireSerial++;
        Power.OnHeavyAmmoGranted = SendHeavyAmmoAllowance;
        SendHeavyAmmoAllowance();
    }
    Super.StartFire(FireModeNum);
}

private final simulated function SendHeavyAmmoAllowance()
{
    if (Power != None && !bDeleteMe)
    {
        ServerUpdateHeavyAmmoAllowance(Power.GetScaledChargeAllowance(), FireSerial);
    }
}

public final reliable server function ServerUpdateHeavyAmmoAllowance(int Allowance, int NewFireSerial)
{
    if (GetAmmoPower() != None)
    {
        Power.SetRemoteScaledChargeAllowance(Self, Allowance);
        FireSerial = NewFireSerial;
    }
}

public reliable server function ServerStopFire(byte FireModeNum)
{
    Super.ServerStopFire(FireModeNum);
    if (GetAmmoPower() != None)
    {
        ClientConfirmScaledShots(Power.GetAcceptedScaledShots(Self), FireSerial);
    }
}

public final reliable client function ClientConfirmScaledShots(int AcceptedShots, int StoppedFireSerial)
{
    if (Role == ENetRole.ROLE_Authority || GetAmmoPower() == None)
    {
        return;
    }
    Power.ConfirmScaledShots(Self, AcceptedShots, StoppedFireSerial != 0 && StoppedFireSerial == FireSerial);
    if (StoppedFireSerial == 0 && Instigator != None && Instigator.Weapon != Self)
    {
        ServerCurrentWeapon(Instigator.Weapon);
    }
}

public reliable server function ServerCurrentWeapon(Weapon ClientCurrentWeapon)
{
    local SFXPlayerInventoryManager PlayerInv;

    if (ClientCurrentWeapon != None && Instigator != None && Instigator.Weapon != ClientCurrentWeapon)
    {
        PlayerInv = SFXPlayerInventoryManager(InvManager);
        if (PlayerInv != None)
        {
            PlayerInv.SetWeaponIfAvailable(SFXWeapon(ClientCurrentWeapon));
        }
    }
}

public unreliable server function ServerPlayNoAmmoEffects()
{
    IncrementFizzleCount();
    PlayNoAmmoEffects();
}

defaultproperties
{
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh
    End Template
    ScaledHeavyAmmoFamily = 'Firestorm'
    HeavyAmmoRoundsPerCharge = 100
    bWeaponCanBeReloaded = FALSE
    bQuickSwitchEligible = FALSE
    Mesh = WeaponMesh
    DroppedPickupMesh = WeaponMesh
    PickupFactoryMesh = WeaponMesh
    Components = (WeaponMesh)
}
