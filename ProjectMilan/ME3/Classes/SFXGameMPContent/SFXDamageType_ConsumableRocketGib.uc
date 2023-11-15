Class SFXDamageType_ConsumableRocketGib extends SFXDamageType_ConsumableRocket
    config(Weapon);

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=ForceFeedbackWaveform Name=DamagedFFWave
    End Template
    ShieldHitFFWaveform = DamagedFFWave
    CE_DeathEffect = RvrClientEffect'BioVFX_C_Blood.VCFX.Gib_01_VCFX'
    bCorpseDestroyedOnDeath = TRUE
    DamagedFFWaveform = DamagedFFWave
    KilledFFWaveform = DamagedFFWave
}