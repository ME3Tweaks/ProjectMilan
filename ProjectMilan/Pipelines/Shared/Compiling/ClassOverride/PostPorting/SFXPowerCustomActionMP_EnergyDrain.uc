// Source: LE3, Salarian_Infiltrator_MP
// Initial decompilation: 9/7/2024 3:58:21 PM
// MILAN CHANGE - UP3
// Allow Energy Drain shield restoration and defensive buffs to process off-host
Class SFXPowerCustomActionMP_EnergyDrain extends SFXPowerCustomAction_EnergyDrain
    config(Game);

// MILAN CHANGE - UP3 - Allow off-host shield restoration and defensive evolution processing
public function bool OnImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local SFXPawn ImpactedPawn;
    local float ShieldDrainAmount;
    local RvrClientEffectInterface.RvrClientEffectTarget CETarget;
    local SFXModule_GameEffectManager Manager;
    
    ImpactedPawn = SFXPawn(oImpacted);
    if (ImpactedPawn == None || Resistance == EPowerResistance.Resistance_Full)
    {
        return FALSE;
    }
    ImpactedPawn.AddPowerAssistEvent(m_oPawn, DisplayName, PowerAssistPartialControlValue);
    if (IsMachineRace(ImpactedPawn))
    {
        ShieldDrainAmount = MachineHealth - ImpactedPawn.GetCurrentHealth();
    }
    ShieldDrainAmount += EnergyShields - GetCurrentEnergyShields(ImpactedPawn);
    AddComboEffect(ImpactedPawn, Class'SFXGameEffect_PowerCombo_Electric', ElectricComboDuration);
    Manager = ImpactedPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None && !Manager.HasEffectOfTypeAndCategory(Class'SFXGameEffect_ShieldRegenBonus', Name))
    {
        Manager.CreateAndApplyEffect(Class'SFXGameEffect_ShieldRegenBonus', Name, ShieldRegenPenaltyDuration, 1, ShieldRegenPenalty, m_oPawn.Controller, m_oPawn);
    }
    if (ShieldDrainAmount <= float(0))
    {
        return FALSE;
    }
    bDrainedTarget = TRUE;
    CETarget.Instigator = m_oPawn;
    if (bDrainedTarget && IsEvolvedWithChoice(5))
    {
        CETarget.SpawnValue.X = Evolve_DamageReductionDuration.CurrentValue;
    }
    else
    {
        CETarget.SpawnValue.X = 1.0;
    }
    Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(CE_ArmorCrustTemplate, CETarget);
    if (m_oPawn != None)
    {
        ProcessShieldDrain(ImpactedPawn, ShieldDrainAmount * ShieldsRestored.CurrentValue);
    }
    return TRUE;
}
// END MILAN CHANGE

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_BC_RifleTechTool
        m_nmOrigSetName = 'HMM_BC_RifleTechTool'
        Sequences = (AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechTool_BC_Start', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechTool_BC_End')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_BC_A.HMM_BC_RifleTechTool_BioAnimSetData'
    End Object
    CastAnimSet = MY_DYN_HMM_BC_RifleTechTool
}
