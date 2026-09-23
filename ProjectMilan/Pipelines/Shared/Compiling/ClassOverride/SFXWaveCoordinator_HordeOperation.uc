// Source: ME3, Patch_WaveCoord_HordeOperation
// Decompiled 9/20/2026 9:50:31 PM
// MILAN CHANGE - 09/21/2026 - Mgamerz
// Change how wave loading works so host pushes archetypes to client
// so that modding waves is easier and allows us to make dynamic wavelists.
Class SFXWaveCoordinator_HordeOperation extends SFXWaveCoordinator
    transient
    config(Game);

struct OperationWave 
{
    var int WaveNumber;
    var float CreditScale;
};

var transient repnotify WaveEventInfo ReplicatedWaveEventInfo;
var config array<OperationWave> OperationWaves;
var config biodynamicload string BioSimpleDialogClassName;
var transient array<bool> HasSeenEnemyType;
var array<Class<Object>> ForcedClasses;
var protectedwrite Class<SFXWave> HordeWaveType;
var protectedwrite Class<SFXWave> OperationWaveType;
var config int NumWaves;
var config float InitialStartDelay;
var config float InitialInstructionDelay;
var config float BetweenWaveDelay;
var config stringref srWaveNumberPopup;
var config stringref srWaveCompletePopup;
var config float ManDownVOCooldown;
var transient float LastSawEnemyTypeShoutTime;
var privatewrite int CurrentWaveNumber;
var protectedwrite float PercentageOfWavesComplete;
var float TimeUntilWaveStart;
var float ManDownVOTimestamp;
var protectedwrite SFXWaveManager_Horde HordeManager;
var protectedwrite SFXWaveManager_Operation OperationManager;
var protectedwrite int HordeWaveIndex;
var protectedwrite int OperationWaveIndex;
var protectedwrite BioSimpleDialog SimpleDialogPlayer;
var protectedwrite transient SFXHostMigration HostMigration;
var config float OperationEnemyBudgetMultiplier;
var config bool bExtractionWaveEnabled;
var bool ShouldStartNewWaves;
var bool bForceOperationWave;

// MILAN CHANGE ------
// NEW: Random Waves / Random Enemies additions
const RANDOM_WAVES_ENEMY_SETTING_ID = 1;   // Must match ID in config for Random Waves
var config bool bRandomizeWaveTypePerWave;

// Host-authoritative "what to spawn and what to load" for the CURRENT wave, always populated
// (not just for Random Enemies) - every SFXWave_Horde reads composition/archetypes from here
// instead of resolving its own perobjectconfig data locally, so a host-only wavelist edit
// (via ModMaker) reaches unmodified clients regardless of same/cross-faction changes.
struct ReplicatedArchetypeEntry
{
    var Name EnemyType;
    var string EnemyArchetypeName;
    var int MinCount;
    var int MaxCount;
    var int MaxPerWave;
};
struct ReplicatedWaveComposition
{
    var int WaveNumber;                            // Horde wave this composition belongs to
    var array<Name> Types;                        // ChooseEnemyToSpawn() selects from this
    var array<ReplicatedArchetypeEntry> Archetypes; // Name -> asset path, for precache/loading
};
var transient repnotify ReplicatedWaveComposition ReplicatedComposition;
// END MILAN CHANGE ---

public simulated function PostBeginPlay()
{
    local Class<BioSimpleDialogContainer> BioSimpleDialogClass;
    local BioSimpleDialogContainer Container;
    
    Super(Actor).PostBeginPlay();
    BioSimpleDialogClass = Class<BioSimpleDialogContainer>(Class'SFXEngine'.static.GetSeekFreeObject(BioSimpleDialogClassName, Class'Class'));
    if (BioSimpleDialogClass != None)
    {
        Container = new (Self) BioSimpleDialogClass;
        SimpleDialogPlayer = Container.Dialog;
    }
    if (WorldInfo.NetMode == ENetMode.NM_Client)
    {
        SetTimer(1.0, FALSE, 'SyncWithServer', );
    }
    HasSeenEnemyType.Length = 20;
}
public simulated function PreBeginPlay()
{
    HostMigration = Class'SFXHostMigration'.static.GetHostMigration();
    Super(Actor).PreBeginPlay();
}
public event simulated function ReplicatedEvent(Name VarName)
{
    if (VarName == 'ReplicatedWaveEventInfo')
    {
        ReplicatedWaveEventUpdated();
    }
    // MILAN CHANGE
    // Added the ReplicatedComposition case
    else if (VarName == 'ReplicatedComposition')
    {
        // No action needed here
        // SFXWave_Horde.GetEnemyArray() will read it live.
    }
    // END MILAN CHANGE
    else
    {
        Super(Actor).ReplicatedEvent(VarName);
    }
}
public function EndWaves()
{
    ShouldStartNewWaves = FALSE;
    Super.EndWaves();
}
public simulated function float GetEnemyScoreBudget()
{
    local SFXWave_Horde pHordeWave;
    local SFXWave_Operation pOperationWave;
    
    pHordeWave = SFXWave_Horde(GetWaveOfType('SFXWave_Horde'));
    pOperationWave = SFXWave_Operation(GetWaveOfType('SFXWave_Operation'));
    if (pOperationWave != None)
    {
        return pHordeWave.GetScoreBudget() * OperationEnemyBudgetMultiplier;
    }
    return pHordeWave.GetScoreBudget();
}
public simulated function int GetFriendlyCurrentWaveNumber()
{
    return CurrentWaveNumber + 1;
}
public simulated function float GetObjectiveCreditBudget()
{
    local SFXWave_Operation pOperationWave;
    
    pOperationWave = SFXWave_Operation(GetWaveOfType('SFXWave_Operation'));
    if (pOperationWave == None)
    {
        return 0.0;
    }
    return pOperationWave.GetCreditBudget();
}
public simulated function float GetObjectiveScoreBudget()
{
    local SFXWave_Operation pOperationWave;
    
    pOperationWave = SFXWave_Operation(GetWaveOfType('SFXWave_Operation'));
    if (pOperationWave == None)
    {
        return 0.0;
    }
    return pOperationWave.OperationScoreReward;
}
public simulated function float GetPercentOfWavesCompleted()
{
    return PercentageOfWavesComplete;
}
public function HandleHostMigration()
{
    RecoverFromWaveEventInfo(FALSE, HostMigration.GetWaveToRestore());
}
protected simulated function OnAllWavesFinished()
{
    local SFXGRI GRI;
    local bool bIsGameOver;
    local BioWorldInfo oWorldInfo;
    local bool bLastWave;
    
    ReplicateWaveEventInfo(3);
    Super.OnAllWavesFinished();
    oWorldInfo = BioWorldInfo(WorldInfo);
    if (oWorldInfo != None)
    {
        if (oWorldInfo.GRI != None)
        {
            if (SFXGRI(oWorldInfo.GRI).ObjectPool != None)
            {
                bLastWave = CurrentWaveNumber + 1 >= NumWaves;
                SFXGRI(oWorldInfo.GRI).ObjectPool.CleanUpPools(FALSE, , !bLastWave);
                Class'RvrClientEffectManager'.static.GetClientEffectManager().CleanUpPools();
                oWorldInfo.RescheduleGarbageCollectionTimer(2.0);
            }
        }
    }
    ClearAllTimers();
    GRI = SFXGRI(WorldInfo.GRI);
    bIsGameOver = GRI.IsGameOver();
    if (Role == ENetRole.ROLE_Authority)
    {
        if (GRI.NumLivingPlayers() > 0 && !bIsGameOver)
        {
            SetTimer(1.0, FALSE, 'PlayEndWaveCongratulationsVO', );
            if (CurrentWaveNumber + 1 == NumWaves / 2)
            {
                SetTimer(3.5, FALSE, 'PlayHalfWavesDoneVO', );
            }
            else if (CurrentWaveNumber + 1 < NumWaves)
            {
                SetTimer(3.5, FALSE, 'PlayHordeWaveDoneVO', );
            }
        }
        else
        {
            SimpleDialogPlayer.PlayVOEventRandomLine('MissionFailed');
        }
        if (CurrentWaveNumber + 1 < NumWaves)
        {
            if (ShouldStartNewWaves)
            {
                AdvanceToNextWave();
                TimeUntilWaveStart = BetweenWaveDelay;
                DisplayDebugCountdown();
                SetTimer(1.0, TRUE, 'DisplayDebugCountdown', );
            }
        }
        else
        {
            WorldInfo.Game.GotoState('MatchOver', , , );
        }
    }
    SetTimer(1.0, FALSE, 'EndOfWave', );
    Class'SFXEngine'.static.ValidateNetObjectIndex();
}
protected simulated function OnAllWavesFinishedLoading()
{
    local SFXWave WaveIter;
    local bool CurrentWaveIsAnOperation;
    local string WaveTextPopup;
    
    Super.OnAllWavesFinishedLoading();
    BioWorldInfo(WorldInfo).ShowDebugMessage("Starting wave");
    if (Role == ENetRole.ROLE_Authority)
    {
        CurrentWaveIsAnOperation = IsCurrentWaveAnOperation();
        if (CurrentWaveNumber != 0)
        {
            if (!CurrentWaveIsAnOperation)
            {
                SimpleDialogPlayer.PlayVOEventRandomLine('HordeWaveStarted');
                PlayPlayerAcknowledgment(SimpleDialogPlayer.LastEventDuration + 0.5);
            }
        }
    }
    if (CurrentWaveNumber + 1 < NumWaves)
    {
        ClearCustomTokens();
        SetCustomToken(0, string(GetFriendlyCurrentWaveNumber()));
        WaveTextPopup = GetTokenisedString(srWaveNumberPopup);
        SFXPlayerController(WorldInfo.GetALocalPlayerController()).DisplayTextPopup(WaveTextPopup);
        Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound('MPNewWaveBegun');
    }
    else
    {
        Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound('MPFinalWaveBegun');
    }
    if (CurrentWaveIsAnOperation)
    {
        SFXWave_Horde(GetWaveOfType('SFXWave_Horde')).SetEndlessWaves(TRUE);
    }
    foreach ActiveWaves(WaveIter, )
    {
        WaveIter.BeginWave();
    }
}
public simulated function OnWaveFinished(SFXWave Wave)
{
    local BioPlayerController PC;
    local SFXWave_Horde HordeWave;
    local SFXWeapon oWeapon;
    local float AmmoRefillOnWaveEnd;
    local float ReviveHealthReturn;
    local float EndWaveHealthReturn;
    local SFXPawn_Player Player;
    local SFXModule_Damage DamageMod;
    local SFXPRI PRI;
    
    Super.OnWaveFinished(Wave);
    if (SFXWave_Operation(Wave) != None)
    {
        HordeWave = SFXWave_Horde(GetWaveOfType('SFXWave_Horde'));
        if (HordeWave != None)
        {
            HordeWave.SetEndlessWaves(FALSE);
            HordeWave.StopSpawningNewEnemies();
            HordeWave.UpdateObjectiveStatus();
            OperationWaveIndex = -1;
        }
    }
    else if (Role == ENetRole.ROLE_Authority)
    {
        AmmoRefillOnWaveEnd = SFXGRI(WorldInfo.GRI).DifficultyHandler.GetFloat('AmmoRefillOnWaveEnd', 'MPGlobal');
        ReviveHealthReturn = SFXGRI(WorldInfo.GRI).DifficultyHandler.GetFloat('ReviveHealthReturn', 'MPGlobal');
        EndWaveHealthReturn = SFXGRI(WorldInfo.GRI).DifficultyHandler.GetFloat('EndWaveHealthReturn', 'MPGlobal');
        foreach WorldInfo.AllControllers(Class'BioPlayerController', PC)
        {
            Player = SFXPawn_Player(PC.Pawn);
            if (Player != None)
            {
                if (Player.IsInState('Downed', ) || Player.IsDead())
                {
                    Player.Resurrect(ReviveHealthReturn, FALSE);
                }
                DamageMod = Player.GetModule(Class'SFXModule_Damage');
                if (DamageMod != None)
                {
                    DamageMod.SetCurrentHealth(FClamp(DamageMod.GetCurrentHealth() + EndWaveHealthReturn * DamageMod.GetMaxHealth(), 0.0, DamageMod.GetMaxHealth()), TRUE);
                }
                if (Player.InvManager != None)
                {
                    foreach Player.InvManager.InventoryActors(Class'SFXWeapon', oWeapon)
                    {
                        if (SFXHeavyWeapon(oWeapon) == None)
                        {
                            oWeapon.AddAmmo(int(float(oWeapon.GetMaxSpareAmmo()) * AmmoRefillOnWaveEnd));
                        }
                    }
                }
            }
        }
    }
    PC = BioPlayerController(WorldInfo.GetALocalPlayerController());
    if (Role == ENetRole.ROLE_Authority && PC != None)
    {
        PRI = SFXPRI(PC.PlayerReplicationInfo);
        if (PRI != None)
        {
            if (IsCurrentWaveAnOperation() == FALSE || SFXWave_Operation(Wave) != None)
            {
                Class'SFXTelemetryHooksMP'.static.SendWaveComplete(CurrentWaveNumber, string(Wave.@Class), IsCurrentWaveAnOperation(), int(PRI.GetTotalCredits()), int(PRI.GetTotalPoints()), 0);
            }
        }
    }
}
public simulated function PawnDowned(BioPawn Pawn)
{
    Super.PawnDowned(Pawn);
    if (!IsTimerActive('PlayManDownVO'))
    {
        SetTimer(1.0, FALSE, 'PlayManDownVO', );
    }
}

protected simulated function StartNewWave()
{
    local SFXWave NewHordeWave;
    local SFXWave NewOperationWave;
    local SFXScoreManager ScoreManager;
    local SFXGRI GRI;
    local SFXEngine LocalEngine;
    local int WaveNumber;
    local Name TriggerName;
    local Name TierName;
    local string StateString;
    local string TriggerString;
    local string OperationString;
    local BioPlayerController PC;
    local PlayerReplicationInfo PRI;
    local int NumPlayers;
    
    if (Role == ENetRole.ROLE_Authority && !ShouldStartNewWaves)
    {
        return;
    }
    // MILAN CHANGE
    if (Role == ENetRole.ROLE_Authority)
    {
    	// Server side only: Resets ReplicatedComposition struct each new wave
	    ReplicatedComposition.WaveNumber = -1;
    	ReplicatedComposition.Types.Length = 0;
        ReplicatedComposition.Archetypes.Length = 0;
    }
    // END MILAN CHANGE
    ActiveWaves.Length = 0;
    NewHordeWave = HordeManager.GetNewWave(HordeWaveIndex, HordeWaveType);
    NewHordeWave.SetWaveCoordinator(Self);
    ActiveWaves.AddItem(NewHordeWave);
    if (Role == ENetRole.ROLE_Authority)
    {
        PublishEnemyComposition(SFXWave_Horde(NewHordeWave));
    }
    if (IsCurrentWaveAnOperation() && OperationWaveIndex != -1)
    {
        NewOperationWave = OperationManager.GetNewWave(OperationWaveIndex, OperationWaveType);
        if (NewOperationWave != None)
        {
            NewOperationWave.SetWaveCoordinator(Self);
            ActiveWaves.AddItem(NewOperationWave);
        }
    }
    BeginWaveLoading();
    GRI = SFXGRI(WorldInfo.GRI);
    if (GRI != None)
    {
        ScoreManager = GRI.GetScoreManager();
        if (ScoreManager != None)
        {
            ScoreManager.NewWaveStarted();
        }
        if (HostMigration != None)
        {
            HostMigration.SaveGRI(GRI);
        }
    }
	// MILAN CHANGE - Remove RemoteLogger
	
    SetTimer(BetweenWaveDelay, FALSE, 'OnAllWavesFinishedLoading', );
    ReplicateWaveEventInfo(1);
}

protected simulated function BeginWaveLoading()
{
    local SFXWave WaveIter;
    local SFXWave_Horde HordeWave;

    // On the host, StartNewWave() has already published the composition. On a
    // client the replicated struct can arrive a frame after the wave event, so
    // wait for the composition belonging to this exact wave before allowing
    // the base coordinator to start its loading/update loop.
    if (Role != ENetRole.ROLE_Authority && ReplicatedComposition.WaveNumber != CurrentWaveNumber)
    {
        // TEMP WAVEDBG
        LogInternal("[WAVEDBG] BeginWaveLoading: waiting for composition, role=" $ int(Role) $ " compWave=" $ ReplicatedComposition.WaveNumber $ " curWave=" $ CurrentWaveNumber);
        SetTimer(0.1, FALSE, 'BeginWaveLoading', );
        return;
    }

    foreach ActiveWaves(WaveIter, )
    {
        HordeWave = SFXWave_Horde(WaveIter);
        if (HordeWave != None && !HordeWave.PrepareWaveAssetLoadData())
        {
            SetTimer(0.1, FALSE, 'BeginWaveLoading', );
            return;
        }
        // TEMP WAVEDBG
        LogInternal("[WAVEDBG] BeginWaveLoading: BeginLoading on " $ WaveIter.Name $ " role=" $ int(Role) $ " assets=" $ WaveIter.AssetLoadData.Length $ " curWave=" $ CurrentWaveNumber);
        WaveIter.BeginLoading();
    }
    WavesAreLoading = TRUE;
    SetTimer(0.2, TRUE, 'UpdateWaveLoading', );
    UpdateWaveLoading();
}

// TEMP WAVEDBG - remove once the async-load stall is diagnosed.
// Dumps every not-yet-complete asset each poll (status 3 == ASYNC_LOAD_COMPLETE).
public simulated function UpdateWaveLoading()
{
    local SFXWave WaveIter;
    local int i;

    Super.UpdateWaveLoading();
    foreach ActiveWaves(WaveIter, )
    {
        for (i = 0; i < WaveIter.AssetLoadData.Length; i++)
        {
            if (int(WaveIter.AssetLoadData[i].AssetLoadStatus) != 3)
            {
                LogInternal("[WAVEDBG] UpdateWaveLoading: role=" $ int(Role) $ " wave=" $ WaveIter.Name $ " asset='" $ WaveIter.AssetLoadData[i].AssetToLoad $ "' status=" $ int(WaveIter.AssetLoadData[i].AssetLoadStatus) $ " loaded=" $ (WaveIter.AssetLoadData[i].LoadedAsset != None) $ " timerActive=" $ IsTimerActive('UpdateWaveLoading'));
            }
        }
    }
}

public simulated function StartWaves()
{
    local SFXPlayerController PC;
    local int EnemyTypesIndex;
    
    if (Role == ENetRole.ROLE_Authority)
    {
        if (HordeManager == None)
        {
            HordeManager = Spawn(Class'SFXWaveManager_Horde', Self);
            HordeManager.GenerateEnemySpawnPointList();
        }
        if (HordeWaveType == None)
        {
        	// MILAN CHANGE
        	// Determine if we're doing randomized faction per wave
            if (SFXGRI(WorldInfo.GRI).GetEnemyWaveTypeID() == RANDOM_WAVES_ENEMY_SETTING_ID)
            {
                bRandomizeWaveTypePerWave = TRUE;
                HordeWaveType = PickRandomFactionWaveType();
            }
            else
            {
	            // Original Logic
                EnemyTypesIndex = Class'SFXOnlineGameSettings'.default.EnemyTypes.Find('Id', SFXGRI(WorldInfo.GRI).GetEnemyWaveTypeID());
                if (EnemyTypesIndex == -1)
                {
                    HordeWaveType = Class'SFXWave_Horde';
                }
                else
                {
                    HordeWaveType = Class<SFXWave>(FindObject(Class'SFXOnlineGameSettings'.default.EnemyTypes[EnemyTypesIndex].WaveClass, Class'Class'));
                    if (HordeWaveType == None)
                    {
                        HordeWaveType = Class<SFXWave>(Class'SFXEngine'.static.GetSeekFreeObject(Class'SFXOnlineGameSettings'.default.EnemyTypes[EnemyTypesIndex].WaveClass, Class'Class'));
                    }
                }
            }
            // END MILAN CHANGE
        }
        if (OperationManager == None)
        {
            OperationManager = Spawn(Class'SFXWaveManager_Operation', Self);
        }
        SetTimer(InitialInstructionDelay, FALSE, 'PlayInstructionVO', );
        SetTimer(InitialStartDelay, FALSE, 'StartNewWave', );
    }
    else if (HordeManager == None || OperationManager == None)
    {
        SetTimer(0.100000001, FALSE, 'StartWaves', );
        return;
    }
    SetTimer(InitialStartDelay + BetweenWaveDelay, FALSE, 'OnAllWavesFinishedLoading', );
    GenerateHordeWaveList(HordeWaveType);
    GenerateOperationWaveList(OperationWaveType);
    if (Role == ENetRole.ROLE_Authority)
    {
        UpdateCurrentWaveNumber(0);
        ReplicateWaveEventInfo(0);
    }
    ShouldStartNewWaves = TRUE;
    PC = SFXPlayerController(WorldInfo.GetALocalPlayerController());
    if (PC != None)
    {
        PC.UpdateInGameConsumableUI();
    }
}
public simulated function SyncClientMatchTimer(float OperationTime)
{
    if (OperationManager != None)
    {
        OperationManager.SyncClientMatchTimer(OperationTime, GetWaveOfType('SFXWave_Operation'));
    }
}
private final simulated function bool IsCurrentWaveAnOperation()
{
    return IsSpecifiedWaveAnOperation(CurrentWaveNumber) || bForceOperationWave;
}
private final simulated function bool IsSpecifiedWaveAnOperation(int WaveNumber)
{
    if (OperationManager == None || OperationManager.PotentialWaves.Length == 0)
    {
        return FALSE;
    }
    else
    {
        return OperationWaves.Find('WaveNumber', WaveNumber) != -1;
    }
}
public function OnSingleEnemyRemaining()
{
    local SFXPawn_Player PlayerPawnSpeaker;
    local BioBaseSquad PlayerSquad;
    local BioWorldInfo BWI;
    
    SimpleDialogPlayer.PlayVOEventRandomLine('SingleEnemyLeft');
    BWI = BioWorldInfo(WorldInfo);
    if (BWI != None)
    {
        PlayerSquad = BioWorldInfo(WorldInfo).m_playerSquad;
        if (PlayerSquad != None && PlayerSquad.Members.Length > 0)
        {
            PlayerPawnSpeaker = SFXPawn_Player(PlayerSquad.Members[Rand(PlayerSquad.Members.Length)]);
        }
        if (PlayerPawnSpeaker != None)
        {
            SFXGRI(WorldInfo.GRI).TriggerVocalizationEvent(29, PlayerPawnSpeaker, , SimpleDialogPlayer.LastEventDuration + 0.5, , TRUE);
        }
    }
}
public final function float PlayAssassinationVOEvent(Name EventName)
{
    SimpleDialogPlayer.PlayVOEventRandomLine(EventName);
    return SimpleDialogPlayer.LastEventDuration;
}
protected function PlayEndWaveCongratulationsVO()
{
    local SFXPawn_Player PlayerPawnSpeaker;
    local BioBaseSquad PlayerSquad;
    local BioWorldInfo BWI;
    
    SimpleDialogPlayer.PlayVOEventRandomLine('EndWaveCongratulations');
    BWI = BioWorldInfo(WorldInfo);
    if (BWI != None)
    {
        PlayerSquad = BioWorldInfo(WorldInfo).m_playerSquad;
        if (PlayerSquad != None && PlayerSquad.Members.Length > 0)
        {
            PlayerPawnSpeaker = SFXPawn_Player(PlayerSquad.Members[Rand(PlayerSquad.Members.Length)]);
        }
        if (PlayerPawnSpeaker != None)
        {
            SFXGRI(WorldInfo.GRI).TriggerVocalizationEvent(30, PlayerPawnSpeaker, , SimpleDialogPlayer.LastEventDuration + 0.5, , TRUE);
        }
    }
}
protected function PlayHalfWavesDoneVO()
{
    SimpleDialogPlayer.PlayVOEventRandomLine('HalfHordeWavesDone');
}
protected function PlayHordeGameStartedVO()
{
    SimpleDialogPlayer.PlayVOEventRandomLine('HordeGameStarted');
    PlayPlayerAcknowledgment(SimpleDialogPlayer.LastEventDuration + 0.5);
}
protected function PlayHordeWaveDoneVO()
{
    SimpleDialogPlayer.PlayVOEventRandomLine('HordeWaveDone');
}
protected function PlayInstructionVO()
{
    SimpleDialogPlayer.PlayVOEventRandomLine('MissionInstructions');
    SetTimer(SimpleDialogPlayer.LastEventDuration + 0.5, FALSE, 'PlayHordeGameStartedVO', );
}
protected function PlayManDownVO()
{
    if (WorldInfo.TimeSeconds - ManDownVOTimestamp > ManDownVOCooldown)
    {
        ManDownVOTimestamp = WorldInfo.TimeSeconds;
        SimpleDialogPlayer.PlayVOEventRandomLine('ManDown');
    }
}
public final function PlayPlayerAcknowledgment(optional float DelayTime = 3.0, optional bool PlayObjectiveBegin = FALSE)
{
    local SFXGRI GRI;
    local SFXPawn_Player PlayerPawnSpeaker;
    local BioBaseSquad PlayerSquad;
    
    if (Role == ENetRole.ROLE_Authority)
    {
        PlayerSquad = BioWorldInfo(WorldInfo).m_playerSquad;
        if (PlayerSquad != None && PlayerSquad.Members.Length > 0)
        {
            PlayerPawnSpeaker = SFXPawn_Player(PlayerSquad.Members[Rand(PlayerSquad.Members.Length)]);
        }
        GRI = SFXGRI(WorldInfo.GRI);
        if (GRI != None)
        {
            GRI.TriggerVocalizationEvent(133, PlayerPawnSpeaker, , DelayTime, , TRUE);
            if (PlayObjectiveBegin)
            {
                GRI.TriggerVocalizationEvent(118, PlayerPawnSpeaker, , DelayTime + 2.0, , TRUE);
            }
        }
    }
}
public simulated function RecoverFromWaveEventInfo(bool bStartNewWaveNow, WaveEventInfo NewWaveEventInfo)
{
    HordeWaveType = NewWaveEventInfo.HordeWaveType;
    StartWaves();
    UpdateCurrentWaveNumber(NewWaveEventInfo.WaveNumber);
    OperationWaveIndex = NewWaveEventInfo.OperationWaveIndex;
    HordeWaveIndex = NewWaveEventInfo.HordeWaveIndex;
    if (bStartNewWaveNow)
    {
        if (CurrentWaveNumber > -1)
        {
            StartNewWave();
        }
    }
}
public simulated function ReplicatedWaveEventUpdated()
{
    if (Role == ENetRole.ROLE_Authority)
    {
        return;
    }
    if (HostMigration != None && (ReplicatedWaveEventInfo.WaveEvent == EWaveCoordinator_HordeOpEvent.EW_BeginWave || ReplicatedWaveEventInfo.WaveEvent == EWaveCoordinator_HordeOpEvent.EW_JoinInProgress))
    {
        HostMigration.SetWaveToRestore(ReplicatedWaveEventInfo);
    }
    switch (ReplicatedWaveEventInfo.WaveEvent)
    {
        case EWaveCoordinator_HordeOpEvent.EW_StartWaves:
            HordeWaveType = ReplicatedWaveEventInfo.HordeWaveType;
            StartWaves();
            break;
        case EWaveCoordinator_HordeOpEvent.EW_BeginWave:
            FinishActiveWaves();
            UpdateCurrentWaveNumber(ReplicatedWaveEventInfo.WaveNumber);
            HordeWaveIndex = ReplicatedWaveEventInfo.HordeWaveIndex;
            OperationWaveIndex = ReplicatedWaveEventInfo.OperationWaveIndex;
            HordeWaveType = ReplicatedWaveEventInfo.HordeWaveType;
            StartNewWave();
            break;
        case EWaveCoordinator_HordeOpEvent.EW_FinishWave:
            FinishActiveWaves();
            break;
        case EWaveCoordinator_HordeOpEvent.EW_JoinInProgress:
            if (!ShouldStartNewWaves)
            {
                ClientHandleJoinInProgress();
            }
            break;
        default:
            break;
    }
}
public function ReplicateWaveEventInfo(EWaveCoordinator_HordeOpEvent NewEvent)
{
    if (Role != ENetRole.ROLE_Authority)
    {
        return;
    }
    ReplicatedWaveEventInfo.Trigger++;
    ReplicatedWaveEventInfo.WaveEvent = NewEvent;
    if (ActiveWaves.Length > 0)
    {
        ReplicatedWaveEventInfo.WaveNumber = CurrentWaveNumber;
    }
    else
    {
        ReplicatedWaveEventInfo.WaveNumber = -1;
    }
    ReplicatedWaveEventInfo.OperationWaveIndex = OperationWaveIndex;
    ReplicatedWaveEventInfo.HordeWaveIndex = HordeWaveIndex;
    ReplicatedWaveEventInfo.HordeWaveType = HordeWaveType;
    ReplicatedWaveEventInfo.WavesAreLoading = WavesAreLoading;
}
public simulated function SyncWithServer()
{
    if (SFXGRI(WorldInfo.GRI) != None && HordeManager != None && OperationManager != None)
    {
        if (SFXGRI(WorldInfo.GRI).IsJoinInProgress())
        {
            SFXPlayerControllerMP(GetALocalPlayerController()).ServerWaveCoordinatorJoinInProgress(Self);
        }
    }
    else
    {
        SetTimer(0.00999999978, FALSE, 'SyncWithServer', );
    }
}
private final simulated function UpdateCurrentWaveNumber(int NewWaveNumber)
{
    CurrentWaveNumber = NewWaveNumber;
    if (NumWaves == 0)
    {
        PercentageOfWavesComplete = 0.0;
    }
    else
    {
        PercentageOfWavesComplete = float(CurrentWaveNumber) / float(NumWaves);
    }
    // MILAN CHANGE
    // If bRandomizeWaveTypePerWave, randomly change faction
    if (bRandomizeWaveTypePerWave && Role == ENetRole.ROLE_Authority)
    {
        HordeWaveType = PickRandomFactionWaveType();
        GenerateHordeWaveList(HordeWaveType);
    }
    // END MILAN CHANGE
    HordeWaveIndex = HordeManager.GetWaveIndex(CurrentWaveNumber);
    HordeWaveType = HordeManager.PotentialWavesType;
    if (IsCurrentWaveAnOperation())
    {
        if (CurrentWaveNumber + 1 == HordeManager.MaxWaves && bExtractionWaveEnabled)
        {
            OperationWaveIndex = OperationManager.GetWaveIndex(CurrentWaveNumber, "SFXGameMPContent.SFXEngagement_Extraction");
        }
        else
        {
            OperationWaveIndex = OperationManager.GetWaveIndex(CurrentWaveNumber);
        }
        OperationWaveType = OperationManager.PotentialWavesType;
    }
}
protected function AdvanceToNextWave()
{
    UpdateCurrentWaveNumber(CurrentWaveNumber + 1);
    StartNewWave();
}
public simulated function ClientHandleJoinInProgress()
{
    RecoverFromWaveEventInfo(TRUE, ReplicatedWaveEventInfo);
}
public final simulated function DisplayDebugCountdown()
{
    local SFXPlayerController PC;
    local string Message;
    
    Message = "WAVE COUNTDOWN - " $ TimeUntilWaveStart;
    foreach WorldInfo.AllControllers(Class'SFXPlayerController', PC)
    {
        if (PC != None && PC.Pawn != None)
        {
            PC.Pawn.ClientMessage(Message);
        }
    }
    TimeUntilWaveStart -= 1.0;
    if (TimeUntilWaveStart < 0.0)
    {
        ClearTimer('DisplayDebugCountdown');
    }
}
public simulated function EndOfWave()
{
    local SFXPlayerController PC;
    local SFXGRI GRI;
    local bool bIsGameOver;
    
    PC = SFXPlayerController(WorldInfo.GetALocalPlayerController());
    GRI = SFXGRI(WorldInfo.GRI);
    bIsGameOver = GRI.IsGameOver();
    if (CurrentWaveNumber < NumWaves && GRI.NumLivingPlayers() > 0 && !bIsGameOver)
    {
        SFXPlayerController(WorldInfo.GetALocalPlayerController()).DisplayTextPopup(string(srWaveCompletePopup));
        Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound('MPWaveComplete');
    }
    if (PC != None)
    {
        PC.OnWaveFinished();
    }
    if (GRI.NumLivingPlayers() > 0 && !bIsGameOver)
    {
        if (bExtractionWaveEnabled && CurrentWaveNumber == NumWaves - 1)
        {
            GRI.OnMissionComplete();
        }
        GRI.GetScoreManager().WaveCompleted();
    }
}
public simulated function GenerateHordeWaveList(Class<SFXWave> NewHordeWaveType)
{
    HordeManager.GeneratePotentialWaveList(NewHordeWaveType);
}
public simulated function GenerateOperationWaveList(Class<SFXWave> NewOperationWaveType)
{
    OperationManager.GeneratePotentialWaveList(NewOperationWaveType);
}
public simulated function float GetCreditScaling()
{
    local int OpWave;
    
    OpWave = OperationWaves.Find('WaveNumber', CurrentWaveNumber);
    if (OpWave >= 0)
    {
        return OperationWaves[OpWave].CreditScale;
    }
    return 0.0;
}
public function GoToWave(int nWave)
{
    ShouldStartNewWaves = FALSE;
    FinishActiveWaves();
    ShouldStartNewWaves = TRUE;
    ClearTimer('StartNewWave');
    UpdateCurrentWaveNumber(nWave);
    StartNewWave();
}
public function HandleJoinInProgress()
{
    if (ShouldStartNewWaves)
    {
        ReplicateWaveEventInfo(4);
    }
    OperationManager.ForceMatchTimerSync();
}

// MILAN CHANGE
// NEW: Random Waves
// Weighted pick over real factions only - IsRandomOption excludes Unknown/Random Waves/
// Random Enemies (and any future meta-option) explicitly, same flag ChooseRandomEnemy()
// in SFXGameInfoMP_Lobby now filters on, instead of relying on WaveClass=="" incidentally.
private final function Class<SFXWave> PickRandomFactionWaveType()
{
    local array<MPEnemyInfo> Candidates;
    local MPEnemyInfo Info;
    local int idx;
    local float SelectionSum;
    local float RandVal;
    local float Weight;
    local Class<SFXWave> Picked;

    foreach Class'SFXOnlineGameSettings'.default.EnemyTypes(Info, )
    {
        if (!Info.IsRandomOption && Info.WaveClass != "")
        {
            idx = Class'SFXWaveManager_Horde'.default.WaveTypes.Find('WaveClassName', Info.WaveClass);
            if (idx != -1 && Class'SFXWaveManager_Horde'.default.WaveTypes[idx].SelectionWeight > 0)
            {
                Candidates.AddItem(Info);
                SelectionSum += float(Class'SFXWaveManager_Horde'.default.WaveTypes[idx].SelectionWeight);
            }
        }
    }

    if (Candidates.Length == 0 || SelectionSum <= 0.0)
    {
        return Class'SFXWave_Horde_Cerberus';
    }

    RandVal = FRand() * SelectionSum;
    foreach Candidates(Info, )
    {
        idx = Class'SFXWaveManager_Horde'.default.WaveTypes.Find('WaveClassName', Info.WaveClass);
        Weight = float(Class'SFXWaveManager_Horde'.default.WaveTypes[idx].SelectionWeight);
        if (RandVal < Weight)
        {
            Picked = Class<SFXWave>(FindObject(Info.WaveClass, Class'Class'));
            if (Picked == None)
            {
                Picked = Class<SFXWave>(Class'SFXEngine'.static.GetSeekFreeObject(Info.WaveClass, Class'Class'));
            }
            if (Picked != None)
            {
                return Picked;
            }
        }
        RandVal -= Weight;
    }
    return Class'SFXWave_Horde_Cerberus';
}

// NEW: Random Enemies
// Server-only: Publish the current wave's composition so it replicates to clients
public function PublishEnemyComposition(SFXWave_Horde Wave)
{
    local array<EnemyWaveInfo> LocalComposition;
    local EnemyWaveInfo Info;
    local EnemySpawnInfo SpawnInfo;
    local ReplicatedArchetypeEntry Entry;

    if (Role != ENetRole.ROLE_Authority)
    {
    	// Never run on client
        return;
    }
    ReplicatedComposition.Types.Length = 0;
    ReplicatedComposition.Archetypes.Length = 0;
    ReplicatedComposition.WaveNumber = CurrentWaveNumber;

    Wave.GetLocalEnemyArray(LocalComposition);
    foreach LocalComposition(Info, )
    {
        ReplicatedComposition.Types.AddItem(Info.EnemyType);
        SpawnInfo = Wave.GetEnemySpawnInfoForEnemyType(Info.EnemyType);
        Entry.EnemyType = Info.EnemyType;
        Entry.EnemyArchetypeName = SpawnInfo.EnemyArchetypeName;
        Entry.MinCount = Info.MinCount;
        Entry.MaxCount = Info.MaxCount;
        Entry.MaxPerWave = Info.MaxPerWave;
        ReplicatedComposition.Archetypes.AddItem(Entry);
        // TEMP WAVEDBG
        LogInternal("[WAVEDBG] PublishEnemyComposition: wave=" $ CurrentWaveNumber $ " waveObj=" $ Wave.Name $ " type=" $ Entry.EnemyType $ " archetype='" $ Entry.EnemyArchetypeName $ "'");
    }
    bForceNetUpdate = TRUE;
}
// END MILAN CHANGE

replication
{
    if (!bNetInitial && bNetDirty && Role == ENetRole.ROLE_Authority)
        ReplicatedWaveEventInfo;
    if (bNetDirty && Role == ENetRole.ROLE_Authority)
        HordeManager, OperationManager;
    // MILAN CHANGE - Add new ReplicatedComposition Struct
    if (bNetDirty && Role == ENetRole.ROLE_Authority)
        ReplicatedComposition;
    // END MILAN CHANGE
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    OperationWaves = ({WaveNumber = 2, CreditScale = 0.150000006}, 
                      {WaveNumber = 5, CreditScale = 0.25}, 
                      {WaveNumber = 9, CreditScale = 0.600000024}, 
                      {WaveNumber = 10, CreditScale = 0.0}
                     )
    BioSimpleDialogClassName = "SFXGameMPContent.BioSimpleDlgContainer_Horde"
    ForcedClasses = (Class'SFXWave_Horde_Cerberus', 
                     Class'SFXWave_Horde_Geth', 
                     Class'SFXWave_Horde_Reaper', 
                     Class'SFXEngagement_Annex', 
                     Class'SFXEngagement_Assassination', 
                     Class'SFXEngagement_Disarm', 
                     Class'SFXEngagement_Extraction', 
                     Class'SFXEngagement_Retrieve'
                    )
    OperationWaveType = Class'SFXWave_Operation'
    NumWaves = 11
    InitialStartDelay = 10.0
    InitialInstructionDelay = 3.0
    BetweenWaveDelay = 10.0
    srWaveNumberPopup = $572616
    srWaveCompletePopup = $708507
    ManDownVOCooldown = 4.0
    OperationEnemyBudgetMultiplier = 3.0
    bExtractionWaveEnabled = TRUE
}
