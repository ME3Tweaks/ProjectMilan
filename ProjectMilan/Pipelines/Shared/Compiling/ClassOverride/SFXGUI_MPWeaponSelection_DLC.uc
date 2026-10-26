// Source: Ported from ME3, MPLobby
Class SFXGUI_MPWeaponSelection_DLC extends SFXGUI_WeaponSelection
    config(UI);

var transient bool bHeavyInitialized;
var transient bool bHeavyFocused;
var transient bool bEditingHeavy;
var transient int SelectedHeavyId;
var transient int PendingHeavyIndex;
var transient array<int> AvailableHeavyIndices;

// Functions
public function string GetWeaponRarity(string WeaponName)
{
    local int HeavyIndex;
    local CardInfoData CardData;
    local SFXGAWReinforcementManager GAWManager;
    local string ToRet;
    
    HeavyIndex = Class'SFXMilanHeavyWeaponCatalog'.default.Weapons.Find('ClassPath', WeaponName);
    if (HeavyIndex != -1)
    {
        return Class'SFXMilanHeavyWeaponCatalog'.default.Weapons[HeavyIndex].Rarity;
    }
    CardData.UniqueName = WeaponName;
    GAWManager = SFXGAWReinforcementManager(SFXLocalPlayer(GetPC().Player).GAWReinforcementManager);
    ToRet = "";
    if (GAWManager != None && GAWManager.PopulateCardData(CardData))
    {
        switch (CardData.Rarity)
        {
            case ECardRarity.Rarity_Common:
                ToRet = "common";
                break;
            case ECardRarity.Rarity_Uncommon:
                ToRet = "uncommon";
                break;
            case ECardRarity.Rarity_Rare:
                ToRet = "rare";
                break;
            case ECardRarity.Rarity_UltraRare:
                ToRet = "ultrarare";
                break;
            default:
        }
    }
    return ToRet;
}

// MILAN CHANGE DropTheSquid 5/15/2024
// adding this so we can swap out the message box handler to one that handles controller input properly during the MP weapon select while not affecting single player
public function OnStart()
{
    bHeavyInitialized = FALSE;
    bHeavyFocused = FALSE;
    bEditingHeavy = FALSE;
    Super.OnStart();
    SwapMessageHandler();
    InitializeHeavyWeaponSelector();
    if (GetPC() != None)
    {
        GetPC().SetTimer(0.2, TRUE, 'InitializeHeavyWeaponSelector', Self);
    }
}
public function OnClose()
{
    if (GetPC() != None)
    {
        GetPC().ClearTimer('InitializeHeavyWeaponSelector', Self);
    }
    bEditingHeavy = FALSE;
    bHeavyFocused = FALSE;
    AS_ShutdownHeavySelector();
    Super.OnClose();
    SwapMessageHandler();
}
private final function SwapMessageHandler()
{
    local SFXGUIInteraction oGUI;
    local int vanillaMessageBoxIndex;
    local int mpMessageBoxIndex;
    
    oGUI = Class'SFXGUIInteraction'.static.GetInstance();
    vanillaMessageBoxIndex = oGUI.MovieLibrary.Find('Tag', 'messageBox');
    mpMessageBoxIndex = oGUI.MovieLibrary.Find('Tag', 'MPMessageBox');
    if (vanillaMessageBoxIndex != -1 && mpMessageBoxIndex != -1)
    {
        oGUI.MovieLibrary[vanillaMessageBoxIndex].Tag = 'MPMessageBox';
        oGUI.MovieLibrary[mpMessageBoxIndex].Tag = 'messageBox';
    }
}
// END MILAN

public final function InitializeHeavyWeaponSelector()
{
    local SFXPRIMP PRI;
    local int Id;
    local int Index;
    local bool bChanged;
    local array<int> Available;
    if (GetPC() == None)
    {
        return;
    }
    PRI = SFXPRIMP(GetPC().PlayerReplicationInfo);
    for (Index = 0; Index < Class'SFXMilanHeavyWeaponCatalog'.default.Weapons.Length; ++Index)
    {
        if (Class'SFXMilanHeavyWeaponCatalog'.static.IsUnlocked(Class'SFXMilanHeavyWeaponCatalog'.default.Weapons[Index].Id))
        {
            Available.AddItem(Index);
        }
    }
    bChanged = Available.Length != AvailableHeavyIndices.Length;
    if (!bChanged)
    {
        for (Index = 0; Index < Available.Length; ++Index)
        {
            bChanged = bChanged || Available[Index] != AvailableHeavyIndices[Index];
        }
    }
    AvailableHeavyIndices = Available;
    Id = Class'SFXMilanHeavyWeaponCatalog'.static.NormalizeOwnedId(PRI != None ? PRI.HeavyWeaponId : 0);
    if (!bHeavyInitialized || (!bEditingHeavy && (bChanged || Id != SelectedHeavyId)))
    {
        bHeavyInitialized = TRUE;
        SelectedHeavyId = Id;
        RefreshHeavySlot();
        if (bHeavyFocused && !bEditingHeavy)
        {
            DisplayHeavyWeapon();
        }
    }
}
// Do not allow opening heavy weapon in mod view
public final function OpenModifyUIForWeapon()
{
    local SFXGUIExt_WeaponMods ModExtension;
    if (bHeavyFocused || bEditingHeavy)
    {
        return;
    }
    ModExtension = SFXGUIExt_WeaponMods(GetExtension(Class'SFXGUIExt_WeaponMods'));
    if (ModExtension != None)
    {
        ModExtension.OpenModifyUIForWeapon();
    }
}
private final function string HeavyName(HeavyWeaponEntry Entry, optional bool bShort)
{
    local string Text;
    Text = UIStrRef(bShort ? Entry.ShortName : Entry.DisplayName);
    if (Entry.bHidden)
    {
        Text $= " (" $ UIStrRef(Class'SFXMilanHeavyWeaponCatalog'.default.HiddenLabel) $ ")";
    }
    return Text;
}
private final function string HeavyDescription(HeavyWeaponEntry Entry)
{
    local string Text;
    Text = UIStrRef(Entry.Description);
    if (Entry.bHidden)
    {
        Text $= "\n\n" $ UIStrRef(Class'SFXMilanHeavyWeaponCatalog'.default.HiddenDescriptionSuffix);
    }
    return Text;
}
private final function RefreshHeavySlot()
{
    local int Index;
    local HeavyWeaponEntry Entry;
    Index = Class'SFXMilanHeavyWeaponCatalog'.static.FindIndex(SelectedHeavyId);
    if (Index == -1)
    {
        return;
    }
    Entry = Class'SFXMilanHeavyWeaponCatalog'.default.Weapons[Index];
    AS_SetHeavySlot(Entry.bNoWeapon ? -1 : Entry.Id, HeavyName(Entry, TRUE), Entry.IconResource, Entry.IconIndex,
        UIStrRef(Class'SFXMilanHeavyWeaponCatalog'.default.CategoryLabel),
        AvailableHeavyIndices.Length);
}
public final function HeavyWeaponFocused(bool bFocused)
{
    bHeavyFocused = bFocused;
    if (bFocused && bHeavyInitialized)
    {
        DisplayHeavyWeapon();
    }
}
public final function BeginHeavyWeaponSelection()
{
    if (!bHeavyInitialized || bEditingHeavy)
    {
        return;
    }
    PendingHeavyIndex = Class'SFXMilanHeavyWeaponCatalog'.static.FindIndex(SelectedHeavyId);
    if (PendingHeavyIndex == -1)
    {
        return;
    }
    bEditingHeavy = TRUE;
    AS_SetHeavySelection(TRUE);
    DisplayHeavyWeapon();
}
public final function CycleHeavyWeapon(int Direction)
{
    local int NextIndex;
    if (!bEditingHeavy)
    {
        return;
    }
    NextIndex = AvailableHeavyIndices.Find(PendingHeavyIndex) + (Direction > 0 ? 1 : -1);
    if (NextIndex < 0 || NextIndex >= AvailableHeavyIndices.Length)
    {
        PlayGuiError();
        return;
    }
    PendingHeavyIndex = AvailableHeavyIndices[NextIndex];
    PlayGuiSound('WeaponGUIListMoveWeapon');
    DisplayHeavyWeapon(TRUE);
}
public final function AcceptHeavyWeaponSelection()
{
    local SFXPRIMP PRI;
    if (!bEditingHeavy)
    {
        return;
    }
    PRI = SFXPRIMP(GetPC().PlayerReplicationInfo);
    if (PRI == None)
    {
        PlayGuiError();
        return;
    }
    SelectedHeavyId = Class'SFXMilanHeavyWeaponCatalog'.default.Weapons[PendingHeavyIndex].Id;
    if (!Class'SFXMilanHeavyWeaponCatalog'.static.IsUnlocked(SelectedHeavyId))
    {
        PlayGuiError();
        return;
    }
    PRI.SetHeavyWeaponSelection(SelectedHeavyId);
    bEditingHeavy = FALSE;
    AS_SetHeavySelection(FALSE);
    RefreshHeavySlot();
    DisplayHeavyWeapon();
}
public final function CancelHeavyWeaponSelection()
{
    if (!bEditingHeavy)
    {
        return;
    }
    bEditingHeavy = FALSE;
    AS_SetHeavySelection(FALSE);
    RefreshHeavySlot();
    DisplayHeavyWeapon();
}
private final function DisplayHeavyWeapon(optional bool bFlourish)
{
    local int Index;
    local HeavyWeaponEntry Entry;
    Index = bEditingHeavy ? PendingHeavyIndex : Class'SFXMilanHeavyWeaponCatalog'.static.FindIndex(SelectedHeavyId);
    if (Index < 0 || Index >= Class'SFXMilanHeavyWeaponCatalog'.default.Weapons.Length)
    {
        return;
    }
    Entry = Class'SFXMilanHeavyWeaponCatalog'.default.Weapons[Index];
    AS_ClearWeaponStatsDisplay();
    AS_SetWeaponInfoDisplay(HeavyName(Entry), HeavyDescription(Entry),
        UIStrRef(Class'SFXMilanHeavyWeaponCatalog'.default.CategoryLabel), Entry.Image);
    if (bEditingHeavy)
    {
        AS_SetInventoryWeapon(HeavyName(Entry), HeavyDescription(Entry), Entry.Image, FALSE,
            AvailableHeavyIndices.Find(Index) + 1, AvailableHeavyIndices.Length, bFlourish, Entry.ClassPath);
    }
}
private final function AS_ShutdownHeavySelector()
{
    ActionScriptVoid("WeaponSelect.ShutdownHeavySelector");
}
public final function AS_SetHeavySlot(int Id, string ShortName, string IconResource, int IconIndex, string Category, int Count)
{
    ActionScriptVoid("WeaponSelect.SetHeavySlot");
}
public final function AS_SetHeavySelection(bool bSelecting)
{
    ActionScriptVoid("WeaponSelect.SetHeavySelection");
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=SFXWeaponUIDataManager Name=oDataManager
    End Template
    DataManager = oDataManager
}
