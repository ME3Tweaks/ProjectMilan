// Source: LE3, N7_Engineer_MP
// Initial decompilation: 9/7/2024 4:01:42 PM
// MILAN CHANGE - UP3
// Classify Homing Grenade damage as tech damage
Class SFXDamageType_HomingGrenade extends SFXDamageType_Power_Fire
    config(Weapon);

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=ForceFeedbackWaveform Name=DamagedFFWave
    End Template
    // MILAN CHANGE - UP3 - Classify Homing Grenade damage as tech
    Discipline = EBioCapMode.BIO_CAPMODE_TECH
    // END MILAN CHANGE
    ShieldHitFFWaveform = DamagedFFWave
    SourceDisplayName = $754613
    DamagedFFWaveform = DamagedFFWave
    KilledFFWaveform = DamagedFFWave
}
