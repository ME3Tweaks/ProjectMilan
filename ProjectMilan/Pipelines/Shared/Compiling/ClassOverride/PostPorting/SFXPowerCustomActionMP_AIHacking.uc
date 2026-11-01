// Source: LE3, Quarian_Infiltrator_MP
// Initial decompilation: 9/7/2024 3:57:31 PM
// MILAN CHANGE - UP3
// Apply Sabotage backfire to synthetics when the host cannot apply a hack
Class SFXPowerCustomActionMP_AIHacking extends SFXPowerCustomAction_AIHacking
    config(Game);

// MILAN CHANGE - UP3 - Apply synthetic backfire only when no hack was applied by this power
public function bool OnImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local BioPawn oPawn;
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_WeaponSabotage Sabotage;
    local SFXGameEffect oEffect;
    local SFXGameEffect_AIHacking HackingEffect;
    local bool bShouldBackfire;
    
    oPawn = BioPawn(oImpacted);
    if (oPawn == None)
    {
        return FALSE;
    }
    if (Resistance != EPowerResistance.Resistance_Full)
    {
        bShouldBackfire = TRUE;
        if (oPawn.RaceType == ERaceType.RaceType_Machine)
        {
            // The host decides whether a synthetic is hacked or receives backfire.
            bShouldBackfire = FALSE;
            if (m_oPawn != None && m_oPawn.Role == ENetRole.ROLE_Authority)
            {
                bShouldBackfire = TRUE;
                if (!bRobotHacked)
                {
                    bRobotHacked = TRUE;
                    UnHackPreviousTargets();
                }
                if (CanHackNewRobot(oPawn))
                {
                    HackNewRobot(SFXPawn(oPawn));
                    Manager = oPawn.GetModule(Class'SFXModule_GameEffectManager');
                    if (Manager != None)
                    {
                        foreach Manager.GameEffects(oEffect, )
                        {
                            HackingEffect = SFXGameEffect_AIHacking(oEffect);
                            if (HackingEffect != None && HackingEffect.Power == Self)
                            {
                                bShouldBackfire = FALSE;
                                break;
                            }
                        }
                    }
                }
            }
        }
        if (bShouldBackfire)
        {
            Manager = oPawn.GetModule(Class'SFXModule_GameEffectManager');
            if (Manager != None)
            {
                Sabotage = SFXGameEffect_WeaponSabotage(Manager.CreateEffect(Class'SFXGameEffect_WeaponSabotage', Name, WeaponHackDuration, 1, WeaponExplosionDamage.CurrentValue, m_oPawn.Controller));
                if (Sabotage != None)
                {
                    Sabotage.Power = Self;
                    Sabotage.OnApplied();
                }
            }
        }
        if (IsEvolvedWithChoice(5))
        {
            Manager = oPawn.GetModule(Class'SFXModule_GameEffectManager');
            if (Manager != None)
            {
                Manager.RemoveEffectsByTypeAndCategory(Class'SFXGameEffect_TechPowerDamageTakenBonus', TechPowerDamageTakenBonusEffectCategory);
            }
            ApplyTemporaryGameEffect(oPawn, Class'SFXGameEffect_TechPowerDamageTakenBonus', Evolve_TechPowerDuration, Evolve_TechPowerDamageBonus, TechPowerDamageTakenBonusEffectCategory, m_oPawn.Controller);
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
    CastAnimSet = MY_DYN_HMM_BC_RifleTechTool
    MaximumImpactTargets = {BaseValue = 2.0}
}
