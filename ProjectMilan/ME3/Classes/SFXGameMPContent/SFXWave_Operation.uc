Class SFXWave_Operation extends SFXWave
    perobjectconfig
    config(Game);

// Types
struct SFXOperation_ObjectiveSpawnPointData 
{
    var Actor ObjectiveActor;
    var SFXCombatZone CombatZone;
    var Actor AnnexZoneLocation;
};
struct SFXOperation_ObjectiveGroupToSpawn 
{
    var array<SFXOperation_ObjectiveToSpawn> ObjectivesToSpawn;
    var int MinimumObjectivesToSpawn;
    var int MaximumObjectivesToSpawn;
};
struct SFXOperation_ObjectiveToSpawn 
{
    var SFXOperation_ObjectiveData ObjectiveData;
    var bool IsObjectiveAllocatedForSpawn;
};
struct SFXOperation_ObjectiveRequirement 
{
    var config string ObjectiveType;
    var config int MinimumObjectivesRequired;
    var config int MaximumObjectivesAllowed;
};

// Variables
var config array<SFXOperation_ObjectiveRequirement> ObjectivesRequired;
var privatewrite transient array<Actor> ObjectiveActors;
var transient array<SFXOperation_ObjectiveGroupToSpawn> ObjectiveGroupsToSpawn;
var transient array<SFXOperation_ObjectiveSpawnPoint> AvailableSpawnPoints;
var transient array<SFXOperation_ObjectiveSpawnPointData> ObjectiveSpawnPointData;
var config Vector2D CreditBonusTime;
var config Name MusicEventName;
var config float WeightedChanceOfSelection;
var config stringref srBeginWaveMessage;
var config stringref srEndWaveMessage;
var config stringref srEndWaveFailure;
var config stringref srScoreHudObjectiveTitle;
var config stringref srEventTickerString;
var config stringref srWaveFailedHint;
var config float OperationTimeLimit;
var config float OperationTimeWarning;
var config float OperationFirstWarning;
var config float OperationSecondWarning;
var config float OperationTimeLimitBuffer;
var config float CreditBonusTimePct;
var config float OperationScoreReward;
var config float FinishWaveDelay;
var config float SpawnDistanceIdeal;
var config float SpawnPenaltyLongDistance;
var config float SpawnPenaltyShortDistance;
var float WaveInstructionDuration;
var transient float WaveStartedTimestamp;
var transient SFXWaveManager_Operation WaveManager_Operation;
var bool bUseObjectiveHud;
var transient bool SuccessfullySpawnedObjectives;
var transient bool bScoreDistributed;

// Functions
public function bool BeginWave()
{
    local Actor NewActor;
    local int i;
    local int J;
    local int K;
    local int NumObjectivesSelected;
    local array<SFXOperation_ObjectiveSpawnPoint> LocalAvailableSpawnPoints;
    local array<SFXOperation_ObjectiveData> ObjectivesToSpawn;
    local array<SFXOperation_ObjectiveSpawnPoint> ObjectiveSpawnPoints;
    local array<SFXOperation_ObjectiveSpawnPoint> RandomizedSpawnPoints;
    local bool FoundEnoughSpawnsForObjective;
    local Object ObjectTemplate;
    local int AllocateSpawnPointPass;
    local SFXOperation_ObjectiveSpawnPointData ObjectiveSpawnData;
    
    if (!Super.BeginWave())
    {
        return FALSE;
    }
    WaveStartedTimestamp = BioWorldInfo.GameTimeSeconds;
    bScoreDistributed = FALSE;
    if (SFXGRI(BioWorldInfo.GRI).Role == ENetRole.ROLE_Authority)
    {
        LocalAvailableSpawnPoints = AvailableSpawnPoints;
        for (i = 0; i < LocalAvailableSpawnPoints.Length; i++)
        {
            LocalAvailableSpawnPoints[i].DynamicWeight = LocalAvailableSpawnPoints[i].Weight * (float(101) + float(1000) * FRand());
        }
        RandomizedSpawnPoints = LocalAvailableSpawnPoints;
        RandomizedSpawnPoints.Sort(ObjectiveSpawnSort);
        FoundEnoughSpawnsForObjective = TRUE;
        for (i = 0; i < ObjectiveGroupsToSpawn.Length; i++)
        {
            for (J = 0; J < ObjectiveGroupsToSpawn[i].ObjectivesToSpawn.Length; J++)
            {
                ObjectiveGroupsToSpawn[i].ObjectivesToSpawn[J].IsObjectiveAllocatedForSpawn = FALSE;
            }
        }
        for (AllocateSpawnPointPass = 0; AllocateSpawnPointPass < 2; AllocateSpawnPointPass++)
        {
            for (i = 0; i < ObjectiveGroupsToSpawn.Length; i++)
            {
                NumObjectivesSelected = 0;
                for (J = 0; J < ObjectiveGroupsToSpawn[i].ObjectivesToSpawn.Length; J++)
                {
                    if (ObjectiveGroupsToSpawn[i].ObjectivesToSpawn[J].IsObjectiveAllocatedForSpawn)
                    {
                        continue;
                    }
                    for (K = 0; K < RandomizedSpawnPoints.Length; K++)
                    {
                        if (ObjectiveGroupsToSpawn[i].ObjectivesToSpawn[J].ObjectiveData.CanSelectedMeshSpawnAtLocation(RandomizedSpawnPoints[K]))
                        {
                            NumObjectivesSelected++;
                            ObjectivesToSpawn.AddItem(ObjectiveGroupsToSpawn[i].ObjectivesToSpawn[J].ObjectiveData);
                            ObjectiveSpawnPoints.AddItem(RandomizedSpawnPoints[K]);
                            ObjectiveGroupsToSpawn[i].ObjectivesToSpawn[J].IsObjectiveAllocatedForSpawn = TRUE;
                            RandomizedSpawnPoints.Remove(K, 1);
                            K--;
                            break;
                        }
                    }
                    if (AllocateSpawnPointPass == 0 && NumObjectivesSelected >= ObjectiveGroupsToSpawn[i].MinimumObjectivesToSpawn || AllocateSpawnPointPass == 1 && NumObjectivesSelected >= ObjectiveGroupsToSpawn[i].MaximumObjectivesToSpawn)
                    {
                        break;
                    }
                }
                if (AllocateSpawnPointPass == 0 && NumObjectivesSelected < ObjectiveGroupsToSpawn[i].MinimumObjectivesToSpawn)
                {
                    FoundEnoughSpawnsForObjective = FALSE;
                    goto label_0x59A;
                }
            }
        }
label_0x59A:
        if (!FoundEnoughSpawnsForObjective)
        {
            WaveCoordinator.SetTimer(0.100000001, FALSE, 'FinishWave', Self);
            SuccessfullySpawnedObjectives = FALSE;
            return FALSE;
        }
        for (i = 0; i < ObjectivesToSpawn.Length; i++)
        {
            ObjectTemplate = FindObject(ObjectivesToSpawn[i].AssetPath, Class'Object');
            if (Actor(ObjectTemplate) != None)
            {
                NewActor = BioWorldInfo.Spawn(Class<Actor>(ObjectTemplate.Class), BioWorldInfo, , ObjectiveSpawnPoints[i].location, ObjectiveSpawnPoints[i].Rotation, Actor(ObjectTemplate));
            }
            else if (Class<Object>(ObjectTemplate) != None && ClassIsChildOf(Class<Object>(ObjectTemplate), Class'Actor'))
            {
                NewActor = BioWorldInfo.Spawn(Class<Actor>(ObjectTemplate), BioWorldInfo, , ObjectiveSpawnPoints[i].location, ObjectiveSpawnPoints[i].Rotation, , TRUE);
            }
            if (NewActor != None)
            {
                ObjectiveActors.AddItem(NewActor);
                SFXOperationObjective(NewActor).SetOwningWave(Self);
                SFXOperationObjective(NewActor).SetObjectiveData(ObjectivesToSpawn[i]);
                ObjectiveSpawnData.ObjectiveActor = NewActor;
                ObjectiveSpawnData.CombatZone = ObjectiveSpawnPoints[i].CombatZone;
                ObjectiveSpawnData.AnnexZoneLocation = ObjectiveSpawnPoints[i].AnnexZoneLocation;
                ObjectiveSpawnPointData.AddItem(ObjectiveSpawnData);
            }
        }
        SuccessfullySpawnedObjectives = TRUE;
    }
    if (bUseObjectiveHud)
    {
        LocalPlayerController.SetScoreHudObjectiveText(srScoreHudObjectiveTitle);
    }
    WaveCoordinator.SetTimer(1.5, FALSE, 'ShowBeginWaveMessage', Self);
    if (WaveManager_Operation.Role == ENetRole.ROLE_Authority)
    {
        if (OperationTimeLimit != float(0))
        {
            WaveManager_Operation.MatchTimer = int(OperationTimeLimit);
        }
        WaveManager_Operation.SetTimer(60.0, FALSE, 'MatchTimerSync', WaveManager_Operation);
    }
    BeginWaveTimeLimit();
    if (MusicEventName != 'None')
    {
        Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound(MusicEventName);
    }
    return TRUE;
}
public function CancelCountdownTimer()
{
    local SFXPlayerController PC;
    
    if (OperationTimeLimit <= float(0))
    {
        return;
    }
    BioWorldInfo.GetLocalPlayerController().ClearTimer('LocalPlayerTimeWarningHint', Self);
    foreach BioWorldInfo.AllControllers(Class'SFXPlayerController', PC)
    {
        PC.CancelCountdownTimer();
    }
    WaveCoordinator.ClearTimer('CountdownTimerExpired', Self);
    if (WaveManager_Operation.Role == ENetRole.ROLE_Authority)
    {
        WaveManager_Operation.ClearTimer('MatchTimerSync');
    }
}
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
    }
    if (MusicEventName != 'None')
    {
        Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound('Set_mus_gameplaymode_silence');
    }
    Super.FinishWave();
}
public function InitializeWave(SFXWaveManager OwnerManager)
{
    Super.InitializeWave(OwnerManager);
    WaveManager_Operation = SFXWaveManager_Operation(OwnerManager);
    DetermineObjectivesToSpawn();
}
public simulated function PawnDowned(BioPawn Pawn)
{
    local Actor ObjectiveActor;
    local SFXOperationObjective Objective;
    
    foreach ObjectiveActors(ObjectiveActor, )
    {
        Objective = SFXOperationObjective(ObjectiveActor);
        if (Objective != None)
        {
            Objective.PawnDowned(Pawn);
        }
    }
}
public function PawnRevived(BioPawn Pawn)
{
    local Actor ObjectiveActor;
    local SFXOperationObjective Objective;
    
    Super.PawnRevived(Pawn);
    foreach ObjectiveActors(ObjectiveActor, )
    {
        Objective = SFXOperationObjective(ObjectiveActor);
        if (Objective != None)
        {
            Objective.PawnRevived(Pawn);
        }
    }
}
public final function ActivateObjectiveCombatZone(Actor ObjectiveActor)
{
    local int idx;
    local SFXWave_Horde HordeWave;
    local AIController AI;
    
    HordeWave = SFXWave_Horde(WaveCoordinator.GetWaveOfType('SFXWave_Horde'));
    if (HordeWave == None)
    {
        return;
    }
    if (BioWorldInfo != None && BioWorldInfo.Role == ENetRole.ROLE_Authority)
    {
        if (BioWorldInfo.GetAutoBotsEnabled() == TRUE)
        {
            foreach BioWorldInfo.AllControllers(Class'AIController', AI)
            {
                if (int(AI.GetTeamNum()) == int(LocalPlayerController.GetTeamNum()))
                {
                    SFXAI_Core(AI).ObjectiveGoalActor = ObjectiveActor;
                    if (BioCheatManagerNonNative(LocalPlayerController.CheatManager) != None)
                    {
                        BioCheatManagerNonNative(LocalPlayerController.CheatManager).MPBotsDisableTick(BioPawn(AI.Pawn));
                    }
                }
            }
        }
    }
    for (idx = 0; idx < ObjectiveSpawnPointData.Length; idx++)
    {
        if (ObjectiveSpawnPointData[idx].ObjectiveActor == ObjectiveActor)
        {
            HordeWave.EnemySquad.AddCombatZone(ObjectiveSpawnPointData[idx].CombatZone);
            break;
        }
    }
}
public function BeginWaveTimeLimit()
{
    local float TimeLimit;
    
    if (WaveManager_Operation.WaveTimerOverride != 0.0)
    {
        TimeLimit = WaveManager_Operation.WaveTimerOverride - (BioWorldInfo.GameTimeSeconds - WaveManager_Operation.JoinInProgressTimeStamp);
        WaveManager_Operation.WaveTimerOverride = 0.0;
    }
    else
    {
        TimeLimit = OperationTimeLimit;
    }
    SetTimeLimit(TimeLimit);
}
public function CountdownTimerExpired()
{
    srEndWaveMessage = srEndWaveFailure;
    BioWorldInfo.Game.GotoState('MatchOver', , , );
}
public final function DeactivateObjectiveCombatZone(Actor ObjectiveActor)
{
    local int idx;
    local SFXWave_Horde HordeWave;
    local AIController AI;
    
    HordeWave = SFXWave_Horde(WaveCoordinator.GetWaveOfType('SFXWave_Horde'));
    if (HordeWave == None)
    {
        return;
    }
    if (BioWorldInfo != None && BioWorldInfo.Role == ENetRole.ROLE_Authority)
    {
        if (BioWorldInfo.GetAutoBotsEnabled() == TRUE)
        {
            foreach BioWorldInfo.AllControllers(Class'AIController', AI)
            {
                if (int(AI.GetTeamNum()) == int(LocalPlayerController.GetTeamNum()))
                {
                    SFXAI_Core(AI).ObjectiveGoalActor = None;
                }
            }
        }
    }
    for (idx = 0; idx < ObjectiveSpawnPointData.Length; idx++)
    {
        if (ObjectiveSpawnPointData[idx].ObjectiveActor == ObjectiveActor)
        {
            HordeWave.EnemySquad.RemoveCombatZone(ObjectiveSpawnPointData[idx].CombatZone);
            break;
        }
    }
}
public function DelayedFinishWave()
{
    if (OperationTimeLimit > float(0))
    {
        CancelCountdownTimer();
    }
    WaveCoordinator.SetTimer(FinishWaveDelay, FALSE, 'FinishWave', Self);
}
public function DetermineObjectivesToSpawn()
{
    local SFXOperation_ObjectiveData ObjectiveDataIter;
    local SFXOperation_ObjectiveRequirement ObjectiveRequiredIter;
    local int i;
    local bool FoundValidObjective;
    local SFXOperation_ObjectiveGroupToSpawn ObjectiveGroupToSpawn;
    local array<SFXOperation_ObjectiveData> CommonObjectiveData;
    local SFXWaveAssetLoadData NewAssetLoadData;
    local int nRandom;
    local array<EObjectiveLocation> ValidLocations;
    local array<SFXOperation_ObjectiveMeshInfo> ValidMeshes;
    
    ObjectiveGroupsToSpawn.Length = 0;
    CommonObjectiveData.Length = 0;
    foreach ObjectivesRequired(ObjectiveRequiredIter, )
    {
        ObjectiveGroupToSpawn.MinimumObjectivesToSpawn = ObjectiveRequiredIter.MinimumObjectivesRequired;
        ObjectiveGroupToSpawn.MaximumObjectivesToSpawn = ObjectiveRequiredIter.MaximumObjectivesAllowed;
        ObjectiveGroupToSpawn.ObjectivesToSpawn.Length = 0;
        while (ObjectiveGroupToSpawn.ObjectivesToSpawn.Length < ObjectiveRequiredIter.MaximumObjectivesAllowed)
        {
            foreach WaveManager_Operation.ObjectiveData(ObjectiveDataIter, )
            {
                if (ObjectiveDataIter.ObjectiveType == ObjectiveRequiredIter.ObjectiveType)
                {
                    ObjectiveGroupToSpawn.ObjectivesToSpawn.Add(1);
                    ObjectiveGroupToSpawn.ObjectivesToSpawn[ObjectiveGroupToSpawn.ObjectivesToSpawn.Length - 1].ObjectiveData = ObjectiveDataIter;
                    if (CommonObjectiveData.Find(ObjectiveDataIter) == -1)
                    {
                        CommonObjectiveData.AddItem(ObjectiveDataIter);
                    }
                    if (ObjectiveGroupToSpawn.ObjectivesToSpawn.Length >= ObjectiveRequiredIter.MaximumObjectivesAllowed)
                    {
                        break;
                    }
                }
            }
            if (ObjectiveGroupToSpawn.ObjectivesToSpawn.Length == 0)
            {
                break;
            }
        }
        ObjectiveGroupsToSpawn.AddItem(ObjectiveGroupToSpawn);
    }
    AvailableSpawnPoints = WaveManager_Operation.ObjectiveSpawnPoints;
    for (i = 0; i < AvailableSpawnPoints.Length; i++)
    {
        FoundValidObjective = FALSE;
        foreach CommonObjectiveData(ObjectiveDataIter, )
        {
            if (AvailableSpawnPoints[i].IsObjectiveValidForSpawn(ObjectiveDataIter))
            {
                FoundValidObjective = TRUE;
            }
        }
        if (!FoundValidObjective)
        {
            AvailableSpawnPoints.Remove(i, 1);
            i--;
        }
    }
    for (i = 0; i < AvailableSpawnPoints.Length; i++)
    {
        if (ValidLocations.Find(AvailableSpawnPoints[i].SpawnLocation) == -1)
        {
            ValidLocations.AddItem(AvailableSpawnPoints[i].SpawnLocation);
        }
    }
    foreach CommonObjectiveData(ObjectiveDataIter, )
    {
        NewAssetLoadData.AssetToLoad = ObjectiveDataIter.AssetPath;
        AssetLoadData.AddItem(NewAssetLoadData);
        if (SFXGRI(BioWorldInfo.GRI).Role == ENetRole.ROLE_Authority && ObjectiveDataIter.MeshAssets.Length > 0)
        {
            for (i = 0; i < ObjectiveDataIter.MeshAssets.Length; i++)
            {
                if (ValidLocations.Find(ObjectiveDataIter.MeshAssets[i].SpawnLocation) != -1)
                {
                    ValidMeshes.AddItem(ObjectiveDataIter.MeshAssets[i]);
                }
            }
            if (ValidMeshes.Length == 0)
            {
                continue;
            }
            nRandom = Rand(ValidMeshes.Length);
            ObjectiveDataIter.ChosenMeshUniqueString = ValidMeshes[nRandom].UniqueString;
            NewAssetLoadData.AssetToLoad = ValidMeshes[nRandom].MeshPath;
            AssetLoadData.AddItem(NewAssetLoadData);
        }
    }
}
public function DistributeObjectiveScore()
{
    local float fCompletionTime;
    local float fBonusRatio;
    local float fReward;
    local float fBonusReward;
    local int BaseReward;
    local int BonusReward;
    local SFXPlayerController PC;
    local SFXPawn_Player Player;
    local SFXScoreManager ScoreManager;
    local SFXMPEventTicker EventTicker;
    
    if (SFXGRI(BioWorldInfo.GRI) != None)
    {
        ScoreManager = SFXGRI(BioWorldInfo.GRI).GetScoreManager();
        if (ScoreManager == None)
        {
            return;
        }
    }
    if (bScoreDistributed)
    {
        return;
    }
    bScoreDistributed = TRUE;
    fReward = GetCreditsReward();
    fCompletionTime = BioWorldInfo.WorldInfo.GameTimeSeconds - WaveStartedTimestamp;
    fBonusRatio = (FClamp(fCompletionTime, CreditBonusTime.X, CreditBonusTime.Y) - CreditBonusTime.X) / CreditBonusTime.Y;
    fBonusReward = Lerp(CreditBonusTimePct * fReward, 0.0, fBonusRatio);
    BaseReward = int(fReward);
    fReward += fBonusReward;
    fReward = float(Round(fReward));
    fReward -= float(int(fReward) %  25);
    BonusReward = int(fReward) - BaseReward;
    ScoreManager.LastCreditsEarned = BaseReward;
    ScoreManager.LastBonusCreditsEarned = BonusReward;
    foreach BioWorldInfo.AllControllers(Class'SFXPlayerController', PC)
    {
        Player = SFXPawn_Player(PC.Pawn);
        if (Player != None)
        {
            fReward = ScoreManager.AddCredits(Player, fReward);
            if (Player.IsLocallyControlled())
            {
                SFXPlayerController(Player.Controller).HintSystem.AddNotification_CreditRecovery(int(fReward));
                Player.SetTimer(2.5, FALSE, 'ShowCreditsEarnedMessage', ScoreManager);
                if (BonusReward > 0)
                {
                    Player.SetTimer(5.0, FALSE, 'ShowBonusCreditsEarnedMessage', ScoreManager);
                }
            }
        }
    }
    EventTicker = SFXGRI(BioWorldInfo.GRI).GetEventTicker();
    if (EventTicker != None)
    {
        ClearCustomTokens();
        SetCustomToken(0, string(int(fReward)));
        EventTicker.AddTickerEntry(string(srEventTickerString));
        ClearCustomTokens();
    }
}
public function float GetCreditBudget()
{
    return GetCreditsReward() * (1.0 + CreditBonusTimePct);
}
public simulated function float GetCreditsReward()
{
    local float fReward;
    
    fReward = SFXGRI(BioWorldInfo.GRI).DifficultyHandler.GetMinFloat('ObjectiveCreditsReward', 'MPGlobal');
    fReward *= SFXWaveCoordinator_HordeOperation(WaveCoordinator).GetCreditScaling();
    return fReward;
}
public function LocalPlayerTimeWarningHint()
{
    local SFXPlayerController Player;
    local float TimeRemaining;
    
    Player = SFXPlayerController(BioWorldInfo.GetLocalPlayerController());
    if (Player != None && IsActive)
    {
        TimeRemaining = Player.GetRemainingCountdownTime();
        if (TimeRemaining > 25.0 && TimeRemaining < 35.0)
        {
            Player.HintSystem.HintEvent('Objective30Seconds');
        }
    }
}
public function int ObjectiveSpawnSort(SFXOperation_ObjectiveSpawnPoint A, SFXOperation_ObjectiveSpawnPoint B)
{
    if (A.DynamicWeight < B.DynamicWeight)
    {
        return -1;
    }
    return 0;
}
public function float RateEnemyStart(NavigationPoint NavPoint)
{
    local float Rating;
    local float CurrentRating;
    local float Distance;
    local Actor Objective;
    
    Rating = 1.0;
    foreach ObjectiveActors(Objective, )
    {
        Distance = VSize(Objective.location - NavPoint.location);
        if (Distance > SpawnDistanceIdeal)
        {
            CurrentRating = 1.0 - ((Distance - SpawnDistanceIdeal) * SpawnPenaltyLongDistance) / SpawnDistanceIdeal;
            CurrentRating = FClamp(CurrentRating, 1.0 - SpawnPenaltyLongDistance, 1.0);
        }
        if (Distance <= SpawnDistanceIdeal)
        {
            CurrentRating = 1.0 - ((SpawnDistanceIdeal - Distance) * SpawnPenaltyShortDistance) / SpawnDistanceIdeal;
        }
        if (CurrentRating < Rating)
        {
            Rating = CurrentRating;
        }
    }
    Rating = FClamp(Rating, 0.0, 100.0);
    return Rating;
}
public function SetTimeLimit(float TimeLimit)
{
    if (TimeLimit > 0.0)
    {
        SFXPlayerController(BioWorldInfo.GetLocalPlayerController()).BeginCountdownTimer(TimeLimit, OperationTimeWarning);
        BioWorldInfo.GetLocalPlayerController().SetTimer(TimeLimit - 30.0, FALSE, 'LocalPlayerTimeWarningHint', Self);
        WaveCoordinator.SetTimer(OperationTimeLimit + OperationTimeLimitBuffer, FALSE, 'CountdownTimerExpired', Self);
    }
}
public function ShowBeginWaveMessage()
{
    if (srBeginWaveMessage != 0)
    {
        LocalPlayerController.DisplayTextPopup(string(srBeginWaveMessage));
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    CreditBonusTime = {X = 90.0, Y = 150.0}
    MusicEventName = 'Set_mus_gameplaymode_objective'
    srEndWaveFailure = $602479
    srEventTickerString = $664988
    OperationTimeLimit = 301.0
    OperationTimeWarning = 30.0
    OperationTimeLimitBuffer = 1.75
    CreditBonusTimePct = 0.25
    OperationScoreReward = 2000.0
    FinishWaveDelay = 3.0
    WaveInstructionDuration = 8.0
    bUseObjectiveHud = TRUE
}