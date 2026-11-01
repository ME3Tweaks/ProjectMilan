// Source: LE3, HumanFemale_Sentinel_MP
// Initial decompilation: 9/7/2024 3:56:46 PM
// MILAN CHANGE - UP3
// Allow Tech Armor blasts to detonate elemental power combos
Class SFXPowerCustomActionMP_TechArmor extends SFXPowerCustomAction_TechArmor
    config(Game);

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_BC_RifleTechToolActivate
        m_nmOrigSetName = 'HMM_BC_RifleTechToolActivate'
        Sequences = (AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechToolActivate_BC_Start', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechToolActivate_BC_Start_Cover_Neutral', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechToolActivate_BC_Start_Cover_Neutral_Mid', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechToolActivate_BC_End', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechToolActivate_BC_End_Cover_Neutral', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechToolActivate_BC_End_Cover_Neutral_Mid')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_BC_A.HMM_BC_RifleTechToolActivate_BioAnimSetData'
    End Object
    CastAnimSet = MY_DYN_HMM_BC_RifleTechToolActivate
// MILAN CHANGE - UP3 - Allow Tech Armor to detonate electric, cryo and fire primers
    ComboDetonators = (Class'SFXGameEffect_PowerCombo_Electric', Class'SFXGameEffect_PowerCombo_Cryo', Class'SFXGameEffect_PowerCombo_Fire')
// END MILAN CHANGE
}
