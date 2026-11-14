// Source: ME3, Patch_SFXPlayerControllerMP
// Decompiled 10/12/2026 9:48:00 AM
// MILAN CHANGE 10/17/2026
// By Mgamerz
// Fix controller vibration not working due to ME3 PC-specific build assuming no controller support
// 10/23/2026 ClientSetMaterialActorParam, for SFXGameContent_Milan.SFXSeqAct_SetMaterialParam
// 10/31/2026 Don't kick in photo mode, don't kick in public when you're the only player
Class SFXPlayerControllerMP extends SFXPlayerController
    config(Game);

var config array<Name> MPMapNames;
var Camera.ViewTargetTransitionParams VTTransParms;
var Object.Vector AFKLastMoveStick;
var SFXGUI_MPStore StoreGUI;
var SFXGUI_SquadRecord LevelUpGUI;
var SFXLobbyFlow LobbyFlow;
var BioStartLocationMP BioStartSpot;
var float CountdownTimerEndTime;
var const float CountdownTimerLeeway;
var config float TickSaveGameInterval;
var config stringref srWaitMessageMatchStarted;
var config stringref srWaitMessageMatchEnded;
var config stringref srWaitMessageGeneric;
var config stringref srExitMessage;
var config stringref srExitMessageLobby;
var config stringref srConfirm;
var config stringref srCancel;
var config float AFKTimeLimitSeconds;
var config int AFKTickTime;
var float AFKPostponementStartTime;
var float AFKLastActionTime;
var bool bReceivedPlayer;
var bool bFinishedTraveling;
var bool bIsJoinInProgress;
var bool bRestarting;
var config bool AFKIgnoreMovementCheck;
var config bool AFKIgnoreWeaponAndPowerCheck;
var bool IsAFKPostponementActive;

public event function bool CanSave(out string Reason)
{
    return FALSE;
}
public event function CheckThatGameCanContinue()
{
    if (SFXEngine(Class'SFXEngine'.static.GetEngine()).HasCantContinueError())
    {
        return;
    }
    Super(BioPlayerController).CheckThatGameCanContinue();
}
public event reliable client function ClientPlaySimpleDialogLine(stringref DialogLineSr, Actor DialogPlayerOwner)
{
    local BioSimpleDialog DialogPlayer;
    local SFXWaveCoordinator_HordeOperation WaveOwner;
    local SFXOperationObjective ObjectiveOwner;
    
    WaveOwner = SFXWaveCoordinator_HordeOperation(DialogPlayerOwner);
    ObjectiveOwner = SFXOperationObjective(DialogPlayerOwner);
    if (WaveOwner != None)
    {
        DialogPlayer = WaveOwner.SimpleDialogPlayer;
    }
    else if (ObjectiveOwner != None)
    {
        DialogPlayer = ObjectiveOwner.SimpleDialogPlayer;
    }
    else
    {
        DialogPlayer = BioWorldInfo(WorldInfo).SimGetConversationManager().GetSimpleDialog('None', $0, DialogLineSr);
    }
    if (DialogPlayer != None)
    {
        DialogPlayer.PlayDialogLine(DialogLineSr, Self);
    }
}
// MILAN CHANGE
// Method used to replicate material parameters to clients
public reliable client function ClientSetMaterialActorParam(MaterialInstanceActor MIA, Name ParamName, bool bScalar, Object.LinearColor VectorValue, float ScalarValue)
{
    if (MIA == None || MIA.MatInst == None)
    {
        return;
    }
    if (bScalar)
    {
        MIA.MatInst.SetScalarParameterValue(ParamName, ScalarValue);
    }
    else
    {
        MIA.MatInst.SetVectorParameterValue(ParamName, VectorValue);
    }
}
// END MILAN CHANGE
public event simulated function Destroyed()
{
    if (IsLocalPlayerController())
    {
        if (GetOnlineSubsystem().GameInterface != None)
        {
            GetOnlineSubsystem().GameInterface.ClearDestroyOnlineGameCompleteDelegate(OnMultiplayerGameDestroyed);
        }
        if (WorldInfo != None && WorldInfo.Game != None && IsLocalPlayerController())
        {
            SFXGame(WorldInfo.Game).ClearCrossLevelReferences();
        }
    }
    if (LobbyFlow != None)
    {
        LobbyFlow.Destroy();
        LobbyFlow = None;
    }
    Super.Destroyed();
}
public function KickPlayer(OnlineSubsystem.UniqueNetId kickedPlayer)
{
    local SFXPlayerControllerMP PC;
    
    if (kickedPlayer == LocalPlayer(Player).GetUniqueNetId())
    {
        foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
        {
            if (PC != None && PC != Self)
            {
                PC.ClientKickPlayer(kickedPlayer);
                return;
            }
        }
    }
    else
    {
        SFXOnlineSubsystem(OnlineSub).GetComponentGame().KickPlayer(kickedPlayer);
    }
}
public function bool LoadingScreenTimedOut(SFXEngine.EWaitMessage WaitMessage)
{
    local SFXEngine Engine;
    local SFXPawn_PlayerMP PlayerPawn;
    
    PlayerPawn = SFXPawn_PlayerMP(Pawn);
    if (PlayerPawn != None && PlayerPawn.bFullyInitializedMP && !WorldInfo.bIsLobbyLevel)
    {
        PlayerPawn.StopLoadingMovie();
        return TRUE;
    }
    if (WorldInfo.NetMode == ENetMode.NM_Standalone)
    {
        return Super.LoadingScreenTimedOut(WaitMessage);
    }
    ShowPleaseWaitMessage(WaitMessage);
    Engine = SFXEngine(Class'SFXEngine'.static.GetEngine());
    Engine.LoadMovieManager.StopLoadingMovie();
     // MILAN Patched: Remove calls to SFXTelemetry
    SetTimer(0.200000003, FALSE, 'ShowLoadingWidget', );
    return TRUE;
}
public exec function Pause()
{
    Super(PlayerController).Pause();
}
public event function PlayerTick(float DeltaTime)
{
    local bool bReadyOnClient;
    
    Super(BioPlayerController).PlayerTick(DeltaTime);
    if (!bFinishedTraveling)
    {
        bReadyOnClient = TRUE;
        if (WorldInfo.NetMode == ENetMode.NM_Client && (Role != ENetRole.ROLE_AutonomousProxy || RemoteRole != ENetRole.ROLE_Authority) && bReceivedPlayer)
        {
            bReadyOnClient = FALSE;
        }
        bFinishedTraveling = bReadyOnClient && PlayerReplicationInfo != None && WorldInfo.GRI != None && !WorldInfo.IsInSeamlessTravel() && BioWorldInfo(WorldInfo).m_UIWorld.m_bLoaded && LobbyFlow != None;
        if (Class'WorldInfo'.static.IsPlayInEditor())
        {
            bFinishedTraveling = TRUE;
        }
    }
}
public event function Possess(Pawn inPawn, bool bVehicleTransition)
{
    Super(BioPlayerController).Possess(inPawn, bVehicleTransition);
    ClearServerMoveExtrapolation();
}
public event simulated function PostBeginPlay()
{
    if (PlayerReplicationInfo == None || !PlayerReplicationInfo.bFromPreviousLevel)
    {
        Super.PostBeginPlay();
    }
    if (IsFinalReleaseBuild() == FALSE)
    {
        CheatManager = new (Self) CheatClass;
        CheatManager.InitCheatManager();
    }
    bFinishedTraveling = FALSE;
    if (LobbyFlow != None)
    {
        LobbyFlow.Destroy();
        LobbyFlow = None;
    }
    if (!WorldInfo.bIsMenuLevel)
    {
        CreateLobbyFlow();
    }
    DeferredCheckLocalPlayer();
}
public event function PreClientTravel(string PendingURL, Actor.ETravelType TravelType, bool bIsSeamlessTravel)
{
    local SFXGUIInteraction SFXUIController;
    local BioSFHandler_MessageBox messageBox;
    
    if (LobbyFlow != None)
    {
        LobbyFlow.ClearCrossLevelReferences();
    }
    if (WorldInfo != None && WorldInfo.Game != None)
    {
        SFXGame(WorldInfo.Game).ClearCrossLevelReferences();
    }
    if (bIsSeamlessTravel)
    {
        if (Pawn != None)
        {
            SFXPawn_PlayerMP(Pawn).PreClientTravel();
        }
        GotoState('Auto', , , );
        PlayerReplicationInfo.bReadyToPlay = FALSE;
        SFXPRIMP(PlayerReplicationInfo).bReplicationReady = FALSE;
        SFXOnlineSubsystem(Class'GameEngine'.static.GetOnlineSubsystem()).GetComponentLogin().SuspendUserPing(TRUE);
        SFXEngine(Class'SFXEngine'.static.GetEngine()).ShowLoadScreen(PendingURL);
        ClearDamageIndicators(None);
        SFXGRI(WorldInfo.GRI).m_pClientEffectPool.FlushAllPools(FALSE);
        if (Role != ENetRole.ROLE_Authority)
        {
            WorldInfo.GRI = None;
        }
    }
    SFXUIController = GetSFXUIController();
    messageBox = SFXUIController.CastGetMovie(Class'BioSFHandler_MessageBox', Self, SFXUIController.MovieTag_MessageBox);
    if (messageBox != None)
    {
        messageBox.HideMessageBox(TRUE, TRUE);
        messageBox.SetGameMode(FALSE, 9);
    }
    Super(BioPlayerController).PreClientTravel(PendingURL, TravelType, bIsSeamlessTravel);
}
public event simulated function ReceivedPlayer()
{
    Super(PlayerController).ReceivedPlayer();
    if (IsLocalPlayerController())
    {
        if (GetOnlineSubsystem() != None && GetOnlineSubsystem().GameInterface != None)
        {
            GetOnlineSubsystem().GameInterface.AddDestroyOnlineGameCompleteDelegate(OnMultiplayerGameDestroyed);
        }
        bReceivedPlayer = TRUE;
    }
}
public event function SetRichPresence()
{
    local array<Settings.LocalizedStringSetting> aContexts;
    local array<Settings.SettingsProperty> aProperties;
    local Settings.LocalizedStringSetting Context;
    local Settings.SettingsProperty Property;
    local LocalPlayer LocPlayer;
    local int nPresenceMode;
    local SFXGRIMP GRIMP;
    local string CharacterName;
    local Name CharacterKit;
    local stringref ClassPrettyName;
    local int Level;
    local int n7Rating;
    local float XP;
    
    LocPlayer = LocalPlayer(Player);
    if (LocPlayer == None)
    {
        return;
    }
    if (Pawn == None || SFXPawn_Player(Pawn) == None || OnlineSub == None || OnlineSub.PlayerInterface == None || SFXPRIMP(PlayerReplicationInfo) == None)
    {
        return;
    }
    GRIMP = SFXGRIMP(WorldInfo.GRI);
    if (GRIMP != None && GRIMP.GameStatus == EGameStatus.GS_MatchInProgress)
    {
        nPresenceMode = 5;
    }
    else
    {
        Context.Id = 1;
        Context.ValueIndex = GetRichPresenceClassContextID();
        Context.AdvertisementType = EOnlineDataAdvertisementType.ODAT_OnlineService;
        aContexts.AddItem(Context);
        SFXPRIMP(PlayerReplicationInfo).GetCharacterData(CharacterName, CharacterKit, ClassPrettyName, Level, XP, n7Rating);
        Property.PropertyId = 268435458;
        Class'Settings'.static.SetSettingsDataInt(Property.Data, Level);
        Property.AdvertisementType = EOnlineDataAdvertisementType.ODAT_OnlineService;
        aProperties.AddItem(Property);
        nPresenceMode = 3;
    }
    OnlineSub.PlayerInterface.SetOnlineStatus(byte(LocPlayer.ControllerId), nPresenceMode, aContexts, aProperties);
    SetRichPresenceForIdlePlayers();
}
public exec function StopLoadingMovie()
{
    local SFXEngine Engine;
    local SFXGUIInteraction GUIManager;
    
    Engine = SFXEngine(Class'SFXEngine'.static.GetEngine());
    GUIManager = Class'SFXGUIInteraction'.static.GetInstance();
    if (GUIManager != None)
    {
        GUIManager.RemoveNamedMessageBox('LoadingScreenTimeout', Self);
        GUIManager.GetSaveLoadWidget().HideLoadingMessage(TRUE);
        GUIManager.HideBlackScreen(Self, FALSE);
    }
    ClearTimer('ShowPleaseWaitMessage');
    ClearTimer('ShowExitConfirmation');
    Engine.CloseLoadScreen(TRUE);
    SFXOnlineSubsystem(OnlineSub).GetComponentLogin().SuspendUserPing(FALSE);
    // MILAN CHANGE - 10/17/2026
    // Turn back on force feedback system
    if (ForceFeedbackManager != None)
    {
        ForceFeedbackManager.bAllowsForceFeedback = TRUE;
    }
    // END MILAN CHANGE
}
public event function SwitchWeapon(SFXWeapon_NativeBase oWpn)
{
    local SFXInventoryManager oInventory;
    local BioPawn PlayerPawn;
    
    PlayerPawn = BioPawn(Pawn);
    if (PlayerPawn != None)
    {
        oInventory = SFXInventoryManager(PlayerPawn.InvManager);
        if (oInventory != None)
        {
            oInventory.SetWeaponIfAvailable(SFXWeapon(oWpn));
        }
        if (PlayerPawn.IsInCoverLeaning())
        {
            PlayerPawn.CoverAction = PlayerPawn.GetDefaultCoverAction();
        }
    }
}
public event reliable client function TeamMessage(PlayerReplicationInfo PRI, coerce string S, Name Type, optional float MsgLifeTime)
{
    if (Type != 'Say')
    {
        return;
    }
    if (myHUD != None)
    {
        myHUD.Message(PRI, S, Type, MsgLifeTime);
    }
}
public event function UpdateLocalProfileSettingsCache()
{
    local SFXEngine Engine;
    
    Super(BioPlayerController).UpdateLocalProfileSettingsCache();
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Engine != None && Engine.LoadMovieManager.IsLoadingMoviePlaying() && ForceFeedbackManager != None)
    {
        ForceFeedbackManager.bAllowsForceFeedback = FALSE;
    }
}
public function CleanupPawn()
{
    local BioPawn PawnAsBioPawn;
    
    PawnAsBioPawn = BioPawn(Pawn);
    PawnAsBioPawn.SetHidden(TRUE);
    PawnAsBioPawn.Destroy();
}
public reliable client function ClientWriteLeaderboardStats(Class<OnlineStatsWrite> OnlineStatsWriteClass)
{
    local OnlineStatsWrite OnlineStats;
    local SFXSaveManagerMP MPSaveManager;
    local SFXAccomplishmentManager AccManager;
    local int n7Rating;
    local int ChallengePoints;
    
    OnlineStats = new OnlineStatsWriteClass;
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    AccManager = SFXEngine(Class'Engine'.static.GetEngine()).AccomplishmentManager;
    if (OnlineSub != None && OnlineSub.StatsInterface != None)
    {
        n7Rating = MPSaveManager.GetN7Rating();
        OnlineStats.SetIntStat(0, n7Rating);
        if (AccManager != None)
        {
            ChallengePoints = AccManager.GetTotalChallengePoints();
        }
        OnlineStats.SetIntStat(1, ChallengePoints);
        OnlineSub.StatsInterface.WriteOnlineStats('Game', LocalPlayer(Player).GetUniqueNetId(), OnlineStats);
        OnlineSub.StatsInterface.FlushOnlineStats('Game');
    }
}
public reliable client simulated function ClientWriteOnlinePlayerScores(int LeaderboardId);

public simulated function EnterStartState()
{
    if (WorldInfo.bIsLobbyLevel)
    {
        GotoState('InLobby', , , );
    }
    else
    {
        Super.EnterStartState();
    }
}
public function bool GamePlayEndedState()
{
    return TRUE;
}
public function OnControllerChanged(int ControllerId, bool bIsConnected)
{
    Super(BioPlayerController).OnControllerChanged(ControllerId, bIsConnected);
    if (!bIsConnected && LocalPlayer(Player).ControllerId == ControllerId)
    {
        if (GetOnlineSubsystem() != None && GetOnlineSubsystem().GameInterface != None)
        {
            if (Class'WorldInfo'.static.IsConsoleBuild(2))
            {
                GetOnlineSubsystem().GameInterface.CancelFindOnlineGames();
            }
        }
    }
}
public exec function QuickLoad();

public reliable server function ServerSuicide()
{
    if (Pawn != None)
    {
        Pawn.Suicide();
    }
}
public function bool SetPause(bool bPause, optional delegate<PlayerController.CanUnpause> CanUnpauseDelegate = CanUnpause)
{
    if (WorldInfo.Game.bPauseable == FALSE)
    {
        return FALSE;
    }
    Super(PlayerController).SetPause(bPause, CanUnpause);
}
public simulated function BeginCountdownTimer(float CountdownTime, float CountdownWarningTime)
{
    local SFXGUI_MPHUD oMPHUD;
    
    oMPHUD = GetMPHUD();
    if (oMPHUD == None)
    {
        return;
    }
    CountdownTimerEndTime = CountdownTime + WorldInfo.GameTimeSeconds;
    oMPHUD.StartCountdownTimer(CountdownTime, CountdownWarningTime);
}
public reliable client function CancelCountdownTimer()
{
    local SFXGUI_MPHUD oMPHUD;
    
    oMPHUD = GetMPHUD();
    if (oMPHUD == None)
    {
        return;
    }
    oMPHUD.CancelCountdownTimer();
}
public exec function CastPower(int nIndex)
{
    if (BioPlayerInput(PlayerInput).IsCombatEnabled() == FALSE || nIndex >= BioPawn(Pawn).PowerManager.Powers.Length)
    {
        return;
    }
    SquadOrderUsePower(BioPawn(Pawn).PowerManager.Powers[nIndex].PowerName, Pawn);
}
public reliable client function ClientShowExtractionCredits(float Credits)
{
    local int RoundedCredits;
    
    Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound('MPBonusCreditsEarned');
    RoundedCredits = Round(Credits);
    ClearCustomTokens();
    SetCustomToken(0, string(RoundedCredits));
    DisplayTextPopup(string(Class'SFXScoreManager'.default.srExtractionCreditsEarned));
    ClearCustomTokens();
    HintSystem.AddNotification_CreditRecovery(int(Credits));
}
public simulated function DisplayDebugScore()
{
    local string Output;
    local int idx;
    
    for (idx = 0; idx < WorldInfo.GRI.PRIArray.Length; idx++)
    {
        if (WorldInfo.GRI.PRIArray[idx].bBot == FALSE)
        {
            Output $= SFXPRIMP(WorldInfo.GRI.PRIArray[idx]).ComputerName $ " " $ SFXPRIMP(WorldInfo.GRI.PRIArray[idx]).GetTotalPoints() $ "\n";
        }
    }
    BioHUD(myHUD).AddDesignerText('DebugScore', Output, 80.0, 75.0, 0.0, 1.0);
}
public simulated function float GetRemainingCountdownTime()
{
    local float TimeRemaining;
    
    TimeRemaining = CountdownTimerEndTime - WorldInfo.GameTimeSeconds + CountdownTimerLeeway;
    TimeRemaining = float(Max(0, int(TimeRemaining)));
    return TimeRemaining;
}
public function HideInGameConsumableUI()
{
    local SFXGUI_MPHUD oMPHUD;
    
    oMPHUD = GetMPHUD();
    if (oMPHUD == None)
    {
        return;
    }
    oMPHUD.HideDPadPowerIcons();
}
public function Internal_ResetPlayerController(Object.Vector NewLocation)
{
    local BioPawn PawnAsBioPawn;
    
    ClearServerMoveExtrapolation();
    PawnAsBioPawn = BioPawn(Pawn);
    if (PawnAsBioPawn != None)
    {
        if (PawnAsBioPawn.bTearOff)
        {
            return;
        }
        if (PawnAsBioPawn.IsDead() && PawnAsBioPawn.Role == ENetRole.ROLE_Authority)
        {
            PawnAsBioPawn.Resurrect(1.0, TRUE);
        }
        if (PawnAsBioPawn.IsInCover() == TRUE || PawnAsBioPawn.CoverAction == ECoverAction.CA_Aimback)
        {
            PawnAsBioPawn.LeaveCover();
        }
        PawnAsBioPawn.ShouldCrouch(FALSE);
        if (PawnAsBioPawn.Physics == EPhysics.PHYS_RigidBody)
        {
            if (!PawnAsBioPawn.TermRagdoll())
            {
            }
        }
        else
        {
            PawnAsBioPawn.SetPhysics(1);
        }
        PawnAsBioPawn.StopMovement(TRUE);
        ResetCameraMode();
        SetViewTarget(PawnAsBioPawn);
        PawnAsBioPawn.GotoState('Auto', , , );
    }
    GotoState('PlayerWalking', , , );
    ForceLocation(NewLocation);
    if (PawnAsBioPawn != None)
    {
        PawnAsBioPawn.MoveActorToFloor();
    }
}
public function InternalSawNewEnemy(const out BioPawn EnemyPawn)
{
    local SFXGRI GRI;
    local SFXWaveCoordinator_HordeOperation WaveCoordinator;
    
    GRI = SFXGRI(WorldInfo.GRI);
    if (GRI != None)
    {
        WaveCoordinator = SFXWaveCoordinator_HordeOperation(GRI.WaveCoordinator);
        if (Role == ENetRole.ROLE_Authority && WaveCoordinator != None && EnemyPawn != None && WaveCoordinator.HasSeenEnemyType[int(EnemyPawn.CharacterType)] == FALSE)
        {
            if (WorldInfo.GameTimeSeconds - WaveCoordinator.LastSawEnemyTypeShoutTime > SawEnemyTypeShoutCooldownTime)
            {
                WaveCoordinator.LastSawEnemyTypeShoutTime = WorldInfo.GameTimeSeconds;
                GRI.TriggerVocalizationEvent(132, BioPawn(Pawn), EnemyPawn, , , TRUE);
            }
            WaveCoordinator.HasSeenEnemyType[int(EnemyPawn.CharacterType)] = TRUE;
        }
    }
}
public simulated function MPBotsClearUsed()
{
    if (BioCheatManagerNonNative(CheatManager) != None)
    {
        BioCheatManagerNonNative(CheatManager).MPBotsClearUsedLast();
    }
}
public function OnGameConnectionLost()
{
    Super.OnGameConnectionLost();
}
public simulated function OnWaveFinished()
{
    local SFXAccomplishmentManager AccomplishmentManager;
    local SFXGRIMP GRI;

    // MILAN CHANGE DropTheSquid 1/11/2024
    // I don't know why this is being called here, but it is pretty useless. it gets shown again immediately by MPHud update
    // it just causes it to do the entry animation again at the end of each wave. removing it fixes that.
    // HideInGameConsumableUI();
    // END MILAN
    if (IsLocalPlayerController())
    {
        GRI = SFXGRIMP(WorldInfo.GRI);
        if (GRI != None && GRI.GameStatus == EGameStatus.GS_MatchInProgress)
        {
            AccomplishmentManager = SFXEngine(Class'Engine'.static.GetEngine()).AccomplishmentManager;
            AccomplishmentManager.UpdateWaveChallenges(Self);
        }

        // MILAN CHANGE - d00t - 2026-11-13
        // Move this after the challenges get updated so that we persist them to the profile.
        SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager.SaveRecords(TRUE);
        // END MILAN CHANGE
    }
}
public function PulsePowerDisplay()
{
    local SFXGUI_MPHUD oMPHUD;
    
    oMPHUD = GetMPHUD();
    if (oMPHUD == None)
    {
        return;
    }
    oMPHUD.ShowDPadPowerIcons();
}
public function SetAFKLastActionTime(bool isMovementCheck)
{
    if (isMovementCheck && AFKIgnoreMovementCheck)
    {
        return;
    }
    else if (!isMovementCheck && AFKIgnoreWeaponAndPowerCheck)
    {
        return;
    }
    if (!IsAFKPostponementActive)
    {
        AFKLastActionTime = WorldInfo.TimeSeconds;
    }
}
public simulated function SetObjectiveCircleProgress(int nNumComplete)
{
    local SFXGUI_MPHUD oMPHUD;
    
    oMPHUD = GetMPHUD();
    if (oMPHUD == None)
    {
        return;
    }
    oMPHUD.SetObjectiveCircleProgress(nNumComplete);
}
public simulated function SetObjectiveCircleText(const string s1, const string s2, const string s3, const string s4)
{
    local SFXGUI_MPHUD oMPHUD;
    
    oMPHUD = GetMPHUD();
    if (oMPHUD == None)
    {
        return;
    }
    oMPHUD.SetObjectiveCircleText(s1, s2, s3, s4);
}
public simulated function SetScoreHudObjectiveProgress(float Progress, optional bool bBoostAnim = FALSE)
{
    local SFXGUI_MPHUD oMPHUD;
    
    oMPHUD = GetMPHUD();
    if (oMPHUD == None)
    {
        return;
    }
    oMPHUD.SetObjectiveBarProgress(Progress, bBoostAnim);
}
public simulated function SetScoreHudObjectiveText(stringref ObjectiveText)
{
    local SFXGUI_MPHUD oMPHUD;
    
    oMPHUD = GetMPHUD();
    if (oMPHUD == None)
    {
        return;
    }
    oMPHUD.SetObjectiveText(ObjectiveText);
}
public function UpdateInGameConsumableUI()
{
    local SFXGUI_MPHUD oMPHUD;
    
    oMPHUD = GetMPHUD();
    if (oMPHUD == None)
    {
        return;
    }
    oMPHUD.UpdateDPadPowerIcons();
}
public exec function ViewNextPlayer()
{
    GotoState('SpectateCam', , , );
}
public delegate function OnWeaponSelectFinishedDelegate();

public function bool PawnNeedsCleanup()
{
    local SFXPawn_PlayerMP oPawn;
    local SFXPRIMP oPRI;
    
    if (IsInState('InLobby', ))
    {
        return TRUE;
    }
    else
    {
        oPawn = SFXPawn_PlayerMP(Pawn);
        oPRI = SFXPRIMP(PlayerReplicationInfo);
        return oPawn != None && oPRI != None && oPawn.Kit != oPRI.GetCharacterKit();
    }
}
public function bool PlayerHasCreditsToSpend()
{
    local SFXEngine Engine;
    
    Engine = SFXEngine(Class'SFXEngine'.static.GetEngine());
    return Engine.MPSaveManager.GetCredits() > 0;
}
public function bool PlayerHasTalentPointsToSpend()
{
    local SFXEngine Engine;
    local SFXMPCharacterRecord CharacterRecord;
    
    Engine = SFXEngine(Class'SFXEngine'.static.GetEngine());
    CharacterRecord = Engine.MPSaveManager.GetCurrentSelectedCharacterRecord();
    return CharacterRecord.HasLeveledUp();
}
public final function PleaseWait_Callback(bool bAPressed, int nContext)
{
    SetTimer(0.100000001, FALSE, 'ShowExitConfirmation', );
}
public simulated function RefreshLobbyScreen()
{
    local SFXGUIInteraction Manager;
    local SFXGUI_MPLobby LobbyScreen;
    
    Manager = Class'SFXGUIInteraction'.static.GetInstance();
    LobbyScreen = Manager.CastGetMovie(Class'SFXGUI_MPLobby', Self, LobbyFlow.LobbyScreenTag);
    if (LobbyScreen != None)
    {
        LobbyScreen.Refresh();
    }
}
public final function RefreshLobbyStatusBars()
{
    local SFXGUIInteraction oGUI;
    local SFXGUI_MPLobbyStatusBars LobbyStatusBars;
    
    oGUI = Class'SFXGUIInteraction'.static.GetInstance();
    LobbyStatusBars = oGUI.CastGetMovie(Class'SFXGUI_MPLobbyStatusBars', Self, oGUI.MovieTag_MPLobbyStatusBars);
    if (LobbyStatusBars != None)
    {
        LobbyStatusBars.Refresh();
    }
}
public simulated function ResetSaveTimer()
{
    ClearTimer('TickSaveGame');
    if (!IsLocalPlayerController())
    {
        return;
    }
    SetTimer(TickSaveGameInterval, TRUE, 'TickSaveGame', );
}
public reliable server function ServerWaveCoordinatorJoinInProgress(SFXWaveCoordinator_HordeOperation Coordinator)
{
    Coordinator.HandleJoinInProgress();
}
public simulated function ShowCustomMatchScreen()
{
    local SFXGUIInteraction Manager;
    local SFXGUI_MPLobby LobbyScreen;
    
    Manager = Class'SFXGUIInteraction'.static.GetInstance();
    LobbyScreen = Manager.CastGetMovie(Class'SFXGUI_MPLobby', Self, LobbyFlow.LobbyScreenTag);
    if (LobbyScreen != None)
    {
        LobbyScreen.LoadTab(2);
    }
}
public reliable client function ShowEndOfMatchUI(int WaveNumber)
{
    local SFXGUIInteraction Manager;
    
    Manager = Class'SFXGUIInteraction'.static.GetInstance();
    Manager.CastGetMovie(Class'SFXGUI_PlayerCountdown', Self, Manager.MovieTag_PlayerCountdown).AbortAnimation(0);
}
public final function ShowExitConfirmation()
{
    local string sMsg;
    local BioDefine.BioMessageBoxOptionalParams Params;
    
    if (WorldInfo.bIsLobbyLevel)
    {
        sMsg = Class'SFXGame'.static.GetSimpleString(srExitMessageLobby);
    }
    else
    {
        sMsg = Class'SFXGame'.static.GetSimpleString(srExitMessage);
    }
    Params.srAText = srConfirm;
    Params.srBText = srCancel;
    Params.bModal = TRUE;
    Class'SFXGUIInteraction'.static.GetInstance().QueueNamedMessageBoxEx('LoadingScreenTimeout', 1, sMsg, Params, ExitConformation_Callback);
}
public function ShowLevelUpUI(optional delegate<SFXGUI_SquadRecord.OnCloseCallback> onClosedDelegate)
{
    SpawnLevelUpScreen(onClosedDelegate);
}
public function ShowLoadingWidget()
{
    Class'SFXGUIInteraction'.static.GetInstance().GetSaveLoadWidget().ShowLoadingMessage(TRUE);
}
public simulated function ShowLobbyScreen()
{
    local SFXGUIInteraction Manager;
    
    Manager = Class'SFXGUIInteraction'.static.GetInstance();
    Manager.OpenMovie(Self, LobbyFlow.LobbyScreenTag);
}
public final function ShowLobbyStatusBars()
{
    local SFXGUIInteraction oGUI;
    
    oGUI = Class'SFXGUIInteraction'.static.GetInstance();
    oGUI.OpenMovie(Self, oGUI.MovieTag_MPLobbyStatusBars);
}
public simulated function ShowMatchConsumablesScreen()
{
    local SFXGUIInteraction Manager;
    
    Manager = Class'SFXGUIInteraction'.static.GetInstance();
    Manager.OpenMovie(Self, Manager.MovieTag_MPMatchConsumables);
}
public simulated function ShowMatchResultsScreen()
{
    local SFXGUIInteraction Manager;
    
    Manager = Class'SFXGUIInteraction'.static.GetInstance();
    Manager.OpenMovie(Self, Manager.MovieTag_MPMatchResults);
}
public simulated function ShowMatchSettingsScreen()
{
    local SFXGUIInteraction Manager;
    local SFXGUI_MPLobby LobbyScreen;
    
    Manager = Class'SFXGUIInteraction'.static.GetInstance();
    LobbyScreen = Manager.CastGetMovie(Class'SFXGUI_MPLobby', Self, LobbyFlow.LobbyScreenTag);
    if (LobbyScreen != None)
    {
        LobbyScreen.LoadTab(2);
    }
}
public simulated function ShowMPAppearanceScreen()
{
    local SFXGUIInteraction Manager;
    
    Manager = Class'SFXGUIInteraction'.static.GetInstance();
    Manager.OpenMovie(Self, Manager.MovieTag_MPAppearance);
}
public final function ShowMPEndOfMatchScreen()
{
    local SFXGUIInteraction Manager;
    
    Manager = Class'SFXGUIInteraction'.static.GetInstance();
    Manager.OpenMovie(Self, Manager.MovieTag_MPEndOfMatch);
}
public simulated function ShowMPSelectKitScreen()
{
    local SFXGUIInteraction Manager;
    
    Manager = Class'SFXGUIInteraction'.static.GetInstance();
    Manager.OpenMovie(Self, Manager.MovieTag_MPSelectKit);
}
public function ShowMPStoreUI(optional int PromotionalStoreID = -1, optional bool bProcessPurchases = TRUE)
{
    local SFXGUIInteraction Manager;
    
    Manager = Class'SFXGUIInteraction'.static.GetInstance();
    Manager.PlayGuiSound('MPStoreStart');
    StoreGUI = Manager.CastOpenMovie(Class'SFXGUI_MPStore', Self, Manager.MovieTag_MPStore, FALSE);
    StoreGUI.SetInitialSelectedStoreID(PromotionalStoreID);
    StoreGUI.bProcessPurchases = bProcessPurchases;
    StoreGUI.Start();
}
public function ShowPleaseWaitMessage(SFXEngine.EWaitMessage WaitMessage)
{
    local SFXGUIInteraction GUIManager;
    local BioDefine.BioMessageBoxOptionalParams Params;
    local stringref srWaitMessage;
    local string sMsg;
    
    GUIManager = Class'SFXGUIInteraction'.static.GetInstance();
    if (GUIManager != None)
    {
        GUIManager.ShowBlackScreen(Self, FALSE);
        srWaitMessage = srWaitMessageGeneric;
        if (WaitMessage == EWaitMessage.EWaitMessage_MatchStarted)
        {
            srWaitMessage = srWaitMessageMatchStarted;
        }
        else if (WaitMessage == EWaitMessage.EWaitMessage_MatchEnded)
        {
            srWaitMessage = srWaitMessageMatchEnded;
        }
        sMsg = Class'SFXGame'.static.GetSimpleString(srWaitMessage);
        Params.srBText = srCancel;
        Params.bModal = TRUE;
        GUIManager.QueueNamedMessageBoxEx('LoadingScreenTimeout', 1, sMsg, Params, PleaseWait_Callback);
    }
}
public final function ShowPromotionScreen()
{
    local SFXGUIInteraction oGUI;
    
    oGUI = Class'SFXGUIInteraction'.static.GetInstance();
    oGUI.OpenMovie(Self, oGUI.MovieTag_MPPromotion);
}
public simulated function ShowReinforcementsRevealScreeen(optional delegate<SFXGUI_MPReinforcementsReveal.OnCloseCallback> onClosedDelegate)
{
    local SFXGUIMovie NewPanel;
    local SFXGUIInteraction Manager;
    local SFXGUI_MPReinforcementsReveal RevealScreen;
    
    Manager = Class'SFXGUIInteraction'.static.GetInstance();
    NewPanel = Manager.OpenMovie(Self, Manager.MovieTag_MPReinforcementsReveal);
    if (NewPanel != None)
    {
        RevealScreen = SFXGUI_MPReinforcementsReveal(NewPanel);
        RevealScreen.SetOnCloseCallback(onClosedDelegate);
    }
}
public final function ShowStoreScreenFromPromotion(optional int PromotionalStoreID)
{
    local SFXGUIInteraction oGUI;
    local SFXGUI_MPLobby Lobby;
    local SFXGUI_MPSelectKit KitSelect;
    
    oGUI = Class'SFXGUIInteraction'.static.GetInstance();
    Lobby = oGUI.CastGetMovie(Class'SFXGUI_MPLobby', Self, LobbyFlow.LobbyScreenTag);
    if (Lobby != None)
    {
        oGUI.RemoveMovie(Self, LobbyFlow.LobbyScreenTag);
    }
    KitSelect = oGUI.CastGetMovie(Class'SFXGUI_MPSelectKit', Self, oGUI.MovieTag_MPSelectKit);
    if (KitSelect != None)
    {
        oGUI.RemoveMovie(Self, oGUI.MovieTag_MPSelectKit);
    }
    ShowMPStoreUI(PromotionalStoreID);
}
public function ShowWeaponSelectionUI(optional delegate<SFXPlayerControllerMP.OnWeaponSelectFinishedDelegate> OnFinishedDelegate)
{
    local SeqEvent_RemoteEvent WeaponEvent;
    
    WeaponEvent = Class'SeqEvent_RemoteEvent'.static.FindRemoteEvent('OpenMPWeaponSelect');
    WeaponEvent.CheckActivate(Self, Self);
    OnWeaponSelectFinishedDelegate = OnFinishedDelegate;
}
public function SpawnLevelUpScreen(optional delegate<SFXGUI_SquadRecord.OnCloseCallback> onClosedDelegate)
{
    local SFXGUIMovie NewPanel;
    local SFXGUIInteraction Manager;
    
    Manager = Class'SFXGUIInteraction'.static.GetInstance();
    NewPanel = Manager.OpenMovie(Self, Manager.MovieTag_SquadRecord, TRUE);
    if (NewPanel != None)
    {
        LevelUpGUI = SFXGUI_SquadRecord(NewPanel);
        LevelUpGUI.SetRequiresUIWorld(TRUE);
        LevelUpGUI.SetOnCloseCallback(onClosedDelegate);
    }
    else
    {
        FinishedLevelUpUI();
    }
}
public exec function Spectate()
{
    if (IsInState('SpectateCam', ))
    {
        GotoState('PlayerWalking', , , );
    }
    else
    {
        GotoState('SpectateCam', , , );
    }
}
public simulated function TickSaveGame()
{
    local SFXSaveManagerMP MPSaveManager;
    
    if (!IsLocalPlayerController())
    {
        ClearTimer('TickSaveGame');
        return;
    }
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    if (MPSaveManager != None && MPSaveManager.bInitialized)
    {
        MPSaveManager.SaveRecords();
    }
}
public event simulated function UpdateMPMapsCompleted(Name MapName, bool bIsGoldMap)
{
    local Name PlayedMaps;
    local Name PlayedMapsCount;
    
    PlayedMaps = bIsGoldMap ? 'MPPLAYEDMAPSGOLD' : 'MPPLAYEDMAPS';
    PlayedMapsCount = bIsGoldMap ? 'MPMAPSGOLDCOUNT' : 'MPMAPSCOUNT';
    UpdateMapsCompletedHelper(MapName, PlayedMaps, PlayedMapsCount, MPMapNames);
}
public exec function ViewPrevPlayer()
{
    GotoState('SpectateCam', 'PrevPlayer', , );
}
public exec function VoicePushToTalkEnd()
{
    Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentVoiceInterface().PushToTalkEnd();
}
public exec function VoicePushToTalkStart()
{
    Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentVoiceInterface().PushToTalkStart();
}
public exec function AFK()
{
    if (IsLocalPlayerController())
    {
        if (!IsTimerActive('DoAFKTick'))
        {
            ClientMessage("AFK timer - INACTIVE");
        }
        else if (IsAFKPostponementActive)
        {
            ClientMessage("AFK timer - PAUSED: if no reset occurs, will be kicked in" @ AFKTimeLimitSeconds - (AFKPostponementStartTime - AFKLastActionTime) @ "seconds.");
        }
        else
        {
            ClientMessage("AFK timer - ACTIVE: will be kicked in" @ AFKTimeLimitSeconds - (WorldInfo.TimeSeconds - AFKLastActionTime) @ "seconds.");
        }
    }
}
private final function BackToMainMenu(bool bAPressed, int Context)
{
    local ISFXOnlineComponentGameFlow oGameFlow;
    
    oGameFlow = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentGameFlow();
    if (oGameFlow != None)
    {
        oGameFlow.GM_OnNetworkErrorDismissed();
    }
    ClientTravel("EntryMenu?nosplash?", 0);
}
public exec function BioTalk()
{
    local Console PlayerConsole;
    
    if (WorldInfo.NetMode == ENetMode.NM_Standalone)
    {
        return;
    }
    PlayerConsole = LocalPlayer(Player).ViewportClient.ViewportConsole;
    PlayerConsole.GotoState('Say', , , );
}
// SFXGameMPContent.SFXPlayerControllerMP.CheckIfConnectedFailsafe - 12/10/2023
// By Mgamerz
// Patches out the online failsafe check which brings up 'you have lost connection to the server'
public function bool CheckIfConnectedFailsafe()
{
    return TRUE;
}

public reliable client function ClientKickPlayer(OnlineSubsystem.UniqueNetId kickedPlayer)
{
    SFXOnlineSubsystem(OnlineSub).GetComponentGame().KickPlayer(kickedPlayer);
}
public simulated function CreateLobbyFlow()
{
    if (WorldInfo.NetMode == ENetMode.NM_Standalone)
    {
        LobbyFlow = Spawn(Class'SFXLobbyFlow', Self);
    }
    else if (bReceivedPlayer)
    {
        if (IsLocalPlayerController())
        {
            LobbyFlow = Spawn(Class'SFXLobbyFlow', Self);
        }
    }
    else if (!IsTimerActive('CreateLobbyFlow'))
    {
        SetTimer(0.100000001, FALSE, 'CreateLobbyFlow', );
    }
}
public exec function DebugSwapController();

public simulated function DeferredCheckLocalPlayer()
{
    local SFXGRIMP GRIMP;
    local SFXGRIMP_Lobby GRIMP_Lobby;
    
    if (Player == None || WorldInfo.GRI == None)
    {
        SetTimer(0.100000001, FALSE, 'DeferredCheckLocalPlayer', );
        return;
    }
    if (IsLocalPlayerController())
    {
        ResetSaveTimer();
        GRIMP = SFXGRIMP(WorldInfo.GRI);
        GRIMP_Lobby = SFXGRIMP_Lobby(WorldInfo.GRI);
        if (IsTimerActive('DoAFKTick'))
        {
            ClearTimer('DoAFKTick');
        }
        if (AFKTimeLimitSeconds > float(0) && GRIMP_Lobby == None && GRIMP != None && GRIMP.PrivacySetting == 0)
        {
            IsAFKPostponementActive = FALSE;
            AFKLastActionTime = WorldInfo.TimeSeconds;
            SetTimer(float(AFKTickTime), TRUE, 'DoAFKTick', );
        }
    }
}
public function DoAFKTick()
{
    local BioPlayerInput BPI;
    local SFXOnlineSubsystem oOnlineSubsystem;
    local ISFXOnlineComponentGame oOnlineGame;
    // MILAN CHANGE - Add GRIMP
    local SFXGRIMP GRIMP;
    // END MILAN CHANGE

    BPI = BioPlayerInput(PlayerInput);
    if (BPI != None)
    {
        if (BPI.MoveStick.X != AFKLastMoveStick.X || BPI.MoveStick.Y != AFKLastMoveStick.Y)
        {
            SetAFKLastActionTime(TRUE);
            AFKLastMoveStick = BPI.MoveStick;
        }
        if (IsInState('InLobby', ) || IsInState('RoundEnded', ) || IsInState('PlayerWaiting', ))
        {
            AFKLastActionTime = WorldInfo.TimeSeconds;
            return;
        }

        // MILAN CHANGE - Mgamerz - 2026-10-31
        // If there's only 1 player (you), don't AFK kick.
        // Why should we do that? You can idle in your own game all you want.
        GRIMP = SFXGRIMP(WorldInfo.GRI);
        if (GRIMP != None && GRIMP.PRIArray.Length <= 1)
        {
            if (!IsAFKPostponementActive)
            {
                AFKPostponementStartTime = WorldInfo.TimeSeconds;
                IsAFKPostponementActive = TRUE;
            }
        }
        // END MILAN CHANGE
        // MILAN CHANGE - Mgamerz - 2026-10-31
        // MilanPhotoMode extends BaseSpectating, not Spectating, so it needs its own entry
        // or players get kicked for being AFK even though they're technically spectating
        else if (IsInState('Dead', ) || IsInState('Dying', ) || IsInState('SpectateCam', ) || IsInState('Spectating', ) || IsInState('MilanPhotoMode', ))
        {
            if (!IsAFKPostponementActive)
            {
                AFKPostponementStartTime = WorldInfo.TimeSeconds;
                IsAFKPostponementActive = TRUE;
            }
        }
        else if (IsAFKPostponementActive)
        {
            IsAFKPostponementActive = FALSE;
            AFKLastActionTime += WorldInfo.TimeSeconds - AFKPostponementStartTime;
        }
        if (!IsAFKPostponementActive)
        {
            if (WorldInfo.TimeSeconds - AFKLastActionTime > AFKTimeLimitSeconds)
            {
                ClearTimer('DoAFKTick');
                 // MILAN Patched: Remove calls to SFXTelemetry
                oOnlineSubsystem = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem();
                if (oOnlineSubsystem != None)
                {
                    oOnlineGame = oOnlineSubsystem.GetComponentGame();
                    if (oOnlineGame != None)
                    {
                        oOnlineGame.LeaveGame();
                    }
                }
                Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentGame().SetKickedOutOfGame(TRUE);
                ConsoleCommand("Disconnect");
            }
        }
    }
}
public final function ExitConformation_Callback(bool bAPressed, int nContext)
{
    if (bAPressed)
    {
        ConsoleCommand("open mplobby");
    }
    else
    {
        SetTimer(0.100000001, FALSE, 'ShowPleaseWaitMessage', );
    }
}
public function FinishedLevelUpUI()
{
    local SFXEngine Engine;
    local SFXMPCharacterRecord CharacterRecord;
    local SFXPRIMP PRI;
    local SFXGUIInteraction Manager;
    
    Engine = SFXEngine(Class'SFXEngine'.static.GetEngine());
    CharacterRecord = Engine.MPSaveManager.GetCurrentSelectedCharacterRecord();
    CharacterRecord.SetPowersFromPawn(SFXPawn(Pawn));
    CharacterRecord.RecalculateTalentPoints();
    CharacterRecord.SetLeveledUp(FALSE);
    Engine.MPSaveManager.SaveRecords();
    PRI = SFXPRIMP(PlayerReplicationInfo);
    PRI.LoadPowerDataFromSave(CharacterRecord);
    Manager = Class'SFXGUIInteraction'.static.GetInstance();
    if (Manager != None)
    {
        Manager.RemoveMovie(Self, Manager.MovieTag_SquadRecord);
    }
    LevelUpGUI = None;
}
public function FinishedMPStoreUI()
{
    local SFXEngine Engine;
    local SFXMPCharacterRecord CharacterRecord;
    local SFXPRIMP PRI;
    
    Engine = SFXEngine(Class'SFXEngine'.static.GetEngine());
    Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound('MPStoreFinished');
    Engine.MPSaveManager.SaveRecords();
    CharacterRecord = Engine.MPSaveManager.GetCurrentSelectedCharacterRecord();
    PRI = SFXPRIMP(PlayerReplicationInfo);
    PRI.LoadDataFromSave(CharacterRecord);
    CharacterRecord.TransferCharacterDataToPawn(SFXPawn_PlayerMP(Pawn));
}
public function FinishedWeaponSelectionUI()
{
    local SFXEngine Engine;
    local SFXMPCharacterRecord CharacterRecord;
    local SFXPRIMP PRI;
    
    Engine = SFXEngine(Class'Engine'.static.GetEngine());
    CharacterRecord = Engine.MPSaveManager.GetCurrentSelectedCharacterRecord();
    CharacterRecord.InitializeWeaponsFromEnginePlayerLoadout();
    Engine.MPSaveManager.SaveRecords();
    PRI = SFXPRIMP(PlayerReplicationInfo);
    PRI.LoadWeaponDataFromSave(CharacterRecord);
    SFXPawn_PlayerMP(Pawn).LoadWeapons();
    SFXPawn_PlayerMP(Pawn).LoadWeaponModData();
    SFXPawn_PlayerMP(Pawn).UpdateWeaponEncumbrance();
}
public final function SFXGUI_MPHUD GetMPHUD()
{
    local SFXGUIInteraction oGUI;
    
    oGUI = Class'SFXGUIInteraction'.static.GetInstance();
    if (oGUI == None)
    {
        return None;
    }
    return SFXGUI_MPHUD(oGUI.GetMovie(Self, oGUI.MovieTag_MPHUD));
}
public simulated function HideCustomMatchScreen()
{
    local SFXGUIInteraction Manager;
    local SFXGUI_MPLobby LobbyScreen;
    
    Manager = Class'SFXGUIInteraction'.static.GetInstance();
    LobbyScreen = Manager.CastGetMovie(Class'SFXGUI_MPLobby', Self, LobbyFlow.LobbyScreenTag);
    if (LobbyScreen != None)
    {
        LobbyScreen.LoadTab(11);
    }
}
public simulated function HideLobbyScreen()
{
    local SFXGUIInteraction Manager;
    
    Manager = Class'SFXGUIInteraction'.static.GetInstance();
    Manager.RemoveMovie(Self, LobbyFlow.LobbyScreenTag);
}
public final function HideLobbyStatusBars()
{
    local SFXGUIInteraction oGUI;
    
    oGUI = Class'SFXGUIInteraction'.static.GetInstance();
    oGUI.RemoveMovie(Self, oGUI.MovieTag_MPLobbyStatusBars);
}
public simulated function HideMatchResultsScreen()
{
    local SFXGUIInteraction Manager;
    
    Manager = Class'SFXGUIInteraction'.static.GetInstance();
    Manager.RemoveMovie(Self, Manager.MovieTag_MPMatchResults);
}
public simulated function HideMatchSettingsScreen()
{
    local SFXGUIInteraction Manager;
    local SFXGUI_MPLobby LobbyScreen;
    
    Manager = Class'SFXGUIInteraction'.static.GetInstance();
    LobbyScreen = Manager.CastGetMovie(Class'SFXGUI_MPLobby', Self, LobbyFlow.LobbyScreenTag);
    if (LobbyScreen != None)
    {
        LobbyScreen.LoadTab(12);
    }
}
public simulated function HideMPSelectKitScreen()
{
    local SFXGUIInteraction Manager;
    
    Manager = Class'SFXGUIInteraction'.static.GetInstance();
    Manager.RemoveMovie(Self, Manager.MovieTag_MPSelectKit);
}

simulated state SpectateCam 
{
    public function PlayerMove(float DeltaTime)
    {
        UpdateRotation(DeltaTime);
    }
    public function UpdateRotation(float DeltaTime)
    {
        local Object.Rotator DeltaRot;
        local Object.Rotator ViewRotation;
        
        ViewRotation = PlayerCamera.Rotation;
        DeltaRot.Yaw = int(PlayerInput.aTurn);
        DeltaRot.Pitch = int(PlayerInput.aLookUp);
        ProcessViewRotation(DeltaTime, ViewRotation, DeltaRot);
        PlayerCamera.SetRotation(ViewRotation);
    }
    public exec function ViewPrevPlayer()
    {
        local Actor CurrentTarget;
        local int nStartingIdx;
        local int nIdx;
        local SFXGRIMP GRI;
        local SFXPRIMP PRI;
        local Pawn NextPawn;
        
        GRI = SFXGRIMP(WorldInfo.GRI);
        if (PlayerCamera != None)
        {
            CurrentTarget = PlayerCamera.PendingViewTarget.Target == None ? PlayerCamera.ViewTarget.Target : PlayerCamera.PendingViewTarget.Target;
            for (nStartingIdx = 0; nStartingIdx < GRI.PRIArray.Length; nStartingIdx++)
            {
                if (SFXPRIMP(GRI.PRIArray[nStartingIdx]).SFXPawn == CurrentTarget)
                {
                    break;
                }
            }
            nStartingIdx--;
            for (nIdx = GRI.PRIArray.Length; nIdx > 0; nIdx--)
            {
                PRI = SFXPRIMP(GRI.PRIArray[(nIdx + nStartingIdx) % GRI.PRIArray.Length]);
                NextPawn = SFXPawn_PlayerMP(PRI.SFXPawn);
                if (NextPawn != None && NextPawn != Pawn && !NextPawn.IsDead() && !NextPawn.IsInState('Dying', ) && !NextPawn.IsInState('Downed', ))
                {
                    SetViewTarget(NextPawn, VTTransParms);
                    return;
                }
            }
        }
    }
    public exec function ViewNextPlayer()
    {
        local Actor CurrentTarget;
        local int nStartingIdx;
        local int nIdx;
        local SFXGRIMP GRI;
        local SFXPRIMP PRI;
        local Pawn NextPawn;
        
        GRI = SFXGRIMP(WorldInfo.GRI);
        if (GRI == None)
        {
            return;
        }
        if (PlayerCamera != None)
        {
            CurrentTarget = PlayerCamera.PendingViewTarget.Target == None ? PlayerCamera.ViewTarget.Target : PlayerCamera.PendingViewTarget.Target;
            for (nStartingIdx = 0; nStartingIdx < GRI.PRIArray.Length; nStartingIdx++)
            {
                if (SFXPRIMP(GRI.PRIArray[nStartingIdx]).SFXPawn == CurrentTarget)
                {
                    break;
                }
            }
            nStartingIdx++;
            for (nIdx = 0; nIdx < GRI.PRIArray.Length; nIdx++)
            {
                PRI = SFXPRIMP(GRI.PRIArray[(nIdx + nStartingIdx) % GRI.PRIArray.Length]);
                NextPawn = SFXPawn_PlayerMP(PRI.SFXPawn);
                if (NextPawn != None && NextPawn != Pawn && !NextPawn.IsDead() && !NextPawn.IsInState('Dying', ) && !NextPawn.IsInState('Downed', ))
                {
                    SetViewTarget(NextPawn, VTTransParms);
                    return;
                }
            }
        }
    }
    public function EndState(Name NextStateName)
    {
        SetViewTarget(Pawn, VTTransParms);
        GameModeManager2.DisableMode(20); // MILAN Patched: GameMode Enum Index
        SFXCameraNativeBase(PlayerCamera).bUseCameraRotation = FALSE;
    }
    public function BeginState(Name PreviousStateName)
    {
        GameModeManager2.EnableMode(20); // MILAN Patched: GameMode Enum Index
        SFXCameraNativeBase(PlayerCamera).bUseCameraRotation = TRUE;
        PlayerCamera.SetRotation(rot(0, 0, 0));
    }
    
Begin:
    ViewNextPlayer();
    goto 'End';
PrevPlayer:
    ViewPrevPlayer();
    goto 'End';
End:
    stop;
};
state RoundEnded 
{
    public function EndState(Name NextStateName)
    {
        Super(PlayerController).EndState(NextStateName);
        GameModeManager2.EnableInput();
    }
    public function BeginState(Name PreviousStateName)
    {
        Super(PlayerController).BeginState(PreviousStateName);
        GameModeManager2.DisableInput();
    }
    
    stop;
};
state Dying 
{
    public function PlayerTick(float DeltaTime)
    {
        Super.PlayerTick(DeltaTime);
        if (Role == ENetRole.ROLE_AutonomousProxy && Pawn != None)
        {
            Pawn.AutonomousPhysics(DeltaTime);
        }
    }
    public function EndState(Name NextStateName)
    {
        GameModeManager2.DisableMode(21); // MILAN Patched: GameMode Enum Index
    }
    public function BeginState(Name PreviousStateName)
    {
        GameModeManager2.EnableMode(21); // MILAN Patched: GameMode Enum Index
    }
    
    stop;
};
simulated state InLobby 
{
    public reliable server function ServerRestartPlayer()
    {
        WorldInfo.Game.RestartPlayer(Self);
    }
    public function TickSaveGame();
    
    public function ReplicateMove(float DeltaTime, Object.Vector newAccel, Actor.EDoubleClickDir DoubleClickMove, Object.Rotator DeltaRot);
    
    
    stop;
};
auto state PlayerWaiting 
{
    public function ReplicateMove(float DeltaTime, Object.Vector newAccel, Actor.EDoubleClickDir DoubleClickMove, Object.Rotator DeltaRot);
    
    public reliable server function ServerRestartPlayer()
    {
        if (WorldInfo.TimeSeconds < WaitDelay)
        {
            return;
        }
        if (WorldInfo.NetMode == ENetMode.NM_Client)
        {
            return;
        }
        WorldInfo.Game.RestartPlayer(Self);
    }
    public function TickSaveGame();
    
    
    stop;
};

public function UpdateMapsCompletedHelper(Name MapName, Name PlayedMaps, Name PlayedMapsCount, array<Name> MapNames)
{
    local SFXAccomplishmentManager AccomplishmentManager;
    local int BitMask;
    local int MapsPlayed;
    local int NumMapsPlayed;
    local int MapIndex;
    
    AccomplishmentManager = SFXEngine(Class'Engine'.static.GetEngine()).AccomplishmentManager;
    if (AccomplishmentManager == None)
    {
        return;
    }
    MapIndex = MapNames.Find(MapName);
    BitMask = 0;
    if (MapIndex >= 0)
    {
        BitMask = 1 << MapIndex;
    }
    if (BitMask > 0)
    {
        MapsPlayed = AccomplishmentManager.GetGrinderAccomplishmentProgress(PlayedMaps, Self);
        if (MapsPlayed > -1 && (MapsPlayed & BitMask) == 0)
        {
            MapsPlayed = MapsPlayed | BitMask;
            AccomplishmentManager.SetGrinderAccomplishmentProgress(PlayedMaps, MapsPlayed, Self);
        }
        NumMapsPlayed = 0;
        while (MapsPlayed != 0)
        {
            NumMapsPlayed += MapsPlayed & 1;
            MapsPlayed = MapsPlayed >> 1;
        }
        if (AccomplishmentManager.SetGrinderAccomplishmentProgressWithUpdate(PlayedMapsCount, NumMapsPlayed, Self))
        {
            AccomplishmentManager.Save();
        }
    }
}

// NEW to Milan - 10/09/2026 - Mgamerz
// Console: "lobbysize <players>" sets the lobby size. Host only, in the lobby.
public exec function LobbySize(int NewSize)
{
    local SFXGameInfoMP_Lobby GameInfo;

    GameInfo = SFXGameInfoMP_Lobby(WorldInfo.Game);
    if (GameInfo == None)
    {
        LogInternal("lobbysize: only the host can change the lobby size");
        return;
    }
    LogInternal("lobbysize: the lobby now admits" @ GameInfo.SetLobbySize(NewSize) @ "players (largest allowed:" @ GameInfo.MaxPlayersAllowed $ ").");
}


//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=BioPlayerSelection Name=oSelection
        Begin Template Class=SFXSelectionLensFlareComponent Name=SelectionFlare0
            ReplacementPrimitive = None
        End Template
        SelectionFlareComp = SelectionFlare0
    End Template
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    Begin Object Class=SFXHintSystemMP Name=HintSys1
    End Object
    Begin Template Class=SFXModule_AimAssist Name=AimAssist_0
    End Template
    MPMapNames = ('BioP_MPTowr', 'BioP_MPCer', 'BioP_MPNov', 'BioP_MPSlum', 'BioP_MPRctr', 'BioP_MPDish')
    VTTransParms = {BlendTime = 0.0, BlendExp = 2.0, bSkipCameraReset = TRUE, BlendFunction = EViewTargetBlendFunction.VTBlend_Cubic}
    CountdownTimerLeeway = -1.0
    TickSaveGameInterval = 60.0
    srWaitMessageMatchStarted = $727561
    srWaitMessageMatchEnded = $727562
    srWaitMessageGeneric = $727560
    srExitMessage = $641884
    srExitMessageLobby = $631051
    srConfirm = $153362
    srCancel = $665537
    AFKTimeLimitSeconds = 120.0
    AFKTickTime = 1
    DLCRemovedText = $720546
    ProfileChangedText = $695550
    HintSystem = HintSys1
    m_oPlayerSelection = oSelection
    bMultiplayerCommandMode = TRUE
    CheatClass = Class'SFXCheatManagerNonNativeMP'
    CylinderComponent = CollisionCylinder
    Components = (None, CollisionCylinder)
    Modules = (AimAssist_0)
    CollisionComponent = CollisionCylinder
}