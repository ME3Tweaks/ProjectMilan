// MILAN CHANGE - Mgamerz
// Add some null guards
// Raise map limit to 255, up from 30
// MILAN CHANGE - 10/04/2026 - Mgamerz
// Report which lobby screen the local player is on (SFXPRIMP.LobbyScreen), so the lobby can show it on each player's card.
// 0 = lobby, 1 = store, 2 = weapons, 3 = powers, 4 = appearance, 5 = match consumables, 6 = character,
// 7 = challenges, 8 = leaderboards, 9 = options, 10 = match settings. The lobby icon index is the value minus 1.
Class SFXLobbyFlow extends Info
    config(Game);

// Types
enum ELobbySubscreen
{
    LSS_None,
    LSS_SelectCharacter,
    LSS_MissionSetup,
    LSS_Character,
    LSS_Weapons,
    LSS_Store,
    LSS_Leaderboards,
    LSS_MatchResults,
    LSS_MatchRewards,
    LSS_Appearance,
    LSS_MatchConsumables,
    LSS_MultiplayerMenu,
    LSS_Lobby,
    LSS_Squad,
    LSS_TalentsLevelUp,
};

// Variables
var array<int> PreviouslySelectedItems;
var array<MPMapInfo> MapList;
var config array<string> MPGUIPackages;
var array<Texture2D> LoadedGUITextures;
var delegate<SortMapInfoData> __SortMapInfoData__Delegate;
var config Name LobbyScreenTag;
var SFXPawn_PlayerMP DummyPawn;
var SFXPawn_PlayerMP OriginalPawn;
var SFXWeaponUIDataManager DataManager;
var int nLastOffer;
var config int FramesToWaitBeforeFadingFromBlack;
var transient int FramesToWaitBeforeFadingFromBlackCounter;
var int LastMapPlayed;
var int LastEnemyPlayed;
var bool bDirty;
var bool bPlayerDataSent;
var bool bMPFlowStarted;
var bool bCreateCharacterFlowStarted;
var bool bDeployFlowStarted;
var bool bReadyToEnterLobby;
var bool bAlwaysAllowGoBackFromKitSelect;
var bool bCameFromSelectFirstCharacter;
var config bool bShowRevealReinforcementsOnUnexpectedAwarding;
var bool bManuallyRevealingReinforcements;
var bool bHostingNewMission;
var ELobbySubscreen CurrentLobbyTab;
var ELobbySubscreen PreviousSubScreen;

// Functions
public event function Destroyed()
{
    Super(Actor).Destroyed();
    // MILAN CHANGE - 12/03/2023 - Mgamerz
    // Fix for map changes. Datamanger can be null, this will crash game
    // Add if check before access
    if (DataManager != None){
        DataManager.Clear();
        DataManager.__OnDataLoadedDelegate__Delegate = None;
    } // END MILAN
    DataManager = None;
}
public function PlayGuiSound(Name SoundName)
{
    Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound(SoundName);
}
public event function Tick(float DeltaTime)
{
    Super(Actor).Tick(DeltaTime);
    if (DummyPawn != None && GetPC().Pawn != DummyPawn)
    {
        GetPC().Pawn = DummyPawn;
    }
    if (GetStateName() != 'Startup')
    {
        if (bDirty)
        {
            GetPC().RefreshLobbyScreen();
            bDirty = FALSE;
        }
    }
    if (FramesToWaitBeforeFadingFromBlackCounter > 0)
    {
        FramesToWaitBeforeFadingFromBlackCounter--;
        if (FramesToWaitBeforeFadingFromBlackCounter <= 0)
        {
            Class'SFXGUIInteraction'.static.GetInstance().HACK_IgnoreTurnBlackScreenOffForMP = FALSE;
            Class'SFXGUIInteraction'.static.GetInstance().HideBlackScreen(GetPC(), TRUE, 0.5);
        }
    }
}
public simulated function SFXPlayerControllerMP GetPC()
{
    local SFXPlayerControllerMP PC;
    
    PC = SFXPlayerControllerMP(Owner);
    return PC;
}
public function ServerRestartPlayer()
{
    GetPRI().bWaitingForPawn = TRUE;
    GetPC().ServerRestartPlayer();
}
public function ClearCrossLevelReferences();

public function bool IsInConnectToMapFlow()
{
    local SFXOnlineSubsystem oOnlineSubsystem;
    local ISFXOnlineComponentGameEntryFlow oEntryFlow;
    
    oOnlineSubsystem = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem();
    if (oOnlineSubsystem != None)
    {
        oEntryFlow = oOnlineSubsystem.GetComponentGameEntryFlow();
        if (oEntryFlow != None && oEntryFlow.IsInConnectToMapFlow())
        {
            return TRUE;
        }
    }
    return FALSE;
}
public simulated function OnCharacterChanged(PlayerReplicationInfo PRI);

public final function OnWeaponUIDataLoaded()
{
    RefreshLobbyScreen();
}
public function ReturnToMainMenu()
{
    local SFXOnlineSubsystem oOnlineSubsystem;
    local ISFXOnlineComponentGameEntryFlow oInviteFlow;
    
    Class'SFXGUIInteraction'.static.GetInstance().StopGuiMusic();
    oOnlineSubsystem = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem();
    if (oOnlineSubsystem != None)
    {
        oInviteFlow = oOnlineSubsystem.GetComponentGameEntryFlow();
        if (oInviteFlow != None && oInviteFlow.IsInConnectToMapFlow())
        {
            oInviteFlow.OnConnectToMapFlowCompleted(FALSE);
        }
        oOnlineSubsystem.GetComponentGameFlow().GM_OnExitMPFlow();
    }
    Class'SFXGUIInteraction'.static.GetInstance().HackReloadMainMenu();
}
public function bool IsInDeployFlow()
{
    return bDeployFlowStarted;
}
public function bool IsReadyToEnterLobby()
{
    local bool bWaitingForPawn;
    local bool bHostIsWaitingForPlayers;
    
    bWaitingForPawn = GetPC().Pawn == None;
    bHostIsWaitingForPlayers = GetLobbyGRI().IsInState('WaitingForPlayers', );
    return !bWaitingForPawn && (IsServer() || bHostIsWaitingForPlayers);
}
public function bool IsReadyToSendPlayerDataToServer()
{
    local SFXOnlineSubsystem OnlineSub;
    local bool SignedIn;
    local SFXSaveManagerMP MPSaveManager;
    local SFXPRIMP PRI;
    
    OnlineSub = SFXOnlineSubsystem(Class'GameEngine'.static.GetOnlineSubsystem());
    SignedIn = OnlineSub.GetComponentLogin().IsSignedIn();
    PRI = GetPRI();
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    if (SignedIn)
    {
        return (MPSaveManager.bInitialized && GetPC().bFinishedTraveling) && PRI != None;
    }
    else
    {
        return (MPSaveManager != None && GetPC().bFinishedTraveling) && PRI != None;
    }
}
public function bool IsReadyToStartMPFlow()
{
    local SFXPRIMP PRI;
    local bool fetchingLiveINIData;
    
    PRI = GetPRI();
    fetchingLiveINIData = SFXOnlineSubsystem(Class'GameEngine'.static.GetOnlineSubsystem()).GetComponentNotification().IsFetchingLiveBinaryINIData();
    return (GetPC().bFinishedTraveling && PRI != None) && !fetchingLiveINIData;
}
public function LoadPersonalMatchSettings(EPersonalMatchSettingsType eType)
{
    local SFXGameInfoMP_Lobby GameInfo;
    local SFXGRIMP_Lobby GRI;
    local int PrivacySetting;
    local SFXPlayerControllerMP PC;
    
    PC = GetPC();
    GameInfo = SFXGameInfoMP_Lobby(WorldInfo.Game);
    if ((GameInfo != None && PC != None) && PC.ProfileSettings != None)
    {
        GRI = GetLobbyGRI();
        PrivacySetting = GRI.PrivacySetting;
        if (eType == EPersonalMatchSettingsType.SETTINGS_FOR_SEARCH)
        {
            PC.ProfileSettings.GetProfileSettingValueInt(112, GRI.MapSetting);
            PC.ProfileSettings.GetProfileSettingValueInt(113, GRI.EnemySetting);
            PC.ProfileSettings.GetProfileSettingValueInt(114, GRI.DifficultySetting);
        }
        else if (eType == EPersonalMatchSettingsType.SETTINGS_FOR_CREATE)
        {
            PC.ProfileSettings.GetProfileSettingValueInt(98, PrivacySetting);
            PC.ProfileSettings.GetProfileSettingValueInt(99, GRI.MapSetting);
            PC.ProfileSettings.GetProfileSettingValueInt(100, GRI.EnemySetting);
            PC.ProfileSettings.GetProfileSettingValueInt(101, GRI.DifficultySetting);
        }
        Class'SFXOnlineGameSettings'.static.EnsureMatchSettingsAreValid(eType, PrivacySetting, GRI.MapSetting, GRI.EnemySetting, GRI.DifficultySetting);
        GRI.PrivacySetting = PrivacySetting;
        GRI.bRandomMap = GRI.MapSetting == 0;
        GRI.bRandomEnemy = GRI.EnemySetting == 0;
    }
}
public final function OnCloseRevealScreen()
{
    ShowStoreScreen(FALSE, FALSE);
}
public function OnMatchSettingsChanged()
{
    RefreshLobbyStatusBars();
}
public final function bool OnMPChallengesScreenClosed(SFXGUIMovie oMovie)
{
    ShowLobbyScreen();
    return TRUE;
}
public final function OnOptionsScreenClosed()
{
    ShowLobbyScreen();
}
public simulated function OnPlayerEnter(PlayerReplicationInfo PRI);

public simulated function OnPlayerLeave(PlayerReplicationInfo PRI);

public function OnSearchGameCancelled();

public final function RefreshLobbyScreen()
{
    bDirty = TRUE;
}
public final function RefreshLobbyStatusBars()
{
    GetPC().RefreshLobbyStatusBars();
}
public function RefreshMapList()
{
    MapList = GetAvailableMapList();
}
public final function RestoreLocalPRIMatchConsumablesFromOfflineTransfer(SFXPRI PRI)
{
    local SFXGAWReinforcementManager GAWManager;
    local SFXGAWReinforcementMatchConsumable MatchConsumables;
    local SFXGAWReinforcementBase CardOwner;
    local SFXEngine Engine;
    local int i;
    local int CardIdx;
    local int CardID;
    local int CardVersion;
    local bool IsGear;
    
    Engine = SFXEngine(Class'SFXEngine'.static.GetEngine());
    GAWManager = SFXGAWReinforcementManager(SFXLocalPlayer(Class'Engine'.static.GetCurrentWorldInfo().GetALocalPlayerController().Player).GAWReinforcementManager);
    if (GAWManager == None)
    {
        return;
    }
    MatchConsumables = GAWManager.GetUniqueMatchConsumables();
    for (i = 0; i < Engine.MPSaveManager.ActiveMatchConsumablesForOfflineTransfer.Length; ++i)
    {
        CardID = Engine.MPSaveManager.ActiveMatchConsumablesForOfflineTransfer[i].ClassNameID;
        CardVersion = int(Engine.MPSaveManager.ActiveMatchConsumablesForOfflineTransfer[i].Value);
        CardIdx = MatchConsumables.FindCardIndexFromID(CardID, -1.0);
        if (CardIdx != -1)
        {
            IsGear = Class'SFXGAWReinforcementMatchConsumable'.static.GetSlotTypeForCategory(MatchConsumables.CardList[CardIdx].Category) == 3;
            if (IsGear)
            {
                CardOwner = MatchConsumables.CardList[CardIdx].CardOwner;
                CardOwner.Activate(CardID, -1.0);
                continue;
            }
            CardIdx = MatchConsumables.FindCardIndexFromID(CardID, float(CardVersion));
            if (CardIdx != -1)
            {
                CardOwner = MatchConsumables.CardList[CardIdx].CardOwner;
                if (CardOwner.GetCurrentCount(CardID, CardVersion) > 0)
                {
                    CardOwner.Activate(CardID, float(CardVersion));
                }
            }
        }
    }
}
public function RestoreOriginalPawn()
{
    local SFXPlayerControllerMP oPC;
    
    oPC = GetPC();
    if (oPC != None && OriginalPawn != None)
    {
        oPC.Pawn = OriginalPawn;
        if (DummyPawn != None)
        {
            DummyPawn.Destroy();
            DummyPawn = None;
        }
        OriginalPawn = None;
    }
}
public function SavePersonalMatchSettings(EPersonalMatchSettingsType eType)
{
    local SFXGameInfoMP_Lobby GameInfo;
    local SFXGRIMP_Lobby GRI;
    local SFXPlayerControllerMP PC;
    
    PC = GetPC();
    GameInfo = SFXGameInfoMP_Lobby(WorldInfo.Game);
    if ((GameInfo != None && PC != None) && PC.ProfileSettings != None)
    {
        GRI = GetLobbyGRI();
        if (eType == EPersonalMatchSettingsType.SETTINGS_FOR_SEARCH)
        {
            PC.ProfileSettings.SetProfileSettingValueInt(112, GRI.MapSetting);
            PC.ProfileSettings.SetProfileSettingValueInt(113, GRI.EnemySetting);
            PC.ProfileSettings.SetProfileSettingValueInt(114, GRI.DifficultySetting);
        }
        else if (eType == EPersonalMatchSettingsType.SETTINGS_FOR_CREATE)
        {
            PC.ProfileSettings.SetProfileSettingValueInt(98, GRI.PrivacySetting);
            PC.ProfileSettings.SetProfileSettingValueInt(99, GRI.MapSetting);
            PC.ProfileSettings.SetProfileSettingValueInt(100, GRI.EnemySetting);
            PC.ProfileSettings.SetProfileSettingValueInt(101, GRI.DifficultySetting);
        }
        PC.SaveProfile();
    }
}
public function SendPlayerDataToServer()
{
    local SFXSaveManagerMP MPSaveManager;
    local SFXPRIMP PRI;
    local SFXMPCharacterRecord Character;
    
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    PRI = GetPRI();
    if (GetPC().IsLocalPlayerController())
    {
        if (MPSaveManager.IsCurrentSelectedCharacterRecordValid())
        {
            Character = MPSaveManager.GetCurrentSelectedCharacterRecord();
            PRI.LoadDataFromSave(Character);
            PRI.SetComputerName(PRI.PlayerName);
            PRI.SendCharacterDataToServer();
        }
        PRI.BuildLocalMapArray(MapList);
        PRI.ServerSetMapArray(PRI.LocalMapArray);
        PRI.ServerSetKickVote(PRI.KickVotePlayerId);
    }
}
public final function SetLastSelectedOffer(int nOfferID)
{
    nLastOffer = nOfferID;
}
public function SetupLocalCharacterData()
{
    local SFXSaveManagerMP MPSaveManager;
    local SFXMPCharacterRecord CharacterRecord;
    local SFXPawn_PlayerMP LocalPawn;
    
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    CharacterRecord = MPSaveManager.GetCurrentSelectedCharacterRecord();
    if (CharacterRecord == None)
    {
        return;
    }
    SpawnDummyPawn(MPSaveManager.GetKitArchetypeReference(CharacterRecord.KitName));
    LocalPawn = SFXPawn_PlayerMP(GetPC().Pawn);
    if (LocalPawn != None)
    {
        CharacterRecord.TransferCharacterDataToPawn(LocalPawn);
        CharacterRecord.TransferPowersToPawn(LocalPawn);
        CharacterRecord.TransferWeaponsToEnginePlayerLoadout();
        if (int(GetPC().ProfileSettings.GetMPAutoLevelConfigOption()) == 0)
        {
            CharacterRecord.AutoLevelUpPowers(LocalPawn);
        }
        GetPRI().LoadDataFromSave(CharacterRecord);
    }
    GetPC().SetRichPresence();
}
public final function ShowCustomMatchScreen()
{
    bHostingNewMission = FALSE;
    LoadPersonalMatchSettings(0);
    ChangeMapMusic(GetLobbyGRI().MapSetting);
    GetPC().ShowCustomMatchScreen();
    PreviousSubScreen = ELobbySubscreen.LSS_MissionSetup;
}
public final function ShowHostNewMissionScreen()
{
    bHostingNewMission = TRUE;
    LoadPersonalMatchSettings(1);
    ChangeMapMusic(GetLobbyGRI().MapSetting);
    GetPC().ShowCustomMatchScreen();
    PreviousSubScreen = ELobbySubscreen.LSS_MissionSetup;
}
public final function ShowLeaderboardScreen()
{
    Class'SFXGUIInteraction'.static.GetInstance().ShowLeaderboard(GetPC(), FinishLeaderboardScreen);
    // MILAN CHANGE - SET SCREEN VALUE
    GetPRI().SetLobbyScreen(8);
    // END MILAN CHANGE
    PreviousSubScreen = ELobbySubscreen.LSS_Leaderboards;
}
public final function ShowLobbyScreen()
{
    FadeInFromBlack();
    GetPC().ShowLobbyScreen();
    // MILAN CHANGE - SET SCREEN VALUE
    GetPRI().SetLobbyScreen(0);
    // END MILAN CHANGE
}
public final function ShowLobbyStatusBars()
{
    GetPC().ShowLobbyStatusBars();
}
public final function ShowMatchConsumablesScreen()
{
    GetPC().ShowMatchConsumablesScreen();
    // MILAN CHANGE - SET SCREEN VALUE
    GetPRI().SetLobbyScreen(5);
    // END MILAN CHANGE
    PreviousSubScreen = ELobbySubscreen.LSS_MatchConsumables;
}
public final function ShowMatchResultsScreen()
{
    SFXOnlineSubsystem(Class'GameEngine'.static.GetOnlineSubsystem()).GetComponentGameFlow().GM_OnEnterMPGameResults();
    GetPC().ShowMatchResultsScreen();
}
public final function ShowMatchSettingsScreen()
{
    GetPC().ShowMatchSettingsScreen();
    // MILAN CHANGE - SET SCREEN VALUE
    GetPRI().SetLobbyScreen(10);
    // END MILAN CHANGE
    PreviousSubScreen = ELobbySubscreen.LSS_MissionSetup;
}
public final function ShowMPAppearanceScreen()
{
    FadeInFromBlack();
    GetPC().ShowMPAppearanceScreen();
    // MILAN CHANGE - SET SCREEN VALUE
    GetPRI().SetLobbyScreen(4);
    // END MILAN CHANGE
    PreviousSubScreen = ELobbySubscreen.LSS_Appearance;
}
public final function bool ShowMPChallengeScreen()
{
    local array<bool> AccomplishmentDataRepeatability;
    local SFXAccomplishmentManager AccomplishmentManager;
    local Accomplishment AccomplishmentIter;
    local int idx;
    
    AccomplishmentManager = SFXEngine(Class'Engine'.static.GetEngine()).AccomplishmentManager;
    AccomplishmentDataRepeatability.Length = AccomplishmentManager.AccomplishmentData.Length;
    foreach AccomplishmentManager.AccomplishmentData(AccomplishmentIter, idx)
    {
        AccomplishmentDataRepeatability[idx] = AccomplishmentIter.bRepeatableChallenge;
    }
    return ShowMPChallengeScreen_Helper(AccomplishmentDataRepeatability);
}
private final function bool ShowMPChallengeScreen_Helper(array<bool> AccomplishmentDataRepeatability)
{
    local SFXGUIMovie oMPChallengesMovie;
    local SFXGUIInteraction oGuiInteraction;
    
    oGuiInteraction = Class'SFXGUIInteraction'.static.GetInstance();
    oMPChallengesMovie = oGuiInteraction.OpenMovie(GetPC(), 'MPChallenges');
    if (oMPChallengesMovie != None)
    {
        oMPChallengesMovie.ActionScriptVoid("InitializeData");
        oMPChallengesMovie.AddOnMovieClosedDelegate(OnMPChallengesScreenClosed);
        // MILAN CHANGE - SET SCREEN VALUE
        GetPRI().SetLobbyScreen(7);
        // END MILAN CHANGE
        return TRUE;
    }
    return FALSE;
}
public final function ShowMPSelectKitScreen()
{
    GetPC().ShowMPSelectKitScreen();
    // MILAN CHANGE - SET SCREEN VALUE
    GetPRI().SetLobbyScreen(6);
    // END MILAN CHANGE
    PreviousSubScreen = ELobbySubscreen.LSS_SelectCharacter;
}
public final function ShowMultiplayerMenu()
{
    FadeInFromBlack();
    GetPC().ShowLobbyScreen();
}
public final function ShowOptionsScreen()
{
    GetPC().GetSFXUIController().ShowMPOptions(GetPC(), OnOptionsScreenClosed);
    // MILAN CHANGE - SET SCREEN VALUE
    GetPRI().SetLobbyScreen(9);
    // END MILAN CHANGE
}
public final function ShowPromotionScreen()
{
    GetPC().ShowPromotionScreen();
}
public final function ShowReinforcementsRevealScreeen(bool bManualReveal)
{
    bManuallyRevealingReinforcements = bManualReveal;
    GetPC().ShowReinforcementsRevealScreeen(OnCloseRevealScreen);
    // MILAN CHANGE - SET SCREEN VALUE
    GetPRI().SetLobbyScreen(1);
    // END MILAN CHANGE
    PreviousSubScreen = ELobbySubscreen.LSS_Store;
}
public final function ShowStoreScreen(optional bool bProcessPurchases = TRUE, optional bool bSendTelemetry = TRUE)
{
    if (bSendTelemetry)
    {
        Class'SFXTelemetryHooksMP'.static.SendStoreOpened(IsInState('Lobby', ));
    }
    GetPC().ShowMPStoreUI(nLastOffer, bProcessPurchases);
    GetPRI().SetStoreIsOpen(TRUE);
    // MILAN CHANGE - SET SCREEN VALUE
    GetPRI().SetLobbyScreen(1);
    // END MILAN CHANGE
    nLastOffer = -1;
    PreviousSubScreen = ELobbySubscreen.LSS_Store;
}
public final function ShowStoreScreenFromPromotion(optional int PromotionalStoreID)
{
    GetPC().ShowStoreScreenFromPromotion(PromotionalStoreID);
}
public final function ShowTalentsLevelUpScreen()
{
    FadeInFromBlack();
    GetPC().ShowLevelUpUI(FinishTalentsLevelUpScreen);
    // MILAN CHANGE - SET SCREEN VALUE
    GetPRI().SetLobbyScreen(3);
    // END MILAN CHANGE
    PreviousSubScreen = ELobbySubscreen.LSS_TalentsLevelUp;
}
public final function ShowWeaponsScreen()
{
    FadeInFromBlack();
    GetPC().ShowWeaponSelectionUI(FinishWeaponsScreen);
    // MILAN CHANGE - SET SCREEN VALUE
    GetPRI().SetLobbyScreen(2);
    // END MILAN CHANGE
    PreviousSubScreen = ELobbySubscreen.LSS_Weapons;
}
public delegate function int SortMapInfoData(MPMapInfo A, MPMapInfo B)
{
    if (A.Id > B.Id)
    {
        return -1;
    }
    return 0;
}
public function SpawnDummyPawn(string KitArchetype)
{
    local Actor PawnArchetype;
    local SFXPRIMP oPRI;
    local SFXPlayerControllerMP oPC;
    local Vector SpawnLocation;
    local SFXSaveManagerMP MPSaveManager;
    local SFXMPCharacterRecord CharacterRecord;
    
    oPRI = GetPRI();
    oPC = GetPC();
    if ((oPRI == None || oPC == None) || oPC.Pawn == None)
    {
        return;
    }
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    CharacterRecord = MPSaveManager.GetCurrentSelectedCharacterRecord();
    PawnArchetype = SFXPawn_PlayerMP(Class'SFXEngine'.static.GetSeekFreeObject(KitArchetype, Class'SFXPawn_PlayerMP'));
    if (PawnArchetype == None)
    {
        return;
    }
    if (OriginalPawn == None)
    {
        OriginalPawn = SFXPawn_PlayerMP(oPC.Pawn);
    }
    if (DummyPawn != None)
    {
        DummyPawn.Destroy();
        DummyPawn = None;
    }
    SpawnLocation = OriginalPawn.location;
    SpawnLocation.Z += OriginalPawn.GetCollisionHeight() * float(4);
    DummyPawn = Spawn(Class<SFXPawn_PlayerMP>(PawnArchetype.Class), oPC, , SpawnLocation, OriginalPawn.Rotation, PawnArchetype);
    if (DummyPawn == None)
    {
        RestoreOriginalPawn();
        return;
    }
    DummyPawn.RemoteRole = ENetRole.ROLE_None;
    DummyPawn.Controller = oPC;
    DummyPawn.Squad = OriginalPawn.Squad;
    DummyPawn.SetPhysics(0);
    DummyPawn.AutoLevelUpInfo = DummyPawn.PlayerClass.default.AutoLevelUpInfo;
    DummyPawn.SetMPAppearanceVariables(CharacterRecord.Tint1ID, CharacterRecord.Tint2ID, CharacterRecord.PatternID, CharacterRecord.PatternColorID, CharacterRecord.PhongID, CharacterRecord.EmissiveID, CharacterRecord.SkinToneID);
    if (oPC.Pawn != None)
    {
        oPC.Pawn.PlayerReplicationInfo = None;
    }
    oPC.Pawn = DummyPawn;
    DummyPawn.PlayerReplicationInfo = oPRI;
    oPRI.bWaitingForPawn = FALSE;
}
public function bool StartConnectToMapFlow()
{
    local SFXOnlineSubsystem oOnlineSubsystem;
    local ISFXOnlineComponentGameEntryFlow oEntryFlow;
    
    Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound('Set_mus_gameplaymode_silence');
    oOnlineSubsystem = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem();
    if (oOnlineSubsystem != None)
    {
        oEntryFlow = oOnlineSubsystem.GetComponentGameEntryFlow();
        if (oEntryFlow != None)
        {
            if (!oEntryFlow.GetDeferredGameSettings().ValidateMapName(oEntryFlow.GetDeferredGameSettings().mME3MapName))
            {
                oEntryFlow.GetDeferredGameSettings().mME3MapName = "";
            }
            SFXGameInfoMP_Lobby(WorldInfo.Game).StartMPMatch(oEntryFlow.GetDeferredGameSettings());
            oEntryFlow.OnConnectToMapFlowCompleted();
            return TRUE;
        }
    }
    return FALSE;
}
public function StartCustomMatch()
{
    local SFXGameInfoMP_Lobby GameInfo;
    local SFXGRIMP_Lobby GRI;
    local SFXOnlineGameSettings NewMatchSettings;
    
    GameInfo = SFXGameInfoMP_Lobby(WorldInfo.Game);
    if (GameInfo != None)
    {
        GRI = GetLobbyGRI();
        NewMatchSettings = new Class'SFXOnlineGameSettings';
        NewMatchSettings.SetPrivacy(0);
        // MILAN CHANGE - 10/09/2026 - Mgamerz
        // A new lobby starts at the default size ([Engine.GameInfo] MaxPlayers).
        NewMatchSettings.SetLobbySize(Class'SFXGameInfoMP_Lobby'.static.GetDefaultLobbySize());
        // END MILAN CHANGE
        NewMatchSettings.mME3MapName = NewMatchSettings.GetMapByID(GRI.MapSetting).PackageName;
        NewMatchSettings.EnemyType = GRI.EnemySetting;
        NewMatchSettings.Difficulty = byte(GRI.DifficultySetting);
        NewMatchSettings.mCreateNewMatch = FALSE;
        SavePersonalMatchSettings(0);
        GameInfo.StartMPMatch(NewMatchSettings);
    }
}
public function StartDeployFlow()
{
    local SFXSaveManagerMP MPSaveManager;
    
    bDeployFlowStarted = TRUE;
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    SpawnDummyPawn(MPSaveManager.GetKitArchetypeReference(MPSaveManager.GetCurrentModifiableCharacter().KitName));
    ShowMPAppearanceScreen();
}
public final function StartMPFlow()
{
    local SFXEngine Engine;
    local SFXOnlineSubsystem OnlineSub;
    
    Engine = SFXEngine(Class'SFXEngine'.static.GetEngine());
    OnlineSub = SFXOnlineSubsystem(Engine.GetOnlineSubsystem());
    Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound('Play_mus_mp');
    if (OnlineSub != None && !bMPFlowStarted)
    {
        RestoreLocalPRIMatchConsumablesFromOfflineTransfer(GetPRI());
        if (WorldInfo.bIsLobbyLevel)
        {
        }
        else
        {
            OnlineSub.GetComponentGameFlow().GM_OnEnterMPGameplay();
            ChangeMapMusic(SFXGRIMP(WorldInfo.GRI).MapSetting);
            Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound('Set_mus_gameplaymode_silence');
            GotoState('MatchInProgress', , , );
        }
        Engine.SetBlockOnStreaming();
        bMPFlowStarted = TRUE;
        GetPRI().SetReadyToPlay(TRUE);
    }
}
public function StartNewMatch()
{
    local SFXGameInfoMP_Lobby GameInfo;
    local SFXGRIMP_Lobby GRI;
    local SFXOnlineGameSettings NewMatchSettings;
    
    GameInfo = SFXGameInfoMP_Lobby(WorldInfo.Game);
    if (GameInfo != None)
    {
        GRI = GetLobbyGRI();
        NewMatchSettings = new Class'SFXOnlineGameSettings';
        NewMatchSettings.SetPrivacy(byte(GRI.PrivacySetting));
        // MILAN CHANGE - 10/09/2026 - Mgamerz
        // These settings are new, so carry the lobby's size over (it would reset to 4 otherwise).
        NewMatchSettings.SetLobbySize(GRI.NumPlayerSlots);
        // END MILAN CHANGE
        NewMatchSettings.mME3MapName = NewMatchSettings.GetMapByID(GRI.MapSetting).PackageName;
        NewMatchSettings.EnemyType = GRI.EnemySetting;
        NewMatchSettings.Difficulty = byte(GRI.DifficultySetting);
        NewMatchSettings.mCreateNewMatch = TRUE;
        SavePersonalMatchSettings(1);
        GameInfo.StartMPMatch(NewMatchSettings);
    }
}
public function StartQuickMatch()
{
    local SFXGameInfoMP_Lobby GameInfo;
    
    GameInfo = SFXGameInfoMP_Lobby(WorldInfo.Game);
    if (GameInfo != None)
    {
        GameInfo.StartMPMatch();
    }
}
public function bool CanSetReady()
{
    local SFXGUIInteraction GUIManager;
    local SFXGUIMovie MatchResultsGUI;
    local SFXGUIMovie LobbyGUI;
    local SFXGUI_MPStore StoreGUI;
    local bool bInMissionSettingsScreen;
    local bool bIsLeader;
    
    if (GetLobbyGRI() == None)
    {
        return FALSE;
    }
    GUIManager = Class'SFXGUIInteraction'.static.GetInstance();
    StoreGUI = GUIManager.CastGetMovie(Class'SFXGUI_MPStore', GetPC(), GUIManager.MovieTag_MPStore);
    MatchResultsGUI = GUIManager.GetMovie(GetPC(), GUIManager.MovieTag_MPMatchResults);
    LobbyGUI = GUIManager.GetMovie(GetPC(), GUIManager.MovieTag_MPNewLobby);
    bInMissionSettingsScreen = LobbyGUI != None && CurrentLobbyTab == ELobbySubscreen.LSS_MissionSetup;
    bIsLeader = GetPRI() == GetLobbyGRI().LeaderPRI;
    if (StoreGUI != None && StoreGUI.CanSetReady() == FALSE)
    {
        return FALSE;
    }
    else if (MatchResultsGUI != None)
    {
        return FALSE;
    }
    else if (bInMissionSettingsScreen && bIsLeader)
    {
        return FALSE;
    }
    else
    {
        return TRUE;
    }
}
public function ChangeMapMusic(int MapId)
{
    local SFXGUIInteraction UIManager;
    local array<MPMapInfo> MasterMapList;
    local int nIndex;
    local array<MPMapInfo> MapsToChooseFrom;
    
    UIManager = Class'SFXGUIInteraction'.static.GetInstance();
    MasterMapList = Class'SFXOnlineGameSettings'.default.MasterMapList;
    nIndex = MasterMapList.Find('Id', MapId);
    if (nIndex >= 0)
    {
        if (MapId == 0)
        {
            MapsToChooseFrom = MasterMapList;
            MapsToChooseFrom.Remove(nIndex, 1);
            nIndex = Rand(MapsToChooseFrom.Length);
            UIManager.PlayGuiSound(MapsToChooseFrom[nIndex].MusicEventName);
        }
        else
        {
            UIManager.PlayGuiSound(MasterMapList[nIndex].MusicEventName);
        }
    }
}
public function bool ChangeMatchSettings(int privacy, int MapId, int EnemyType, int NewDifficulty);

public final function bool DoesEveryoneHaveMap(int MapId)
{
    local int idx;
    local int PlayerMask;
    local SFXPRIMP PRI;
    local SFXGRIMP_Lobby GRI;
    
    GRI = GetLobbyGRI();
    if (GRI == None)
    {
        return FALSE;
    }
    if (MapId == -1)
    {
        return TRUE;
    }
    // MILAN CHANGE 09/07/2026 - Mgamerz
    // Raise map limit to 255, up from 30
    else if (MapId >= 0 && MapId < 255)
    // END MILAN CHANGE
    {
        // MILAN CHANGE - 10/09/2026 - Mgamerz
        // CombinedMapArray counts the players who have each map (SFXGRIMP_Lobby.BuildCombinedMapArray)
        // instead of holding a bit per player, which ran out at 8 players. Everyone has the map when
        // that count equals the number of players who have sent their map list.
        PlayerMask = 0;
        for (idx = 0; idx < GRI.PRIArray.Length; ++idx)
        {
            PRI = SFXPRIMP(GRI.PRIArray[idx]);
            if (PRI.bLocalMapsSent)
            {
                ++PlayerMask;
            }
        }
        // END MILAN CHANGE
        return int(GetPRI().CombinedMapArray[MapId]) == PlayerMask;
    }
    else
    {
        return FALSE;
    }
}
public function EnterLobby()
{
    local SFXEngine Engine;
    local string URLString;
    local string OptionsString;
    local string OriginScreen;
    local SFXOnlineSubsystem OnlineSub;
    local SFXSaveManagerMP MPSaveManager;
    local int idx;
    local bool bDelayStopLoadingMovie;
    local SFXLocalPlayer LP;
    local ISFXOnlineComponentGameEntryFlow oInviteFlow;
    
    if (PreviouslySelectedItems.Length == 0)
    {
        PreviouslySelectedItems.Add(15);
    }
    for (idx = 0; idx < PreviouslySelectedItems.Length; ++idx)
    {
        PreviouslySelectedItems[idx] = -1;
    }
    Engine = SFXEngine(Class'SFXEngine'.static.GetEngine());
    OnlineSub = SFXOnlineSubsystem(Engine.GetOnlineSubsystem());
    MPSaveManager = Engine.MPSaveManager;
    bDelayStopLoadingMovie = FALSE;
    oInviteFlow = OnlineSub.GetComponentGameEntryFlow();
    if (OnlineSub.GetComponentNotification().IsLiveINIOutOfDate())
    {
        if (WorldInfo.NetMode == ENetMode.NM_Standalone)
        {
            ConsoleCommand("open " $ Engine.GetDefaultLobbyMap());
            return;
        }
    }
    LP = SFXLocalPlayer(Class'Engine'.static.GetCurrentWorldInfo().GetALocalPlayerController().Player);
    if (LP.GAWReinforcementManager == None)
    {
        LP.GAWReinforcementManager = new (LP) Class'SFXGAWReinforcementManager';
    }
    SFXGAWReinforcementManager(LP.GAWReinforcementManager).LoadDeck();
    SFXGAWReinforcementManager(LP.GAWReinforcementManager).UpdateStoreDescriptions();
    if (WorldInfo.NetMode == ENetMode.NM_Standalone)
    {
        if (IsInConnectToMapFlow())
        {
            GotoState('ConnectToMap', , , );
        }
        else
        {
            SetupLocalCharacterData();
            URLString = WorldInfo.GetLocalURL();
            OptionsString = Mid(URLString, InStr(URLString, "?", , , ), );
            OriginScreen = Class'GameInfo'.static.ParseOption(OptionsString, "origin");
            if (MPSaveManager.GetPromotionalMessageData().TrackingID > MPSaveManager.GetPlayerVariable('LastPromoIDShown'))
            {
                ShowPromotionScreen();
            }
            Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound('Set_mus_map_mainmenu');
            if (OriginScreen == "EndOfMatchError")
            {
                GotoState('MatchResultsFromError', , , );
            }
            else if (OriginScreen == "MainMenu" && !MPSaveManager.IsCurrentSelectedCharacterRecordValid() || oInviteFlow != None && oInviteFlow.IsWaitingForKitSelect())
            {
                GotoState('SelectFirstCharacter', , , );
            }
            else
            {
                GotoState('MultiplayerMenu', , , );
                bDelayStopLoadingMovie = TRUE;
            }
        }
    }
    else
    {
        SetupLocalCharacterData();
        GetPRI().SendCharacterDataToServer();
        if (MPSaveManager.GetPromotionalMessageData().TrackingID == MPSaveManager.DefaultTutorialMessage.TrackingID)
        {
            ShowPromotionScreen();
        }
        if (MPSaveManager.IsCurrentSelectedCharacterRecordValid() || !MPSaveManager.bInitialized)
        {
            GotoState('Lobby', , , );
        }
        else
        {
            GotoState('SelectFirstCharacterInLobby', , , );
        }
    }
    OnlineSub.GetComponentGameFlow().GM_OnEnterMPFlow();
    if (!bDelayStopLoadingMovie)
    {
        Class'Engine'.static.FlushAsyncLoading();
        GetPC().StopLoadingMovie();
    }
}
public final function ExitMultiplayer()
{
    ReturnToMainMenu();
}
public final function FadeInFromBlack()
{
    Class'SFXGUIInteraction'.static.GetInstance().ShowBlackScreen(GetPC(), FALSE);
    Class'SFXGUIInteraction'.static.GetInstance().HACK_IgnoreTurnBlackScreenOffForMP = TRUE;
    FramesToWaitBeforeFadingFromBlackCounter = FramesToWaitBeforeFadingFromBlack;
}
public function FinishChangingMatchSettings(bool bSuccess);

public final function bool FinishLeaderboardScreen(SFXGUIMovie i_ScreenToClose)
{
    ShowLobbyScreen();
    return TRUE;
}
public function FinishMatchResults()
{
    ShowLobbyScreen();
}
public function FinishModifyCharacterFlow();

public function FinishMPAppearanceScreen(bool bSuccess, SFXMPCharacterRecord ModifiedCharacter)
{
    local SFXSaveManagerMP MPSaveManager;
    
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    if (bSuccess)
    {
        if (bDeployFlowStarted)
        {
            if (!ModifiedCharacter.Deployed)
            {
                MPSaveManager.DeployCharacter(ModifiedCharacter);
                MPSaveManager.SetCurrentSelectedCharacterRecord(ModifiedCharacter.KitName);
                GetPC().UnlockAccomplishment('CREATECHAR');
                if (Class'Engine'.static.GetCurrentWorldInfo().Game != None)
                {
                    Class'Engine'.static.GetCurrentWorldInfo().Game.WriteOnlineStats();
                }
            }
        }
        MPSaveManager.SaveRecords();
    }
    MPSaveManager.ClearCurrentModifiableCharacter();
    if (bDeployFlowStarted)
    {
        bDeployFlowStarted = FALSE;
        if (bSuccess)
        {
            FinishSelectCharacterFlow(TRUE);
        }
        else
        {
            ShowMPSelectKitScreen();
        }
    }
    else
    {
        FinishModifyCharacterFlow();
    }
}
public function FinishSelectCharacterFlow(bool bSuccess);

public final function FinishStoreScreen()
{
    local SFXSaveManagerMP MPSaveManager;
    
    Class'SFXTelemetryHooksMP'.static.SendStoreClosed();
    GetPC().FinishedMPStoreUI();
    GetPRI().SetStoreIsOpen(FALSE);
    GetPRI().SendCharacterDataToServer();
    MPSaveManager = Class'SFXEngine'.static.GetSFXEngine().MPSaveManager;
    MPSaveManager.ClearNewReinforcementCategory(12);
    if (PreviousSubScreen == ELobbySubscreen.LSS_MatchConsumables)
    {
        ShowMatchConsumablesScreen();
    }
    else
    {
        CurrentLobbyTab = CurrentLobbyTab == ELobbySubscreen.LSS_None ? 11 : CurrentLobbyTab;
        if (!Class'SFXEngine'.static.GetSFXEngine().MPSaveManager.IsCurrentSelectedCharacterRecordValid() || PreviousSubScreen == ELobbySubscreen.LSS_SelectCharacter)
        {
            ShowMPSelectKitScreen();
        }
        else
        {
            ShowLobbyScreen();
        }
    }
}
public final function FinishTalentsLevelUpScreen()
{
    GetPC().FinishedLevelUpUI();
    ShowLobbyScreen();
}
public final function FinishWeaponsScreen()
{
    GetPC().FinishedWeaponSelectionUI();
    GetPRI().SendCharacterDataToServer(FALSE, TRUE, FALSE);
    ShowLobbyScreen();
}
public function array<MPMapInfo> GetAvailableMapList()
{
    local array<MPMapInfo> MasterMapList;
    local array<MPMapInfo> AvailableMapList;
    local MPMapInfo MapInfo;
    local array<string> AvailableMapPackageNames;
    local string PackageName;
    local bool PackageExists;
    local int idx;
    
    MasterMapList = Class'SFXOnlineGameSettings'.default.MasterMapList;
    AvailableMapPackageNames = Class'SFXOnlineGameSettings'.default.AvailableMaps;
    foreach AvailableMapPackageNames(PackageName, )
    {
        PackageExists = Class'SFXEngine'.static.DoesPackageExist(PackageName);
        if (PackageExists || PackageName == "")
        {
            idx = MasterMapList.Find('PackageName', PackageName);
            MapInfo = MasterMapList[idx];
            MapInfo.EveryoneHasThisMap = DoesEveryoneHaveMap(MapInfo.Id);
            AvailableMapList.AddItem(MapInfo);
        }
    }
    if (FALSE)
    {
        AvailableMapList.Sort(SortMapInfoData);
    }
    return AvailableMapList;
}
public final function SFXGRIMP_Lobby GetLobbyGRI()
{
    return SFXGRIMP_Lobby(WorldInfo.GRI);
}
public simulated function SFXPRIMP GetPRI()
{
    local SFXPRIMP PRI;
    
    PRI = SFXPRIMP(SFXPlayerControllerMP(Owner).PlayerReplicationInfo);
    return PRI;
}
public final function GoBackToSelectFirstCharacter()
{
    HideLobbyScreen();
    GotoState('SelectFirstCharacter', , , );
}
public final function HideCustomMatchScreen()
{
    GetPC().HideCustomMatchScreen();
}
public final function HideLobbyScreen()
{
    GetPC().HideLobbyScreen();
}
public final function HideLobbyStatusBars()
{
    GetPC().HideLobbyStatusBars();
}
public final function HideMatchResultsScreen()
{
    GetPC().HideMatchResultsScreen();
}
public final function HideMultiplayerMenu()
{
    GetPC().HideLobbyScreen();
}
public final function HideSelectKitScreen()
{
    GetPC().HideMPSelectKitScreen();
}
public function InitializeWeaponUIManager()
{
    if (DataManager == None)
    {
        DataManager = new Class'SFXWeaponUIDataManager';
    }
    if (!DataManager.DataIsLoaded)
    {
        DataManager.LoadData(OnWeaponUIDataLoaded);
    }
}

// States
state MatchInProgress 
{
    ignores Tick
    ;
    // State Functions
    
    // State code
    stop;
};
simulated state Lobby 
{
    // State Functions
    public simulated function OnCharacterChanged(PlayerReplicationInfo PRI)
    {
        RefreshLobbyScreen();
    }
    public simulated function OnPlayerLeave(PlayerReplicationInfo PRI)
    {
        PlayGuiSound('MPLobbyPlayerExit');
        RefreshLobbyStatusBars();
        RefreshLobbyScreen();
    }
    public simulated function OnPlayerEnter(PlayerReplicationInfo PRI)
    {
        PlayGuiSound('MPLobbyPlayerEnter');
        RefreshLobbyStatusBars();
        RefreshLobbyScreen();
    }
    public function FinishChangingMatchSettings(bool bSuccess)
    {
        // MILAN CHANGE - SET SCREEN VALUE
        // Closing match settings does not go through ShowLobbyScreen.
        GetPRI().SetLobbyScreen(0);
        // END MILAN CHANGE
        if (bSuccess)
        {
            PlayGuiSound('MPSelectMapSuccess');
            GetLobbyGRI().UnreadyAllPlayers();
        }
        else
        {
            PlayGuiSound('MPSelectMapCancel');
            if (IsServer())
            {
                ChangeMapMusic(GetLobbyGRI().MapSetting);
            }
        }
        GetPC().HideMatchSettingsScreen();
        RefreshLobbyScreen();
    }
    public function bool ChangeMatchSettings(int privacy, int MapId, int EnemyType, int NewDifficulty)
    {
        local SFXGameInfoMP_Lobby GameInfo;
        local bool bRandomMap;
        local bool bRandomEnemy;
        
        bRandomMap = MapId == 0;
        bRandomEnemy = EnemyType == 0;
        GameInfo = SFXGameInfoMP_Lobby(WorldInfo.Game);
        if (GameInfo != None)
        {
            return GameInfo.ChangeMatchSettings(privacy, MapId, bRandomMap, EnemyType, bRandomEnemy, NewDifficulty);
        }
        return FALSE;
    }
    public function InitMatchSettings()
    {
        local SFXGameInfoMP_Lobby GameInfo;
        local SFXGRIMP_Lobby GRI;
        local SFXHostMigrationMP HostMigration;
        local string URLString;
        local string OptionsString;
        local string OriginScreen;
        local SFXOnlineGameSettings GameSettings;
        
        GRI = GetLobbyGRI();
        GameInfo = SFXGameInfoMP_Lobby(WorldInfo.Game);
        URLString = WorldInfo.GetLocalURL();
        OptionsString = Mid(URLString, InStr(URLString, "?", , , ), );
        OriginScreen = Class'GameInfo'.static.ParseOption(OptionsString, "origin");
        if (GameInfo != None && GRI != None)
        {
            if (OriginScreen == "MultiplayerMenu")
            {
                GameSettings = GameInfo.GetOnlineGameSettings();
                if (GameSettings != None)
                {
                    GRI.PrivacySetting = int(GameSettings.GetPrivacy());
                    GRI.MapSetting = GameSettings.GetMapByPackageName(GameSettings.mME3MapName).Id;
                    GRI.bRandomMap = GRI.MapSetting == 0;
                    GRI.EnemySetting = GameSettings.EnemyType;
                    GRI.bRandomEnemy = GRI.EnemySetting == 0;
                    GRI.DifficultySetting = int(GameSettings.Difficulty);
                }
            }
            HostMigration = SFXHostMigrationMP(Class'SFXHostMigration'.static.GetHostMigration());
            if (HostMigration != None)
            {
                HostMigration.RestoreGRI(GRI);
            }
            GameInfo.GetOnlineGameSettings().mMapIsRequired = FALSE;
            GameInfo.ChangeMatchSettings(GRI.PrivacySetting, GRI.MapSetting, GRI.bRandomMap, GRI.EnemySetting, GRI.bRandomEnemy, GRI.DifficultySetting);
            if (GRI.bRandomMap == TRUE)
            {
                GRI.MapSetting = 0;
            }
            if (GRI.bRandomEnemy == TRUE)
            {
                GRI.EnemySetting = 0;
            }
        }
        ChangeMapMusic(GRI.MapSetting);
    }
    public function FinishModifyCharacterFlow()
    {
        local SFXSaveManagerMP MPSaveManager;
        local SFXMPCharacterRecord CharacterRecord;
        
        MPSaveManager = Class'SFXEngine'.static.GetSFXEngine().MPSaveManager;
        CharacterRecord = MPSaveManager.GetCurrentSelectedCharacterRecord();
        GetPRI().LoadDataFromSave(CharacterRecord);
        ShowLobbyScreen();
    }
    public function FinishSelectCharacterFlow(bool bSuccess)
    {
        SetupLocalCharacterData();
        if (bSuccess)
        {
            GetPRI().SendCharacterDataToServer();
        }
        HideSelectKitScreen();
        ShowLobbyScreen();
    }
    public function EndState(Name NextStateName)
    {
        Super(Object).EndState(NextStateName);
        RestoreOriginalPawn();
        HideLobbyStatusBars();
    }
    public function BeginState(Name PreviousStateName)
    {
        local string URLString;
        local string OptionsString;
        local string OriginState;
        local SFXGameInfoMP_Lobby GameInfo;
        
        CurrentLobbyTab = ELobbySubscreen.LSS_Lobby;
        URLString = WorldInfo.GetLocalURL();
        OptionsString = Mid(URLString, InStr(URLString, "?", , , ), );
        OriginState = Class'GameInfo'.static.ParseOption(OptionsString, "origin");
        if (OriginState == "EndOfMatch" && PreviousStateName != 'SelectFirstCharacterInLobby')
        {
            ShowMatchResultsScreen();
        }
        else
        {
            SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager.GetMPMatchResultsData().ResetData();
            ShowLobbyScreen();
            GameInfo = SFXGameInfoMP_Lobby(WorldInfo.Game);
            GameInfo.CheckNatRestriction();
        }
        if ((GetLobbyGRI() != None && IsServer()) && GetLobbyGRI().GetStateName() != 'WaitingForPlayers')
        {
            GetLobbyGRI().GotoState('WaitingForPlayers', , , );
        }
        ShowLobbyStatusBars();
        InitializeWeaponUIManager();
        InitMatchSettings();
        Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound('Set_mus_gameplaymode_lobby');
    }
    
    // State code
    stop;
};
simulated state MatchResultsFromError 
{
    // State Functions
    public simulated function FinishMatchResults()
    {
        GotoState('MultiplayerMenu', , , );
        HideMatchResultsScreen();
    }
    public simulated function BeginState(Name PreviousStateName)
    {
        Super(Object).BeginState(PreviousStateName);
        ShowMatchResultsScreen();
    }
    
    // State code
    stop;
};
state ConnectToMap 
{
    // State Functions
    public function OnSearchGameCancelled()
    {
        GotoState('MultiplayerMenu', , , );
    }
    public function BeginState(Name PreviousStateName)
    {
        StartConnectToMapFlow();
    }
    
    // State code
    stop;
};
state MultiplayerMenu 
{
    // State Functions
    public function FinishChangingMatchSettings(bool bSuccess)
    {
        if (bSuccess)
        {
            PlayGuiSound('MPSelectMapSuccess');
            Class'SFXGUIInteraction'.static.GetInstance().StopGuiSound('Play_mus_mp');
            if (bHostingNewMission)
            {
                StartNewMatch();
            }
            else
            {
                StartCustomMatch();
            }
        }
        else
        {
            PlayGuiSound('MPSelectMapCancel');
            Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound('Set_mus_map_mainmenu');
            HideCustomMatchScreen();
        }
    }
    public function bool ChangeMatchSettings(int privacy, int MapId, int EnemyType, int NewDifficulty)
    {
        local SFXGameInfoMP_Lobby GameInfo;
        local bool bRandomMap;
        local bool bRandomEnemy;
        
        bRandomMap = MapId == 0;
        bRandomEnemy = EnemyType == 0;
        GameInfo = SFXGameInfoMP_Lobby(WorldInfo.Game);
        if (GameInfo != None)
        {
            GameInfo.ChangeMatchSettings(privacy, MapId, bRandomMap, EnemyType, bRandomEnemy, NewDifficulty);
        }
        return TRUE;
    }
    public function FinishModifyCharacterFlow()
    {
        local SFXSaveManagerMP MPSaveManager;
        local SFXMPCharacterRecord CharacterRecord;
        
        MPSaveManager = Class'SFXEngine'.static.GetSFXEngine().MPSaveManager;
        CharacterRecord = MPSaveManager.GetCurrentSelectedCharacterRecord();
        GetPRI().LoadDataFromSave(CharacterRecord);
        ShowMultiplayerMenu();
    }
    public function FinishCreateCharacterFlow()
    {
        bCreateCharacterFlowStarted = FALSE;
        ShowMultiplayerMenu();
    }
    public function FinishSelectCharacterFlow(bool bSuccess)
    {
        SetupLocalCharacterData();
        HideSelectKitScreen();
        ShowMultiplayerMenu();
    }
    public final function FinishInitialization()
    {
        CurrentLobbyTab = ELobbySubscreen.LSS_MultiplayerMenu;
        ShowMultiplayerMenu();
        HideLobbyStatusBars();
    }
    public function ContinueInitialization(int nResult)
    {
        local SFXGAWReinforcementManager GAWManager;
        
        GAWManager = SFXGAWReinforcementManager(SFXLocalPlayer(GetPC().Player).GAWReinforcementManager);
        Class'Engine'.static.FlushAsyncLoading();
        GetPC().StopLoadingMovie();
        if (((nResult == 0 && GAWManager != None) && GAWManager.LastAwardedCards.Length != 0) && bShowRevealReinforcementsOnUnexpectedAwarding)
        {
            bManuallyRevealingReinforcements = FALSE;
            GetPC().ShowReinforcementsRevealScreeen(FinishInitialization);
        }
        else
        {
            FinishInitialization();
        }
    }
    public function BeginState(Name PreviousStateName)
    {
        local SFXEngine Engine;
        local SFXOnlineSubsystem OnlineSub;
        local ISFXOnlineComponentGame OnlineGame;
        local SFXGAWReinforcementManager GAWManager;
        
        bCameFromSelectFirstCharacter = PreviousStateName == 'SelectFirstCharacter';
        if (GetLobbyGRI() != None)
        {
            GetLobbyGRI().GotoState('MultiplayerMenu', , , );
        }
        Engine = Class'SFXEngine'.static.GetSFXEngine();
        if (!Engine.LoadMovieManager.IsLoadingMoviePlaying())
        {
            Engine.ShowLoadScreen("");
        }
        OnlineSub = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem();
        if (OnlineSub != None)
        {
            OnlineGame = OnlineSub.GetComponentGame();
            if (OnlineGame != None && OnlineGame.IsPlaying())
            {
                OnlineGame.LeaveGame();
            }
        }
        InitializeWeaponUIManager();
        GAWManager = SFXGAWReinforcementManager(SFXLocalPlayer(GetPC().Player).GAWReinforcementManager);
        if (GAWManager != None)
        {
            GAWManager.ProcessConsumables(ContinueInitialization);
        }
        else
        {
            ContinueInitialization(-1);
        }
        if (Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentGame().WasKickedOutOfGame())
        {
            GetPC().QueueHostLeftMessage(FALSE);
        }
    }
    
    // State code
    stop;
};
state SelectFirstCharacterInLobby 
{
    // State Functions
    public function FinishSelectCharacterFlow(bool bSuccess)
    {
        if (bSuccess)
        {
            SetupLocalCharacterData();
            HideSelectKitScreen();
            GotoState('Lobby', , , );
        }
        else
        {
            ReturnToMainMenu();
        }
    }
    public function BeginState(Name PreviousStateName)
    {
        if (GetLobbyGRI() != None && IsServer())
        {
            GetLobbyGRI().GotoState('WaitingForPlayers', , , );
        }
        bAlwaysAllowGoBackFromKitSelect = TRUE;
        ShowMPSelectKitScreen();
    }
    
    // State code
    stop;
};
state SelectFirstCharacter 
{
    // State Functions
    public function FinishSelectCharacterFlow(bool bSuccess)
    {
        local SFXOnlineSubsystem oOnlineSubsystem;
        
        oOnlineSubsystem = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem();
        if (oOnlineSubsystem != None && oOnlineSubsystem.GetComponentGameEntryFlow() != None)
        {
            oOnlineSubsystem.GetComponentGameEntryFlow().OnKitDeployed(bSuccess);
        }
        if (bSuccess)
        {
            SetupLocalCharacterData();
            HideSelectKitScreen();
            GotoState('MultiplayerMenu', , , );
        }
        else
        {
            ReturnToMainMenu();
        }
    }
    public function BeginState(Name PreviousStateName)
    {
        if (GetLobbyGRI() != None)
        {
            GetLobbyGRI().GotoState('MultiplayerMenu', , , );
        }
        bAlwaysAllowGoBackFromKitSelect = TRUE;
        ShowMPSelectKitScreen();
    }
    
    // State code
    stop;
};
auto state Startup 
{
    // State Functions
    public function Tick(float TimeDelta)
    {
        local SFXEngine Engine;

        Super.Tick(TimeDelta);

        // MILAN CHANGE - Force MPSaveManager to initialize while the online
        // component is unavailable; otherwise the lobby UI can stall.
        Engine = SFXEngine(Class'SFXEngine'.static.GetEngine());
        if (Engine != None && Engine.MPSaveManager == None)
        {
            Engine.InitializePlayerStorage();
            Engine.MPSaveManager.bInitialized = true;
        }
        else if (Engine != None && Engine.MPSaveManager != None && Engine.MPSaveManager.OnlineSave == None)
        {
            Engine.MPSaveManager.Initialize();
            Engine.MPSaveManager.bInitialized = true;
        }

        if (GetPRI() != None && GetPRI().bReplicationReady)
        {
            if (!bPlayerDataSent)
            {
                if (IsReadyToSendPlayerDataToServer())
                {
                    SendPlayerDataToServer();
                    bPlayerDataSent = TRUE;
                }
            }
            else if (!bMPFlowStarted)
            {
                if (IsReadyToStartMPFlow())
                {
                    StartMPFlow();
                    bMPFlowStarted = TRUE;
                }
            }
            else if (!bReadyToEnterLobby)
            {
                if (IsReadyToEnterLobby())
                {
                    EnterLobby();
                    bReadyToEnterLobby = TRUE;
                }
            }
        }
    }
    public simulated function BeginState(Name PreviousStateName)
    {
        if (MapList.Length == 0)
        {
            MapList = GetAvailableMapList();
        }
        if (SFXEngine(Class'Engine'.static.GetEngine()) == None)
        {
            GotoState('MatchInProgress', , , );
            bMPFlowStarted = TRUE;
            GetPRI().SetReadyToPlay(TRUE);
            return;
        }
        bPlayerDataSent = FALSE;
        bMPFlowStarted = FALSE;
    }
    
    // State code
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    MPGUIPackages = ("GUI_MPImages")
    LobbyScreenTag = 'MPNewLobby'
    nLastOffer = -1
    FramesToWaitBeforeFadingFromBlack = 5
    bDirty = TRUE
    bShowRevealReinforcementsOnUnexpectedAwarding = TRUE
}
