// Source: ME3, Patch_SFXPRIMP
// Decompiled 9/4/2026 7:37:53 AM
// MILAN CHANGE - 09/06/2026 - Mgamerz
// Change maximum map count from 30 to 255
Class SFXPRIMP extends SFXPRI
    config(Game);

struct EmblemDisplayInfo 
{
    var string BackgroundResource;
    var int Id;
    var stringref srTitle;
};
struct MapConfigData 
{
    var string MapName;
    var float XPMultiplier;
    var float CreditsMultiplier;
    var int ZoneIncrease;
    var EGAWZone ZoneID;
};
struct MPCharacterData 
{
    var string CharacterName;
    var int CharacterKitID;
    var stringref ClassPrettyName;
    var int Level;
    var float XP;
    var int n7Rating;
    var int NumClassPromotions;
    var int Tint1ID;
    var int Tint2ID;
    var int PatternID;
    var int PatternColorID;
    var int PhongID;
    var int EmissiveID;
    var int SkinToneID;
    var int EmblemID;
    var int ChallengePoints;
    
    structdefaultproperties
    {
        NumClassPromotions = 0
        EmblemID = 0
        ChallengePoints = 0
    }
};
struct MPWeaponData 
{
    var MPWeaponModData WeaponMods[2];
    var int WeaponClassPathID;
    var int WeaponLevel;
    var bool IsValid;
};
struct MPWeaponModData 
{
    var int WeaponModClassPathID;
    var int WeaponModLevel;
};
struct MPPowerData 
{
    var int EvolvedChoices[6];
    var float CurrentRank;
    var int PowerClassPathID;
    var bool IsValid;
};
// MILAN CHANGE - 09/06/2026 - Mgamerz
// Make this 255 instead of 30
// I don't think this is actually used outside of compile time (bioware) but we should change it here to make sure it's accurate
const MAX_MAPS = 255; 
// END MILAN CHANGE
const MAX_PLAYER_MEDALS = 10;
const MAX_POWER_EVOLVED_CHOICES = 6;
const MAX_WEAPON_MODS = 2;
const MAX_WEAPONS = 2;
const MAX_POWERS = 6;

var repnotify UniqueNetId KickVotePlayerId;
var repnotify MPCharacterData CharacterData;
var string ComputerName;
var repnotify string DisplayName;
var config array<float> XPBonusMultipliers;
var const config array<string> DefaultLoadClasses;
var const string DEFAULT_PLAYER_ARCHETYPE_PATH;
var config array<MapConfigData> MapSettings;
var config array<EmblemDisplayInfo> EmblemList;
var repnotify MPPowerData CharacterPowers[6];
var repnotify MPWeaponData CharacterWeapons[2];
var transient repnotify int PlayerMedals[10];
var transient int PlayerMedalsCache[10];
var LinearColor NametagColor;
var Name ActiveXPBonusMultiplierPV;
var const Name DEFAULT_PLAYER_KIT;
var Name MatchConsumableGECategory;
var repnotify SFXPawn SFXPawn;
var config float EndOfMatchScreenDisplayTime;
var repnotify int LobbyListOrder;
var config float MaxReadinessXPBonus;
var Controller m_pControllerOfLastClientInitialize;
var config float GlobalZoneIncrease;
var config float RandomGlobalZoneIncrease;
var config float ScaledGlobalZoneIncrease;
var config float ScaledMapZoneIncrease;
var config float ScaledRandomGlobalZoneIncrease;
var config int NumConsumablesAllowedPerMatch;
var repnotify bool ReadyInLobby;
var bool StoreIsOpen;
var bool ReadyToTransitionToLobby;
var bool bEndOfMatchRecordsSaved;
var bool bEndOfMatchRatingsUpdated;
var bool bEndOfMatchScreenShownForLongEnough;
var bool bSaveRecordSet;
var repnotify bool bReplicationReady;
var transient bool bIsReplicationValid_CharacterPowers;
var transient bool bIsReplicationValid_CharacterWeapons;
var bool bWaitingForPawn;
var bool bLocalMapsSent;
// MILAN CHANGE - 09/06/2026 - Mgamerz
// Make this 255 instead of 30
var byte LocalMapArray[255];
var byte CombinedMapArray[255];
// END MILAN CHANGE
var repnotify byte NumKickVotesReceived;

public simulated function Pawn GetAPawn()
{
    return SFXPawn;
}
public simulated function bool GetPower(int PowerIndex, out Name PowerClassPath, out int EvolvedChoices[6], out int CurrentRank)
{
    local int i;
    
    if (PowerIndex < 0 || PowerIndex >= 6)
    {
        return FALSE;
    }
    PowerClassPath = Name(Class'SFXEngine'.static.GetStrFromSFXUniqueID(CharacterPowers[PowerIndex].PowerClassPathID));
    for (i = 0; i < 6; i++)
    {
        EvolvedChoices[i] = CharacterPowers[PowerIndex].EvolvedChoices[i];
    }
    CurrentRank = int(CharacterPowers[PowerIndex].CurrentRank);
    return TRUE;
}
public simulated function PostBeginPlay()
{
    bReadyToPlay = FALSE;
    Super.PostBeginPlay();
    SetReplicationReady();
}
public event simulated function ReplicatedEvent(Name VarName)
{
    local int i;
    
    Super.ReplicatedEvent(VarName);
    if (VarName == 'CharacterData')
    {
        OnCharacterChanged();
    }
    else if (VarName == 'CharacterWeapons')
    {
        if (!bIsReplicationValid_CharacterWeapons)
        {
            bIsReplicationValid_CharacterWeapons = TRUE;
            for (i = 0; i < 2; ++i)
            {
                if (!CharacterWeapons[i].IsValid)
                {
                    bIsReplicationValid_CharacterWeapons = FALSE;
                    break;
                }
            }
        }
        if (bIsReplicationValid_CharacterWeapons)
        {
            OnCharacterChanged();
        }
    }
    else if (VarName == 'CharacterPowers')
    {
        if (!bIsReplicationValid_CharacterPowers)
        {
            bIsReplicationValid_CharacterPowers = TRUE;
            for (i = 0; i < 6; ++i)
            {
                if (!CharacterPowers[i].IsValid)
                {
                    bIsReplicationValid_CharacterPowers = FALSE;
                    break;
                }
            }
        }
        if (bIsReplicationValid_CharacterPowers)
        {
            OnCharacterChanged();
        }
    }
    else if (VarName == 'SFXPawn')
    {
        if (SFXPawn != None)
        {
            bWaitingForPawn = FALSE;
        }
    }
    else if (VarName == 'ReadyInLobby')
    {
        if (GetLobbyFlow() != None)
        {
            GetLobbyFlow().RefreshLobbyScreen();
            GetLobbyFlow().RefreshLobbyStatusBars();
        }
    }
    else if (VarName == 'DisplayName' || VarName == 'ComputerName' || VarName == 'LobbyListOrder' || VarName == 'NumKickVotesReceived' || VarName == 'KickVotePlayerId')
    {
        if (GetLobbyFlow() != None)
        {
            GetLobbyFlow().RefreshLobbyScreen();
        }
    }
    else if (VarName == 'PlayerMedals')
    {
        OnPlayerMedalsChanged();
    }
}
public simulated function bool SetPower(int PowerIndex, Name PowerClassPath, int EvolvedChoices[6], int CurrentRank)
{
    local int i;
    
    if (PowerIndex < 0 || PowerIndex >= 6)
    {
        return FALSE;
    }
    CharacterPowers[PowerIndex].PowerClassPathID = Class'SFXEngine'.static.GetSFXUniqueIDFromStr(string(PowerClassPath));
    for (i = 0; i < 6; i++)
    {
        CharacterPowers[PowerIndex].EvolvedChoices[i] = EvolvedChoices[i];
    }
    CharacterPowers[PowerIndex].CurrentRank = float(CurrentRank);
    return TRUE;
}
public simulated function SetWeapon(int WeaponIndex, Name WeaponClassPath, int WeaponLevel)
{
    if (WeaponIndex < 0 || WeaponIndex >= 2)
    {
        return;
    }
    CharacterWeapons[WeaponIndex].WeaponClassPathID = Class'SFXEngine'.static.GetSFXUniqueIDFromStr(string(WeaponClassPath));
    CharacterWeapons[WeaponIndex].WeaponLevel = WeaponLevel;
}
public function CopyProperties(PlayerReplicationInfo PRI)
{
    local SFXPRIMP NewPRI;
    local int idx;
    
    Super(PlayerReplicationInfo).CopyProperties(PRI);
    NewPRI = SFXPRIMP(PRI);
    NewPRI.ComputerName = ComputerName;
    NewPRI.CharacterData = CharacterData;
    for (idx = 0; idx < 2; ++idx)
    {
        NewPRI.CharacterWeapons[idx] = CharacterWeapons[idx];
    }
    for (idx = 0; idx < 6; ++idx)
    {
        NewPRI.CharacterPowers[idx] = CharacterPowers[idx];
    }
    NewPRI.NametagColor = NametagColor;
    NewPRI.DisplayName = DisplayName;
    for (idx = 0; idx < 4; idx++)
    {
        NewPRI.ActiveMatchConsumables[idx] = ActiveMatchConsumables[idx];
    }
    NewPRI.ActiveXPBonusMultiplierPV = ActiveXPBonusMultiplierPV;
}
public simulated function bool ShouldBroadCastWelcomeMessage(optional bool bExiting)
{
    return FALSE;
}
public simulated function UnregisterPlayerFromSession();

public function AddPlayerMedal(int Medal, optional int ReplaceMedal = 0, optional bool bDisplay = TRUE)
{
    local int i;
    
    for (i = 0; i < 10; i++)
    {
        if (PlayerMedals[i] == ReplaceMedal)
        {
            PlayerMedals[i] = Medal;
            break;
        }
    }
    if (Role == ENetRole.ROLE_Authority)
    {
        OnPlayerMedalsChanged(bDisplay);
    }
}
public simulated function bool CanSetReadyInLobby()
{
    return GetLobbyFlow().CanSetReady();
}
public simulated function GetCharacterData(out string CharacterName, out Name CharacterKit, out stringref ClassPrettyName, out int Level, out float XP, out int n7Rating)
{
    CharacterName = CharacterData.CharacterName;
    CharacterKit = GetCharacterKit();
    ClassPrettyName = CharacterData.ClassPrettyName;
    Level = CharacterData.Level;
    XP = CharacterData.XP;
    n7Rating = CharacterData.n7Rating;
}
public simulated function stringref GetPlayerChallengeTitle()
{
    return GetCurrentEmblemData().srTitle;
}
public simulated function int GetWeaponLevel(Name WeaponClassPath)
{
    local int Level;
    local int idx;
    local SFXEngine Engine;
    
    Level = 1;
    if (!bBot)
    {
        Engine = Class'SFXEngine'.static.GetSFXEngine();
        for (idx = 0; idx < 2; ++idx)
        {
            if (Class'SFXEngine'.static.GetSFXUniqueIDFromStr(string(WeaponClassPath)) == CharacterWeapons[idx].WeaponClassPathID)
            {
                break;
            }
        }
        if (idx >= 2)
        {
            if (Engine != None && SFXPawn.IsLocallyControlled())
            {
                Level = Class'SFXEngine'.static.GetSFXEngine().GetPlayerVariable(WeaponClassPath);
            }
        }
        else
        {
            Level = CharacterWeapons[idx].WeaponLevel;
        }
    }
    return Level;
}
public reliable client function GrantXP(float fXP)
{
    local SFXEngine Engine;
    local SFXMPCharacterRecord CharacterRecord;
    local int ActiveBonusIdx;
    
    Engine = SFXEngine(Class'Engine'.static.GetEngine());
    CharacterRecord = Engine.MPSaveManager.GetCurrentSelectedCharacterRecord();
    if (CharacterRecord.CharacterName != CharacterData.CharacterName)
    {
        return;
    }
    Engine.MPSaveManager.MPMatchResultsData.SetTotalSquadXP(int(fXP));
    if (Class'SFXGAWAssetsHandler'.static.GetGAWHandler().GetOverallReadiness() == 100)
    {
        fXP *= 1.0 + MaxReadinessXPBonus;
    }
    ActiveBonusIdx = Engine.GetPlayerVariable(ActiveXPBonusMultiplierPV);
    if (ActiveBonusIdx != 0)
    {
        Engine.MPSaveManager.MPMatchResultsData.SetBonusSquadXP(int(fXP * XPBonusMultipliers[ActiveBonusIdx]));
        fXP = fXP * (1.0 + XPBonusMultipliers[ActiveBonusIdx]);
        Engine.SetPlayerVariable(ActiveXPBonusMultiplierPV, 0);
        Class'SFXGAWReinforcementBase'.static.ConsumeNonGameplayConsumable(ActiveXPBonusMultiplierPV, ActiveBonusIdx);
    }
    Engine.MPSaveManager.LevelUpClass(CharacterRecord.className, fXP);
}
public simulated function bool IsMatchConsumableActive(int UniqueConsumableID, float Value)
{
    local int idx;
    
    if (UniqueConsumableID == 0)
    {
        return FALSE;
    }
    for (idx = 0; idx < NumConsumablesAllowedPerMatch; idx++)
    {
        if (ActiveMatchConsumables[idx].ClassNameID == UniqueConsumableID && ActiveMatchConsumables[idx].Value == Value)
        {
            return TRUE;
        }
    }
    return FALSE;
}
public simulated function bool IsReadyInLobby()
{
    return ReadyInLobby;
}
public simulated function OnCharacterChanged()
{
    if (GetLobbyFlow() != None)
    {
        GetLobbyFlow().OnCharacterChanged(Self);
    }
    NotifyPawnCharacterChanged();
}
public simulated function SendTelemetryForWeapons()
{
    local array<TelemetryAttribute> Attributes;
    local int WeaponIndex;
    local int ModIndex;
    local int ConsumableIndex;
    local Name WeaponName;
    local Name modName;
    local Name ConsumableName;
    local array<ActiveMatchConsumable> Consumables;
    
    for (WeaponIndex = 0; WeaponIndex < 2; ++WeaponIndex)
    {
        WeaponName = Name(Class'SFXEngine'.static.GetStrFromSFXUniqueID(CharacterWeapons[WeaponIndex].WeaponClassPathID));
         // MILAN Patched: Remove calls to SFXTelemetry
         // MILAN Patched: Remove calls to SFXTelemetry
         // MILAN Patched: Remove calls to SFXTelemetry
        for (ModIndex = 0; ModIndex < 2; ++ModIndex)
        {
            modName = Name(Class'SFXEngine'.static.GetStrFromSFXUniqueID(CharacterWeapons[WeaponIndex].WeaponMods[ModIndex].WeaponModClassPathID));
             // MILAN Patched: Remove calls to SFXTelemetry
             // MILAN Patched: Remove calls to SFXTelemetry
        }
    }
     // MILAN Patched: Remove calls to SFXTelemetry
    Attributes.Length = 0;
    GetActiveMatchConsumables(Consumables);
    for (ConsumableIndex = 0; ConsumableIndex < Consumables.Length; ++ConsumableIndex)
    {
        ConsumableName = Name(Class'SFXEngine'.static.GetStrFromSFXUniqueID(Consumables[ConsumableIndex].ClassNameID));
         // MILAN Patched: Remove calls to SFXTelemetry
         // MILAN Patched: Remove calls to SFXTelemetry
    }
     // MILAN Patched: Remove calls to SFXTelemetry
}
public simulated function SetPawn(SFXPawn P)
{
    SFXPawn = P;
    if (SFXPawn != None)
    {
        bWaitingForPawn = FALSE;
    }
    NotifyPawnCharacterChanged();
}
public simulated function SetReadyInLobby(bool NewReadyState)
{
    ReadyInLobby = NewReadyState;
    GetLobbyFlow().RefreshLobbyScreen();
    GetLobbyFlow().RefreshLobbyStatusBars();
    if (SFXGameInfoMP_Lobby(WorldInfo.Game) != None)
    {
        SFXGameInfoMP_Lobby(WorldInfo.Game).CheckAllPlayersReady();
    }
    if (Role < ENetRole.ROLE_Authority)
    {
        ServerSetReadyInLobby(NewReadyState);
    }
}
public simulated function TriggerNewScoreTag(int Amount, coerce string Message)
{
    local SFXGUI_MPScoretags ScoretagMovie;
    local SFXPlayerController PC;
    
    PC = SFXPlayerController(Owner);
    if (PC != None && PC.IsLocalPlayerController())
    {
        ScoretagMovie = PC.GetSFXUIController().CastGetMovie(Class'SFXGUI_MPScoretags', PC, PC.GetSFXUIController().MovieTag_MPScoretags);
        ScoretagMovie.QueueScoretag(Amount, Message);
    }
}
public simulated function bool IsPlayer()
{
    return SFXPawn != None && SFXPawn.IsPlayerPawn();
}
public simulated function LoadDataFromSave(SFXMPCharacterRecord Character)
{
    local SFXSaveManagerMP MPSaveManager;
    local SFXMPClassRecord ClassRecord;
    local SFXAccomplishmentManager AccManager;
    local int EmblemID;
    local int EmblemLevel;
    local int ChallengePoints;
    
    if (Character == None)
    {
        return;
    }
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    ClassRecord = MPSaveManager.GetClassRecord(Character.className);
    AccManager = SFXEngine(Class'Engine'.static.GetEngine()).AccomplishmentManager;
    if (AccManager != None)
    {
        AccManager.GetCurrentReward(EmblemID, EmblemLevel);
        ChallengePoints = AccManager.GetTotalChallengePoints();
    }
    SetCharacterData(Character.CharacterName, Character.KitName, MPSaveManager.GetKitBaseClassPrettyName(Character.KitName), ClassRecord.Level, ClassRecord.GetTotalXP(), MPSaveManager.GetN7Rating());
    SetCharacterData_Patch(ClassRecord.NumPromotions, EmblemID, ChallengePoints);
    SetAppearanceData(Character.Tint1ID, Character.Tint2ID, Character.PatternID, Character.PatternColorID, Character.PhongID, Character.EmissiveID, Character.SkinToneID);
    LoadPowerDataFromSave(Character);
    LoadWeaponDataFromSave(Character);
}
public final simulated function LoadPowerDataFromSave(SFXMPCharacterRecord Character)
{
    local int PowerIdx;
    
    ClearPowerData();
    for (PowerIdx = 0; PowerIdx < Character.Powers.Length; ++PowerIdx)
    {
        SetPower(PowerIdx, Character.Powers[PowerIdx].PowerClassName, Character.Powers[PowerIdx].EvolvedChoices, int(Character.Powers[PowerIdx].CurrentRank));
    }
}
public final simulated function LoadWeaponDataFromSave(SFXMPCharacterRecord Character)
{
    local int WeaponIdx;
    local int WeaponLevel;
    local int WeaponModIdx;
    local int WeaponModNamesIdx;
    local int WeaponModLevel;
    
    ClearWeaponData();
    for (WeaponIdx = 0; WeaponIdx < Character.Weapons.Length; ++WeaponIdx)
    {
        WeaponLevel = SFXEngine(Class'Engine'.static.GetEngine()).GetPlayerVariable(Character.Weapons[WeaponIdx].WeaponClassName);
        SetWeapon(WeaponIdx, Character.Weapons[WeaponIdx].WeaponClassName, WeaponLevel);
        for (WeaponModIdx = 0; WeaponModIdx < Character.WeaponMods.Length; ++WeaponModIdx)
        {
            if (Character.WeaponMods[WeaponModIdx].WeaponClassName == Character.Weapons[WeaponIdx].WeaponClassName)
            {
                for (WeaponModNamesIdx = 0; WeaponModNamesIdx < Character.WeaponMods[WeaponModIdx].WeaponModClassNames.Length; ++WeaponModNamesIdx)
                {
                    WeaponModLevel = SFXEngine(Class'Engine'.static.GetEngine()).GetPlayerVariable(Character.WeaponMods[WeaponModIdx].WeaponModClassNames[WeaponModNamesIdx]);
                    SetWeaponMod(WeaponIdx, WeaponModNamesIdx, Character.WeaponMods[WeaponModIdx].WeaponModClassNames[WeaponModNamesIdx], WeaponModLevel);
                }
                break;
            }
        }
    }
}
public final simulated function NotifyPawnCharacterChanged()
{
    if (SFXPawn_PlayerMP(SFXPawn) != None && GetCharacterKit() != 'None')
    {
        SFXPawn_PlayerMP(SFXPawn).SetMPAppearanceVariables(CharacterData.Tint1ID, CharacterData.Tint2ID, CharacterData.PatternID, CharacterData.PatternColorID, CharacterData.PhongID, CharacterData.EmissiveID, CharacterData.SkinToneID);
    }
}
public simulated function OnPlayerMedalsChanged(optional bool bDisplay = TRUE)
{
    local int i;
    local SFXEngine Engine;
    local SFXScoreManager ScoreManager;
    local BioPlayerController BioPC;
    
    ScoreManager = SFXGRI(WorldInfo.GRI).GetScoreManager();
    Engine = SFXEngine(Class'Engine'.static.GetEngine());
    BioPC = BioPlayerController(Owner);
    for (i = 0; i < 10; i++)
    {
        if (PlayerMedals[i] != PlayerMedalsCache[i])
        {
            if (Engine != None && Engine.AccomplishmentManager != None && BioPC != None && BioPC.IsLocalPlayerController())
            {
                if (PlayerMedals[i] > 0 && PlayerMedals[i] < ScoreManager.PlayerMedalDefinitions.Length)
                {
                    Engine.AccomplishmentManager.UpdateMedalChallenges(ScoreManager.PlayerMedalDefinitions[PlayerMedals[i]].Type, BioPC);
                }
            }
            if (bDisplay)
            {
                DisplayPlayerMedal(PlayerMedals[i]);
            }
            PlayerMedalsCache[i] = PlayerMedals[i];
        }
    }
}
public simulated function OnSaveRecordsComplete(int nResult)
{
    if (nResult != 0)
    {
    }
    bEndOfMatchRecordsSaved = TRUE;
    if (bEndOfMatchRatingsUpdated && bEndOfMatchScreenShownForLongEnough)
    {
        ClearTimer('EndOfMatchScreenFinished');
        ServerSetReadyToTransitionToLobby(TRUE);
    }
}
public simulated function OnUpdatedRankingsComplete(int nResult)
{
    local SFXEngine Engine;
    local SFXMatchResultsData MatchResultsData;
    
    Engine = SFXEngine(Class'Engine'.static.GetEngine());
    MatchResultsData = Engine.MPSaveManager.GetMPMatchResultsData();
    if (nResult != 0)
    {
        MatchResultsData.ClearGAWValues();
    }
    bEndOfMatchRatingsUpdated = TRUE;
    if (bEndOfMatchRecordsSaved && bEndOfMatchScreenShownForLongEnough)
    {
        ClearTimer('EndOfMatchScreenFinished');
        ServerSetReadyToTransitionToLobby(TRUE);
    }
}
public delegate function int PRITotalPointSort(SFXPRIMP A, SFXPRIMP B)
{
    return A.GetTotalPoints() >= B.GetTotalPoints() ? 0 : -1;
}
public final simulated function SendCharacterDataToServer(optional bool bCharacter = TRUE, optional bool bWeapon = TRUE, optional bool bPower = TRUE)
{
    if (bCharacter)
    {
        ServerSetCharacterSelection(CharacterData);
    }
    if (bWeapon)
    {
        ServerSetWeaponSelection(CharacterWeapons);
    }
    if (bPower)
    {
        ServerSetPowerSelection(CharacterPowers);
    }
}
public reliable server function ServerSetCharacterSelection(MPCharacterData Data)
{
    CharacterData = Data;
    OnCharacterChanged();
}
public reliable server function ServerSetComputerName(string sComputerName)
{
    SetComputerName(sComputerName);
}
public reliable server function ServerSetKickVote(UniqueNetId KickVote)
{
    KickVotePlayerId = KickVote;
    SFXGameInfoMP_Lobby(WorldInfo.Game).UpdateKickVotes();
    GetLobbyFlow().RefreshLobbyScreen();
}

// MILAN CHANGE - 09/06/2026 - Mgamerz
// Make this 255 instead of 30
public reliable server function ServerSetMapArray(byte MapArray[255])
{
    local int idx;
    
    for (idx = 0; idx < 255; ++idx)
    {
        LocalMapArray[idx] = MapArray[idx];
    }
    bLocalMapsSent = TRUE;
    SFXGRIMP_Lobby(WorldInfo.GRI).UpdateMapArrays();
}
// END MILAN CHANGE

public reliable server function ServerSetPowerSelection(MPPowerData Data[6])
{
    local int idx;
    
    for (idx = 0; idx < 6; ++idx)
    {
        CharacterPowers[idx] = Data[idx];
        CharacterPowers[idx].IsValid = TRUE;
    }
    OnCharacterChanged();
}
public reliable server function ServerSetReadyInLobby(bool NewReadyState)
{
    if (Role == ENetRole.ROLE_Authority)
    {
        SetReadyInLobby(NewReadyState);
    }
}
public reliable server function ServerSetReadyToTransitionToLobby(bool bReady)
{
    ReadyToTransitionToLobby = bReady;
}
public reliable server function ServerSetReplicationReady()
{
    SetReplicationReady();
}
public reliable server function ServerSetStoreIsOpen(bool NewStoreIsOpen)
{
    StoreIsOpen = NewStoreIsOpen;
    if (SFXGameInfoMP_Lobby(WorldInfo.Game) != None)
    {
        SFXGameInfoMP_Lobby(WorldInfo.Game).CheckAllPlayersReady();
    }
}
public reliable server function ServerSetWeaponSelection(MPWeaponData Data[2])
{
    local int idx;
    
    for (idx = 0; idx < 2; ++idx)
    {
        CharacterWeapons[idx] = Data[idx];
        CharacterWeapons[idx].IsValid = TRUE;
    }
    OnCharacterChanged();
}
public simulated function SetAppearanceData(int Tint1ID, int Tint2ID, int PatternID, int PatternColorID, int PhongID, int EmissiveID, int SkinToneID)
{
    CharacterData.Tint1ID = Tint1ID;
    CharacterData.Tint2ID = Tint2ID;
    CharacterData.PatternID = PatternID;
    CharacterData.PatternColorID = PatternColorID;
    CharacterData.PhongID = PhongID;
    CharacterData.EmissiveID = EmissiveID;
    CharacterData.SkinToneID = SkinToneID;
}
public simulated function SetCharacterData(string CharacterName, Name CharacterKit, stringref ClassPrettyName, int Level, float XP, int n7Rating)
{
    CharacterData.CharacterName = CharacterName;
    SetCharacterKit(CharacterKit);
    CharacterData.ClassPrettyName = ClassPrettyName;
    CharacterData.Level = Level;
    CharacterData.XP = XP;
    CharacterData.n7Rating = n7Rating;
}
public simulated function SetCharacterData_Patch(int NumClassPromotions, int EmblemID, int ChallengePoints)
{
    CharacterData.NumClassPromotions = NumClassPromotions;
    CharacterData.EmblemID = EmblemID;
    CharacterData.ChallengePoints = ChallengePoints;
}
public simulated function SetCharacterKit(Name CharacterKit)
{
    CharacterData.CharacterKitID = Class'SFXEngine'.static.GetSFXUniqueIDFromStr(string(CharacterKit));
}
public simulated function SetCharacterName(string CharacterName)
{
    CharacterData.CharacterName = CharacterName;
}
public simulated function SetComputerName(string sComputerName)
{
    ComputerName = sComputerName;
    if (ComputerName == "Local Profile" || ComputerName == "Player")
    {
        ComputerName = WorldInfo.ComputerName;
    }
    DisplayName = sComputerName;
    if (GetLobbyFlow() != None)
    {
        GetLobbyFlow().RefreshLobbyScreen();
    }
    if (Role < ENetRole.ROLE_Authority)
    {
        ServerSetComputerName(sComputerName);
    }
}
public simulated function SetKickVote(UniqueNetId KickVote)
{
    ServerSetKickVote(KickVote);
}
public reliable server function SetReadyToPlay(bool NewReadyState)
{
    local BioWorldInfo BioWorldInfo;
    local SFXGUI_MPMatchResults MatchResutlsMovie;
    local SFXPlayerController PC;
    
    BioWorldInfo = BioWorldInfo(WorldInfo);
    if (BioWorldInfo != None && BioWorldInfo.GetAutoBotsEnabled() == TRUE)
    {
        PC = SFXPlayerController(Owner);
        if (PC != None && PC.IsLocalPlayerController())
        {
            MatchResutlsMovie = PC.GetSFXUIController().CastGetMovie(Class'SFXGUI_MPMatchResults', PC, PC.GetSFXUIController().MovieTag_MPMatchResults);
            if (MatchResutlsMovie != None)
            {
                MatchResutlsMovie.OnContinue();
            }
        }
        if (SFXGameInfoMP_Lobby(WorldInfo.Game) != None)
        {
            SFXGameInfoMP_Lobby(WorldInfo.Game).CheckAllPlayersReady();
        }
    }
    bReadyToPlay = NewReadyState;
}
public simulated function SetReplicationReady()
{
    if (!bReplicationReady)
    {
        if (Role == ENetRole.ROLE_Authority)
        {
            bReplicationReady = TRUE;
        }
        else
        {
            ServerSetReplicationReady();
            SetTimer(0.5, FALSE, 'SetReplicationReady', );
        }
    }
}
public simulated function SetStoreIsOpen(bool NewStoreIsOpen)
{
    ServerSetStoreIsOpen(NewStoreIsOpen);
}
public simulated function bool SetWeaponMod(int WeaponIndex, int ModIndex, Name WeaponModClassPath, int WeaponModLevel)
{
    if (WeaponIndex < 0 || WeaponIndex >= 2 || ModIndex < 0 || ModIndex >= 2)
    {
        return FALSE;
    }
    CharacterWeapons[WeaponIndex].WeaponMods[ModIndex].WeaponModClassPathID = Class'SFXEngine'.static.GetSFXUniqueIDFromStr(string(WeaponModClassPath));
    CharacterWeapons[WeaponIndex].WeaponMods[ModIndex].WeaponModLevel = WeaponModLevel;
    return TRUE;
}
public simulated function bool VerifyPawnPowers(SFXPawn_Player Pawn)
{
    local array<Name> SavedPowers;
    local int idx;
    
    for (idx = 0; idx < 6; ++idx)
    {
        if (Pawn != None && Pawn.Role == ENetRole.ROLE_SimulatedProxy && !CharacterPowers[idx].IsValid)
        {
        }
        SavedPowers.Add(1);
        SavedPowers[idx] = Name(Class'SFXEngine'.static.GetStrFromSFXUniqueID(CharacterPowers[idx].PowerClassPathID));
    }
    return Class'SFXMPCharacterRecord'.static.VerifySavedPawnPowers(SavedPowers, Pawn);
}
public final simulated function ApplyMatchConsumableGameEffects(SFXPawn_Player pPawn)
{
    local SFXModule_GameEffectManager GEManager;
    local Class<SFXGameEffect> EffectClass;
    local int idx;
    local SFXGameEffect_MatchConsumableBase GEMatchConsumable;
    local SFXSaveManagerMP MPSaveManager;
    local SFXPlayerController PC;
    
    if (pPawn == None)
    {
        return;
    }
    GEManager = pPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (GEManager == None)
    {
        return;
    }
    GEManager.RemoveEffectsByCategory(MatchConsumableGECategory);
    for (idx = 0; idx < NumConsumablesAllowedPerMatch; idx++)
    {
        if (ActiveMatchConsumables[idx].ClassNameID == 0)
        {
            continue;
        }
        EffectClass = Class'SFXGameEffect'.static.LoadGameEffectClass(Class'SFXEngine'.static.GetStrFromSFXUniqueID(ActiveMatchConsumables[idx].ClassNameID));
        if (EffectClass == None)
        {
            continue;
        }
        GEMatchConsumable = SFXGameEffect_MatchConsumableBase(GEManager.CreateAndApplyEffect(EffectClass, MatchConsumableGECategory, 0.0, 2, ActiveMatchConsumables[idx].Value, pPawn.Controller));
        if (GEMatchConsumable != None)
        {
            GEMatchConsumable.Consume();
            ActiveMatchConsumables[idx].bShouldDeactivateAfterMatch = GEMatchConsumable.ShouldDeactivateAfterMatch;
        }
    }
    PC = SFXPlayerController(Owner);
    if (PC != None && PC.IsLocalPlayerController())
    {
        MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
        MPSaveManager.SaveLocalPRIMatchConsumablesForOfflineTransfer(Self);
    }
}

// MILAN CHANGE - 09/06/2026 - Mgamerz
// Make this 255 instead of 30
public simulated function BuildLocalMapArray(array<MPMapInfo> AvailableMaps)
{
    local int idx;
    local int MapId;
    
    for (idx = 0; idx < 255; ++idx)
    {
        LocalMapArray[idx] = 0;
    }
    for (idx = 0; idx < AvailableMaps.Length; ++idx)
    {
        MapId = AvailableMaps[idx].Id;
        if (MapId >= 0 && MapId < 255)
        {
            LocalMapArray[MapId] = 1;
            continue;
        }
    }
}
// END MILAN CHANGE

public final simulated function ClearActiveMatchConsumables()
{
    local int idx;
    
    for (idx = 0; idx < 4; idx++)
    {
        ActiveMatchConsumables[idx].ClassNameID = 0;
        ActiveMatchConsumables[idx].Value = 0.0;
    }
}
public final simulated function ClearPowerData()
{
    local int idx;
    local int Idx2;
    
    for (idx = 0; idx < 6; ++idx)
    {
        CharacterPowers[idx].CurrentRank = 0.0;
        for (Idx2 = 0; Idx2 < 6; ++Idx2)
        {
            CharacterPowers[idx].EvolvedChoices[Idx2] = 0;
        }
    }
}
public final simulated function ClearWeaponData()
{
    local int idx;
    local int Idx2;
    
    for (idx = 0; idx < 2; ++idx)
    {
        CharacterWeapons[idx].WeaponClassPathID = 0;
        CharacterWeapons[idx].WeaponLevel = 0;
        for (Idx2 = 0; Idx2 < 2; ++Idx2)
        {
            CharacterWeapons[idx].WeaponMods[Idx2].WeaponModClassPathID = 0;
            CharacterWeapons[idx].WeaponMods[Idx2].WeaponModLevel = 0;
        }
    }
}
public final simulated function DisplayPlayerMedal(int nMedal)
{
    local SFXGRI GRI;
    local SFXScoreManager ScoreManager;
    local string MedalName;
    local int ScoreBonus;
    local BioHintSystem HintSystem;
    local string Icon;
    
    GRI = SFXGRI(WorldInfo.GRI);
    ScoreManager = GRI.GetScoreManager();
    if (nMedal <= 0 || nMedal > ScoreManager.PlayerMedalDefinitions.Length)
    {
        return;
    }
    ClearCustomTokens();
    SetCustomToken(0, string(ScoreManager.PlayerMedalDefinitions[nMedal].Threshold));
    MedalName = string(ScoreManager.PlayerMedalDefinitions[nMedal].MedalName);
    ClearCustomTokens();
    ScoreBonus = ScoreManager.PlayerMedalDefinitions[nMedal].Score;
    Icon = ScoreManager.PlayerMedalDefinitions[nMedal].Icon;
    GRI.GetEventTicker().AddTickerEntry(PlayerName @ "-" @ MedalName @ "+" $ ScoreBonus);
    if (Owner != None)
    {
        HintSystem = BioHintSystem(BioPlayerController(Owner).HintSystem);
        HintSystem.AddNotification_MPMedalGranted(MedalName, ScoreBonus, Icon);
    }
}
public final simulated function EndOfMatchScreenFinished()
{
    bEndOfMatchScreenShownForLongEnough = TRUE;
    if (bEndOfMatchRecordsSaved && bEndOfMatchRatingsUpdated)
    {
        ServerSetReadyToTransitionToLobby(TRUE);
    }
}
public reliable client function GatherMatchResults(bool bMatchWin, int ExtractedPlayers[4])
{
    local SFXGameConfigMP ConfigMP;
    local float TeamXP;
    local PlayerReplicationInfo PRI;
    local SFXPRIMP CastPRI;
    local SFXGRIMP GRI;
    local SFXEngine Engine;
    local SFXMatchResultsData MatchResultsData;
    local SFXMPClassRecord ClassRecord;
    local SFXMPCharacterRecord CharacterRecord;
    local int MatchStartTime;
    local int MatchEndTime;
    local int MapSettingsIdx;
    local int Credits;
    local int idx;
    local int ZoneID;
    local SFXOnlineSubsystem OnlineSub;
    local float ZoneIncrease;
    local float OverallIncrease;
    
    GRI = SFXGRIMP(WorldInfo.GRI);
    if (!IsPlayer() || GRI == None || GRI.GameStatus == EGameStatus.GS_None || GRI.GameStatus == EGameStatus.GS_PendingMatch || GRI.GameStatus == EGameStatus.GS_ReturningToMainMenu)
    {
        return;
    }
    Engine = SFXEngine(Class'Engine'.static.GetEngine());
    MatchResultsData = Engine.MPSaveManager.GetMPMatchResultsData();
    ConfigMP = SFXGameConfigMP(GRI.gameconfig);
    CharacterRecord = Engine.MPSaveManager.GetCurrentSelectedCharacterRecord();
    ClassRecord = Engine.MPSaveManager.GetClassRecord(CharacterRecord.className);
    MapSettingsIdx = MapSettings.Find('MapName', WorldInfo.GetMapName());
    if (MapSettingsIdx != -1)
    {
        bEndOfMatchRatingsUpdated = FALSE;
        GetZoneIncreases(ZoneIncrease, OverallIncrease, GRI.bRandomMap, GRI.WaveCoordinator.GetFriendlyCurrentWaveNumber() - 1, MapSettingsIdx);
        if (GRI.bRandomMap)
        {
            ZoneID = -1;
        }
        else
        {
            ZoneID = int(MapSettings[MapSettingsIdx].ZoneID);
        }
        // MILAN Patched: Remove Galaxy At War calls
    }
    foreach GRI.PRIArray(PRI, )
    {
        CastPRI = SFXPRIMP(PRI);
        if (CastPRI != None && CastPRI.IsPlayer())
        {
            TeamXP += float(FCeil(CastPRI.GetTotalPoints() * ConfigMP.ScoreToXPMultiplier));
            MatchResultsData.UpdatePlayerScoreData(CastPRI.PlayerID, CastPRI.PlayerName, CastPRI.GetTotalPoints());
            MatchResultsData.SetPlayerKit(CastPRI.PlayerID, CastPRI.GetCharacterKit());
            MatchResultsData.SetPlayerLevel(CastPRI.PlayerID, CastPRI.CharacterData.Level);
            MatchResultsData.SetPlayerUniqueID(CastPRI.PlayerID, CastPRI.UniqueId);
            for (idx = 0; idx < 10; ++idx)
            {
                MatchResultsData.AddPlayerMedal(CastPRI.PlayerID, CastPRI.PlayerMedals[idx]);
            }
        }
    }
    for (idx = 0; idx < 10; ++idx)
    {
        MatchResultsData.AddSquadMedal(GRI.SquadMedals[idx]);
    }
    for (idx = 0; idx < 4; ++idx)
    {
        if (ExtractedPlayers[idx] != -1)
        {
            MatchResultsData.ExtractedPlayerIDs.AddItem(ExtractedPlayers[idx]);
        }
    }
    MatchResultsData.SetPlayerRewardOriginalExperience(float(FCeil(ClassRecord.GetTotalXP())));
    GrantXP(TeamXP);
    MatchResultsData.SetPlayerRewardNewExperience(float(FCeil(ClassRecord.GetTotalXP())));
    Credits = int(GetTotalCredits());
    GrantCredits(Credits);
    MatchResultsData.SetTotalSquadCredits(Credits);
    MatchStartTime = GRI.MatchStartTime;
    OnlineSub = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem();
    if (OnlineSub != None)
    {
        MatchEndTime = OnlineSub.GetComponentAPI().GetCurrentTime();
    }
    if (MatchStartTime == 0 || MatchEndTime == 0)
    {
        MatchResultsData.SetMatchTime(0);
    }
    else
    {
        MatchResultsData.SetMatchTime(MatchEndTime - MatchStartTime);
    }
    MatchResultsData.SetMatchSettings(GRI.MapSetting, MapSettings[MapSettingsIdx].ZoneID, int(ZoneIncrease), int(OverallIncrease), GRI.EnemySetting, GRI.DifficultySetting);
    MatchResultsData.SetMatchWaves(GRI.WaveCoordinator.GetFriendlyCurrentWaveNumber());
    MatchResultsData.SetMatchResult(bMatchWin);
    Engine.MPSaveManager.TotalGamesPlayed++;
    Engine.MPSaveManager.TotalTimePlayed += MatchEndTime - MatchStartTime;
    bEndOfMatchRecordsSaved = FALSE;
    Engine.MPSaveManager.SaveRecords(FALSE, OnSaveRecordsComplete);
    bEndOfMatchScreenShownForLongEnough = FALSE;
    SFXPlayerControllerMP(Owner).ShowMPEndOfMatchScreen();
    SetTimer(EndOfMatchScreenDisplayTime, FALSE, 'EndOfMatchScreenFinished', );
    if (Engine.AccomplishmentManager != None)
    {
        Engine.AccomplishmentManager.UpdateMatchChallenges(PlayerID, BioPlayerController(Owner));
    }
    Class'SFXTelemetryHooksMP'.static.SendMatchResults(PlayerID);
}
public simulated function GetAppearanceData(out int Tint1ID, out int Tint2ID, out int PatternID, out int PatternColorID, out int PhongID, out int EmissiveID, out int SkinToneID)
{
    Tint1ID = CharacterData.Tint1ID;
    Tint2ID = CharacterData.Tint2ID;
    PatternID = CharacterData.PatternID;
    PatternColorID = CharacterData.PatternColorID;
    PhongID = CharacterData.PhongID;
    EmissiveID = CharacterData.EmissiveID;
    SkinToneID = CharacterData.SkinToneID;
}
public function EAsyncLoadStatus GetAsyncLoadingStatus()
{
    local EAsyncLoadStatus Status;
    local EAsyncLoadStatus Result;
    local int idx;
    local int ModIdx;
    local string PawnArchetype;
    local Name ClassPath;
    local int EvolvedChoices[6];
    local int Rank;
    
    Result = EAsyncLoadStatus.ASYNC_LOAD_COMPLETE;
    PawnArchetype = GetPawnArchetype();
    if (PawnArchetype != "")
    {
        Status = EAsyncLoadStatus.ASYNC_LOAD_COMPLETE;
        Class'SFXEngine'.static.LoadSeekFreeObjectAsync(PawnArchetype, Class'Object', Status);
        if (Result == EAsyncLoadStatus.ASYNC_LOAD_COMPLETE && (Status == EAsyncLoadStatus.ASYNC_LOAD_STARTED || Status == EAsyncLoadStatus.ASYNC_LOAD_INPROGRESS))
        {
            Result = EAsyncLoadStatus.ASYNC_LOAD_INPROGRESS;
        }
    }
    for (idx = 0; idx < 2; ++idx)
    {
        GetWeapon(idx, ClassPath);
        if (ClassPath == Name(""))
        {
            continue;
        }
        Status = EAsyncLoadStatus.ASYNC_LOAD_COMPLETE;
        Class'SFXEngine'.static.LoadSeekFreeObjectAsync(string(ClassPath), Class'Object', Status);
        if (Result == EAsyncLoadStatus.ASYNC_LOAD_COMPLETE && (Status == EAsyncLoadStatus.ASYNC_LOAD_STARTED || Status == EAsyncLoadStatus.ASYNC_LOAD_INPROGRESS))
        {
            Result = EAsyncLoadStatus.ASYNC_LOAD_INPROGRESS;
        }
        for (ModIdx = 0; ModIdx < 2; ++ModIdx)
        {
            GetWeaponMod(idx, ModIdx, ClassPath, Rank);
            if (ClassPath == Name(""))
            {
                continue;
            }
            Status = EAsyncLoadStatus.ASYNC_LOAD_COMPLETE;
            Class'SFXEngine'.static.LoadSeekFreeObjectAsync(string(ClassPath), Class'Object', Status);
            if (Result == EAsyncLoadStatus.ASYNC_LOAD_COMPLETE && (Status == EAsyncLoadStatus.ASYNC_LOAD_STARTED || Status == EAsyncLoadStatus.ASYNC_LOAD_INPROGRESS))
            {
                Result = EAsyncLoadStatus.ASYNC_LOAD_INPROGRESS;
            }
        }
    }
    for (idx = 0; idx < 6; ++idx)
    {
        GetPower(idx, ClassPath, EvolvedChoices, Rank);
        if (ClassPath == Name(""))
        {
            continue;
        }
        Status = EAsyncLoadStatus.ASYNC_LOAD_COMPLETE;
        Class'SFXEngine'.static.LoadSeekFreeObjectAsync(string(ClassPath), Class'Object', Status);
        if (Result == EAsyncLoadStatus.ASYNC_LOAD_COMPLETE && (Status == EAsyncLoadStatus.ASYNC_LOAD_STARTED || Status == EAsyncLoadStatus.ASYNC_LOAD_INPROGRESS))
        {
            Result = EAsyncLoadStatus.ASYNC_LOAD_INPROGRESS;
        }
    }
    for (idx = 0; idx < DefaultLoadClasses.Length; ++idx)
    {
        Status = EAsyncLoadStatus.ASYNC_LOAD_COMPLETE;
        Class'SFXEngine'.static.LoadSeekFreeObjectAsync(DefaultLoadClasses[idx], Class'Object', Status);
        if (Result == EAsyncLoadStatus.ASYNC_LOAD_COMPLETE && (Status == EAsyncLoadStatus.ASYNC_LOAD_STARTED || Status == EAsyncLoadStatus.ASYNC_LOAD_INPROGRESS))
        {
            Result = EAsyncLoadStatus.ASYNC_LOAD_INPROGRESS;
        }
    }
    return Result;
}
public simulated function GetCharacterData_Patch(out int NumClassPromotions, out int EmblemID, out int ChallengePoints)
{
    NumClassPromotions = CharacterData.NumClassPromotions;
    EmblemID = CharacterData.EmblemID;
    ChallengePoints = CharacterData.ChallengePoints;
}
public simulated function Name GetCharacterKit()
{
    local string CharacterKit;
    
    CharacterKit = Class'SFXEngine'.static.GetStrFromSFXUniqueID(CharacterData.CharacterKitID);
    if (CharacterKit == "")
    {
        return DEFAULT_PLAYER_KIT;
    }
    return Name(CharacterKit);
}
public final simulated function EmblemDisplayInfo GetCurrentEmblemData()
{
    return GetEmblemData(CharacterData.EmblemID);
}
public final simulated function EmblemDisplayInfo GetEmblemData(int EmblemID)
{
    local EmblemDisplayInfo EmblemIter;
    local EmblemDisplayInfo ToRet;
    
    foreach EmblemList(EmblemIter, )
    {
        if (EmblemIter.Id == EmblemID)
        {
            ToRet = EmblemIter;
            break;
        }
    }
    return ToRet;
}
public simulated function SFXLobbyFlow GetLobbyFlow()
{
    local SFXPlayerControllerMP localPC;
    
    localPC = SFXPlayerControllerMP(BioWorldInfo(WorldInfo).GetLocalPlayerController());
    return localPC != None ? localPC.LobbyFlow : None;
}
public simulated function string GetPawnArchetype()
{
    local SFXEngine oEngine;
    local string URL;
    local string Options;
    local string DefaultKit;
    local Name KitToUse;
    local string KitArchetype;
    
    URL = WorldInfo.GetLocalURL();
    Options = Split(URL, "?");
    DefaultKit = Class'GameInfo'.static.ParseOption(Options, "overridekit");
    if (DefaultKit != "")
    {
        KitToUse = Name(DefaultKit);
    }
    else
    {
        KitToUse = GetCharacterKit();
    }
    oEngine = SFXEngine(Class'Engine'.static.GetEngine());
    KitArchetype = "";
    if (oEngine != None)
    {
        KitArchetype = oEngine.MPSaveManager.GetKitArchetypeReference(KitToUse);
        if (Class'SFXEngine'.static.IsSeekFreeObjectSupported(KitArchetype))
        {
            return KitArchetype;
        }
    }
    return DEFAULT_PLAYER_ARCHETYPE_PATH;
}
public simulated function bool GetStoreIsOpen()
{
    return StoreIsOpen;
}
public simulated function bool GetWeapon(int WeaponIndex, out Name WeaponClassPath)
{
    if (WeaponIndex < 0 || WeaponIndex >= 2)
    {
        return FALSE;
    }
    WeaponClassPath = Name(Class'SFXEngine'.static.GetStrFromSFXUniqueID(CharacterWeapons[WeaponIndex].WeaponClassPathID));
    return TRUE;
}
public simulated function bool GetWeaponMod(int WeaponIndex, int ModIndex, out Name WeaponModClassPath, out int WeaponModLevel)
{
    if (WeaponIndex < 0 || WeaponIndex >= 2 || ModIndex < 0 || ModIndex >= 2)
    {
        return FALSE;
    }
    WeaponModClassPath = Name(Class'SFXEngine'.static.GetStrFromSFXUniqueID(CharacterWeapons[WeaponIndex].WeaponMods[ModIndex].WeaponModClassPathID));
    WeaponModLevel = CharacterWeapons[WeaponIndex].WeaponMods[ModIndex].WeaponModLevel;
    return TRUE;
}
public static final function GetZoneIncreases(out float ZoneIncrease, out float OverallIncrease, bool bRandomMap, int Wave, int Map)
{
    local float PctComplete;
    local float PctZoneBonus;
    
    PctComplete = FClamp(float(Wave), 0.0, 10.0) / 10.0;
    PctZoneBonus = 1.0 - float((Class'SFXGAWAssetsHandler'.static.GetGAWHandler().GetOverallReadiness() - 50)) / 50.0;
    if (bRandomMap)
    {
        OverallIncrease = (default.RandomGlobalZoneIncrease + default.ScaledRandomGlobalZoneIncrease * PctZoneBonus) * PctComplete;
        ZoneIncrease = 0.0;
    }
    else
    {
        ZoneIncrease = (float(default.MapSettings[Map].ZoneIncrease) + default.ScaledMapZoneIncrease * PctZoneBonus) * PctComplete;
        OverallIncrease = (default.GlobalZoneIncrease + default.ScaledGlobalZoneIncrease * PctZoneBonus) * PctComplete;
    }
}
public reliable client function GrantCredits(int nCredits)
{
    local SFXEngine Engine;
    
    Engine = SFXEngine(Class'Engine'.static.GetEngine());
    if (Engine.MPSaveManager.GetCurrentSelectedCharacterRecord().CharacterName != CharacterData.CharacterName)
    {
        return;
    }
    Engine.MPSaveManager.AddCredits(nCredits, "game");
}
public simulated function bool IsAI()
{
    return !IsPlayer();
}

replication
{
    if (bNetDirty && Role == ENetRole.ROLE_Authority)
        KickVotePlayerId, PlayerMedals, SFXPawn, LobbyListOrder, ReadyInLobby, StoreIsOpen, bReplicationReady, bLocalMapsSent, CombinedMapArray, NumKickVotesReceived;
    if (bNetDirty && !bNetOwner && Role == ENetRole.ROLE_Authority)
        CharacterData, ComputerName, DisplayName, CharacterPowers, CharacterWeapons;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    DefaultLoadClasses = ("SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Ammo", "SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Revive", "SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Rocket", "SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Shield")
    DEFAULT_PLAYER_ARCHETYPE_PATH = "BioChar_MPPlayers.Archetypes.Adept.HumanMale_Adept"
    MapSettings = ({MapName = "BioP_MPCer", XPMultiplier = 1.0, CreditsMultiplier = 1.0, ZoneIncrease = 7, ZoneID = EGAWZone.EGAWZone_Terminus}, 
                   {MapName = "BioP_MPDish", XPMultiplier = 1.0, CreditsMultiplier = 1.0, ZoneIncrease = 7, ZoneID = EGAWZone.EGAWZone_Attican}, 
                   {MapName = "BioP_MPMoon", XPMultiplier = 1.0, CreditsMultiplier = 1.0, ZoneIncrease = 7, ZoneID = EGAWZone.EGAWZone_InnerCouncil}, 
                   {MapName = "BioP_MPNov", XPMultiplier = 1.0, CreditsMultiplier = 1.0, ZoneIncrease = 7, ZoneID = EGAWZone.EGAWZone_Earth}, 
                   {MapName = "BioP_MPRctr", XPMultiplier = 1.0, CreditsMultiplier = 1.0, ZoneIncrease = 7, ZoneID = EGAWZone.EGAWZone_Council}, 
                   {MapName = "BioP_MPSlum", XPMultiplier = 1.0, CreditsMultiplier = 1.0, ZoneIncrease = 7, ZoneID = EGAWZone.EGAWZone_Earth}, 
                   {MapName = "BioP_MPTowr", XPMultiplier = 1.0, CreditsMultiplier = 1.0, ZoneIncrease = 7, ZoneID = EGAWZone.EGAWZone_InnerCouncil}
                  )
    NametagColor = {R = 1.0, G = 1.0, B = 1.0, A = 1.0}
    ActiveXPBonusMultiplierPV = 'MatchConsumable_ActiveXPBonusMultiplierIndex'
    DEFAULT_PLAYER_KIT = 'AdeptHumanMale'
    MatchConsumableGECategory = 'MatchConsumableGameEffect'
    EndOfMatchScreenDisplayTime = 5.0
    MaxReadinessXPBonus = 0.0500000007
    GlobalZoneIncrease = 1.0
    RandomGlobalZoneIncrease = 3.0
    ScaledGlobalZoneIncrease = 2.0
    ScaledMapZoneIncrease = 3.0
    ScaledRandomGlobalZoneIncrease = 2.0
    NumConsumablesAllowedPerMatch = 3
    ReadyToTransitionToLobby = TRUE
    NetPriority = 2.5
}