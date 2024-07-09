Class SFXAICmd_MoveToCover_Executioner extends SFXAICmd_MoveToCover within SFXAI_Executioner;

public static function bool MoveToCover(SFXAI_Cover AI, optional bool bInDoPeriodicCoverCheck = TRUE, optional bool bInAllowedToFire = TRUE)
{
    local SFXAICmd_MoveToCover_Executioner Cmd;
    
    if (AI != None)
    {
        Cmd = new (SFXAI_Executioner(AI)) Class'SFXAICmd_MoveToCover_Executioner';
        if (Cmd != None)
        {
            Cmd.m_bDoPeriodicCoverCheck = bInDoPeriodicCoverCheck;
            Cmd.m_bAllowedToFire = bInAllowedToFire;
            AI.PushCommand(Cmd);
            return TRUE;
        }
    }
    return FALSE;
}

state MovingToCover 
{
    
Begin:
    if (Outer.MyBP == None || Outer.MyBP.IsDead() || Outer.CoverGoal.Link == None)
    {
        PopState();
    }
    if (Outer.IsValidCover(Outer.CoverGoal) == FALSE || Outer.CoverGoal.Link.Slots[Outer.CoverGoal.SlotIdx].SlotMarker == None)
    {
        PopState();
    }
    Outer.m_bInvalidatedCover = FALSE;
    if (m_bDoPeriodicCoverCheck)
    {
        Outer.SetTimer(0.5, TRUE, 'PeriodicCoverValidation', Self);
    }
    Outer.Sleep(0.00999999978);
    SFXGRI(Outer.WorldInfo.GRI).TriggerVocalizationEvent(18, Outer.MyBP, , , , TRUE);
    if (Outer.CoverGoal.Link.Slots[Outer.CoverGoal.SlotIdx].SlotMarker == Outer.MyBP.Anchor)
    {
        Outer.bReachedMoveGoal = TRUE;
    }
    else
    {
        if (Outer.ExecutionerClass == CloneClassType.CloneClass_Vanguard && Outer.WorldInfo.GameTimeSeconds - Outer.LastTeleportTime > Outer.MinTeleportInterval && FRand() < Outer.TeleportChance)
        {
            Outer.TeleportLocation = Outer.CoverGoal.Link.Slots[Outer.CoverGoal.SlotIdx].SlotMarker;
            Outer.MyBP.StartCustomAction(213, , TRUE);
        }
        Class'SFXAICmd_MoveToGoal_Executioner'.static.MoveToGoal(Outer, Outer.CoverGoal.Link.Slots[Outer.CoverGoal.SlotIdx].SlotMarker, 0.0, m_bAllowedToFire, FALSE);
    }
    if (m_bDoPeriodicCoverCheck)
    {
        Outer.ClearTimer('PeriodicCoverValidation', Self);
    }
    if (Outer.bReachedMoveGoal == FALSE)
    {
        if (Outer.CoverGoal.Link.Slots[Outer.CoverGoal.SlotIdx].SlotOwner == Outer.MyBP)
        {
            Outer.AILog_Internal("Temporarily disabling cover slot " $ Outer.CoverGoal.Link $ ", " $ Outer.CoverGoal.SlotIdx, 'Cover');
            Outer.CoverGoal.Link.SetInvalidUntil(Outer.CoverGoal.SlotIdx, Outer.WorldInfo.GameTimeSeconds + 0.5);
        }
        Outer.UnClaimCover();
        Outer.PopCommand(Self);
    }
    if (Outer.Cover != Outer.CoverGoal)
    {
        if (!Outer.ClaimCover(Outer.CoverGoal))
        {
            Outer.UnClaimCover();
            Outer.PopCommand(Self);
        }
    }
    Class'SFXAICmd_EnterCover'.static.EnterCover(Outer);
    Outer.PopCommand(Self);
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}