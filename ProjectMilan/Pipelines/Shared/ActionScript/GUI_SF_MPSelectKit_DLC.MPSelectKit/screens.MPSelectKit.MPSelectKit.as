// This does not get automatically compiled into the build. It is only included for documentation and a building point for further changes
// we can include comments and more intuitive syntax without it going through the compiler/decompiler cycle of JPEXS
class screens.MPSelectKit.MPSelectKit extends com.SFXScreen
{
    var m_PromotionEvents;
    var m_PromotionBackground;
    var m_ProcessPromoteEventsCallback;
    var RightArrow;
    var LeftArrow;
    var m_ClassList;
    var m_ClassDataList;
    var m_KitDataList;
    var m_KitPanel;
    var XPBar;
    var m_ControllerButtons;
    var m_PCBackButton;
    var m_PCPromoteButton;
	    var PCInfoButton;
    var Titlebar;
    var srSelectKit = "NOLOC:Select Kit";
    var srBack = "NOLOC:Back";
    var srSelect = "NOLOC:Select";
    var srLocked = "NOLOC:Locked";
    var srNew = "NOLOC:New";
    var srReinforcements = "NOLOC:Reinforcements";
    var srPromote = "NOLOC:Promote";
    var srDeploy = "NOLOC:Deploy";
    var srTeamPromoted = "NOLOC:Team Promoted";
    var srExitMultiplayer = "NOLOC:Exit Multiplayer";
    var srLevelUp = "NOLOC:Level Up";
    var srCharacterInfo = "NOLOC:Character Info";
    var m_bSetKitSelection = true;
    var m_PromotionEventList = new Array();
    // MILAN CHANGE DropTheSquid 12/12/2023
	// adding variables to be accessed from the KitPanelItem class
    var bUsingGamepad;
    var currentKitPanelItem;
	var bIgnoreMouseHover;
    // END MILAN
    static var PROMOTION_BACKGROUND_FADEOUT_FRAME = "fadeOut";
	// MILAN CHANGE DropTheSquid 12/19/2023
	// added for debugging purposes
	function LogFromAS()
	{
		// takes any number of args
		var concatArgs = "";
		var i = 0;
		for (i = 0; i < arguments.length; i++)
		{
			if (concatArgs == "")
			{
				concatArgs = arguments[i].toString();
			}
			else
			{
				concatArgs = concatArgs + "," + arguments[i].toString();
			}
		}
		flash.external.ExternalInterface.call("LogFromAS", concatArgs);
	}
	// END MILAN
    function MPSelectKit()
    {
        super();
    }
    function onLoad()
    {
        super.onLoad();
        this.InitializeLocalization();
        this.SetupButtons();
		// MILAN CHANGE DropTheSquid 1/1/2024
		// calling the new setup method
		this.SetupMouse();
		// END MILAN
        this.m_PromotionEvents = _root.PromotionEvents;
        this.m_PromotionBackground = _root.PromotionBackground;
        this.m_PromotionBackground._visible = false;
        this.m_ProcessPromoteEventsCallback = this.MakeDelegate(this.ProcessPromotionEvents);
    }
	// MILAN CHANGE DropTheSquid 1/1/2024
	// adding a mouse listener so we can better distinguish mouse/keyboard input modes, and so we can handle scroll wheel events. 
	function SetupMouse()
	{
		var mouseListener = new Object();
		mouseListener.onMouseMove = function () {
			_root.screen.bIgnoreMouseHover = false;
		};
		mouseListener.onMouseWheel = function(delta, scrollTarget) {
			// this counts as a mouse action and we want things to react to the mouse over them
			_root.screen.bIgnoreMouseHover = false;
			// scrolling "down"
			if (delta < 0)
			{
				// if there is room to scroll, do so to the right
				if (_root.screen.m_KitPanel.HasItemsOffBottom())
				{
					_root.screen.m_KitPanel.movementRefElementIndex++;
				}
			}
			// scrolling "up"
			else
			{
				// if there is room to scroll, do so to the left
				if (_root.screen.m_KitPanel.HasItemsOffTop())
				{
					_root.screen.m_KitPanel.movementRefElementIndex--;
				}
			}
			// make sure the arrow states are updated after scrolling
			_root.screen.RefreshArrowStates();
		}
		Mouse.addListener(mouseListener);
	}
	// END MILAN
    function InitializeLocalization()
    {
        this.srSelectKit = "$" + _global.SFX.GetIniString("srSelectKit");
        this.srBack = "$" + _global.SFX.GetIniString("srBack");
        this.srSelect = "$" + _global.SFX.GetIniString("srSelect");
        this.srLocked = "$" + _global.SFX.GetIniString("srLocked");
        this.srNew = "$" + _global.SFX.GetIniString("srNew");
        this.srPromote = "$" + _global.SFX.GetIniString("srPromote");
        this.srDeploy = "$" + _global.SFX.GetIniString("srDeploy");
        this.srTeamPromoted = "$" + _global.SFX.GetIniString("srTeamPromoted");
        this.srExitMultiplayer = "$" + _global.SFX.GetIniString("srExitMultiplayer");
        this.srLevelUp = "$" + _global.SFX.GetIniString("srLevelUp");
		this.srCharacterInfo = "$" + _global.SFX.GetIniString("srcharacterinfo");
    }
    function InitializeScreen()
    {
        this.m_bSetKitSelection = true;
        this.RebuildClassList();
        this.RightArrow.addEventListener("ArrowPressed",mx.utils.Delegate.create(this,this.OnRightArrowPressed));
        this.LeftArrow.addEventListener("ArrowPressed",mx.utils.Delegate.create(this,this.OnLeftArrowPressed));
        this.RefreshScreen();
        this.m_bSetKitSelection = false;
        _root.gotoAndStop(2);
    }
    function RebuildClassList()
    {
        this.m_ClassList.killMenu();
        this.m_ClassDataList = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetClassData"));
        var _loc2_ = undefined;
        var _loc3_ = 0;
        while(_loc3_ < this.m_ClassDataList.length)
        {
            _loc2_ = screens.MPSelectKit.ClassListItem(this.m_ClassList.addListEntry(_loc3_,{index:_loc3_}));
            _loc2_.addEventListener("VListItem_DoAction",mx.utils.Delegate.create(this,this.OnPromote));
            _loc3_ += 1;
        }
        this.m_ClassList.addEventListener("onChange",mx.utils.Delegate.create(this,this.OnClassListItemSelected));
        var _loc4_ = String(flash.external.ExternalInterface.call("GetSelectedCharacterClass"));
        var _loc5_ = this.FindClassIndex(_loc4_);
        if(_loc5_ < 0)
        {
            _loc5_ = 0;
        }
        this.m_ClassList.selectedIndex = _loc5_;
    }
    function RefreshClassList()
    {
        this.m_ClassDataList = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetClassData"));
        var _loc2_ = undefined;
        var _loc3_ = 0;
        while(_loc3_ < this.m_ClassDataList.length)
        {
            _loc2_ = screens.MPSelectKit.ClassListItem(this.m_ClassList.getListItem(_loc3_));
            _loc2_.SetClassName(this.m_ClassDataList[_loc3_].DisplayName);
            _loc2_.SetClassLevel(this.m_ClassDataList[_loc3_].CurrentLevelText);
            _loc2_.SetPromotions(this.m_ClassDataList[_loc3_].NumPromotions);
            _loc2_.SetNewClass(this.m_ClassDataList[_loc3_].bHasNewKit);
            if(this.m_ClassDataList[_loc3_].bCanPromote)
            {
                _loc2_.IconState = screens.MPSelectKit.ClassListItem.ICON_STATE_PROMOTE;
            }
            else if(this.m_ClassDataList[_loc3_].bCanLevelKit)
            {
                _loc2_.IconState = screens.MPSelectKit.ClassListItem.ICON_STATE_LEVELUP;
            }
            else
            {
                _loc2_.IconState = screens.MPSelectKit.ClassListItem.ICON_STATE_NONE;
            }
            _loc3_ += 1;
        }
    }
    function RefreshKitList()
    {
        var _loc2_ = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetKitData",this.m_ClassDataList[this.m_ClassList.selectedIndex].Name));
        this.m_KitDataList = new Array();
        var _loc3_ = undefined;
        var _loc4_ = 0;
        while(_loc4_ < _loc2_.length)
        {
            _loc3_ = screens.MPSelectKit.KitPanelItem(this.m_KitPanel.getListItem(_loc4_));
            _loc3_.KitName.Text.textAutoSize = "shrink";
            _loc3_.KitName.Text.text = _loc2_[_loc4_].KitDisplayName;
            _loc3_.CharacterName.textAutoSize = "shrink";
            _loc3_.CharacterName.text = _loc2_[_loc4_].CharacterName;
            _loc3_.SetPowerIcon1(_loc2_[_loc4_].PowerIconResource,_loc2_[_loc4_].PowerIcon1,_loc2_[_loc4_].PowerDescription1);
            _loc3_.SetPowerIcon2(_loc2_[_loc4_].PowerIconResource,_loc2_[_loc4_].PowerIcon2,_loc2_[_loc4_].PowerDescription2);
            _loc3_.SetPowerIcon3(_loc2_[_loc4_].PowerIconResource,_loc2_[_loc4_].PowerIcon3,_loc2_[_loc4_].PowerDescription3);
            if(!_loc2_[_loc4_].bDeployed)
            {
                if(_loc2_[_loc4_].bLocked)
                {
                    _loc3_.IconState = screens.MPSelectKit.KitPanelItem.ICON_STATE_LOCKED;
                }
                else
                {
                    _loc3_.IconState = screens.MPSelectKit.KitPanelItem.ICON_STATE_UNDEPLOYED;
                }
            }
            else if(_loc2_[_loc4_].bNeedsLevelUp)
            {
                _loc3_.IconState = screens.MPSelectKit.KitPanelItem.ICON_STATE_LEVELUP;
            }
            else
            {
                _loc3_.IconState = screens.MPSelectKit.KitPanelItem.ICON_STATE_NONE;
            }
            if(_loc2_[_loc4_].bLocked)
            {
                _loc3_.SetCharacterImageReference(_loc2_[_loc4_].LockedTextureReference);
            }
            else
            {
                _loc3_.SetCharacterImageReference(_loc2_[_loc4_].TextureReference);
            }
            this.m_KitDataList.push(_loc2_[_loc4_]);
            _loc4_ += 1;
        }
        var _loc5_ = 0;
        if(this.m_bSetKitSelection)
        {
            var _loc6_ = String(flash.external.ExternalInterface.call("GetSelectedCharacterKit"));
            _loc5_ = this.FindKitIndex(_loc6_);
            if(_loc5_ < 0)
            {
                _loc5_ = 0;
            }
        }
        this.m_KitPanel.movementRefElementIndex = Math.max(0,_loc5_ - this.m_KitPanel.NUM_VISIBLE + 1);
        this.m_KitPanel.selectedIndex = _loc5_;
    }
    function RefreshXPBar()
    {
        this.XPBar.gotoAndStop(this.m_ClassDataList[this.m_ClassList.selectedIndex].XPPercentage + 1);
        this.XPBar.XpTotal.XPText.text = this.m_ClassDataList[this.m_ClassList.selectedIndex].NextLevelXPString;
        this.XPBar.XPCurrent.XPTextCurrent.text = this.m_ClassDataList[this.m_ClassList.selectedIndex].CurrentXPString;
    }
    function RebuildKitList()
    {
        this.m_KitPanel.killMenu();
        var _loc2_ = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetKitData",this.m_ClassDataList[this.m_ClassList.selectedIndex].Name));
        var _loc3_ = undefined;
        var _loc4_ = 0;
        while(_loc4_ < _loc2_.length)
        {
            _loc3_ = screens.MPSelectKit.KitPanelItem(this.m_KitPanel.addListEntry(_loc4_,{index:_loc4_}));
            _loc3_.addEventListener("VListItem_DoAction",mx.utils.Delegate.create(this,this.OnSelect));
            _loc4_ += 1;
        }
        this.m_KitPanel.addEventListener("onChange",mx.utils.Delegate.create(this,this.OnListChanged));
    }
    function OnClassListItemSelected()
    {
        this.RebuildKitList();
        this.RefreshKitList();
        this.RefreshXPBar();
        this.RefreshButtons();
    }
    function SetupButtons()
    {
        this.m_ControllerButtons = _root.mcControllerButtons;
        this.m_PCBackButton = _root.mcBackButton;
        this.m_PCPromoteButton = _root.mcPromoteButton;
        // MILAN CHANGE DropTheSquid 12/12/2023
		// previously, this branched on Platform and set up either the PC buttons or the controller buttons
		// it both set up handlers and set visibility
		// now, it only sets up handlers here (one time) for both input modes
		// and then calls the new RefreshButtonHelp method to set visibility
        this.m_PCBackButton.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.OnBack));
        this.m_PCPromoteButton.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.OnPromote));
		this.PCInfoButton.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.OnShowCharacterInfo));

        this.m_ControllerButtons.addEventListener("onButtonA",this.MakeDelegate(this.OnSelect));
        this.m_ControllerButtons.addEventListener("onButtonB",this.MakeDelegate(this.OnBack));
        this.m_ControllerButtons.addEventListener("onButtonX",this.MakeDelegate(this.OnPromote));
        this.m_ControllerButtons.addEventListener("onButtonY",this.MakeDelegate(this.OnShowCharacterInfo));
        this.m_ControllerButtons.addEventListener("onDPadLeft",this.MakeDelegate(this.OnDPadLeft));
        this.m_ControllerButtons.addEventListener("onDPadRight",this.MakeDelegate(this.OnDPadRight));
        this.m_ControllerButtons.addEventListener("onDPadUp",this.MakeDelegate(this.OnDPadUp));
        this.m_ControllerButtons.addEventListener("onDPadDown",this.MakeDelegate(this.OnDPadDown));
        this.m_ControllerButtons.addEventListener("onInvalidInput",this.MakeDelegate(this.OnInvalidInput));
        this.RefreshButtonHelp(flash.external.ExternalInterface.call("IsUsingGamepad"));
		// END MILAN
        this.RefreshButtons();
    }
    function RefreshScreen()
    {
        this.Titlebar.text = this.srSelectKit;
        this.RefreshClassList();
        this.RefreshKitList();
        this.RefreshXPBar();
        this.RefreshButtons();
        this.RefreshArrowStates();
    }
    function RefreshButtons()
    {
        var _loc3_ = Boolean(flash.external.ExternalInterface.call("BackWillExitMultiplayer"));
        // MILAN CHANGE DroipTheSquid 12/12/2023
        // previously this branched on Platform and set up either the PC buttons or the controller buttons
		// now it unconditionally updates the text and position of both
		// the visibility is controller elsewhere

		// update PC buttons
        this.m_PCBackButton.text = !_loc3_ ? this.srBack : this.srExitMultiplayer;
        this.m_PCPromoteButton.text = this.srPromote;
        this.m_PCPromoteButton.SetEnabled(this.m_ClassDataList[this.m_ClassList.selectedIndex].bCanPromote);
        // update controller buttons
        this.m_ControllerButtons.ControlB.text = !_loc3_ ? this.srBack : this.srExitMultiplayer;
        if(this.m_KitDataList[this.m_KitPanel.selectedIndex].bDeployed)
        {
            this.m_ControllerButtons.ControlA.text = this.srSelect;
        }
        else
        {
            this.m_ControllerButtons.ControlA.text = this.srDeploy;
        }
        this.m_ControllerButtons.ControlA.Active = !this.m_KitDataList[this.m_KitPanel.selectedIndex].bLocked;
        this.m_ControllerButtons.ControlX.Active = this.m_ClassDataList[this.m_ClassList.selectedIndex].bCanPromote;
        this.m_ControllerButtons.ControlX.text = this.srPromote;
        this.m_ControllerButtons.ControlY.Active = true;
        this.m_ControllerButtons.ControlY.text = this.srCharacterInfo;
        // END MILAN
        this.RefreshBackButton();
        this.RefreshArrowStates();
    }
    function RefreshArrowStates()
    {
        this.RightArrow._visible = this.m_KitPanel.HasItemsOffBottom();
        this.LeftArrow._visible = this.m_KitPanel.HasItemsOffTop();
    }
    function OnInvalidInput()
    {
        _global.SFX.PlayGUIError();
    }
    function OnRightArrowPressed()
    {
        if(this.m_KitPanel.HasItemsOffBottom())
        {
            this.m_KitPanel.movementRefElementIndex += 1;
			// MILAN CHANGE DropTheSquid 12/19/2023
			// removed a line here making the PC info button invisible, as I am now handling that better elsewhere. 
        }
        else
        {
            _global.SFX.PlayGUIError();
        }
        this.RefreshArrowStates();
    }
    function OnLeftArrowPressed()
    {
        if(this.m_KitPanel.HasItemsOffTop())
        {
            this.m_KitPanel.movementRefElementIndex -= 1;
			// MILAN CHANGE DropTheSquid 12/19/2023
			// removed a line here making the PC info button invisible, as I am now handling that better elsewhere. 
        }
        else
        {
            _global.SFX.PlayGUIError();
        }
        this.RefreshArrowStates();
    }
    function OnDPadRight()
    {
		// ignore all mouse hover events until the mouse is moved again
		this.bIgnoreMouseHover = true;
		// remove mouse highlight over things when we start doing keyboard navigation
		this.DehighlightHoverableElements();
        if(this.m_KitPanel.selectedIndex < this.m_KitPanel.length - 1)
        {
            this.m_KitPanel.selectedIndex += 1;
            _global.SFX.PlayGUISound("MPSelectKitCharacterChange");
        }
        else
        {
            _global.SFX.PlayGUIError();
        }
        this.RefreshButtons();
    }
    function OnDPadLeft()
    {
		// ignore all mouse hover events until the mouse is moved again
		this.bIgnoreMouseHover = true;
		// remove mouse highlight over things when we start doing keyboard navigation
		this.DehighlightHoverableElements();
        if(this.m_KitPanel.selectedIndex > 0)
        {
            this.m_KitPanel.selectedIndex -= 1;
            _global.SFX.PlayGUISound("MPSelectKitCharacterChange");
        }
        else
        {
            _global.SFX.PlayGUIError();
        }
        this.RefreshButtons();
    }
    function OnDPadUp()
    {
		// ignore all mouse hover events until the mouse is moved again
		this.bIgnoreMouseHover = true;
		// remove mouse highlight over things when we start doing keyboard navigation
		this.DehighlightHoverableElements();
        if(this.m_ClassList.selectedIndex > 0)
        {
            this.m_bSetKitSelection = false;
            this.m_ClassList.selectedIndex -= 1;
            this.m_bSetKitSelection = true;
            _global.SFX.PlayGUISound("MPSelectKitClassSelect");
        }
        else
        {
            _global.SFX.PlayGUIError();
        }
        this.RefreshButtons();
    }
    function OnDPadDown()
    {
		// ignore all mouse hover events until the mouse is moved again
		this.bIgnoreMouseHover = true;
		// remove mouse highlight over things when we start doing keyboard navigation
		this.DehighlightHoverableElements();
        if(this.m_ClassList.selectedIndex < this.m_ClassList.length - 1)
        {
            this.m_bSetKitSelection = false;
            this.m_ClassList.selectedIndex += 1;
            this.m_bSetKitSelection = true;
            _global.SFX.PlayGUISound("MPSelectKitClassSelect");
        }
        else
        {
            _global.SFX.PlayGUIError();
        }
        this.RefreshButtons();
    }
    function OnListChanged()
    {
        this.RefreshArrowStates();
        this.RefreshButtons();
    }
    function OnBack()
    {
        this.m_ControllerButtons.InputDisabled = true;
        flash.external.ExternalInterface.call("GoBack");
    }
    function OnSelect()
    {
        var _loc3_ = this.m_KitPanel.selectedIndex;
        if(this.m_KitDataList[_loc3_].bLocked)
        {
            _global.SFX.PlayGUIError();
        }
        else if(!this.m_KitDataList[_loc3_].bDeployed)
        {
            _global.SFX.PlayGUISound("MPSelectKitCharacterSelect");
            flash.external.ExternalInterface.call("DeployKit",this.m_KitDataList[_loc3_].KitName);
        }
        else
        {
            _global.SFX.PlayGUISound("MPSelectKitCharacterSelect");
            flash.external.ExternalInterface.call("SelectKitAndProceed",this.m_KitDataList[_loc3_].KitName);
        }
    }
    function OnPromote()
    {
        if(this.m_ClassDataList[this.m_ClassList.selectedIndex].bCanPromote)
        {
            flash.external.ExternalInterface.call("PromoteClass",this.m_ClassDataList[this.m_ClassList.selectedIndex].Name);
        }
        else
        {
            _global.SFX.PlayGUIError();
        }
    }
    function OnShowCharacterInfo()
    {
        var _loc2_ = this.m_KitPanel.selectedIndex;
        if(_loc2_ != -1 && _loc2_ < this.m_KitDataList.length)
        {
            flash.external.ExternalInterface.call("ShowCharacterInfo",this.m_KitDataList[_loc2_].KitName);
        }
    }
    function FindClassIndex(ClassName)
    {
        var _loc3_ = 0;
        while(_loc3_ < this.m_ClassDataList.length)
        {
            if(this.m_ClassDataList[_loc3_].Name == ClassName)
            {
                return _loc3_;
            }
            _loc3_ += 1;
        }
        return -1;
    }
    function FindKitIndex(KitName)
    {
        var _loc3_ = 0;
        while(_loc3_ < this.m_KitDataList.length)
        {
            if(this.m_KitDataList[_loc3_].KitName == KitName)
            {
                return _loc3_;
            }
            _loc3_ += 1;
        }
        return -1;
    }
    function onKeyDown()
    {
        switch(Key.getCode())
        {
            case com.XInput.DPadUp:
                this.OnDPadUp();
                break;
            case com.XInput.DPadDown:
                this.OnDPadDown();
                break;
            case com.XInput.DPadLeft:
                this.OnDPadLeft();
                break;
            case com.XInput.DPadRight:
                this.OnDPadRight();
                break;
            case com.XInput.ButtonA:
                this.OnSelect();
                break;
            case com.XInput.ButtonB:
                this.OnBack();
                break;
            default:
                _global.SFX.PlayGUIError();
        }
    }
    function RefreshBackButton()
    {
        // MILAN CHANGE DropTheSquid 12/12/2023
		// previously this branched on Platform to handle either mouse or controller buttons
		// now it just does both
        this.m_PCBackButton.SetEnabled(Boolean(flash.external.ExternalInterface.call("CanGoBack")));
        this.m_ControllerButtons.ControlB.SetEnabled(Boolean(flash.external.ExternalInterface.call("CanGoBack")));
        // END MILAN
    }
    function SetInputDisabled(b)
    {
        this.m_ControllerButtons.InputDisabled = b;
    }
    function StartPromotionEvent()
    {
        if(!this.m_PromotionEvents.hasEventListener("PromoteEventFinished",this.m_ProcessPromoteEventsCallback))
        {
            this.m_PromotionEvents.addEventListener("PromoteEventFinished",this.m_ProcessPromoteEventsCallback);
        }
        this.m_PromotionEventList.length = 0;
        this.m_PromotionEventList.push({ModeID:screens.MPSelectKit.PromotionEvents.EVENT_MODE_GALAXY,Text:String(flash.external.ExternalInterface.call("GetClassPromotionString"))});
        this.m_PromotionEventList.push({ModeID:screens.MPSelectKit.PromotionEvents.EVENT_MODE_N7,Text:String(flash.external.ExternalInterface.call("GetPromotionN7RatingsBoost"))});
        this.m_PromotionEventList.push({ModeID:screens.MPSelectKit.PromotionEvents.EVENT_MODE_PROMOTE,Text:this.srTeamPromoted});
        this.m_PromotionBackground._visible = this.m_PromotionEventList.length > 0;
        this.ProcessPromotionEvents();
        this.SetInputDisabled(true);
    }
    function ProcessPromotionEvents()
    {
        if(this.m_PromotionEventList.length > 0)
        {
            this.m_PromotionEvents.SetEventData(this.m_PromotionEventList[this.m_PromotionEventList.length - 1].ModeID,this.m_PromotionEventList[this.m_PromotionEventList.length - 1].Text);
            this.m_PromotionEventList.pop();
            this.m_PromotionEvents.Start();
            _global.SFX.PlayGUISound("MPSelectKitPromotionEvent");
        }
        else
        {
            this.m_PromotionBackground.gotoAndPlay(screens.MPSelectKit.MPSelectKit.PROMOTION_BACKGROUND_FADEOUT_FRAME);
            this.SetInputDisabled(false);
        }
    }
    // MILAN CHANGE DropTheSquid 12/12/2023
	// added this new method which takes all the button visibility code from RefreshButtons
	// and makes it reusable (not just run once at init) so we can switch dynamically
    function RefreshButtonHelp(usingGamepad)
    {
		// set this so KitPanelItem can use it
        this.bUsingGamepad = usingGamepad;
        if(!usingGamepad)
        {
			// hide controller buttons
            this.m_ControllerButtons._visible = false;
			// show PC buttons
            this.m_PCBackButton.SetEnabled(true);
            this.m_PCBackButton.SetVisible(true);
            this.m_PCPromoteButton.SetEnabled(true);
            this.m_PCPromoteButton.SetVisible(true);
			// make sure the PC Info button is showing correctly
            this.PCInfoButton._visible = false;
            if (this.currentKitPanelItem)
            {
                this.currentKitPanelItem.ShowPCInfoButton()
            }
        }
        else
        {
			// hide PC buttons
            this.m_PCBackButton.SetEnabled(false);
            this.m_PCBackButton.SetVisible(false);
            this.m_PCPromoteButton.SetEnabled(false);
            this.m_PCPromoteButton.SetVisible(false);
			this.PCInfoButton._visible = false;
			// show controller buttons
            this.m_ControllerButtons._visible = true;
            this.m_ControllerButtons.FitLeft();

			// ignore all mouse hover events until the mouse is moved again
			this.bIgnoreMouseHover = true;
			// remove highlight on any highlighted elements
			this.DehighlightHoverableElements();
        }
		this.RefreshButtons();
    }
	function DehighlightHoverableElements()
	{
		// stop showing the hover highlight on the arrows. The mouse off is not animated so there is no harm in calling this repeatedly or when not needed. 
		this.LeftArrow.onRollOut();
		this.RightArrow.onRollOut();
		// same thing with the class list. the hover indicator is a single frame, and only shows up with mouse. so turn it off so we don't have it still hovered under the mouse
		var classItem = undefined;
		var i = 0;
		while(i < this.m_ClassDataList.length)
		{
			classItem = screens.MPSelectKit.ClassListItem(this.m_ClassList.getListItem(i));
			classItem.onRollOut();
			i += 1;
		}
	}
    // END MILAN
}
