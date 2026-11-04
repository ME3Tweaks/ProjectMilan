Class SFXProfileSettings extends OnlineProfileSettings
    native
    config(Game);

struct native BonusPowerUnlockData 
{
    var string PowerClassName;
    var int BonusPowerID;
    var int PlotConditionalID;
    var int PlotStateID;
    var stringref srTitle;
};
// MILAN CHANGE - Stumpy - 2026-10-23
// Add FOV types
struct FovSetting 
{
    var EFovSettings Setting;
    var int bitOffset;
    var int Size;
};
enum EFovSettings
{
    General,
    Zoomed,
};
// MILAN END
enum EProfileSetting
{
    Setting_Unknown,
    Setting_ControllerVibration,
    Setting_YInversion,
    Setting_GamerCred,
    Setting_MilanAccessibility, // CHANGE TO MILAN ACCESSIBILITY
    Setting_VoiceMuted,
    Setting_VoiceThruSpeakers,
    Setting_VoiceVolume,
    Setting_GamerPictureKey,
    Setting_GamerMotto,
    Setting_GamerTitlesPlayed,
    Setting_GamerAchievementsEarned,
    Setting_GameDifficulty,
    Setting_ControllerSensitivity,
    Setting_PreferredColor1,
    Setting_PreferredColor2,
    Setting_AutoAim,
    Setting_AutoCenter,
    Setting_MovementControl,
    Setting_RaceTransmission,
    Setting_RaceCameraLocation,
    Setting_RaceBrakeControl,
    Setting_RaceAcceleratorControl,
    Setting_GameCredEarned,
    Setting_GameAchievementsEarned,
    Setting_EndLiveIds,
    Setting_ProfileVersionNum,
    Setting_ProfileSaveCount,
    Setting_StickConfiguration,
    Setting_TriggerConfiguration,
    Setting_Subtitles,
    Setting_AimAssist,
    Setting_Difficulty,
    Setting_InitialGameDifficulty,
    Setting_AutoLevel,
    Setting_SquadPowers,
    Setting_AutoSave,
    Setting_MusicVolume,
    Setting_FXVolume,
    Setting_DialogVolume,
    Setting_MotionBlur,
    Setting_FilmGrain,
    Setting_SelectedDeviceID,
    Setting_CurrentCareer,
    Setting_DaysSinceRegistration,
    Setting_AutoLogin,
    Setting_LoginInfo,
    Setting_PersonaID,
    Setting_NucleusRefused,
    Setting_NucleusSuccessful,
    Setting_CerberusRefused,
    Setting_Achievement_FieldA,
    Setting_Achievement_FieldB,
    Setting_Achievement_FieldC,
    Setting_TelemetryCollectionEnabled,
    Setting_KeyBindings,
    Setting_DisplayGamma,
    Setting_CurrentSaveGame,
    Setting_HideCinematicHelmet,
    Setting_ActionIconUIHints,
    Setting_AmbientOcclusion,
    Setting_NumGameCompletions,
    Setting_ShowHints,
    Setting_MorinthNotSamara,
    Setting_MaxWeaponUpgradeCount,
    Setting_LastFinishedCareer,
    Setting_SwapTriggersShoulders,
    Setting_PS3_RedeemedProductCode,
    Setting_LastSelectedPawn,
    Setting_ShowScoreIndicators,
    Setting_Accomplishment_FieldA,
    Setting_Accomplishment_FieldB,
    Setting_Accomplishment_FieldC,
    Setting_Accomplishment_FieldD,
    Setting_Accomplishment_FieldE,
    Setting_Accomplishment_FieldF,
    Setting_Accomplishment_FieldG,
    Setting_Accomplishment_FieldH,
    Setting_NumSalvageFound,
    Setting_SPLevel,
    Setting_NumKills,
    Setting_NumMeleeKills,
    Setting_NumShieldsOverloaded,
    Setting_NumEnemiesFlying,
    Setting_NumEnemiesOnFire,
    Setting_CachedDisconnectError,
    Setting_CachedDisconnectFromState,
    Setting_CachedDisconnectToState,
    Setting_CachedDisconnectSessionId,
    Setting_Language_VO,
    Setting_Language_Text,
    Setting_Language_Speech,
    Setting_MPAutoLevel,
    Setting_GalaxyAtWarLevel,
    Setting_N7Rating_LocalUser,
    Setting_N7Rating_FriendBlob,
    Setting_AutoReplyMode,
    Setting_BonusPower,
    Setting_NumGuardianHeadKilled,
    Setting_MPCreateNewMatchPrivacySetting,
    Setting_MPCreateNewMatchMapName,
    Setting_MPCreateNewMatchEnemyType,
    Setting_MPCreateNewMatchDifficulty,
    Setting_HenchmenHelmetOption,
    Setting_AudioDynamicRange,
    Setting_NumPowerCombos,
    Setting_SPMaps,
    Setting_SPMapsCount,
    Setting_NumArmorBought,
    Setting_WeaponLevel,
    Setting_SPMapsInsane,
    Setting_SPMapsInsaneCount,
    Setting_PowerLevel,
    Setting_MPQuickMatchMapName,
    Setting_MPQuickMatchEnemyType,
    Setting_MPQuickMatchDifficulty,
    Setting_KinectTutorialPromptViewed,
    Setting_ChallengePoints_FriendBlob_LastSeen,
    Setting_ChallengePoints_LocalUser_LastSeen,
    Setting_HDREnabled,
    Setting_HDRBrightness,
    Setting_HDRContrast,
    Setting_DynamicResolution,
    Setting_AntiAliasing,
    Setting_DynamicShadows,
};
enum EMappedSettingTypes
{
    MST_Gamma,
    MST_HDRContrast,
    MST_HDRBrightness,
};
enum EOptionOnOff
{
    OOO_On,
    OOO_Off,
};
enum EOptionYesNo
{
    OYN_Yes,
    OYN_No,
};
enum EAudioDynamicRangeOptions
{
    ADR_High,
    ADR_Low,
};
enum EHenchHelmetOptions
{
    HHO_DefaultOff,
    HHO_DefaultOn,
    HHO_ConversationOff,
};
enum EAutoReplyModeOptions
{
    ARMO_All_Decisions,
    ARMO_Major_Decisions,
    ARMO_No_Decisions,
};
enum ETVType
{
    TVT_Default,
    TVT_Soft,
    TVT_Lucent,
    TVT_Vibrant,
};
enum EAutoLevelOptions
{
    ALO_Off,
    ALO_Squad,
    ALO_All,
};
enum EDifficultyOptions
{
    DO_Level1,
    DO_Level2,
    DO_Level3,
    DO_Level4,
    DO_Level5,
    DO_Level6,
};
enum EAimAssistOptions
{
    AAO_Low,
    AAO_Normal,
    AAO_High,
};
enum ETriggerConfigOptions
{
    TCO_Default,
    TCO_SouthPaw,
    TCO_DefaultSwapped,
    TCO_SouthPawSwapped,
};
enum EStickConfigOptions
{
    SCO_Default,
    SCO_SouthPaw,
};
enum EAchievementID
{
    ACHIEVEMENT_00_PROEAR,
    ACHIEVEMENT_01_PROMAR,
    ACHIEVEMENT_02_KROGAR,
    ACHIEVEMENT_03_KRO001,
    ACHIEVEMENT_04_KRO002,
    ACHIEVEMENT_05_KROGRU,
    ACHIEVEMENT_06_GTH001,
    ACHIEVEMENT_07_GTH002,
    ACHIEVEMENT_08_GTHLEG,
    ACHIEVEMENT_09_CAT003,
    ACHIEVEMENT_10_CAT002,
    ACHIEVEMENT_11_CAT004,
    ACHIEVEMENT_12_CERMIR,
    ACHIEVEMENT_13_CITSAM,
    ACHIEVEMENT_14_OMGJCK,
    ACHIEVEMENT_15_CERJCB,
    ACHIEVEMENT_16_END001,
    ACHIEVEMENT_17_END002,
    ACHIEVEMENT_18_STORE,
    ACHIEVEMENT_19_ENDGAMEMAX,
    ACHIEVEMENT_20_FINDSALVAGE,
    ACHIEVEMENT_21_WEAPONMOD,
    ACHIEVEMENT_22_POWERCOMBO,
    ACHIEVEMENT_23_MAXPOWER,
    ACHIEVEMENT_24_ESCAPEREAPER,
    ACHIEVEMENT_25_OVERLOADSHIELDS,
    ACHIEVEMENT_26_ENEMIESFLYING,
    ACHIEVEMENT_27_ENEMIESONFIRE,
    ACHIEVEMENT_28_BRUTECHARGE,
    ACHIEVEMENT_29_GUARDIANMAILSLOT,
    ACHIEVEMENT_30_HIJACKATLAS,
    ACHIEVEMENT_31_HARVESTER,
    ACHIEVEMENT_32_PREPARED,
    ACHIEVEMENT_33_WEAPONMAXED,
    ACHIEVEMENT_34_DLC_LEV3,
    ACHIEVEMENT_35_DLC_OMEGA1,
    ACHIEVEMENT_36_DLC_CIT4,
    ACHIEVEMENT_37_DLC_CIT9,
    ACHIEVEMENT_38_TRILOGY_INSANITYI,
    ACHIEVEMENT_39_TRILOGY_INSANITYII,
    ACHIEVEMENT_40_TRILOGY_INSANITYIII,
    ACHIEVEMENT_41_TRILOGY_PARAMOURI,
    ACHIEVEMENT_42_TRILOGY_PARAMOURII,
    ACHIEVEMENT_43_TRILOGY_PARAMOURIII,
    ACHIEVEMENT_44_TRILOGY_LONGSERVICE,
    ACHIEVEMENT_45_TRILOGY_RECRUIT,
    ACHIEVEMENT_46_TRILOGY_SOLDIER,
    ACHIEVEMENT_47_TRILOGY_VETERAN,
    ACHIEVEMENT_48_TRILOGY_BRUISER,
    ACHIEVEMENT_NONE,
};
const BITS_PER_INT = 32;
// MILAN CHANGE - Stumpy - 2026-10-23
// Add FOV types
var array<FovSetting> FovSettings;
// MILAN END
var config array<BonusPowerUnlockData> BonusPowerUnlockDataArray;

public native function ApplySettings();

public event function bool AreHintsEnabled()
{
    local int Value;
    
    GetProfileSettingValueId(62, Value);
    if (Value == 1)
    {
        return FALSE;
    }
    return TRUE;
}
public event function EAudioDynamicRangeOptions GetAudioDynamicRangeOption()
{
    local int Value;
    
    GetProfileSettingValueId(104, Value);
    return byte(Value);
}
public event function int GetAutoReplyMode()
{
    local int Value;
    
    GetProfileSettingValueId(96, Value);
    return Value;
}
public event function int GetDialogVolume()
{
    local int Value;
    
    GetProfileSettingValueInt(39, Value);
    return Value;
}
public event function EDifficultyOptions GetDifficultyConfigOption()
{
    local int Value;
    
    GetProfileSettingValueId(32, Value);
    return byte(Value);
}
public final native function GetFriendN7RatingBlob(out string userBlob);

public event function int GetFXVolume()
{
    local int Value;
    
    GetProfileSettingValueInt(38, Value);
    return Value;
}
public final native function string GetLanguageSpeech();

public final native function string GetLanguageText();

public final native function string GetLanguageVO();

public event function int GetMusicVolume()
{
    local int Value;
    
    GetProfileSettingValueInt(37, Value);
    return Value;
}
public final native function int GetN7RatingLocalUser();

public event function ETriggerConfigOptions GetTriggerConfigOption()
{
    local ETriggerConfigOptions RetVal;
    local int Value;
    
    GetProfileSettingValueId(29, Value);
    switch (Value)
    {
        case 1:
            RetVal = ETriggerConfigOptions.TCO_SouthPaw;
            break;
        case 2:
            RetVal = ETriggerConfigOptions.TCO_DefaultSwapped;
            break;
        case 3:
            RetVal = ETriggerConfigOptions.TCO_SouthPawSwapped;
            break;
        case 0:
        default:
            RetVal = ETriggerConfigOptions.TCO_Default;
            break;
    }
    return RetVal;
}
public event function bool IsPlotStateIDABonusPowerPlotStateID(int PlotStateID)
{
    local int idx;
    
    for (idx = 0; idx < BonusPowerUnlockDataArray.Length; idx++)
    {
        if (BonusPowerUnlockDataArray[idx].PlotStateID == PlotStateID)
        {
            return TRUE;
        }
    }
    return FALSE;
}
public event function SetAutoReplyMode(int mode)
{
    SetProfileSettingValueId(96, int(byte(mode)));
}
public final native function SetFriendN7RatingBlob(string userBlob);

public final native function SetLanguageSpeech(string Language);

public final native function SetLanguageText(string Language);

public final native function SetLanguageVO(string Language);

public final native function SetN7RatingLocalUser(int n7Rating);

public final native function SetToDefaultsEx(const out array<EProfileSetting> lstProfileSettingsToReset);

public native function ApplyAudioSettings();

public native function ApplyDisplaySettings();

private final function int GetAccomplishmentSettingField(int AccomplishmentIndex)
{
    local int ProfileId;
    
    ProfileId = 70 + AccomplishmentIndex / 32;
    if (ProfileId > 77)
    {
        WarnInternal("GetAccomplishmentSettingField for AccomplishmentIndex" @ AccomplishmentIndex @ "is out of bound; it WILL corrupt the settings!");
    }
    return ProfileId;
}
public final function bool GetActionIconHintOption()
{
    local int Value;
    
    GetProfileSettingValueId(59, Value);
    if (Value == 1)
    {
        return FALSE;
    }
    return TRUE;
}
public function EAimAssistOptions GetAimAssistValue()
{
    local int Value;
    
    GetProfileSettingValueId(31, Value);
    return byte(Value);
}
public function EAutoLevelOptions GetAutoLevelConfigOption()
{
    local int Value;
    
    GetProfileSettingValueId(34, Value);
    return byte(Value);
}
public function bool GetAutoLoginConfigOption()
{
    local int Value;
    
    GetProfileSettingValueId(45, Value);
    if (Value == 1)
    {
        return FALSE;
    }
    return TRUE;
}
public function bool GetAutoSaveConfigOption()
{
    local int Value;
    
    GetProfileSettingValueId(36, Value);
    if (Value == 1)
    {
        return FALSE;
    }
    return TRUE;
}
public function GetBonusPowerArray(out array<BonusPowerUnlockData> OutBonusPowers)
{
    local int idx;
    
    for (idx = 0; idx < BonusPowerUnlockDataArray.Length; idx++)
    {
        OutBonusPowers.AddItem(BonusPowerUnlockDataArray[idx]);
    }
}
public function bool GetChoseMorinthNotSamara()
{
    local int Value;
    
    if (GetProfileSettingValueId(63, Value))
    {
        if (Value == 1)
        {
            return FALSE;
        }
        return TRUE;
    }
    return FALSE;
}
public function EProfileControllerSensitivityOptions GetControllerSensitivityValue()
{
    local EProfileControllerSensitivityOptions RetVal;
    local int Value;
    
    GetProfileSettingValueId(13, Value);
    switch (Value)
    {
        case 1:
            RetVal = EProfileControllerSensitivityOptions.PCSO_Low;
            break;
        case 2:
            RetVal = EProfileControllerSensitivityOptions.PCSO_High;
            break;
        case 0:
        default:
            RetVal = EProfileControllerSensitivityOptions.PCSO_Medium;
            break;
    }
    return RetVal;
}
public function bool GetControllerVibrationOption()
{
    local bool RetVal;
    local int Value;
    
    GetProfileSettingValueId(1, Value);
    switch (Value)
    {
        case 0:
            RetVal = FALSE;
            break;
        case 3:
        default:
            RetVal = TRUE;
            break;
    }
    return RetVal;
}
public function string GetCurrentCareerName()
{
    local string Value;
    
    if (GetProfileSettingValue(43, Value))
    {
        return Value;
    }
    return "";
}
public function int GetCurrentDeviceID()
{
    local int Value;
    
    if (GetProfileSettingValueInt(42, Value))
    {
        return Value;
    }
    return -1;
}
public function float GetDisplayGamma()
{
    local float Value;
    
    GetProfileSettingValueFloat(56, Value);
    return Value;
}
public function bool GetFilmgrainConfigOption()
{
    local int Value;
    
    GetProfileSettingValueId(41, Value);
    if (Value == 1)
    {
        return FALSE;
    }
    return TRUE;
}
public function string GetFinishedGameCareerName()
{
    local string Value;
    
    if (GetProfileSettingValue(65, Value))
    {
        return Value;
    }
    return "";
}
public final native function GetFriendChallengePointBlob(out string userBlob);

public function bool GetHasSeenKinectTutorialPrompt()
{
    local int Value;
    
    if (GetProfileSettingValueInt(116, Value))
    {
        return Value == 0 ? FALSE : TRUE;
    }
    return FALSE;
}
public function EHenchHelmetOptions GetHenchmenHelmetOption()
{
    local int Value;
    
    GetProfileSettingValueId(103, Value);
    return byte(Value);
}
public function bool GetHideCinematicHelmet()
{
    local int Value;
    
    GetProfileSettingValueId(58, Value);
    if (Value == 0)
    {
        return TRUE;
    }
    return FALSE;
}
public function int GetHighestPowerLevel()
{
    local int Value;
    
    if (GetProfileSettingValueInt(112, Value))
    {
        return Value;
    }
    return -1;
}
public function int GetHighestWeaponLevel()
{
    local int Value;
    
    if (GetProfileSettingValueInt(109, Value))
    {
        return Value;
    }
    return -1;
}
public function bool GetInvertYOption()
{
    local bool RetVal;
    local int Value;
    
    GetProfileSettingValueId(2, Value);
    switch (Value)
    {
        case 0:
            RetVal = FALSE;
            break;
        case 1:
        default:
            RetVal = TRUE;
            break;
    }
    return RetVal;
}
public function string GetLastSelectedCharacter()
{
    local string Value;
    
    GetProfileSettingValue(68, Value);
    return Value;
}
public function bool GetMotionBlurConfigOption()
{
    local int Value;
    
    GetProfileSettingValueId(40, Value);
    if (Value == 1)
    {
        return FALSE;
    }
    return TRUE;
}
public function EOptionOnOff GetMPAutoLevelConfigOption()
{
    local int Value;
    
    GetProfileSettingValueId(92, Value);
    return byte(Value);
}
public function int GetNumArmorBought()
{
    local int Value;
    
    if (GetProfileSettingValueInt(108, Value))
    {
        return Value;
    }
    return -1;
}
public function int GetNumEnemiesFlying()
{
    local int Value;
    
    if (GetProfileSettingValueInt(83, Value))
    {
        return Value;
    }
    return -1;
}
public function int GetNumEnemiesOnFire()
{
    local int Value;
    
    if (GetProfileSettingValueInt(84, Value))
    {
        return Value;
    }
    return -1;
}
public function int GetNumGameCompletions()
{
    local int Value;
    
    if (GetProfileSettingValueInt(61, Value))
    {
        return Value;
    }
    return -1;
}
public function int GetNumGuardianHeadKilled()
{
    local int Value;
    
    if (GetProfileSettingValueInt(98, Value))
    {
        return Value;
    }
    return -1;
}
public function int GetNumKills()
{
    local int Value;
    
    if (GetProfileSettingValueInt(80, Value))
    {
        return Value;
    }
    return -1;
}
public function int GetNumMeleeKills()
{
    local int Value;
    
    if (GetProfileSettingValueInt(81, Value))
    {
        return Value;
    }
    return -1;
}
public function int GetNumPowerCombos()
{
    local int Value;
    
    if (GetProfileSettingValueInt(105, Value))
    {
        return Value;
    }
    return -1;
}
public function int GetNumSalvageFound()
{
    local int Value;
    
    if (GetProfileSettingValueInt(78, Value))
    {
        return Value;
    }
    return -1;
}
public function int GetNumShieldsOverloaded()
{
    local int Value;
    
    if (GetProfileSettingValueInt(82, Value))
    {
        return Value;
    }
    return -1;
}
public function int GetNumSPMapsComplete()
{
    local int Value;
    
    if (GetProfileSettingValueInt(107, Value))
    {
        return Value;
    }
    return -1;
}
public function int GetNumSPMapsInsane()
{
    local int Value;
    
    if (GetProfileSettingValueInt(110, Value))
    {
        return Value;
    }
    return -1;
}
public final native function int GetPreviousChallengePointLocalUser();

public function bool GetShowScoreIndicators()
{
    local int Value;
    
    GetProfileSettingValueId(69, Value);
    if (Value == 1)
    {
        return FALSE;
    }
    return TRUE;
}
public function int GetSPLevel()
{
    local int Value;
    
    if (GetProfileSettingValueInt(79, Value))
    {
        return Value;
    }
    return -1;
}
public function bool GetSquadPowerConfigOption()
{
    local int Value;
    
    GetProfileSettingValueId(35, Value);
    if (Value == 1)
    {
        return FALSE;
    }
    return TRUE;
}
public function EStickConfigOptions GetStickConfigOption()
{
    local EStickConfigOptions RetVal;
    local int Value;
    
    GetProfileSettingValueId(28, Value);
    switch (Value)
    {
        case 1:
            RetVal = EStickConfigOptions.SCO_SouthPaw;
            break;
        case 0:
        default:
            RetVal = EStickConfigOptions.SCO_Default;
            break;
    }
    return RetVal;
}
public function bool GetSubtitleConfigOption()
{
    local int Value;
    
    GetProfileSettingValueId(30, Value);
    if (Value == 1)
    {
        return FALSE;
    }
    return TRUE;
}
public function bool GetSwappedCrossCircle()
{
    return Class'BioPlayerInput'.static.IsEnterMenuButtonAssignmentSwapped();
}
public function bool GetSwappedTriggersShoulders()
{
    local int Value;
    
    GetProfileSettingValueId(66, Value);
    if (Value == 1)
    {
        return FALSE;
    }
    return TRUE;
}
public final function bool HasCompletedAccomplishment(int AccomplishmentIndex)
{
    local int ProfileId;
    local int CompletionMask;
    
    ProfileId = GetAccomplishmentSettingField(AccomplishmentIndex);
    if (GetProfileSettingValueInt(ProfileId, CompletionMask))
    {
        return (CompletionMask & 1 << AccomplishmentIndex % 32) != 0;
    }
    return FALSE;
}
public final function bool IsBonusPowerUnlocked(int BonusPowerID)
{
    local int UnlockedPowers;
    
    GetProfileSettingValueInt(97, UnlockedPowers);
    if ((UnlockedPowers & BonusPowerID) == BonusPowerID)
    {
        return TRUE;
    }
    else
    {
        return FALSE;
    }
}
public function bool IsTelemetryCollectionEnabled()
{
    local int Value;
    
    GetProfileSettingValueId(54, Value);
    if (Value == 1)
    {
        return FALSE;
    }
    return TRUE;
}
public final function bool SetAccomplishmentCompleted(int AccomplishmentIndex, BioPlayerController PC, optional bool bSaveProfile = TRUE)
{
    local int ProfileId;
    local int CompletionMask;
    
    if (HasCompletedAccomplishment(AccomplishmentIndex) == FALSE)
    {
        ProfileId = GetAccomplishmentSettingField(AccomplishmentIndex);
        GetProfileSettingValueInt(ProfileId, CompletionMask);
        SetProfileSettingValueInt(ProfileId, CompletionMask | 1 << AccomplishmentIndex % 32);
        if (bSaveProfile)
        {
            PC.SaveProfile(TRUE, FALSE);
        }
        return TRUE;
    }
    return FALSE;
}
public final function bool SetAccomplishmentUncompleted(int AccomplishmentIndex, BioPlayerController PC, optional bool bSaveProfile = TRUE)
{
    local int ProfileId;
    local int CompletionMask;
    
    if (HasCompletedAccomplishment(AccomplishmentIndex) == TRUE)
    {
        ProfileId = GetAccomplishmentSettingField(AccomplishmentIndex);
        GetProfileSettingValueInt(ProfileId, CompletionMask);
        SetProfileSettingValueInt(ProfileId, CompletionMask & ~(1 << AccomplishmentIndex % 32));
        if (bSaveProfile)
        {
            PC.SaveProfile(TRUE, FALSE);
        }
        return TRUE;
    }
    return FALSE;
}
public function SetAutoSaveConfigOption(bool bAutoSave)
{
    local int Value;
    
    Value = bAutoSave ? 0 : 1;
    SetProfileSettingValueId(36, Value);
}
public function SetChoseMorinthNotSamara(bool ChoseMorinth)
{
    local int Value;
    
    if (ChoseMorinth)
    {
        Value = 0;
    }
    else
    {
        Value = 1;
    }
    SetProfileSettingValueId(63, Value);
}
public function SetCurrentCareerName(string CareerName)
{
    local string CurValue;
    
    GetProfileSettingValue(43, CurValue);
    if (CurValue != CareerName)
    {
        SetProfileSettingValue(43, CareerName);
    }
}
public function SetCurrentDeviceID(int DeviceID, BioPlayerController PC)
{
    local int CurValue;
    
    GetProfileSettingValueInt(42, CurValue);
    if (CurValue != DeviceID)
    {
        SetProfileSettingValueInt(42, DeviceID);
        PC.SaveProfile();
    }
}
public function SetDifficultyConfigOption(int Value)
{
    if (Value > -1 && Value < 6)
    {
        SetProfileSettingValueId(32, int(byte(Value)));
    }
}
public final native function SetFriendChallengePointBlob(string userBlob);

public function SetHasSeenKinectTutorialPrompt(bool bHasSeen)
{
    SetProfileSettingValueInt(116, bHasSeen ? 1 : 0);
}
public function SetHenchmenHelmetOption(EHenchHelmetOptions InValue)
{
    SetProfileSettingValueId(103, int(InValue));
}
public function SetHideCinematicHelmet(bool bHideCinematicHelmet)
{
    local int Value;
    
    if (bHideCinematicHelmet)
    {
        Value = 0;
    }
    else
    {
        Value = 1;
    }
    SetProfileSettingValueId(58, Value);
}
public function SetLastSelectedCharacter(string NewValue)
{
    SetProfileSettingValue(68, NewValue);
}
public final native function SetPreviousChallengePointLocalUser(int n7Rating);

public function SetShowHints(bool bEnabled)
{
    local int Value;
    
    if (bEnabled)
    {
        Value = 0;
    }
    else
    {
        Value = 1;
    }
    SetProfileSettingValueId(62, Value);
}
public function SetShowScoreIndicators(bool bShowIndicators)
{
    local int Value;
    
    if (bShowIndicators)
    {
        Value = 0;
    }
    else
    {
        Value = 1;
    }
    SetProfileSettingValueId(69, Value);
}
public function SetTelemetryCollection(bool bEnabled)
{
    local int Value;
    
    if (bEnabled)
    {
        Value = 0;
    }
    else
    {
        Value = 1;
    }
    SetProfileSettingValueId(54, Value);
}
public final function UnlockBonusPower(int BonusPowerID)
{
    local int UnlockedPowers;
    
    GetProfileSettingValueInt(97, UnlockedPowers);
    UnlockedPowers = UnlockedPowers | BonusPowerID;
    SetProfileSettingValueInt(97, UnlockedPowers);
}
public final function UpdateBonusPowerPlotStates()
{
    local int idx;
    local BioWorldInfo WI;
    local BioGlobalVariableTable VarTable;
    
    WI = BioWorldInfo(Class'WorldInfo'.static.GetWorldInfo());
    if (WI == None)
    {
        return;
    }
    VarTable = WI.GetGlobalVariables();
    if (VarTable == None)
    {
        return;
    }
    for (idx = 0; idx < BonusPowerUnlockDataArray.Length; idx++)
    {
        if (IsBonusPowerUnlocked(BonusPowerUnlockDataArray[idx].BonusPowerID) == TRUE)
        {
            VarTable.SetBool(BonusPowerUnlockDataArray[idx].PlotStateID, TRUE, FALSE, TRUE);
            continue;
        }
        VarTable.SetBool(BonusPowerUnlockDataArray[idx].PlotStateID, FALSE, FALSE, TRUE);
    }
}
public final function UpdateBonusPowerProfileSettings()
{
    local int idx;
    local BioWorldInfo WI;
    
    WI = BioWorldInfo(Class'WorldInfo'.static.GetWorldInfo());
    if (WI == None)
    {
        return;
    }
    for (idx = 0; idx < BonusPowerUnlockDataArray.Length; idx++)
    {
        if (WI.CheckConditional(BonusPowerUnlockDataArray[idx].PlotConditionalID) == TRUE)
        {
            UnlockBonusPower(BonusPowerUnlockDataArray[idx].BonusPowerID);
        }
    }
}

// MILAN CHANGE - Mgamerz - 2026-10-26
// Helper method to add missing profile settings on profile read so old profiles are automatically upgraded with values that will return on read
public final function AddMissingDefaultSettings()
{
    local int i;

    for (i = 0; i < DefaultSettings.Length; i++)
    {
        if (FindProfileSettingIndex(DefaultSettings[i].ProfileSetting.PropertyId) == -1)
        {
            ProfileSettings.AddItem(DefaultSettings[i]);
        }
    }
}
// END MILAN CHANGE


// MILAN CHANGE - Stumpy - 2026-10-23
// Add method for getting and setting FOV settings
public function bool GetMilanFOV(out int FOV)
{
    local SFXProfileSettings.FovSetting Item;
    local int ProfileSettingValue;
    local int moveBy;
    
    if (!GetProfileSettingValueInt(3, ProfileSettingValue))
    {
        LogInternal("GETFOV - Setting missing, adding...", );
        AddSettingInt(3);
    }
    LogInternal("GETFOV - Got setting value: " $ ProfileSettingValue, );
    foreach FovSettings(Item, )
    {
        if (Item.Setting == EFovSettings.General)
        {
            moveBy = 32 - Item.bitOffset - Item.Size;
            FOV = ProfileSettingValue << moveBy >>> moveBy + Item.bitOffset;
            // check if value is negative
            if (FOV >>> Item.Size - 1 == 1)
            {
                moveBy = 32 - Item.Size + 1;
                FOV = FOV << moveBy >>> moveBy;
                // Clear the left-most bit
                FOV = ~FOV + 1;
                // Return signed integer
            }
            LogInternal("GETFOV - Got FOV: " $ FOV, );
        }
    }
    return TRUE;
}
public function bool SetMilanFOV(int Value)
{
    local SFXProfileSettings.FovSetting Item;
    local int OriginalProfileSettingValue;
    local int FinalProfileSettingValue;
    local int MilanFOV;
    local int Mask;
    
    LogInternal("SETFOV - Got FOV Value: " $ Value, );
    if (!GetProfileSettingValueInt(3, OriginalProfileSettingValue))
    {
        LogInternal("SETFOV - Setting missing, adding...", );
        AddSettingInt(3);
    }
    foreach FovSettings(Item, )
    {
        if (Item.Setting == EFovSettings.General)
        {
            Mask = (1 << Item.Size) - 1 << Item.bitOffset;
            if (Value < 0)
            {
                LogInternal("Value PRE: " $ Value, );
                // Make sure the sign bit is set and invert the Value
                Value = 1 << Item.Size - 1 | ~Value + 1;
                LogInternal("Value POST: " $ Value, );
            }
            FinalProfileSettingValue = OriginalProfileSettingValue & ~Mask | Value << Item.bitOffset;
            SetProfileSettingValueInt(3, FinalProfileSettingValue);
            LogInternal("SETFOV - Set Profile value: " $ FinalProfileSettingValue, );
            return TRUE;
        }
    }
    return FALSE;
}
public function bool GetMilanZoomFov(out int FOV)
{
    local SFXProfileSettings.FovSetting Item;
    local int ProfileSettingValue;
    local int moveBy;
    
    if (!GetProfileSettingValueInt(3, ProfileSettingValue))
    {
        LogInternal("GETFOVZoom - Setting missing, adding...", );
        AddSettingInt(3);
    }
    LogInternal("GETFOVZoom - Got setting value: " $ ProfileSettingValue, );
    foreach FovSettings(Item, )
    {
        if (Item.Setting == EFovSettings.Zoomed)
        {
            moveBy = 32 - Item.bitOffset - Item.Size;
            FOV = ProfileSettingValue << moveBy >>> moveBy + Item.bitOffset;
            // check if value is negative
            if (FOV >>> Item.Size - 1 == 1)
            {
                moveBy = 32 - Item.Size + 1;
                FOV = FOV << moveBy >>> moveBy;
                // Clear the left-most bit
                FOV = ~FOV + 1;
                // Return signed integer
            }
            LogInternal("GETFOV - Got FOV: " $ FOV, );
        }
    }
    return TRUE;
}
public function bool SetMilanZoomFOV(int Value)
{
    local SFXProfileSettings.FovSetting Item;
    local int OriginalProfileSettingValue;
    local int FinalProfileSettingValue;
    local int MilanFOV;
    local int Mask;
    
    LogInternal("SETFOVZoom - Got FOV Value: " $ Value, );
    if (!GetProfileSettingValueInt(3, OriginalProfileSettingValue))
    {
        LogInternal("SETFOVZoom - Setting missing, adding...", );
        AddSettingInt(3);
    }
    foreach FovSettings(Item, )
    {
        if (Item.Setting == EFovSettings.Zoomed)
        {
            Mask = (1 << Item.Size) - 1 << Item.bitOffset;
            if (Value < 0)
            {
                LogInternal("Value PRE: " $ Value, );
                // Make sure the sign bit is set and invert the Value
                Value = 1 << Item.Size - 1 | ~Value + 1;
                LogInternal("Value POST: " $ Value, );
            }
            FinalProfileSettingValue = OriginalProfileSettingValue & ~Mask | Value << Item.bitOffset;
            SetProfileSettingValueInt(3, FinalProfileSettingValue);
            LogInternal("SETFOVZoom - Set Profile value: " $ FinalProfileSettingValue, );
            return TRUE;
        }
    }
    return FALSE;
}
// MILAN END


// MILAN CHANGE - Stumpy - 2026-10-23
// Default properties cleared and set in relevant part of the pipeline (BaseDelta/SFXGame/DefaultProperties)  
//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{}