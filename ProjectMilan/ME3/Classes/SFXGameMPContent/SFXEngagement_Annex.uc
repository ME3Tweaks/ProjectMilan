Class SFXEngagement_Annex extends SFXWave_Operation
    perobjectconfig
    config(Game);

// Variables
var array<SFXPawn_Player> PlayersInAnnexZone;
var config stringref srAnnexProgressTicker;
var config stringref srAnnexProgressTickerPlural;

// Functions
public function FinishWave()
{
    local Actor ObjectiveActor;
    local SFXOperationObjective Objective;
    
    Super.FinishWave();
    foreach ObjectiveActors(ObjectiveActor, )
    {
        Objective = SFXOperationObjective(ObjectiveActor);
        if (Objective != None)
        {
            Objective.ClearTimer('CountdownTimerFirstWarning');
            Objective.ClearTimer('CountdownTimerSecondWarning');
            Objective.ClearTimer('CountdownTimerFailedMessage');
        }
    }
}
public function Vector GetAnnexZoneLocation(SFXOperationObjective ObjectiveActor)
{
    local int idx;
    
    if (ObjectiveActor == None)
    {
        return vect(0.0, 0.0, 0.0);
    }
    for (idx = 0; idx < ObjectiveSpawnPointData.Length; idx++)
    {
        if (ObjectiveSpawnPointData[idx].ObjectiveActor == ObjectiveActor && ObjectiveSpawnPointData[idx].AnnexZoneLocation != None)
        {
            return ObjectiveSpawnPointData[idx].AnnexZoneLocation.location;
        }
    }
    return ObjectiveActor.location;
}
public function SetTimeLimit(float TimeLimit)
{
    local Actor ObjectiveActor;
    local SFXOperationObjective Objective;
    
    Super.SetTimeLimit(TimeLimit);
    if (TimeLimit > 0.0)
    {
        foreach ObjectiveActors(ObjectiveActor, )
        {
            Objective = SFXOperationObjective(ObjectiveActor);
            if (Objective != None)
            {
                Objective.SetTimer(OperationFirstWarning, FALSE, 'CountdownTimerFirstWarning', Objective);
                Objective.SetTimer(OperationSecondWarning, FALSE, 'CountdownTimerSecondWarning', Objective);
                Objective.SetTimer(TimeLimit, FALSE, 'CountdownTimerFailedMessage', Objective);
            }
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    OperationFirstWarning = 30.0
    OperationSecondWarning = 240.0
    SpawnDistanceIdeal = 2500.0
    SpawnPenaltyLongDistance = 0.600000024
    SpawnPenaltyShortDistance = 0.400000006
}