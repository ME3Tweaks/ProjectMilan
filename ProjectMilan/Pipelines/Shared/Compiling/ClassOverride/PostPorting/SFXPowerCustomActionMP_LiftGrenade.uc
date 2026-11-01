// Source: LE3, Krogan_Sentinel_MP
// Initial decompilation: 9/7/2024 3:57:27 PM
// MILAN CHANGE - UP3/Mgamerz
// Allow protected targets to detonate combos without granting lift effects
Class SFXPowerCustomActionMP_LiftGrenade extends SFXPowerCustomAction_LiftGrenade
    config(Game);

// MILAN CHANGE - UP3/Mgamerz - Separate combo-capable hits from lift eligibility and retain partial assists
public function bool OnImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_LiftGrenade Effect;
    local SFXPawn oPawn;
    local Object.Vector vInitialForce;
    local bool bRagdolled;

    oPawn = SFXPawn(oImpacted);
    if (oPawn == None || Resistance == EPowerResistance.Resistance_Full)
    {
        return FALSE;
    }
    bRagdolled = Resistance == EPowerResistance.Resistance_None && (MaximumRagdollTargets.CurrentValue == float(0) || float(nPreviouslyImpacted) < MaximumRagdollTargets.CurrentValue);
    oPawn.AddPowerAssistEvent(m_oPawn, DisplayName, bRagdolled ? PowerAssistFullControlValue : PowerAssistPartialControlValue);
    if (bRagdolled)
    {
        Manager = oPawn.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager == None)
        {
            return FALSE;
        }
        vInitialForce = Normal(vect(0.0, 0.0, 4.0) + Normal(oPawn.location - HitLocation)) * InitialForce.CurrentValue;
        oPawn.AddRagdollImpulse(vInitialForce, m_oPawn.Controller, oPawn.location);
        AddComboEffect(oPawn, Class'SFXGameEffect_PowerCombo_Biotic', EffectDuration.CurrentValue);
        Effect = SFXGameEffect_LiftGrenade(Manager.CreateEffect(Class'SFXGameEffect_LiftGrenade', Name, EffectDuration.CurrentValue, 1, 0.0, m_oPawn.Controller));
        if (Effect != None)
        {
            Effect.ForceVector = Normal(vInitialForce);
            if (IsEvolvedWithChoice(4))
            {
                Effect.bSlamWhenDone = TRUE;
                Effect.SlamForce = SlamForce.CurrentValue;
                Effect.SlamRagdollDuration = SlamRagdollDuration.CurrentValue;
            }
            Effect.OnApplied();
        }
    }
    return TRUE;
}
// END MILAN CHANGE

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_CB_Grenade
        m_nmOrigSetName = 'HMM_CB_Grenade'
        Sequences = (AnimSequence'BIOG_HMM_CB_A.HMM_CB_Grenade_CB_Grenade2')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_CB_A.HMM_CB_Grenade_BioAnimSetData'
    End Object
    Evolve_GrenadeCountBonus = 1
    CastAnimSet = MY_DYN_HMM_CB_Grenade
    MaximumRagdollTargets = {BaseValue = 1.0}
}
