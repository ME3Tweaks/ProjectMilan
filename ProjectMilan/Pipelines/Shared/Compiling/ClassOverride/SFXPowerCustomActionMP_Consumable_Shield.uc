// Decompilation source: ME3 Patch_PowerCustActMPConsumShield
// MILAN CHANGE - 2026-10-28
// By Mgamerz
// Check if the player is downed or dead before applying a delayed Ops pack so it doesn't consume it 
// after the host has downed you if you use it during the lag between usage and server responding 
// telling you to activate it
Class SFXPowerCustomActionMP_Consumable_Shield extends SFXPowerCustomActionMP_Consumable
    config(Game);

var Object.Guid GUID_ShieldCrustTemplate;
var RvrClientEffectInterface CE_ShieldCrustTemplate;
var config float ShieldDuration;
var config float ShieldStrength;
var config float DamageImmunityLength;

// MILAN CHANGE - 2026-10-28
// Track if we can't actually use the action
var transient bool bOpsEligibilityBlocked;

private final function bool ShouldBlockOpsPack()
{
    if (m_oPawn == None || m_oPawn.Controller == None)
    {
        return TRUE;
    }
    return m_oPawn.bIsDowned || m_oPawn.bIsDead || m_oPawn.IsInState('Downed') || m_oPawn.IsInState('Dying');
}
// private final function LogOpsPack(Name Phase, string Result)
// {
//     local bool bLocalOwner;
//     local int Inventory;
//     local int AvailableCharges;
//     local SFXEngine Engine;
//     local Name ControllerState;
//     local string PlayerName;
//     local int PlayerID;

//     if (m_oPawn == None)
//     {
//         LogInternal("[OpsPackGuard] Phase=" $ Phase @ "Result=" $ Result @ "Pawn=None" @ "UsedCount=" $ UsedCount);
//         return;
//     }
//     PlayerID = -1;
//     if (m_oPawn.PlayerReplicationInfo != None)
//     {
//         PlayerName = m_oPawn.PlayerReplicationInfo.PlayerName;
//         PlayerID = m_oPawn.PlayerReplicationInfo.PlayerID;
//     }
//     Inventory = -1;
//     AvailableCharges = -1;
//     if (m_oPawn.Controller != None)
//     {
//         ControllerState = m_oPawn.Controller.GetStateName();
//         bLocalOwner = m_oPawn.Controller.IsLocalPlayerController();
//     }
//     if (bLocalOwner)
//     {
//         Engine = Class'SFXEngine'.static.GetSFXEngine();
//         if (Engine != None)
//         {
//             Inventory = Engine.GetPlayerVariable(Name(PathName(@Class)));
//             AvailableCharges = GetChargeCount();
//         }
//     }
//     LogInternal("[OpsPackGuard] Phase=" $ Phase @ "Result=" $ Result
//         @ "Time=" $ m_oPawn.WorldInfo.TimeSeconds @ "NetMode=" $ m_oPawn.WorldInfo.NetMode
//         @ "Pawn=" $ m_oPawn @ "PlayerID=" $ PlayerID @ "PlayerName=" $ PlayerName
//         @ "Role=" $ m_oPawn.Role @ "RemoteRole=" $ m_oPawn.RemoteRole @ "LocalOwner=" $ bLocalOwner
//         @ "PawnState=" $ m_oPawn.GetStateName() @ "ControllerState=" $ ControllerState
//         @ "Downed=" $ m_oPawn.bIsDowned @ "Dead=" $ m_oPawn.bIsDead @ "Health=" $ m_oPawn.GetCurrentHealth()
//         @ "Action=" $ m_oPawn.CurrentCustomAction @ "Power=" $ m_oPawn.CurrentPowerCustomAction
//         @ "UsedCount=" $ UsedCount @ "LocalInventory=" $ Inventory @ "LocalAvailable=" $ AvailableCharges);
// }
public function bool CanUsePower(Actor oTarget)
{
    if (ShouldBlockOpsPack())
    {
        if (!bOpsEligibilityBlocked)
        {
            // LogOpsPack('CanUsePower', "Blocked");
            bOpsEligibilityBlocked = TRUE;
        }
        return FALSE;
    }
    bOpsEligibilityBlocked = FALSE;
    return Super.CanUsePower(oTarget);
}
// END MILAN CHANGE

public function bool OnImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local RvrClientEffectInterface.RvrClientEffectTarget CETarget;
    local SFXModule_DamageParty DamageModule;
    
    // MILAN CHANGE
    // Ensure Ops pack is still eligible for use before actually applying it
    if (ShouldBlockOpsPack())
    {
        //LogOpsPack('OnImpact', "Blocked");
        return FALSE;
    }
    //LogOpsPack('OnImpact', "Apply");
    // END MILAN CHANGE

    DamageModule = m_oPawn.GetModule(Class'SFXModule_DamageParty');
    if (DamageModule != None)
    {
        DamageModule.RecoverFromBleedout();
    }
    ApplyShieldBonus(m_oPawn, ShieldStrength, FALSE, ShieldDuration, Name, TRUE);
    if (CE_ShieldCrustTemplate != None)
    {
        CETarget.Instigator = m_oPawn;
        CETarget.SpawnValue.X = ShieldDuration;
        GUID_ShieldCrustTemplate = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_ShieldCrustTemplate, CETarget, m_oPawn);
        m_oPawn.SetTimer(ShieldDuration, FALSE, 'StopShieldVFX', Self);
        m_oPawn.bCanBeDamaged = FALSE;
        m_oPawn.SetTimer(DamageImmunityLength, FALSE, 'RemoveImmunity', Self);
    }
    UseConsumable();
    //LogOpsPack('OnImpact', "Complete");
    return TRUE;
}
private final function RemoveImmunity()
{
    local SFXModule_GameEffectManager Manager;
    local int idx;
    
    if (m_oPawn == None)
    {
        return;
    }
    Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        for (idx = 0; idx < Manager.GameEffects.Length; idx++)
        {
            if (Manager.GameEffects[idx].IsA('SFXGameEffect_DamageImmunity') == TRUE)
            {
                return;
            }
        }
    }
    m_oPawn.bCanBeDamaged = TRUE;
}
private final function StopShieldVFX()
{
    Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(CE_ShieldCrustTemplate, GUID_ShieldCrustTemplate, TRUE);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    CE_ShieldCrustTemplate = RvrClientEffect'BioVFX_C_Powers.01_Fortification.ShieldBoost_Crust_VCFX'
    ShieldDuration = 20.0
    ShieldStrength = 1000.0
    DamageImmunityLength = 2.0
    CapacityPlayerVariable = 'MPCapacity_Shield'
    CustomCasterCrustParameters = {X = 1.5, Y = 0.0, Z = 0.0}
    CE_CasterCrustTemplate = RvrClientEffect'BioVFX_T_TechPowers._OmniTool.VCFX.OmniTool_Arm_Left_VCFX'
    CastSound = WwiseEvent'Wwise_Power_Tech_TechArmor.Play_power_tech_P_techarmor_cast'
    HenchmanCastSound = WwiseEvent'Wwise_Power_Tech_TechArmor.Play_power_tech_NP_techarmor_cast'
    bCustomCasterCrustParameters = TRUE
    PowerName = 'Consumable_Shield'
    PowerCustomActionID = 68
    DisplayName = $661164
    Description = $661165
    Icon = 93
    TalentDescription = $661165
    MinTimeBetweenActions = 1.0
}