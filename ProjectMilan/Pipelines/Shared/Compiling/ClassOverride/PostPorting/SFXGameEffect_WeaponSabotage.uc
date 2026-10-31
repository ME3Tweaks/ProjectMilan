// Source: installed LMP, Turian_Engineer_MP
// MILAN CHANGE - UP3
// Attribute Sabotage backfire damage and kills to the casting player
Class SFXGameEffect_WeaponSabotage extends SFXGameEffect;

var Class<SFXDamageType> DamageType;
var Object.Guid WeaponHackGuid;
var RvrClientEffectInterface CE_WeaponHackTemplate;
var RvrClientEffectInterface CE_WeaponHackTemplate_Cannibal;
var RvrClientEffectInterface CE_WeaponExplodeTemplate;
var RvrClientEffectInterface CE_WeaponExplodeTemplate_Cannibal;
var SFXPowerCustomAction Power;
var WwiseEvent ExplosionSound;
var float ElectricComboDuration;

public function OnRemoved()
{
    local SFXModule_Damage DmgModule;
    local BioPawn oPawn;
    local BioPawn AttackingPawn;
    local Actor oTargetOverride;
    local Actor.EPowerResistance Resistance;
    local Object.Vector Force;
    local Actor oTarget;
    local RvrClientEffectInterface.RvrClientEffectTarget TargetInfo;
    
    // MILAN CHANGE - UP3 - Retain the caster as the backfire damage source
    if (Power != None)
    {
        AttackingPawn = Power.m_oPawn;
    }
    if (AttackingPawn == None && Instigator != None)
    {
        AttackingPawn = BioPawn(Instigator.Pawn);
    }
    // END MILAN CHANGE
    oTarget = Owner;
    oPawn = BioPawn(Owner);
    if (oPawn != None)
    {
        DmgModule = oPawn.GetModule(Class'SFXModule_Damage');
        if (DmgModule != None)
        {
            Resistance = oTarget.GetPowerResistance(None, oTarget.location, vect(0.0, 0.0, 1.0), EffectValue, Force, DamageType, oTargetOverride);
            if (oTargetOverride != None)
            {
                oTarget = oTargetOverride;
            }
            if (oTarget.ImpactWithPower(Resistance, AttackingPawn, oTarget.location, vect(0.0, 0.0, 1.0), EffectValue, Force, DamageType))
            {
                oPawn.ReplicateAnimatedReaction(oPawn.CurrentCustomAction);
            }
            oPawn.PlaySound(ExplosionSound, TRUE);
            if (Resistance != EPowerResistance.Resistance_Full && Power != None)
            {
                Power.AddComboEffect(oTarget, Class'SFXGameEffect_PowerCombo_Electric', ElectricComboDuration);
            }
        }
        TargetInfo.Instigator = oPawn;
        TargetInfo.SpawnValue.X = 2.0;
        if (oPawn.@Class.Name == 'SFXPawn_Cannibal')
        {
            Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(CE_WeaponHackTemplate_Cannibal, WeaponHackGuid, TRUE);
            Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(CE_WeaponExplodeTemplate_Cannibal, TargetInfo);
        }
        else
        {
            TargetInfo.HitBone = 'Flash_2';
            Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(CE_WeaponHackTemplate, WeaponHackGuid, TRUE);
            Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(CE_WeaponExplodeTemplate, TargetInfo);
        }
    }
    Super.OnRemoved();
}
public function OnApplied()
{
    local RvrClientEffectInterface.RvrClientEffectTarget TargetInfo;
    local BioPawn oPawn;
    
    Super.OnApplied();
    oPawn = BioPawn(Owner);
    if (oPawn != None)
    {
        TargetInfo.Instigator = oPawn;
        TargetInfo.HitBone = 'Flash_2';
        if (oPawn.@Class.Name == 'SFXPawn_Cannibal')
        {
            WeaponHackGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_WeaponHackTemplate_Cannibal, TargetInfo);
        }
        else
        {
            WeaponHackGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_WeaponHackTemplate, TargetInfo);
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    DamageType = Class'SFXDamageType_SabotageExplode'
    CE_WeaponHackTemplate = RvrClientEffect'BioVFX_T_TechPowers.08_Sabotage.VCFX.Sabotage_Weapon_VCFX'
    CE_WeaponHackTemplate_Cannibal = RvrClientEffect'BioVFX_T_TechPowers.08_Sabotage.VCFX.Sabotage_Weapon_Can_Mesh_VCFX'
    CE_WeaponExplodeTemplate = RvrClientEffect'BioVFX_T_TechPowers.08_Sabotage.VCFX.Sabotage_Weapon_Burst_VCFX'
    CE_WeaponExplodeTemplate_Cannibal = RvrClientEffect'BioVFX_T_TechPowers.08_Sabotage.VCFX.Sabotage_Weapon_Can_VCFX'
    ExplosionSound = WwiseEvent'Wwise_Power_Tech_Overload.Play_power_tech_NP_overload_impact'
    ElectricComboDuration = 2.0
}
