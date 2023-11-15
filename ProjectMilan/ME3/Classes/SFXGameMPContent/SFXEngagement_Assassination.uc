Class SFXEngagement_Assassination extends SFXWave_Operation
    perobjectconfig
    config(Game);

// Variables
var config float WaveInstructionVODelay;

// Functions
public function PawnDied(BioPawn Pawn, optional BioPawn Killer = None)
{
    local SFXObjective_AssassinationBase ObjActor;
    
    if (Pawn == None)
    {
        return;
    }
    if (WaveCoordinator.Role == ENetRole.ROLE_Authority)
    {
        ObjActor = GetAssassinationObjective();
        if (ObjActor != None && Pawn == ObjActor.CurrentTarget)
        {
            ObjActor.CurrentTargetDied();
        }
    }
}
public function bool BeginWave()
{
    if (!Super.BeginWave())
    {
        return FALSE;
    }
    OperationTimeLimit = 0.0;
    if (WaveCoordinator.Role == ENetRole.ROLE_Authority)
    {
        WaveCoordinator.SetTimer(2.0, FALSE, 'ChooseAssassinationTarget', Self);
        SFXWaveCoordinator_HordeOperation(WaveCoordinator).PlayAssassinationVOEvent('Assassination_MissionIntro');
        WaveCoordinator.SetTimer(WaveInstructionVODelay, FALSE, 'PlayWaveStartedInstructionsVO', Self);
    }
    LocalPlayerController.SetScoreHudObjectiveProgress(0.0);
    return TRUE;
}
public function FinishWave()
{
    local SFXObjective_AssassinationBase ObjActor;
    
    ObjActor = GetAssassinationObjective();
    if ((ObjActor != None && ObjActor.Role == ENetRole.ROLE_Authority) && ObjActor.NumTargetsKilled < ObjActor.NumTargetsToKill)
    {
        SFXWaveCoordinator_HordeOperation(WaveCoordinator).PlayAssassinationVOEvent('Assassination_MissionFailed');
        Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound('MPAssassinationFail');
    }
    Super.FinishWave();
    WaveCoordinator.ClearTimer('ChooseAssassinationTarget');
}
public function PawnSpawned(BioPawn Pawn)
{
    local SFXObjective_AssassinationBase ObjActor;
    
    if (Pawn == None || Pawn.GetTeam().TeamIndex == 0)
    {
        return;
    }
    if (WaveCoordinator.Role == ENetRole.ROLE_Authority)
    {
        ObjActor = GetAssassinationObjective();
        if (((ObjActor != None && ObjActor.CurrentTarget == None) && ObjActor.NumTargetsKilled > 0) && ObjActor.NumTargetsKilled < ObjActor.NumTargetsToKill)
        {
            SetAssassinationTarget(Pawn);
        }
    }
}
public final function ChooseAssassinationTarget()
{
    local SFXWave_Horde HordeWave;
    local Pawn BestEnemy;
    local int HighestValue;
    local int idx;
    
    HordeWave = SFXWave_Horde(WaveCoordinator.GetWaveOfType('SFXWave_Horde'));
    if (HordeWave != None)
    {
        for (idx = 0; idx < HordeWave.EnemiesSpawned.Length; idx++)
        {
            if (HordeWave.EnemiesSpawned[idx].Enemy != None && HordeWave.EnemiesSpawned[idx].Enemy.IsAliveAndWell())
            {
                if (HordeWave.EnemyList[HordeWave.EnemiesSpawned[idx].IndexInEnemyList].WaveCost > HighestValue)
                {
                    BestEnemy = HordeWave.EnemiesSpawned[idx].Enemy;
                    HighestValue = HordeWave.EnemyList[HordeWave.EnemiesSpawned[idx].IndexInEnemyList].WaveCost;
                }
            }
        }
    }
    if (BestEnemy != None)
    {
        SetAssassinationTarget(BioPawn(BestEnemy));
    }
    else
    {
        WaveCoordinator.SetTimer(0.5, FALSE, 'ChooseAssassinationTarget', Self);
    }
}
public final function SFXObjective_AssassinationBase GetAssassinationObjective()
{
    if (ObjectiveActors.Length > 0)
    {
        return SFXObjective_AssassinationBase(ObjectiveActors[0]);
    }
    return None;
}
private final function PlayWaveStartedInstructionsVO()
{
    local float VODuration;
    
    VODuration = SFXWaveCoordinator_HordeOperation(WaveCoordinator).PlayAssassinationVOEvent('Assassination_BasicGoal');
    GetAssassinationObjective().PlayPlayerAcknowledgment(VODuration + 0.5, TRUE);
}
public final function SetAssassinationTarget(BioPawn Pawn)
{
    local SFXObjective_AssassinationBase ObjActor;
    
    if (Pawn == None)
    {
        return;
    }
    if (WaveCoordinator.Role == ENetRole.ROLE_Authority)
    {
        ObjActor = GetAssassinationObjective();
        if (ObjActor != None)
        {
            ObjActor.SetCurrentTarget(Pawn);
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}