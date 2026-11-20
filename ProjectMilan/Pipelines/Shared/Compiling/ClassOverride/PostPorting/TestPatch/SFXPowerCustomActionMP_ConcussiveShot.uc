// Source: ME3, Patch_SFXPwrCustActnMPConcShot
// Decompiled 11/17/2026 7:38:14 AM against HumanFemale_Soldier_MP.pcc
Class SFXPowerCustomActionMP_ConcussiveShot extends SFXPowerCustomAction_ConcussiveShot
    config(Game);

var config float Evolve_DamageBonus2;
var config float Evolve_RadiusBonus2;

public function bool OnImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local SFXPawn oPawn;
    local float fDamage;
    local Class<SFXDamageType> DamageType;
    local bool bRagdolled;
    
    if (oImpacted == None)
    {
        return FALSE;
    }
    oPawn = SFXPawn(oImpacted);
    if (oPawn != None && Resistance != EPowerResistance.Resistance_Full)
    {
        bRagdolled = Resistance == EPowerResistance.Resistance_None && (MaximumRagdollTargets.CurrentValue == float(0) || float(nPreviouslyImpacted) < MaximumRagdollTargets.CurrentValue);
        oPawn.AddPowerAssistEvent(m_oPawn, DisplayName, bRagdolled ? PowerAssistFullControlValue : PowerAssistPartialControlValue);
        if (bRagdolled)
        {
            oPawn.RegisterRBCallback(OnRagdollPhysicsImpact, TRUE);
        }
        if (IsEvolvedWithChoice(5) && oPawn.RaceType != ERaceType.RaceType_Machine)
        {
            fDamage = GetImpactDamage(oImpacted, DamageType) * Evolve_DoTDamage;
            ApplyTemporaryGameEffect(oImpacted, Class'SFXGameEffect_DamageOverTime', Evolve_DoTDuration, fDamage / Evolve_DoTDuration, Name, m_oPawn.Controller);
        }
    }
    return TRUE;
}
public function EvolvePower(SFXPowerCustomActionBase.EEvolveChoice choice)
{
    Super.EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            break;
        case EEvolveChoice.EvolveChoice2:
            break;
        case EEvolveChoice.EvolveChoice3:
            break;
        case EEvolveChoice.EvolveChoice4:
            break;
        case EEvolveChoice.EvolveChoice5:
            AddEvolvedRankBonus(Damage, Evolve_DamageBonus2);
            AddEvolvedRankBonus(ImpactRadius, Evolve_RadiusBonus2);
            break;
        case EEvolveChoice.EvolveChoice6:
            break;
        default:
    }
    RecalculateAllPowerInfo();
}
public function float GetImpactDamage(Actor oImpacted, out Class<SFXDamageType> DamageType)
{
    local SFXModule_GameEffectManager Manager;
    local float fDamage;
    local bool bImpactedIsChilled;
    local SFXGameEffect Effect;
    
    DamageType = GetDamageType();
    fDamage = Damage.CurrentValue;
    if (IsEvolvedWithChoice(2))
    {
        Manager = oImpacted.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None)
        {
            bImpactedIsChilled = FALSE;
            foreach Manager.GameEffects(Effect, )
            {
                if (Effect.IsA('SFXGameEffect_MovementSpeedBonus') && Effect.EffectValue < float(0) && InStr(string(Effect.Category), "Cryo", , , ) != -1)
                {
                    bImpactedIsChilled = TRUE;
                    break;
                }
            }
            if (bImpactedIsChilled || Manager.HasEffectOfType(Class'SFXGameEffect_DelayedCryoFreeze') || Manager.HasEffectOfType(Class'SFXGameEffect_CryoFreeze'))
            {
                fDamage *= 1.0 + Evolve_FreezeComboBonus;
            }
        }
    }
    return fDamage;
}
public function PlayDetonationEffects(Object.Vector ImpactLocation, Object.Vector ImpactNormal, optional SFXProjectile_PowerCustomAction oProjectile)
{
    Super(SFXPowerCustomAction).PlayDetonationEffects(ImpactLocation, ImpactNormal, oProjectile);
    Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayAtLocation(CE_NormalImpact, ImpactLocation, ImpactNormal, GetDefaultClientEffectParams());
}
public function PopulatePowerStatBarEvolves()
{
    Super.PopulatePowerStatBarEvolves();
    PowerStatBars[1].EvolvedBonuses[4] = Evolve_DamageBonus2;
}
public function StartPower()
{
    Super(SFXPowerCustomAction).StartPower();
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_BC_ShotgunSpecial
        m_nmOrigSetName = 'HMM_BC_ShotgunSpecial'
        Sequences = (AnimSequence'BIOG_HMM_BC_A.HMM_BC_ShotgunSpecial_BC_Start', AnimSequence'BIOG_HMM_BC_A.HMM_BC_ShotgunSpecial_BC_End')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_BC_A.HMM_BC_ShotgunSpecial_BioAnimSetData'
    End Object
    Evolve_DamageBonus2 = 0.5
    Evolve_RadiusBonus2 = 100.0
    Evolve_DoTDamage = 2.0
    CastAnimSet = MY_DYN_HMM_BC_ShotgunSpecial
    Ranks = ({
              Icon = 44, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $190258, 
              Evolved1Description = $502601, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 44, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $244427, 
              Evolved1Description = $505365, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 44, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $244428, 
              Evolved1Description = $190375, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 44, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $190921, 
              Evolved1Description = $190922, 
              Evolved2Name = $190917, 
              Evolved2Description = $190918
             }, 
             {
              Icon = 44, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $505438, 
              Evolved1Description = $505439, 
              Evolved2Name = $505448, 
              Evolved2Description = $505449
             }, 
             {
              Icon = 44, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $771245, 
              Evolved1Description = $771249, 
              Evolved2Name = $505470, 
              Evolved2Description = $505471
             }
            )
}