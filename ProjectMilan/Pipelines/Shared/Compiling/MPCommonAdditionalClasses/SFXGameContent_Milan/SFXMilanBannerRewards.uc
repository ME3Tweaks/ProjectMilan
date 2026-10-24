// MILAN CHANGE - Mgamerz - 2026-10-21
// NEW TO MILAN
// A more sensible class for setting banners, because the original is dogwater
// Seriously what linguini
// This system allows you to use tiered banners instead of relying on N7HQ as well
Class SFXMilanBannerRewards extends Object config(Game);

struct BannerUnlockRule
{
    var int EmblemID;
    var int RewardID;
    var int RequiredLevel;
};
var config array<BannerUnlockRule> UnlockRules;

public static final function SFXAccomplishmentManager GetManager()
{
    return SFXEngine(Class'Engine'.static.GetEngine()).AccomplishmentManager;
}
public static final function bool IsDefined(int EmblemID)
{
    return EmblemID > 0 && Class'SFXPRIMP'.default.EmblemList.Find('Id', EmblemID) != -1;
}
public static final function bool IsUnlocked(int EmblemID)
{
    local SFXAccomplishmentManager Manager;
    local BannerUnlockRule Rule;

    if (EmblemID == 0)
    {
        return TRUE;
    }
    Manager = GetManager();
    if (!IsDefined(EmblemID) || Manager == None || Manager.AccomplishmentStorage == None)
    {
        return FALSE;
    }
    if (EmblemID < Manager.AccomplishmentStorage.RewardLevelValues.Length && Manager.AccomplishmentStorage.GetRewardLevel(EmblemID) > 0)
    {
        return TRUE;
    }
    foreach default.UnlockRules(Rule)
    {
        if (Rule.EmblemID == EmblemID && Rule.RewardID > 0 && Rule.RequiredLevel > 0
            && Rule.RewardID < Manager.AccomplishmentStorage.RewardLevelValues.Length
            && Manager.AccomplishmentStorage.GetRewardLevel(Rule.RewardID) >= Rule.RequiredLevel)
        {
            return TRUE;
        }
    }
    return FALSE;
}

public static final function bool GrantBanner(int EmblemID)
{
    local SFXAccomplishmentManager Manager;

    Manager = GetManager();
    if (!IsDefined(EmblemID) || Manager == None || Manager.AccomplishmentStorage == None)
    {
        return FALSE;
    }
    if (IsUnlocked(EmblemID))
    {
        return TRUE;
    }
    if (Manager.AccomplishmentStorage.RewardLevelValues.Length <= EmblemID)
    {
        Manager.AccomplishmentStorage.RewardLevelValues.Length = EmblemID + 1;
    }
    Manager.AccomplishmentStorage.UnlockRewardLevel(EmblemID);
    Manager.Save();
    return IsUnlocked(EmblemID);
}
public static final function bool EquipBanner(PlayerController PC, int EmblemID)
{
    local SFXAccomplishmentManager Manager;
    local SFXPRIMP PRI;
    local int CurrentID;
    local int CurrentLevel;
    local int Promotions;
    local int PreviousID;
    local int ChallengePoints;

    Manager = GetManager();
    if (PC == None || Manager == None || Manager.AccomplishmentStorage == None || !IsUnlocked(EmblemID))
    {
        return FALSE;
    }
    Manager.SetCurrentReward(EmblemID);
    Manager.GetCurrentReward(CurrentID, CurrentLevel);
    if (CurrentID != EmblemID)
    {
        return FALSE;
    }
    Manager.Save();
    PRI = SFXPRIMP(PC.PlayerReplicationInfo);
    if (PRI != None)
    {
        PRI.GetCharacterData_Patch(Promotions, PreviousID, ChallengePoints);
        PRI.SetCharacterData_Patch(Promotions, EmblemID, ChallengePoints);
        PRI.SendCharacterDataToServer(TRUE, FALSE, FALSE);
        PRI.OnCharacterChanged();
    }
    return TRUE;
}

// Tiered unlocks
defaultproperties
{
    UnlockRules = ({EmblemID=207,RewardID=100,RequiredLevel=1},
                   {EmblemID=209,RewardID=128,RequiredLevel=1},
                   {EmblemID=210,RewardID=128,RequiredLevel=1},
                   {EmblemID=211,RewardID=116,RequiredLevel=1},
                   {EmblemID=212,RewardID=116,RequiredLevel=1},
                   {EmblemID=213,RewardID=125,RequiredLevel=1},
                   {EmblemID=214,RewardID=106,RequiredLevel=1},
                   {EmblemID=215,RewardID=127,RequiredLevel=1},
                   {EmblemID=216,RewardID=122,RequiredLevel=1},
                   {EmblemID=217,RewardID=114,RequiredLevel=1},
                   {EmblemID=218,RewardID=117,RequiredLevel=1})
}