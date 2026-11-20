// Source: ME3, Patch_SFXPwrCustActnMPSingularity
// Decompiled 11/17/2026 7:38:27 AM against Cerberus_Adept_MP.pcc
Class SFXPowerCustomActionMP_Singularity extends SFXPowerCustomAction_Singularity
    config(Game);

public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 4;
    PowerStatBars[0].Data = CooldownTime;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_Cooldown;
    PowerStatBars[0].EvolvedBonuses[3] = Evolve_RechargeSpeed;
    PowerStatBars[1].Data = SingularityDuration;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_Duration;
    PowerStatBars[1].EvolvedBonuses[0] = Evolve_DurationBonus;
    PowerStatBars[2].Data = ImpactRadius;
    PowerStatBars[2].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Distance;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Distance;
    PowerStatBars[2].srStatBarDisplayTitle = StatBarTitle_ImpactRadius;
    PowerStatBars[2].EvolvedBonuses[1] = Evolve_RadiusBonus;
    PowerStatBars[3].Data = Damage;
    PowerStatBars[3].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[3].srStatBarDisplayTitle = StatBarTitle_DamagePerSecond;
    PowerStatBars[3].EvolvedBonuses[4] = Evolve_DamageBonus;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_BC_RifleTelekenesis
        m_nmOrigSetName = 'HMM_BC_RifleTelekenesis'
        Sequences = (AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTelekenesis_BC_Start', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTelekenesis_BC_End')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_BC_A.HMM_BC_RifleTelekenesis_BioAnimSetData'
    End Object
    SingularityDuration = {BaseValue = 8.0}
    Evolve_RadiusBonus = 0.349999994
    Evolve_DurationBonus = 1.5
    DetonateMaxRagdollCount = 1
    NonRagdollChargeUse = 0.0
    RagdollChargeUse = 0.0
    ComboNonRagdollDuration = 3.0
    Evolve_DamageBonus = 0.5
    Patch4IterationApplied = TRUE
    PowerAssistPartialControlValue = 0.0625
    CastAnimSet = MY_DYN_HMM_BC_RifleTelekenesis
    CooldownTime = {BaseValue = 8.0}
    ImpactRadius = {RankBonuses[2] = 0.0}
    EffectDuration = {RankBonuses[2] = 0.0}
    Damage = {RankBonuses[2] = 0.200000003, BaseValue = 100.0}
    Ranks = ({
              Icon = 27, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $127058, 
              Evolved1Description = $155064, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 27, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $287414, 
              Evolved1Description = $619263, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 51, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $250284, 
              Evolved1Description = $560406, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 27, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $194960, 
              Evolved1Description = $194958, 
              Evolved2Name = $287427, 
              Evolved2Description = $287428
             }, 
             {
              Icon = 27, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $501497, 
              Evolved1Description = $501499, 
              Evolved2Name = $501502, 
              Evolved2Description = $501500
             }, 
             {
              Icon = 27, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $244477, 
              Evolved1Description = $558835, 
              Evolved2Name = $501498, 
              Evolved2Description = $501504
             }
            )
}