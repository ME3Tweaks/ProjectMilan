// Source: ME3, Patch_GmEfctMtchConsAmmoPwrArmPrc
// Decompiled 11/17/2026 7:37:48 AM against SFXGE_MatchConsumables.pcc
Class SFXGameEffect_MatchConsumable_AmmoPower_ArmorPiercing extends SFXGameEffect_MatchConsumable_AmmoPower
    config(Game);

var config array<float> Damage;
var config array<float> Penetration;
var config array<float> ArmorReduction;
var Class<SFXDamageType> DamageType;
var ParticleSystem PS_OrganicImpactEffect;
var ParticleSystem PS_NonOrganicImpactEffect;
var float VFXSpawnChance;

public function OnRemoved()
{
    local SFXModule_GameEffectManager Manager;
    local SFXWeapon Weapon;
    local SFXInventoryManager InvManager;
    
    Super.OnRemoved();
    if (OwnerPawn == None)
    {
        return;
    }
    InvManager = SFXInventoryManager(OwnerPawn.InvManager);
    if (InvManager == None)
    {
        return;
    }
    foreach InvManager.InventoryActors(Class'SFXWeapon', Weapon)
    {
        Manager = Weapon.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager == None)
        {
            return;
        }
        if (Penetration[VersionIdx] > float(0))
        {
            Manager.RemoveEffectsByTypeAndCategory(Class'SFXGameEffect_PenetrationBonus', Category);
        }
        if (ArmorReduction[VersionIdx] > float(0))
        {
            Manager.RemoveEffectsByTypeAndCategory(Class'SFXGameEffect_ArmorPiercingBonus', Category);
        }
    }
}
public function OnApplied()
{
    local SFXModule_GameEffectManager Manager;
    local SFXWeapon Weapon;
    local SFXInventoryManager InvManager;
    
    Super.OnApplied();
    if (OwnerPawn == None)
    {
        return;
    }
    InvManager = SFXInventoryManager(OwnerPawn.InvManager);
    if (InvManager == None)
    {
        return;
    }
    foreach InvManager.InventoryActors(Class'SFXWeapon', Weapon)
    {
        Manager = Weapon.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager == None)
        {
            return;
        }
        if (Penetration[VersionIdx] > float(0))
        {
            Manager.CreateAndApplyEffect(Class'SFXGameEffect_PenetrationBonus', Category, 0.0, 2, Penetration[VersionIdx], Instigator);
        }
        if (ArmorReduction[VersionIdx] > float(0))
        {
            Manager.CreateAndApplyEffect(Class'SFXGameEffect_ArmorPiercingBonus', Category, 0.0, 2, ArmorReduction[VersionIdx], Instigator);
        }
    }
}
public function OnWeaponImpact(SFXWeapon Weapon, Actor.ImpactInfo Impact)
{
    local SFXPawn Pawn;
    local float ExtraDamage;
    
    Super.OnWeaponImpact(Weapon, Impact);
    Pawn = SFXPawn(Impact.HitActor);
    if (Pawn == None || Pawn.IsDead() || Pawn.IsFriendly(OwnerPawn) || Weapon == None || OwnerPawn == None || Impact.HitActor == None)
    {
        return;
    }
    ExtraDamage = GetWeaponDamage(Weapon, Impact) * Damage[VersionIdx];
    Pawn.TakeDamage(ExtraDamage, OwnerPawn.Controller, vect(0.0, 0.0, 0.0), vect(0.0, 0.0, 0.0), DamageType);
    if (int(Pawn.GetCurrentResistance()) != 0)
    {
        if (FRand() < VFXSpawnChance / BulletsPerSecond)
        {
            if (Pawn.RaceType == ERaceType.RaceType_Machine)
            {
                SpawnWeaponImpactVFX(Instigator, Impact, PS_NonOrganicImpactEffect);
            }
            else
            {
                SpawnWeaponImpactVFX(Instigator, Impact, PS_OrganicImpactEffect, FALSE);
            }
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Damage = (0.100000001, 0.200000003, 0.300000012)
    Penetration = (0.5, 0.75, 1.0)
    ArmorReduction = (0.5, 0.649999976, 0.75)
    DamageType = Class'SFXDamageType_ArmorPiercingAmmo'
    PS_OrganicImpactEffect = ParticleSystem'BioVFX_C_Impacts.Blood.Particles.Blood_Red_Psys_MassiveDamage'
    PS_NonOrganicImpactEffect = ParticleSystem'BioVFX_C_Impacts.Metal.Particles.Blue_Metal_Robot_MassiveDamage'
    VFXSpawnChance = 1.0
    HologramTemplate = ParticleSystem'BioVFX_C_Modal.Particles.Modal_ArmorPiercing'
    IconTemplate = ParticleSystem'BioVFX_C_Modal.Particles.Modal_Holo_Icon_ArmorPiercing'
    NormalImpactSound = WwiseEvent'Wwise_VFX_Tech.Play_ammo_ap_imp'
    WeaponFireSound = WwiseEvent'Wwise_VFX_Tech.Play_ammo_ap_mzzl'
    VersionCount = 3
}