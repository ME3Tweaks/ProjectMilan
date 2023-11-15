Class SFXDamageType_ConsumableRocket extends SFXDamageType_HeavyWeapon
    config(Weapon);

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=ForceFeedbackWaveform Name=DamagedFFWave
    End Template
    DamageRadius = 750.0
    ShieldHitFFWaveform = DamagedFFWave
    CE_PlayerFrameBufferEffect = RvrClientEffect'biovfx_env_camerashakes.VCFX.Grenade_Exp_01_VCFX'
    DamagedFFWaveform = DamagedFFWave
    KilledFFWaveform = DamagedFFWave
}