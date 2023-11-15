Class SFXEngagement_Retrieve extends SFXWave_Operation
    perobjectconfig
    config(Game);

// Variables
var array<SFXPawn_Player> PlayersCarryingObjects;
var array<SFXOperationObjective> DroppedOffPickups;
var config int NumDropOffsRequired;
var config stringref srRetrieveProgress;
var config stringref srPickupDroppedOff;
var config stringref srTeamScoreReward;
var config stringref srObjectiveCompletedReward;

// Functions
public function bool BeginWave()
{
    if (!Super.BeginWave())
    {
        return FALSE;
    }
    DroppedOffPickups.Length = 0;
    PlayersCarryingObjects.Length = 0;
    LocalPlayerController.SetScoreHudObjectiveProgress(0.0);
    if (WaveCoordinator.Role == ENetRole.ROLE_Authority)
    {
        ActivateRandomPickup();
    }
    return TRUE;
}
public function ActivateRandomPickup()
{
    local Actor oActor;
    local SFXOperationObjective ObjectiveActor;
    
    foreach ObjectiveActors(oActor, )
    {
        ObjectiveActor = SFXOperationObjective(oActor);
        if (ObjectiveActor != None && DroppedOffPickups.Find(ObjectiveActor) == -1)
        {
            ObjectiveActor.ActivateObjective();
            break;
        }
    }
}
public function bool IsCarryingPickup(SFXPawn_Player Player)
{
    return PlayersCarryingObjects.Find(Player) != -1;
}
public function PickupDroppedOff(SFXPawn_Player Player, SFXOperationObjective Pickup)
{
    local SFXModule_MarkerObjective Module;
    local Actor ObjectiveActor;
    
    if (Player == None || !IsCarryingPickup(Player) && WaveCoordinator.Role == ENetRole.ROLE_Authority)
    {
        return;
    }
    PlayersCarryingObjects.RemoveItem(Player);
    DroppedOffPickups.AddItem(Pickup);
    UpdateObjectiveStatus();
    SetCustomToken(0, Player.GetHumanReadableName());
    LocalPlayerController.DisplayTextPopup(string(srPickupDroppedOff));
    ClearCustomTokens();
    if (DroppedOffPickups.Length < NumDropOffsRequired)
    {
        ActivateRandomPickup();
    }
    else
    {
        foreach ObjectiveActors(ObjectiveActor, )
        {
            Module = ObjectiveActor.GetModule(Class'SFXModule_MarkerObjective');
            if (Module != None)
            {
                Module.Deactivate();
            }
        }
        DelayedFinishWave();
    }
}
public function PlayerDroppedObject(SFXPawn_Player Player)
{
    if (Player != None)
    {
        PlayersCarryingObjects.RemoveItem(Player);
    }
}
public function PlayerPickedUpObject(SFXPawn_Player Player)
{
    if (Player != None && !IsCarryingPickup(Player))
    {
        PlayersCarryingObjects.AddItem(Player);
    }
}
public function UpdateObjectiveStatus()
{
    LocalPlayerController.SetScoreHudObjectiveProgress(float(DroppedOffPickups.Length) / float(NumDropOffsRequired));
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}