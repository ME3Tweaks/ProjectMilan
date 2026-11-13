// MILAN CHANGE
// 09/21/2026 - Mgamerz
// Disable LogInternal calls from this class as it's REALLY spammy. Changes if (TRUE) to if (FALSE) - bioware even though it was annoying.
Class SFXAccomplishmentManager
    native
    config(Game);

struct native ChallengeEvent 
{
    var string PlayerKit;
    var string PlayerClass;
    var string MapName;
    var array<int> RequiredPlayerMedals;
    var array<int> PartialPlayerMedals;
    var array<int> RequiredSquadMedals;
    var array<int> PartialSquadMedals;
    var Name AccomplishmentProgressName;
    var Name KilledEnemyClass;
    var Name ChallengeDamageType;
    var Name PowerName;
    var int EventStartTime;
    var int EventEndTime;
    var stringref DamageSource;
    var int DifficultyLevel;
    var int EnemyType;
    var int NumPlayers;
    var bool bMelee;
    var bool bHeadShot;
    var bool bHeadGib;
    var bool bCombo;
    var bool bBiotic;
    var bool bTech;
    var ChallengeEventType ChallengeType;
    var MPMedalType MedalEarned;
    
    structdefaultproperties
    {
        EventStartTime = -1
        EventEndTime = -1
        DifficultyLevel = -1
        EnemyType = -1
        NumPlayers = -1
    }
};
enum ChallengeEventType
{
    CET_None,
    CET_EnemyKill,
    CET_EnemyScoreKill,
    CET_DamageScore,
    CET_MatchCompletion,
    CET_WavesCompleted,
    CET_Medal,
    CET_Power,
    CET_Assist,
    CET_Revive,
    CET_Promotion,
};
struct native AchievementReward 
{
    var string PlayerVariableGranted;
    var Name Name;
    var Name AccomplishmentName;
    var int EntitlementIDGranted;
    var int RewardIDGranted;
    var bool bUseNucleusCheck;
};
struct native GrinderAccomplishment 
{
    var Name AccomplishmentName;
    var Name AccomplishmentProgressName;
    var int Goal;
    var int Interval;
    var stringref Title;
    var stringref Description;
    var stringref MPDescription;
};
struct native AccomplishmentProgress 
{
    var Name Name;
    var int Index;
    var EProfileSetting LinkedProfileSetting;
};
struct native Accomplishment 
{
    var string Icon;
    var Name Name;
    var Name Parent;
    var Name ChallengeGroupName;
    var Name GrinderAccomplishmentName;
    var int Index;
    var int XboxAchievementID;
    var int XboxAvatarAwardID;
    var int PS3TrophyID;
    var stringref Title;
    var stringref Incomplete;
    var stringref Complete;
    var int PointValue;
    var stringref NotificationText;
    var stringref MPNotificationText;
    var int VisibilityStartTime;
    var int VisibilityEndTime;
    var bool IsMultiplayerOnly;
    var bool bRepeatableChallenge;
    var EAchievementID LinkedAchievementID;
    
    structdefaultproperties
    {
        XboxAchievementID = -1
        XboxAvatarAwardID = -1
        PS3TrophyID = -1
        LinkedAchievementID = EAchievementID.ACHIEVEMENT_NONE
    }
};
enum EAccomplishmentStorage
{
    ACCSTOR_None,
    ACCSTOR_AsAchievement,
    ACCSTOR_InOnlineStorage,
    ACCSTOR_InProfileSettings,
};

var(SFXAccomplishmentManager) config array<Accomplishment> AccomplishmentData;
var(SFXAccomplishmentManager) array<int> AccomplishmentIsComplete;
var(SFXAccomplishmentManager) array<int> AccomplishmentCompletionTimes;
var(SFXAccomplishmentManager) config array<AccomplishmentProgress> AccomplishmentProgressData;
var(SFXAccomplishmentManager) config array<GrinderAccomplishment> GrinderAccomplishmentData;
var(SFXAccomplishmentManager) config array<AchievementReward> Rewards;
var config array<ChallengeEvent> Challenges;
var SFXAccomplishmentStorage AccomplishmentStorage;
var config bool bChallengeSystemEnabled;
var transient bool IsDataValidated;
var transient bool bIsSaving;
var transient bool bPendingSave;
var transient bool bSaveRequired;

private final event function SFXOnlineJobSendMessage CreateJobSendAchievementMessage(int AchievementId)
{
    local array<string> Params;
    
    Params.AddItem(string(AchievementId));
    return Class'SFXOnlineJobSendMessage'.static.CreateSendMessageToAllFriendsJob(0, Params);
}
public function Destroyed()
{
    local int UserNum;
    
    if (AccomplishmentStorage != None)
    {
        for (UserNum = 0; UserNum < 4; ++UserNum)
        {
            AccomplishmentStorage.AcknowledgeWriteComplete(byte(UserNum), SaveComplete);
        }
    }
}
public final event function Initialize()
{
    local int MaxProgressIndex;
    local int MaxAccomplishmentIndex;
    local int MaxRewardIndex;
    local int i;
    
    if (AccomplishmentStorage == None)
    {
        AccomplishmentStorage = new (Self) Class'SFXAccomplishmentStorage';
    }
    MaxProgressIndex = 0;
    for (i = 0; i < AccomplishmentProgressData.Length; i++)
    {
        if (AccomplishmentProgressData[i].Index > MaxProgressIndex)
        {
            MaxProgressIndex = AccomplishmentProgressData[i].Index;
        }
    }
    MaxRewardIndex = 0;
    for (i = 0; i < Rewards.Length; i++)
    {
        if (Rewards[i].RewardIDGranted > MaxRewardIndex)
        {
            MaxRewardIndex = Rewards[i].RewardIDGranted;
        }
    }
    AccomplishmentStorage.Initialize(MaxProgressIndex + 1, MaxRewardIndex + 1);
    MaxAccomplishmentIndex = 0;
    for (i = 0; i < AccomplishmentData.Length; i++)
    {
        if (AccomplishmentData[i].Index > MaxAccomplishmentIndex)
        {
            MaxAccomplishmentIndex = AccomplishmentData[i].Index;
        }
    }
    if (MaxAccomplishmentIndex >= AccomplishmentIsComplete.Length)
    {
        AccomplishmentIsComplete.Length = MaxAccomplishmentIndex + 1;
        AccomplishmentCompletionTimes.Length = MaxAccomplishmentIndex + 1;
    }
}
public final function Save()
{
    local WorldInfo World;
    local int ControllerId;
    local PlayerController pController;
    
    bSaveRequired = FALSE;
    if (bIsSaving)
    {
        bPendingSave = TRUE;
    }
    else
    {
        World = Class'Engine'.static.GetCurrentWorldInfo();
        if (World != None)
        {
            pController = World.GetALocalPlayerController();
            if (pController != None && LocalPlayer(pController.Player) != None)
            {
                bIsSaving = TRUE;
                ControllerId = LocalPlayer(pController.Player).ControllerId;
                AccomplishmentStorage.UpdateFromAccomplishments(bChallengeSystemEnabled, AccomplishmentIsComplete, AccomplishmentProgressData, AccomplishmentCompletionTimes);
                if (FALSE)
                {
                    LogInternal("STATUS: Save is writing Accomplishments to Blaze with ControllerId" @ ControllerId, 'DevOnline');
                }
                if (!AccomplishmentStorage.Write(byte(ControllerId), SaveComplete))
                {
                    WarnInternal("Failed call to WritePlayerStorage in SFXAccomplishmentManager:Save.");
                }
            }
        }
    }
}
public final function Name AccomplishmentIndexToName(int AccomplishmentIndex)
{
    local int i;
    local Name AccomplishmentName;
    
    for (i = 0; i < AccomplishmentData.Length; ++i)
    {
        if (AccomplishmentData[i].Index == AccomplishmentIndex)
        {
            AccomplishmentName = AccomplishmentData[i].Name;
            break;
        }
    }
    return AccomplishmentName;
}
public final function Name AccomplishmentProgressIndexToName(int AccomplishmentProgressIndex)
{
    local int i;
    local Name AccomplishmentProgressName;
    
    for (i = 0; i < AccomplishmentProgressData.Length; ++i)
    {
        if (AccomplishmentProgressData[i].Index == AccomplishmentProgressIndex)
        {
            AccomplishmentProgressName = AccomplishmentProgressData[i].Name;
            break;
        }
    }
    return AccomplishmentProgressName;
}
public final function AddChallengePointsEarned(int PointsEarned)
{
    AccomplishmentStorage.CurrentChallengePoints += PointsEarned;
    Class'Engine'.static.GetCurrentWorldInfo().Game.WriteOnlineStats();
}
private final function bool AreAllChildAccomplishmentsCompleted(Name ParentAccomplishment)
{
    local int i;
    
    for (i = 0; i < AccomplishmentData.Length; ++i)
    {
        if (AccomplishmentData[i].Parent == ParentAccomplishment && AccomplishmentIsComplete[AccomplishmentData[i].Index] == 0)
        {
            return FALSE;
        }
    }
    return TRUE;
}
public final function bool CanUnlockAccomplishment(Name AccomplishmentName)
{
    local int i;
    
    i = AccomplishmentData.Find('Name', AccomplishmentName);
    if (i != -1)
    {
        // MILAN CHANGE - Mgamerz - 2026-10-13
        // Do not increment SP accomplishment data
        if (!AccomplishmentData[i].IsMultiplayerOnly)
        {
            return FALSE;
        }
        // END MILAN CHANGE
        return AccomplishmentIsComplete[AccomplishmentData[i].Index] == 0 || AccomplishmentData[i].bRepeatableChallenge;
    }
    WarnInternal("No Accomplishment matches ID" @ AccomplishmentName);
    return FALSE;
}
public native function bool CanUpdateAccomplishmentProgress(int CurrentProgress, int GrinderIndex, int AccomplishmentIndex);

public static final function EAccomplishmentStorage GetAccomplishmentParamsStorage(EAchievementID AchievementId, bool IsMultiplayerOnly)
{
    if (IsMultiplayerOnly)
    {
        return EAccomplishmentStorage.ACCSTOR_InOnlineStorage;
    }
    return EAccomplishmentStorage.ACCSTOR_InProfileSettings;
}
public final function EAccomplishmentStorage GetAccomplishmentStorage(int ArrayIndex)
{
    return GetAccomplishmentParamsStorage(AccomplishmentData[ArrayIndex].LinkedAchievementID, AccomplishmentData[ArrayIndex].IsMultiplayerOnly);
}
public final function GetCurrentChallengeData(out ChallengeEvent CurrentEvent, BioPlayerController PC)
{
    local SFXSaveManagerMP MPSaveManager;
    local SFXGRI GRI;
    
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    if (MPSaveManager != None)
    {
        CurrentEvent.PlayerKit = MPSaveManager.GetCurrentCharacterKit();
        CurrentEvent.PlayerClass = MPSaveManager.GetCurrentCharacterClass();
    }
    if (PC.WorldInfo != None)
    {
        CurrentEvent.MapName = PC.WorldInfo.GetMapName();
        GRI = SFXGRI(PC.WorldInfo.GRI);
        if (GRI != None)
        {
            CurrentEvent.DifficultyLevel = int(GRI.DifficultyHandler.CurrentDifficulty);
            CurrentEvent.EnemyType = GRI.GetEnemyWaveTypeID();
        }
    }
}
public final function GetCurrentReward(out int nRewardID, out int nRewardLevel)
{
    if (AccomplishmentStorage != None)
    {
        AccomplishmentStorage.GetCurrentReward(nRewardID, nRewardLevel);
    }
}
public native function GetDamageScoreAccomplishments(out ChallengeEvent CurrentEvent, out array<Name> Accomplishments);

public native function GetEnemyScoreAccomplishments(Class<SFXPawn> KilledPawnClass, out ChallengeEvent CurrentEvent, out array<Name> Accomplishments);

public final function bool GetGrinderAccomplishment(Name AccomplishmentName, out array<GrinderAccomplishment> GAList)
{
    local int i;
    
    for (i = 0; i < GrinderAccomplishmentData.Length; i++)
    {
        if (GrinderAccomplishmentData[i].AccomplishmentName == AccomplishmentName)
        {
            GAList.AddItem(GrinderAccomplishmentData[i]);
        }
    }
    return GAList.Length > 0;
}
public final function int GetGrinderAccomplishmentProgress(Name AccomplishmentProgressName, BioPlayerController PC)
{
    local EProfileSetting ProfileSettingId;
    local int Progress;
    local int i;
    
    Progress = -1;
    ProfileSettingId = GetProfileSettingFromAccomplishmentProgress(AccomplishmentProgressName);
    if (ProfileSettingId != EProfileSetting.Setting_Unknown)
    {
        if (PC != None && PC.ProfileSettings != None && PC.ProfileSettings.GetProfileSettingValueInt(int(ProfileSettingId), Progress))
        {
        }
        else
        {
            WarnInternal("Failed call to GetProfileSettingValueInt with ProfileSettingID" @ ProfileSettingId);
        }
    }
    else
    {
        i = AccomplishmentProgressData.Find('Name', AccomplishmentProgressName);
        if (i != -1)
        {
            Progress = AccomplishmentStorage.ProgressValues[AccomplishmentProgressData[i].Index];
        }
        else
        {
            WarnInternal("Failed call to GetGrinderAccomplishmentProgress with AccomplishmentProgressName" @ AccomplishmentProgressName);
        }
    }
    return Progress;
}
public native function GetKillAccomplishments(Class<SFXPawn> KilledPawnClass, Class<SFXDamageType> KillingDamageType, out ChallengeEvent CurrentEvent, out array<Name> Accomplishments);

public native function GetMatchAccomplishments(out ChallengeEvent CurrentEvent, out array<Name> Accomplishments);

public native function GetMedalAccomplishments(out ChallengeEvent CurrentEvent, out array<Name> Accomplishments);

public native function GetOtherAccomplishments(out ChallengeEvent CurrentEvent, out array<Name> Accomplishments);

public native function GetPowerAccomplishments(Class<SFXDamageType> PowerDamageType, out ChallengeEvent CurrentEvent, out array<Name> Accomplishments);

private final function EProfileSetting GetProfileSettingFromAccomplishmentProgress(Name AccomplishmentProgressName)
{
    local int i;
    
    for (i = 0; i < AccomplishmentProgressData.Length; ++i)
    {
        if (AccomplishmentProgressData[i].Name == AccomplishmentProgressName)
        {
            return AccomplishmentProgressData[i].LinkedProfileSetting;
        }
    }
    return EProfileSetting.Setting_Unknown;
}
public final function int GetTotalChallengePoints()
{
    if (bChallengeSystemEnabled)
    {
        return AccomplishmentStorage.CurrentChallengePoints;
    }
    else
    {
        return 0;
    }
}
public native function GetWaveAccomplishments(out ChallengeEvent CurrentEvent, out array<Name> Accomplishments);

public final function bool GrinderAccomplishmentIncrement(Name AccomplishmentProgressName, BioPlayerController PC)
{
    local int Progress;
    
    Progress = GetGrinderAccomplishmentProgress(AccomplishmentProgressName, PC);
    ++Progress;
    return SetGrinderAccomplishmentProgressWithUpdate(AccomplishmentProgressName, Progress, PC);
}
public final function GrinderAccomplishmentReset(Name AccomplishmentProgressName, BioPlayerController PC)
{
    SetGrinderAccomplishmentProgress(AccomplishmentProgressName, 0, PC);
}
public final function bool HasCompletedAccomplishment(Name AccomplishmentName)
{
    local int i;
    
    for (i = 0; i < AccomplishmentData.Length; ++i)
    {
        if (AccomplishmentData[i].Name == AccomplishmentName)
        {
            return AccomplishmentIsComplete[AccomplishmentData[i].Index] != 0;
        }
    }
    WarnInternal("No Accomplishment matches ID" @ AccomplishmentName);
    return FALSE;
}
public final function LoadAchievementData(array<AchievementDetails> AchievementsList, BioPlayerController PC)
{
    local int idx;
    local int AccomplishmentArrayIndex;
    local bool bSaveProfile;
    local AchievementDetails Achievement;
    
    if (!IsDataValidated)
    {
        Validate();
    }
    if (FALSE)
    {
        LogInternal("ACCOMPLISHMENT - LoadAchievementData", 'DevOnline');
    }
    if (AchievementsList.Length > 0)
    {
        ResetAchievementStatus();
    }
    for (idx = 0; idx < AchievementsList.Length; idx++)
    {
        Achievement = AchievementsList[idx];
        AccomplishmentArrayIndex = AccomplishmentData.Find('LinkedAchievementID', byte(Achievement.Id));
        if (AccomplishmentArrayIndex != -1)
        {
            if (FALSE)
            {
                LogInternal("ACCOMPLISHMENT - Loading Accomplishment" @ AccomplishmentData[AccomplishmentArrayIndex].Name @ "as" @ (Achievement.bWasAchievedOffline || Achievement.bWasAchievedOnline ? "COMPLETE" : "incomplete") @ "(LoadAchievementData)", 'DevOnline');
            }
            if (PropagateAccomplishmentCompletion(AccomplishmentData[AccomplishmentArrayIndex].Index, Achievement.bWasAchievedOffline || Achievement.bWasAchievedOnline, PC, FALSE))
            {
                bSaveProfile = TRUE;
            }
        }
    }
    if (bSaveProfile)
    {
        PC.SaveProfile(TRUE, FALSE);
    }
}
public final function LoadSettingsData(SFXProfileSettings CurrentProfileSettings)
{
    local int i;
    
    if (!IsDataValidated)
    {
        Validate();
    }
    if (FALSE)
    {
        LogInternal("ACCOMPLISHMENT - LoadSettingsData", 'DevOnline');
    }
    if (CurrentProfileSettings != None)
    {
        for (i = 0; i < AccomplishmentData.Length; ++i)
        {
            if (int(GetAccomplishmentStorage(i)) == 3)
            {
                AccomplishmentIsComplete[AccomplishmentData[i].Index] = CurrentProfileSettings.HasCompletedAccomplishment(AccomplishmentData[i].Index) ? 1 : 0;
                if (FALSE)
                {
                    LogInternal("ACCOMPLISHMENT - Loading Accomplishment" @ AccomplishmentData[i].Name @ "as" @ (AccomplishmentIsComplete[AccomplishmentData[i].Index] != 0 ? "COMPLETE" : "incomplete") @ "(LoadSettingsData)", 'DevOnline');
                }
            }
        }
        if (AccomplishmentStorage != None)
        {
            AccomplishmentStorage.ReadFromProfileSettings(Self, CurrentProfileSettings);
        }
    }
}
public final function LoadStorageData(byte LocalUserNum, bool bWasSuccessful)
{
    if (!IsDataValidated)
    {
        Validate();
    }
    if (FALSE)
    {
        LogInternal("STATUS: Accomplishments read from Blaze for" @ LocalUserNum @ "complete. Success:" @ bWasSuccessful, 'DevOnline');
    }
    if (bWasSuccessful)
    {
        AccomplishmentStorage.LoadCompleted();
        AccomplishmentStorage.ReadFromStorage(Self);
    }
}
public final function OnGrantedEntitlement(BWEntitlementId Id, int nResult)
{
    if (FALSE)
    {
        LogInternal("Granted entitlement " $ Id.nID $ " with result " $ nResult, 'DevOnline');
    }
}
private final function bool PropagateAccomplishmentCompletion(int Index, bool IsComplete, BioPlayerController PC, bool bSaveProfile)
{
    local int AccomplishmentIndex;
    
    if (Index < 0 || Index >= AccomplishmentIsComplete.Length)
    {
        return FALSE;
    }
    AccomplishmentIsComplete[Index] = IsComplete ? AccomplishmentIsComplete[Index] + 1 : 0;
    if (PC == None || PC.ProfileSettings == None)
    {
        WarnInternal("PropagateAccomplishmentCompletion failed - no PC or ProfileSettings");
        return FALSE;
    }
    AccomplishmentIndex = AccomplishmentData.Find('Index', Index);
    if (AccomplishmentIndex != -1)
    {
        if (AccomplishmentData[AccomplishmentIndex].IsMultiplayerOnly)
        {
            return TRUE;
        }
    }
    if (IsComplete)
    {
        return PC.ProfileSettings.SetAccomplishmentCompleted(Index, PC, bSaveProfile);
    }
    else
    {
        return PC.ProfileSettings.SetAccomplishmentUncompleted(Index, PC, bSaveProfile);
    }
}
private final function ResetAchievementStatus()
{
    local int idx;
    
    for (idx = 0; idx < AccomplishmentData.Length; idx++)
    {
        // MILAN CHANGE - d00t - 2026-11-13
        // Do not reset multiplayer accomplishments.
        if (!AccomplishmentData[idx].IsMultiplayerOnly)
        {
            AccomplishmentIsComplete[AccomplishmentData[idx].Index] = 0;
        }
        // END MILAN CHANGE
    }
}
public native function ResetChallengeGroupProgress(Name ChallengeGroupName);

public final function ResetChallengeRewards()
{
    local int i;
    
    if (AccomplishmentStorage != None)
    {
        for (i = 0; i < AccomplishmentStorage.RewardLevelValues.Length; i++)
        {
            AccomplishmentStorage.RewardLevelValues[i] = 0;
        }
    }
}
public final function SaveComplete(byte LocalUserNum, bool bWasSuccessful)
{
    if (FALSE)
    {
        LogInternal("STATUS: Accomplishments write to Blaze for" @ LocalUserNum @ "complete. Success:" @ bWasSuccessful, 'DevOnline');
    }
    if (bWasSuccessful)
    {
        AccomplishmentStorage.SaveCompleted();
        AccomplishmentStorage.IsInvalid = FALSE;
    }
    AccomplishmentStorage.AcknowledgeWriteComplete(LocalUserNum, SaveComplete);
    bIsSaving = FALSE;
    if (bPendingSave)
    {
        bPendingSave = FALSE;
        Save();
    }
}
public final function SaveOnInvalidVersion()
{
    if (AccomplishmentStorage.IsInvalid)
    {
        Save();
    }
}
public final function bool SetAccomplishmentCompleted(Name AccomplishmentName, BioPlayerController PC)
{
    local LocalPlayer LP;
    local array<GrinderAccomplishment> GAList;
    local GrinderAccomplishment GA;
    local Accomplishment CurrentAccomplishment;
    local int CurrentIndex;
    local int AccomplishmentIndexForGrinder;
    local int GrinderAccomplishmentIndex;
    local int PlatformAchievementId;
    local int PlatformAvatarAwardId;
    local int NumCompletions;
    local int NumGrinderAccomplishmentCompletions;
    
    if (PC == None || PC.ProfileSettings == None)
    {
        WarnInternal("SetAccomplishmentCompleted(" $ AccomplishmentName $ ") failed - no Controller or ProfileSettings");
        return FALSE;
    }
    CurrentIndex = AccomplishmentData.Find('Name', AccomplishmentName);
    if (CurrentIndex == -1)
    {
        WarnInternal("No Accomplishment matches ID" @ AccomplishmentName);
        return FALSE;
    }
    // MILAN CHANGE - Mgamerz - 2026-10-13
    // Do not increment SP accomplishment data
    if (!AccomplishmentData[CurrentIndex].IsMultiplayerOnly)
    {
        return FALSE;
    }
    // END MILAN CHANGE
    NumCompletions = AccomplishmentIsComplete[AccomplishmentData[CurrentIndex].Index];
    PropagateAccomplishmentCompletion(AccomplishmentData[CurrentIndex].Index, TRUE, PC, TRUE);
    UnlockReward(AccomplishmentName, AccomplishmentData[CurrentIndex].PointValue, AccomplishmentData[CurrentIndex].IsMultiplayerOnly, PC);
    if (AccomplishmentData[CurrentIndex].GrinderAccomplishmentName != 'None')
    {
        GrinderAccomplishmentIndex = GrinderAccomplishmentData.Find('AccomplishmentProgressName', AccomplishmentData[CurrentIndex].GrinderAccomplishmentName);
        AccomplishmentIndexForGrinder = AccomplishmentData.Find('Name', GrinderAccomplishmentData[GrinderAccomplishmentIndex].AccomplishmentName);
        if (AccomplishmentIndexForGrinder != -1)
        {
            NumGrinderAccomplishmentCompletions = AccomplishmentIsComplete[AccomplishmentData[AccomplishmentIndexForGrinder].Index];
            if (NumCompletions <= NumGrinderAccomplishmentCompletions)
            {
                GrinderAccomplishmentIncrement(AccomplishmentData[CurrentIndex].GrinderAccomplishmentName, PC);
            }
        }
    }
    AccomplishmentCompletionTimes[AccomplishmentData[CurrentIndex].Index] = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentAPI().GetCurrentTime();
    UpdateAccomplishmentTree(AccomplishmentData[CurrentIndex].Parent, PC);
    if (Class'WorldInfo'.static.IsConsoleBuild() == FALSE || AccomplishmentData[CurrentIndex].LinkedAchievementID == EAchievementID.ACHIEVEMENT_NONE)
    {
        if (GetGrinderAccomplishment(AccomplishmentName, GAList))
        {
            GA = GAList[0];
        }
        CurrentAccomplishment = AccomplishmentData[CurrentIndex];
        PC.HintSystem.AddNotification_AccomplishmentUnlocked(CurrentAccomplishment, GA);
    }
    if (AccomplishmentData[CurrentIndex].IsMultiplayerOnly && PC.OnlineSub != None)
    {
        SFXOnlineSubsystem(PC.OnlineSub).GetComponentJobQueue().AddJob(CreateJobSendAchievementMessage(CurrentIndex));
    }
    if (PC.OnlineSub != None && PC.OnlineSub.PlayerInterfaceEx != None)
    {
        LP = LocalPlayer(PC.Player);
        PlatformAchievementId = int(AccomplishmentData[CurrentIndex].LinkedAchievementID);
        PlatformAvatarAwardId = -1;
        if (Class'WorldInfo'.static.IsConsoleBuild(1))
        {
            PlatformAchievementId = AccomplishmentData[CurrentIndex].XboxAchievementID;
            PlatformAvatarAwardId = AccomplishmentData[CurrentIndex].XboxAvatarAwardID;
        }
        else if (Class'WorldInfo'.static.IsConsoleBuild(2))
        {
            PlatformAchievementId = AccomplishmentData[CurrentIndex].PS3TrophyID;
        }
        else if (!Class'WorldInfo'.static.IsConsoleBuild())
        {
            PlatformAchievementId = AccomplishmentData[CurrentIndex].Index;
        }
        if (PlatformAvatarAwardId >= 0)
        {
            if (PC.OnlineSub.PlayerInterfaceEx.UnlockAvatarAward(byte(LP.ControllerId), PlatformAvatarAwardId) == FALSE)
            {
                WarnInternal("SetAccomplishmentCompleted(" $ LP.ControllerId $ "," $ AccomplishmentName $ ") failed awarding avatar - Award id: " @ PlatformAvatarAwardId);
            }
        }
        if (PlatformAchievementId < 0)
        {
            WarnInternal("SetAccomplishmentCompleted(" $ LP.ControllerId $ "," $ AccomplishmentName $ ") failed :remapped to invalid online Achievement id: " @ AccomplishmentData[CurrentIndex].LinkedAchievementID @ " on PlatformID : " @ PlatformAchievementId);
            return FALSE;
        }
        if (PC.OnlineSub.PlayerInterface.UnlockAchievement(byte(LP.ControllerId), PlatformAchievementId) == FALSE)
        {
            WarnInternal("SetAccomplishmentCompleted(" $ LP.ControllerId $ "," $ AccomplishmentName $ ") failed - PlatformID" @ PlatformAchievementId);
        }
    }
    return TRUE;
}
public final function bool SetAccomplishmentUncompleted(Name AccomplishmentName, BioPlayerController PC)
{
    local int i;
    local int CurrentIndex;
    
    if (PC == None || PC.ProfileSettings == None)
    {
        WarnInternal("SetAccomplishmentUncompleted(" $ AccomplishmentName $ ") failed - no Controller or ProfileSettings");
        return FALSE;
    }
    CurrentIndex = -1;
    for (i = 0; i < AccomplishmentData.Length; ++i)
    {
        if (AccomplishmentData[i].Name == AccomplishmentName)
        {
            PropagateAccomplishmentCompletion(AccomplishmentData[i].Index, FALSE, PC, TRUE);
            CurrentIndex = i;
            break;
        }
    }
    if (CurrentIndex < 0)
    {
        WarnInternal("No Accomplishment matches ID" @ AccomplishmentName);
        return FALSE;
    }
    return TRUE;
}
public final function SetCurrentReward(int nRewardID)
{
    if (AccomplishmentStorage != None)
    {
        AccomplishmentStorage.SetCurrentReward(nRewardID);
    }
}
public final function SetGrinderAccomplishmentProgress(Name AccomplishmentProgressName, int Progress, BioPlayerController PC)
{
    local int i;
    local EProfileSetting ProfileSettingId;
    
    ProfileSettingId = GetProfileSettingFromAccomplishmentProgress(AccomplishmentProgressName);
    // MILAN CHANGE - Mgamerz - 2026-10-13
    // Do not save to MELE profile
    if (ProfileSettingId != EProfileSetting.Setting_Unknown)
    {
        return;
    }
    // END MILAN CHANGE
    for (i = 0; i < AccomplishmentProgressData.Length; ++i)
    {
        if (AccomplishmentProgressData[i].Name == AccomplishmentProgressName)
        {
            AccomplishmentStorage.ProgressValues[AccomplishmentProgressData[i].Index] = Progress;
            break;
        }
    }
}
public final function bool SetGrinderAccomplishmentProgressWithUpdate(Name AccomplishmentProgressName, int Progress, BioPlayerController PC)
{
    local int i;
    local int J;
    local int CurrentIndex;
    local int OldProgress;
    local string Title;
    local string Description;
    local GrinderAccomplishment CurrentGrinder;
    local bool IsProgressStillUsed;
    local bool bFound;
    local array<Name> AccomplishmentTreeBranchAlreadyNotified;
    local bool bResetProgress;
    
    if (BioWorldInfo(PC.WorldInfo).GetGlobalVariables().GetBoolByName('IgnoreGrinderAccomplishments'))
    {
        return FALSE;
    }
    OldProgress = GetGrinderAccomplishmentProgress(AccomplishmentProgressName, PC);
    if (OldProgress == Progress)
    {
        return FALSE;
    }
    for (i = 0; i < GrinderAccomplishmentData.Length; ++i)
    {
        if (GrinderAccomplishmentData[i].AccomplishmentProgressName == AccomplishmentProgressName)
        {
            CurrentGrinder = GrinderAccomplishmentData[i];
            bFound = FALSE;
            for (J = 0; J < AccomplishmentData.Length; ++J)
            {
                if (AccomplishmentData[J].Name == CurrentGrinder.AccomplishmentName)
                {
                    CurrentIndex = J;
                    bFound = TRUE;
                    break;
                }
            }
            if (!bFound)
            {
                WarnInternal("Could not match Grinder.AccomplishmentName" @ CurrentGrinder.AccomplishmentName @ "with any Accomplishment in AccomplishmentData.");
            }
            // MILAN CHANGE - Mgamerz - 2026-10-13
            // Base-game (non-MP) grinders don't advance in LMP - so show no progress toast, unlock or save for them
            if (bFound && !AccomplishmentData[CurrentIndex].IsMultiplayerOnly)
            {
                continue;
            }
            // END MILAN CHANGE
            if (bFound && CanUpdateAccomplishmentProgress(OldProgress, i, CurrentIndex) && AccomplishmentTreeBranchAlreadyNotified.Find(AccomplishmentData[CurrentIndex].Parent) == -1)
            {
                IsProgressStillUsed = TRUE;
                AccomplishmentTreeBranchAlreadyNotified.AddItem(AccomplishmentData[CurrentIndex].Parent);
                if (Progress >= CurrentGrinder.Goal)
                {
                    PC.UnlockAccomplishment(CurrentGrinder.AccomplishmentName);
                    bSaveRequired = TRUE;
                    if (AccomplishmentData[CurrentIndex].bRepeatableChallenge && AccomplishmentData[CurrentIndex].ChallengeGroupName == AccomplishmentData[CurrentIndex].Name)
                    {
                        bResetProgress = TRUE;
                        ResetChallengeGroupProgress(AccomplishmentData[CurrentIndex].ChallengeGroupName);
                    }
                    else if (AccomplishmentData[CurrentIndex].GrinderAccomplishmentName != 'None')
                    {
                        if (GetGrinderAccomplishmentProgress(AccomplishmentData[CurrentIndex].GrinderAccomplishmentName, PC) == 0)
                        {
                            bResetProgress = TRUE;
                        }
                    }
                    continue;
                }
                if (Progress - OldProgress >= CurrentGrinder.Interval || Progress % CurrentGrinder.Interval < OldProgress % CurrentGrinder.Interval)
                {
                    Title = Class'SFXGame'.static.GetSimpleString(CurrentGrinder.Title);
                    ClearCustomTokens();
                    if (CurrentGrinder.Goal > 0)
                    {
                        SetCustomToken(0, string(CurrentGrinder.Goal));
                    }
                    if (CurrentGrinder.MPDescription != 0 && (PC.WorldInfo.NetMode != ENetMode.NM_Standalone || PC.WorldInfo.bIsLobbyLevel))
                    {
                        Description = Class'SFXGame'.static.GetSimpleString(CurrentGrinder.MPDescription, TRUE);
                    }
                    else
                    {
                        Description = Class'SFXGame'.static.GetSimpleString(CurrentGrinder.Description, TRUE);
                    }
                    PC.HintSystem.AddNotification_AccomplishmentChange(Title, Progress $ "/" $ CurrentGrinder.Goal, Description, Progress, CurrentGrinder.Goal, AccomplishmentData[CurrentIndex].Icon);
                }
            }
        }
    }
    if (IsProgressStillUsed)
    {
        if (bResetProgress)
        {
            Progress = 0;
        }
        SetGrinderAccomplishmentProgress(AccomplishmentProgressName, Progress, PC);
    }
    return IsProgressStillUsed;
}
public function bool UnlockReward(Name AccomplishmentName, int PointsEarned, bool bIsMultiplayerOnly, BioPlayerController PC)
{
    local int idx;
    local int Idx2;
    local BWEntitlementId Entitlement;
    
    if (PC == None || PC.Pawn == None)
    {
        return FALSE;
    }
    if (!Class'SFXEngine'.static.AreGoBigFeaturesEnabled() || !bChallengeSystemEnabled)
    {
        return FALSE;
    }
    if (!bIsMultiplayerOnly)
    {
        return FALSE;
    }
    idx = Rewards.Find('AccomplishmentName', AccomplishmentName);
    if (idx != -1)
    {
        Idx2 = AccomplishmentData.Find('Name', AccomplishmentName);
        if (Idx2 != -1 && AccomplishmentIsComplete[AccomplishmentData[Idx2].Index] <= 1)
        {
            if (Rewards[idx].EntitlementIDGranted != 0)
            {
                Entitlement.nID = Rewards[idx].EntitlementIDGranted;
                Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentCommerce().GrantEntitlementId(Entitlement, OnGrantedEntitlement, Rewards[idx].bUseNucleusCheck);
            }
            if (Rewards[idx].PlayerVariableGranted != "")
            {
                SFXEngine(Class'Engine'.static.GetEngine()).SetPlayerVariable(Name(Rewards[idx].PlayerVariableGranted), 1);
            }
            if (Rewards[idx].RewardIDGranted != 0)
            {
                AccomplishmentStorage.UnlockRewardLevel(Rewards[idx].RewardIDGranted);
            }
        }
    }
    AddChallengePointsEarned(PointsEarned);
    return TRUE;
}
private final function UpdateAccomplishmentTree(Name ParentAccomplishment, BioPlayerController PC)
{
    local int i;
    
    for (i = 0; i < AccomplishmentData.Length; ++i)
    {
        if (AccomplishmentData[i].Name == ParentAccomplishment)
        {
            if (AreAllChildAccomplishmentsCompleted(AccomplishmentData[i].Name))
            {
                SetAccomplishmentCompleted(AccomplishmentData[i].Name, PC);
            }
            return;
        }
    }
}
public final function UpdateDamageScoreChallenges(float Score, stringref DamageSource, BioPlayerController PC)
{
    local array<Name> ScoreAccomplishments;
    local int i;
    local ChallengeEvent ChallengeData;
    
    if (!Class'SFXEngine'.static.AreGoBigFeaturesEnabled() || !bChallengeSystemEnabled)
    {
        return;
    }
    ChallengeData.DamageSource = DamageSource;
    GetCurrentChallengeData(ChallengeData, PC);
    GetDamageScoreAccomplishments(ChallengeData, ScoreAccomplishments);
    for (i = 0; i < ScoreAccomplishments.Length; i++)
    {
        UpdateGrinderAccomplishmentByValue(int(Score), ScoreAccomplishments[i], PC);
    }
    if (bSaveRequired)
    {
        Save();
    }
}
public final function UpdateEnemyScoreChallenges(Class<SFXPawn> KilledPawnClass, float Score, BioPlayerController PC)
{
    local array<Name> ScoreAccomplishments;
    local int i;
    local ChallengeEvent ChallengeData;
    
    if (!Class'SFXEngine'.static.AreGoBigFeaturesEnabled() || !bChallengeSystemEnabled)
    {
        return;
    }
    GetCurrentChallengeData(ChallengeData, PC);
    GetEnemyScoreAccomplishments(KilledPawnClass, ChallengeData, ScoreAccomplishments);
    for (i = 0; i < ScoreAccomplishments.Length; i++)
    {
        UpdateGrinderAccomplishmentByValue(int(Score), ScoreAccomplishments[i], PC);
    }
    if (bSaveRequired)
    {
        Save();
    }
}
public final function bool UpdateGrinderAccomplishmentByValue(int UpdateValue, Name AccomplishmentProgressName, BioPlayerController PC)
{
    local int Progress;
    
    Progress = GetGrinderAccomplishmentProgress(AccomplishmentProgressName, PC);
    Progress += UpdateValue;
    return SetGrinderAccomplishmentProgressWithUpdate(AccomplishmentProgressName, Progress, PC);
}
public final function UpdateKillChallenges(Class<SFXPawn> KilledPawnClass, Class<SFXDamageType> KillingDamageType, stringref KillingSource, bool bHeadShot, bool bHeadGib, BioPlayerController PC)
{
    local array<Name> KillAccomplishments;
    local int i;
    local ChallengeEvent ChallengeData;
    
    if (!Class'SFXEngine'.static.AreGoBigFeaturesEnabled() || !bChallengeSystemEnabled)
    {
        return;
    }
    ChallengeData.DamageSource = KillingSource;
    if (KillingDamageType != None)
    {
        ChallengeData.bMelee = KillingDamageType.default.bIsMelee;
    }
    ChallengeData.bHeadShot = bHeadShot;
    ChallengeData.bHeadGib = bHeadGib;
    GetCurrentChallengeData(ChallengeData, PC);
    GetKillAccomplishments(KilledPawnClass, KillingDamageType, ChallengeData, KillAccomplishments);
    for (i = 0; i < KillAccomplishments.Length; i++)
    {
        GrinderAccomplishmentIncrement(KillAccomplishments[i], PC);
    }
    if (bSaveRequired)
    {
        Save();
    }
}
public final function UpdateMatchChallenges(int PlayerID, BioPlayerController PC)
{
    local SFXMatchResultsData MatchResults;
    local int idx;
    local int Idx2;
    local array<Name> Accomplishments;
    local ChallengeEvent ChallengeData;
    local SFXGRI GRI;
    
    if (!Class'SFXEngine'.static.AreGoBigFeaturesEnabled() || !bChallengeSystemEnabled)
    {
        return;
    }
    MatchResults = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager.GetMPMatchResultsData();
    if (MatchResults != None)
    {
        for (idx = 0; idx < MatchResults.PlayerData.Length; ++idx)
        {
            if (MatchResults.PlayerData[idx].PlayerID == PlayerID)
            {
                for (Idx2 = 0; Idx2 < MatchResults.PlayerData[idx].PlayerMedalIDs.Length; ++Idx2)
                {
                    if (MatchResults.PlayerData[idx].PlayerMedalIDs[Idx2] != 0)
                    {
                        ChallengeData.PartialPlayerMedals.AddItem(MatchResults.PlayerData[idx].PlayerMedalIDs[Idx2]);
                    }
                }
            }
        }
        for (Idx2 = 0; Idx2 < MatchResults.SquadMedalIDs.Length; ++Idx2)
        {
            if (MatchResults.SquadMedalIDs[Idx2] != 0)
            {
                ChallengeData.PartialSquadMedals.AddItem(MatchResults.SquadMedalIDs[Idx2]);
            }
        }
        ChallengeData.NumPlayers = MatchResults.PlayerData.Length;
    }
    GRI = SFXGRI(PC.WorldInfo.GRI);
    if (GRI != None)
    {
        ChallengeData.NumPlayers = Max(ChallengeData.NumPlayers, int(GRI.MaxUniquePlayers));
    }
    GetCurrentChallengeData(ChallengeData, PC);
    GetMatchAccomplishments(ChallengeData, Accomplishments);
    for (idx = 0; idx < Accomplishments.Length; idx++)
    {
        GrinderAccomplishmentIncrement(Accomplishments[idx], PC);
    }
    Save();
}
public final function UpdateMedalChallenges(MPMedalType Medal, BioPlayerController PC)
{
    local array<Name> MedalAccomplishments;
    local int i;
    local ChallengeEvent ChallengeData;
    
    if (!Class'SFXEngine'.static.AreGoBigFeaturesEnabled() || !bChallengeSystemEnabled)
    {
        return;
    }
    ChallengeData.MedalEarned = Medal;
    GetCurrentChallengeData(ChallengeData, PC);
    GetMedalAccomplishments(ChallengeData, MedalAccomplishments);
    for (i = 0; i < MedalAccomplishments.Length; i++)
    {
        GrinderAccomplishmentIncrement(MedalAccomplishments[i], PC);
    }
    if (bSaveRequired)
    {
        Save();
    }
}
public final function UpdateMiscChallenges(ChallengeEventType ChallengeType, BioPlayerController PC)
{
    local array<Name> MiscAccomplishments;
    local ChallengeEvent ChallengeData;
    local int i;
    
    if (!Class'SFXEngine'.static.AreGoBigFeaturesEnabled() || !bChallengeSystemEnabled)
    {
        return;
    }
    ChallengeData.ChallengeType = ChallengeType;
    GetCurrentChallengeData(ChallengeData, PC);
    GetOtherAccomplishments(ChallengeData, MiscAccomplishments);
    for (i = 0; i < MiscAccomplishments.Length; i++)
    {
        GrinderAccomplishmentIncrement(MiscAccomplishments[i], PC);
    }
    if (bSaveRequired)
    {
        Save();
    }
}
public final function UpdateN7RatingChallenge(int n7Rating, BioPlayerController PC);

public final function UpdatePowerChallenges(Name PowerName, Class<SFXDamageType> PowerDamageType, bool bCombo, BioPlayerController PC)
{
    local array<Name> PowerAccomplishments;
    local ChallengeEvent ChallengeData;
    local int i;
    local Class<SFXDamageType_Power> PwrDamage;
    
    if (!Class'SFXEngine'.static.AreGoBigFeaturesEnabled() || !bChallengeSystemEnabled)
    {
        return;
    }
    ChallengeData.ChallengeType = ChallengeEventType.CET_Power;
    ChallengeData.PowerName = PowerName;
    ChallengeData.bCombo = bCombo;
    PwrDamage = Class<SFXDamageType_Power>(PowerDamageType);
    if (PwrDamage != None)
    {
        ChallengeData.bBiotic = PwrDamage.default.Discipline == EBioCapMode.BIO_CAPMODE_BIOTICS;
        ChallengeData.bTech = PwrDamage.default.Discipline == EBioCapMode.BIO_CAPMODE_TECH;
    }
    GetCurrentChallengeData(ChallengeData, PC);
    GetPowerAccomplishments(PowerDamageType, ChallengeData, PowerAccomplishments);
    for (i = 0; i < PowerAccomplishments.Length; i++)
    {
        GrinderAccomplishmentIncrement(PowerAccomplishments[i], PC);
    }
    if (bSaveRequired)
    {
        Save();
    }
}
public final function UpdateWaveChallenges(BioPlayerController PC)
{
    local int idx;
    local array<Name> Accomplishments;
    local ChallengeEvent ChallengeData;
    
    if (!Class'SFXEngine'.static.AreGoBigFeaturesEnabled() || !bChallengeSystemEnabled)
    {
        return;
    }
    GetCurrentChallengeData(ChallengeData, PC);
    GetWaveAccomplishments(ChallengeData, Accomplishments);
    for (idx = 0; idx < Accomplishments.Length; idx++)
    {
        GrinderAccomplishmentIncrement(Accomplishments[idx], PC);
    }
    if (bSaveRequired)
    {
        Save();
    }
}
public final function Validate()
{
    local int i;
    local int J;
    local int K;
    local int GrinderIndex;
    local int ProgressIndex;
    local array<Name> TempAccomplishmentNames;
    local array<int> TempAccomplishmentIndexes;
    local bool bFound;
    
    for (i = 0; i < AccomplishmentData.Length; ++i)
    {
        if (TempAccomplishmentNames.Find(AccomplishmentData[i].Name) > -1)
        {
            WarnInternal("Invalid setup for Accomplishment" @ AccomplishmentData[i].Name $ ": an Accomplishment with the same name already exists.");
        }
        TempAccomplishmentNames.AddItem(AccomplishmentData[i].Name);
        if (TempAccomplishmentIndexes.Find(AccomplishmentData[i].Index) > -1)
        {
            WarnInternal("Invalid setup for Accomplishment" @ AccomplishmentData[i].Name $ ": an Accomplishment with the same index already exists.");
        }
        TempAccomplishmentIndexes.AddItem(AccomplishmentData[i].Index);
        if (AccomplishmentData[i].IsMultiplayerOnly)
        {
            GrinderIndex = GrinderAccomplishmentData.Find('AccomplishmentName', AccomplishmentData[i].Name);
            if (GrinderIndex != -1)
            {
                ProgressIndex = AccomplishmentProgressData.Find('Name', GrinderAccomplishmentData[GrinderIndex].AccomplishmentProgressName);
                if (ProgressIndex != -1)
                {
                    if (AccomplishmentProgressData[ProgressIndex].LinkedProfileSetting != EProfileSetting.Setting_Unknown)
                    {
                        WarnInternal("Invalid setup for Accomplishment" @ AccomplishmentData[i].Name $ ": IsMultiplayerOnly == true but its progress is saved in the ProfileSettings.");
                    }
                }
            }
        }
    }
    for (i = 0; i < AccomplishmentData.Length; ++i)
    {
        J = i;
        while (AccomplishmentData[J].Parent != Name("none"))
        {
            if (AccomplishmentData[J].Parent == AccomplishmentData[i].Name)
            {
                WarnInternal("Invalid setup for Accomplishment" @ AccomplishmentData[i].Name $ ": its hierachical Parent" @ AccomplishmentData[J].Name @ "references it.");
                break;
                continue;
            }
            bFound = FALSE;
            for (K = 0; K < AccomplishmentData.Length; ++K)
            {
                if (AccomplishmentData[K].Name == AccomplishmentData[J].Parent)
                {
                    J = K;
                    bFound = TRUE;
                    break;
                }
            }
            if (!bFound)
            {
                WarnInternal("Invalid setup for Accomplishment" @ AccomplishmentData[i].Name $ ": one of its hierachical Parents" @ AccomplishmentData[J].Parent @ "cannot be found.");
                break;
            }
        }
    }
    TempAccomplishmentNames.Length = 0;
    TempAccomplishmentIndexes.Length = 0;
    for (i = 0; i < AccomplishmentProgressData.Length; ++i)
    {
        if (TempAccomplishmentNames.Find(AccomplishmentProgressData[i].Name) > -1)
        {
            WarnInternal("Invalid setup for AccomplishmentProgress" @ AccomplishmentProgressData[i].Name $ ": a AccomplishmentProgress with the same name already exists.");
        }
        TempAccomplishmentNames.AddItem(AccomplishmentProgressData[i].Name);
        if (TempAccomplishmentIndexes.Find(AccomplishmentProgressData[i].Index) > -1)
        {
            WarnInternal("Invalid setup for AccomplishmentProgress" @ AccomplishmentProgressData[i].Name $ ": a AccomplishmentProgress with the same index already exists.");
        }
        TempAccomplishmentIndexes.AddItem(AccomplishmentProgressData[i].Index);
    }
    IsDataValidated = TRUE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    AccomplishmentData = ({
                           Icon = "GUI_Achievement_Images.01_driven", 
                           Name = 'ProEar', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 0, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $558082, 
                           Incomplete = $558104, 
                           Complete = $558104, 
                           PointValue = 5, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_00_PROEAR
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.02_bringer_of_war", 
                           Name = 'ProMar', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 1, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $558083, 
                           Incomplete = $558105, 
                           Complete = $558105, 
                           PointValue = 10, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_01_PROMAR
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.03_mobilizer", 
                           Name = 'KroGar', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 2, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $660010, 
                           Incomplete = $660027, 
                           Complete = $660027, 
                           PointValue = 15, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_02_KROGAR
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.04_world_shaker", 
                           Name = 'Kro001', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 3, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $558085, 
                           Incomplete = $558107, 
                           Complete = $558107, 
                           PointValue = 15, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_03_KRO001
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.05_pathfinder", 
                           Name = 'Kro002', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 4, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $558086, 
                           Incomplete = $558108, 
                           Complete = $558108, 
                           PointValue = 15, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_04_KRO002
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.06_tunnel_rat", 
                           Name = 'KroGru', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 5, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $558087, 
                           Incomplete = $558109, 
                           Complete = $558109, 
                           PointValue = 15, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_05_KROGRU
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.07_party_crasher", 
                           Name = 'Gth001', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 6, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $558089, 
                           Incomplete = $558111, 
                           Complete = $558111, 
                           PointValue = 15, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_06_GTH001
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.08_hard_target", 
                           Name = 'Gth002', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 7, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $558090, 
                           Incomplete = $558112, 
                           Complete = $558112, 
                           PointValue = 15, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_07_GTH002
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.09_saboteur", 
                           Name = 'GthLeg', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 8, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $558091, 
                           Incomplete = $558113, 
                           Complete = $558113, 
                           PointValue = 15, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_08_GTHLEG
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.10_arbiter", 
                           Name = 'Cat003', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 9, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $558092, 
                           Incomplete = $558114, 
                           Complete = $558114, 
                           PointValue = 25, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_09_CAT003
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.11_last_witness", 
                           Name = 'Cat002', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 10, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $558093, 
                           Incomplete = $558115, 
                           Complete = $558115, 
                           PointValue = 25, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_10_CAT002
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.12_executioner", 
                           Name = 'Cat004', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 11, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $558094, 
                           Incomplete = $558116, 
                           Complete = $558116, 
                           PointValue = 25, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_11_CAT004
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.13_well_connected", 
                           Name = 'CerMir', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 12, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $558095, 
                           Incomplete = $558117, 
                           Complete = $558117, 
                           PointValue = 15, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_12_CERMIR
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.14_fact_finder", 
                           Name = 'CitSam', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 13, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $558096, 
                           Incomplete = $558118, 
                           Complete = $558118, 
                           PointValue = 15, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_13_CITSAM
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.15_liberator", 
                           Name = 'OmgJck', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 14, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $558097, 
                           Incomplete = $558119, 
                           Complete = $558119, 
                           PointValue = 15, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_14_OMGJCK
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.16_problem_solver", 
                           Name = 'CerJcb', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 15, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $558098, 
                           Incomplete = $558120, 
                           Complete = $558120, 
                           PointValue = 15, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_15_CERJCB
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.17_patriot", 
                           Name = 'End001', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 16, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $558099, 
                           Incomplete = $558121, 
                           Complete = $558121, 
                           PointValue = 25, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_16_END001
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.18_legend", 
                           Name = 'END002', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 17, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $558100, 
                           Incomplete = $558122, 
                           Complete = $558122, 
                           PointValue = 50, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_17_END002
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.19_shopaholic", 
                           Name = 'Store', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 18, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $558079, 
                           Incomplete = $558101, 
                           Complete = $558101, 
                           PointValue = 10, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_18_STORE
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.20_commander", 
                           Name = 'ENDGAMEMAX', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 19, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $558080, 
                           Incomplete = $558102, 
                           Complete = $558102, 
                           PointValue = 50, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_19_ENDGAMEMAX
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.21_lost_and_found", 
                           Name = 'FindSalvage', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 20, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $558081, 
                           Incomplete = $558103, 
                           Complete = $558103, 
                           PointValue = 25, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_20_FINDSALVAGE
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.24_a_personal_touch", 
                           Name = 'WEAPONMOD', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 21, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $582573, 
                           Incomplete = $582588, 
                           Complete = $582588, 
                           PointValue = 10, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_21_WEAPONMOD
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.26_combined_arms", 
                           Name = 'PowerCombo', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 22, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $582575, 
                           Incomplete = $582590, 
                           Complete = $582590, 
                           PointValue = 25, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_22_POWERCOMBO
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.27_focused", 
                           Name = 'MaxPower', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 23, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $582576, 
                           Incomplete = $582591, 
                           Complete = $582591, 
                           PointValue = 25, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_23_MAXPOWER
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.32_untouchable", 
                           Name = 'ESCAPEREAPER', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 24, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $660005, 
                           Incomplete = $660022, 
                           Complete = $660022, 
                           PointValue = 10, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_24_ESCAPEREAPER
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.34_overload_specialist", 
                           Name = 'OVERLOADSHIELDS', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 25, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $582581, 
                           Incomplete = $582596, 
                           Complete = $582596, 
                           PointValue = 15, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_25_OVERLOADSHIELDS
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.35_sky_high", 
                           Name = 'ENEMIESFLYING', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 26, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $582582, 
                           Incomplete = $582597, 
                           Complete = $582597, 
                           PointValue = 15, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_26_ENEMIESFLYING
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.36_pyromaniac", 
                           Name = 'ENEMIESONFIRE', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 27, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $660007, 
                           Incomplete = $660024, 
                           Complete = $660024, 
                           PointValue = 15, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_27_ENEMIESONFIRE
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.37_eye_of_the_hurricaine", 
                           Name = 'BRUTECHARGE', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 28, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $660008, 
                           Incomplete = $660025, 
                           Complete = $660025, 
                           PointValue = 10, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_28_BRUTECHARGE
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.38_peekaboo", 
                           Name = 'GUARDIANMAILSLOT', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 29, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $582583, 
                           Incomplete = $582598, 
                           Complete = $582598, 
                           PointValue = 10, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_29_GUARDIANMAILSLOT
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.39_hijacker", 
                           Name = 'HIJACKATLAS', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 30, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $582584, 
                           Incomplete = $582599, 
                           Complete = $582599, 
                           PointValue = 10, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_30_HIJACKATLAS
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.40_big_game_hunter", 
                           Name = 'HARVESTER', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 31, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $558084, 
                           Incomplete = $558106, 
                           Complete = $558106, 
                           PointValue = 10, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_31_HARVESTER
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.43_always_prepared", 
                           Name = 'PREPARED', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 32, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $660011, 
                           Incomplete = $660028, 
                           Complete = $660028, 
                           PointValue = 5, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_32_PREPARED
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.46_gunsmith", 
                           Name = 'WEAPONMAXED', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 33, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $660014, 
                           Incomplete = $660031, 
                           Complete = $660031, 
                           PointValue = 25, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_33_WEAPONMAXED
                          }, 
                          {
                           Icon = "GUI_LevNotifi.Achievements.55_under_pressure", 
                           Name = 'DLC_LEV3', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 34, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $761056, 
                           Incomplete = $761057, 
                           Complete = $761057, 
                           PointValue = 50, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_34_DLC_LEV3
                          }, 
                          {
                           Icon = "GUI_OMG_Medals.58_Savior", 
                           Name = 'DLC_OMEGA1', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 35, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $766887, 
                           Incomplete = $766888, 
                           Complete = $766888, 
                           PointValue = 25, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_35_DLC_OMEGA1
                          }, 
                          {
                           Icon = "DLC_MPImages.Medals.63_last_resort", 
                           Name = 'DLC_CIT4', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 36, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $813087, 
                           Incomplete = $813088, 
                           Complete = $813088, 
                           PointValue = 50, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_36_DLC_CIT4
                          }, 
                          {
                           Icon = "DLC_MPImages.Medals.68_one_and_only", 
                           Name = 'DLC_CIT9', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 37, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $814351, 
                           Incomplete = $814352, 
                           Complete = $814352, 
                           PointValue = 50, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_37_DLC_CIT9
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.23_insanity", 
                           Name = 'TRILOGY_INSANITYI', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 38, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $817869, 
                           Incomplete = $817880, 
                           Complete = $817880, 
                           PointValue = 50, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_38_TRILOGY_INSANITYI
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.23_insanity", 
                           Name = 'TRILOGY_INSANITYII', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 39, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $817870, 
                           Incomplete = $817881, 
                           Complete = $817881, 
                           PointValue = 75, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_39_TRILOGY_INSANITYII
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.23_insanity", 
                           Name = 'TRILOGY_INSANITYIII', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 40, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $817871, 
                           Incomplete = $817882, 
                           Complete = $817882, 
                           PointValue = 100, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_40_TRILOGY_INSANITYIII
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.25_paramour", 
                           Name = 'TRILOGY_PARAMOURI', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 41, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $817872, 
                           Incomplete = $817883, 
                           Complete = $817883, 
                           PointValue = 10, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_41_TRILOGY_PARAMOURI
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.25_paramour", 
                           Name = 'TRILOGY_PARAMOURII', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 42, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $817873, 
                           Incomplete = $817884, 
                           Complete = $817884, 
                           PointValue = 20, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_42_TRILOGY_PARAMOURII
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.25_paramour", 
                           Name = 'TRILOGY_PARAMOURIII', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 43, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $817874, 
                           Incomplete = $817885, 
                           Complete = $817885, 
                           PointValue = 50, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_43_TRILOGY_PARAMOURIII
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.22_long_service", 
                           Name = 'TRILOGY_LONGSERVICE', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 44, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $817875, 
                           Incomplete = $817886, 
                           Complete = $817886, 
                           PointValue = 125, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_44_TRILOGY_LONGSERVICE
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.28_recruit", 
                           Name = 'TRILOGY_RECRUIT', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 45, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $817876, 
                           Incomplete = $817887, 
                           Complete = $817887, 
                           PointValue = 10, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_45_TRILOGY_RECRUIT
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.29_soldier", 
                           Name = 'TRILOGY_SOLDIER', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 46, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $817877, 
                           Incomplete = $817888, 
                           Complete = $817888, 
                           PointValue = 15, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_46_TRILOGY_SOLDIER
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.30_veteran", 
                           Name = 'TRILOGY_VETERAN', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 47, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $817878, 
                           Incomplete = $817889, 
                           Complete = $817889, 
                           PointValue = 25, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_47_TRILOGY_VETERAN
                          }, 
                          {
                           Icon = "GUI_Achievement_Images.31_bruiser", 
                           Name = 'TRILOGY_BRUISER', 
                           Parent = 'None', 
                           ChallengeGroupName = 'None', 
                           GrinderAccomplishmentName = 'None', 
                           Index = 48, 
                           XboxAchievementID = -1, 
                           XboxAvatarAwardID = -1, 
                           PS3TrophyID = -1, 
                           Title = $817879, 
                           Incomplete = $817890, 
                           Complete = $817890, 
                           PointValue = 10, 
                           NotificationText = $0, 
                           MPNotificationText = $0, 
                           VisibilityStartTime = 0, 
                           VisibilityEndTime = 0, 
                           IsMultiplayerOnly = FALSE, 
                           bRepeatableChallenge = FALSE, 
                           LinkedAchievementID = EAchievementID.ACHIEVEMENT_48_TRILOGY_BRUISER
                          }
                         )
    AccomplishmentProgressData = ({Name = 'SALVAGECOUNT', Index = 1, LinkedProfileSetting = EProfileSetting.Setting_NumSalvageFound}, 
                                  {Name = 'OVERLOADCOUNT', Index = 6, LinkedProfileSetting = EProfileSetting.Setting_NumShieldsOverloaded}, 
                                  {Name = 'FLYINGCOUNT', Index = 7, LinkedProfileSetting = EProfileSetting.Setting_NumEnemiesFlying}, 
                                  {Name = 'ONFIRECOUNT', Index = 8, LinkedProfileSetting = EProfileSetting.Setting_NumEnemiesOnFire}, 
                                  {Name = 'COMBOCOUNT', Index = 9, LinkedProfileSetting = EProfileSetting.Setting_NumPowerCombos}, 
                                  {Name = 'GUARDIANHEADKILLCOUNT', Index = 10, LinkedProfileSetting = EProfileSetting.Setting_NumGuardianHeadKilled}, 
                                  {Name = 'ARMORCOUNT', Index = 19, LinkedProfileSetting = EProfileSetting.Setting_NumArmorBought}, 
                                  {Name = 'WeaponLevel', Index = 20, LinkedProfileSetting = EProfileSetting.Setting_WeaponLevel}, 
                                  {Name = 'POWERLEVEL', Index = 21, LinkedProfileSetting = EProfileSetting.Setting_PowerLevel}
                                 )
    GrinderAccomplishmentData = ({
                                  AccomplishmentName = 'FindSalvage', 
                                  AccomplishmentProgressName = 'SALVAGECOUNT', 
                                  Goal = 10, 
                                  Interval = 1, 
                                  Title = $558081, 
                                  Description = $558103, 
                                  MPDescription = $0
                                 }, 
                                 {
                                  AccomplishmentName = 'OVERLOADSHIELDS', 
                                  AccomplishmentProgressName = 'OVERLOADCOUNT', 
                                  Goal = 100, 
                                  Interval = 10, 
                                  Title = $582581, 
                                  Description = $582596, 
                                  MPDescription = $0
                                 }, 
                                 {
                                  AccomplishmentName = 'ENEMIESFLYING', 
                                  AccomplishmentProgressName = 'FLYINGCOUNT', 
                                  Goal = 100, 
                                  Interval = 10, 
                                  Title = $582582, 
                                  Description = $582597, 
                                  MPDescription = $0
                                 }, 
                                 {
                                  AccomplishmentName = 'ENEMIESONFIRE', 
                                  AccomplishmentProgressName = 'ONFIRECOUNT', 
                                  Goal = 100, 
                                  Interval = 10, 
                                  Title = $660007, 
                                  Description = $660024, 
                                  MPDescription = $0
                                 }, 
                                 {
                                  AccomplishmentName = 'PowerCombo', 
                                  AccomplishmentProgressName = 'COMBOCOUNT', 
                                  Goal = 50, 
                                  Interval = 5, 
                                  Title = $582575, 
                                  Description = $582590, 
                                  MPDescription = $0
                                 }, 
                                 {
                                  AccomplishmentName = 'GUARDIANMAILSLOT', 
                                  AccomplishmentProgressName = 'GUARDIANHEADKILLCOUNT', 
                                  Goal = 10, 
                                  Interval = 1, 
                                  Title = $582583, 
                                  Description = $582598, 
                                  MPDescription = $0
                                 }, 
                                 {
                                  AccomplishmentName = 'PREPARED', 
                                  AccomplishmentProgressName = 'ARMORCOUNT', 
                                  Goal = 2, 
                                  Interval = 1, 
                                  Title = $660011, 
                                  Description = $723154, 
                                  MPDescription = $0
                                 }, 
                                 {
                                  AccomplishmentName = 'WEAPONMAXED', 
                                  AccomplishmentProgressName = 'WeaponLevel', 
                                  Goal = 10, 
                                  Interval = 1, 
                                  Title = $660014, 
                                  Description = $660031, 
                                  MPDescription = $0
                                 }, 
                                 {
                                  AccomplishmentName = 'MaxPower', 
                                  AccomplishmentProgressName = 'POWERLEVEL', 
                                  Goal = 6, 
                                  Interval = 1, 
                                  Title = $582576, 
                                  Description = $582591, 
                                  MPDescription = $0
                                 }
                                )
}