Class SFXPowerCustomActionMP_Consumable_Shield extends SFXPowerCustomActionMP_Consumable
    config(Game);

// Variables
var Guid GUID_ShieldCrustTemplate;
var RvrClientEffectInterface CE_ShieldCrustTemplate;
var config float ShieldDuration;
var config float ShieldStrength;

// Functions
public function bool OnImpact(EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Vector HitLocation, Vector HitNormal)
{
    local RvrClientEffectTarget CETarget;
    local SFXModule_DamageParty DamageModule;
    
    DamageModule = m_oPawn.GetModule(Class'SFXModule_DamageParty');
    if (DamageModule != None)
    {
        DamageModule.RecoverFromBleedout();
    }
    ApplyShieldBonus(m_oPawn, ShieldStrength, FALSE, ShieldDuration, Name, TRUE);
    if (CE_ShieldCrustTemplate != None)
    {
        CETarget.Instigator = m_oPawn;
        CETarget.SpawnValue.X = ShieldDuration;
        GUID_ShieldCrustTemplate = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_ShieldCrustTemplate, CETarget, m_oPawn);
        m_oPawn.SetTimer(ShieldDuration, FALSE, 'StopShieldVFX', Self);
    }
    UseConsumable();
    return TRUE;
}
private final function StopShieldVFX()
{
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_ShieldCrustTemplate, GUID_ShieldCrustTemplate, TRUE);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    CE_ShieldCrustTemplate = RvrClientEffect'BioVFX_C_Powers.01_Fortification.ShieldBoost_Crust_VCFX'
    ShieldDuration = 20.0
    ShieldStrength = 1000.0
    CapacityPlayerVariable = 'MPCapacity_Shield'
    CustomCasterCrustParameters = {X = 1.5, Y = 0.0, Z = 0.0}
    CE_CasterCrustTemplate = RvrClientEffect'BioVFX_T_TechPowers._OmniTool.VCFX.OmniTool_Arm_Left_VCFX'
    CastSound = WwiseEvent'Wwise_Power_Tech_TechArmor.Play_power_tech_P_techarmor_cast'
    HenchmanCastSound = WwiseEvent'Wwise_Power_Tech_TechArmor.Play_power_tech_NP_techarmor_cast'
    bCustomCasterCrustParameters = TRUE
    PowerName = 'Consumable_Shield'
    PowerCustomActionID = 68
    DisplayName = $661164
    Description = $661165
    Icon = 93
    TalentDescription = $661165
}