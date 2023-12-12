// MILAN CHANGE - 12/12/2013
// By Mgamerz
// Purpose: Patch out call to GetComponentAPI() which is used to determine time but is not loaded by default for LE3.
// This is only used to time gate challenges, which we won't be using.
public final function BuildUIData(out array<ChallengeDisplayItem> aChallenges, int nChallengeIndex, const out array<float> PercentageCompletion, optional SFXAccomplishmentManager AccomplishmentManager)
{
    local ChallengeUIData ReturnData;
    local int nAccomplishmentIndex;
    local int nGrinderIndex;
    local Accomplishment foundAccomplishment;
    local stringref srTitle;
    local stringref srBody;
    local ChallengeDisplayItem challengeItem;
    local int nPercentComplete;
    local int nTimesCompleted;
    local int nTimesParentCompleted;
    local string sParsedBody;
    local string sParsedTimesCompleted;
    local string sParsedChallengePoints;
    local int nCurrentTime;
    local int idx;
    local bool bEntitlementFound;
    local bool bCompleteChallengeIcon;
    local bool bChallengeIsRepeatable;
    
    challengeItem = aChallenges[nChallengeIndex];
    if (AccomplishmentManager == None)
    {
        AccomplishmentManager = SFXEngine(Class'Engine'.static.GetEngine()).AccomplishmentManager;
    }
    nAccomplishmentIndex = AccomplishmentManager.AccomplishmentData.Find('Index', challengeItem.AccomplishmentIndex);
    if (nAccomplishmentIndex == -1)
    {
        return;
    }
    // MILAN CHANGE - Remove current time check----
    //nCurrentTime = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentAPI().GetCurrentTime();
    //if (challengeItem.VisibilityStartTime > 0 && challengeItem.VisibilityStartTime > nCurrentTime || challengeItem.VisibilityEndTime > 0 && challengeItem.VisibilityEndTime < nCurrentTime)
    //{
    //    return;
    //}
    nCurrentTime = -1;
    // END MILAN CHANGE-----------------------------
    if (challengeItem.VisibilityEntitlement != 0)
    {
        for (idx = 0; idx < Entitlements.Length; idx++)
        {
            if (Entitlements[idx].Id.nID == challengeItem.VisibilityEntitlement)
            {
                bEntitlementFound = TRUE;
            }
        }
        if (challengeItem.VisibilityEntitlement > 0 && !bEntitlementFound || challengeItem.VisibilityEntitlement < 0 && bEntitlementFound)
        {
            return;
        }
    }
    foundAccomplishment = AccomplishmentManager.AccomplishmentData[nAccomplishmentIndex];
    if (challengeItem.Parent != -1)
    {
        nTimesParentCompleted = AccomplishmentManager.AccomplishmentIsComplete[challengeItem.Parent];
    }
    else
    {
        nTimesParentCompleted = 0;
    }
    nTimesCompleted = AccomplishmentManager.AccomplishmentIsComplete[foundAccomplishment.Index];
    ReturnData.NumCompletions = nTimesCompleted;
    nGrinderIndex = AccomplishmentManager.GrinderAccomplishmentData.Find('AccomplishmentName', foundAccomplishment.Name);
    if (nGrinderIndex != -1)
    {
        ReturnData.CurrentValue = AccomplishmentManager.GetGrinderAccomplishmentProgress(AccomplishmentManager.GrinderAccomplishmentData[nGrinderIndex].AccomplishmentProgressName, BioPlayerController(GetPC()));
        ReturnData.GoalValue = AccomplishmentManager.GrinderAccomplishmentData[nGrinderIndex].Goal;
        ReturnData.CurrentValue = Min(ReturnData.CurrentValue, ReturnData.GoalValue);
        if (PercentageCompletion[nChallengeIndex] > float(0))
        {
            nPercentComplete = Max(FFloor(PercentageCompletion[nChallengeIndex] * float(100)), 1);
        }
        else
        {
            nPercentComplete = 0;
        }
    }
    bChallengeIsRepeatable = IsAccomplishmentRepeatable(nAccomplishmentIndex);
    if (bChallengeIsRepeatable)
    {
        bCompleteChallengeIcon = nPercentComplete == 100 || nTimesCompleted > nTimesParentCompleted;
    }
    else
    {
        bCompleteChallengeIcon = nPercentComplete == 100;
    }
    if (challengeItem.Parent == -1)
    {
        ReturnData.Rank = MPChallengeRank.MPChallengeRank_Gold;
        ReturnData.Icon = bCompleteChallengeIcon ? MPChallengeRankIcon.MPChallengeRankIcon_Gold_Complete : MPChallengeRankIcon.MPChallengeRankIcon_Gold;
    }
    else if (aChallenges[aChallenges.Find('AccomplishmentIndex', challengeItem.Parent)].Parent == -1)
    {
        ReturnData.Rank = MPChallengeRank.MPChallengeRank_Silver;
        ReturnData.Icon = bCompleteChallengeIcon ? MPChallengeRankIcon.MPChallengeRankIcon_Silver_Complete : MPChallengeRankIcon.MPChallengeRankIcon_Silver;
    }
    else
    {
        ReturnData.Rank = MPChallengeRank.MPChallengeRank_Bronze;
        ReturnData.Icon = bCompleteChallengeIcon ? MPChallengeRankIcon.MPChallengeRankIcon_Bronze_Complete : MPChallengeRankIcon.MPChallengeRankIcon_Bronze;
    }
    srTitle = foundAccomplishment.Title;
    if (challengeItem.TitleOverride != 0)
    {
        srTitle = challengeItem.TitleOverride;
    }
    ReturnData.Title = UIStrRef(srTitle);
    SetCustomToken(0, UIStrRef(srTitle));
    SetCustomToken(1, string(nPercentComplete));
    ReturnData.DisplayTitle = GetUIString(TitleTemplateString, TRUE);
    ClearCustomTokens();
    srBody = challengeItem.BodyOverride;
    if (srBody == 0)
    {
        if (ReturnData.CurrentValue == ReturnData.GoalValue)
        {
            srBody = foundAccomplishment.Complete;
        }
        else
        {
            srBody = foundAccomplishment.Incomplete;
        }
        if (srBody == 0)
        {
            srBody = foundAccomplishment.MPNotificationText;
            if (srBody == 0)
            {
                srBody = foundAccomplishment.NotificationText;
            }
        }
    }
    SetCustomToken(0, string(ReturnData.GoalValue));
    sParsedBody = GetUIString(srBody, TRUE);
    ClearCustomTokens();
    if (foundAccomplishment.PointValue > 0)
    {
        SetCustomToken(0, string(foundAccomplishment.PointValue));
        sParsedChallengePoints = GetUIString(ChallengePointsString, TRUE);
        ClearCustomTokens();
    }
    if (bChallengeIsRepeatable && nTimesCompleted >= 1)
    {
        SetCustomToken(0, string(nTimesCompleted));
        sParsedTimesCompleted = GetUIString(TimesCompletedString, TRUE);
        ClearCustomTokens();
    }
    SetCustomToken(0, string(ReturnData.CurrentValue));
    SetCustomToken(1, string(ReturnData.GoalValue));
    SetCustomToken(2, sParsedBody);
    SetCustomToken(3, sParsedChallengePoints);
    SetCustomToken(4, sParsedTimesCompleted);
    ReturnData.DisplayBody = GetUIString(BodyTemplateString, TRUE);
    ClearCustomTokens();
    ReturnData.Image = challengeItem.ImageOverride;
    if (ReturnData.Image == "")
    {
        ReturnData.Image = foundAccomplishment.Icon;
    }
    aChallenges[nChallengeIndex].UIData = ReturnData;
}