// Source: LE3, HumanFemale_Engineer_MP
// Initial decompilation: 9/7/2024 3:56:55 PM
// MILAN CHANGE - UP3
// Keep Incinerate fire priming active for the evolved burn duration
Class SFXPowerCustomActionMP_Incinerate extends SFXPowerCustomAction_Incinerate
    config(Game);

// MILAN CHANGE - UP3 - Match Incinerate fire priming to the selected burn duration
public function bool OnImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_FireDamageOverTime Effect;
    local Class<SFXDamageType> DamageType;
    local float fDamagePerSecond;
    local RvrClientEffectInterface.RvrClientEffectTarget TargetInfo;
    local SFXGameEffect_FireDeath DeathEffect;
    
    if (oImpacted == None)
    {
        return FALSE;
    }
    Manager = oImpacted.GetModule(Class'SFXModule_GameEffectManager');
    if (Resistance == EPowerResistance.Resistance_None && Manager != None)
    {
        if (!Manager.HasEffectOfTypeAndCategory(Class'SFXGameEffect_HealthRegenPenalty', Name))
        {
            ApplyPermanentGameEffect(oImpacted, Class'SFXGameEffect_HealthRegenPenalty', 1.0, Name, m_oPawn.Controller);
        }
        if (!Manager.HasEffectOfTypeAndCategory(Class'SFXGameEffect_FireDeath', Name))
        {
            DeathEffect = SFXGameEffect_FireDeath(Manager.CreateEffect(Class'SFXGameEffect_FireDeath', Name, 2.0, 1, 0.0, m_oPawn.Controller));
            if (DeathEffect != None)
            {
                DeathEffect.CE_DeathEffectTemplate = CE_DeathEffectTemplate;
            }
        }
    }
    if (Resistance != EPowerResistance.Resistance_Full)
    {
        if (Manager != None)
        {
            fDamagePerSecond = GetTotalDamage(oImpacted, DamageType) * (1.0 - InstantDamagePercent) / DOTDuration;
            Effect = SFXGameEffect_FireDamageOverTime(Manager.CreateEffect(Class'SFXGameEffect_FireDamageOverTime', Name, DOTDuration, 1, fDamagePerSecond, m_oPawn.Controller));
            if (Effect != None)
            {
                Effect.DamageType = DamageType;
                Effect.bCanCauseCombo = FALSE;
                Effect.OnApplied();
            }
            if (IsEvolvedWithChoice(2))
            {
                fDamagePerSecond = GetTotalDamage(oImpacted, DamageType) * Evolve_DoTDamagePercent / Evolve_DoTDuration;
                Effect = SFXGameEffect_FireDamageOverTime(Manager.CreateEffect(Class'SFXGameEffect_FireDamageOverTime', Name, Evolve_DoTDuration, 1, fDamagePerSecond, m_oPawn.Controller));
                if (Effect != None)
                {
                    Effect.DamageType = DamageType;
                    Effect.bCanCauseCombo = FALSE;
                    Effect.OnApplied();
                }
            }
            TargetInfo.Instigator = oImpacted;
            if (IsEvolvedWithChoice(2))
            {
                TargetInfo.SpawnValue.X = Evolve_DoTDuration;
            }
            else
            {
                TargetInfo.SpawnValue.X = DOTDuration;
            }
            AddComboEffect(oImpacted, Class'SFXGameEffect_PowerCombo_Fire', TargetInfo.SpawnValue.X);
            Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(CE_FireDoTTemplate, TargetInfo);
        }
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
    Evolve_RadiusBonus = 150.0
    LargeFlameCount = 1
    CE_DeathEffectTemplate = RvrClientEffect'BioVFX_C_Fire.VCFX.Fire_Death_MP_VCFX'
    CastAnimSet = MY_DYN_HMM_BC_RifleTechTool
}
