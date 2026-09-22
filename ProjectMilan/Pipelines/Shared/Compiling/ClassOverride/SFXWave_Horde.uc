// MILAN CHANGE - 09/21/2026 - Mgamerz
// Enable dyanmic wavelists
Class SFXWave_Horde extends SFXWave
    perobjectconfig
    abstract
    config(Game);

struct DifficultyLevelEnemies 
{
    var array<EnemyWaveInfo> Enemies;
    var EDifficultyOptions Difficulty;
};
struct BerserkStartCount 
{
    var int EnemiesLeft;
    var EDifficultyOptions Difficulty;
};
struct PetData 
{
    var Name className;
    var int WaveCost;
};
struct SpawnedEnemy 
{
    var Pawn Enemy;
    var int IndexInEnemyList;
};
struct EnemySquadInfo 
{
    var array<Name> EnemyTypes;
    var int WaveCost;
};
struct EnemySpawnInfo 
{
    var biodynamicload string EnemyArchetypeName;
    var Name EnemyType;
    var Pawn EnemyArchetype;
    var int WaveCost;
};

var config array<EnemySpawnInfo> EnemyList;
var config array<PetData> PetList;
var config array<EnemySquadInfo> EnemySquadList;
var config array<BerserkStartCount> BerserkStartCounts;
var config array<DifficultyLevelEnemies> Enemies;
var array<int> Squads;
var array<SpawnedEnemy> EnemiesSpawned;
var array<int> AliveEnemiesByType;
var array<int> NumSpawnedEnemiesByType;
var config float SpawnDelay;
var config int WaveIndex;
var config int WavePoints;
var config float SquadChance;
var config int MinPlayersToSpawnSquad;
var BioBaseSquad EnemySquad;
var int CurrentWave;
var int WavePointsRemaining;
var int CurrentSquadIndex;
var int NextSquadEnemyIndex;
var NavigationPoint LastEnemyNavPoint;
var transient SFXEnemySpawnPoint CurrentEnemySpawnPoint;
var int CurrentEnemySpawnPointCount;
var config int MaxEnemiesPerSpawnPoint;
var config int MaxEnemies;
var const stringref srWaveNumber;
var const stringref SrEnemiesAlive;
var config float SpawnPenaltyOnTop;
var config float SpawnPenaltyLineOfSight;
var config float SpawnPenaltyLineOfSightMaxDist;
var config float SpawnDistancePenaltyClose;
var config float SpawnRandomVariance;
var config float SpawnDesignerWeightMultiplier;
var config float SpawnDistanceClose;
var config float SpawnBaseRating;
var config float SpawnMinRatingForRespawn;
var config int EnemiesRemainingToActivateObjective;
var config float EnemyObjectiveMarkerDelay;
var config int DamageReductionTimerOnSpawnIn;
var transient float EndOfRoundSpeedBonus;
var config float WavePointsToBudget;
var bool EndlessWave;
var transient bool bEndRushTriggered;
var config bool DisplayObjectivesForAllEnemies;
var transient bool bWaveIsOver;

public final function int GetPlayerCount()
{
    local SFXPlayerController PC;
    local int PlayerCount;
    
    foreach BioWorldInfo.AllControllers(Class'SFXPlayerController', PC)
    {
        PlayerCount++;
    }
    return PlayerCount;
}
public function PawnDied(BioPawn Pawn, optional BioPawn Killer = None)
{
    local int EnemyIndex;
    local int i;
    local SFXModule_MarkerObjective ObjectiveModule;
    
    if (!IsActive)
    {
        return;
    }
    if (SFXPawn_Player(Pawn) != None)
    {
        return;
    }
    EnemyIndex = -1;
    for (i = 0; i < EnemiesSpawned.Length; i++)
    {
        if (EnemiesSpawned[i].Enemy == Pawn)
        {
            EnemyIndex = EnemiesSpawned[i].IndexInEnemyList;
            EnemiesSpawned.Remove(i, 1);
            break;
        }
    }
    if (EnemyIndex == -1)
    {
        return;
    }
    AliveEnemiesByType[EnemyIndex]--;
    TriggerEnemyKilledEvent(Pawn, Killer);
    BioWorldInfo.ShowDebugMessage(Killer.PlayerReplicationInfo.PlayerName $ " killed " $ Pawn);
    UpdateObjectiveStatus();
    ObjectiveModule = Pawn.GetModule(Class'SFXModule_MarkerObjective');
    if (ObjectiveModule != None)
    {
        ObjectiveModule.Deactivate();
    }
    if (EnemyBudgetRemaining())
    {
        WaveCoordinator.SetTimer(SpawnDelay, FALSE, 'SpawnHorde', Self);
    }
    if (!EnemyBudgetRemaining() || !WaveCoordinator.IsTimerActive('SpawnHorde', Self))
    {
        if (EnemiesSpawned.Length == 0 || AreRemainingEnemiesOnMyTeam())
        {
            TriggerWaveEndEvent(CurrentWave);
            FinishWave();
        }
        else if (!bEndRushTriggered)
        {
            i = BerserkStartCounts.Find('Difficulty', SFXGRI(BioWorldInfo.GRI).DifficultyHandler.CurrentDifficulty);
            if (i != -1 && EnemiesSpawned.Length <= BerserkStartCounts[i].EnemiesLeft)
            {
                bEndRushTriggered = TRUE;
                for (i = 0; i < EnemiesSpawned.Length; i++)
                {
                    if (EnemiesSpawned[i].Enemy != None && SFXAI_Core(EnemiesSpawned[i].Enemy.Controller) != None)
                    {
                        SFXAI_Core(EnemiesSpawned[i].Enemy.Controller).SetCombatMood(5);
                    }
                }
            }
        }
    }
}
// MILAN CHANGE
// Use replicated composition to determine which assets to preload
public function bool BeginWave()
{
    local int i;
    local int Index;
    local ReplicatedArchetypeEntry ArchetypeEntry;
    local SFXWaveAssetLoadData NewAssetLoadData;
    local SFXWaveCoordinator_HordeOperation Coord;

    Coord = SFXWaveCoordinator_HordeOperation(WaveCoordinator);
    if (Coord.ReplicatedComposition.Types.Length == 0)
    {
        if (BioWorldInfo != None && BioWorldInfo.Role == ENetRole.ROLE_Authority)
        {
            Coord.PublishEnemyComposition(Self);
        }
        if (Coord.ReplicatedComposition.Types.Length == 0)
        {
            // not generated yet (server) or not yet received (client) - try again shortly.
            // OnAllWavesFinishedLoading()/BeginWave() only fires ~BetweenWaveDelay (10s)
            // after StartNewWave() replicated ReplicatedWaveEventInfo, so there is ample
            // margin for ReplicatedComposition to have already arrived by the time this
            // ever actually needs to retry.
            WaveCoordinator.SetTimer(0.1, FALSE, 'BeginWave', Self);
            return FALSE;
        }
        // composition just became available this tick - queue its assets for async loading
        foreach Coord.ReplicatedComposition.Archetypes(ArchetypeEntry, )
        {
            NewAssetLoadData.AssetToLoad = ArchetypeEntry.EnemyArchetypeName;
            AssetLoadData.AddItem(NewAssetLoadData);
        }
        BeginLoading();
    }
    // END MILAN CHANGE
    if (!Super.BeginWave())
    {
        return FALSE;
    }
    bWaveIsOver = FALSE;
    EndOfRoundSpeedBonus = 0.0;
    WavePointsRemaining = WavePoints;
    CurrentSquadIndex = -1;
    NextSquadEnemyIndex = -1;
    if (BioWorldInfo != None && BioWorldInfo.Game != None && BioWorldInfo.Role == ENetRole.ROLE_Authority)
    {
        if (BioWorldInfo.GetAutoBotsEnabled() == TRUE)
        {
            if (!WaveCoordinator.IsTimerActive('StartAutoBots', Self))
            {
                WaveCoordinator.SetTimer(1.0, TRUE, 'StartAutoBots', Self);
            }
        }
        EnemySquad = SFXGame(BioWorldInfo.Game).SpawnEnemySquad();
        WaveCoordinator.SetTimer(SpawnDelay, FALSE, 'SpawnHorde', Self);
    }
    LocalPlayerController.SetScoreHudObjectiveText($0);
    for (i = 0; i < EnemyList.Length; i++)
    {
        Index = AssetLoadData.Find('AssetToLoad', EnemyList[i].EnemyArchetypeName);
        if (Index != -1)
        {
            EnemyList[i].EnemyArchetype = Pawn(FindObject(EnemyList[i].EnemyArchetypeName, Class'Pawn'));
            BioPawn(EnemyList[i].EnemyArchetype).@Class.static.PrecacheVFX(SFXGRI(BioWorldInfo.GRI).ObjectPool, Class'RvrClientEffectManager'.static.GetClientEffectManager());
        }
        // MILAN CHANGE
        else
        {

            WarnInternal("Asset wasn't found for vfx precache: " $ EnemyList[i].EnemyArchetypeName);
        }
        // END MILAN CHANGE
    }
    TriggerWaveStartEvent(CurrentWave);
    return TRUE;
}
public function FinishWave()
{
    local BioPawn Enemy;
    local SFXGRI GRI;
    
    GRI = SFXGRI(BioWorldInfo.GRI);
    EndlessWave = FALSE;
    if (BioWorldInfo != None && BioWorldInfo.Role == ENetRole.ROLE_Authority && GRI != None && GRI.NumLivingPlayers() > 0 && !GRI.IsGameOver())
    {
        while (EnemiesSpawned.Length > 0)
        {
            Enemy = BioPawn(EnemiesSpawned[0].Enemy);
            if (Enemy != None)
            {
                Enemy.Died(Enemy.Controller, Class'SFXDamageType_CheatKill', Enemy.location);
            }
            if (EnemiesSpawned.Length > 0 && EnemiesSpawned[0].Enemy == Enemy)
            {
                EnemiesSpawned.Remove(0, 1);
            }
        }
        AliveEnemiesByType.Remove(0, AliveEnemiesByType.Length);
        AliveEnemiesByType.Length = EnemyList.Length;
        NumSpawnedEnemiesByType.Remove(0, NumSpawnedEnemiesByType.Length);
        NumSpawnedEnemiesByType.Length = EnemyList.Length;
    }
    Super.FinishWave();
}

// MILAN CHANGE - AssetLoadData is moved to different function
public function InitializeWave(SFXWaveManager OwnerManager)
{
    local int i;
    local Name EnemyTypeIter;

    Super.InitializeWave(OwnerManager);
    LogInternal("Initializing wave", );
    bWaveIsOver = FALSE;
    AliveEnemiesByType.Length = EnemyList.Length;
    NumSpawnedEnemiesByType.Length = EnemyList.Length;
    EnemiesSpawned.Length = 0;
    for (i = 0; i < EnemySquadList.Length; i++)
    {
        EnemySquadList[i].WaveCost = 0;
        foreach EnemySquadList[i].EnemyTypes(EnemyTypeIter, )
        {
            EnemySquadList[i].WaveCost += GetEnemySpawnInfoForEnemyType(EnemyTypeIter).WaveCost;
        }
    }
    if (BioWorldInfo != None && BioWorldInfo.Role == ENetRole.ROLE_Authority)
    {
        if (BioWorldInfo.GetAutoBotsEnabled() == TRUE)
        {
            StartAutoBots();
        }
    }
}
public function PawnRevived(BioPawn Pawn)
{
    local SFXModule_GameEffectManager Manager;
    
    Super.PawnRevived(Pawn);
    Manager = Pawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        Manager.CreateAndApplyEffect(Class'SFXGameEffect_DamageTakenBonus', 'SpawnInBonus', float(DamageReductionTimerOnSpawnIn / 3), 1, -0.899999976, Pawn.Controller);
        Manager.CreateAndApplyEffect(Class'SFXGameEffect_DamageTakenBonus', 'SpawnInBonus', float(DamageReductionTimerOnSpawnIn), 1, -0.5, Pawn.Controller);
    }
}
public function ActivateEnemyObjectiveMarkers()
{
    local int i;
    local SFXModule_MarkerObjective ObjectiveModule;
    
    for (i = 0; i < EnemiesSpawned.Length; i++)
    {
        ObjectiveModule = EnemiesSpawned[i].Enemy.GetModule(Class'SFXModule_MarkerObjective');
        if (ObjectiveModule == None)
        {
            ObjectiveModule = new (EnemiesSpawned[i].Enemy) Class'SFXModule_MarkerObjective';
            ObjectiveModule.MarkerLabel = $0;
            ObjectiveModule.MarkerIconType = EObjectiveMarkerIconType.EOMIT_Attack;
            EnemiesSpawned[i].Enemy.AddSFXModule(ObjectiveModule);
        }
        ObjectiveModule.Activate();
    }
    SFXWaveCoordinator_HordeOperation(WaveCoordinator).OnSingleEnemyRemaining();
}
public function bool AreRemainingEnemiesOnMyTeam()
{
    local int i;
    
    for (i = 0; i < EnemiesSpawned.Length; i++)
    {
        if (EnemiesSpawned[i].Enemy.GetTeam().TeamIndex != 0)
        {
            return FALSE;
        }
    }
    return TRUE;
}
public final function int CalculateSpawnedEnemyCost()
{
    local SpawnedEnemy SpawnedEnemyIter;
    local int ToRet;
    
    ToRet = 0;
    foreach EnemiesSpawned(SpawnedEnemyIter, )
    {
        ToRet += EnemyList[SpawnedEnemyIter.IndexInEnemyList].WaveCost;
    }
    return ToRet;
}
public final function bool CanEnemyUseSpawnPoint(Class<BioPawn> EnemyClass, float EnemyRadius, float EnemyHeight, NavigationPoint NavPoint)
{
    local SFXEnemySpawnPoint SpawnPoint;
    local Class<SFXCustomReachSpec> ReachSpecClass;
    local int ReachSpecCount;
    local int ReachSpecIndex;
    local int CustomActionCount;
    local int CustomActionIndex;
    
    if (EnemyClass == None)
    {
        return FALSE;
    }
    if (NavPoint == None || NavPoint.bBlocked)
    {
        return FALSE;
    }
    if (NavPoint.MaxPathSize.Radius < EnemyRadius || NavPoint.MaxPathSize.Height < EnemyHeight)
    {
        return FALSE;
    }
    SpawnPoint = SFXEnemySpawnPoint(NavPoint);
    if (SpawnPoint == None)
    {
        SpawnPoint = CurrentEnemySpawnPoint;
    }
    if (SpawnPoint == None)
    {
        return TRUE;
    }
    ReachSpecCount = SpawnPoint.SupportedReachSpecs.Length;
    if (ReachSpecCount > 0)
    {
        for (ReachSpecIndex = 0; ReachSpecIndex < ReachSpecCount; ReachSpecIndex++)
        {
            ReachSpecClass = SpawnPoint.SupportedReachSpecs[ReachSpecIndex];
            if (ReachSpecClass != None)
            {
                if (EnemyClass.default.SupportedCustomReachSpecs.Find(ReachSpecClass) != -1)
                {
                    return TRUE;
                }
            }
        }
    }
    else
    {
        CustomActionCount = SpawnPoint.SupportedCustomActions.Length;
        if (CustomActionCount > 0)
        {
            for (CustomActionIndex = 0; CustomActionIndex < CustomActionCount; CustomActionIndex++)
            {
                if (EnemyClass.default.CustomActionClasses[int(SpawnPoint.SupportedCustomActions[CustomActionIndex])] != None)
                {
                    return TRUE;
                }
            }
        }
        else
        {
            return TRUE;
        }
    }
    return FALSE;
}
public final function NavigationPoint ChooseEnemyStart(Class<Pawn> EnemyClass)
{
    local float EnemyRadius;
    local float EnemyHeight;
    local int i;
    local SFXEnemySpawnPoint SpawnPoint;
    local NavigationPoint BestStart;
    local float Rating;
    local float BestRating;
    local SFXWaveManager_Horde HordeManager;
    
    EnemyRadius = EnemyClass.default.CylinderComponent.CollisionRadius;
    EnemyHeight = EnemyClass.default.CylinderComponent.CollisionHeight;
    BestStart = None;
    Rating = 0.0;
    BestRating = 0.0;
    if (CurrentEnemySpawnPoint != None && CurrentEnemySpawnPointCount < MaxEnemiesPerSpawnPoint)
    {
        if (LastEnemyNavPoint != None)
        {
            for (i = 0; i < LastEnemyNavPoint.PathList.Length; i++)
            {
                if (SFXCustomReachSpec(LastEnemyNavPoint.PathList[i]) == None && LastEnemyNavPoint.PathList[i].End.Actor != None)
                {
                    Rating = RateEnemyStart(NavigationPoint(LastEnemyNavPoint.PathList[i].End.Actor), EnemyRadius, EnemyHeight, EnemyClass, TRUE);
                    if (Rating > BestRating)
                    {
                        BestRating = Rating;
                        BestStart = NavigationPoint(LastEnemyNavPoint.PathList[i].End.Actor);
                    }
                }
            }
            if (BestRating > SpawnMinRatingForRespawn)
            {
                return BestStart;
            }
        }
    }
    HordeManager = SFXWaveManager_Horde(WaveManager);
    foreach HordeManager.EnemySpawnPoints(SpawnPoint, )
    {
        if (SpawnPoint == CurrentEnemySpawnPoint)
        {
            continue;
        }
        Rating = RateEnemyStart(SpawnPoint, EnemyRadius, EnemyHeight, EnemyClass, TRUE);
        if (Rating > BestRating)
        {
            BestRating = Rating;
            BestStart = SpawnPoint;
        }
    }
    CurrentEnemySpawnPoint = SFXEnemySpawnPoint(BestStart);
    CurrentEnemySpawnPointCount = 0;
    return BestStart;
}
public final function int ChooseEnemyToSpawn()
{
    local int Index;
    local int i;
    local int EnemyIndex;
    local int MaxCount;
    local int MinCount;
    local array<int> ValidChoices;
    local array<EnemyWaveInfo> EnemiesToSpawn;
    
    Index = -1;
    if (CurrentSquadIndex != -1)
    {
        Index = EnemyList.Find('EnemyType', EnemySquadList[CurrentSquadIndex].EnemyTypes[NextSquadEnemyIndex]);
        NextSquadEnemyIndex++;
        if (NextSquadEnemyIndex >= EnemySquadList[CurrentSquadIndex].EnemyTypes.Length)
        {
            CurrentSquadIndex = -1;
            NextSquadEnemyIndex = -1;
        }
    }
    else
    {
        GetEnemyArray(EnemiesToSpawn);
        for (i = 0; i < EnemiesToSpawn.Length; i++)
        {
            EnemyIndex = EnemyList.Find('EnemyType', EnemiesToSpawn[i].EnemyType);
            if (EnemiesToSpawn[i].MaxPerWave > 0 && NumSpawnedEnemiesByType[EnemyIndex] >= EnemiesToSpawn[i].MaxPerWave)
            {
                continue;
            }
            if (EndlessWave || WavePointsRemaining >= EnemyList[EnemyIndex].WaveCost)
            {
                MaxCount = EnemiesToSpawn[i].MaxCount;
                if (MaxCount == 0 || AliveEnemiesByType[EnemyIndex] < MaxCount)
                {
                    MinCount = EnemiesToSpawn[i].MinCount;
                    if (MinCount > 0 && AliveEnemiesByType[EnemyIndex] < MinCount)
                    {
                        ValidChoices.Length = 1;
                        ValidChoices[0] = EnemyIndex;
                        break;
                        continue;
                    }
                    ValidChoices.AddItem(EnemyIndex);
                }
            }
        }
        if (ValidChoices.Length > 0)
        {
            Index = ValidChoices[Rand(ValidChoices.Length)];
        }
    }
    return Index;
}
public final function bool ChooseSquadToSpawn()
{
    local int i;
    local array<int> ValidChoices;
    
    for (i = 0; i < Squads.Length; i++)
    {
        if (WavePointsRemaining >= EnemySquadList[Squads[i]].WaveCost)
        {
            ValidChoices.AddItem(Squads[i]);
        }
    }
    if (ValidChoices.Length > 0)
    {
        CurrentSquadIndex = Rand(ValidChoices.Length);
        NextSquadEnemyIndex = 0;
        return TRUE;
    }
    return FALSE;
}
public final function bool EnemyBudgetRemaining()
{
    return EndlessWave || WavePointsRemaining > 0;
}
public function int GetCreatureWaveCost(Pawn P)
{
    local int idx;
    
    for (idx = 0; idx < EnemyList.Length; idx++)
    {
        if (EnemyList[idx].EnemyArchetype != None && EnemyList[idx].EnemyArchetype.@Class == P.@Class)
        {
            return EnemyList[idx].WaveCost;
        }
    }
    for (idx = 0; idx < PetList.Length; idx++)
    {
        if (PetList[idx].className == P.@Class.Name)
        {
            return PetList[idx].WaveCost;
        }
    }
    return 0;
}
// MILAN CHANGE
// Client-facing (and technically server) ALWAYS reads the
// host-authoritative replicated composition, never this machine's own local perobjectconfig
// data. This is what ChooseEnemyToSpawn() uses to determine spawns.

public function GetEnemyArray(out array<EnemyWaveInfo> EnemyArray)
{
    local Name TypeName;
    local EnemyWaveInfo Info;

    EnemyArray.Length = 0;
    foreach SFXWaveCoordinator_HordeOperation(WaveCoordinator).ReplicatedComposition.Types(TypeName, )
    {
        Info.EnemyType = TypeName;
        Info.MinCount = 0;
        Info.MaxCount = 0;
        Info.MaxPerWave = 0;
        EnemyArray.AddItem(Info);
    }
}
// END MILAN CHANGE

// Note: The original GetEnemyArray() was renamed to GetLocalEnemyArray() and runs serverside
public function GetLocalEnemyArray(out array<EnemyWaveInfo> EnemyArray)
{
    local int idx;
    local int HighestDiff;
    local int HighestIdx;
    
    if (Enemies.Length == 0)
    {
        return;
    }
    idx = Enemies.Find('Difficulty', SFXGRI(BioWorldInfo.GRI).DifficultyHandler.CurrentDifficulty);
    if (idx != -1)
    {
        EnemyArray = Enemies[idx].Enemies;
    }
    else
    {
        for (idx = 0; idx < Enemies.Length; idx++)
        {
            if (int(Enemies[idx].Difficulty) >= HighestDiff)
            {
                HighestIdx = idx;
                HighestDiff = int(Enemies[idx].Difficulty);
            }
        }
        EnemyArray = Enemies[HighestIdx].Enemies;
    }
}
public final function EnemySpawnInfo GetEnemySpawnInfoForEnemyType(Name EnemyType)
{
    local int Index;
    
    Index = EnemyList.Find('EnemyType', EnemyType);
    return EnemyList[Index];
}
public function float GetScoreBudget()
{
    return float(WavePoints) * WavePointsToBudget;
}
public final function float RateEnemyStart(NavigationPoint NavPoint, float EnemyRadius, float EnemyHeight, Class<Pawn> EnemyClass, bool bDoTraceCheck)
{
    local float Rating;
    local float Penalty;
    local float Distance;
    local SFXPlayerController PC;
    local SFXEnemySpawnPoint SpawnPoint;
    local SFXWave_Operation ActiveOperationWave;
    local Vector LineOfSight_EnemyHead;
    local Vector LineOfSight_PlayerHead;
    
    if (CanEnemyUseSpawnPoint(Class<BioPawn>(EnemyClass), EnemyRadius, EnemyHeight, NavPoint) == FALSE)
    {
        return -1.0;
    }
    Rating = SpawnBaseRating + SpawnBaseRating * SpawnRandomVariance * FRand();
    ActiveOperationWave = SFXWave_Operation(WaveCoordinator.GetWaveOfType('SFXWave_Operation'));
    if (ActiveOperationWave != None)
    {
        Rating = Rating * ActiveOperationWave.RateEnemyStart(NavPoint);
    }
    LineOfSight_EnemyHead = NavPoint.location;
    LineOfSight_EnemyHead.Z += EnemyHeight;
    foreach BioWorldInfo.AllControllers(Class'SFXPlayerController', PC)
    {
        if (PC.Pawn != None && PC.Pawn.CylinderComponent != None)
        {
            Distance = VSize(PC.Pawn.location - NavPoint.location);
            if (Distance < float(2) * (PC.Pawn.CylinderComponent.CollisionRadius + PC.Pawn.CylinderComponent.CollisionHeight))
            {
                Rating -= SpawnBaseRating * SpawnPenaltyOnTop;
            }
            else if (Distance < SpawnDistanceClose)
            {
                Penalty = (SpawnDistanceClose - Distance) * SpawnDistancePenaltyClose / SpawnDistanceClose;
                Rating -= SpawnBaseRating * Penalty;
            }
            LineOfSight_PlayerHead = PC.Pawn.location;
            LineOfSight_PlayerHead.Z += PC.Pawn.default.CylinderComponent.CollisionHeight;
            if (bDoTraceCheck && Distance < SpawnPenaltyLineOfSightMaxDist && BioWorldInfo.FastTrace(LineOfSight_EnemyHead, LineOfSight_PlayerHead, , ))
            {
                Penalty = (SpawnPenaltyLineOfSightMaxDist - Distance) * SpawnPenaltyLineOfSight / SpawnPenaltyLineOfSightMaxDist;
                Rating -= SpawnBaseRating * Penalty;
            }
        }
    }
    SpawnPoint = SFXEnemySpawnPoint(NavPoint);
    if (SpawnPoint == None)
    {
        SpawnPoint = CurrentEnemySpawnPoint;
    }
    if (SpawnPoint != None)
    {
        if (SpawnPoint.Weight > float(1))
        {
            Rating += (SpawnPoint.Weight - float(1)) * SpawnDesignerWeightMultiplier * SpawnBaseRating;
        }
        else
        {
            Rating += SpawnPoint.Weight * SpawnDesignerWeightMultiplier * SpawnBaseRating;
        }
    }
    return FMax(Rating, 1.0);
}
public final function SetEndlessWaves(bool Endless)
{
    EndlessWave = Endless;
}
public final function bool ShouldSpawnSquad()
{
    if (GetPlayerCount() >= MinPlayersToSpawnSquad && CurrentSquadIndex == -1 && FRand() < SquadChance)
    {
        return TRUE;
    }
    return FALSE;
}
public final function SpawnEnemy(int Index)
{
    local NavigationPoint StartSpot;
    local Class<Pawn> PawnClass;
    local Class<AIController> ControllerClass;
    local Pawn Enemy;
    local SFXAI_Core AI;
    
    if (Index < 0 || Index >= EnemyList.Length)
    {
        WavePointsRemaining = 0;
        EndlessWave = FALSE;
        return;
    }
    PawnClass = EnemyList[Index].EnemyArchetype.@Class;
    ControllerClass = PawnClass.default.ControllerClass;
    if (PawnClass == None || ControllerClass == None)
    {
        return;
    }
    StartSpot = ChooseEnemyStart(PawnClass);
    if (StartSpot == None)
    {
        BioWorldInfo.ShowDebugMessage("WARNING: WAVE - Failed to find start location for the enemy at index " $ Index $ " in the EnemyList");
        return;
    }
    Enemy = BioWorldInfo.Spawn(PawnClass, , , StartSpot.location, StartSpot.Rotation, EnemyList[Index].EnemyArchetype, TRUE);
    LastEnemyNavPoint = StartSpot;
    CurrentEnemySpawnPointCount++;
    if (Enemy == None)
    {
        BioWorldInfo.ShowDebugMessage("WARNING: WAVE - Failed to spawn " $ PawnClass $ " at " $ StartSpot);
        return;
    }
    AI = SFXAI_Core(BioWorldInfo.Spawn(ControllerClass, , , StartSpot.location, StartSpot.Rotation, None, TRUE));
    if (AI == None)
    {
        BioWorldInfo.ShowDebugMessage("WARNING: WAVE - Failed to spawn controller for " $ PawnClass);
        return;
    }
    AI.Possess(Enemy, FALSE);
    PawnRevived(BioPawn(Enemy));
    EnemiesSpawned.Add(1);
    EnemiesSpawned[EnemiesSpawned.Length - 1].Enemy = Enemy;
    EnemiesSpawned[EnemiesSpawned.Length - 1].IndexInEnemyList = Index;
    WavePointsRemaining = Max(0, WavePointsRemaining - EnemyList[Index].WaveCost);
    WavePointsRemaining = EndlessWave ? WavePoints : WavePointsRemaining;
    UpdateObjectiveStatus();
    AliveEnemiesByType[Index]++;
    NumSpawnedEnemiesByType[Index]++;
    AI.SetTeam(1);
    if (EnemySquad != None)
    {
        EnemySquad.AddMember(Enemy);
    }
    WaveCoordinator.PawnSpawned(BioPawn(Enemy));
    AI.AutoAcquireEnemy();
    AI.BeginCombatCommand(Class'SFXAICmd_Base_HordeApproach');
    BioWorldInfo.ShowDebugMessage(PawnClass $ " was spawned");
}
public function SpawnHorde()
{
    local int EnemyToSpawn;
    
    if (EnemyBudgetRemaining())
    {
        if (EnemiesSpawned.Length < MaxEnemies)
        {
            if (ShouldSpawnSquad())
            {
                ChooseSquadToSpawn();
            }
            EnemyToSpawn = ChooseEnemyToSpawn();
            if (EnemyToSpawn != -1)
            {
                SpawnEnemy(EnemyToSpawn);
            }
            else
            {
                WavePointsRemaining = EndlessWave ? WavePointsRemaining : 0;
            }
            WaveCoordinator.SetTimer(SpawnDelay, FALSE, 'SpawnHorde', Self);
        }
        return;
    }
    WavePointsRemaining = 0;
    EndlessWave = FALSE;
    if (EnemiesSpawned.Length == 0 || AreRemainingEnemiesOnMyTeam())
    {
        TriggerWaveEndEvent(CurrentWave);
        FinishWave();
    }
}
public final function StartAutoBots()
{
    if (BioWorldInfo != None && BioWorldInfo.Role == ENetRole.ROLE_Authority)
    {
        if (BioWorldInfo.GetAutoBotsEnabled() == TRUE)
        {
            if (BioCheatManagerNonNative(LocalPlayerController.CheatManager) != None)
            {
                BioCheatManagerNonNative(LocalPlayerController.CheatManager).MPBotsInternal(TRUE);
            }
        }
    }
}
public final function StopSpawningNewEnemies()
{
    WavePointsRemaining = 0;
}
public function TriggerEnemyKilledEvent(Pawn Killed, Pawn Killer)
{
    local Sequence GameSequence;
    local array<SequenceObject> KilledEvents;
    local int Index;
    local SFXSeqEvt_HordeEnemyKilled Event;
    
    if (BioWorldInfo != None && Killed != None && Killer != None)
    {
        GameSequence = BioWorldInfo.GetGameSequence();
        if (GameSequence != None)
        {
            GameSequence.FindSeqObjectsByClass(Class'SFXSeqEvt_HordeEnemyKilled', TRUE, KilledEvents);
            for (Index = 0; Index < KilledEvents.Length; Index++)
            {
                Event = SFXSeqEvt_HordeEnemyKilled(KilledEvents[Index]);
                if (Event != None)
                {
                    if (Event.CheckActivate(Killed, Killer))
                    {
                        Event.SetObjectVars("Killed", Killed);
                        Event.SetObjectVars("Killer", Killer);
                    }
                }
            }
        }
    }
}
public function TriggerWaveEndEvent(int Wave)
{
    local PlayerController PlayerController;
    local Sequence GameSequence;
    local array<SequenceObject> WaveEndEvents;
    local int Index;
    local SFXSeqEvt_HordeWaveEnd Event;
    
    if (BioWorldInfo != None)
    {
        PlayerController = BioWorldInfo.GetLocalPlayerController();
        if (PlayerController != None && PlayerController.Pawn != None)
        {
            GameSequence = BioWorldInfo.GetGameSequence();
            if (GameSequence != None)
            {
                GameSequence.FindSeqObjectsByClass(Class'SFXSeqEvt_HordeWaveEnd', TRUE, WaveEndEvents);
                for (Index = 0; Index < WaveEndEvents.Length; Index++)
                {
                    Event = SFXSeqEvt_HordeWaveEnd(WaveEndEvents[Index]);
                    if (Event != None)
                    {
                        if (Event.CheckActivate(PlayerController.Pawn, PlayerController.Pawn))
                        {
                            Event.SetIntVars("Wave", Wave);
                        }
                    }
                }
            }
        }
    }
}
public function TriggerWaveStartEvent(int Wave)
{
    local PlayerController PlayerController;
    local Sequence GameSequence;
    local array<SequenceObject> WaveStartEvents;
    local int Index;
    local SFXSeqEvt_HordeWaveStart Event;
    
    if (BioWorldInfo != None)
    {
        PlayerController = BioWorldInfo.GetLocalPlayerController();
        if (PlayerController != None && PlayerController.Pawn != None)
        {
            GameSequence = BioWorldInfo.GetGameSequence();
            if (GameSequence != None)
            {
                GameSequence.FindSeqObjectsByClass(Class'SFXSeqEvt_HordeWaveStart', TRUE, WaveStartEvents);
                for (Index = 0; Index < WaveStartEvents.Length; Index++)
                {
                    Event = SFXSeqEvt_HordeWaveStart(WaveStartEvents[Index]);
                    if (Event != None)
                    {
                        if (Event.CheckActivate(PlayerController.Pawn, PlayerController.Pawn))
                        {
                            Event.SetIntVars("Wave", Wave);
                        }
                    }
                }
            }
        }
    }
}
public function UpdateObjectiveStatus()
{
    if (DisplayObjectivesForAllEnemies)
    {
        ActivateEnemyObjectiveMarkers();
    }
    else if (!EndlessWave)
    {
        if (WavePointsRemaining <= 0 && EnemiesSpawned.Length <= EnemiesRemainingToActivateObjective)
        {
            if (EnemyObjectiveMarkerDelay > float(0))
            {
                WaveCoordinator.SetTimer(EnemyObjectiveMarkerDelay, FALSE, 'ActivateEnemyObjectiveMarkers', Self);
            }
            else
            {
                ActivateEnemyObjectiveMarkers();
            }
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    EnemyList = ({EnemyArchetypeName = "Char_Enemies.Archetypes.Cerberus.AssaultTrooper", EnemyType = 'WAVE_CER_AssaultTrooper', EnemyArchetype = None, WaveCost = 20}, 
                 {EnemyArchetypeName = "Char_Enemies.Archetypes.Cerberus.Centurion", EnemyType = 'WAVE_CER_Centurion', EnemyArchetype = None, WaveCost = 30}, 
                 {EnemyArchetypeName = "Char_Enemies.Archetypes.Cerberus.Nemesis", EnemyType = 'WAVE_CER_Nemesis', EnemyArchetype = None, WaveCost = 40}, 
                 {EnemyArchetypeName = "Char_Enemies.Archetypes.Cerberus.Engineer", EnemyType = 'WAVE_CER_Engineer', EnemyArchetype = None, WaveCost = 40}, 
                 {EnemyArchetypeName = "Char_Enemies.Archetypes.Cerberus.Guardian", EnemyType = 'WAVE_CER_Guardian', EnemyArchetype = None, WaveCost = 40}, 
                 {EnemyArchetypeName = "Char_Enemies.Archetypes.Cerberus.Phantom", EnemyType = 'WAVE_CER_Phantom', EnemyArchetype = None, WaveCost = 80}, 
                 {EnemyArchetypeName = "Char_Enemies.Archetypes.Cerberus.Atlas", EnemyType = 'WAVE_CER_Atlas', EnemyArchetype = None, WaveCost = 100}, 
                 {EnemyArchetypeName = "Char_Enemies.Archetypes.Reapers.Husk", EnemyType = 'WAVE_RPR_Husk', EnemyArchetype = None, WaveCost = 10}, 
                 {EnemyArchetypeName = "Char_Enemies.Archetypes.Reapers.Cannibal", EnemyType = 'WAVE_RPR_Cannibal', EnemyArchetype = None, WaveCost = 25}, 
                 {EnemyArchetypeName = "Char_Enemies.Archetypes.Reapers.Marauder", EnemyType = 'WAVE_RPR_Marauder', EnemyArchetype = None, WaveCost = 35}, 
                 {EnemyArchetypeName = "Char_Enemies.Archetypes.Reapers.Brute", EnemyType = 'WAVE_RPR_Brute', EnemyArchetype = None, WaveCost = 70}, 
                 {EnemyArchetypeName = "Char_Enemies.Archetypes.Reapers.Ravager", EnemyType = 'WAVE_RPR_Ravager', EnemyArchetype = None, WaveCost = 60}, 
                 {EnemyArchetypeName = "Char_Enemies.Archetypes.Reapers.Banshee", EnemyType = 'WAVE_RPR_Banshee', EnemyArchetype = None, WaveCost = 100}, 
                 {EnemyArchetypeName = "Char_Enemies.Archetypes.Geth.GethTrooper", EnemyType = 'WAVE_GTH_GethTrooper', EnemyArchetype = None, WaveCost = 25}, 
                 {EnemyArchetypeName = "Char_Enemies.Archetypes.Geth.GethRocketTrooper", EnemyType = 'WAVE_GTH_GethRocketTrooper', EnemyArchetype = None, WaveCost = 40}, 
                 {EnemyArchetypeName = "Char_Enemies.Archetypes.Geth.GethPyro", EnemyType = 'WAVE_GTH_GethPyro', EnemyArchetype = None, WaveCost = 40}, 
                 {EnemyArchetypeName = "Char_Enemies.Archetypes.Geth.GethHunter", EnemyType = 'WAVE_GTH_GethHunter', EnemyArchetype = None, WaveCost = 40}, 
                 {EnemyArchetypeName = "Char_Enemies_MP5.Archetypes.Geth.GethPrime", EnemyType = 'WAVE_GTH_GethPrime', EnemyArchetype = None, WaveCost = 100}
                )
    PetList = ({className = 'SFXPawn_GethPrimeShieldDrone', WaveCost = 5}, 
               {className = 'SFXPawn_GethPrimeTurret', WaveCost = 7}, 
               {className = 'SFXPawn_GunnerTurret', WaveCost = 20}, 
               {className = 'SFXPawn_Swarmer', WaveCost = 2}
              )
    EnemySquadList = ({
                       EnemyTypes = ('WAVE_CER_AssaultTrooper', 'WAVE_CER_AssaultTrooper', 'WAVE_CER_AssaultTrooper', 'WAVE_CER_AssaultTrooper', 'WAVE_CER_Centurion', 'WAVE_CER_Centurion'), 
                       WaveCost = 0
                      }, 
                      {
                       EnemyTypes = ('WAVE_CER_AssaultTrooper', 'WAVE_CER_AssaultTrooper', 'WAVE_CER_AssaultTrooper', 'WAVE_CER_Centurion', 'WAVE_CER_Atlas'), 
                       WaveCost = 0
                      }
                     )
    BerserkStartCounts = ({EnemiesLeft = 2, Difficulty = EDifficultyOptions.DO_Level1}, 
                          {EnemiesLeft = 4, Difficulty = EDifficultyOptions.DO_Level2}, 
                          {EnemiesLeft = 6, Difficulty = EDifficultyOptions.DO_Level3}
                         )
    SpawnDelay = 0.300000012
    MinPlayersToSpawnSquad = 1
    MaxEnemiesPerSpawnPoint = 5
    MaxEnemies = 8
    srWaveNumber = $572616
    SrEnemiesAlive = $572617
    SpawnPenaltyOnTop = 0.300000012
    SpawnPenaltyLineOfSight = 0.600000024
    SpawnPenaltyLineOfSightMaxDist = 5000.0
    SpawnDistancePenaltyClose = 0.200000003
    SpawnRandomVariance = 0.100000001
    SpawnDesignerWeightMultiplier = 0.100000001
    SpawnDistanceClose = 3000.0
    SpawnBaseRating = 100.0
    SpawnMinRatingForRespawn = 90.0
    EnemiesRemainingToActivateObjective = 1
    EnemyObjectiveMarkerDelay = 10.0
    DamageReductionTimerOnSpawnIn = 6
    WavePointsToBudget = 13.5
}