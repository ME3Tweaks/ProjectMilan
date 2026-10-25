Class SFXMilanHeavyWeaponLoadout extends Object;

const BonusCategory = 'Milan_NoHeavyWeapon';

public static final function Apply(SFXPawn_PlayerMP PlayerPawn, int Id, optional bool bFillNewWeapons)
{
    local class<SFXHeavyWeapon> SelectedClass;
    local SFXHeavyWeapon Heavy;
    local SFXHeavyWeapon Kept;
    local SFXWeapon RegularWeapon;
    local SFXWeapon Weapon;
    local bool bNone;

    if (PlayerPawn == None || PlayerPawn.InvManager == None)
    {
        return;
    }
    SelectedClass = Class'SFXMilanHeavyWeaponCatalog'.static.ResolveClass(Id);
    bNone = SelectedClass == None;
    if (PlayerPawn.Role == ENetRole.ROLE_Authority)
    {
        foreach PlayerPawn.InvManager.InventoryActors(Class'SFXWeapon', Weapon)
        {
            if (SFXHeavyWeapon(Weapon) == None)
            {
                RegularWeapon = Weapon;
                break;
            }
        }
        foreach PlayerPawn.InvManager.InventoryActors(Class'SFXHeavyWeapon', Heavy)
        {
            if (SelectedClass != None && Heavy.Class == SelectedClass && Kept == None)
            {
                Kept = Heavy;
            }
            else
            {
                if (PlayerPawn.Weapon == Heavy && RegularWeapon != None)
                {
                    PlayerPawn.SetWeaponImmediately(RegularWeapon);
                }
                PlayerPawn.InvManager.RemoveFromInventory(Heavy);
                Heavy.Destroy();
            }
        }
        if (SelectedClass != None && Kept == None)
        {
            PlayerPawn.CreateWeapon(SelectedClass, FALSE);
        }
    }
    if (PlayerPawn.Role == ENetRole.ROLE_Authority || PlayerPawn.IsLocallyControlled())
    {
        ApplyNoneBonuses(PlayerPawn, bNone && !PlayerPawn.WorldInfo.bIsLobbyLevel, bFillNewWeapons);
    }
}

private static final function ApplyNoneBonuses(SFXPawn_PlayerMP PlayerPawn, bool bNone, bool bFillNewWeapons)
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_PassiveMaxAmmoBonus AmmoEffect;
    local SFXWeapon Weapon;

    Manager = PlayerPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager == None)
    {
        return;
    }
    if (bNone)
    {
        if (Manager.GetFirstEffectOfTypeAndCategory(Class'SFXGameEffect_MovementSpeedBonus', BonusCategory) == None)
        {
            Manager.CreateAndApplyEffect(Class'SFXGameEffect_MovementSpeedBonus', BonusCategory, 0.0, EDurationType.DurationType_Permanent, 0.05, PlayerPawn.Controller);
        }
        AmmoEffect = SFXGameEffect_PassiveMaxAmmoBonus(Manager.GetFirstEffectOfTypeAndCategory(Class'SFXGameEffect_PassiveMaxAmmoBonus', BonusCategory));
        if (AmmoEffect == None)
        {
            AmmoEffect = SFXGameEffect_PassiveMaxAmmoBonus(Manager.CreateAndApplyEffect(Class'SFXGameEffect_PassiveMaxAmmoBonus', BonusCategory, 0.0, EDurationType.DurationType_Permanent, 0.10, PlayerPawn.Controller));
        }
        foreach PlayerPawn.InvManager.InventoryActors(Class'SFXWeapon', Weapon)
        {
            if (SFXHeavyWeapon(Weapon) == None && AmmoEffect != None)
            {
                // Recreated weapons need the existing pawn bonus too.
                AmmoEffect.ApplyBonus(Weapon);
                if (bFillNewWeapons && PlayerPawn.Role == ENetRole.ROLE_Authority)
                {
                    Weapon.AddAmmo(Weapon.GetMaxSpareAmmo());
                }
            }
        }
    }
    else
    {
        Manager.RemoveEffectsByTypeAndCategory(Class'SFXGameEffect_MovementSpeedBonus', BonusCategory);
        Manager.RemoveEffectsByTypeAndCategory(Class'SFXGameEffect_PassiveMaxAmmoBonus', BonusCategory);
        foreach PlayerPawn.InvManager.InventoryActors(Class'SFXWeapon', Weapon)
        {
            if (SFXHeavyWeapon(Weapon) == None)
            {
                Weapon.AddAmmo(0);
            }
        }
    }
}
