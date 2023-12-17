// This does not get automatically compiled into the build. It is only included for documentation and a building point for further changes
// we can include comments and more intuitive syntax without it going through the compiler/decompiler cycle of JPEXS
class screens.MPAppearance.MPAppearance extends com.SFXScreen
{
    var Scrollbar;
    var Titlebar;
    var TintPanel;
    var PatternMenu;
    var AppearanceMenu;
    var Message;
    var m_ControllerButtons;
    var m_PCResetButton;
    var m_PCBackButton;
    var m_PCResetButton_Deploy;
    var m_PCBackButton_Deploy;
    var m_PCConfirmButton_Deploy;
    var rightStick;
    var rightStickPC;
    var CurrSelectedTint1ID;
    var ChangeItemCallback;
    var ChangeItemEnd;
    var ConfirmItemCallback;
    var CurrSelectedTint2ID;
    var CurrSelectedPatternID;
    var CurrSelectedPatternColorID;
    var CurrSelectedPhongID;
    var CurrSelectedEmissiveID;
    var CurrSelectedSkinToneID;
    var playerInfo;
    var srSelectAppearance = "NOLOC:Select Appearance";
    var srCharacterName = "NOLOC:Character Name:";
    var srReset = "NOLOC:Reset";
    var srSelect = "NOLOC:Select";
    var srBack = "NOLOC:Back";
    var srConfirm = "NOLOC:Create Character";
    var srArmorColor = "NOLOC:Armor Color";
    var srPrimaryColor = "NOLOC:Primary Color";
    var srSecondaryColor = "NOLOC:Secondary Color";
    var srPattern = "NOLOC:Pattern";
    var srPatternColor = "NOLOC:Pattern Color";
    var srMaterialColor = "NOLOC:Material";
    var srLights = "NOLOC:Lights";
    var srSkinTone = "NOLOC:Skin Tone";
    var srNew = "NOLOC:New";
    var srCancel = "NOLOC:Cancel";
    var srDisabledOptionDescription = "NOLOC:This option currently isn\'t available.  Buy more packs from the reinforcement store to unlock more customization options";
    var srMoveCamera = "NOLOC:Move Camera";
    static var SELECTED_FIELD_NONE = 0;
    static var SELECTED_FIELD_NAME = 1;
    static var SELECTED_FIELD_MENU = 2;
    static var SELECTED_FIELD_TINTS = 3;
    static var SELECTED_FIELD_PATTERNS = 4;
    var SelectedField = screens.MPAppearance.MPAppearance.SELECTED_FIELD_NAME;
    var SelectedRightField = screens.MPAppearance.MPAppearance.SELECTED_FIELD_TINTS;
    var bLoaded = false;
    var RESTRICTED_CHARACTERS = "^;";
	var confirmMenuItem;
	// MILAN CHANGE DropTheSquid 12/12/2023
	// added for debugging purposes
	// function LogFromAS()
	// {
	// 	// takes any number of args
	// 	var concatArgs = "";
	// 	var i = 0;
	// 	for (i = 0; i < arguments.length; i++)
	// 	{
	// 		if (concatArgs == "")
	// 		{
	// 			concatArgs = arguments[i].toString();
	// 		}
	// 		else
	// 		{
	// 			concatArgs = concatArgs + "," + arguments[i].toString();
	// 		}
	// 	}
	// 	flash.external.ExternalInterface.call("LogFromAS", concatArgs);
	// }
	// END MILAN
    function MPAppearance()
    {
        super();
    }
    function onLoad()
    {
        super.onLoad();
        this.bLoaded = true;
        this.SetupLocalization();
        this.SetupButtons();
        this.Scrollbar._visible = false;
        Key.addListener(this);
        Selection.addListener(this);
        Selection.disableFocusKeys = true;
    }
    function InitializeScreen()
    {
        this.Titlebar.text = this.srSelectAppearance;
        this.RefreshCharacterData();
        this.SelectedField = screens.MPAppearance.MPAppearance.SELECTED_FIELD_NAME;
        this.TintPanel.SetSelectedCallback(mx.utils.Delegate.create(this,this.OnSwatchSelected));
        this.TintPanel.SetHoveredCallback(mx.utils.Delegate.create(this,this.OnSwatchHovered));
        this.TintPanel.SetHoveredEndCallback(mx.utils.Delegate.create(this,this.OnSwatchHoveredEnd));
        this.PatternMenu.setupScrollBar(this.Scrollbar);
        this.TintPanel.setupScrollBar(this.Scrollbar);
        if(this.AppearanceMenu.IsLoaded())
        {
            this.InitializeMenu();
        }
        else
        {
            this.AppearanceMenu.onLoad = this.MakeDelegate(this.OnAppearanceMenuLoad);
        }
        this.Message.text = this.srDisabledOptionDescription;
        this.Message._visible = false;
        this.InitializeNameField();
    }
    function SetupLocalization()
    {
        this.srSelectAppearance = "$" + _global.SFX.GetIniString("srSelectAppearance");
        this.srCharacterName = "$" + _global.SFX.GetIniString("srCharacterNameLabel");
        this.srArmorColor = "$" + _global.SFX.GetIniString("srArmorColorLabel");
        this.srConfirm = "$" + _global.SFX.GetIniString("srConfirm");
        this.srReset = "$" + _global.SFX.GetIniString("srReset");
        this.srBack = "$" + _global.SFX.GetIniString("srBack");
        this.srSelect = "$" + _global.SFX.GetIniString("srSelect");
        this.srBack = "$" + _global.SFX.GetIniString("srBack");
        this.srReset = "$" + _global.SFX.GetIniString("srReset");
        this.srCancel = "$" + _global.SFX.GetIniString("srCancel");
        this.srPrimaryColor = "$" + _global.SFX.GetIniString("srPrimaryColor");
        this.srSecondaryColor = "$" + _global.SFX.GetIniString("srSecondaryColor");
        this.srPattern = "$" + _global.SFX.GetIniString("srPattern");
        this.srPatternColor = "$" + _global.SFX.GetIniString("srPatternColor");
        this.srLights = "$" + _global.SFX.GetIniString("srLights");
        this.srMaterialColor = "$" + _global.SFX.GetIniString("srMaterialColor");
        this.srSkinTone = "$" + _global.SFX.GetIniString("srSkinTone");
        this.srNew = "$" + _global.SFX.GetIniString("srNew");
        this.srDisabledOptionDescription = "$" + _global.SFX.GetIniString("srDisabledOptionDescription");
        this.srMoveCamera = "$" + _global.SFX.GetIniString("srMoveCamera");
    }
    function SetupButtons()
    {
        this.m_ControllerButtons = _root.ConsoleController;
        this.m_PCResetButton = _root.PCResetButton;
        this.m_PCBackButton = _root.PCBackButton;
        this.m_PCResetButton_Deploy = _root.PCResetButton_Deploy;
        this.m_PCBackButton_Deploy = _root.PCBackButton_Deploy;
        this.m_PCConfirmButton_Deploy = _root.PCConfirmButton_Deploy;
		// MILAN CHANGE DropTheSquid 12/12/2023
		// moving all visibility stuff to RefreshButtonHelp, keying off of bUsingGamepad instead of platform
		var bIsInDeployFlow = Boolean(flash.external.ExternalInterface.call("IsInDeployFlow"));
        // set up PC buttons
		this.rightStickPC.TextInput.text = this.srMoveCamera;
		if(bIsInDeployFlow)
		{
			this.m_PCResetButton_Deploy.SetText(this.srReset);
			this.m_PCBackButton_Deploy.SetText(this.srCancel);
			this.m_PCConfirmButton_Deploy.SetText(this.srConfirm);
			this.m_PCResetButton_Deploy.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.OnResetButtonPressed));
			this.m_PCBackButton_Deploy.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.OnBackButtonPressed));
			// changed this from pointing to OnSelectButtonPressed to the method that should get invoked only for the PC button, so I can edit OnSelectButtonPressed to work for console well
			this.m_PCConfirmButton_Deploy.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.OnConfirmActivate));
		}
		else
		{
			this.m_PCResetButton.SetText(this.srReset);
			this.m_PCBackButton.SetText(this.srBack);
			this.m_PCResetButton.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.OnResetButtonPressed));
			this.m_PCBackButton.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.OnBackButtonPressed));
		}
		// set up Controller buttons
		this.m_ControllerButtons.addEventListener("onButtonA",mx.utils.Delegate.create(this,this.OnSelectButtonPressed));
		this.m_ControllerButtons.addEventListener("onButtonB",mx.utils.Delegate.create(this,this.OnBackButtonPressed));
		this.m_ControllerButtons.addEventListener("onButtonX",mx.utils.Delegate.create(this,this.OnResetButtonPressed));
		this.m_ControllerButtons.addEventListener("onDPadUp",mx.utils.Delegate.create(this,this.onDPadUp));
		this.m_ControllerButtons.addEventListener("onDPadDown",mx.utils.Delegate.create(this,this.onDPadDown));
		this.m_ControllerButtons.addEventListener("onDPadLeft",mx.utils.Delegate.create(this,this.onDPadLeft));
		this.m_ControllerButtons.addEventListener("onDPadRight",mx.utils.Delegate.create(this,this.onDPadRight));
		this.m_ControllerButtons.addEventListener("onInvalidInput",mx.utils.Delegate.create(this,this.onInvalidInput));
		this.m_ControllerButtons.ControlA.SetText(this.srSelect);
		this.m_ControllerButtons.ControlB.SetText(this.srBack);
		this.m_ControllerButtons.ControlX.SetText(this.srReset);
		this.rightStick.TextInput.text = this.srMoveCamera;
        // set visibility correctly
		this.RefreshButtonHelp(flash.external.ExternalInterface.call("IsUsingGamepad"));
		// END MILAN
        this.RefreshActionButtonStates();
    }
    function OnAppearanceMenuLoad()
    {
        delete this.AppearanceMenu.onLoad;
        this.InitializeMenu();
    }
    function InitializeMenu()
    {
        if(this.bLoaded)
        {
			// renamed these loc variables to be more clear
            var tint1State = Number(flash.external.ExternalInterface.call("GetTint1State"));
            var tint2State = Number(flash.external.ExternalInterface.call("GetTint2State"));
            var patternState = Number(flash.external.ExternalInterface.call("GetPatternState"));
            var patternColorState = Number(flash.external.ExternalInterface.call("GetPatternColorState"));
            var phongState = Number(flash.external.ExternalInterface.call("GetPhongState"));
            var emissiveState = Number(flash.external.ExternalInterface.call("GetEmissiveState"));
            var skinToneState = Number(flash.external.ExternalInterface.call("GetSkinToneState"));
            var canShowPrimaryColor = Boolean(flash.external.ExternalInterface.call("CanShowPrimaryColor"));
            var canShowSecondaryColor = Boolean(flash.external.ExternalInterface.call("CanShowSecondaryColor"));
            var canShowPattern = Boolean(flash.external.ExternalInterface.call("CanShowPattern"));
            var canShowPatternColor = Boolean(flash.external.ExternalInterface.call("CanShowPatternColor"));
            var canShowPhong = Boolean(flash.external.ExternalInterface.call("CanShowPhong"));
            var canShowLights = Boolean(flash.external.ExternalInterface.call("CanShowEmissive"));
            var canShowSkintone = Boolean(flash.external.ExternalInterface.call("CanShowSkinTone"));
            if(canShowPrimaryColor)
            {
                this.AppearanceMenu.AddNewItem(this.srPrimaryColor,tint1State,this.srNew,this.MakeDelegate(this.OnAppearanceMenuItemSelected),this.MakeDelegate(this.OnTint1Activate));
            }
            if(canShowSecondaryColor)
            {
                this.AppearanceMenu.AddNewItem(this.srMaterialColor,phongState,this.srNew,this.MakeDelegate(this.OnAppearanceMenuItemSelected),this.MakeDelegate(this.OnPhongActivate));
            }
            if(canShowPattern)
            {
                this.AppearanceMenu.AddNewItem(this.srSecondaryColor,tint2State,this.srNew,this.MakeDelegate(this.OnAppearanceMenuItemSelected),this.MakeDelegate(this.OnTint2Activate));
            }
            if(canShowPatternColor)
            {
                this.AppearanceMenu.AddNewItem(this.srPattern,patternState,this.srNew,this.MakeDelegate(this.OnAppearanceMenuItemSelected),this.MakeDelegate(this.OnPatternActivate));
            }
            if(canShowPhong)
            {
                this.AppearanceMenu.AddNewItem(this.srPatternColor,patternColorState,this.srNew,this.MakeDelegate(this.OnAppearanceMenuItemSelected),this.MakeDelegate(this.OnPatternColorActivate));
            }
            if(canShowLights)
            {
                this.AppearanceMenu.AddNewItem(this.srLights,emissiveState,this.srNew,this.MakeDelegate(this.OnAppearanceMenuItemSelected),this.MakeDelegate(this.OnEmissiveActivate));
            }
            if(canShowSkintone)
            {
                this.AppearanceMenu.AddNewItem(this.srSkinTone,skinToneState,this.srNew,this.MakeDelegate(this.OnAppearanceMenuItemSelected),this.MakeDelegate(this.OnSkinToneActivate));
            }
			this.RefreshButtonHelp(flash.external.ExternalInterface.call("IsUsingGamepad"));
        }
    }
    function OnAppearanceMenuItemSelected()
    {
        this.HidePanels();
        this.Message._visible = !this.AppearanceMenu.selectedItem.IsEnabled();
    }
    function OnTint1Activate()
    {
        this.SetNewFocus(screens.MPAppearance.MPAppearance.SELECTED_FIELD_MENU);
        if(flash.external.ExternalInterface.call("GetTint1State") != screens.MPAppearance.AppearanceMenuList.APPEARANCE_ITEM_DISABLED)
        {
            var _loc2_ = Number(flash.external.ExternalInterface.call("GetSelectedTint1ID"));
            this.CurrSelectedTint1ID = _loc2_;
            this.ChangeItemCallback = this.MakeDelegate(this.OnTint1Change);
            this.ChangeItemEnd = this.MakeDelegate(this.OnTint1End);
            this.ConfirmItemCallback = this.MakeDelegate(this.OnTint1Confirm);
            this.SetupTintPanel(com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetTint1SwatchData")),_loc2_);
        }
        this.RefreshActionButtonStates();
    }
    function OnPCAppearanceMenuItemActivate(nID, nIndex)
    {
        this.AppearanceMenu.selectedIndex = nIndex;
    }
    function OnTint1Change(nID)
    {
        flash.external.ExternalInterface.call("ChangePawnTint1",nID);
    }
    function OnTint1End()
    {
        flash.external.ExternalInterface.call("ChangePawnTint1",this.CurrSelectedTint1ID);
    }
    function OnTint1Confirm(nID)
    {
        this.CurrSelectedTint1ID = nID;
        flash.external.ExternalInterface.call("ChangeTint1Selection",nID);
    }
    function OnTint2Activate()
    {
        this.SetNewFocus(screens.MPAppearance.MPAppearance.SELECTED_FIELD_MENU);
        if(flash.external.ExternalInterface.call("GetTint2State") != screens.MPAppearance.AppearanceMenuList.APPEARANCE_ITEM_DISABLED)
        {
            var _loc2_ = Number(flash.external.ExternalInterface.call("GetSelectedTint2ID"));
            this.CurrSelectedTint2ID = _loc2_;
            this.ChangeItemCallback = this.MakeDelegate(this.OnTint2Change);
            this.ChangeItemEnd = this.MakeDelegate(this.OnTint2End);
            this.ConfirmItemCallback = this.MakeDelegate(this.OnTint2Confirm);
            this.SetupTintPanel(com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetTint2SwatchData")),_loc2_);
        }
        this.RefreshActionButtonStates();
    }
    function OnTint2Change(nID)
    {
        flash.external.ExternalInterface.call("ChangePawnTint2",nID);
    }
    function OnTint2End()
    {
        flash.external.ExternalInterface.call("ChangePawnTint2",this.CurrSelectedTint2ID);
    }
    function OnTint2Confirm(nID)
    {
        this.CurrSelectedTint2ID = nID;
        flash.external.ExternalInterface.call("ChangeTint2Selection",nID);
    }
    function OnPatternActivate()
    {
        this.SetNewFocus(screens.MPAppearance.MPAppearance.SELECTED_FIELD_MENU);
        if(flash.external.ExternalInterface.call("GetPatternState") != screens.MPAppearance.AppearanceMenuList.APPEARANCE_ITEM_DISABLED)
        {
            var _loc2_ = Number(flash.external.ExternalInterface.call("GetSelectedPatternID"));
            this.CurrSelectedPatternID = _loc2_;
            this.SetupPatternPanel(com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetPatternData")),_loc2_);
        }
    }
    function OnPatternColorActivate()
    {
        this.SetNewFocus(screens.MPAppearance.MPAppearance.SELECTED_FIELD_MENU);
        if(flash.external.ExternalInterface.call("GetPatternColorState") != screens.MPAppearance.AppearanceMenuList.APPEARANCE_ITEM_DISABLED)
        {
            var _loc2_ = Number(flash.external.ExternalInterface.call("GetSelectedPatternColorID"));
            this.CurrSelectedPatternColorID = _loc2_;
            this.ChangeItemCallback = this.MakeDelegate(this.OnPatternColorChange);
            this.ChangeItemEnd = this.MakeDelegate(this.OnPatternColorEnd);
            this.ConfirmItemCallback = this.MakeDelegate(this.OnPatternColorConfirm);
            this.SetupTintPanel(com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetPatternColorSwatchData")),_loc2_);
        }
        this.RefreshActionButtonStates();
    }
    function OnPatternColorChange(nID)
    {
        flash.external.ExternalInterface.call("ChangePawnPatternColor",nID);
    }
    function OnPatternColorEnd()
    {
        flash.external.ExternalInterface.call("ChangePawnPatternColor",this.CurrSelectedPatternColorID);
    }
    function OnPatternColorConfirm(nID)
    {
        this.CurrSelectedPatternColorID = nID;
        flash.external.ExternalInterface.call("ChangePatternColorSelection",nID);
    }
    function OnPhongActivate()
    {
        this.SetNewFocus(screens.MPAppearance.MPAppearance.SELECTED_FIELD_MENU);
        if(flash.external.ExternalInterface.call("GetPhongState") != screens.MPAppearance.AppearanceMenuList.APPEARANCE_ITEM_DISABLED)
        {
            var _loc2_ = Number(flash.external.ExternalInterface.call("GetSelectedPhongID"));
            this.CurrSelectedPhongID = _loc2_;
            this.ChangeItemCallback = this.MakeDelegate(this.OnPhongChange);
            this.ChangeItemEnd = this.MakeDelegate(this.OnPhongEnd);
            this.ConfirmItemCallback = this.MakeDelegate(this.OnPhongConfirm);
            this.SetupTintPanel(com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetPhongSwatchData")),_loc2_);
        }
        this.RefreshActionButtonStates();
    }
    function OnPhongChange(nID)
    {
        flash.external.ExternalInterface.call("ChangePawnPhong",nID);
    }
    function OnPhongEnd()
    {
        flash.external.ExternalInterface.call("ChangePawnPhong",this.CurrSelectedPhongID);
    }
    function OnPhongConfirm(nID)
    {
        this.CurrSelectedPhongID = nID;
        flash.external.ExternalInterface.call("ChangePhongSelection",nID);
    }
    function OnEmissiveActivate()
    {
        this.SetNewFocus(screens.MPAppearance.MPAppearance.SELECTED_FIELD_MENU);
        if(flash.external.ExternalInterface.call("GetEmissiveState") != screens.MPAppearance.AppearanceMenuList.APPEARANCE_ITEM_DISABLED)
        {
            var _loc2_ = Number(flash.external.ExternalInterface.call("GetSelectedEmissiveID"));
            this.CurrSelectedEmissiveID = _loc2_;
            this.ChangeItemCallback = this.MakeDelegate(this.OnEmissiveChange);
            this.ChangeItemEnd = this.MakeDelegate(this.OnEmissiveEnd);
            this.ConfirmItemCallback = this.MakeDelegate(this.OnEmissiveConfirm);
            this.SetupTintPanel(com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetEmissiveSwatchData")),_loc2_);
        }
        this.RefreshActionButtonStates();
    }
    function OnEmissiveChange(nID)
    {
        flash.external.ExternalInterface.call("ChangePawnEmissive",nID);
    }
    function OnEmissiveEnd()
    {
        flash.external.ExternalInterface.call("ChangePawnEmissive",this.CurrSelectedEmissiveID);
    }
    function OnEmissiveConfirm(nID)
    {
        this.CurrSelectedEmissiveID = nID;
        flash.external.ExternalInterface.call("ChangeEmissiveSelection",nID);
    }
    function OnSkinToneActivate()
    {
        this.SetNewFocus(screens.MPAppearance.MPAppearance.SELECTED_FIELD_MENU);
        if(flash.external.ExternalInterface.call("GetSkinToneState") != screens.MPAppearance.AppearanceMenuList.APPEARANCE_ITEM_DISABLED)
        {
            var _loc2_ = Number(flash.external.ExternalInterface.call("GetSelectedSkinToneID"));
            this.CurrSelectedSkinToneID = _loc2_;
            this.ChangeItemCallback = this.MakeDelegate(this.OnSkinToneChange);
            this.ChangeItemEnd = this.MakeDelegate(this.OnSkinToneEnd);
            this.ConfirmItemCallback = this.MakeDelegate(this.OnSkinToneConfirm);
            this.SetupTintPanel(com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetSkinToneSwatchData")),_loc2_);
        }
        this.RefreshActionButtonStates();
    }
    function OnSkinToneChange(nID)
    {
        flash.external.ExternalInterface.call("ChangePawnSkinTone",nID);
    }
    function OnSkinToneEnd()
    {
        flash.external.ExternalInterface.call("ChangePawnSkinTone",this.CurrSelectedSkinToneID);
    }
    function OnSkinToneConfirm(nID)
    {
        this.CurrSelectedSkinToneID = nID;
        flash.external.ExternalInterface.call("ChangeSkinToneSelection",nID);
    }
    function OnConfirmSelect()
    {
        this.SetNewFocus(screens.MPAppearance.MPAppearance.SELECTED_FIELD_MENU);
        this.HidePanels();
        this.Message._visible = false;
        this.RefreshActionButtonStates();
    }
    function OnConfirmActivate()
    {
        flash.external.ExternalInterface.call("SetCharacterName",this.playerInfo.characterName.name.text);
        flash.external.ExternalInterface.call("ConfirmButtonPressed");
    }
    function SetupTintPanel(ColorData, nInitialID)
    {
        this.SelectedField = screens.MPAppearance.MPAppearance.SELECTED_FIELD_TINTS;
        this.PatternMenu._visible = false;
        this.TintPanel._visible = true;
        this.Message._visible = false;
        this.TintPanel.InitializeSwatches(ColorData);
        this.TintPanel.SelectInitialSwatch(nInitialID);
        this.Scrollbar._visible = this.TintPanel.length > this.TintPanel.NUM_VISIBLE;
    }
    function SetupPatternPanel(PatternData, nInitialID)
    {
        this.SelectedField = screens.MPAppearance.MPAppearance.SELECTED_FIELD_PATTERNS;
        this.PatternMenu._visible = true;
        this.TintPanel._visible = false;
        this.Message._visible = false;
        this.PatternMenu.killMenu();
        var _loc4_ = -1;
        var _loc2_ = 0;
        while(_loc2_ < PatternData.length)
        {
            if(PatternData[_loc2_].PatternID == nInitialID)
            {
                _loc4_ = _loc2_;
            }
            this.PatternMenu.AddNewItem("$" + PatternData[_loc2_].PatternName,PatternData[_loc2_].PatternID);
            _loc2_ = _loc2_ + 1;
        }
        this.PatternMenu.SetSelectedCallback(this.MakeDelegate(this.OnPatternSelected));
        this.PatternMenu.SetActivatedCallback(this.MakeDelegate(this.OnPatternActivated));
        this.PatternMenu.SetHoveredCallback(this.MakeDelegate(this.OnPatternHovered));
        this.PatternMenu.SetHoveredEndCallback(this.MakeDelegate(this.OnPatternHoveredEnd));
        this.PatternMenu.selectedIndex = _loc4_;
        this.Scrollbar._visible = this.PatternMenu.length > this.PatternMenu.NUM_VISIBLE;
    }
    function OnPatternHovered(nID)
    {
        this.SetNewFocus(screens.MPAppearance.MPAppearance.SELECTED_FIELD_PATTERNS);
        flash.external.ExternalInterface.call("ChangePawnPattern",nID);
    }
    function OnPatternHoveredEnd()
    {
        flash.external.ExternalInterface.call("ChangePawnPattern",this.CurrSelectedPatternID);
    }
    function OnPatternSelected(nID)
    {
        this.SetNewFocus(screens.MPAppearance.MPAppearance.SELECTED_FIELD_PATTERNS);
		// MILAN CHANGE DropTheSquid 12/12/2023
		// this would only fire for non PC layout, which prevented controller users from previewing the changes
		flash.external.ExternalInterface.call("ChangePawnPattern",nID);
        // END MILAN
        this.CurrSelectedPatternID = nID;
        flash.external.ExternalInterface.call("ChangePatternSelection",nID);
    }
    function OnPatternActivated(nID, nIndex)
    {
        this.PatternMenu.selectedIndex = nIndex;
    }
    function RefreshCurrentMenuItem()
    {
        if(this.SelectedField != screens.MPAppearance.MPAppearance.SELECTED_FIELD_NAME)
        {
            if(_global.SFX.Platform == com.XPlatform.PC || this.SelectedField != screens.MPAppearance.MPAppearance.SELECTED_FIELD_MENU)
            {
                this.AppearanceMenu.selectedItem.Activate();
            }
        }
        else
        {
            this.ClearAppearanceMenuItem();
            this.AppearanceMenu.unselectAllItems();
        }
    }
    function onInvalidInput()
    {
        _global.SFX.PlayGUIError();
    }
    function onDPadUp(p_event)
    {
        if(this.SelectedField != screens.MPAppearance.MPAppearance.SELECTED_FIELD_NAME)
        {
            if(this.SelectedField == screens.MPAppearance.MPAppearance.SELECTED_FIELD_TINTS)
            {
                if(!this.TintPanel.MoveHoveredSelectionUp())
                {
                    _global.SFX.PlayGUIError();
                }
            }
            else if(this.SelectedField == screens.MPAppearance.MPAppearance.SELECTED_FIELD_PATTERNS)
            {
                if(this.PatternMenu.selectedIndex > 0)
                {
                    this.PatternMenu.selectedIndex -= 1;
                }
                else
                {
                    _global.SFX.PlayGUIError();
                }
            }
            else if(this.SelectedField == screens.MPAppearance.MPAppearance.SELECTED_FIELD_MENU)
            {
                if(this.AppearanceMenu.selectedIndex == 0)
                {
                    this.SelectedField = screens.MPAppearance.MPAppearance.SELECTED_FIELD_NAME;
                    this.playerInfo.characterName.gotoAndStop("focused");
                    if(_global.SFX.Platform == com.XPlatform.PC)
                    {
                        Selection.setFocus(this.playerInfo.characterName.name);
                    }
                    this.ClearAppearanceMenuItem();
                }
                else
                {
                    this.AppearanceMenu.selectedIndex -= 1;
                }
            }
        }
        else
        {
            _global.SFX.PlayGUIError();
        }
        this.RefreshActionButtonStates();
    }
    function onDPadDown(p_event)
    {
        if(this.SelectedField == screens.MPAppearance.MPAppearance.SELECTED_FIELD_NAME)
        {
            if(_global.SFX.Platform == com.XPlatform.PC)
            {
                Selection.setFocus(null);
            }
            this.playerInfo.characterName.gotoAndStop("normal");
            this.SelectedField = screens.MPAppearance.MPAppearance.SELECTED_FIELD_MENU;
            this.AppearanceMenu.selectedIndex = 0;
        }
        else if(this.SelectedField == screens.MPAppearance.MPAppearance.SELECTED_FIELD_MENU)
        {
            if(this.AppearanceMenu.selectedIndex < this.AppearanceMenu.length - 1)
            {
                this.AppearanceMenu.selectedIndex += 1;
            }
            else
            {
                _global.SFX.PlayGUIError();
            }
        }
        else if(this.SelectedField == screens.MPAppearance.MPAppearance.SELECTED_FIELD_TINTS)
        {
            if(!this.TintPanel.MoveHoveredSelectionDown())
            {
                _global.SFX.PlayGUIError();
            }
        }
        else if(this.SelectedField == screens.MPAppearance.MPAppearance.SELECTED_FIELD_PATTERNS)
        {
            if(this.PatternMenu.selectedIndex < this.PatternMenu.length - 1)
            {
                this.PatternMenu.selectedIndex += 1;
            }
            else
            {
                _global.SFX.PlayGUIError();
            }
        }
        this.RefreshActionButtonStates();
    }
    function onDPadLeft(p_event)
    {
        if(this.SelectedField == screens.MPAppearance.MPAppearance.SELECTED_FIELD_TINTS)
        {
            if(!this.TintPanel.MoveHoveredSelectionLeft())
            {
                _global.SFX.PlayGUIError();
            }
        }
        else
        {
            _global.SFX.PlayGUIError();
        }
    }
    function onDPadRight(p_event)
    {
        if(this.SelectedField == screens.MPAppearance.MPAppearance.SELECTED_FIELD_TINTS)
        {
            if(!this.TintPanel.MoveHoveredSelectionRight())
            {
                _global.SFX.PlayGUIError();
            }
        }
        else
        {
            _global.SFX.PlayGUIError();
        }
    }
    function OnResetButtonPressed()
    {
        flash.external.ExternalInterface.call("ResetScreenInfo");
    }
    function OnSelectButtonPressed()
    {
		// MILAN CHANGE DropTeheSquid 12/12/2023
		// removed some PC specific handling that was always executing. I have already fixed the PC handler
		if(this.SelectedField == screens.MPAppearance.MPAppearance.SELECTED_FIELD_NAME)
		// END MILAN
        {
			// TODO pretty sure this doesn't actually do anything, as it was stripped out of PC release or relied on console APIs
            flash.external.ExternalInterface.call("ShowKeyboard");
        }
        else if(this.SelectedField == screens.MPAppearance.MPAppearance.SELECTED_FIELD_MENU)
        {
            this.SelectedField = this.SelectedRightField;
            this.RefreshActionButtonStates();
            this.AppearanceMenu.selectedItem.Activate();
        }
        else if(this.SelectedField == screens.MPAppearance.MPAppearance.SELECTED_FIELD_TINTS || this.SelectedField == screens.MPAppearance.MPAppearance.SELECTED_FIELD_PATTERNS)
        {
            this.SelectedField = screens.MPAppearance.MPAppearance.SELECTED_FIELD_MENU;
            this.RefreshActionButtonStates();
            this.HidePanels();
        }
    }
    function OnBackButtonPressed()
    {
        flash.external.ExternalInterface.call("BackButtonPressed");
    }
    function OnNameMouseClick(p_event)
    {
        _global.SFX.PlayGUISound("MPAppearanceNameClick");
        this.SelectedField = screens.MPAppearance.MPAppearance.SELECTED_FIELD_NAME;
        Selection.setFocus(this.playerInfo.characterName.name);
        Selection.setSelection(0,this.playerInfo.characterName.name.text.length);
        this.ClearAppearanceMenuItem();
    }
    function onKeyDown()
    {
    }
    function onKeyUp()
    {
        flash.external.ExternalInterface.call("SetCharacterName",this.playerInfo.characterName.name.text);
        if(Key.getCode() == 13)
        {
            this.SetNewFocus(screens.MPAppearance.MPAppearance.SELECTED_FIELD_NONE);
        }
    }
    function onSetFocus(oldFocus, newFocus)
    {
        if(_global.SFX.Platform == com.XPlatform.PC)
        {
            if(oldFocus != this.playerInfo.characterName.name && newFocus == this.playerInfo.characterName.name)
            {
                flash.external.ExternalInterface.call("StartHandlingKeyPresses");
                this.playerInfo.characterName.gotoAndStop("focused");
            }
            else if(oldFocus == this.playerInfo.characterName.name && newFocus != this.playerInfo.characterName.name)
            {
                flash.external.ExternalInterface.call("StopHandlingKeyPresses");
                this.playerInfo.characterName.gotoAndStop("normal");
            }
        }
    }
    function ResetToLastTintSelection()
    {
        flash.external.ExternalInterface.call("ResetPawnToLastSelection");
    }
    function OnSwatchSelected(nID)
    {
        this.SetNewFocus(screens.MPAppearance.MPAppearance.SELECTED_FIELD_TINTS);
        this.ConfirmItemCallback(nID);
    }
    function OnSwatchHovered(nID)
    {
        this.SetNewFocus(screens.MPAppearance.MPAppearance.SELECTED_FIELD_TINTS);
        this.ChangeItemCallback(nID);
    }
    function OnSwatchHoveredEnd(nID)
    {
        this.ChangeItemEnd();
    }
    function InitializeNameField()
    {
        this.playerInfo.characterName.name.textAutoSize = "fit";
        if(_global.SFX.Platform == com.XPlatform.PC)
        {
            this.playerInfo.characterName.name.enabled = true;
            Selection.setFocus(this.playerInfo.characterName.name);
            this.playerInfo.characterName.onPress = this.MakeDelegate(this.OnNameMouseClick);
            this.playerInfo.characterName.onRollOver = this.MakeDelegate(this.OnNameRollOver);
            this.playerInfo.characterName.onRollOut = this.MakeDelegate(this.OnNameRollOut);
        }
        this.playerInfo.characterName.gotoAndStop("focused");
        this.playerInfo.characterName.name.maxChars = Number(flash.external.ExternalInterface.call("GetMaxCharacterNameLength"));
        this.playerInfo.characterName.name.restrict = this.RESTRICTED_CHARACTERS;
    }
    function OnNameRollOver()
    {
        this.playerInfo.characterName.gotoAndStop("focused");
    }
    function OnNameRollOut()
    {
        if(Selection.getFocus() != this.playerInfo.characterName.name)
        {
            this.playerInfo.characterName.gotoAndStop("normal");
        }
    }
    function RefreshCharacterData()
    {
        this.RefreshCharacterName(String(flash.external.ExternalInterface.call("GetSelectedCharacterName")));
        this.playerInfo.levelAndClass.text = String(flash.external.ExternalInterface.call("GetSelectedCharacterClassAndLevel"));
        this.playerInfo.kit.text = String(flash.external.ExternalInterface.call("GetSelectedKitName"));
    }
    function RefreshCharacterName(NewName)
    {
        this.playerInfo.characterName.name.text = NewName;
    }
    function SetNewFocus(NewFocusedField)
    {
        if(this.SelectedField != NewFocusedField)
        {
            if(_global.SFX.Platform == com.XPlatform.PC)
            {
                this.SelectedField = NewFocusedField;
            }
            Selection.setFocus(null);
        }
    }
    function RefreshActionButtonStates()
    {
        var _loc3_ = Boolean(flash.external.ExternalInterface.call("IsInDeployFlow"));
		// MILAN CHANGE DropTheSquid 12/12/2023
		// this was conditioned on it not being PC platform. It now always runs this. the visibility is controlled elsewhere
		switch(this.SelectedField)
		{
			case screens.MPAppearance.MPAppearance.SELECTED_FIELD_TINTS:
			case screens.MPAppearance.MPAppearance.SELECTED_FIELD_PATTERNS:
				this.m_ControllerButtons.ControlA.SetEnabled(true);
				this.m_ControllerButtons.ControlB.SetText(this.srBack);
				this.m_ControllerButtons.ControlB.SetEnabled(false);
				break;
			case screens.MPAppearance.MPAppearance.SELECTED_FIELD_NAME:
				this.m_ControllerButtons.ControlA.SetEnabled(true);
				this.m_ControllerButtons.ControlB.SetText(!_loc3_ ? this.srBack : this.srCancel);
				this.m_ControllerButtons.ControlB.SetEnabled(true);
				break;
			case screens.MPAppearance.MPAppearance.SELECTED_FIELD_MENU:
				this.m_ControllerButtons.ControlA.SetEnabled(this.AppearanceMenu.selectedItem.IsEnabled());
				this.m_ControllerButtons.ControlB.SetText(!_loc3_ ? this.srBack : this.srCancel);
				this.m_ControllerButtons.ControlB.SetEnabled(true);
		}
    }
    function ClearAppearanceMenuItem()
    {
        this.AppearanceMenu.selectedItem.active = false;
        this.HidePanels();
        this.AppearanceMenu.unselectAllItems();
    }
    function HidePanels()
    {
        this.Scrollbar._visible = false;
        this.TintPanel._visible = false;
        this.PatternMenu._visible = false;
    }
    function SetFocusToNameField()
    {
        this.ClearAppearanceMenuItem();
        this.SelectedField = screens.MPAppearance.MPAppearance.SELECTED_FIELD_NAME;
        Selection.setFocus(this.playerInfo.characterName.name);
    }
	// MILAN CHANGE DropTheSquid 12/12/2023
	// added this new method which takes all the button visibility code from RefreshButtons
	// and makes it reusable (not just run once at init) so we can switch dynamically
    function RefreshButtonHelp(usingGamepad)
    {
		var bIsInDeployFlow = Boolean(flash.external.ExternalInterface.call("IsInDeployFlow"));
		if(!usingGamepad)
        {
			this.m_ControllerButtons._visible = false;
            this.rightStick._visible = false;
			this.rightStickPC._visible = true;
			this.m_PCResetButton._visible = !bIsInDeployFlow;
            this.m_PCResetButton.enabled = !bIsInDeployFlow;
            this.m_PCBackButton._visible = !bIsInDeployFlow;
            this.m_PCBackButton.enabled = !bIsInDeployFlow;
            this.m_PCResetButton_Deploy._visible = bIsInDeployFlow;
            this.m_PCResetButton_Deploy.enabled = bIsInDeployFlow;
            this.m_PCBackButton_Deploy._visible = bIsInDeployFlow;
            this.m_PCBackButton_Deploy.enabled = bIsInDeployFlow;
            this.m_PCConfirmButton_Deploy._visible = bIsInDeployFlow;
            this.m_PCConfirmButton_Deploy.enabled = bIsInDeployFlow;
			// removes the "confirm" item at the end of the list
			if (this.confirmMenuItem)
			{
				if (this.AppearanceMenu.selectedIndex == this.confirmMenuItem.m_nIndex)
				{
					this.AppearanceMenu.selectedIndex = -1;
				}
				this.AppearanceMenu.removeLastItem();
				this.confirmMenuItem = undefined;
			}
        }
        else
        {
			this.m_PCResetButton._visible = false;
            this.m_PCResetButton.enabled = false;
            this.m_PCBackButton._visible = false;
            this.m_PCBackButton.enabled = false;
            this.m_PCResetButton_Deploy._visible = false;
            this.m_PCResetButton_Deploy.enabled = false;
            this.m_PCBackButton_Deploy._visible = false;
            this.m_PCBackButton_Deploy.enabled = false;
            this.m_PCConfirmButton_Deploy._visible = false;
            this.m_PCConfirmButton_Deploy.enabled = false;
            this.rightStickPC._visible = false;
			this.rightStick._visible = true;
            this.m_ControllerButtons._visible = true;
            this.m_ControllerButtons.ControlY.Active = false;
            this.m_ControllerButtons.ControlY._visible = false;
			this.m_ControllerButtons.FitLeft();
			// make sure the list is loaded before we try to add things or it breaks the UI
			// also make sure we don't add it twice
			if (this.AppearanceMenu.IsLoaded() && !this.confirmMenuItem)
			{
				// add the "confirm" item to the end of the list
				this.confirmMenuItem = this.AppearanceMenu.AddNewItem(this.srConfirm,screens.MPAppearance.AppearanceMenuList.APPEARANCE_ITEM_NORMAL,this.srNew,this.MakeDelegate(this.OnConfirmSelect),this.MakeDelegate(this.OnConfirmActivate));
			}
			
        }
    }
    // END MILAN
}
