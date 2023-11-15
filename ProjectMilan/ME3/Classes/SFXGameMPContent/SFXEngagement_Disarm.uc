Class SFXEngagement_Disarm extends SFXWave_Operation
    perobjectconfig
    config(Game);

// Variables
var array<SFXOperationObjective> DisabledBombs;
var int NumDisarmsCompleted;
var config int NumDisarmsRequired;
var config stringref srDisarmBombMessage;
var config stringref srDisarmNextBombMessage;
var config stringref srEndWaveSuccess;
var config float ActivateNextBombDelay;
var config float WaveInstructionVODelay;
var config float InstructionReminderDelay;
var config stringref srBombDisarmedTicker;
var transient SFXOperationObjective ActiveBomb;

// Functions
public function bool BeginWave()
{
    if (!Super.BeginWave())
    {
        return FALSE;
    }
    ActiveBomb = None;
    NumDisarmsCompleted = 0;
    DisabledBombs.Length = 0;
    ActivateRandomBomb();
    if (ActiveBomb != None)
    {
        ActiveBomb.PlayMeshSpecificVOLine();
    }
    WaveCoordinator.SetTimer(WaveInstructionVODelay, FALSE, 'PlayWaveInstructions', Self);
    WaveCoordinator.SetTimer(InstructionReminderDelay, TRUE, 'PlayInstructionReminder', Self);
    LocalPlayerController.SetObjectiveCircleText("1", "2", "3", "4");
    LocalPlayerController.SetObjectiveCircleProgress(0);
    return TRUE;
}
public function CancelCountdownTimer()
{
    Super.CancelCountdownTimer();
    WaveCoordinator.ClearTimer('PlayTimeWarning', Self);
}
public function FinishWave()
{
    local Actor ObjectiveActor;
    local SFXModule_MarkerObjective Module;
    
    WaveCoordinator.ClearTimer('ActivateNextBomb', Self);
    WaveCoordinator.ClearTimer('PlayInstructionReminder', Self);
    ActiveBomb = None;
    foreach ObjectiveActors(ObjectiveActor, )
    {
        Module = ObjectiveActor.GetModule(Class'SFXModule_MarkerObjective');
        if (Module != None)
        {
            Module.Deactivate();
        }
    }
    if (NumDisarmsCompleted != NumDisarmsRequired)
    {
        srEndWaveMessage = srEndWaveFailure;
    }
    Super.FinishWave();
}
public function ActivateNextBomb()
{
    if (WaveCoordinator != None && WaveCoordinator.Role == ENetRole.ROLE_Authority)
    {
        ActivateRandomBomb();
    }
    LocalPlayerController.DisplayTextPopup(string(srDisarmNextBombMessage));
}
public function ActivateRandomBomb()
{
    local Actor oActor;
    local SFXOperationObjective ObjectiveActor;
    
    foreach ObjectiveActors(oActor, )
    {
        ObjectiveActor = SFXOperationObjective(oActor);
        if (ObjectiveActor != None && DisabledBombs.Find(ObjectiveActor) == -1)
        {
            ObjectiveActor.ActivateObjective();
            ActiveBomb = ObjectiveActor;
            break;
        }
    }
}
public function OnBombDisarmed(SFXOperationObjective Bomb, BioPawn oPawn)
{
    local SFXScoreManager ScoreManager;
    local SFXGRI GRI;
    local SFXMPEventTicker EventTicker;
    local float fScore;
    local SFXPRI PRI;
    
    DisabledBombs.AddItem(Bomb);
    NumDisarmsCompleted++;
    SetCustomToken(0, string(NumDisarmsCompleted));
    SetCustomToken(1, string(NumDisarmsRequired));
    LocalPlayerController.DisplayTextPopup(string(srDisarmBombMessage));
    ClearCustomTokens();
    LocalPlayerController.SetObjectiveCircleProgress(NumDisarmsCompleted);
    GRI = SFXGRI(WaveCoordinator.WorldInfo.GRI);
    if (GRI != None && SFXPawn_Player(oPawn) != None)
    {
        ScoreManager = GRI.GetScoreManager();
        if (ScoreManager != None)
        {
            fScore = ScoreManager.AddScore(SFXPawn_Player(oPawn), OperationScoreReward / float(NumDisarmsRequired), 2);
        }
        EventTicker = GRI.GetEventTicker();
        if ((EventTicker != None && srBombDisarmedTicker != 0) && fScore > float(0))
        {
            PRI = SFXPRI(oPawn.PlayerReplicationInfo);
            if (PRI != None)
            {
                ClearCustomTokens();
                SetCustomToken(0, PRI.PlayerName);
                SetCustomToken(1, string(int(fScore)));
                EventTicker.AddTickerEntry(Class'SFXGame'.static.GetSimpleString(srBombDisarmedTicker, TRUE));
                ClearCustomTokens();
            }
        }
    }
    if (DisabledBombs.Length == NumDisarmsRequired)
    {
        PlayVOEvent('WaveCompleted');
        WaveCoordinator.ClearTimer('PlayInstructionReminder', Self);
        DelayedFinishWave();
    }
    else
    {
        WaveCoordinator.SetTimer(ActivateNextBombDelay, FALSE, 'ActivateNextBomb', Self);
        WaveCoordinator.SetTimer(InstructionReminderDelay, TRUE, 'PlayInstructionReminder', Self);
        if (NumDisarmsCompleted == NumDisarmsRequired / 2)
        {
            PlayVOEvent('WaveHalfCompleted');
        }
        else
        {
            PlayVOEvent('BombDisarmed');
        }
    }
}
public final function PlayInstructionReminder()
{
    PlayVOEvent('InstructionReminder');
}
public final function PlayTimeWarning()
{
    PlayVOEvent('AlmostOutOfTime');
}
public final function PlayVOEvent(Name EventName)
{
    if ((ActiveBomb != None && ActiveBomb.SimpleDialogPlayer != None) && ActiveBomb.Role == ENetRole.ROLE_Authority)
    {
        ActiveBomb.SimpleDialogPlayer.PlayVOEventRandomLine(EventName);
    }
}
public final function PlayWaveInstructions()
{
    PlayVOEvent('WaveStartedInstructions');
}
public function SetTimeLimit(float TimeLimit)
{
    Super.SetTimeLimit(TimeLimit);
    WaveCoordinator.SetTimer(OperationTimeLimit - OperationTimeWarning, FALSE, 'PlayTimeWarning', Self);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    NumDisarmsRequired = 4
    ActivateNextBombDelay = 3.0
    WaveInstructionVODelay = 4.0
    InstructionReminderDelay = 35.0
    SpawnDistanceIdeal = 3000.0
    SpawnPenaltyLongDistance = 0.200000003
    SpawnPenaltyShortDistance = 0.800000012
}