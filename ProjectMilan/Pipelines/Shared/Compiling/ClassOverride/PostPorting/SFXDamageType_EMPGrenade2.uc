// Source: LE3, N7_Engineer_MP
// Initial decompilation: 9/7/2024 4:01:42 PM
// MILAN CHANGE 10/19/2026
// Use same discipline as EMPGrenade2 (N7 Engineer)
// Credit: MP Unofficial Bugfix and Consistency Patch
Class SFXDamageType_EMPGrenade2 extends SFXDamageType_Power_Electrocute
    config(Weapon);

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=ForceFeedbackWaveform Name=DamagedFFWave
    End Template
    // MILAN CHANGE - Use tech
    Discipline = EBioCapMode.BIO_CAPMODE_TECH
    // END MILAN CHANGE
    Resistance = {Shield = 2.0, Biotic = 2.0}
    ShieldHitFFWaveform = DamagedFFWave
    SourceDisplayName = $756716
    DamagedFFWaveform = DamagedFFWave
    KilledFFWaveform = DamagedFFWave
    FracturedMeshDamage = 25.0
}
