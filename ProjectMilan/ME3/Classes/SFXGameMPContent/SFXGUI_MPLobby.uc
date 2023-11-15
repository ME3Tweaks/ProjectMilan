Class SFXGUI_MPLobby extends SFXGUIMovieMP
    config(UI);

// Types
struct InGameConsumableInfo 
{
    var string ConsumableName;
    var string ConsumableIconResource;
    var int ConsumableIconIndex;
    var int ConsumableCount;
    var int ConsumableCap;
    var int UniqueId;
};
struct PlayerDisplayInfo 
{
    var string Gamertag;
    var string PlayerName;
    var string ClassData;
    var string CurrentXPString;
    var string NextLevelXPString;
    var string CombinedXPString;
    var string Credits;
    var string KitTextureRef;
    var string SmallKitTextureRef;
    var string ClassIconTextureRef;
    var string KitPrettyName;
    var array<PowerDisplayInfo> PowerData;
    var array<WeaponDisplayInfo> WeaponData;
    var array<MatchConsumableDisplayInfo> MatchConsumableData;
    var int XPPercentage;
    var int Rating;
    var int NumKickVotesReceived;
    var bool Ready;
    var bool IsLocalPlayer;
    var bool IsLeader;
};
struct MatchConsumableDisplayInfo 
{
    var string MatchConsumableIconRef;
    var string MatchConsumableName;
    var int Category;
};
struct WeaponDisplayInfo 
{
    var string WeaponIconResource;
    var string WeaponImage;
    var string WeaponName;
    var string WeaponMod1Reference;
    var string WeaponMod2Reference;
    var int WeaponIconIndex;
};
struct PowerDisplayInfo 
{
    var string PowerIconResource;
    var string PowerName;
    var int PowerIconIndex;
};
const VOIP_REMOTE_HEADSETOK = 16;
const VOICE_CHAT_ICON_UPDATE_FREQUENCY = 0.5;

// Variables
var config array<EReinforcementGUICategory> ValidNewWeaponCategories;
var array<GAWZoneGUIData> GAWRatings;
var config stringref srExitMultiplayer;
var config stringref srExitMultiplayerConfirmation;
var config stringref srExitLobby;
var config stringref srExitLobbyConfirmation;
var config stringref srCancel;
var config stringref srCharacterClassAndLevel;
var config stringref srLeaderboardNotificationText;
var config stringref srFormattedXPShort;
var config stringref srFormattedXPLong;
var config stringref srMatchSettingBonusXP;
var config stringref srOriginIgoDisabled;
var config stringref srCredits;
var config stringref srFormattedReadiness;
var config stringref srGAWGlobalBonus;
var config stringref srGAWZoneBonus;
var SFXGAWReinforcementMatchConsumable AllConsumables;
var float ElapsedTime;
var BioPawn UIWorldPawnOriginal;
var float m_fPreviousMipLevelFadingValue;
var SFXGAWAssetsHandler GAWAssetHandler;
var bool bPreviouslyInParty;
var bool bPreviouslyCouldInteract;
var bool m_bGAWRatingsError;

// Functions
public final function bool IsPrivateMatch()
{
    return GetLobbyGRI().IsPrivateMatch();
}
public event function OnStart()
{
    Super(SFXGUIMovie).OnStart();
    SetGameMode(TRUE, 23);
    SetMouseVisible(TRUE);
    SetRequiresUIWorld(TRUE);
    PreloadLobbyImages();
    if (IsUIWorldPawnRequired(int(GetLobbyFlow().CurrentLobbyTab)))
    {
        SetupUIWorldPawn();
    }
    if (GetPreviousSubScreen() == 4)
    {
        ClearAllNewWeaponNotifications();
    }
    Refresh();
    GetLobbyFlow().RefreshLobbyStatusBars();
    GAWAssetHandler = Class'SFXGAWAssetsHandler'.static.GetGAWHandler();
    GAWAssetHandler.RequestGAWRatings(OnGAWRequestFinished);
}
public final function QuickMatch()
{
    if (!CheckIfSignedInFailSafe())
    {
        return;
    }
    PlayGuiSound('MPLobbyStartMatch');
    GetLobbyFlow().StartQuickMatch();
}
public final function ShowGamercard(int SlotIndex)
{
    local SFXPRIMP PRI;
    local int LocalUserNum;
    
    PRI = GetPlayerInSlot(SlotIndex);
    if (PRI != None)
    {
        PlayGuiSound('MPLobbyShowGamercard');
        LocalUserNum = LocalPlayer(GetPC().Player).ControllerId;
        Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentPlatform().ShowGamerCardUI(byte(LocalUserNum), PRI.UniqueId);
    }
}
public event function Update(float fDeltaT)
{
    Super(SFXGUIMovie).Update(fDeltaT);
    if (bPreviouslyInParty != IsInParty())
    {
        Refresh();
    }
    bPreviouslyInParty = IsInParty();
    if (bPreviouslyCouldInteract != CanInteract())
    {
        Refresh();
    }
    bPreviouslyCouldInteract = CanInteract();
    ElapsedTime += fDeltaT;
    if (ElapsedTime > 0.5)
    {
        RefreshAllSpeakerIcons();
        ElapsedTime = 0.0;
    }
}
public event function OnClose()
{
    CleanupUIWorldPawn();
    if (GAWAssetHandler != None)
    {
        GAWAssetHandler.Cleanup();
        GAWAssetHandler = None;
    }
    SetMouseVisible(FALSE);
    SetGameMode(FALSE, 23);
    Super(SFXGUIMovie).OnClose();
}
public final function int GetNumPlayers()
{
    return GetLobbyGRI().PRIArray.Length;
}
private final function bool CanAffordNewStoreItems()
{
    local SFXSaveManagerMP MPSaveManager;
    
    MPSaveManager = Class'SFXEngine'.static.GetSFXEngine().MPSaveManager;
    return MPSaveManager.HasNewReinforcementCategory(12);
}
public final function int GetCredits()
{
    return SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager.GetCredits();
}
public function array<GAWZoneGUIData> GetGAWRatings()
{
    return GAWRatings;
}
public function bool HasGAWRatingsError()
{
    return m_bGAWRatingsError;
}
public function OnGAWRequestFinished(array<GAWZoneGUIData> ZoneData, int Level, int errorCode)
{
    GAWRatings = ZoneData;
    m_bGAWRatingsError = errorCode != 0;
    AS_RefreshGalaxyAtWarMap();
}
public final function string GetLobbyStatus()
{
    return string(GetLobbyFlow().GetStateName());
}
public final function int GetPreviousSubScreen()
{
    return int(GetLobbyFlow().PreviousSubScreen);
}
public function ApplyTinting(Object InSettings)
{
    local Actor TargetActor;
    local SFXCustomizationInstance_PlayerMP LocalSettings;
    local SFXPawn_Player SourcePlayer;
    
    LocalSettings = SFXCustomizationInstance_PlayerMP(InSettings);
    SourcePlayer = SFXPawn_Player(UIWorldPawnOriginal);
    if (SourcePlayer != None)
    {
        TargetActor = oWorldInfo.m_UIWorld.GetSpawnedActor(SourcePlayer);
        if (TargetActor != None)
        {
            SourcePlayer.ApplyCustomizationToActor(TargetActor, LocalSettings);
        }
    }
}
public final function AS_ExitLobbyCancelled()
{
    ActionScriptVoid("screen.ExitLobbyCancelled");
}
public final function AS_ExitMultiplayerCancelled()
{
    ActionScriptVoid("screen.ExitMultiplayerCancelled");
}
public final function int AS_GetChallengeSetting()
{
    return ActionScriptInt("screen.GetChallengeSetting");
}
public final function int AS_GetEnemySetting()
{
    return ActionScriptInt("screen.GetEnemySetting");
}
public final function int AS_GetMapSetting()
{
    return ActionScriptInt("screen.GetMapSetting");
}
public final function int AS_GetPrivacySetting()
{
    return ActionScriptInt("screen.GetPrivacySetting");
}
public final function AS_OnTabLoaded(int Subscreen)
{
    ActionScriptVoid("screen.OnTabLoaded");
}
public final function AS_RefreshAllSpeakerIcons(array<float> VoiceData)
{
    ActionScriptVoid("screen.RefreshAllSpeakerIcons");
}
public final function AS_RefreshGalaxyAtWarMap()
{
    ActionScriptVoid("screen.RefreshGalaxyAtWarMap");
}
public final function AS_RefreshScreen()
{
    ActionScriptVoid("screen.RefreshScreen");
}
public final function bool CameFromSelectFirstCharacter()
{
    return GetLobbyFlow().bCameFromSelectFirstCharacter;
}
public final function CancelMatchSettings()
{
    GetLobbyFlow().FinishChangingMatchSettings(FALSE);
}
public final function bool CanInteract()
{
    return GetLobbyGRI().CanInteract();
}
public final function bool CanLevelUp()
{
    return HasTalentPointsToSpend();
}
public function ChangeMapMusic(int nMapId)
{
    GetLobbyFlow().ChangeMapMusic(nMapId);
}
public final function ChangeMatchSettings()
{
    local bool bPrivate;
    local bool bSettingsChanged;
    local int MapId;
    local int EnemyID;
    local int ChallengeID;
    
    bPrivate = AS_GetPrivacySetting() != 0;
    MapId = AS_GetMapSetting();
    EnemyID = AS_GetEnemySetting();
    ChallengeID = AS_GetChallengeSetting();
    bSettingsChanged = GetLobbyFlow().ChangeMatchSettings(bPrivate, MapId, EnemyID, ChallengeID);
    GetLobbyFlow().FinishChangingMatchSettings(bSettingsChanged);
}
private final function bool CheckIfSignedInFailSafe()
{
    local SFXPlayerControllerMP oPCMP;
    
    oPCMP = SFXPlayerControllerMP(GetPC());
    return oPCMP != None && oPCMP.CheckIfConnectedFailsafe();
}
public final function CleanupUIWorldPawn()
{
    Class'SFXGame'.static.SetMipFadingValue(m_fPreviousMipLevelFadingValue);
    if (oWorldInfo != None && oWorldInfo.m_UIWorld != None)
    {
        oWorldInfo.m_UIWorld.CleanupPawn(UIWorldPawnOriginal);
        UIWorldPawnOriginal = None;
    }
}
private final function ClearAllNewWeaponNotifications()
{
    local SFXSaveManagerMP MPSaveManager;
    local int idx;
    
    MPSaveManager = Class'SFXEngine'.static.GetSFXEngine().MPSaveManager;
    for (idx = 0; idx < ValidNewWeaponCategories.Length; ++idx)
    {
        MPSaveManager.ClearNewReinforcementCategory(ValidNewWeaponCategories[idx]);
    }
}
public final function ConfirmExitLobby()
{
    local SFXOnlineSubsystem oOnlineSubsystem;
    local ISFXOnlineComponentGame oOnlineGame;
    
    oOnlineSubsystem = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem();
    if (oOnlineSubsystem != None)
    {
        oOnlineGame = oOnlineSubsystem.GetComponentGame();
        if (oOnlineGame != None)
        {
            oOnlineGame.LeaveGame();
        }
    }
    PlayGuiSound('MPLobbyExitConfirm');
    Class'SFXGUIInteraction'.static.GetInstance().StopGuiSound('Play_mus_mp');
    oWorldInfo.ConsoleCommand("disconnect");
}
public final function ConfirmExitMultiplayer()
{
    Class'SFXGUIInteraction'.static.GetInstance().StopGuiSound('Play_mus_mp');
    PlayGuiSound('MPLobbyExitConfirm');
    GetLobbyFlow().ExitMultiplayer();
}
public final function CustomMatch()
{
    if (!CheckIfSignedInFailSafe())
    {
        return;
    }
    GetLobbyFlow().ShowCustomMatchScreen();
}
public final function ExitLobby()
{
    local BioSFHandler_MessageBox messageBox;
    local BioMessageBoxOptionalParams Params;
    
    GetPRIMP().SetReadyInLobby(FALSE);
    PlayGuiSound('MPLobbyExit');
    messageBox = GetSFXUIController().CreateMessageBox(GetPC());
    messageBox.SetInputDelegate(ExitLobbyPopupInputDelegate);
    Params.srAText = srExitLobby;
    Params.srBText = srCancel;
    messageBox.DisplayMessageBox(srExitLobbyConfirmation, Params);
}
public final function ExitLobbyPopupInputDelegate(bool bAPressed, int nContext)
{
    if (bAPressed)
    {
        ConfirmExitLobby();
    }
    else
    {
        AS_ExitLobbyCancelled();
    }
}
public final function ExitMultiplayer()
{
    PlayGuiSound('MPLobbyExit');
    ShowExitMultiplayerConfirmationPopup();
}
public final function ExitMultiplayerConfirmationPopupInputDelegate(bool bAPressed, int nContext)
{
    if (bAPressed)
    {
        ConfirmExitMultiplayer();
    }
    else
    {
        AS_ExitMultiplayerCancelled();
    }
}
public final function array<MatchConsumableDisplayInfo> GetCharacterConsumableInfo(SFXPRIMP PRI)
{
    local array<MatchConsumableDisplayInfo> ConsumableData;
    local MatchConsumableDisplayInfo CurrConsumableData;
    local int idx;
    local int Idx2;
    local int CurrConsumableValue;
    local Name CurrConsumableClass;
    local SFXGAWReinforcementManager GAWManager;
    
    GAWManager = SFXGAWReinforcementManager(SFXLocalPlayer(GetPC().Player).GAWReinforcementManager);
    if (AllConsumables == None && GAWManager != None)
    {
        AllConsumables = GAWManager.GetUniqueMatchConsumables();
    }
    for (idx = 0; idx < Class'SFXPRIMP'.default.NumConsumablesAllowedPerMatch; ++idx)
    {
        PRI.GetActiveMatchConsumable(idx, CurrConsumableClass, CurrConsumableValue);
        if (CurrConsumableClass == 'None')
        {
            continue;
        }
        for (Idx2 = 0; Idx2 < AllConsumables.CardList.Length; ++Idx2)
        {
            if (Name(AllConsumables.CardList[Idx2].UniqueName) == CurrConsumableClass && AllConsumables.CardList[Idx2].VersionIdx == CurrConsumableValue)
            {
                SetCustomToken(0, Class'SFXWeaponUIDataManager'.static.GetRomanNumeral(AllConsumables.CardList[Idx2].VersionIdx + 1));
                CurrConsumableData.MatchConsumableName = GetUIString(AllConsumables.CardList[Idx2].GUIName, TRUE);
                ClearCustomTokens();
                CurrConsumableData.MatchConsumableIconRef = AllConsumables.CardList[Idx2].GUITextureRef;
                CurrConsumableData.Category = AllConsumables.CardList[Idx2].Category;
                ConsumableData.AddItem(CurrConsumableData);
                break;
            }
        }
    }
    return ConsumableData;
}
public final function PlayerDisplayInfo GetCharacterInfoBasic(SFXPRIMP PRI)
{
    local PlayerDisplayInfo PlayerData;
    local Name PlayerKit;
    local SFXSaveManagerMP MPSaveManager;
    local int CurrLevelXP;
    local int NextLevelXP;
    local int PrevLevelXP;
    local int Level;
    local int CurrentXP;
    local int n7Rating;
    local stringref ClassPrettyName;
    local MPKitData KitData;
    local float fCurrentXP;
    
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    PRI.GetCharacterData(PlayerData.PlayerName, PlayerKit, ClassPrettyName, Level, fCurrentXP, n7Rating);
    CurrentXP = int(fCurrentXP);
    KitData = MPSaveManager.GetKitData(PlayerKit);
    SetCustomToken(0, string(Level));
    SetCustomToken(1, GetUIString(MPSaveManager.GetKitBaseClassPrettyName(PlayerKit)));
    PlayerData.ClassData = GetUIString(srCharacterClassAndLevel, TRUE);
    Class'BioLevelUpSystem'.static.GetXPNeededForLevel(Level, CurrLevelXP);
    CurrentXP = CurrentXP - CurrLevelXP;
    if (!Class'BioLevelUpSystem'.static.GetXPNeededForLevel(Level + 1, NextLevelXP))
    {
        Class'BioLevelUpSystem'.static.GetXPNeededForLevel(Level - 1, PrevLevelXP);
        NextLevelXP = CurrLevelXP - PrevLevelXP;
        CurrentXP = NextLevelXP;
    }
    else
    {
        NextLevelXP = NextLevelXP - CurrLevelXP;
    }
    ClearCustomTokens();
    SetCustomToken(0, string(CurrentXP));
    PlayerData.CurrentXPString = GetUIString(srFormattedXPShort, TRUE);
    ClearCustomTokens();
    SetCustomToken(0, string(NextLevelXP));
    PlayerData.NextLevelXPString = GetUIString(srFormattedXPShort, TRUE);
    ClearCustomTokens();
    SetCustomToken(0, string(CurrentXP));
    SetCustomToken(1, string(NextLevelXP));
    PlayerData.CombinedXPString = GetUIString(srFormattedXPLong, TRUE);
    ClearCustomTokens();
    SetCustomToken(0, string(MPSaveManager.GetCredits()));
    PlayerData.Credits = GetUIString(srCredits, TRUE);
    ClearCustomTokens();
    PlayerData.XPPercentage = int((float(CurrentXP) / float(NextLevelXP)) * float(100));
    PlayerData.Rating = n7Rating;
    PlayerData.KitPrettyName = GetUIString(KitData.srDisplayName);
    PlayerData.KitTextureRef = KitData.KitTextureRef;
    PlayerData.SmallKitTextureRef = KitData.SmallKitTextureRef;
    PlayerData.ClassIconTextureRef = "";
    PlayerData.Gamertag = PRI.DisplayName;
    PlayerData.Ready = PRI.ReadyInLobby;
    PlayerData.IsLocalPlayer = PRI.IsLocalPlayerPRI();
    PlayerData.IsLeader = PRI == GetLobbyGRI().LeaderPRI;
    PlayerData.NumKickVotesReceived = int(PRI.NumKickVotesReceived);
    return PlayerData;
}
public final function PlayerDisplayInfo GetCharacterInfoDetailed(SFXPRIMP PRI)
{
    local PlayerDisplayInfo PlayerData;
    
    PlayerData = GetCharacterInfoBasic(PRI);
    PlayerData.PowerData = GetCharacterPowerInfo(PRI);
    PlayerData.WeaponData = GetCharacterWeaponInfo(PRI);
    PlayerData.MatchConsumableData = GetCharacterConsumableInfo(PRI);
    return PlayerData;
}
public final function array<PowerDisplayInfo> GetCharacterPowerInfo(SFXPRIMP PRI)
{
    local array<PowerDisplayInfo> PowerData;
    local PowerDisplayInfo CurrPowerData;
    local SFXSaveManagerMP MPSaveManager;
    local MPKitData KitData;
    
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    KitData = MPSaveManager.GetKitData(PRI.GetCharacterKit());
    CurrPowerData.PowerIconResource = KitData.PowerIconResource;
    CurrPowerData.PowerIconIndex = KitData.PowerIconIndex1;
    CurrPowerData.PowerName = GetUIString(KitData.srPowerName1);
    PowerData.AddItem(CurrPowerData);
    CurrPowerData.PowerIconIndex = KitData.PowerIconIndex2;
    CurrPowerData.PowerName = GetUIString(KitData.srPowerName2);
    PowerData.AddItem(CurrPowerData);
    CurrPowerData.PowerIconIndex = KitData.PowerIconIndex3;
    CurrPowerData.PowerName = GetUIString(KitData.srPowerName3);
    PowerData.AddItem(CurrPowerData);
    return PowerData;
}
public final function array<WeaponDisplayInfo> GetCharacterWeaponInfo(SFXPRIMP PRI)
{
    local array<WeaponDisplayInfo> WeaponData;
    local WeaponDisplayInfo CurrWeaponData;
    local SFXWeaponSelectWeaponData CurrWeaponManagerData;
    local SFXWeaponModData CurrWeaponModManagerData;
    local Name CurrWeaponClassName;
    local Name CurrModClassName;
    local int idx;
    local int nWeaponDataIndex;
    local int nModDataIndex;
    local int nModLevel;
    local int nWeaponLevel;
    local SFXWeaponUIDataManager DataManager;
    
    DataManager = GetLobbyFlow().DataManager;
    if (!DataManager.DataIsLoaded)
    {
        return WeaponData;
    }
    for (idx = 0; idx < 2; ++idx)
    {
        PRI.GetWeapon(idx, CurrWeaponClassName);
        if (CurrWeaponClassName != 'None')
        {
            CurrWeaponManagerData = DataManager.GetWeaponUIDataFromClassPath(CurrWeaponClassName, nWeaponDataIndex);
            CurrWeaponData.WeaponIconIndex = CurrWeaponManagerData.IconIndex;
            CurrWeaponData.WeaponIconResource = PathName(CurrWeaponManagerData.IconResource);
            CurrWeaponData.WeaponImage = PathName(CurrWeaponManagerData.Image);
            nWeaponLevel = PRI.GetWeaponLevel(CurrWeaponClassName);
            SetCustomToken(0, Class'SFXWeaponUIDataManager'.static.GetRomanNumeral(nWeaponLevel));
            CurrWeaponData.WeaponName = GetUIString(CurrWeaponManagerData.Name, TRUE);
            ClearCustomTokens();
            PRI.GetWeaponMod(idx, 0, CurrModClassName, nModLevel);
            CurrWeaponModManagerData = DataManager.GetWeaponModUIDataFromClassName(CurrModClassName, nModDataIndex);
            CurrWeaponData.WeaponMod1Reference = PathName(CurrWeaponModManagerData.Image);
            PRI.GetWeaponMod(idx, 1, CurrModClassName, nModLevel);
            CurrWeaponModManagerData = DataManager.GetWeaponModUIDataFromClassName(CurrModClassName, nModDataIndex);
            CurrWeaponData.WeaponMod2Reference = PathName(CurrWeaponModManagerData.Image);
        }
        else
        {
            CurrWeaponData.WeaponIconIndex = 0;
            CurrWeaponData.WeaponIconResource = "";
            CurrWeaponData.WeaponImage = "";
            CurrWeaponData.WeaponName = "";
            CurrWeaponData.WeaponMod1Reference = "";
            CurrWeaponData.WeaponMod2Reference = "";
        }
        WeaponData.AddItem(CurrWeaponData);
    }
    return WeaponData;
}
public final function int GetCurrentLobbyTab()
{
    return int(GetLobbyFlow().CurrentLobbyTab);
}
public final function string GetFormattedReadinessPercentage(int nReadiness)
{
    local string ReturnString;
    
    SetCustomToken(0, string(nReadiness));
    ReturnString = GetUIString(srFormattedReadiness, TRUE);
    ClearCustomTokens();
    return ReturnString;
}
public final function string GetGAWZoneBonusText(int MapId)
{
    local string BonusString;
    local SFXGAWAssetsHandler GAWAssetsHandler;
    local int nZoneIndex;
    local int nMapIndex;
    local float ZoneIncrease;
    local float OverallIncrease;
    local MPMapInfo MapInfo;
    
    if (MapId < 0)
    {
        return "";
    }
    else if (MapId == 0)
    {
        Class'SFXPRIMP'.static.GetZoneIncreases(ZoneIncrease, OverallIncrease, TRUE, Class'SFXWaveCoordinator_HordeOperation'.default.NumWaves, 0);
        SetCustomToken(0, string(int(OverallIncrease)));
        BonusString = GetUIString(srGAWGlobalBonus, TRUE);
    }
    else
    {
        MapInfo = GetMapInfo(MapId);
        nMapIndex = Class'SFXPRIMP'.default.MapSettings.Find('MapName', MapInfo.PackageName);
        if (nMapIndex < 0)
        {
            return "";
        }
        GAWAssetsHandler = Class'SFXGAWAssetsHandler'.static.GetGAWHandler();
        nZoneIndex = GAWAssetsHandler.GAWTheatreData.Find('ZoneID', Class'SFXPRIMP'.default.MapSettings[nMapIndex].ZoneID);
        if (nZoneIndex < 0)
        {
            return "";
        }
        Class'SFXPRIMP'.static.GetZoneIncreases(ZoneIncrease, OverallIncrease, FALSE, Class'SFXWaveCoordinator_HordeOperation'.default.NumWaves, nMapIndex);
        SetCustomToken(0, string(GAWAssetsHandler.GAWTheatreData[nZoneIndex].srZoneName));
        SetCustomToken(1, string(int(ZoneIncrease)));
        BonusString = GetUIString(srGAWZoneBonus, TRUE);
    }
    ClearCustomTokens();
    return BonusString;
}
public final function string GetLeaderboardNotificationText()
{
    return string(srLeaderboardNotificationText);
}
public final function string GetLobbyStatusString()
{
    return GetLobbyGRI().GetLobbyStatusString();
}
public final function PlayerDisplayInfo GetLocalPlayerBasicInfo()
{
    return GetCharacterInfoBasic(GetPRIMP());
}
public final function PlayerDisplayInfo GetLocalPlayerDetailedInfo()
{
    return GetCharacterInfoDetailed(GetPRIMP());
}
public final function int GetMapZoneID(string MapName)
{
    local int nMapIndex;
    
    nMapIndex = Class'SFXPRIMP'.default.MapSettings.Find('MapName', MapName);
    if (nMapIndex >= 0)
    {
        return int(Class'SFXPRIMP'.default.MapSettings[nMapIndex].ZoneID);
    }
    return -1;
}
public final function int GetMatchConsumableSlotTypeForCategory(int Category)
{
    return Class'SFXGAWReinforcementMatchConsumable'.static.GetSlotTypeForCategory(Category);
}
public final function int GetMaxActiveConsumables()
{
    return Class'SFXPRIMP'.default.NumConsumablesAllowedPerMatch;
}
public final function int GetNumPlayerSlots()
{
    return GetLobbyGRI().NumPlayerSlots;
}
public final function SFXPRIMP GetPlayerInSlot(int Index)
{
    local PlayerReplicationInfo PRI;
    
    foreach GetLobbyGRI().PRIArray(PRI, )
    {
        if (SFXPRIMP(PRI).LobbyListOrder == Index)
        {
            return SFXPRIMP(PRI);
        }
    }
    return None;
}
public final function PlayerDisplayInfo GetPlayerSlotBasicInfo(int Index)
{
    return GetCharacterInfoBasic(GetPlayerInSlot(Index));
}
public final function PlayerDisplayInfo GetPlayerSlotDetailedInfo(int Index)
{
    return GetCharacterInfoDetailed(GetPlayerInSlot(Index));
}
public final function int GetPreviouslySelectedItem(int Subscreen)
{
    return GetLobbyFlow().PreviouslySelectedItems[Subscreen];
}
public function string GetRandomEnemyBonusText()
{
    local string BonusText;
    
    SetCustomToken(0, string(int(Class'SFXScoreManager'.default.RandomFactionScoreBonus * 100.0)));
    BonusText = GetUIString(srMatchSettingBonusXP, TRUE);
    ClearCustomTokens();
    return BonusText;
}
public function string GetRandomMapBonusText()
{
    local string BonusText;
    
    SetCustomToken(0, string(int(Class'SFXScoreManager'.default.RandomMapScoreBonus * 100.0)));
    BonusText = GetUIString(srMatchSettingBonusXP, TRUE);
    ClearCustomTokens();
    return BonusText;
}
public final function GoBackToSelectFirstCharacter()
{
    GetLobbyFlow().GoBackToSelectFirstCharacter();
}
public final function bool HasCreditsToSpend()
{
    return SFXPlayerControllerMP(GetPC()).PlayerHasCreditsToSpend();
}
public final function bool HasLeaderboardNotifications()
{
    return Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentLeaderboard().HasNotificationsAvailable();
}
private final function bool HasNewAppearanceOptions()
{
    local SFXSaveManagerMP MPSaveManager;
    local Name SelectedKitName;
    
    MPSaveManager = Class'SFXEngine'.static.GetSFXEngine().MPSaveManager;
    SelectedKitName = MPSaveManager.GetCurrentSelectedCharacterRecord().KitName;
    return MPSaveManager.HasNewReinforcement(13, string(SelectedKitName));
}
private final function bool HasNewMatchConsumables()
{
    local SFXSaveManagerMP MPSaveManager;
    
    MPSaveManager = Class'SFXEngine'.static.GetSFXEngine().MPSaveManager;
    return ((MPSaveManager.HasNewReinforcementCategory(8) || MPSaveManager.HasNewReinforcementCategory(9)) || MPSaveManager.HasNewReinforcementCategory(10)) || MPSaveManager.HasNewReinforcementCategory(11);
}
private final function bool HasNewWeapons()
{
    local SFXSaveManagerMP MPSaveManager;
    local int idx;
    
    MPSaveManager = Class'SFXEngine'.static.GetSFXEngine().MPSaveManager;
    for (idx = 0; idx < ValidNewWeaponCategories.Length; ++idx)
    {
        if (MPSaveManager.HasNewReinforcementCategory(ValidNewWeaponCategories[idx]))
        {
            return TRUE;
        }
    }
    return FALSE;
}
public final function bool HasTalentPointsToSpend()
{
    return SFXPlayerControllerMP(GetPC()).PlayerHasTalentPointsToSpend();
}
private final function bool HasVotedToKickPlayerInSlot(int SlotIndex)
{
    local SFXPRIMP OtherPRI;
    local UniqueNetId ZeroId;
    
    OtherPRI = GetPlayerInSlot(SlotIndex);
    return GetPRIMP().KickVotePlayerId != ZeroId && GetPRIMP().KickVotePlayerId == OtherPRI.UniqueId;
}
public final function HostNewMission()
{
    if (!CheckIfSignedInFailSafe())
    {
        return;
    }
    GetLobbyFlow().ShowHostNewMissionScreen();
}
public final function InviteFriends()
{
    local int LocalUserNum;
    local bool bInviteOk;
    local BioSFHandler_MessageBox messageBox;
    local BioMessageBoxOptionalParams messageParams;
    
    if (!IsGameFull())
    {
        PlayGuiSound('MPLobbyInvite');
        LocalUserNum = LocalPlayer(GetPC().Player).ControllerId;
        bInviteOk = Class'GameEngine'.static.GetOnlineSubsystem().PlayerInterfaceEx.ShowInviteUI(byte(LocalUserNum));
        if (!bInviteOk)
        {
            if (Class'WorldInfo'.static.IsConsoleBuild() == FALSE)
            {
                messageParams.srAText = Class'SFXGUI_MainMenu_RTT'.default.srOK;
                messageBox = GetSFXUIController().CreateMessageBox(GetPC());
                messageBox.DisplayMessageBox(srOriginIgoDisabled, messageParams);
            }
        }
    }
}
public final function InviteParty()
{
    local int LocalUserNum;
    
    if (!IsGameFull())
    {
        LocalUserNum = LocalPlayer(GetPC().Player).ControllerId;
        Class'GameEngine'.static.GetOnlineSubsystem().PlayerInterfaceEx.ShowInviteUI(byte(LocalUserNum));
    }
}
public final function bool IsGameFull()
{
    return GetNumPlayers() >= GetLobbyGRI().NumPlayerSlots;
}
public final function bool IsHostingNewMission()
{
    return GetLobbyFlow().bHostingNewMission;
}
public final function bool IsInParty()
{
    local SFXOnlineSubsystem OnlineSubsystem;
    local SFXOnlineComponentPlatformXenon OnlineComponentXenon;
    
    if (Class'WorldInfo'.static.IsConsoleBuild(1))
    {
        OnlineSubsystem = SFXOnlineSubsystem(Class'GameEngine'.static.GetOnlineSubsystem());
        OnlineComponentXenon = OnlineSubsystem.GetComponentPlatform();
        return OnlineComponentXenon.IsPlayerInActiveParty();
    }
    else
    {
        return FALSE;
    }
}
public final function bool IsUIWorldPawnRequired(int Subscreen)
{
    return (Subscreen == 11 || Subscreen == 3) || Subscreen == 12;
}
public final function LoadTab(int NewTab)
{
    local bool RequiredPawnBefore;
    local bool RequiresPawnNow;
    
    RequiredPawnBefore = IsUIWorldPawnRequired(int(GetLobbyFlow().CurrentLobbyTab));
    RequiresPawnNow = IsUIWorldPawnRequired(NewTab);
    GetLobbyFlow().CurrentLobbyTab = byte(NewTab);
    if (!RequiredPawnBefore && RequiresPawnNow)
    {
        SetupUIWorldPawn();
    }
    else if (RequiredPawnBefore && !RequiresPawnNow)
    {
        CleanupUIWorldPawn();
    }
    AS_OnTabLoaded(NewTab);
}
public final function PreloadLobbyImages()
{
    local int idx;
    local array<string> Images;
    local array<MPPrivacyInfo> PrivacyTypes;
    local array<MPMapInfo> MapList;
    local array<MPEnemyInfo> EnemyTypes;
    local array<MPChallengeInfo> ChallengeTypes;
    local SFXSaveManagerMP MPSaveManager;
    
    PrivacyTypes = GetPrivacyTypes();
    MapList = GetMapList();
    EnemyTypes = GetEnemyTypes();
    ChallengeTypes = GetChallengeTypes();
    for (idx = 0; idx < PrivacyTypes.Length; ++idx)
    {
        Images.AddItem(PrivacyTypes[idx].Image);
    }
    for (idx = 0; idx < MapList.Length; ++idx)
    {
        Images.AddItem(MapList[idx].Image);
    }
    for (idx = 0; idx < EnemyTypes.Length; ++idx)
    {
        Images.AddItem(EnemyTypes[idx].Image);
    }
    for (idx = 0; idx < ChallengeTypes.Length; ++idx)
    {
        Images.AddItem(ChallengeTypes[idx].Image);
    }
    Images.AddItem(Class'SFXOnlineGameSettings'.default.AnyMapImage);
    Images.AddItem(Class'SFXOnlineGameSettings'.default.AnyEnemyImage);
    Images.AddItem(Class'SFXOnlineGameSettings'.default.AnyChallengeImage);
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    for (idx = 0; idx < MPSaveManager.MPKits.Length; ++idx)
    {
        Images.AddItem(MPSaveManager.MPKits[idx].KitTextureRef);
    }
    PreloadImages(Images);
}
public final function Refresh()
{
    AS_RefreshScreen();
}
public final function RefreshAllSpeakerIcons()
{
    local array<float> VoiceData;
    local PlayerReplicationInfo PRI;
    local SFXOnlineComponentVoiceInterface oVoiceInterface;
    local int LocalUserNum;
    local bool bPlayerHasHeadset;
    local bool bPlayerIsTalking;
    local bool bPlayerIsMuted;
    
    oVoiceInterface = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentVoiceInterface();
    LocalUserNum = LocalPlayer(GetPC().Player).ControllerId;
    foreach GetLobbyGRI().PRIArray(PRI, )
    {
        bPlayerIsMuted = FALSE;
        if (SFXPRIMP(PRI) == GetPRIMP())
        {
            bPlayerHasHeadset = oVoiceInterface.IsHeadsetPresent(byte(LocalUserNum));
            bPlayerIsTalking = oVoiceInterface.IsLocalPlayerTalking(byte(LocalUserNum));
        }
        else
        {
            bPlayerHasHeadset = (oVoiceInterface.GetRemotePlayerStatus(PRI.UniqueId) & 16) != 0;
            bPlayerIsTalking = oVoiceInterface.IsRemotePlayerTalking(PRI.UniqueId);
            if (!Class'WorldInfo'.static.IsConsoleBuild())
            {
                bPlayerIsMuted = oVoiceInterface.IsRemoteTalkerMuted(byte(LocalUserNum), PRI.UniqueId);
            }
        }
        if (!bPlayerHasHeadset || bPlayerIsMuted)
        {
            VoiceData[SFXPRIMP(PRI).LobbyListOrder] = -1.0;
        }
        else
        {
            VoiceData[SFXPRIMP(PRI).LobbyListOrder] = float(bPlayerIsTalking ? 1 : 0);
        }
    }
    AS_RefreshAllSpeakerIcons(VoiceData);
}
public function SetInitialPawnPosition(Object Data)
{
    local Actor TargetActor;
    local SFXPawn_Player SourcePlayer;
    
    SourcePlayer = SFXPawn_Player(UIWorldPawnOriginal);
    if (SourcePlayer != None)
    {
        TargetActor = oWorldInfo.m_UIWorld.GetSpawnedActor(SourcePlayer);
        if (TargetActor != None)
        {
            TargetActor.SetLocation(m_UIWorldMPPawnInitialLocation, );
            TargetActor.SetRotation(m_UIWorldMPPawnInitialRotation);
        }
    }
}
public final function SetPreviouslySelectedItem(int Subscreen, int ItemIndex)
{
    GetLobbyFlow().PreviouslySelectedItems[Subscreen] = ItemIndex;
}
public final function SetReady(bool Ready)
{
    if (Ready)
    {
        PlayGuiSound('MPLobbySetReady');
    }
    else
    {
        PlayGuiSound('MPLobbySetNotReady');
    }
    GetPRIMP().SetReadyInLobby(Ready);
}
public final function SetupUIWorldPawn()
{
    UIWorldPawnOriginal = GetLobbyFlow().DummyPawn;
    oWorldInfo.m_UIWorld.TriggerEvent('SetupMPLobby', UIWorldPawnOriginal);
    oWorldInfo.m_UIWorld.SpawnPawn(UIWorldPawnOriginal, 'CharRecSpawnPoint', 'CharRecPawn', None, 'None', 4 | 8);
    oWorldInfo.m_UIWorld.AddDeferredOperation(ApplyTinting, SFXPawn_PlayerMP(UIWorldPawnOriginal).CustomizationMP);
    oWorldInfo.m_UIWorld.AddDeferredOperation(SetInitialPawnPosition);
    oWorldInfo.m_UIWorld.HidePawn(UIWorldPawnOriginal, FALSE);
    m_fPreviousMipLevelFadingValue = Class'SFXGame'.static.GetMipFadingValue();
    Class'SFXGame'.static.SetMipFadingValue(-1.0);
}
public final function bool ShouldShowChatDisabledMessage()
{
    local ISFXOnlineComponentPlatform oPlatform;
    local int LocalUserNum;
    
    oPlatform = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentPlatform();
    LocalUserNum = LocalPlayer(GetPC().Player).ControllerId;
    if (Class'WorldInfo'.static.IsConsoleBuild(2))
    {
        return int(oPlatform.CanCommunicate(byte(LocalUserNum))) == 0;
    }
    else
    {
        return FALSE;
    }
}
public final function ShowAppearanceScreen()
{
    local SFXSaveManagerMP MPSaveManager;
    
    if (!CheckIfSignedInFailSafe())
    {
        return;
    }
    if (GetPRIMP().bWaitingForPawn == FALSE)
    {
        MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
        MPSaveManager.SetCurrentModifiableCharacter(MPSaveManager.GetCurrentSelectedCharacterRecord().KitName);
        GetLobbyFlow().ShowMPAppearanceScreen();
        Close();
    }
}
public final function ShowExitMultiplayerConfirmationPopup()
{
    local BioSFHandler_MessageBox messageBox;
    local BioMessageBoxOptionalParams Params;
    
    messageBox = GetSFXUIController().CreateMessageBox(GetPC());
    messageBox.SetInputDelegate(ExitMultiplayerConfirmationPopupInputDelegate);
    Params.srAText = srExitMultiplayer;
    Params.srBText = srCancel;
    messageBox.DisplayMessageBox(srExitMultiplayerConfirmation, Params);
}
public final function ShowLeaderboardScreen()
{
    if (!CheckIfSignedInFailSafe())
    {
        return;
    }
    GetLobbyFlow().ShowLeaderboardScreen();
    Close();
}
public final function ShowMatchConsumablesScreen()
{
    if (!CheckIfSignedInFailSafe())
    {
        return;
    }
    GetLobbyFlow().ShowMatchConsumablesScreen();
    Close();
}
public final function ShowMatchSettingsScreen()
{
    local bool bIsLeader;
    
    bIsLeader = GetPRIMP() == GetLobbyGRI().LeaderPRI;
    if (bIsLeader)
    {
        GetPRIMP().SetReadyInLobby(FALSE);
    }
    GetLobbyFlow().ShowMatchSettingsScreen();
}
public final function ShowOptionsScreen()
{
    if (!CheckIfSignedInFailSafe())
    {
        return;
    }
    GetLobbyFlow().ShowOptionsScreen();
    Close();
}
public final function ShowPartySessions()
{
    local SFXOnlineSubsystem OnlineSubsystem;
    local int LocalUserNum;
    
    OnlineSubsystem = SFXOnlineSubsystem(Class'GameEngine'.static.GetOnlineSubsystem());
    if (OnlineSubsystem != None && OnlineSubsystem.PartyChatInterface != None)
    {
        LocalUserNum = LocalPlayer(GetPC().Player).ControllerId;
        OnlineSubsystem.PartyChatInterface.ShowCommunitySessionsUI(byte(LocalUserNum));
    }
}
public final function ShowStoreScreen()
{
    if (!CheckIfSignedInFailSafe())
    {
        return;
    }
    if (GetPRIMP().bWaitingForPawn == FALSE)
    {
        GetLobbyFlow().ShowStoreScreen();
        Close();
    }
}
public final function ShowTalentsLevelUpScreen()
{
    if (!CheckIfSignedInFailSafe())
    {
        return;
    }
    if (GetPRIMP().bWaitingForPawn == FALSE)
    {
        GetLobbyFlow().ShowTalentsLevelUpScreen();
        Close();
    }
}
public final function ShowWeaponsScreen()
{
    if (!CheckIfSignedInFailSafe())
    {
        return;
    }
    if (GetPRIMP().bWaitingForPawn == FALSE)
    {
        GetLobbyFlow().ShowWeaponsScreen();
        Close();
    }
}
public final function SwitchCharacter()
{
    if (!CheckIfSignedInFailSafe())
    {
        return;
    }
    GetPRIMP().SetReadyInLobby(FALSE);
    GetLobbyFlow().bAlwaysAllowGoBackFromKitSelect = FALSE;
    GetLobbyFlow().ShowMPSelectKitScreen();
    Close();
}
public final function ToggleMuteForSlot(int SlotIndex)
{
    local SFXOnlineComponentVoiceInterface oVoiceInterface;
    local SFXPRIMP PRI;
    local int LocalUserNum;
    
    PRI = GetPlayerInSlot(SlotIndex);
    if (PRI != None)
    {
        LocalUserNum = LocalPlayer(GetPC().Player).ControllerId;
        oVoiceInterface = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentVoiceInterface();
        if (oVoiceInterface.IsRemoteTalkerMuted(byte(LocalUserNum), PRI.UniqueId))
        {
            oVoiceInterface.UnmuteRemoteTalker(byte(LocalUserNum), PRI.UniqueId);
        }
        else
        {
            oVoiceInterface.MuteRemoteTalker(byte(LocalUserNum), PRI.UniqueId);
        }
    }
}
public final function ViewInvitations()
{
    local OnlineSubsystem OnlineSub;
    
    if (Class'WorldInfo'.static.IsConsoleBuild(2))
    {
        OnlineSub = Class'GameEngine'.static.GetOnlineSubsystem();
        if (OnlineSub != None)
        {
            SFXOnlineSubsystem(OnlineSub).GetComponentPlatform().ShowInbox();
        }
    }
}
private final function VoteToKickPlayerInSlot(int SlotIndex, bool bKick)
{
    local SFXPRIMP OtherPRI;
    local UniqueNetId ZeroId;
    
    if (bKick)
    {
        OtherPRI = GetPlayerInSlot(SlotIndex);
        if (!OtherPRI.IsLocalPlayerPRI())
        {
            GetPRIMP().SetKickVote(OtherPRI.UniqueId);
            Class'SFXTelemetry'.static.SendString('TelemetryHook_MP_KickVote', Class'OnlineSubsystem'.static.UniqueNetIdToString(OtherPRI.UniqueId));
        }
    }
    else
    {
        GetPRIMP().SetKickVote(ZeroId);
    }
}
public final function bool IsReady()
{
    return GetPRIMP().ReadyInLobby;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    ValidNewWeaponCategories = (EReinforcementGUICategory.EReinforcementGUICategory_Mod, EReinforcementGUICategory.EReinforcementGUICategory_AssaultRifle, EReinforcementGUICategory.EReinforcementGUICategory_SniperRifle, EReinforcementGUICategory.EReinforcementGUICategory_Pistol, EReinforcementGUICategory.EReinforcementGUICategory_SMG, EReinforcementGUICategory.EReinforcementGUICategory_Shotgun)
    srExitMultiplayer = $621032
    srExitMultiplayerConfirmation = $724951
    srExitLobby = $592437
    srExitLobbyConfirmation = $631051
    srCancel = $168246
    srCharacterClassAndLevel = $611705
    srLeaderboardNotificationText = $654801
    srFormattedXPShort = $677972
    srFormattedXPLong = $663144
    srMatchSettingBonusXP = $712076
    srOriginIgoDisabled = $722913
    srCredits = $723512
    srFormattedReadiness = $710700
    srGAWGlobalBonus = $724824
    srGAWZoneBonus = $724825
    m_UIWorldMPPawnInitialRotation = {Pitch = 0, Yaw = 29000, Roll = 0}
    m_bFocusOnStart = TRUE
}