// MILAN CHANGE - Mgamerz
// Decompiled 09/20/2026
// Always cancel countdown timer on wave finish so things like skipwave work properly.
public function FinishWave()
{
    local Actor ActorIter;
    local AIController AI;
    local SFXGRI GRI;
    
    GRI = SFXGRI(BioWorldInfo.GRI);
    if (BioWorldInfo != None && BioWorldInfo.Role == ENetRole.ROLE_Authority)
    {
        if (BioWorldInfo.GetAutoBotsEnabled() == TRUE)
        {
            foreach BioWorldInfo.AllControllers(Class'AIController', AI)
            {
                if (int(AI.GetTeamNum()) == int(LocalPlayerController.GetTeamNum()))
                {
                    SFXAI_Core(AI).ObjectiveGoalActor = None;
                    if (BioCheatManagerNonNative(LocalPlayerController.CheatManager) != None)
                    {
                        BioCheatManagerNonNative(LocalPlayerController.CheatManager).MPBotsDisableTick(BioPawn(AI.Pawn));
                    }
                }
            }
        }
    }
    foreach ObjectiveActors(ActorIter, )
    {
        ActorIter.Destroy();
    }
    ObjectiveActors.Length = 0;
    ObjectiveSpawnPointData.Length = 0;
    if (bUseObjectiveHud)
    {
        LocalPlayerController.SetScoreHudObjectiveText($0);
    }
    if (!GRI.IsGameOver())
    {
        DistributeObjectiveScore();
        if (srEndWaveMessage != 0 && GRI.NumLivingPlayers() > 0)
        {
            LocalPlayerController.DisplayTextPopup(string(srEndWaveMessage));
        }
        // MILAN Patched: Remove calls to SFXTelemetry
    }
    if (MusicEventName != 'None')
    {
        Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound('Set_mus_gameplaymode_silence');
    }
    // MILAN CHANGE - Always call CancelCountdownTimer() so if a wave changes abnormally the timer is removed from the screen
    CancelCountdownTimer();
    // END MILAN CHANGE
    Super.FinishWave();
}