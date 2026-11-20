// Source: ME3, Patch_SFXPwrCustActnDefensiveShld
// Decompiled 11/17/2026 7:38:35 AM against BioD_ProEar_200.pcc
Class SFXPowerCustomAction_DefensiveShield extends SFXPowerCustomAction
    abstract
    config(Game);

var config SFXPowerCustomActionBase.PowerData DamageReduction;
var config SFXPowerCustomActionBase.PowerData EncumbrancePenalty;
var RvrClientEffectInterface CE_ArmorCrustTemplate;
var transient bool bRemoveArmorApplyCooldown;

public function bool CanUsePower(Actor Target)
{
    local SFXModule_GameEffectManager Manager;
    local SFXEngine Engine;
    
    if (SFXPawn_Henchman(m_oPawn) != None && !m_bPlayerOrderedPowerUse)
    {
        Engine = Class'SFXEngine'.static.GetSFXEngine();
        if (Engine != None && !Engine.GetProfileSettings().GetSquadPowerConfigOption())
        {
            return FALSE;
        }
        Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None && Manager.HasEffectOfTypeAndCategory(Class'SFXGameEffect_DefensiveArmor', Name))
        {
            return FALSE;
        }
    }
    return Super.CanUsePower(Target);
}
public function bool OnImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local SFXModule_GameEffectManager Manager;
    
    if (m_oPawn == None || m_oPawn.Role == ENetRole.ROLE_SimulatedProxy)
    {
        return TRUE;
    }
    Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None && Manager.HasEffectOfTypeAndCategory(Class'SFXGameEffect_DefensiveArmor', Name))
    {
        RemoveArmor();
        return FALSE;
    }
    ApplyArmor();
    return TRUE;
}
public event function bool ShouldUsePower(Actor Target, out string sOptionalInfo)
{
    local SFXModule_GameEffectManager Manager;
    
    sOptionalInfo = "";
    Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        return Manager.HasEffectOfType(Class'SFXGameEffect_DefensiveArmor') == FALSE;
    }
    return TRUE;
}
public function ClientDoPowerSubsequentImpact(Actor oActor, optional int CustomActionReactionType, optional float Duration, optional int ImpactCount, optional float Delay, optional bool DoCallback)
{
    switch (ImpactCount)
    {
        case -1:
            if (m_oPawn.Role != ENetRole.ROLE_AutonomousProxy)
            {
                ApplyArmor();
            }
            else
            {
                TryApplyArmor();
            }
            break;
        case -2:
            bRemoveArmorApplyCooldown = FALSE;
            RemoveArmor();
            bRemoveArmorApplyCooldown = TRUE;
            break;
        default:
    }
}
public function DoJoinInProgress()
{
    local SFXModule_GameEffectManager Manager;
    
    if (ShouldReplicate() == FALSE)
    {
        return;
    }
    Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None && Manager.HasEffectOfTypeAndCategory(Class'SFXGameEffect_DefensiveArmor', Name))
    {
        ReplicatePowerSubsequentImpact(m_oPawn, , , -1);
    }
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super(SFXPowerCustomActionBase).RecalculateAllPowerData(bReset);
    RecalculatePowerData(DamageReduction, bReset);
    RecalculatePowerData(EncumbrancePenalty, bReset);
}
public function ResetPower()
{
    Super(SFXPowerCustomActionBase).ResetPower();
    bRemoveArmorApplyCooldown = FALSE;
    RemoveArmor();
    bRemoveArmorApplyCooldown = TRUE;
}
public function RestoreSaveState()
{
    local SFXModule_GameEffectManager Manager;
    
    if (m_oPawn.bInjuredPawn)
    {
        SetSaveGamePowerState(0);
        return;
    }
    if (GetSaveGamePowerState() > 0)
    {
        Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None && !Manager.HasEffectOfType(Class'SFXGameEffect_DefensiveArmor'))
        {
            ApplyArmor();
        }
    }
}
public function RemoveArmor()
{
    local SFXModule_GameEffectManager Manager;
    
    Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        Manager.RemoveEffectsByCategory(Name);
    }
    if (ShouldReplicate())
    {
        ReplicatePowerSubsequentImpact(m_oPawn, , , -2);
    }
    SetSaveGamePowerState(0);
}
public final function SetupEffect(SFXGameEffect_DefensiveArmor Effect)
{
    Effect.CE_ArmorCrustTemplate = CE_ArmorCrustTemplate;
}
public function TryApplyArmor()
{
    local SFXModule_GameEffectManager Manager;
    
    Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None && !Manager.HasEffectOfTypeAndCategory(Class'SFXGameEffect_DefensiveArmor', Name))
    {
        ApplyArmor();
    }
}
public function ApplyArmor()
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_DefensiveArmor ArmorEffect;
    
    Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager == None)
    {
        return;
    }
    if (DamageReduction.CurrentValue > float(0) && !Manager.HasEffectOfTypeAndCategory(Class'SFXGameEffect_DefensiveArmor', Name))
    {
        ArmorEffect = SFXGameEffect_DefensiveArmor(Manager.CreateEffect(Class'SFXGameEffect_DefensiveArmor', Name, 0.0, 2, -DamageReduction.CurrentValue, m_oPawn.Controller));
        if (ArmorEffect != None)
        {
            SetupEffect(ArmorEffect);
            ArmorEffect.Power = Self;
            ArmorEffect.OnApplied();
        }
    }
    m_oPawn.PowerManager.ApplyPowerBonus(m_oPawn, 'CooldownTime', -EncumbrancePenalty.CurrentValue, 0.0, Name, Self, FALSE, TRUE, TRUE, TRUE, FALSE);
    if (ShouldReplicate())
    {
        ReplicatePowerSubsequentImpact(m_oPawn, , , -1);
    }
    SetSaveGamePowerState(1);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    bRemoveArmorApplyCooldown = TRUE
    LeanOutToCast = FALSE
    PowerType = EPowerType.PowerType_Buff
    HenchmanPowerType = EPowerType.PowerType_Buff
}