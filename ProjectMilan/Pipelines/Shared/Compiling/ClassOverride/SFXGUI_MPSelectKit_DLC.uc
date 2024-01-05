Class SFXGUI_MPSelectKit_DLC extends SFXGUI_MPSelectKit
    config(UI);

// Types
struct KitDescriptionData 
{
    var string KitName;
    var stringref ClassString;
    var stringref IPNameString;
    var stringref IPEntryString;
    var stringref GameplayEntryString;
    var stringref StatsString1;
    var stringref StatsString2;
    var stringref StatsString3;
    var stringref StatsString4;
    var stringref StatsString5;
};

// Variables
var config array<KitDescriptionData> KitDescriptions;
// MILAN CHANGE DropTheSquid 1/4/2024
// added so we can keep track of whether a promotion event is currently active
// to control mouse visibility
var transient bool bIsPromotionEventActive;
// END MILAN

// Functions
// MILAN CHANGE DropTheSquid 12/12/2023
// added so that we can react to input changes to update the UI
public event function HandleButtonRefresh(bool usingGamepad)
{
    Super(SFXGUIMovie).HandleButtonRefresh(usingGamepad);
	// if there is a promotion event, do not show the mouse
    SetMouseVisible(!usingGamepad && !bIsPromotionEventActive);
	ActionScriptVoid("screen.RefreshButtonHelp");
}
// added so the unrealscript can keep track of whether it is currently displaying a promotion event to control mouse visibility appropriately
public function PromotionEventActive(bool active)
{
    bIsPromotionEventActive = active;
    if (active)
    {
        SetMouseVisible(false);
    }
    else 
    {
        SetMouseVisible(!bUsingGamepad);
    }     
}
// added to set the mouse visibility on start according to the UI mode
public event function OnStart()
{
    Super.OnStart();
    // make sure we actually can control the mouse visibility
	BioPlayerController(GetPC()).GameModeManager2.GameModes[int(EGameModes.GameMode_Lobby)].bHasMouseAuthority = false;
	// make sure the mouse is initially shown/hidden based on the input mode
	SetMouseVisible(!bUsingGamepad);
}
// END MILAN
public final function string ComposeKitDescriptionString(KitDescriptionData oData)
{
    local string DescriptionString;
    
    if (oData.ClassString != 0)
    {
        DescriptionString $= GetUIString(oData.ClassString, TRUE) $ "\n";
    }
    if (oData.IPNameString != 0)
    {
        DescriptionString $= GetUIString(oData.IPNameString, TRUE) $ "\n";
    }
    if (oData.IPEntryString != 0)
    {
        DescriptionString $= "\n";
        DescriptionString $= GetUIString(oData.IPEntryString, TRUE) $ "\n";
    }
    if (oData.GameplayEntryString != 0)
    {
        DescriptionString $= "\n";
        DescriptionString $= GetUIString(oData.GameplayEntryString, TRUE) $ "\n";
    }
    if (oData.StatsString1 != 0)
    {
        DescriptionString $= "\n";
        DescriptionString $= GetUIString(oData.StatsString1, TRUE) $ "\n";
    }
    if (oData.StatsString2 != 0)
    {
        DescriptionString $= GetUIString(oData.StatsString2, TRUE) $ "\n";
    }
    if (oData.StatsString3 != 0)
    {
        DescriptionString $= GetUIString(oData.StatsString3, TRUE) $ "\n";
    }
    if (oData.StatsString4 != 0)
    {
        DescriptionString $= GetUIString(oData.StatsString4, TRUE) $ "\n";
    }
    if (oData.StatsString5 != 0)
    {
        DescriptionString $= GetUIString(oData.StatsString5, TRUE) $ "\n";
    }
    return DescriptionString;
}
public final function ShowCharacterInfo(string KitName)
{
    local BioMessageBoxOptionalParams oParams;
    local string DescriptionString;
    local int idx;
    
    idx = KitDescriptions.Find('KitName', KitName);
    if (idx != -1)
    {
        oParams.bModal = TRUE;
		// MILAN CHANGE DropTheSquid 1/4/2024
		// this was srCancel, but you are not cancelling anything
        oParams.srBText = srback;
        DescriptionString = ComposeKitDescriptionString(KitDescriptions[idx]);
        AS_SetInputDisabled(TRUE);
        GetSFXUIController().QueueNamedMessageBoxEx('CharacterInfo', 3, DescriptionString, oParams, ShowCharacterInfoCallback, 0, GetPC());
    }
}
public final function ShowCharacterInfoCallback(bool bAPressed, int Context)
{
    AS_SetInputDisabled(FALSE);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    KitDescriptions = ({
                        KitName = "SoldierHumanMale", 
                        ClassString = $727964, 
                        IPNameString = $0, 
                        IPEntryString = $727970, 
                        GameplayEntryString = $727979, 
                        StatsString1 = $728002, 
                        StatsString2 = $728011, 
                        StatsString3 = $728024, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "SentinelHumanMale", 
                        ClassString = $727965, 
                        IPNameString = $0, 
                        IPEntryString = $727970, 
                        GameplayEntryString = $727980, 
                        StatsString1 = $728002, 
                        StatsString2 = $728011, 
                        StatsString3 = $728015, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "EngineerHumanMale", 
                        ClassString = $727966, 
                        IPNameString = $0, 
                        IPEntryString = $727970, 
                        GameplayEntryString = $727981, 
                        StatsString1 = $728002, 
                        StatsString2 = $728011, 
                        StatsString3 = $728019, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "InfiltratorHumanMale", 
                        ClassString = $727967, 
                        IPNameString = $0, 
                        IPEntryString = $727970, 
                        GameplayEntryString = $727982, 
                        StatsString1 = $728002, 
                        StatsString2 = $728011, 
                        StatsString3 = $728014, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "VanguardHumanMale", 
                        ClassString = $727968, 
                        IPNameString = $0, 
                        IPEntryString = $727970, 
                        GameplayEntryString = $727983, 
                        StatsString1 = $728002, 
                        StatsString2 = $728011, 
                        StatsString3 = $728009, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "AdeptHumanMale", 
                        ClassString = $727969, 
                        IPNameString = $0, 
                        IPEntryString = $727970, 
                        GameplayEntryString = $727984, 
                        StatsString1 = $728002, 
                        StatsString2 = $728011, 
                        StatsString3 = $728007, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "SoldierHumanFemale", 
                        ClassString = $727964, 
                        IPNameString = $0, 
                        IPEntryString = $727970, 
                        GameplayEntryString = $727979, 
                        StatsString1 = $728002, 
                        StatsString2 = $728011, 
                        StatsString3 = $728024, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "SentinelHumanFemale", 
                        ClassString = $727965, 
                        IPNameString = $0, 
                        IPEntryString = $727970, 
                        GameplayEntryString = $727980, 
                        StatsString1 = $728002, 
                        StatsString2 = $728011, 
                        StatsString3 = $728015, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "EngineerHumanFemale", 
                        ClassString = $727966, 
                        IPNameString = $0, 
                        IPEntryString = $727970, 
                        GameplayEntryString = $727981, 
                        StatsString1 = $728002, 
                        StatsString2 = $728011, 
                        StatsString3 = $728019, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "InfiltratorHumanFemale", 
                        ClassString = $727967, 
                        IPNameString = $0, 
                        IPEntryString = $727970, 
                        GameplayEntryString = $727982, 
                        StatsString1 = $728002, 
                        StatsString2 = $728011, 
                        StatsString3 = $728014, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "VanguardHumanFemale", 
                        ClassString = $727968, 
                        IPNameString = $0, 
                        IPEntryString = $727970, 
                        GameplayEntryString = $727983, 
                        StatsString1 = $728002, 
                        StatsString2 = $728011, 
                        StatsString3 = $728009, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "AdeptHumanFemale", 
                        ClassString = $727969, 
                        IPNameString = $0, 
                        IPEntryString = $727970, 
                        GameplayEntryString = $727984, 
                        StatsString1 = $728002, 
                        StatsString2 = $728011, 
                        StatsString3 = $728007, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "AdeptAsari", 
                        ClassString = $711376, 
                        IPNameString = $0, 
                        IPEntryString = $727971, 
                        GameplayEntryString = $727985, 
                        StatsString1 = $728001, 
                        StatsString2 = $728008, 
                        StatsString3 = $728018, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "AdeptDrell", 
                        ClassString = $711377, 
                        IPNameString = $0, 
                        IPEntryString = $727974, 
                        GameplayEntryString = $727990, 
                        StatsString1 = $728000, 
                        StatsString2 = $728006, 
                        StatsString3 = $728023, 
                        StatsString4 = $728020, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "EngineerQuarian", 
                        ClassString = $711378, 
                        IPNameString = $0, 
                        IPEntryString = $727976, 
                        GameplayEntryString = $727994, 
                        StatsString1 = $728003, 
                        StatsString2 = $728010, 
                        StatsString3 = $728019, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "EngineerSalarian", 
                        ClassString = $711379, 
                        IPNameString = $0, 
                        IPEntryString = $727975, 
                        GameplayEntryString = $727992, 
                        StatsString1 = $728003, 
                        StatsString2 = $728010, 
                        StatsString3 = $728019, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "InfiltratorSalarian", 
                        ClassString = $711380, 
                        IPNameString = $0, 
                        IPEntryString = $727975, 
                        GameplayEntryString = $727991, 
                        StatsString1 = $728003, 
                        StatsString2 = $728010, 
                        StatsString3 = $728014, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "InfiltratorQuarian", 
                        ClassString = $711381, 
                        IPNameString = $0, 
                        IPEntryString = $727976, 
                        GameplayEntryString = $727993, 
                        StatsString1 = $728003, 
                        StatsString2 = $728010, 
                        StatsString3 = $728014, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "SentinelTurian", 
                        ClassString = $711382, 
                        IPNameString = $0, 
                        IPEntryString = $727972, 
                        GameplayEntryString = $727987, 
                        StatsString1 = $728004, 
                        StatsString2 = $728015, 
                        StatsString3 = $728028, 
                        StatsString4 = $728026, 
                        StatsString5 = $728012
                       }, 
                       {
                        KitName = "SentinelKrogan", 
                        ClassString = $711383, 
                        IPNameString = $0, 
                        IPEntryString = $727973, 
                        GameplayEntryString = $727988, 
                        StatsString1 = $728005, 
                        StatsString2 = $728021, 
                        StatsString3 = $728022, 
                        StatsString4 = $728027, 
                        StatsString5 = $728012
                       }, 
                       {
                        KitName = "SoldierKrogan", 
                        ClassString = $711384, 
                        IPNameString = $0, 
                        IPEntryString = $727973, 
                        GameplayEntryString = $727988, 
                        StatsString1 = $728005, 
                        StatsString2 = $728021, 
                        StatsString3 = $728022, 
                        StatsString4 = $728027, 
                        StatsString5 = $728012
                       }, 
                       {
                        KitName = "SoldierTurian", 
                        ClassString = $711385, 
                        IPNameString = $0, 
                        IPEntryString = $727972, 
                        GameplayEntryString = $727987, 
                        StatsString1 = $728004, 
                        StatsString2 = $728015, 
                        StatsString3 = $728028, 
                        StatsString4 = $728026, 
                        StatsString5 = $728012
                       }, 
                       {
                        KitName = "VanguardDrell", 
                        ClassString = $711386, 
                        IPNameString = $0, 
                        IPEntryString = $727974, 
                        GameplayEntryString = $727990, 
                        StatsString1 = $728000, 
                        StatsString2 = $728006, 
                        StatsString3 = $728023, 
                        StatsString4 = $728020, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "VanguardAsari", 
                        ClassString = $711387, 
                        IPNameString = $0, 
                        IPEntryString = $727971, 
                        GameplayEntryString = $727986, 
                        StatsString1 = $728001, 
                        StatsString2 = $728008, 
                        StatsString3 = $728018, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "SoldierHumanMaleBF3", 
                        ClassString = $727964, 
                        IPNameString = $0, 
                        IPEntryString = $727970, 
                        GameplayEntryString = $727979, 
                        StatsString1 = $728002, 
                        StatsString2 = $728011, 
                        StatsString3 = $728024, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "SoldierGethDestroyer", 
                        ClassString = $782882, 
                        IPNameString = $0, 
                        IPEntryString = $727977, 
                        GameplayEntryString = $785637, 
                        StatsString1 = $814531, 
                        StatsString2 = $728027, 
                        StatsString3 = $728012, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "AdeptCollector", 
                        ClassString = $783880, 
                        IPNameString = $0, 
                        IPEntryString = $785638, 
                        GameplayEntryString = $785639, 
                        StatsString1 = $787961, 
                        StatsString2 = $785642, 
                        StatsString3 = $785643, 
                        StatsString4 = $785644, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "SentinelKroganWarlord", 
                        ClassString = $812780, 
                        IPNameString = $0, 
                        IPEntryString = $727973, 
                        GameplayEntryString = $812781, 
                        StatsString1 = $812782, 
                        StatsString2 = $812783, 
                        StatsString3 = $728022, 
                        StatsString4 = $728027, 
                        StatsString5 = $728012
                       }, 
                       {
                        KitName = "EngineerMerc", 
                        ClassString = $814592, 
                        IPNameString = $0, 
                        IPEntryString = $812785, 
                        GameplayEntryString = $812786, 
                        StatsString1 = $728002, 
                        StatsString2 = $728011, 
                        StatsString3 = $812787, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "VanguardTurianFemale", 
                        ClassString = $812774, 
                        IPNameString = $0, 
                        IPEntryString = $812776, 
                        GameplayEntryString = $812777, 
                        StatsString1 = $812778, 
                        StatsString2 = $728020, 
                        StatsString3 = $812779, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }, 
                       {
                        KitName = "InfiltratorFembot", 
                        ClassString = $812764, 
                        IPNameString = $0, 
                        IPEntryString = $812766, 
                        GameplayEntryString = $812767, 
                        StatsString1 = $728004, 
                        StatsString2 = $728006, 
                        StatsString3 = $728023, 
                        StatsString4 = $0, 
                        StatsString5 = $0
                       }
                      )
}