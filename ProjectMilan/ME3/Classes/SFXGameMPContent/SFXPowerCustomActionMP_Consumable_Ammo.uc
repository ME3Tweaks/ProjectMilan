Class SFXPowerCustomActionMP_Consumable_Ammo extends SFXPowerCustomActionMP_Consumable
    config(Game);

// Variables
var config int NumGrenadesRestored;
var float AverageAmmoMissingThreshold;

// Functions
public function bool CanUsePower(Actor oTarget)
{
    local SFXPawn_Player pPawn;
    local SFXInventoryManager InvManager;
    local bool bNeedsGrenades;
    local SFXWeapon ChkWeapon;
    local array<float> AmmoPercentMissingArray;
    local float AmmoPercentMissing;
    local float TotalAmmoPercentMissing;
    local int idx;
    
    if (m_oPawn.IsLocallyControlled() == FALSE)
    {
        return TRUE;
    }
    pPawn = SFXPawn_Player(m_oPawn);
    if (pPawn == None)
    {
        return FALSE;
    }
    InvManager = SFXInventoryManager(pPawn.InvManager);
    if (InvManager == None)
    {
        return FALSE;
    }
    if (InvManager.bCanPickUpGrenades && InvManager.Grenades < InvManager.GetMaxGrenades())
    {
        bNeedsGrenades = TRUE;
    }
    if (!bNeedsGrenades)
    {
        foreach InvManager.InventoryActors(Class'SFXWeapon', ChkWeapon)
        {
            if (SFXHeavyWeapon(ChkWeapon) != None)
            {
                continue;
            }
            AmmoPercentMissing = 1.0 - float(ChkWeapon.GetCurrentTotalAmmo()) / float(ChkWeapon.GetMaxTotalAmmo());
            AmmoPercentMissingArray.AddItem(AmmoPercentMissing);
        }
        for (idx = 0; idx < AmmoPercentMissingArray.Length; idx++)
        {
            TotalAmmoPercentMissing += AmmoPercentMissingArray[idx];
        }
        AmmoPercentMissing = TotalAmmoPercentMissing / FMax(float(AmmoPercentMissingArray.Length), 1.0);
        if (AmmoPercentMissing < AverageAmmoMissingThreshold)
        {
            return FALSE;
        }
    }
    return Super.CanUsePower(oTarget);
}
public function bool OnImpact(EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Vector HitLocation, Vector HitNormal)
{
    local SFXPawn_Player Player;
    local SFXWeapon oWeapon;
    
    if (oImpacted != None && oImpacted.Role == ENetRole.ROLE_Authority)
    {
        Player = SFXPawn_Player(oImpacted);
        if (Player != None && Player.InvManager != None)
        {
            foreach Player.InvManager.InventoryActors(Class'SFXWeapon', oWeapon)
            {
                if (SFXHeavyWeapon(oWeapon) == None)
                {
                    oWeapon.AddAmmo(oWeapon.GetMaxSpareAmmo());
                }
            }
            if (NumGrenadesRestored > 0)
            {
                m_oPawn.AdjustInventoryResource(3, NumGrenadesRestored, TRUE);
            }
        }
    }
    if (m_oPawn.IsLocallyControlled())
    {
        Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound('MPAmmoConsumable');
    }
    UseConsumable();
    return TRUE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    NumGrenadesRestored = 10
    AverageAmmoMissingThreshold = 0.25
    CapacityPlayerVariable = 'MPCapacity_Ammo'
    CastSound = None
    HenchmanCastSound = None
    PowerName = 'Consumable_Ammo'
    PowerCustomActionID = 69
    DisplayName = $661162
    Description = $661163
    Icon = 91
    TalentDescription = $661163
}