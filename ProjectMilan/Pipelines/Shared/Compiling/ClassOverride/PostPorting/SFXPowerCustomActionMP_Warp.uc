// Source: LE3, HumanFemale_Sentinel_MP
// Initial decompilation: 9/7/2024 3:56:46 PM
// MILAN CHANGE - UP3
// Preserve Warp damage-over-time DPS with duration bonuses
Class SFXPowerCustomActionMP_Warp extends SFXPowerCustomAction_Warp
    config(Game);

// MILAN CHANGE - UP3 - Preserve Warp DoT DPS when duration increases
public function bool OnImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local SFXPawn ImpactedPawn;
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_FireDamageOverTime DOTEffect;
    local Class<SFXDamageType> DamageType;
    local SFXGameEffect_DeathEffect DeathEffect;
    local float fDamagePerSecond;
    local SFXGameEffect_PowerCombo_Biotic BioticEffect;
    local SFXGameEffect oEffect;
    local Object.Vector Param;
    local float fAssistAmount;
    
    if (Resistance == EPowerResistance.Resistance_Full)
    {
        return FALSE;
    }
    ImpactedPawn = SFXPawn(oImpacted);
    if (ImpactedPawn == None)
    {
        return FALSE;
    }
    Manager = ImpactedPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager == None)
    {
        return FALSE;
    }
    AddComboEffect(oImpacted, Class'SFXGameEffect_PowerCombo_Biotic', EffectDuration.CurrentValue);
    if (IsEvolvedWithChoice(1))
    {
        foreach Manager.GameEffects(oEffect, )
        {
            if (oEffect.@Class == Class'SFXGameEffect_PowerCombo_Biotic')
            {
                BioticEffect = SFXGameEffect_PowerCombo_Biotic(oEffect);
                if (BioticEffect != None)
                {
                    BioticEffect.ComboDamage.X *= 1.0 + Evolve_ComboDamage;
                    BioticEffect.ComboDamage.Y *= 1.0 + Evolve_ComboDamage;
                    BioticEffect.ComboForce.X *= 1.0 + Evolve_ComboForce;
                    BioticEffect.ComboForce.Y *= 1.0 + Evolve_ComboForce;
                    BioticEffect.ComboRadius.X *= 1.0 + Evolve_ComboRadius;
                    BioticEffect.ComboRadius.Y *= 1.0 + Evolve_ComboRadius;
                }
            }
        }
    }
    fDamagePerSecond = GetTotalDamage(oImpacted, DamageType) * (1.0 - InstantDamagePercent) / EffectDuration.BaseValue;
    if (IsEvolvedWithChoice(4))
    {
        DamageType = Class'SFXDamageType_ImprovedWarpDoT';
    }
    else
    {
        DamageType = Class'SFXDamageType_WarpDoT';
    }
    DOTEffect = SFXGameEffect_FireDamageOverTime(Manager.CreateEffect(Class'SFXGameEffect_FireDamageOverTime', Name, EffectDuration.CurrentValue, 1, fDamagePerSecond, m_oPawn.Controller));
    if (DOTEffect != None)
    {
        DOTEffect.DamageType = DamageType;
        DOTEffect.bCanCauseCombo = FALSE;
        DOTEffect.bCanTriggerAchievement = FALSE;
        DOTEffect.OnApplied();
        Param.X = EffectDuration.CurrentValue;
        Class'RvrClientEffectManager'.static.GetClientEffectManager().Play(CE_TargetCrustTemplate, ImpactedPawn, Param);
    }
    if (Resistance == EPowerResistance.Resistance_None)
    {
        if (!Manager.HasEffectOfTypeAndCategory(Class'SFXGameEffect_HealthRegenPenalty', Name))
        {
            ApplyPermanentGameEffect(oImpacted, Class'SFXGameEffect_HealthRegenPenalty', 1.0, Name, m_oPawn.Controller);
        }
    }
    if (!Manager.HasEffectOfTypeAndCategory(Class'SFXGameEffect_DeathEffect', Name))
    {
        DeathEffect = SFXGameEffect_DeathEffect(Manager.CreateEffect(Class'SFXGameEffect_DeathEffect', Name, EffectDuration.CurrentValue + 0.5, 1, 0.0, m_oPawn.Controller));
        if (DeathEffect != None)
        {
            DeathEffect.CE_DeathEffectTemplate = CE_DeathEffect;
            DeathEffect.OnApplied();
        }
    }
    if (IsEvolvedWithChoice(3))
    {
        Manager.RemoveEffectsByTypeAndCategory(Class'SFXGameEffect_BioticPowerDamageTakenBonus', Name);
        Manager.RemoveEffectsByTypeAndCategory(Class'SFXGameEffect_WeaponDamageTakenBonus', Name);
        ApplyTemporaryGameEffect(oImpacted, Class'SFXGameEffect_BioticPowerDamageTakenBonus', Evolve_DebuffDamageTakenDuration.CurrentValue, Evolve_DebuffBioticDamageTakenStrength, Name, m_oPawn.Controller);
        ApplyTemporaryGameEffect(oImpacted, Class'SFXGameEffect_WeaponDamageTakenBonus', Evolve_DebuffDamageTakenDuration.CurrentValue, Evolve_DebuffWeaponDamageTakenStrength, Name, m_oPawn.Controller);
        fAssistAmount += Evolve_DebuffBioticDamageTakenStrength;
    }
    if (ImpactedPawn.HasResistance(3))
    {
        fAssistAmount += ArmorWeakness.CurrentValue;
    }
    if (fAssistAmount > float(0))
    {
        ImpactedPawn.AddPowerAssistEvent(m_oPawn, DisplayName, fAssistAmount);
    }
    ApplyTemporaryGameEffect(oImpacted, Class'SFXGameEffect_ArmorWeakness', EffectDuration.CurrentValue, -ArmorWeakness.CurrentValue, Name, m_oPawn.Controller);
    return TRUE;
}
// END MILAN CHANGE

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_BC_ThrowBiotic
        m_nmOrigSetName = 'HMM_BC_ThrowBiotic'
        Sequences = (AnimSequence'BIOG_HMM_BC_A.HMM_BC_ThrowBiotic_BC_Start', AnimSequence'BIOG_HMM_BC_A.HMM_BC_ThrowBiotic_BC_End')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_BC_A.HMM_BC_ThrowBiotic_BioAnimSetData'
    End Object
    CE_DeathEffect = RvrClientEffect'BioVFX_B_Warp.VCFX.Warp_Death_MP_VCFX'
    CastAnimSet = MY_DYN_HMM_BC_ThrowBiotic
}
