Class SFXEngagement_Extraction extends SFXWave_Operation
    perobjectconfig
    config(Game);

// Functions
public function CountdownTimerExpired();

public function DistributeObjectiveScore();

public function LocalPlayerTimeWarningHint();


//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    MusicEventName = 'Set_mus_gameplaymode_finalwave'
    srEndWaveFailure = $0
    OperationTimeLimit = 120.0
    OperationTimeLimitBuffer = 0.0
    OperationScoreReward = 0.0
    FinishWaveDelay = 0.0
    SpawnDistanceIdeal = 3500.0
    SpawnPenaltyLongDistance = 0.200000003
    SpawnPenaltyShortDistance = 0.800000012
    bUseObjectiveHud = FALSE
}