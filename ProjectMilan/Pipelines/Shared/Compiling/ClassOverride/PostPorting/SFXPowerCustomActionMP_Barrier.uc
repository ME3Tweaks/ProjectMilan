// Source: LE3, Krogan_Vanguard_MP
// Initial decompilation: 9/7/2024 4:00:28 PM
// MILAN CHANGE - UP3
// Allow Barrier blasts to detonate existing power combos
Class SFXPowerCustomActionMP_Barrier extends SFXPowerCustomAction_Barrier
    config(Game);

// MILAN CHANGE - UP3 - Check existing primers before applying the Barrier lift primer
public function bool OnBlastImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local SFXPawn oPawn;
    local bool bRagdolled;

    oPawn = SFXPawn(oImpacted);
    if (oPawn == None)
    {
        return FALSE;
    }
    bRagdolled = Resistance == EPowerResistance.Resistance_None && (MaximumRagdollTargets.CurrentValue == float(0) || float(nPreviouslyImpacted) < MaximumRagdollTargets.CurrentValue);
    if (Resistance != EPowerResistance.Resistance_Full)
    {
        oPawn.AddPowerAssistEvent(m_oPawn, DisplayName, bRagdolled ? PowerAssistFullControlValue : PowerAssistPartialControlValue);
        CheckForPowerCombo(oPawn, Resistance, HitLocation, HitNormal);
    }
    if (bRagdolled)
    {
        ApplyTemporaryGameEffect(oPawn, Class'SFXGameEffect_AntiGravity', BlastLiftDuration.CurrentValue, 0.0, Name, m_oPawn.Controller);
        ApplyTemporaryGameEffect(oPawn, Class'SFXGameEffect_BarrierLift', BlastLiftDuration.CurrentValue, 0.0, Name, m_oPawn.Controller);
        AddComboEffect(oPawn, Class'SFXGameEffect_PowerCombo_Biotic', BlastLiftDuration.CurrentValue);
    }
    return TRUE;
}
// END MILAN CHANGE

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_DG_Deaths
        m_nmOrigSetName = 'HMM_DG_Deaths'
        Sequences = (AnimSequence'BIOG_HMM_DG_A.HMM_DG_Deaths_DG_FireInTheSky')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_DG_A.HMM_DG_Deaths_BioAnimSetData'
    End Object
// MILAN CHANGE - UP3 - Allow Barrier to detonate all four combo families
    ComboDetonators = (Class'SFXGameEffect_PowerCombo_Biotic', Class'SFXGameEffect_PowerCombo_Electric', Class'SFXGameEffect_PowerCombo_Cryo', Class'SFXGameEffect_PowerCombo_Fire')
// END MILAN CHANGE
    BlastMaxTargets = 3
    CastAnimSet = MY_DYN_HMM_DG_Deaths
    MaximumRagdollTargets = {BaseValue = 1.0}
}
