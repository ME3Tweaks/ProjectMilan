// MILAN CHANGE - 11/19/2026 - Mgamerz
// Omni-key split - ladder nodes 'Use' now use PC_Use
public function string GetActionIconString(BioDefine.ESFXHUDActionIcon eActionIcon)
{
    local stringref sr;
    local string sAction;

    ClearCustomTokens();
    switch (eActionIcon)
    {
        case ESFXHUDActionIcon.SFXHUD_Cover_Enter:
            sr = m_srCoverEnterAction;
            SetCustomToken(0, GetBoundKeyString("Shared_Action"));
            break;
        case ESFXHUDActionIcon.SFXHUD_Cover_Mantle:
            sr = m_srCoverMantleAction;
            SetCustomToken(0, "[XBoxB_Btn_LSUp]");
            SetCustomToken(1, GetBoundKeyString("Shared_Action"));
            break;
        case ESFXHUDActionIcon.SFXHUD_Cover_Climb:
            sr = m_srCoverClimbAction;
            SetCustomToken(0, "[XBoxB_Btn_LSUp]");
            SetCustomToken(1, GetBoundKeyString("Shared_Action"));
            break;
        case ESFXHUDActionIcon.SFXHUD_Cover_90DegreeRight:
            sr = m_srCover90RightAction;
            SetCustomToken(0, GetBoundKeyString("Shared_Action"));
            break;
        case ESFXHUDActionIcon.SFXHUD_Cover_90DegreeLeft:
            sr = m_srCover90LeftAction;
            SetCustomToken(0, GetBoundKeyString("Shared_Action"));
            break;
        case ESFXHUDActionIcon.SFXHUD_Cover_SlipRight:
            sr = m_srCoverSlipRightAction;
            SetCustomToken(0, "[XBoxB_Btn_LSUp]");
            SetCustomToken(1, GetBoundKeyString("Shared_Action"));
            break;
        case ESFXHUDActionIcon.SFXHUD_Cover_SlipLeft:
            sr = m_srCoverSlipLeftAction;
            SetCustomToken(0, "[XBoxB_Btn_LSUp]");
            SetCustomToken(1, GetBoundKeyString("Shared_Action"));
            break;
        case ESFXHUDActionIcon.SFXHUD_Cover_SwatTurnRight:
            sr = m_srCoverSwatRightAction;
            SetCustomToken(0, "[XBoxB_Btn_LSRight]");
            SetCustomToken(1, GetBoundKeyString("Shared_Action"));
            break;
        case ESFXHUDActionIcon.SFXHUD_Cover_SwatTurnLeft:
            sr = m_srCoverSwatLeftAction;
            SetCustomToken(0, "[XBoxB_Btn_LSLeft]");
            SetCustomToken(1, GetBoundKeyString("Shared_Action"));
            break;
        case ESFXHUDActionIcon.SFXHUD_Cover_Grab:
            sr = m_srCoverGrabAction;
            SetCustomToken(0, GetBoundKeyString("Shared_Melee"));
            break;
        // MILAN CHANGE - Change Use icon for ladders
        case ESFXHUDActionIcon.SFXHUD_LadderUp:
            sr = m_srLadderUpAction;
            SetCustomToken(0, GetBoundKeyString("PC_Use"));
            break;
        case ESFXHUDActionIcon.SFXHUD_LadderDown:
            sr = m_srLadderDownAction;
            SetCustomToken(0, GetBoundKeyString("PC_Use"));
            break;
        // END MILAN CHANGE
        case ESFXHUDActionIcon.SFXHUD_GapJump:
            sr = m_srGapJumpAction;
            SetCustomToken(0, "[XBoxB_Btn_LSUp]");
            SetCustomToken(1, GetBoundKeyString("Shared_Action"));
            break;
        case ESFXHUDActionIcon.SFXHUD_AtlasSuit:
            sr = m_srAtlasSuitAction;
            SetCustomToken(0, GetBoundKeyString("Shared_Action"));
            break;
        default:
    }
    sAction = GetUIString(sr, TRUE);
    return sAction;
}
