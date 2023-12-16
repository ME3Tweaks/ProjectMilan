Class SFXGUI_MPChallenges extends SFXGUIMovie
    config(UI);

// Types
struct ChallengeDisplayItem 
{
    var transient ChallengeUIData UIData;
    var string ImageOverride;
    var int AccomplishmentIndex;
    var stringref TitleOverride;
    var stringref BodyOverride;
    var int Parent;
    var int VisibilityStartTime;
    var int VisibilityEndTime;
    var int VisibilityEntitlement;
    var transient int ParentItemIndex;
    
    structdefaultproperties
    {
        AccomplishmentIndex = -1
        Parent = -1
    }
};
struct ChallengeUIData 
{
    var string Title;
    var string DisplayTitle;
    var string DisplayBody;
    var string Image;
    var int CurrentValue;
    var int GoalValue;
    var int NumCompletions;
    var MPChallengeRankIcon Icon;
    var MPChallengeRank Rank;
};
struct ChallengeListItem 
{
    var string sName;
    var int nIndex;
    var int nID;
    var MPChallengeRankIcon eIcon;
};
enum MPChallengeRankIcon
{
    MPChallengeRankIcon_Bronze,
    MPChallengeRankIcon_Bronze_Complete,
    MPChallengeRankIcon_Silver,
    MPChallengeRankIcon_Silver_Complete,
    MPChallengeRankIcon_Gold,
    MPChallengeRankIcon_Gold_Complete,
};
enum MPChallengeRank
{
    MPChallengeRank_Unknown,
    MPChallengeRank_Gold,
    MPChallengeRank_Silver,
    MPChallengeRank_Bronze,
};
enum MPChallengeCategory
{
    MPChallengeCat_NONE,
    MPChallengeCat_General,
    MPChallengeCat_Aliens,
    MPChallengeCat_Weapons,
};

// Variables
var transient array<int> m_aCurrentAccomplishmentIndices;
var transient array<bool> m_bAccomplishmentDataRepeatable;
var transient array<BWEntitlementInfo> Entitlements;
var transient string m_sCurrentDetailBody;
var transient string m_sCurrentDetailImageResource;
var config array<ChallengeDisplayItem> GeneralChallenges;
var config array<ChallengeDisplayItem> AlienChallenges;
var config array<ChallengeDisplayItem> WeaponChallenges;
var delegate<ChallengeSort_Rank_Index> __ChallengeSort_Rank_Index__Delegate;
var delegate<ChallengeSort_Parent> __ChallengeSort_Parent__Delegate;
var transient int m_nCurrentChallengeIndex;
var transient int m_nDefaultChallengeId;
var config stringref TitleText;
var config stringref ExitText;
var config stringref BackText;
var config stringref CloseSubListText;
var config stringref Tab1Text;
var config stringref Tab2Text;
var config stringref Tab3Text;
var config stringref ViewText;
var config stringref ContinueText;
var config stringref MarkAllViewedText;
var config stringref TitleTemplateString;
var config stringref BodyTemplateString;
var config stringref TimesCompletedString;
var config stringref ChallengePointsString;
var config stringref SetTitleConfirmString;
var transient bool m_bInitialized;
var transient bool m_bIsRewardButtonEnabled;
var transient MPChallengeCategory m_eStartupTab;
var transient MPChallengeCategory m_eCurrentTab;

// Functions
// MILAN CHANGE DropTheSquid 12/15/223
// this is needed to dynamically switch between mouse/controller UIs
public event function HandleButtonRefresh(bool usingGamepad)
{
    Super.HandleButtonRefresh(usingGamepad);
    ActionScriptVoid("mcGUI.RefreshButtonHelp");
}
// END MILAN
public final event function AS_AddListItems(array<ChallengeListItem> aItems)
{
    ActionScriptVoid("mcGUI.AddListItems");
}
public final event function AS_EndDisplayList(int nLastEntryID)
{
    ActionScriptVoid("mcGUI.EndDisplayList");
}
public final event function AS_ScrollDetailsAnalog(float fScroll)
{
    ActionScriptVoid("mcGUI.scrollDetailsAnalog");
}
public final event function AS_SetDetails(string sInfo, string sImgResource)
{
    ActionScriptVoid("mcGUI.SetDetails");
}
public final event function AS_SetSubItems(array<ChallengeListItem> aSubItems)
{
    ActionScriptVoid("mcGUI.SetSubItems");
}
public final event function AS_SetUnreadItemCounts(int nQuestPrimary, int nQuestSecondary, int nCodexPrimary, int nCodexSecondary)
{
    ActionScriptVoid("mcGUI.SetUnreadItemCounts");
}
public final event function AS_SetupVisualState(int nForceTab)
{
    ActionScriptVoid("mcGUI.setupVisualState");
}
public final event function AS_StartDisplayList(const string sLabel, const string sTitle, int nListLen)
{
    ActionScriptVoid("mcGUI.StartDisplayList");
}
public final function ExExpandEntry()
{
    switch (m_eCurrentTab)
    {
        case MPChallengeCategory.MPChallengeCat_General:
            ExpandListEntry(GeneralChallenges);
            break;
        case MPChallengeCategory.MPChallengeCat_Aliens:
            ExpandListEntry(AlienChallenges);
            break;
        case MPChallengeCategory.MPChallengeCat_Weapons:
            ExpandListEntry(WeaponChallenges);
            break;
        default:
    }
}
public final function ExFocusOnSubentry(int nChallengeIndex)
{
    switch (m_eCurrentTab)
    {
        case MPChallengeCategory.MPChallengeCat_General:
            FocusOnSubentry(GeneralChallenges, nChallengeIndex);
            break;
        case MPChallengeCategory.MPChallengeCat_Aliens:
            FocusOnSubentry(AlienChallenges, nChallengeIndex);
            break;
        case MPChallengeCategory.MPChallengeCat_Weapons:
            FocusOnSubentry(WeaponChallenges, nChallengeIndex);
            break;
        default:
    }
    SetRewardButtonVisibility(FALSE);
}
public final function ExFocusOnTab(int nTab)
{
    m_eCurrentTab = byte(nTab);
    switch (nTab)
    {
        case 1:
            DisplayCategoryChallenges(GeneralChallenges, m_nDefaultChallengeId);
            break;
        case 2:
            DisplayCategoryChallenges(AlienChallenges, m_nDefaultChallengeId);
            break;
        case 3:
            DisplayCategoryChallenges(WeaponChallenges, m_nDefaultChallengeId);
            break;
        default:
    }
}
public final function ExInitializeJournal()
{
    CheckInitializeData();
    AS_SetupVisualState(int(m_eStartupTab));
    AS_SetUnreadItemCounts(0, 0, 0, 0);
}
public final function ExSetLastEntry(int nListIndex)
{
    local ChallengeUIData Data;
    
    m_nCurrentChallengeIndex = m_aCurrentAccomplishmentIndices[nListIndex];
    switch (m_eCurrentTab)
    {
        case MPChallengeCategory.MPChallengeCat_General:
            Data = GeneralChallenges[m_nCurrentChallengeIndex].UIData;
            break;
        case MPChallengeCategory.MPChallengeCat_Aliens:
            Data = AlienChallenges[m_nCurrentChallengeIndex].UIData;
            break;
        case MPChallengeCategory.MPChallengeCat_Weapons:
            Data = WeaponChallenges[m_nCurrentChallengeIndex].UIData;
            break;
        default:
    }
    SetDetails(Data.DisplayBody, Data.Image);
    SetRewardButtonVisibility(Data.GoalValue > 0);
    SetRewardButtonEnabled(Data.NumCompletions > 0);
}
public event function bool HandleInputEvent(BioGuiEvents Event, optional float fValue = 1.0)
{
    switch (Event)
    {
        case BioGuiEvents.BIOGUI_EVENT_AXIS_RSTICK_Y:
            AS_ScrollDetailsAnalog(fValue);
            break;
        default:
            return Super.HandleInputEvent(Event, fValue);
    }
    return TRUE;
}
public event function OnStart()
{
    Super.OnStart();
    SetupFunctionIntercepts();
    ConstructEnumObjects();
}
public event function OnClose()
{
    m_bInitialized = FALSE;
    ResetStartupOverrides();
    Super.OnClose();
}
public final function CheckInitializeData()
{
    local bool bFoundStartupEntry;
    local SFXAccomplishmentManager AccomplishmentManager;
    
    if (m_bInitialized)
    {
        return;
    }
    Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentCommerce().GetEntitlementsList(Entitlements);
    m_eStartupTab = MPChallengeCategory.MPChallengeCat_General;
    AccomplishmentManager = SFXEngine(Class'Engine'.static.GetEngine()).AccomplishmentManager;
    InitializeChallengeArray(GeneralChallenges, AccomplishmentManager);
    if (GeneralChallenges.Find('AccomplishmentIndex', m_nDefaultChallengeId) != -1)
    {
        m_eStartupTab = MPChallengeCategory.MPChallengeCat_General;
        bFoundStartupEntry = TRUE;
    }
    InitializeChallengeArray(AlienChallenges, AccomplishmentManager);
    if (!bFoundStartupEntry && AlienChallenges.Find('AccomplishmentIndex', m_nDefaultChallengeId) != -1)
    {
        m_eStartupTab = MPChallengeCategory.MPChallengeCat_Aliens;
        bFoundStartupEntry = TRUE;
    }
    InitializeChallengeArray(WeaponChallenges, AccomplishmentManager);
    if (!bFoundStartupEntry && WeaponChallenges.Find('AccomplishmentIndex', m_nDefaultChallengeId) != -1)
    {
        m_eStartupTab = MPChallengeCategory.MPChallengeCat_Weapons;
        bFoundStartupEntry = TRUE;
    }
    if (!bFoundStartupEntry)
    {
        m_nDefaultChallengeId = -1;
    }
    m_bInitialized = TRUE;
}
public final function ResetStartupOverrides()
{
    m_eStartupTab = MPChallengeCategory.MPChallengeCat_General;
    m_nDefaultChallengeId = -1;
}
public function ReturnToBrowser()
{
    Close();
}
public final function BuildPercentCompletion(out array<float> PercentCompletion, out array<ChallengeDisplayItem> aChallenges, SFXAccomplishmentManager AccomplishmentManager)
{
    local int idx;
    
    aChallenges.Sort(ChallengeSort_Parent);
    PercentCompletion.Length = aChallenges.Length;
    for (idx = 0; idx < aChallenges.Length && aChallenges[idx].Parent == -1; idx++)
    {
        BuildPercentCompletion_Helper(PercentCompletion, aChallenges, idx, AccomplishmentManager);
    }
}
private final function BuildPercentCompletion_Helper(out array<float> PercentCompletion, const out array<ChallengeDisplayItem> aChallenges, int nCurrentChallengeIndex, SFXAccomplishmentManager AccomplishmentManager)
{
    local float ChildrenPercentSum;
    local float CurrentChildrenPercent;
    local float MinChildrenPercent;
    local array<float> ChildrenPercentages;
    local int nChallengeIdx;
    local int CurrentValue;
    local int GoalValue;
    local int nCurrentAccomplishmentIndex;
    local int nAccomplishmentDataIndex;
    local int nGrinderIndex;
    local int nParentAccomplishmentIndex;
    local int nParentAccomplishmentDataIndex;
    local int nChildrenPercentagesIdx;
    local int nMinChildrenPercentIdx;
    local bool bParentIsRepeatable;
    local int nNumCompletions;
    local ChallengeDisplayItem CurrentChallenge;
    
    CurrentChallenge = aChallenges[nCurrentChallengeIndex];
    nCurrentAccomplishmentIndex = CurrentChallenge.AccomplishmentIndex;
    nParentAccomplishmentIndex = CurrentChallenge.Parent;
    nChallengeIdx = aChallenges.Find('Parent', nCurrentAccomplishmentIndex);
    nAccomplishmentDataIndex = AccomplishmentManager.AccomplishmentData.Find('Index', nCurrentAccomplishmentIndex);
    if (nAccomplishmentDataIndex == -1)
    {
        PercentCompletion[nCurrentChallengeIndex] = 0.0;
        return;
    }
    nParentAccomplishmentDataIndex = AccomplishmentManager.AccomplishmentData.Find('Index', nParentAccomplishmentIndex);
    if (nParentAccomplishmentDataIndex != -1)
    {
        bParentIsRepeatable = IsAccomplishmentRepeatable(nParentAccomplishmentDataIndex);
    }
    nGrinderIndex = AccomplishmentManager.GrinderAccomplishmentData.Find('AccomplishmentName', AccomplishmentManager.AccomplishmentData[nAccomplishmentDataIndex].Name);
    GoalValue = AccomplishmentManager.GrinderAccomplishmentData[nGrinderIndex].Goal;
    nNumCompletions = AccomplishmentManager.AccomplishmentIsComplete[nCurrentAccomplishmentIndex];
    if (nChallengeIdx != -1)
    {
        for (nChallengeIdx = nChallengeIdx; nChallengeIdx < aChallenges.Length && aChallenges[nChallengeIdx].Parent == nCurrentAccomplishmentIndex; nChallengeIdx++)
        {
            BuildPercentCompletion_Helper(PercentCompletion, aChallenges, nChallengeIdx, AccomplishmentManager);
            CurrentChildrenPercent = PercentCompletion[nChallengeIdx];
            ChildrenPercentSum += CurrentChildrenPercent;
            if (ChildrenPercentages.Length <= GoalValue)
            {
                ChildrenPercentages.AddItem(CurrentChildrenPercent);
            }
            if (ChildrenPercentages.Length > GoalValue)
            {
                MinChildrenPercent = 1.0;
                nMinChildrenPercentIdx = -1;
                for (nChildrenPercentagesIdx = 0; nChildrenPercentagesIdx < ChildrenPercentages.Length; nChildrenPercentagesIdx++)
                {
                    if (ChildrenPercentages[nChildrenPercentagesIdx] < MinChildrenPercent)
                    {
                        MinChildrenPercent = ChildrenPercentages[nChildrenPercentagesIdx];
                        nMinChildrenPercentIdx = nChildrenPercentagesIdx;
                    }
                }
                if (nMinChildrenPercentIdx != -1)
                {
                    ChildrenPercentages[nMinChildrenPercentIdx] = ChildrenPercentages[ChildrenPercentages.Length - 1];
                    ChildrenPercentages.Length = ChildrenPercentages.Length - 1;
                    ChildrenPercentSum -= MinChildrenPercent;
                }
            }
        }
    }
    if ((nParentAccomplishmentIndex != -1 && nParentAccomplishmentDataIndex != -1) && (bParentIsRepeatable && nNumCompletions > AccomplishmentManager.AccomplishmentIsComplete[nParentAccomplishmentIndex] || !bParentIsRepeatable && nNumCompletions > 0))
    {
        PercentCompletion[nCurrentChallengeIndex] = 1.0;
    }
    else if (ChildrenPercentages.Length > 0)
    {
        PercentCompletion[nCurrentChallengeIndex] = ChildrenPercentSum / float(GoalValue);
    }
    else if (nGrinderIndex == -1)
    {
        PercentCompletion[nCurrentChallengeIndex] = 0.0;
    }
    else
    {
        CurrentValue = AccomplishmentManager.GetGrinderAccomplishmentProgress(AccomplishmentManager.GrinderAccomplishmentData[nGrinderIndex].AccomplishmentProgressName, BioPlayerController(GetPC()));
        PercentCompletion[nCurrentChallengeIndex] = FClamp(float(CurrentValue) / float(GoalValue), 0.0, 1.0);
    }
}
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
    nCurrentTime = -1;
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
public final delegate function int ChallengeSort_Parent(ChallengeDisplayItem A, ChallengeDisplayItem B)
{
    return B.Parent - A.Parent;
}
public final delegate function int ChallengeSort_Rank_Index(ChallengeDisplayItem A, ChallengeDisplayItem B)
{
    if (int(A.UIData.Rank) != int(B.UIData.Rank))
    {
        return int(B.UIData.Rank) - int(A.UIData.Rank);
    }
    return B.AccomplishmentIndex - A.AccomplishmentIndex;
}
public final function ConstructEnumObjects()
{
    local GFxValue EnumObject;
    local int tempValue;
    
    EnumObject = CreateObject("Object");
    tempValue = 0;
    EnumObject.SetNumber("Bronze", float(tempValue));
    tempValue = 1;
    EnumObject.SetNumber("Bronze_Complete", float(tempValue));
    tempValue = 2;
    EnumObject.SetNumber("Silver", float(tempValue));
    tempValue = 3;
    EnumObject.SetNumber("Silver_Complete", float(tempValue));
    tempValue = 4;
    EnumObject.SetNumber("Gold", float(tempValue));
    tempValue = 5;
    EnumObject.SetNumber("Gold_Complete", float(tempValue));
    SetVariableObject("_root.MPChallengeRankIcon", EnumObject);
}
public final function DisplayCategoryChallenges(const array<ChallengeDisplayItem> aChallenges, optional int nSelectChallengeId = -1)
{
    local array<ChallengeListItem> aListItems;
    local ChallengeListItem NewItem;
    local int nIndex;
    local int displayId;
    
    m_aCurrentAccomplishmentIndices.Length = 0;
    displayId = 0;
    for (nIndex = 0; nIndex < aChallenges.Length; ++nIndex)
    {
        if (aChallenges[nIndex].UIData.Rank != MPChallengeRank.MPChallengeRank_Gold)
        {
            continue;
        }
        m_aCurrentAccomplishmentIndices.AddItem(nIndex);
        NewItem.nIndex = aListItems.Length;
        NewItem.nID = nIndex;
        if (NewItem.nID == nSelectChallengeId)
        {
            displayId = nSelectChallengeId;
        }
        NewItem.sName = aChallenges[nIndex].UIData.DisplayTitle;
        NewItem.eIcon = aChallenges[nIndex].UIData.Icon;
        aListItems.AddItem(NewItem);
    }
    if (displayId == 0)
    {
        displayId = aListItems[0].nID;
    }
    AS_StartDisplayList("", "", aListItems.Length);
    AS_AddListItems(aListItems);
    AS_EndDisplayList(displayId);
}
public final function DoNothingFunction();

public final function ExpandListEntry(const array<ChallengeDisplayItem> aChallenges)
{
    local int N;
    local int nAccomplishment;
    local array<int> aSilverEntries;
    local array<ChallengeListItem> aListItems;
    local ChallengeListItem NewItem;
    
    if (m_nCurrentChallengeIndex < 0 || m_nCurrentChallengeIndex >= aChallenges.Length)
    {
        return;
    }
    for (N = 0; N < aChallenges.Length; ++N)
    {
        nAccomplishment = aChallenges[m_nCurrentChallengeIndex].AccomplishmentIndex;
        if (aChallenges[N].Parent == nAccomplishment)
        {
            aSilverEntries.AddItem(N);
            NewItem.nIndex = aListItems.Length;
            NewItem.nID = N;
            NewItem.sName = aChallenges[N].UIData.DisplayTitle;
            NewItem.eIcon = aChallenges[N].UIData.Icon;
            aListItems.AddItem(NewItem);
        }
    }
    for (N = 0; N < aChallenges.Length; ++N)
    {
        if (aChallenges[N].UIData.Rank == MPChallengeRank.MPChallengeRank_Bronze && aSilverEntries.Find(aChallenges[N].ParentItemIndex) != -1)
        {
            NewItem.nIndex = aListItems.Length;
            NewItem.nID = N;
            NewItem.sName = aChallenges[N].UIData.DisplayTitle;
            NewItem.eIcon = aChallenges[N].UIData.Icon;
            aListItems.AddItem(NewItem);
        }
    }
    AS_SetSubItems(aListItems);
}
public final function FocusOnSubentry(const array<ChallengeDisplayItem> aChallenges, int nIndex)
{
    if (nIndex < 0 || nIndex >= aChallenges.Length)
    {
        return;
    }
    SetDetails(aChallenges[nIndex].UIData.DisplayBody, aChallenges[nIndex].UIData.Image);
}
public final function HandleRewardSelection()
{
    local SFXAccomplishmentManager AccomplishmentManager;
    local int nAccomplishmentIndex;
    local int nArrayIndex;
    local Name nmAccomplishmentName;
    local int nRewardIndex;
    local BioMessageBoxOptionalParams stParams;
    
    if (m_bIsRewardButtonEnabled)
    {
        AccomplishmentManager = SFXEngine(Class'Engine'.static.GetEngine()).AccomplishmentManager;
        if (AccomplishmentManager == None)
        {
            return;
        }
        switch (m_eCurrentTab)
        {
            case MPChallengeCategory.MPChallengeCat_General:
                nAccomplishmentIndex = GeneralChallenges[m_nCurrentChallengeIndex].AccomplishmentIndex;
                break;
            case MPChallengeCategory.MPChallengeCat_Aliens:
                nAccomplishmentIndex = AlienChallenges[m_nCurrentChallengeIndex].AccomplishmentIndex;
                break;
            case MPChallengeCategory.MPChallengeCat_Weapons:
                nAccomplishmentIndex = WeaponChallenges[m_nCurrentChallengeIndex].AccomplishmentIndex;
                break;
            default:
        }
        nArrayIndex = AccomplishmentManager.AccomplishmentData.Find('Index', nAccomplishmentIndex);
        if (nArrayIndex != -1)
        {
            nmAccomplishmentName = AccomplishmentManager.AccomplishmentData[nArrayIndex].Name;
            nRewardIndex = AccomplishmentManager.Rewards.Find('AccomplishmentName', nmAccomplishmentName);
            if (nRewardIndex != -1)
            {
                GetPC().ConsoleCommand("SetCurrentChallengeReward " $ nRewardIndex);
                stParams.srAText = Class'SFXGUI_MainMenu_RTT'.default.srOK;
                GetSFXUIController().QueueNamedMessageBox('RewardSelectConfirm', 3, SetTitleConfirmString, stParams, None, , GetPC());
            }
        }
    }
    else
    {
        PlayGuiSound('GuiError');
    }
}
public final function InitializeChallengeArray(out array<ChallengeDisplayItem> aChallenges, SFXAccomplishmentManager AccomplishmentManager)
{
    local int nIndex;
    local array<float> PercentCompletion;
    
    BuildPercentCompletion(PercentCompletion, aChallenges, AccomplishmentManager);
    for (nIndex = 0; nIndex < aChallenges.Length; ++nIndex)
    {
        BuildUIData(aChallenges, nIndex, PercentCompletion, AccomplishmentManager);
    }
    aChallenges.Sort(ChallengeSort_Rank_Index);
    for (nIndex = 0; nIndex < aChallenges.Length; ++nIndex)
    {
        aChallenges[nIndex].ParentItemIndex = aChallenges.Find('AccomplishmentIndex', aChallenges[nIndex].Parent);
    }
}
public final function bool IsAccomplishmentRepeatable(int AccomplishmentDataIndex)
{
    if (AccomplishmentDataIndex < m_bAccomplishmentDataRepeatable.Length && AccomplishmentDataIndex >= 0)
    {
        return m_bAccomplishmentDataRepeatable[AccomplishmentDataIndex];
    }
    return FALSE;
}
private final function OnRequestImageComplete(SFXOnlineImageRequest ImageRequestResult)
{
    if (ImageRequestResult.mDynamicImage != None && m_sCurrentDetailImageResource == ImageRequestResult.mImageName)
    {
        SetDetails(m_sCurrentDetailBody, m_sCurrentDetailImageResource, PathName(ImageRequestResult.mDynamicImage));
    }
}
public final function SetAccomplishmentRepeatable(array<bool> NewAccomplishmentDataRepeatable)
{
    m_bAccomplishmentDataRepeatable = NewAccomplishmentDataRepeatable;
}
public final function SetDetails(string sBody, string sImageResourceString, optional string sImageAssetPath = "")
{
    m_sCurrentDetailBody = sBody;
    m_sCurrentDetailImageResource = sImageResourceString;
    if (sImageAssetPath == "" && !Class'SFXEngine'.static.IsSeekFreeObjectSupported(sImageResourceString))
    {
        Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentImageManager().RequestImage(sImageResourceString, OnRequestImageComplete);
        AS_SetDetails(sBody, "");
        return;
    }
    else if (sImageAssetPath != "")
    {
        sImageResourceString = sImageAssetPath;
    }
    AS_SetDetails(sBody, sImageResourceString);
}
public function SetRewardButtonEnabled(bool bEnabled)
{
    local GFxValue buttonObject;
    
    m_bIsRewardButtonEnabled = bEnabled;
    // MILAN CHANGE DropTheSquid 12/15/2023
    // this was going off of whether it was a console build, which is a bad way to determine this
    if (bUsingGamepad)
    // END MILAN
    {
        buttonObject = GetVariableObject("_root.mcConsoleButtons.ControlX");
        buttonObject.SetBool("Active", bEnabled);
    }
    else
    {
        ActionScriptVoid("mcGUI.PC_MiddleButton.SetEnabled");
    }
}
public function SetRewardButtonVisibility(bool bVisible)
{
    local GFxValue buttonObject;
    
    // MILAN CHANGE DropTheSquid 12/15/2023
    // this was going off of whether it was a console build, which is a bad way to determine this
    if (bUsingGamepad)
    // END MILAN
    {
        buttonObject = GetVariableObject("_root.mcConsoleButtons.ControlX");
        buttonObject.SetBool("Hidden", !bVisible);
    }
    else
    {
        ActionScriptVoid("mcGUI.PC_MiddleButton.SetVisible");
    }
}
public final function SetupFunctionIntercepts()
{
    AttachToASFunction("mcGUI", "onXButton", 'HandleRewardSelection', FALSE);
    AttachToASFunction("mcGUI", "SetUpdateStatus", 'DoNothingFunction', FALSE);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    GeneralChallenges = ({
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 100, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = -1, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 104, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 105, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 106, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 107, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 108, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 109, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 110, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 111, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 112, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 113, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 114, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 115, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 116, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 117, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 118, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 119, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 120, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 121, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 122, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 123, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 124, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 125, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 126, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 127, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 128, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 100, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 104, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = -1, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 133, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 104, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 134, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 104, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 135, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 104, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 136, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 104, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 137, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 104, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 138, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 104, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 139, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 104, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 140, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 104, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 141, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 104, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 142, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 104, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 105, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = -1, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 147, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 105, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 148, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 105, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 149, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 105, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 106, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = -1, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 154, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 106, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 155, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 106, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 156, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 106, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 157, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 106, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 125, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = -1, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 470, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 125, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 471, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 125, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 472, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 125, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 473, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 125, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 474, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 125, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 475, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 125, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 126, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = -1, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 480, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 481, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 482, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 483, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 484, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 485, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 486, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 487, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 488, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 489, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 490, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 491, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 492, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 493, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 494, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 495, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 496, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 497, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 498, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 499, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 500, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 501, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 502, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 503, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 504, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 505, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 506, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 507, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 508, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 509, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 510, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 511, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 512, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 513, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 514, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 515, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 516, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 517, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 518, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 519, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 520, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 521, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 522, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 523, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 524, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 525, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 526, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 527, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 528, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 529, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 530, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 531, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 532, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 533, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 534, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 535, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 126, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 127, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = -1, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 540, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 127, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 541, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 127, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 542, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 127, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 543, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 127, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 544, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 127, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 545, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 127, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 546, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 127, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 547, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 127, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 548, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 127, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 549, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 127, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 550, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 127, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 552, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 127, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 553, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 127, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 554, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 127, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 555, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 127, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 556, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 127, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 128, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = -1, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 561, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 128, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 562, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 128, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 563, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 128, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 564, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 128, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 565, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 128, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 567, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 128, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 568, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 128, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 569, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 128, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 570, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 128, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 571, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 128, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 572, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 128, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 574, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 128, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 575, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 128, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 576, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 128, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 577, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 128, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 578, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 128, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 704, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 127, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 705, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 127, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 706, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 127, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 707, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 127, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 708, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 128, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 709, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 128, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }, 
                         {
                          UIData = {
                                    Title = "", 
                                    DisplayTitle = "", 
                                    DisplayBody = "", 
                                    Image = "", 
                                    CurrentValue = 0, 
                                    GoalValue = 0, 
                                    NumCompletions = 0, 
                                    Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                    Rank = MPChallengeRank.MPChallengeRank_Unknown
                                   }, 
                          ImageOverride = "", 
                          AccomplishmentIndex = 712, 
                          TitleOverride = $0, 
                          BodyOverride = $0, 
                          Parent = 128, 
                          VisibilityStartTime = 0, 
                          VisibilityEndTime = 0, 
                          VisibilityEntitlement = 0, 
                          ParentItemIndex = 0
                         }
                        )
    AlienChallenges = ({
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 112, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = -1, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 237, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 112, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 238, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 112, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 239, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 112, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 240, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 112, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 241, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 112, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 242, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 112, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 243, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 112, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 244, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 112, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 245, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 112, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 246, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 112, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 405, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 112, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 113, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = -1, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 251, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 113, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 252, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 113, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 253, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 113, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 254, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 113, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 255, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 113, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 256, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 113, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 257, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 113, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 258, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 113, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 259, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 113, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 260, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 113, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 261, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 113, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 114, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = -1, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 266, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 114, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 267, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 114, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 268, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 114, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 269, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 114, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 270, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 114, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 271, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 114, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 272, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 114, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 273, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 114, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 274, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 114, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 275, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 114, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 276, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 114, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 277, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 114, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 115, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = -1, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 282, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 115, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 283, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 115, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 284, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 115, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 287, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 115, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 288, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 115, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 289, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 115, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 290, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 115, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 291, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 115, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 121, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = -1, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 404, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 121, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 408, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 121, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 409, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 121, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 410, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 121, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 411, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 121, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 412, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 121, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 413, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 121, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 414, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 121, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 415, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 121, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 416, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 121, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 417, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 121, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 122, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = -1, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 422, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 122, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 423, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 122, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 424, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 122, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 425, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 122, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 426, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 122, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 427, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 122, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 428, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 122, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 429, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 122, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 430, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 122, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 582, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 122, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 589, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 122, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 433, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 122, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 434, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 122, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 435, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 122, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 123, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = -1, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 440, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 123, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 442, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 123, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 443, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 123, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 445, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 123, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 446, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 123, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 447, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 123, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 448, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 123, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 449, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 123, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 451, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 123, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 579, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 123, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 124, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = -1, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 457, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 124, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 458, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 124, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 459, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 124, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 460, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 124, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 461, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 124, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 462, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 124, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 463, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 124, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 464, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 124, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 465, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 124, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 690, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = -1, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 691, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 690, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 692, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 690, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 693, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 690, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 694, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 690, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 695, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 690, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 696, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 690, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 698, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 690, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 699, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 690, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 700, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 690, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 701, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 690, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 702, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 690, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 684, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 124, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 685, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 121, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 686, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 122, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 687, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 123, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 688, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 124, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }, 
                       {
                        UIData = {
                                  Title = "", 
                                  DisplayTitle = "", 
                                  DisplayBody = "", 
                                  Image = "", 
                                  CurrentValue = 0, 
                                  GoalValue = 0, 
                                  NumCompletions = 0, 
                                  Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                  Rank = MPChallengeRank.MPChallengeRank_Unknown
                                 }, 
                        ImageOverride = "", 
                        AccomplishmentIndex = 689, 
                        TitleOverride = $0, 
                        BodyOverride = $0, 
                        Parent = 675, 
                        VisibilityStartTime = 0, 
                        VisibilityEndTime = 0, 
                        VisibilityEntitlement = 0, 
                        ParentItemIndex = 0
                       }
                      )
    WeaponChallenges = ({
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 107, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = -1, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 162, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 107, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 163, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 107, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 164, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 107, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 165, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 107, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 166, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 107, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 167, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 107, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 168, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 107, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 169, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 107, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 170, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 107, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 171, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 107, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 172, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 107, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 173, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 107, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 108, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = -1, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 178, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 108, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 179, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 108, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 180, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 108, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 181, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 108, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 182, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 108, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 183, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 108, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 184, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 108, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 185, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 108, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 186, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 108, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 187, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 108, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 188, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 108, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 189, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 108, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 595, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 108, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 190, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 108, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 111, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = -1, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 195, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 111, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 196, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 111, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 197, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 111, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 198, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 111, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 199, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 111, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 200, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 111, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 201, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 111, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 202, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 111, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 203, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 111, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 204, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 111, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 205, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 111, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 206, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 111, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 110, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = -1, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 211, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 110, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 212, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 110, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 213, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 110, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 214, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 110, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 215, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 110, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 216, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 110, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 217, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 110, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 109, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = -1, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 222, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 109, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 223, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 109, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 224, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 109, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 225, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 109, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 226, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 109, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 227, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 109, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 228, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 109, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 229, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 109, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 230, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 109, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 231, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 109, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 116, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = -1, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 296, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 116, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 297, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 116, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 298, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 116, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 299, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 116, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 300, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 116, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 301, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 116, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 302, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 116, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 303, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 116, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 304, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 116, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 305, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 116, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 306, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 116, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 307, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 116, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 117, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = -1, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 315, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 117, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 316, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 117, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 317, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 117, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 318, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 117, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 319, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 117, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 320, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 117, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 321, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 117, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 322, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 117, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 323, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 117, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 324, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 117, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 325, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 117, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 326, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 117, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 327, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 117, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 328, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 117, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 329, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 117, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 330, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 117, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 331, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 117, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 332, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 117, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 333, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 117, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 334, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 117, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 335, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 117, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 118, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = -1, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 340, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 118, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 341, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 118, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 342, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 118, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 343, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 118, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 344, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 118, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 345, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 118, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 346, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 118, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 347, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 118, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 348, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 118, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 349, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 118, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 350, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 118, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 351, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 118, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 352, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 118, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 353, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 118, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 354, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 118, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 355, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 118, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 356, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 118, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 357, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 118, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 119, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = -1, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 362, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 119, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 363, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 119, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 364, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 119, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 365, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 119, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 366, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 119, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 367, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 119, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 368, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 119, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 369, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 119, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 370, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 119, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 371, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 119, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 372, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 119, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 373, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 119, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 374, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 119, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 375, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 119, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 376, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 119, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 377, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 119, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 378, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 119, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 379, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 119, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 120, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = -1, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 384, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 120, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 385, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 120, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 386, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 120, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 387, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 120, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 388, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 120, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 389, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 120, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 390, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 120, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 391, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 120, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 392, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 120, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 393, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 120, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 394, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 120, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 395, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 120, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 396, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 120, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 397, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 120, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 398, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 120, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 713, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 108, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 714, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 108, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 715, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 110, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 716, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 107, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }, 
                        {
                         UIData = {
                                   Title = "", 
                                   DisplayTitle = "", 
                                   DisplayBody = "", 
                                   Image = "", 
                                   CurrentValue = 0, 
                                   GoalValue = 0, 
                                   NumCompletions = 0, 
                                   Icon = MPChallengeRankIcon.MPChallengeRankIcon_Bronze, 
                                   Rank = MPChallengeRank.MPChallengeRank_Unknown
                                  }, 
                         ImageOverride = "", 
                         AccomplishmentIndex = 717, 
                         TitleOverride = $0, 
                         BodyOverride = $0, 
                         Parent = 109, 
                         VisibilityStartTime = 0, 
                         VisibilityEndTime = 0, 
                         VisibilityEntitlement = 0, 
                         ParentItemIndex = 0
                        }
                       )
    m_nDefaultChallengeId = -1
    TitleText = $769618
    ExitText = $529360
    BackText = $103236
    CloseSubListText = $163668
    Tab1Text = $769619
    Tab2Text = $769620
    Tab3Text = $769621
    ViewText = $244393
    ContinueText = $163589
    MarkAllViewedText = $769624
    TitleTemplateString = $769622
    BodyTemplateString = $769623
    TimesCompletedString = $778497
    ChallengePointsString = $778498
    SetTitleConfirmString = $778511
    m_bFocusOnStart = TRUE
    m_bHandleKeyPresses = TRUE
    m_bRequiresUIWorld = TRUE
    m_bApplyRightThumbstickDeadzone = TRUE
}