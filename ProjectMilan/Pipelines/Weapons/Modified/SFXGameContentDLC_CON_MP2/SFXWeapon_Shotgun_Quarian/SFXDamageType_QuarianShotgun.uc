// MILAN CHANGE - 12/26/2023
// By: Mgamerz
// Purpose: Change death effect to GUN01 version due to particle system using MP material
Class SFXDamageType_QuarianShotgun extends SFXDamageType_Shotgun
    config(Weapon);

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=ForceFeedbackWaveform Name=DamagedFFWave
    End Template
    Resistance = {Shield = 2.0, Armour = 0.5, Biotic = 2.0}
    DamageRadius = 250.0
    ShieldHitFFWaveform = DamagedFFWave
    CE_DeathEffect = RvrClientEffect'BioVFX_DLC_Wpn_BLSk_GUN01.VCFX.Eletric_Death_VCFX' // MILAN CHANGE - Use GUN01 effect
    bCanGibHead = FALSE
    RadialDamageImpulse = 0.5
    DamagedFFWaveform = DamagedFFWave
    KilledFFWaveform = DamagedFFWave
    FracturedMeshDamage = 35.0
}