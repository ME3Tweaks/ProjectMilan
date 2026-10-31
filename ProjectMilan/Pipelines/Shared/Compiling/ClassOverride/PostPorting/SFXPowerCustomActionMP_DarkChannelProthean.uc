// Source: LE3, Collector_Adept_MP
// Initial decompilation: 9/7/2024 5:13:18 PM
// MILAN CHANGE - UP3
// Preserve Dark Channel damage type on replicated jumps and restore Prothean visuals
Class SFXPowerCustomActionMP_DarkChannelProthean extends SFXPowerCustomActionMP_DarkChannel2_MP5
    config(Game);

public function bool OnImpact(EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Vector HitLocation, Vector HitNormal)
{
    local SFXModule_GameEffectManager Manager;
    local BioPawn oPawn;
    local SFXGameEffectMP_ProtheanDarkChannel oEffect;
    
    if (Resistance == EPowerResistance.Resistance_Full)
    {
        return FALSE;
    }
    oPawn = BioPawn(oImpacted);
    if (oPawn != None)
    {
        if (CurrentTarget != None)
        {
            Manager = CurrentTarget.GetModule(Class'SFXModule_GameEffectManager');
            if (Manager != None)
            {
                Manager.RemoveEffectsByCategory(Name);
            }
        }
        Manager = oPawn.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None)
        {
            oEffect = SFXGameEffectMP_ProtheanDarkChannel(Manager.CreateEffect(Class'SFXGameEffectMP_ProtheanDarkChannel', Name, EffectDuration.CurrentValue, 1, Damage.CurrentValue, m_oPawn.Controller));
            if (oEffect != None)
            {
                if (IsEvolvedWithChoice(5))
                {
                    oEffect.DamageType = Class'SFXDamageTypeMP_ProtheanDarkChannel_Improved';
                }
                else
                {
                    oEffect.DamageType = Class'SFXDamageTypeMP_ProtheanDarkChannel';
                }
                if (IsEvolvedWithChoice(2))
                {
                    oEffect.SlowPercent = Evolve_MoveSpeedPenalty;
                    Manager.CreateAndApplyEffect(Class'SFXGameEffect_MovementSpeedBonus', Name, EffectDuration.CurrentValue, 1, -Evolve_MoveSpeedPenalty, m_oPawn.Controller);
                }
                else
                {
                    oEffect.SlowPercent = 0.0;
                }
                oEffect.Power = Self;
                oEffect.OnApplied();
            }
            CurrentTarget = oPawn;
        }
        return TRUE;
    }
    return FALSE;
}
public function ClientDoPowerSubsequentImpact(Actor oActor, optional int CustomActionReactionType, optional float Duration, optional int ImpactCount, optional float Delay, optional bool DoCallback)
{
    local SFXGameEffectMP_ProtheanDarkChannel Effect;
    local SFXModule_GameEffectManager Manager;
    
    if (m_oPawn == None || BioPawn(oActor) == None)
    {
        return;
    }
    Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
    Effect = SFXGameEffectMP_ProtheanDarkChannel(Manager.CreateEffect(Class'SFXGameEffectMP_ProtheanDarkChannel', Name, EffectDuration.CurrentValue, 1, Damage.CurrentValue, m_oPawn.Controller));
    if (Effect != None)
    {
        Effect.CurrentTime = Duration;
        Effect.Duration = EffectDuration.CurrentValue;
        Effect.OwnerPawn = CurrentTarget;
        Effect.LastHitPawn = CurrentTarget;
        Effect.Power = Self;
        // MILAN CHANGE - UP3 - Initialize the replicated Dark Channel jump damage type
        if (IsEvolvedWithChoice(5))
        {
            Effect.DamageType = Class'SFXDamageTypeMP_ProtheanDarkChannel_Improved';
        }
        else
        {
            Effect.DamageType = Class'SFXDamageTypeMP_ProtheanDarkChannel';
        }
        // END MILAN CHANGE
        Effect.ImpactAdditionalTarget(BioPawn(oActor));
        Manager.RemoveEffect(Effect);
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_BC_ThrowBiotic
        m_nmOrigSetName = 'HMM_BC_ThrowBiotic'
        Sequences = (AnimSequence'BIOG_HMM_BC_A.HMM_BC_ThrowBiotic_BC_Start', AnimSequence'BIOG_HMM_BC_A.HMM_BC_ThrowBiotic_BC_End')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_BC_A.HMM_BC_ThrowBiotic_BioAnimSetData'
    End Object
    CastAnimSet = MY_DYN_HMM_BC_ThrowBiotic
    // MILAN CHANGE - UP3 - Use Prothean Dark Channel caster and impact effects
    CE_CasterCrustTemplate = RvrClientEffect'BioVFX_Hch_Prothean.VCFX.DarkChannel_Charge_VCFX'
    CE_ImpactTemplate = RvrClientEffect'BioVFX_Hch_Prothean.VCFX.DarkChannel_Impact_VCFX'
    // END MILAN CHANGE
    CooldownTime = {BaseValue = 6.0}
    Damage = {BaseValue = 125.0}
}
