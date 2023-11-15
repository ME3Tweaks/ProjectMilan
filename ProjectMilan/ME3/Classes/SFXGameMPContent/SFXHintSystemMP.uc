Class SFXHintSystemMP extends BioHintSystem
    config(Game);

// Variables
var bool bDying;
var bool bCanUseRevive;
var bool bCanUseAmmoKit;
var bool bObjectiveActive;
var bool bObjectiveNear;
var bool bReviveObjectiveActive;
var bool bReviveObjectiveActiveNear;
var bool bDoingCustomAction;
var bool bBeingRevived;
var bool bAnyWeaponHasAmmo;

// Functions
public function CacheCurrentState()
{
    local BioWorldInfo oWorldInfo;
    local BioPlayerController oController;
    local BioPawn oPawn;
    local SFXGRIMP GRI;
    local SFXPowerCustomActionBase oPower;
    local SFXSimpleUseModule UseModule;
    local Class<SFXDamageType> DamageType;
    local SFXInventoryManager oInvManager;
    local SFXWeapon Weapon;
    local array<Actor> Markers;
    local Actor Marker;
    
    oWorldInfo = BioWorldInfo(Class'Engine'.static.GetCurrentWorldInfo());
    oController = oWorldInfo.GetLocalPlayerController();
    GRI = SFXGRIMP(oWorldInfo.GRI);
    bReviveObjectiveActive = FALSE;
    bReviveObjectiveActiveNear = FALSE;
    bObjectiveActive = FALSE;
    bDying = FALSE;
    bObjectiveNear = FALSE;
    bCanUseAmmoKit = FALSE;
    bCanUseRevive = FALSE;
    bDoingCustomAction = FALSE;
    bBeingRevived = FALSE;
    bAnyWeaponHasAmmo = FALSE;
    if (oController != None)
    {
        oPawn = BioPawn(oController.Pawn);
    }
    if (oPawn != None)
    {
        if (oController != None && oController.IsInState('Dying', ))
        {
            DamageType = Class<SFXDamageType>(oPawn.KilledByDamageType);
            if (DamageType == None || DamageType.default.bMPKillDamage == FALSE)
            {
                bDying = TRUE;
            }
        }
        if (oPawn.CurrentCustomAction != 0)
        {
            bDoingCustomAction = TRUE;
        }
        bBeingRevived = SFXPawn_PlayerParty(oPawn).bBeingRevived;
        if (m_bOutOfAmmo)
        {
            oInvManager = SFXInventoryManager(oPawn.InvManager);
            if (oInvManager != None)
            {
                foreach oInvManager.InventoryActors(Class'SFXWeapon', Weapon)
                {
                    if (Weapon != None && Weapon.HasAnyAmmo())
                    {
                        bAnyWeaponHasAmmo = TRUE;
                        break;
                    }
                }
            }
        }
        if (oPawn.PowerManager != None)
        {
            if (m_bOutOfAmmo && !bDying)
            {
                oPower = oPawn.PowerManager.GetPower('Consumable_Ammo');
                if (oPower != None)
                {
                    bCanUseAmmoKit = oPower.CanUsePower(None);
                }
            }
            if (bDying)
            {
                oPower = oPawn.PowerManager.GetPower('Consumable_Revive');
                if (oPower != None)
                {
                    bCanUseRevive = oPower.CanUsePower(None);
                }
            }
        }
        if (GRI != None && !bDying)
        {
            Markers = GRI.MarkerModuleManager.GetActiveMarkerActors();
            foreach Markers(Marker, )
            {
                UseModule = Marker.GetModule(Class'SFXSimpleUseModule');
                if (UseModule != None && UseModule.m_bTargetable)
                {
                    if (((Marker != oPawn && Marker.IsA('SFXPawn_PlayerMP')) && Marker.IsInState('Downed', )) && !SFXPawn_PlayerMP(Marker).bIsDead)
                    {
                        bReviveObjectiveActive = TRUE;
                        if (VSize2D(Marker.location - oPawn.location) < float(300))
                        {
                            bReviveObjectiveActiveNear = TRUE;
                        }
                    }
                    if ((Marker.IsA('SFXOperationObjective') && !Marker.IsA('SFXObjective_SupplyDrop')) && !Marker.IsA('SFXObjective_ExtractionPoint'))
                    {
                        bObjectiveActive = TRUE;
                        if (VSizeSq2D(Marker.location - oPawn.location) < float(40000))
                        {
                            bObjectiveNear = TRUE;
                        }
                    }
                }
            }
        }
    }
    Super.CacheCurrentState();
}
public function bool UseReviveHint()
{
    if ((bDying && bCanUseRevive) && !bBeingRevived)
    {
        return TRUE;
    }
    return FALSE;
}
public function bool UseAmmoHint()
{
    if ((m_bOutOfAmmo && bCanUseAmmoKit) && !m_bUsingHeavyWeapon)
    {
        return TRUE;
    }
    return FALSE;
}
public function bool UseObjectiveHint()
{
    return bObjectiveNear && !bDoingCustomAction;
}
public function bool ReviveOtherHint()
{
    return bReviveObjectiveActiveNear && !bDoingCustomAction;
}
public function bool SwapWeapons()
{
    if ((m_bOutOfAmmo && !bCanUseAmmoKit) && bAnyWeaponHasAmmo)
    {
        return TRUE;
    }
    return FALSE;
}
public function bool ObjectiveHint()
{
    local HintTrackingData oActivated;
    local HintTrackingData oStarted;
    local float SinceActivated;
    
    if (bObjectiveActive)
    {
        oActivated = GetTrackingData('ObjectiveActivated');
        oStarted = GetTrackingData('ObjectiveStarted');
        SinceActivated = TimeSince(oActivated.LastTime);
        if ((oStarted.Num == 0 || TimeSince(oStarted.LastTime) > SinceActivated) && SinceActivated > float(60))
        {
            return TRUE;
        }
    }
    return FALSE;
}
public function bool DyingHint()
{
    local HintTrackingData oDying;
    local HintTrackingData oMashed;
    
    if ((bDying && !bCanUseRevive) && !bBeingRevived)
    {
        oDying = GetTrackingData('Dying');
        oMashed = GetTrackingData('ProlongLife');
        if ((oMashed.Num == 0 || TimeSince(oMashed.LastTime) > float(60)) && TimeSince(oDying.LastTime) >= 3.0)
        {
            return TRUE;
        }
    }
    return FALSE;
}
public function bool Objective30sHint()
{
    local HintTrackingData oWarning;
    local HintTrackingData oHintData;
    
    oWarning = GetTrackingData('Objective30Seconds');
    oHintData = GetTrackingData('Hint', 'Objective30sHint');
    if ((oWarning.Num > 0 && TimeSince(oWarning.LastTime) < 2.0) && TimeSince(oHintData.LastTime) > float(30))
    {
        return TRUE;
    }
    return FALSE;
}
public function bool ReviveSystemHint()
{
    local HintTrackingData oRevived;
    
    oRevived = GetTrackingData('StartRevive');
    if (bReviveObjectiveActive && oRevived.Num == 0)
    {
        return TRUE;
    }
    return FALSE;
}
public function AddNotification_SupplyDrop(CardInfoData CardData)
{
    local SFXNotificationData oNotificationData;
    local CardDisplayData CardDisplay;
    
    CardDisplay = Class'SFXGUI_MPReinforcementsReveal'.static.GetCardDisplayData(CardData);
    oNotificationData = GetNotificationData('SupplyDrop');
    AddNotification_Custom(oNotificationData.DisplayTime, string(oNotificationData.srTitle), CardDisplay.DisplayName, CardDisplay.CardTypeText, CardDisplay.TextureReference, 'None', oNotificationData.nmType, oNotificationData.nmSound, oNotificationData.Priority, oNotificationData.nFlourishID);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}