// Source: ME3, Patch_GmEfctMtchConsAmmoPwrDisrupt
// Decompiled 10/31/2026 6:14:07 PM
Class SFXGameEffect_MatchConsumable_AmmoPower_Disruptor extends SFXGameEffect_MatchConsumable_AmmoPower
    config(Game);

var config array<float> Damage;
var config array<float> StunChance;
var config array<float> ElectricComboDuration;
var Class<SFXDamageType> DamageType;
var config float ShieldRegenPenalty;
var config float ShieldRegenPenaltyDuration;
var config float ShieldDamageMultiplier;
var float LastStunTime;

public function OnWeaponImpact(SFXWeapon Weapon, Actor.ImpactInfo Impact)
{
    local BioPawn oPawn;
    local Actor oHitActor;
    local Object.Vector Momentum;
    local float fDamage;
    local Actor.EPowerResistance Resistance;
    local Actor oTargetOverride;
    local float fStunChance;
    local SFXModule_GameEffectManager Manager;
    local float CurrentEnemyShields;
    local float DamageToShields;
    local float DamageNeededToBreakShields;
    
    Super.OnWeaponImpact(Weapon, Impact);
    oHitActor = GetHitTarget(Impact);
    if (Weapon == None || oHitActor == None || Power == None)
    {
        return;
    }
    if (BioPawn(oHitActor) != None && Power.m_oPawn.IsFriendly(BioPawn(oHitActor)))
    {
        return;
    }
    fDamage = GetWeaponDamage(Weapon, Impact) * Damage[VersionIdx];
    Resistance = oHitActor.GetPowerResistance(Power.m_oPawn, Impact.HitLocation, Impact.HitNormal, fDamage, Momentum, DamageType, oTargetOverride);
    if (oTargetOverride != None)
    {
        oHitActor = oTargetOverride;
    }
    oPawn = BioPawn(oHitActor);
    // MILAN CHANGE - 11/14/2026 - Mgamerz
    // Check that hit target is actually a pawn
    if (oPawn != None) 
    {
        CurrentEnemyShields = oPawn.GetCurrentShields();
    }
    // END MILAN CHANGE

    if (CurrentEnemyShields > float(0) && ShieldDamageMultiplier != float(0))
    {
        DamageNeededToBreakShields = CurrentEnemyShields / ShieldDamageMultiplier;
        DamageToShields = FMin(fDamage, DamageNeededToBreakShields);
        fDamage -= DamageToShields;
        DamageToShields *= ShieldDamageMultiplier;
        fDamage += DamageToShields;
    }
    if (oHitActor.ImpactWithPower(Resistance, None, Impact.HitLocation, Impact.HitNormal, fDamage, Momentum, DamageType))
    {
        if (oPawn != None)
        {
            oPawn.ReplicateAnimatedReaction(oPawn.CurrentCustomAction);
        }
    }
    if (int(Resistance) != 0)
    {
        Manager = oHitActor.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None && !Manager.HasEffectOfTypeAndCategory(Class'SFXGameEffect_ShieldRegenBonus', Category))
        {
            Manager.CreateAndApplyEffect(Class'SFXGameEffect_ShieldRegenBonus', Category, ShieldRegenPenaltyDuration, 1, ShieldRegenPenalty, Instigator, Causer);
        }
    }
    // MILAN CHANGE - 11/14/2026 - Mgamerz
    // Add null guard
    if (oPawn != None && OwnerPawn != None && int(OwnerPawn.Role) == 3)
    {
        fStunChance = StunChance[VersionIdx];
        if (BulletsPerSecond > float(0))
        {
            fStunChance = StunChance[VersionIdx] / BulletsPerSecond;
        }
        if (fStunChance > float(0) && FRand() < fStunChance && int(Resistance) != 0 && Power != None && Power.m_oPawn != None && Power.m_oPawn.WorldInfo != None && Power.m_oPawn.WorldInfo.GameTimeSeconds - LastStunTime > 1.0)
        {
            LastStunTime = Power.m_oPawn.WorldInfo.GameTimeSeconds;
            StunEnemy(oPawn);
        }
    }
    // END MILAN CHANGE
}
public function StunEnemy(BioPawn oPawn)
{
    if (oPawn == None || Power == None)
    {
        return;
    }
    if (oPawn != None && int(oPawn.Role) == 3)
    {
        if (oPawn.RequestReaction(3, Instigator))
        {
            oPawn.ReplicateAnimatedReaction(oPawn.CurrentCustomAction);
        }
    }
    Power.AddComboEffect(oPawn, Class'SFXGameEffect_PowerCombo_Electric', ElectricComboDuration[VersionIdx]);
    if (Power.ShouldReplicate())
    {
        Power.ReplicateImpact(oPawn);
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Damage = (0.0500000007, 0.100000001, 0.150000006)
    StunChance = (1.0, 1.39999998, 1.79999995)
    ElectricComboDuration = (3.5, 3.5, 3.5)
    ShieldRegenPenalty = 1.0
    ShieldRegenPenaltyDuration = 8.0
    ShieldDamageMultiplier = 4.0
    HologramTemplate = ParticleSystem'BioVFX_C_Modal.Particles.Modal_Overload'
    IconTemplate = ParticleSystem'BioVFX_C_Modal.Particles.Modal_Holo_Icon_Disruptor'
    NormalImpactSound = WwiseEvent'Wwise_VFX_Tech.Play_vfx_dis_ammo_imp'
    WeaponFireSound = WwiseEvent'Wwise_VFX_Tech.Play_ammo_dis_mzzl'
    VersionCount = 3
}