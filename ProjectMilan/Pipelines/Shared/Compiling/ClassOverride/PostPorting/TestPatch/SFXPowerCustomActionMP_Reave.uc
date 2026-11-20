// Source: ME3, Patch_SFXPowerCustomActionMP_Reave
// Decompiled 11/17/2026 7:38:24 AM against AsariCommando_Adept_MP.pcc
Class SFXPowerCustomActionMP_Reave extends SFXPowerCustomAction_Reave
    config(Game);

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_BC_RifleTelekenesis
        m_nmOrigSetName = 'HMM_BC_RifleTelekenesis'
        Sequences = (AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTelekenesis_BC_Start', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTelekenesis_BC_End')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_BC_A.HMM_BC_RifleTelekenesis_BioAnimSetData'
    End Object
    HenchmanConfirmStartSound = None
    HenchmanConfirmStopSound = None
    CastAnimSet = MY_DYN_HMM_BC_RifleTelekenesis
}