class screens.WeaponMod.WeaponSelectMain extends com.SFXInputMovieClip
{
    var ActionButtonText;
    var ActionButtonCallback;
    var State;
    var ShowingInfo;
    var Slots;
    var Slot1;
    var Slot2;
    var Slot3;
    var Slot4;
    var Slot5;
    var m_fnMainAction;
    var m_fnBackAction;
    var m_fnWeapAction;
    var WeaponSelect;
    var m_sChangeWeaponButtonText;
    var m_sExitButtonText;
    var m_sDescriptionButtonText;
    var m_sSelectWeaponButtonText;
    var ModDisplay;
    var onEnterFrame;
    var m_sReturnToLoadoutText;
    var m_sStatsButtonText;
    var m_sEquipButtonText;
    var wpnNoWeapText;
    var InputTitle;
    var SelectedWeaponSlot;
    var CurrentWeaponSlot;
    var LastBottomSlot;
    var LastTopSlot;
    var wpnCategoryText;
    var weaponInfoMC;
    var weightDisplay;
    var Stats;
    static var STATE_NAVIGATE_LOADOUT = 0;
    static var STATE_NAVIGATE_INVENTORY = 1;
    function WeaponSelectMain()
    {
        super();
    }
    function onLoad()
    {
        super.onLoad();
        _global.gfxExtensions = true;
        _global.noInvisibleAdvance = true;
        Stage.scaleMode = "noBorder";
        this.InitializeStrings();
        this.ActionButtonText = "";
        this.ActionButtonCallback = "";
        this.State = screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_LOADOUT;
        this.ShowingInfo = false;
        this.Slots = new Array(this.Slot1,this.Slot2,this.Slot3,this.Slot4,this.Slot5);
        var _loc5_ = 0;
        while(_loc5_ < this.Slots.length)
        {
            if(this.Slots[_loc5_] != undefined)
            {
                this.Slots[_loc5_].SlotID = _loc5_;
                this.Slots[_loc5_].hitArea = this.Slots[_loc5_].weaponSlot.HitArea;
                this.Slots[_loc5_].addEventListener("PCMouseOver",this.MakeDelegate(this.WeaponSlotMouseOver));
                this.Slots[_loc5_].addEventListener("PCMouseLeave",this.MakeDelegate(this.WeaponSlotMouseLeave));
                this.Slots[_loc5_].addEventListener("PCMouseClick",this.MakeDelegate(this.WeaponSlotMouseClick));
            }
            _loc5_ = _loc5_ + 1;
        }
        this.SetLoading(true);
        this.m_fnMainAction = this.MakeDelegate(this.PerformAction);
        this.m_fnBackAction = this.MakeDelegate(this.PerformBackAction);
        this.m_fnWeapAction = this.MakeDelegate(this.PerformWeaponAction);
        this.addEventListener("onInvalidInput",this.MakeDelegate(this.HandleInvalidInput));
        this.addEventListener("onDPadUp",this.MakeDelegate(this.MoveSelectionUp));
        this.addEventListener("onDPadDown",this.MakeDelegate(this.MoveSelectionDown));
        this.addEventListener("onDPadLeft",this.MakeDelegate(this.MoveSelectionLeft));
        this.addEventListener("onDPadRight",this.MakeDelegate(this.MoveSelectionRight));
        if(com.XPlatform.IsConsoleLayout(_global.SFX.Platform))
        {
            this.addEventListener("onButtonA",this.MakeDelegate(this.m_fnMainAction));
            this.addEventListener("onButtonY",this.MakeDelegate(this.ToggleInfoDisplay));
            this.addEventListener("onButtonB",this.MakeDelegate(this.m_fnBackAction));
            this.addEventListener("onButtonX",this.MakeDelegate(this.m_fnWeapAction));
            this.addEventListener("onButtonStart",this.MakeDelegate(this.m_fnBackAction));
            this.addEventListener("onTriggerLeft",this.MakeDelegate(this.SelectPrevHench));
            this.addEventListener("onTriggerRight",this.MakeDelegate(this.SelectNextHench));
            this.WeaponSelect.addEventListener("selectNextWeapon",this.MakeDelegate(this.SelectNextWeapon));
            this.WeaponSelect.addEventListener("selectPrevWeapon",this.MakeDelegate(this.SelectPrevWeapon));
            _root.ConsoleButtons.ControlA.SetText(this.m_sChangeWeaponButtonText);
            _root.ConsoleButtons.ControlA.SetVisible(false);
            _root.ConsoleButtons.ControlB.SetText(this.m_sExitButtonText);
            _root.ConsoleButtons.ControlB.SetVisible(false);
            _root.ConsoleButtons.ControlX.SetText("");
            _root.ConsoleButtons.ControlX.SetVisible(false);
            _root.ConsoleButtons.ControlY.SetText(this.m_sDescriptionButtonText);
            _root.ConsoleButtons.ControlY.SetVisible(false);
            _root.ConsoleButtons.FitLeft();
            _root.PCButtonLeft.SetVisible(false);
            _root.PCButtonMiddle.SetVisible(false);
            _root.PCButtonRight.SetVisible(false);
        }
        else
        {
            _root.ConsoleButtons._visible = false;
            this.AddKeyUpEvent(13,"onEnter");
            this.AddKeyUpEvent(32,"onSpace");
            this.AddKeyUpEvent(27,"onEscape");
            if(_global.SFX.IsMPLobby == true)
            {
                this.addEventListener("onButtonB",this.MakeDelegate(this.m_fnBackAction));
            }
            else
            {
                this.addEventListener("onButtonStart",this.MakeDelegate(this.m_fnBackAction));
            }
            this.addEventListener("onEnter",this.MakeDelegate(this.m_fnMainAction));
            this.addEventListener("onSpace",this.MakeDelegate(this.m_fnMainAction));
            this.addEventListener("onEscape",this.MakeDelegate(this.m_fnBackAction));
            this.WeaponSelect.addEventListener("selectNextWeapon",this.MakeDelegate(this.SelectNextWeapon));
            this.WeaponSelect.addEventListener("selectPrevWeapon",this.MakeDelegate(this.SelectPrevWeapon));
            this.WeaponSelect.addEventListener("toggleInfoDisplay",this.MakeDelegate(this.ToggleInfoDisplay));
            _root.PCButtonRight.SetText(this.m_sExitButtonText);
            _root.PCButtonRight.addEventListener("SFXButton_onRelease",this.MakeDelegate(this.m_fnBackAction));
            _root.PCButtonRight.SetVisible(true);
            _root.PCButtonMiddle.addEventListener("SFXButton_onRelease",this.MakeDelegate(this.m_fnWeapAction));
            _root.PCButtonMiddle.SetVisible(false);
            _root.PCButtonLeft.SetText(this.m_sSelectWeaponButtonText);
            _root.PCButtonLeft.addEventListener("SFXButton_onRelease",this.MakeDelegate(this.m_fnMainAction));
            _root.PCButtonLeft.SetVisible(false);
            this.ModDisplay.onRelease = this.MakeDelegate(this.m_fnWeapAction);
        }
        if(com.XPlatform.IsRunningInEngine() == false)
        {
            this.onEnterFrame = this.TEST_InitTest;
        }
        flash.external.ExternalInterface.call("MainMovieLoaded");
    }
    function InitializeStrings()
    {
        this.m_sChangeWeaponButtonText = "$" + _global.SFX.GetIniString("ChangeWeaponButtonText");
        this.m_sExitButtonText = "$" + _global.SFX.GetIniString("ExitButtonText");
        this.m_sDescriptionButtonText = "$" + _global.SFX.GetIniString("DescriptionButtonText");
        this.m_sSelectWeaponButtonText = "$" + _global.SFX.GetIniString("SelectWeaponButtonText");
        this.m_sReturnToLoadoutText = "$" + _global.SFX.GetIniString("ReturnToLoadoutText");
        this.m_sStatsButtonText = "$" + _global.SFX.GetIniString("StatsButtonText");
        this.m_sEquipButtonText = "$" + _global.SFX.GetIniString("EquipButtonText");
        var _loc3_ = _global.SFX.GetIniNumber("InstructionText");
        this.wpnNoWeapText.text = !_loc3_ ? "" : "$" + _loc3_;
        if(!_global.SFX.IsMPLobby)
        {
            this.InputTitle.text = "$" + _global.SFX.GetIniString("WeaponLoadoutTitle");
        }
        else
        {
            this.InputTitle.text = "";
            this.m_sExitButtonText = "$593575";
        }
        var _loc4_ = "$" + _global.SFX.GetIniString("WeaponModTitle");
        this.ModDisplay.wpnModsText.text = _loc4_;
        if(_global.SFX.Platform != com.XPlatform.PC)
        {
            var _loc5_ = this.ModDisplay.wpnModsText._x + this.ModDisplay.wpnModsText._width * 0.5 + this.ModDisplay.wpnModsText.textWidth * 0.5;
            this.ModDisplay.ConsoleBtnX._x = _loc5_ + this.ModDisplay.ConsoleBtnX._width * 0.5;
        }
        this.ModDisplay.ConsoleBtnX._visible = false;
    }
    function TurnOnWeaponSlot(nSlotID)
    {
        if(nSlotID < 0 || nSlotID >= this.Slots.length)
        {
            return undefined;
        }
        if(this.SelectedWeaponSlot == undefined)
        {
            this.Slots[nSlotID].SetDesiredState(screens.WeaponMod.WeaponSlot.STATE_ON);
            this.CurrentWeaponSlot = this.Slots[nSlotID];
            flash.external.ExternalInterface.call("WeaponLoadoutItemChanged",this.CurrentWeaponSlot.WeaponID,this.CurrentWeaponSlot.CategoryID);
            _global.SFX.PlayGUISound("WeaponGUIListMove");
            var _loc4_ = 0;
            while(_loc4_ < this.Slots.length)
            {
                if(_loc4_ != nSlotID)
                {
                    this.Slots[_loc4_].SetDesiredState(screens.WeaponMod.WeaponSlot.STATE_OFF);
                }
                _loc4_ = _loc4_ + 1;
            }
            if(_global.SFX.Platform != com.XPlatform.PC)
            {
                _root.ConsoleButtons.ControlA.SetText(!this.CurrentWeaponSlot.SlotIsEmpty() ? this.m_sChangeWeaponButtonText : this.m_sEquipButtonText);
                _root.ConsoleButtons.ControlA.SetVisible(true);
                _root.ConsoleButtons.ControlX.SetVisible(this.CheckCanModify());
                _root.ConsoleButtons.ControlY.SetVisible(!this.CurrentWeaponSlot.SlotIsEmpty());
                this.ModDisplay.ConsoleBtnX._visible = this.CheckCanModify();
            }
        }
    }
    function TurnOffWeaponSlot(nSlotID)
    {
        if(nSlotID < 0 || nSlotID >= this.Slots.length)
        {
            _global.SFX.PlayGUIError();
            return undefined;
        }
        if(this.SelectedWeaponSlot == undefined)
        {
            this.Slots[nSlotID].SetDesiredState(screens.WeaponMod.WeaponSlot.STATE_OFF);
            if(this.CurrentWeaponSlot == this.Slots[nSlotID])
            {
                this.CurrentWeaponSlot = undefined;
                flash.external.ExternalInterface.call("WeaponLoadoutItemChanged",-1,-1);
            }
        }
    }
    function ToggleSelectWeaponSlot(nSlotID)
    {
        if(nSlotID < 0 || nSlotID >= this.Slots.length)
        {
            _global.SFX.PlayGUIError();
            return undefined;
        }
        if(this.SelectedWeaponSlot != undefined && this.SelectedWeaponSlot != this.Slots[nSlotID])
        {
            var _loc4_ = this.SelectedWeaponSlot.SlotID;
            this.ToggleSelectWeaponSlot(_loc4_);
            this.TurnOffWeaponSlot(_loc4_);
            this.TurnOnWeaponSlot(nSlotID);
        }
        if(this.SelectedWeaponSlot == undefined)
        {
            if(this.Slots[nSlotID].WeaponsInCategory == 0 || Boolean(flash.external.ExternalInterface.call("CheckCanSelectWeapon",this.Slots[nSlotID].CategoryID)) == false)
            {
                _global.SFX.PlayGUIError();
                return undefined;
            }
            this.SelectedWeaponSlot = this.Slots[nSlotID];
        }
        else
        {
            var _loc5_ = Boolean(flash.external.ExternalInterface.call("CheckCanEquipWeapon",this.SelectedWeaponSlot.CategoryID));
            if(!_loc5_)
            {
                _global.SFX.PlayGUIError();
                return undefined;
            }
            _global.SFX.PlayGUISound("WeaponGUIAcceptSelection");
        }
        if(this.SelectedWeaponSlot == this.Slots[nSlotID])
        {
            this.SelectedWeaponSlot.Selected = !this.SelectedWeaponSlot.Selected;
            if(!this.SelectedWeaponSlot.Selected)
            {
                this.SelectedWeaponSlot = undefined;
                this.SwitchToWeaponLoadout();
            }
            else
            {
                this.SwitchToWeaponSelection();
            }
        }
        else
        {
            _global.SFX.PlayGUIError();
        }
    }
    function GetBestBottomRowSlot()
    {
        if(this.LastBottomSlot == 3 && this.LastTopSlot == 0)
        {
            return 3;
        }
        return this.LastTopSlot != 0 ? 4 : 2;
    }
    function GetBestTopRowSlot()
    {
        switch(this.LastBottomSlot)
        {
            case 2:
            case 3:
                return 0;
            case 4:
                return 1;
            default:
                return 0;
        }
    }
    function MoveSelectionUp()
    {
        if(this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_INVENTORY)
        {
            _global.SFX.PlayGUIError();
            return undefined;
        }
        if(this.SelectedWeaponSlot != undefined)
        {
            _global.SFX.PlayGUIError();
            return undefined;
        }
        if(this.CurrentWeaponSlot == undefined)
        {
            this.TurnOnWeaponSlot(0);
            return undefined;
        }
        switch(this.CurrentWeaponSlot.SlotID)
        {
            case 0:
            case 1:
                _global.SFX.PlayGUIError();
                return undefined;
            case 2:
            case 3:
            case 4:
                this.LastBottomSlot = this.CurrentWeaponSlot.SlotID;
                this.TurnOffWeaponSlot(this.LastBottomSlot);
                this.TurnOnWeaponSlot(this.GetBestTopRowSlot());
        }
    }
    function MoveSelectionDown()
    {
        if(this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_INVENTORY)
        {
            _global.SFX.PlayGUIError();
            return undefined;
        }
        if(this.SelectedWeaponSlot != undefined)
        {
            _global.SFX.PlayGUIError();
            return undefined;
        }
        if(this.CurrentWeaponSlot == undefined)
        {
            this.TurnOnWeaponSlot(0);
            return undefined;
        }
        switch(this.CurrentWeaponSlot.SlotID)
        {
            case 0:
            case 1:
                this.LastTopSlot = this.CurrentWeaponSlot.SlotID;
                this.TurnOffWeaponSlot(this.LastTopSlot);
                this.TurnOnWeaponSlot(this.GetBestBottomRowSlot());
                break;
            default:
                break;
            case 2:
            case 3:
            case 4:
                _global.SFX.PlayGUIError();
                return undefined;
        }
    }
    function MoveSelectionLeft()
    {
        if(this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_LOADOUT)
        {
            this.SelectLoadoutLeft();
        }
        else if(this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_INVENTORY)
        {
            this.SelectInventoryLeft();
        }
    }
    function SelectLoadoutLeft()
    {
        if(this.SelectedWeaponSlot != undefined)
        {
            _global.SFX.PlayGUIError();
            return undefined;
        }
        if(this.CurrentWeaponSlot == undefined)
        {
            this.TurnOnWeaponSlot(0);
            return undefined;
        }
        switch(this.CurrentWeaponSlot.SlotID)
        {
            case 0:
                _global.SFX.PlayGUIError();
                return undefined;
            case 1:
                this.TurnOffWeaponSlot(1);
                this.TurnOnWeaponSlot(0);
                break;
            case 3:
                this.TurnOffWeaponSlot(3);
                this.TurnOnWeaponSlot(2);
                break;
            case 4:
                this.TurnOffWeaponSlot(4);
                this.TurnOnWeaponSlot(3);
                break;
            default:
                break;
            case 2:
                _global.SFX.PlayGUIError();
                return undefined;
        }
    }
    function MoveSelectionRight()
    {
        if(this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_LOADOUT)
        {
            this.SelectLoadoutRight();
        }
        else if(this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_INVENTORY)
        {
            this.SelectInventoryRight();
        }
    }
    function SelectLoadoutRight()
    {
        if(this.SelectedWeaponSlot != undefined)
        {
            _global.SFX.PlayGUIError();
            return undefined;
        }
        if(this.CurrentWeaponSlot == undefined)
        {
            this.TurnOnWeaponSlot(0);
            return undefined;
        }
        switch(this.CurrentWeaponSlot.SlotID)
        {
            case 0:
                this.TurnOffWeaponSlot(0);
                this.TurnOnWeaponSlot(1);
                break;
            case 2:
                this.TurnOffWeaponSlot(2);
                this.TurnOnWeaponSlot(3);
                break;
            case 3:
                this.TurnOffWeaponSlot(3);
                this.TurnOnWeaponSlot(4);
                break;
            default:
                break;
            case 1:
                _global.SFX.PlayGUIError();
                return undefined;
            case 4:
                _global.SFX.PlayGUIError();
                return undefined;
        }
    }
    function SelectInventoryRight()
    {
        this.WeaponSelect.OnRightArrow(true);
    }
    function SelectInventoryLeft()
    {
        this.WeaponSelect.OnLeftArrow(true);
    }
    function WeaponSlotMouseOver(oEventData)
    {
        this.TurnOnWeaponSlot(oEventData.src.SlotID);
    }
    function WeaponSlotMouseLeave(oEventData)
    {
        this.TurnOffWeaponSlot(oEventData.src.SlotID);
    }
    function WeaponSlotMouseClick(oEventData)
    {
        this.ToggleSelectWeaponSlot(oEventData.src.SlotID);
    }
    function HandleInvalidInput()
    {
        _global.SFX.PlayGUISound("guierror");
    }
    function PerformAction()
    {
        if(this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_LOADOUT && this.CurrentWeaponSlot != undefined)
        {
            if(this.CurrentWeaponSlot.Valid == true)
            {
                this.ToggleSelectWeaponSlot(this.CurrentWeaponSlot.SlotID);
                _global.SFX.PlayGUISound("WeaponGUIOpenSelect");
            }
        }
        else if(this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_INVENTORY)
        {
            this.ToggleSelectWeaponSlot(this.SelectedWeaponSlot.SlotID);
        }
    }
    function CheckCanModify()
    {
        if(this.CurrentWeaponSlot == undefined || this.CurrentWeaponSlot.SlotIsEmpty() && this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_LOADOUT || this.CurrentWeaponSlot.Valid == false || this.ActionButtonCallback == "" || this.WeaponSelect.m_nCurrentWeap == 0 && this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_INVENTORY || this.CurrentWeaponSlot.HasModsAvailable == false)
        {
            return false;
        }
        return true;
    }
    function PerformWeaponAction()
    {
        if(this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_INVENTORY || _global.SFX.Platform != com.XPlatform.PC)
        {
            if(this.CheckCanModify() == false)
            {
                _global.SFX.PlayGUIError();
                return undefined;
            }
            _global.SFX.PlayGUISound("WeaponGUIModify");
            flash.external.ExternalInterface.call(this.ActionButtonCallback);
        }
        _global.SFX.PlayGUIError();
        return undefined;
    }
    function PerformBackAction()
    {
        if(this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_LOADOUT)
        {
            this.Exit();
        }
        else if(this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_INVENTORY)
        {
            this.ToggleSelectWeaponSlot(this.SelectedWeaponSlot.SlotID);
        }
    }
    function SwitchToWeaponSelection()
    {
        if(this.CurrentWeaponSlot != undefined)
        {
            if(this.SelectedWeaponSlot == undefined)
            {
                this.ToggleSelectWeaponSlot(this.CurrentWeaponSlot.SlotID);
                return undefined;
            }
            this.State = screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_INVENTORY;
            flash.external.ExternalInterface.call("SwitchToWeaponSelection",this.SelectedWeaponSlot.CategoryID);
            this.WeaponSelect.EnterSelectionMode();
            _global.SFX.PlayGUISound("WeaponGUIListSelectionChange");
            if(com.XPlatform.IsConsoleLayout(_global.SFX.Platform))
            {
                _root.ConsoleButtons.ControlA.SetText(this.m_sSelectWeaponButtonText);
                _root.ConsoleButtons.ControlB.SetText(this.m_sReturnToLoadoutText);
                _root.ConsoleButtons.ControlB.SetVisible(false);
                _root.ConsoleButtons.ControlX.SetVisible(this.CheckCanModify());
                _root.ConsoleButtons.ControlY.SetVisible(this.WeaponSelect.m_nCurrentWeap != 0);
                this.wpnNoWeapText._visible = false;
            }
            else
            {
                _root.PCButtonRight.SetText(this.m_sReturnToLoadoutText);
            }
        }
    }
    function SwitchToWeaponLoadout()
    {
        if(this.SelectedWeaponSlot != undefined)
        {
            this.ToggleSelectWeaponSlot(this.SelectedWeaponSlot.SlotID);
            return undefined;
        }
        this.WeaponSelect.ExitSelectionMode();
        flash.external.ExternalInterface.call("SwitchToWeaponLoadout");
        this.State = screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_LOADOUT;
        if(com.XPlatform.IsConsoleLayout(_global.SFX.Platform))
        {
            _root.ConsoleButtons.ControlA.SetText(!this.CurrentWeaponSlot.SlotIsEmpty() ? this.m_sChangeWeaponButtonText : this.m_sEquipButtonText);
            _root.ConsoleButtons.ControlA.SetVisible(true);
            _root.ConsoleButtons.ControlB.SetText(this.m_sExitButtonText);
            _root.ConsoleButtons.ControlB.SetVisible(true);
            _root.ConsoleButtons.ControlY.SetVisible(!this.CurrentWeaponSlot.SlotIsEmpty());
            _root.ConsoleButtons.ControlX.SetVisible(this.CheckCanModify());
            this.wpnNoWeapText._visible = this.CurrentWeaponSlot.SlotIsEmpty();
        }
        else
        {
            _root.PCButtonRight.SetText(this.m_sExitButtonText);
            _root.PCButtonMiddle.SetVisible(false);
            _root.PCButtonLeft.SetVisible(false);
        }
    }
    function SelectNextWeapon()
    {
        if(this.SelectedWeaponSlot != undefined)
        {
            this.SelectedWeaponSlot.ShiftAnim(true);
        }
        _global.SFX.PlayGUISound("WeaponGUIListMoveWeapon");
        flash.external.ExternalInterface.call("SelectNextWeapon");
    }
    function SelectPrevWeapon()
    {
        if(this.SelectedWeaponSlot != undefined)
        {
            this.SelectedWeaponSlot.ShiftAnim(false);
        }
        _global.SFX.PlayGUISound("WeaponGUIListMoveWeapon");
        flash.external.ExternalInterface.call("SelectPrevWeapon");
    }
    function ToggleInfoDisplay()
    {
        if(this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_LOADOUT)
        {
            if(this.CurrentWeaponSlot == undefined || this.CurrentWeaponSlot.SlotIsEmpty() || this.CurrentWeaponSlot.Valid == false)
            {
                _global.SFX.PlayGUIError();
                return undefined;
            }
        }
        else if(this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_INVENTORY)
        {
            if(this.WeaponSelect.m_nCurrentWeap == 0)
            {
                _global.SFX.PlayGUIError();
                return undefined;
            }
        }
        if(!this.ShowingInfo)
        {
            this.gotoAndPlay("toInfo");
            this.ShowingInfo = true;
        }
        else
        {
            this.gotoAndPlay("toStats");
            this.ShowingInfo = false;
        }
        _global.SFX.PlayGUISound("WeaponGUIToggleInfo");
        if(_global.SFX.Platform != com.XPlatform.PC)
        {
            if(this.ShowingInfo)
            {
                _root.ConsoleButtons.ControlY.SetText(this.m_sStatsButtonText);
            }
            else
            {
                _root.ConsoleButtons.ControlY.SetText(this.m_sDescriptionButtonText);
            }
        }
    }
    function Exit()
    {
        _global.SFX.PlayGUISound("WeaponGUIExit");
        flash.external.ExternalInterface.call("Exit");
    }
    function SetVisible(bVisible)
    {
        this._visible = bVisible;
        this.InputDisabled = !bVisible;
        if(com.XPlatform.IsConsoleLayout(_global.SFX.Platform))
        {
            _root.ConsoleButtons.ControlB.SetVisible(bVisible);
            _root.ConsoleButtons.SetVisible(bVisible);
        }
        else
        {
            _root.ConsoleButtons.SetVisible(false);
        }
    }
    function SetLoading(bLoading, sText)
    {
        _root.LoadingMain._visible = bLoading;
        _root.LoadingMain.TextMovie.LoadingText.text = sText != undefined ? sText : "";
        this.SetVisible(!bLoading);
    }
    function SetWeaponAction(sText, sAction)
    {
        this.ActionButtonText = sText;
        this.ActionButtonCallback = sAction;
        if(com.XPlatform.IsConsoleLayout(_global.SFX.Platform))
        {
            _root.ConsoleButtons.ControlX.SetText(this.ActionButtonText);
            _root.ConsoleButtons.ControlX.SetVisible(this.CheckCanModify());
            this.ModDisplay.ConsoleBtnX._visible = this.CheckCanModify();
        }
        else
        {
            _root.PCButtonMiddle.SetText(this.ActionButtonText);
            _root.PCButtonMiddle.SetVisible(this.CheckCanModify());
        }
    }
    function SetWeaponSlot(nSlotID, nWeaponID, sWeaponIconResource, nWeaponIconIndex, nNumOtherWeapons, bHaveNewWeapons, nCategory, bValid, bHasModsAvailable)
    {
        if(nSlotID < 0 || nSlotID >= this.Slots.length)
        {
            return undefined;
        }
        this.Slots[nSlotID].SetDisplay(nWeaponID,sWeaponIconResource,nWeaponIconIndex,nNumOtherWeapons,bHaveNewWeapons,nCategory,bValid,bHasModsAvailable);
    }
    function SetWeaponInfoDisplay(sWeaponName, sWeaponDescription, sCategory, sWeaponImage)
    {
        this.wpnCategoryText.text = sCategory;
        this.WeaponSelect.SetName(sWeaponName);
        this.WeaponSelect.SetImage(sWeaponImage);
        this.weaponInfoMC.text = sWeaponDescription;
        this.wpnNoWeapText._visible = this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_LOADOUT && this.CurrentWeaponSlot.SlotIsEmpty();
    }
    function SetInventoryWeapon(sName, sDesc, sIconResource, bNew, nNum, nTotal, bFlourish, sClassPath)
    {
        var _loc5_ = String(flash.external.ExternalInterface.call("GetWeaponRarity",sClassPath));
        this.WeaponSelect.SetSwitchWeapon(sName,sIconResource,bNew,nNum,nTotal,bFlourish,_loc5_);
        this.weaponInfoMC.text = sDesc;
        if(this.ActionButtonText != "")
        {
            if(_global.SFX.Platform == com.XPlatform.PC)
            {
                _root.PCButtonMiddle.SetVisible(this.CheckCanModify());
            }
            else
            {
                _root.ConsoleButtons.ControlY.SetVisible(nNum != 0);
                var _loc4_ = this.CheckCanModify();
                _root.ConsoleButtons.ControlX.SetVisible(_loc4_);
                this.ModDisplay.ConsoleBtnX._visible = _loc4_;
            }
        }
    }
    function SetWeightDisplay(nPercent, nComparePct, sBarLabel, sInfo)
    {
        if(nPercent < 0 && nComparePct < 0 && sBarLabel == "" && sInfo == "")
        {
            this.weightDisplay._visible = false;
            return undefined;
        }
        this.weightDisplay._visible = true;
        nPercent = Math.min(101,Math.max(1,nPercent + 1));
        this.weightDisplay.weightBar.gotoAndStop(nPercent);
        this.weightDisplay.barLabel.text = sBarLabel;
        this.weightDisplay.infoText.text = sInfo;
        if(nComparePct >= 0)
        {
            nComparePct = Math.min(101,Math.max(1,nComparePct + 1));
            this.weightDisplay.weightBar.currentIndicator._visible = true;
            this.weightDisplay.weightBar.currentIndicator.gotoAndStop(nComparePct);
        }
        else
        {
            this.weightDisplay.weightBar.currentIndicator._visible = false;
        }
    }
    function SetSlotNewIcon(nSlotID, bHasNew)
    {
        if(nSlotID < 0 || nSlotID >= this.Slots.length)
        {
            return undefined;
        }
        this.Slots[nSlotID].SetNew(bHasNew);
    }
    function ScrollInfoText(nScrollDelta)
    {
        if(Math.abs(nScrollDelta) >= 0.7)
        {
            this.weaponInfoMC.scrollByTime(nScrollDelta <= 0 ? com.bioware.masseffect.controls.Marquee.SCROLL_CONTENT_DOWN : com.bioware.masseffect.controls.Marquee.SCROLL_CONTENT_UP,Math.abs(nScrollDelta));
        }
        else
        {
            this.weaponInfoMC.ResetScrollTime();
        }
    }
    function PerformPlayerWeaponAction(bSelect)
    {
        if(bSelect)
        {
            this.PerformAction();
        }
    }
    function SelectWeaponSlot(nSlotID)
    {
        if(nSlotID < 0 || nSlotID >= this.Slots.length)
        {
            _global.SFX.PlayGUIError();
            return undefined;
        }
        if(this.SelectedWeaponSlot == this.Slots[nSlotID])
        {
            return undefined;
        }
        if(this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_INVENTORY && this.SelectedWeaponSlot != undefined)
        {
            this.PerformBackAction();
        }
        if(this.CurrentWeaponSlot != undefined)
        {
            this.TurnOffWeaponSlot(this.CurrentWeaponSlot.SlotID);
        }
        this.TurnOnWeaponSlot(nSlotID);
    }
    function ClearWeaponStatsDisplay()
    {
        this.Stats.Reset();
    }
    function AddWeaponStat(sName, nValue, nBonus, nCompare)
    {
        this.Stats.AddBar({name:sName,value:nValue,bonus:nBonus,compare:nCompare});
    }
    function SetModDisplay(nDisplay, sName, sImagePath)
    {
        var _loc2_ = nDisplay != 1 ? this.ModDisplay.Mod2 : this.ModDisplay.Mod1;
        if(_loc2_ == undefined)
        {
            return undefined;
        }
        _loc2_.SetName(sName);
        _loc2_.SetImage(sImagePath);
    }
    function SelectPrevHench()
    {
        if(this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_LOADOUT)
        {
            flash.external.ExternalInterface.call("SelectPreviousHenchman");
        }
        else
        {
            _global.SFX.PlayGUIError();
        }
    }
    function SelectNextHench()
    {
        if(this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_LOADOUT)
        {
            flash.external.ExternalInterface.call("SelectNextHenchman");
        }
        else
        {
            _global.SFX.PlayGUIError();
        }
    }
    function TEST_InitTest()
    {
        if(this.IsLoaded() == true)
        {
            delete this.onEnterFrame;
            this.TEST_DoTest();
        }
    }
    function TEST_DoTest()
    {
        this.SetLoading(false);
    }
}
