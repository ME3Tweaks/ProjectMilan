// Source: Ported from ME3, MPLobby
Class SFXGUI_MPWeaponSelection_DLC extends SFXGUI_WeaponSelection
    config(UI);

// Functions
public function string GetWeaponRarity(string WeaponName)
{
    local CardInfoData CardData;
    local SFXGAWReinforcementManager GAWManager;
    local string ToRet;
    
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
    Super.OnStart();
    SwapMessageHandler();
}
public function OnClose()
{
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

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=SFXWeaponUIDataManager Name=oDataManager
    End Template
    DataManager = oDataManager
}
