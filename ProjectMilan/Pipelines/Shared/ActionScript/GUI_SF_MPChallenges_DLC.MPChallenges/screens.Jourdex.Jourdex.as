// MILAN CHANGE DropTheSquid 12/16/2023
// this whole script is lifted wholesale from Jourdex to give us mixed input handling. 
// I have modified it slightly from there as noted in comments. 
class screens.Jourdex.Jourdex extends com.SFXInputMovieClip
{
    var bDebuggingFlash;
    var controller;
    var m_nUnreadQuestPrimary;
    var m_nUnreadQuestSecondary;
    var m_nUnreadCodexPrimary;
    var m_nUnreadCodexSecondary;
    var mcSB_Primary;
    var mcSB_Secondary;
    var PC_ReturnButton;
    var PC_MiddleButton;
    var PC_LeftButton;
    var m_oLoadMonitor;
    var detailMC;
    var mcPrimaryList;
    var mcSecondaryList;
    var BarGroup;
    var guiTitleText;
    var m_sExit;
    var m_sBack;
    var m_sCloseTasks;
    var m_sMissionTab;
    var m_sPrimaryTab;
    var m_sSecondaryTab;
    var m_sMarkAllViewed;
    var m_sView;
    var m_sContinue;
    var aTabTitles;
    var mcTab1;
    var mcTab2;
    var mcTab3;
    var bUsingGamepad;
    var IsFullScreen = false;
    static var LEFTTABINDEX = 0;
    static var RIGHTTABINDEX = 2;
    static var RIGHT_PANE_DEFAULT = 0;
    static var RIGHT_PANE_PLOTITEMS = 1;
    function Jourdex()
    {
        super();
    }
    function onLoad()
    {
        super.onLoad();
        com.SFXScreen.PrepareScreen();
        this.bDebuggingFlash = !com.XPlatform.IsRunningInEngine();
        this.controller = _root.mcConsoleButtons;
        this.m_nUnreadQuestPrimary = 0;
        this.m_nUnreadQuestSecondary = 0;
        this.m_nUnreadCodexPrimary = 0;
        this.m_nUnreadCodexSecondary = 0;
        this.mcSB_Primary._visible = false;
        this.mcSB_Secondary._visible = false;
        this.controller._visible = false;
        this.PC_ReturnButton._visible = false;
        this.PC_MiddleButton._visible = false;
        this.PC_LeftButton._visible = false;
        this.SetupStrings();
        this.m_oLoadMonitor = new com.SFXMovieClipLoadMonitor();
        this.m_oLoadMonitor.RegisterMovieClip(this.detailMC.screenShotLoader);
        this.m_oLoadMonitor.RegisterMovieClip(this.mcPrimaryList);
        this.m_oLoadMonitor.RegisterMovieClip(this.mcSecondaryList);
        this.m_oLoadMonitor.RegisterMovieClip(this.BarGroup);
        this.m_oLoadMonitor.RegisterMovieClip(this.controller);
        this.m_oLoadMonitor.WaitForRegisteredClips(this.MakeDelegate(this.onMovieClipsLoadedAndReady));
    }
    function onMovieClipsLoadedAndReady()
    {
        this.initialize();
        this.detailMC.screenShotLoader.FadeScalar = 2;
        this.detailMC.screenShotLoader.Async = true;
        this.detailMC.screenShotLoader.FadeIn = true;
        this.detailMC.screenShotLoader.FadeOut = true;
        this.detailMC.screenShotLoader.HAlign = com.bioware.masseffect.controls.ResourceLoader.ALIGN_CENTER;
        this.detailMC.screenShotLoader.VAlign = com.bioware.masseffect.controls.ResourceLoader.ALIGN_CENTER;
        this.detailMC.screenShotLoader.UsePlaceholderSize();
        flash.external.ExternalInterface.call("ExInitializeJournal");
        if(this.bDebuggingFlash)
        {
            this.RunTests();
        }
    }
    function SetupStrings()
    {
        this.guiTitleText.text = "$" + _global.SFX.GetIniString("TitleText");
        this.m_sExit = "$" + _global.SFX.GetIniString("ExitText");
        this.m_sBack = "$" + _global.SFX.GetIniString("BackText");
        this.m_sCloseTasks = "$" + _global.SFX.GetIniString("CloseSubListText");
        this.m_sMissionTab = "$" + _global.SFX.GetIniString("Tab1Text");
        this.m_sPrimaryTab = "$" + _global.SFX.GetIniString("Tab2Text");
        this.m_sSecondaryTab = "$" + _global.SFX.GetIniString("Tab3Text");
        var _loc3_ = _global.SFX.GetIniNumber("MarkAllViewedText");
        this.m_sMarkAllViewed = _loc3_ != 0 ? "$" + _loc3_ : "";
        this.m_sView = "$" + _global.SFX.GetIniString("ViewText");
        this.m_sContinue = "$" + _global.SFX.GetIniString("ContinueText");
        this.aTabTitles = new Array(this.m_sMissionTab,this.m_sPrimaryTab,this.m_sSecondaryTab);
    }
    function initialize()
    {
        this.BarGroup.SetSounds("GuiError","QuestExpand","QuestListMove","QuestExpand");
        this.detailMC.gotoAndStop(2);
        this.mcPrimaryList.setupScrollBar(this.mcSB_Primary);
        this.mcSecondaryList.setupScrollBar(this.mcSB_Secondary);
        this.mcSecondaryList.EnableIcons = false;
        this.BarGroup.SetLists(this.mcPrimaryList,this.mcSecondaryList);
        this.mcPrimaryList.addEventListener("JournalVList_SplitList",this.MakeDelegate(this.onAButton));
        this.mcPrimaryList.addEventListener("JournalVList_MergeList",this.MakeDelegate(this.onBButton));
        this.BarGroup.BarTop.SetTabButtons(this.mcTab1,this.m_sMissionTab,this.mcTab2,this.m_sPrimaryTab,this.mcTab3,this.m_sSecondaryTab);
        this.BarGroup.SetCallbacks(this,this.onItemSelected,this.onSubItemSelected,this.onTabSwitch,this.onItemExpanded);
        this.BarGroup.BarTop.SetTabCallbacks(this,this.onTabSwitch);
        this.setupControllerAndConsoleInput();
    }
    function ShowFullScreenController()
    {
        if(!this.IsFullScreen)
        {
            this.IsFullScreen = true;
            if(_global.SFX.Platform == com.XPlatform.PS3)
            {
                _root.ControllerMC.ControllerMap.gotoAndStop("PS3");
            }
            _root.ControllerMC.gotoAndPlay("open");
            this.controller.ControlA.text = this.m_sContinue;
            this.controller._x += 320;
        }
    }
    function HideFullScreenController()
    {
        if(this.IsFullScreen)
        {
            this.IsFullScreen = false;
            _root.ControllerMC.gotoAndPlay("close");
            this.controller.ControlA.text = this.m_sView;
            this.controller._x -= 320;
        }
    }
    function setupControllerAndConsoleInput()
    {
        this.addEventListener("onDPadUp",this.MakeDelegate(this.onDPadUp));
        this.addEventListener("onDPadDown",this.MakeDelegate(this.onDPadDown));
        this.addEventListener("onDPadLeft",this.MakeDelegate(this.onDPadLeft));
        this.addEventListener("onDPadRight",this.MakeDelegate(this.onDPadRight));
        this.addEventListener("onButtonX",this.MakeDelegate(this.onXButton));
        this.addEventListener("onButtonY",this.MakeDelegate(this.onYButton));
        this.addEventListener("onButtonA",this.MakeDelegate(this.onAButton));
        this.addEventListener("onButtonB",this.MakeDelegate(this.onBButton));
        this.addEventListener("onButtonStart",this.MakeDelegate(this.onButtonStart));
        this.addEventListener("onInvalidInput",this.MakeDelegate(this.onInvalidInput));
        this.controller.ControlX.Active = false;
        this.controller.ControlX.text = this.m_sMarkAllViewed;
        this.controller.ControlX.Hidden = true;
        this.controller.ControlY.Active = false;
        this.controller.ControlY.text = "";
        this.controller.ControlY.Hidden = true;
        this.controller.ControlA.Active = true;
        this.controller.ControlA.text = this.m_sView;
        this.controller.ControlB.Active = true;
        this.controller.ControlB.text = this.m_sBack;
        this.controller.FitLeft();
        if(_global.SFX.Platform == com.XPlatform.PC)
        {
            this.AddKeyUpEvent(13,"onEnter");
            this.AddKeyUpEvent(32,"onSpace");
            this.AddKeyUpEvent(27,"onEscape");
            this.addEventListener("onEnter",this.MakeDelegate(this.onAButton));
            this.addEventListener("onSpace",this.MakeDelegate(this.onBButton));
            this.addEventListener("onEscape",this.MakeDelegate(this.onBButton));
            this.PC_ReturnButton.addEventListener("SFXButton_onRelease",this.MakeDelegate(this.onPC_ReturnButton));
            this.PC_MiddleButton.addEventListener("SFXButton_onRelease",this.MakeDelegate(this.onXButton));
            this.PC_LeftButton.addEventListener("SFXButton_onRelease",this.MakeDelegate(this.onYButton));
            this.PC_ReturnButton.SetText(this.m_sBack);
            this.PC_MiddleButton.SetText(this.m_sMarkAllViewed);
        }
        if(_global.SFX.Platform == com.XPlatform.PC && !this.bUsingGamepad)
        {
            this.PC_ReturnButton.SetVisible(true);
            this.PC_MiddleButton.SetVisible(false);
            this.PC_LeftButton.SetVisible(false);
            this.BarGroup.xboxButton._visible = false;
            this.detailMC.missionMC.scrollStick._visible = false;
            this.controller._visible = false;
        }
        else
        {
            this.PC_ReturnButton.SetVisible(false);
            this.PC_MiddleButton.SetVisible(false);
            this.PC_LeftButton.SetVisible(false);
            this.BarGroup.xboxButton._visible = true;
            this.detailMC.missionMC.scrollStick._visible = true;
            this.controller._visible = true;
        }
    }
    function setupVisualState(nForceTab)
    {
        this.BarGroup.BarTop.SelectedTab = nForceTab;
        this.detailMC.Mission.text = this.aTabTitles[this.getSelectedTab()];
        this.SetPlatformLayout(_global.SFX.Platform);
    }
    function SetPlatformLayout(nPlatformID)
    {
        _global.PlatformID = nPlatformID;
        this.detailMC.missionMC.PlatformLayout = nPlatformID;
        this.BarGroup.SetPlatformLayout(nPlatformID);
    }
    function StartDisplayList(sYLabel, sFilterName, nNumItems)
    {
        this.PC_LeftButton.SetText(sYLabel);
        this.controller.InputDisabled = true;
        this.controller.ControlY.text = sYLabel;
        this.controller.ControlY.Active = sYLabel != "";
        if(_global.SFX.Platform == com.XPlatform.PC && !this.bUsingGamepad)
        {
            this.controller.ControlY.Hidden = true;
            this.PC_LeftButton.SetVisible(sYLabel != "");
        }
        else
        {
            this.controller.ControlY.Hidden = sYLabel == "";
            this.PC_LeftButton.SetVisible(false);
        }
        this.BarGroup.Empty();
        this.BarGroup.BarTop.FilterName = sFilterName;
    }
    function AddListItems(aItems)
    {
        aItems = com.SFXScreen.ObjectToArray(aItems);
        var _loc3_ = 0;
        while(_loc3_ < aItems.length)
        {
            var _loc4_ = aItems[_loc3_].bHasSubItems == undefined ? true : aItems[_loc3_].bHasSubItems;
            this.BarGroup.AddPrimaryEntry(aItems[_loc3_].nIndex,aItems[_loc3_].nID,aItems[_loc3_].sName,aItems[_loc3_].bComplete,aItems[_loc3_].bUpdated,aItems[_loc3_].sListTag,aItems[_loc3_],_loc4_);
            _loc3_ += 1;
        }
    }
    function EndDisplayList(nCurrentItemID)
    {
        if(this.BarGroup.PrimaryList.length > 0 && this.controller.ControlY.text != "")
        {
            this.controller.ControlY.Active = true;
            this.controller.ControlY.Hidden = false;
        }
        this.controller.InputDisabled = false;
        this.BarGroup.SynchToQuest(nCurrentItemID);
        if(this.BarGroup.length > 3)
        {
            this.mcSB_Primary.scrollbarVisibleOveride = true;
            this.mcSB_Primary.scrollbarVisibleOverideValue = true;
        }
        else
        {
            this.mcSB_Primary.scrollbarVisibleOveride = false;
        }
    }
    function SetSubItems(aSubItems)
    {
        aSubItems = com.SFXScreen.ObjectToArray(aSubItems);
        var _loc3_ = 0;
        while(_loc3_ < aSubItems.length)
        {
            this.AddSubListItem(_loc3_,aSubItems[_loc3_].nID,aSubItems[_loc3_].sName,aSubItems[_loc3_].bUpdated,aSubItems[_loc3_].sListTag,aSubItems[_loc3_]);
            _loc3_ += 1;
        }
    }
    function AddSubListItem(nIndex, nSubItemID, sSubItemName, bUpdated, sListTag, rawData)
    {
        this.BarGroup.AddSublistEntry(nIndex,nSubItemID,sSubItemName,bUpdated,sListTag,rawData);
    }
    function SetUnreadItemCounts(nUnreadQuestPrimary, nUnreadQuestSecondary, nUnreadCodexPrimary, nUnreadCodexSecondary)
    {
        this.m_nUnreadQuestPrimary = nUnreadQuestPrimary;
        this.m_nUnreadCodexPrimary = nUnreadCodexPrimary;
        this.m_nUnreadCodexSecondary = nUnreadCodexSecondary;
        this.SetUpdateStatus(true);
    }
    function UpdateUnreadItemCounts()
    {
        var _loc2_ = !this.BarGroup.PrimaryList.ContainsUpdated() ? 0 : 1;
        switch(this.getSelectedTab())
        {
            case 0:
                this.m_nUnreadQuestPrimary = _loc2_;
                break;
            case 1:
                this.m_nUnreadCodexPrimary = _loc2_;
                break;
            case 2:
                this.m_nUnreadCodexSecondary = _loc2_;
        }
        this.SetUpdateStatus(false);
    }
    function SetDetails(sDesc, imageResource)
    {
        this.detailMC.missionMC.text = sDesc;
        this.detailMC.screenShotLoader.ImageResource = imageResource;
    }
    function SetUpdateStatus(nForce)
    {
        this.BarGroup.BarTop.SetTabCategoryHilight(1,this.m_nUnreadQuestPrimary > 0,nForce);
        this.BarGroup.BarTop.SetTabCategoryHilight(2,this.m_nUnreadCodexPrimary > 0,nForce);
        this.BarGroup.BarTop.SetTabCategoryHilight(3,this.m_nUnreadCodexSecondary > 0,nForce);
        var _loc4_ = this.m_sMarkAllViewed != "";
        this.controller.ControlX.Active = _loc4_;
        if(this.m_nUnreadQuestPrimary + this.m_nUnreadCodexPrimary + this.m_nUnreadCodexSecondary > 0)
        {
            if(_global.SFX.Platform == com.XPlatform.PC && !this.bUsingGamepad)
            {
                this.PC_MiddleButton.SetVisible(_loc4_);
                this.controller.ControlX.Hidden = true;
            }
            else
            {
                this.PC_MiddleButton.SetVisible(false);
                this.controller.ControlX.Hidden = !_loc4_;
            }
        }
        else
        {
            this.PC_MiddleButton.SetVisible(false);
            this.controller.ControlX.Hidden = true;
        }
    }
    function SetItemUpdate(nIndex, bUpdated)
    {
        this.BarGroup.SetQuestUpdate(nIndex,bUpdated);
    }
    function SetSubItemUpdate(nIndex, bUpdated)
    {
        this.BarGroup.SetQuestUpdate(nIndex,bUpdated);
    }
    function getItemIndex()
    {
        return this.BarGroup.PrimaryList.selectedIndex;
    }
    function getSubItemIndex()
    {
        return this.BarGroup.Sublist.selectedIndex;
    }
    function getSelectedItem()
    {
        return this.BarGroup.PrimaryList.selectedItem;
    }
    function getSelectedSubItem()
    {
        return this.BarGroup.Sublist.selectedItem;
    }
    function getSelectedTab()
    {
        if(this.BarGroup == undefined || this.BarGroup.BarTop == undefined)
        {
            return 0;
        }
        if(this.BarGroup.BarTop.SelectedTab - 1 < screens.Jourdex.Jourdex.LEFTTABINDEX || this.BarGroup.BarTop.SelectedTab - 1 > screens.Jourdex.Jourdex.RIGHTTABINDEX)
        {
            if(this.BarGroup.BarTop.DefaultTab - 1 < screens.Jourdex.Jourdex.LEFTTABINDEX || this.BarGroup.BarTop.DefaultTab - 1 > screens.Jourdex.Jourdex.RIGHTTABINDEX)
            {
                return 0;
            }
            return this.BarGroup.BarTop.DefaultTab - 1;
        }
        return this.BarGroup.BarTop.SelectedTab - 1;
    }
    function onDPadUp()
    {
        if(this.IsFullScreen)
        {
            _global.SFX.PlayGUIError();
            return undefined;
        }
        this.BarGroup.moveList(-1);
    }
    function onDPadDown()
    {
        if(this.IsFullScreen)
        {
            _global.SFX.PlayGUIError();
            return undefined;
        }
        this.BarGroup.moveList(1);
    }
    function onDPadLeft()
    {
        if(this.IsFullScreen)
        {
            _global.SFX.PlayGUIError();
            return undefined;
        }
        if(this.getSelectedTab() > screens.Jourdex.Jourdex.LEFTTABINDEX && !this.BarGroup.IsSplit)
        {
            if(this.bDebuggingFlash)
            {
                this.ImitatePopulate();
            }
            this.switchCategory(false);
        }
        else
        {
            this.onInvalidInput();
        }
    }
    function onDPadRight()
    {
        if(this.IsFullScreen)
        {
            _global.SFX.PlayGUIError();
            return undefined;
        }
        if(this.getSelectedTab() < screens.Jourdex.Jourdex.RIGHTTABINDEX && !this.BarGroup.IsSplit)
        {
            if(this.bDebuggingFlash)
            {
                this.ImitatePopulate();
            }
            this.switchCategory(true);
        }
        else
        {
            this.onInvalidInput();
        }
    }
    function onXButton()
    {
        if(this.IsFullScreen)
        {
            _global.SFX.PlayGUIError();
            return undefined;
        }
        if(this.m_nUnreadQuestPrimary > 0 || this.m_nUnreadCodexPrimary > 0 || this.m_nUnreadCodexSecondary > 0)
        {
            this.externalSetAllViewed();
        }
        else
        {
            this.onInvalidInput();
        }
    }
    function onYButton()
    {
        if(this.IsFullScreen)
        {
            _global.SFX.PlayGUIError();
            return undefined;
        }
        if(!this.BarGroup.IsSplit)
        {
            _global.SFX.PlayGUISound("QuestSort");
            this.externalSortItems();
        }
        else
        {
            this.onInvalidInput();
        }
    }
    function onAButton()
    {
        if(this.IsFullScreen)
        {
            this.HideFullScreenController();
            return undefined;
        }
        if(this.BarGroup.PrimaryList.length == 0 || this.BarGroup.PrimaryList.selectedItem.data.bHasSubItems == false)
        {
            _global.SFX.PlayGUIError();
            return undefined;
        }
        if(!this.BarGroup.IsSplit)
        {
            this.BarGroup.BarTop.DisableTabs();
            this.BarGroup.onJournalVList_SplitList();
            this.controller.ControlA.Active = false;
            this.controller.ControlB.text = this.m_sCloseTasks;
            this.detailMC.Mission.text = "";
        }
    }
    function onBButton()
    {
        if(this.IsFullScreen)
        {
            this.ReturnToBrowser();
        }
        else if(this.BarGroup.IsSplit)
        {
            this.externalExitSublist();
            this.BarGroup.onJournalVList_MergeList();
            this.controller.ControlA.Active = true;
            this.controller.ControlB.text = this.m_sBack;
            this.detailMC.Mission.text = this.aTabTitles[this.getSelectedTab()];
            this.BarGroup.BarTop.EnableTabs();
        }
        else
        {
            this.ReturnToBrowser();
        }
    }
    function onPC_ReturnButton(p_event)
    {
        this.ReturnToBrowser();
    }
    function onButtonStart()
    {
        flash.external.ExternalInterface.call("CloseGUIs");
    }
    function onInvalidInput()
    {
        _global.SFX.PlayGUISound("GuiError");
    }
    function onTabSwitch(bFullTransition)
    {
        this.detailMC.Mission.text = this.aTabTitles[this.getSelectedTab()];
        if(bFullTransition)
        {
            _global.SFX.PlayGUISound("SwapMissionAssignment");
        }
        this.externalSwapTabs();
    }
    function onItemExpanded(itemIndex)
    {
        if(this.bDebuggingFlash)
        {
            this.ImitateExpandItemEvent(itemIndex);
        }
        else
        {
            this.externalExpandItem(itemIndex);
        }
    }
    function onItemSelected(item)
    {
        if(this.bDebuggingFlash)
        {
            this.ImitateEnteredItemEvent(item.data.index);
        }
        else
        {
            if(this.bUsingGamepad)
            {
                var _loc3_ = item.data.bHasSubItems && !this.BarGroup.IsSplit;
                this.controller.ControlA.Hidden = !_loc3_;
                this.controller.ControlA.Active = _loc3_;
            }
            else
            {
                this.controller.ControlA.Hidden = true;
            }
            this.BarGroup.Plus._visible = item.data.bHasSubItems;
            this.externalEnterItem(item);
            this.UpdateUnreadItemCounts();
        }
    }
    function onSubItemSelected(itemIndex, subItemIndex)
    {
        if(this.bDebuggingFlash)
        {
            this.ImitateEnteredSubItemEvent(itemIndex,subItemIndex);
        }
        else
        {
            this.externalEnterSubItem(itemIndex,subItemIndex);
        }
    }
    function scrollDetailsAnalog(nScroll)
    {
        if(this.IsFullScreen)
        {
            return undefined;
        }
        if(Math.abs(nScroll) >= 0.2)
        {
            this.detailMC.missionMC.scrollByTime(nScroll <= 0 ? com.bioware.masseffect.controls.Marquee.SCROLL_CONTENT_DOWN : com.bioware.masseffect.controls.Marquee.SCROLL_CONTENT_UP,Math.abs(nScroll));
        }
        else
        {
            this.detailMC.missionMC.ResetScrollTime();
        }
    }
    function MarkAllViewedConfirmed()
    {
        var _loc3_ = this.getSelectedTab();
        if(this.m_nUnreadQuestPrimary > 0 || this.m_nUnreadCodexPrimary > 0 || this.m_nUnreadCodexSecondary > 0)
        {
            var _loc4_ = 0;
            while(_loc4_ < this.BarGroup.Sublist.length)
            {
                this.BarGroup.SetTaskUpdate(_loc4_,false);
                _loc4_ += 1;
            }
            var _loc5_ = 0;
            while(_loc5_ < this.BarGroup.length)
            {
                this.BarGroup.SetQuestUpdate(_loc5_,false);
                _loc5_ += 1;
            }
            this.SetUnreadItemCounts(0,0,0,0);
        }
        _global.SFX.PlayGUISound("MarkQuestsViewed");
    }
    function switchCategory(bForward)
    {
        if(bForward)
        {
            this.BarGroup.BarTop.SelectedTab += 1;
        }
        else
        {
            this.BarGroup.BarTop.SelectedTab -= 1;
        }
    }
    function RefreshButtonHelp(usingGamepad)
    {
        this.bUsingGamepad = usingGamepad;
        if(_global.SFX.Platform == com.XPlatform.PC && !this.bUsingGamepad)
        {
            this.PC_ReturnButton.SetVisible(true);
            this.PC_LeftButton.SetVisible(this.PC_LeftButton.text != "" && this.PC_LeftButton.text != null);
            this.PC_MiddleButton.SetVisible(this.m_sMarkAllViewed != "" && this.m_sMarkAllViewed != null);
            this.controller.ControlA.Hidden = true;
            this.controller.ControlB.Hidden = true;
            this.controller.ControlX.Hidden = true;
            this.controller.ControlY.Hidden = true;
            this.BarGroup.xboxButton._visible = false;
            this.detailMC.missionMC.scrollStick._visible = false;
            this.controller._visible = false;
            // MILAN CHANGE  DropTheSquid 12/17/2023
			// this fixes an issue where sometimes, after switching tabs with controller then switching to mouse
			// without changing items, the Set Title button would appear erroneously enabled, but not actually be clickable
			// it just forces a UI update to what it already should be, but failed to update correctly while not visible. 
            this.PC_MiddleButton.SetEnabled(this.PC_MiddleButton.enabled);
        }
        else
        {
            this.PC_ReturnButton.SetVisible(false);
            this.PC_LeftButton.SetVisible(false);
            this.PC_MiddleButton.SetVisible(false);
            this.controller.ControlA.Hidden = false;
            this.controller.ControlB.Hidden = false;
            this.controller.ControlX.Hidden = this.m_sMarkAllViewed == "" || this.m_sMarkAllViewed == null;
            this.controller.ControlY.Hidden = this.PC_LeftButton.text == "" || this.PC_LeftButton.text == null;
            this.BarGroup.xboxButton._visible = true;
            this.detailMC.missionMC.scrollStick._visible = true;
            this.controller._visible = true;
        }
    }
    function externalExitSublist()
    {
        flash.external.ExternalInterface.call("ExExitEntries");
    }
    function externalSetAllViewed()
    {
        flash.external.ExternalInterface.call("ExMarkAllDataViewed");
    }
    function externalExpandItem(nIndex)
    {
        flash.external.ExternalInterface.call("ExExpandEntry");
    }
    function externalEnterSubItem(itemIndex, subItemIndex)
    {
        var _loc4_ = subItemIndex;
        if(this.getSelectedTab() + 1 != this.BarGroup.BarTab.TAB1)
        {
            _loc4_ = this.getSelectedSubItem().TaskID;
        }
        flash.external.ExternalInterface.call("ExFocusOnSubentry",_loc4_);
    }
    function externalEnterItem(item)
    {
        var _loc3_ = this.getSelectedTab() + 1;
        flash.external.ExternalInterface.call("ExSetLastEntry",item.data.index);
        flash.external.ExternalInterface.call("ExFocusOnEntry");
    }
    function externalSortItems()
    {
        flash.external.ExternalInterface.call("ExSortList");
    }
    function externalSwapTabs()
    {
        var _loc2_ = this.getSelectedTab() + 1;
        flash.external.ExternalInterface.call("ExFocusOnTab",_loc2_);
    }
    function ReturnToBrowser()
    {
        flash.external.ExternalInterface.call("ReturnToBrowser");
    }
    function DebugTrace(s)
    {
        if(this.bDebuggingFlash)
        {
            trace("Codex: " + s);
        }
    }
    function RunTests()
    {
        this.setupVisualState(this.BarGroup.BarTop.TAB1,com.XPlatform.PC);
        this.ImitatePopulate();
    }
    function ImitatePopulate()
    {
        this.SetUnreadItemCounts(1,0,1);
        this.testList(15);
    }
    function testList(nNumEntries)
    {
        this.StartDisplayList("","",nNumEntries);
        this.testPopulateList(nNumEntries);
        this.EndDisplayList(0);
        this.BarGroup.bDebug = true;
    }
    function testPopulateList(num)
    {
        var _loc3_ = new Array();
        var _loc4_ = 0;
        while(_loc4_ < num)
        {
            _loc3_.push({nIndex:_loc4_,nID:_loc4_ * 10,sName:"Quest name " + (_loc4_ + 1),bComplete:false,bUpdated:true});
            _loc4_ += 1;
        }
        this.AddListItems(_loc3_);
    }
    function ImitateEnteredSubItemEvent(itemIndex, subItemIndex)
    {
        this.DebugTrace("Sub Item Selected " + subItemIndex);
        var _loc4_ = undefined;
        switch(random(3))
        {
            case 0:
                _loc4_ = "Codex page descriptions are really cool";
                break;
            case 1:
                _loc4_ = "Codex page descriptions are super cool";
                break;
            case 2:
                _loc4_ = "Codex page descriptions are wicked cool";
        }
        this.SetDetails(_loc4_,"");
    }
    function ImitateEnteredItemEvent(itemIndex)
    {
        this.DebugTrace("Item Selected " + itemIndex);
        var _loc3_ = undefined;
        _loc3_ = "\tThe beacon <u>on Eden Prime</u> was destroyed. <b> Before </b> it self-destructed, it burned horrific images of death and galactic destruction into your mind. Whether these are images of the past or warnigns of the future, you can\'t really say.";
        _loc3_ += "\r\n" + _loc3_;
        _loc3_ += "\r\n" + _loc3_;
        this.SetDetails(_loc3_,"");
    }
    function ImitateExpandItemEvent(itemIndex)
    {
        var _loc3_ = new Array();
        var _loc4_ = 0;
        while(_loc4_ < 30)
        {
            _loc3_.push({nID:_loc4_,sName:"subitem " + (_loc4_ + 1),bUpdated:true});
            _loc4_ += 1;
        }
        this.SetSubItems(_loc3_);
    }
}
