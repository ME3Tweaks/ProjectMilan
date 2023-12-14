class screens.MPMatchConsumables.MPMatchConsumables extends com.SFXScreen
{
    var m_Page;
    var m_List;
    var m_ControllerButtons;
    var m_PCBackButton;
    var m_PCButton1;
    var m_PCButton2;
    var m_Slots;
    var m_SlotItems;
    var m_Message;
    var m_Scrollbar;
    var m_DescriptionPanel;
    var m_Title;
    var srMatchConsumables = "NOLOC:Match Consumables";
    var srSelect = "NOLOC:Select";
    var srExit = "NOLOC:Back";
    var srAmmoSlot = "NOLOC:Ammo Slot";
    var srDamageSlot = "NOLOC:Damage Slot";
    var srBonusSlot = "NOLOC:Bonus Slot";
    var srGearSlot = "NOLOC:Gear Slot";
    var srNoUpgradesMessage = "NOLOC:You have no upgrades for this slot. Get some from the Reinforcements Store.";
    var srStore = "NOLOC:Store";
    var srSupplies = "NOLOC:Supplies";
    var srCap = "NOLOC:Cap";
    var srCount = "NOLOC:Total";
    var srNew = "NOLOC:New";
    var srEmpty = "NOLOC:empty";
    var srNone = "NOLOC:None";
    var PAGE_SLOTS = 0;
    var PAGE_LIST = 1;
    var m_SelectedSlot = -1;
    var m_NumSlotsLoaded = 0;
    var SLOT_NONE = -1;
    var SLOT_AMMO = 0;
    var SLOT_DAMAGE = 1;
    var SLOT_BONUS = 2;
    var SLOT_GEAR = 3;
    var SLOT_MAX = 3;
    var m_ListCategoryFilter = screens.MPMatchConsumables.MPMatchConsumables.prototype.SLOT_AMMO;
    var m_ActiveListItem = -1;
    function MPMatchConsumables()
    {
        super();
    }
    function onLoad()
    {
        super.onLoad();
        this.InitializeLocalization();
        this.SetupSlots();
        this.SetupList();
        this.SetupScrollbar();
        this.SetupButtons();
        this.ShowPage(this.PAGE_SLOTS);
    }
    function InitializeLocalization()
    {
        this.srMatchConsumables = "$" + _global.SFX.GetIniString("srMatchConsumables");
        this.srSelect = "$" + _global.SFX.GetIniString("srSelect");
        this.srExit = "$" + _global.SFX.GetIniString("srExit");
        this.srAmmoSlot = "$" + _global.SFX.GetIniString("srAmmoSlot");
        this.srDamageSlot = "$" + _global.SFX.GetIniString("srDamageSlot");
        this.srBonusSlot = "$" + _global.SFX.GetIniString("srBonusSlot");
        this.srGearSlot = "$" + _global.SFX.GetIniString("srGearSlot");
        this.srNoUpgradesMessage = "$" + _global.SFX.GetIniString("srNoUpgradesMessage");
        this.srStore = "$" + _global.SFX.GetIniString("srStore");
        this.srSupplies = "$" + _global.SFX.GetIniString("srSupplies");
        this.srCap = "$" + _global.SFX.GetIniString("srCap");
        this.srCount = "$" + _global.SFX.GetIniString("srCount");
        this.srNew = "$" + _global.SFX.GetIniString("srNew");
        this.srEmpty = "$" + _global.SFX.GetIniString("srEmpty");
        this.srNone = "$" + _global.SFX.GetIniString("srNone");
    }
    function ShowPage(page)
    {
        this.m_Page = page;
        if(this.m_Page == this.PAGE_LIST)
        {
            this.m_List.GiveFocus();
        }
        this.RefreshScreen();
    }
    function SetupButtons()
    {
        this.m_ControllerButtons = _root.mcControllerButtons;
        this.m_PCBackButton = _root.m_PCBackButton;
        this.m_PCButton1 = _root.m_PCButton1;
        this.m_PCButton2 = _root.m_PCButton2;
        if(_global.SFX.Platform == com.XPlatform.PC)
        {
            this.m_ControllerButtons._visible = false;
            this.m_PCBackButton.SetVisible(true);
            this.m_PCBackButton.SetEnabled(true);
            this.m_PCButton1.SetVisible(false);
            this.m_PCButton1.SetEnabled(false);
            this.m_PCButton2.SetVisible(true);
            this.m_PCButton2.SetEnabled(true);
            this.m_PCBackButton.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.onBack));
            this.m_PCButton2.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.ShowStoreScreen));
        }
        else
        {
            this.m_PCBackButton.SetVisible(false);
            this.m_PCBackButton.SetEnabled(false);
            this.m_PCButton1.SetVisible(false);
            this.m_PCButton1.SetEnabled(false);
            this.m_PCButton2.SetVisible(false);
            this.m_PCButton2.SetEnabled(false);
            this.m_ControllerButtons._visible = true;
            this.m_ControllerButtons.addEventListener("onButtonX",mx.utils.Delegate.create(this,this.ShowStoreScreen));
            this.m_ControllerButtons.addEventListener("onButtonA",mx.utils.Delegate.create(this,this.onAButton));
            this.m_ControllerButtons.addEventListener("onButtonB",mx.utils.Delegate.create(this,this.onBack));
            this.m_ControllerButtons.addEventListener("onDPadUp",mx.utils.Delegate.create(this,this.onDPadUp));
            this.m_ControllerButtons.addEventListener("onDPadDown",mx.utils.Delegate.create(this,this.onDPadDown));
            this.m_ControllerButtons.addEventListener("onDPadLeft",mx.utils.Delegate.create(this,this.onDPadLeft));
            this.m_ControllerButtons.addEventListener("onDPadRight",mx.utils.Delegate.create(this,this.onDPadRight));
            this.m_ControllerButtons.addEventListener("onInvalidInput",mx.utils.Delegate.create(this,this.onInvalidInput));
            this.m_ControllerButtons.ControlY.Active = false;
            this.m_ControllerButtons.ControlY.SetVisible(false);
            this.m_ControllerButtons.FitLeft();
        }
        this.RefreshButtons();
    }
    function SetupSlots()
    {
        this.m_Slots = _root.slots;
        this.SLOT_MAX = Number(flash.external.ExternalInterface.call("GetMaxActiveConsumables"));
        if(this.SLOT_MAX == 3)
        {
            this.m_Slots.gotoAndStop("slots3");
            this.m_Slots.slotGear._visible = false;
        }
        else if(this.SLOT_MAX == 4)
        {
            this.m_Slots.gotoAndStop("slots4");
            this.m_Slots.slotGear._visible = true;
        }
        this.m_SlotItems = new Array();
        this.m_SlotItems[this.SLOT_AMMO] = this.m_Slots.slotAmmo;
        this.m_SlotItems[this.SLOT_DAMAGE] = this.m_Slots.slotDamage;
        this.m_SlotItems[this.SLOT_BONUS] = this.m_Slots.slotBonus;
        this.m_SlotItems[this.SLOT_GEAR] = this.m_Slots.slotGear;
        this.m_Slots.slotAmmo.action = this.MakeDelegate(this.ShowAmmoList);
        this.m_Slots.slotDamage.action = this.MakeDelegate(this.ShowDamageList);
        this.m_Slots.slotBonus.action = this.MakeDelegate(this.ShowBonusList);
        this.m_Slots.slotGear.action = this.MakeDelegate(this.ShowGearList);
        if(_global.SFX.Platform != com.XPlatform.PC)
        {
            this.m_SelectedSlot = this.SLOT_AMMO;
        }
    }
    function OnSlotLoaded()
    {
        this.m_NumSlotsLoaded = this.m_NumSlotsLoaded + 1;
        if(this.m_NumSlotsLoaded == this.SLOT_MAX)
        {
            this.RefreshSlots();
        }
    }
    function RefreshSlots()
    {
        if(this.m_Page == this.PAGE_SLOTS)
        {
            this.m_Slots._visible = true;
            this.m_Slots.slotAmmo.Initialize(this.SLOT_AMMO,this.srAmmoSlot);
            this.m_Slots.slotDamage.Initialize(this.SLOT_DAMAGE,this.srDamageSlot);
            this.m_Slots.slotBonus.Initialize(this.SLOT_BONUS,this.srBonusSlot);
            this.m_Slots.slotGear.Initialize(this.SLOT_GEAR,this.srGearSlot);
            var _loc5_ = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetActiveConsumables"));
            var _loc3_ = 0;
            while(_loc3_ < _loc5_.length)
            {
                var _loc6_ = Number(flash.external.ExternalInterface.call("GetSlotTypeForCategory",_loc5_[_loc3_].Category));
                var _loc4_ = this.GetSlotItemByType(_loc6_);
                if(_loc4_ != null)
                {
                    _loc4_.SetConsumable(_loc5_[_loc3_]);
                }
                _loc3_ = _loc3_ + 1;
            }
            if(_global.SFX.Platform != com.XPlatform.PC)
            {
                _loc3_ = 0;
                while(_loc3_ < this.SLOT_MAX)
                {
                    this.m_SlotItems[_loc3_].selected = this.m_SelectedSlot == _loc3_;
                    _loc3_ = _loc3_ + 1;
                }
            }
        }
        else if(this.m_Page == this.PAGE_LIST)
        {
            this.m_Slots._visible = false;
        }
    }
    function ShowAmmoList()
    {
        this.m_ListCategoryFilter = this.SLOT_AMMO;
        this.ShowPage(this.PAGE_LIST);
    }
    function ShowDamageList()
    {
        this.m_ListCategoryFilter = this.SLOT_DAMAGE;
        this.ShowPage(this.PAGE_LIST);
    }
    function ShowBonusList()
    {
        this.m_ListCategoryFilter = this.SLOT_BONUS;
        this.ShowPage(this.PAGE_LIST);
    }
    function ShowGearList()
    {
        this.m_ListCategoryFilter = this.SLOT_GEAR;
        this.ShowPage(this.PAGE_LIST);
    }
    function GetSlotItemByType(slotType)
    {
        return this.m_SlotItems[slotType];
    }
    function SetupList()
    {
        this.m_List.addEventListener("onChange",mx.utils.Delegate.create(this,this.onListChanged));
        this.m_Message._visible = false;
        this.m_Message.text = this.srNoUpgradesMessage;
    }
    function SetupScrollbar()
    {
        this.m_List.setupScrollBar(this.m_Scrollbar);
        this.m_List.SetPlatformLayout(_global.SFX.Platform);
    }
    function RefreshButtons()
    {
        this.m_PCButton2.SetText(this.srStore);
        this.m_PCBackButton.SetText(this.srExit);
        this.m_ControllerButtons.ControlX.SetText(this.srStore);
        this.m_ControllerButtons.ControlA.SetText(this.srSelect);
        this.m_ControllerButtons.ControlB.SetText(this.srExit);
        if(this.m_Page == this.PAGE_LIST && this.m_List.length == 0)
        {
            this.m_ControllerButtons.ControlA.SetEnabled(false);
        }
        else
        {
            this.m_ControllerButtons.ControlA.SetEnabled(true);
        }
    }
    function RefreshSelectionArrows()
    {
        var _loc2_ = undefined;
        _loc2_ = screens.MPMatchConsumables.ConsumableListItem(this.m_List.selectedItem);
        if(_loc2_ != null)
        {
            _loc2_.DownArrow._visible = true;
            _loc2_.UpArrow._visible = true;
            if(this.m_List.selectedIndex == this.m_List.length - 1)
            {
                _loc2_.DownArrow._visible = false;
            }
            if(this.m_List.selectedIndex == 0)
            {
                _loc2_.UpArrow._visible = false;
            }
        }
    }
    function onAButton()
    {
        if(this.m_Page == this.PAGE_LIST)
        {
            if(this.m_List.selectedIndex != -1 && this.m_List.selectedItem.active)
            {
                _global.SFX.PlayGUISound("MPMatchConsumablesSelect");
            }
            else
            {
                _global.SFX.PlayGUIError();
            }
        }
        this.onSelect();
    }
    function onSelect()
    {
        if(this.m_Page == this.PAGE_SLOTS)
        {
            this.m_SlotItems[this.m_SelectedSlot].Activate();
        }
        else if(this.m_Page == this.PAGE_LIST)
        {
            if(this.m_List.selectedIndex != -1 && this.m_List.selectedItem.active)
            {
                var _loc2_ = this.m_List.selectedItem.ConsumableID;
                var _loc3_ = this.m_List.selectedItem.Version;
                var _loc4_ = flash.external.ExternalInterface.call("GetConsumable_DLC",_loc2_,_loc3_);
                flash.external.ExternalInterface.call("SetConsumableActive_DLC",_loc2_,_loc3_,!_loc4_.Active);
                this.RefreshList();
            }
        }
    }
    function onBack()
    {
        if(this.m_Page == this.PAGE_SLOTS)
        {
            this.m_ControllerButtons.InputDisabled = true;
            flash.external.ExternalInterface.call("ExitScreen");
        }
        else if(this.m_Page == this.PAGE_LIST)
        {
            flash.external.ExternalInterface.call("ClearNewFlagsForSlotType",this.m_ListCategoryFilter);
            this.ShowPage(this.PAGE_SLOTS);
            _global.SFX.PlayGUISound("MPMatchConsumablesShowGroup");
        }
    }
    function onDPadUp(p_event)
    {
        if(this.m_Page == this.PAGE_LIST)
        {
            if(this.m_List.selectedIndex > 0)
            {
                this.m_List.selectedIndex = this.m_List.selectedIndex - 1;
                _global.SFX.PlayGUISound("MPMatchConsumablesChanged");
            }
            else
            {
                _global.SFX.PlayGUIError();
            }
        }
        else if(this.m_Page == this.PAGE_SLOTS)
        {
            if(this.NavigateSlots(com.XInput.DPadUp))
            {
                _global.SFX.PlayGUISound("MPMatchConsumablesGroupChanged");
                this.RefreshSlots();
            }
            else
            {
                _global.SFX.PlayGUIError();
            }
        }
    }
    function onDPadDown(p_event)
    {
        if(this.m_Page == this.PAGE_LIST)
        {
            if(this.m_List.selectedIndex < this.m_List.GetListCount() - 1)
            {
                this.m_List.selectedIndex = this.m_List.selectedIndex + 1;
                _global.SFX.PlayGUISound("MPMatchConsumablesChanged");
            }
            else
            {
                _global.SFX.PlayGUIError();
            }
        }
        else if(this.m_Page == this.PAGE_SLOTS)
        {
            if(this.NavigateSlots(com.XInput.DPadDown))
            {
                _global.SFX.PlayGUISound("MPMatchConsumablesGroupChanged");
                this.RefreshSlots();
            }
            else
            {
                _global.SFX.PlayGUIError();
            }
        }
    }
    function onDPadLeft(p_event)
    {
        if(this.m_Page == this.PAGE_SLOTS)
        {
            if(this.NavigateSlots(com.XInput.DPadLeft))
            {
                _global.SFX.PlayGUISound("MPMatchConsumablesGroupChanged");
                this.RefreshSlots();
            }
            else
            {
                _global.SFX.PlayGUIError();
            }
        }
    }
    function onDPadRight(p_event)
    {
        if(this.m_Page == this.PAGE_SLOTS)
        {
            if(this.NavigateSlots(com.XInput.DPadRight))
            {
                _global.SFX.PlayGUISound("MPMatchConsumablesGroupChanged");
                this.RefreshSlots();
            }
            else
            {
                _global.SFX.PlayGUIError();
            }
        }
    }
    function onInvalidInput(p_event)
    {
        _global.SFX.PlayGUIError();
    }
    function onListChanged(p_event)
    {
        this.RefreshDescription();
        this.RefreshSelectionArrows();
        this.RefreshButtons();
    }
    function onListItemDo(p_event)
    {
        this.onSelect();
    }
    function BuildList()
    {
        if(this.m_Page == this.PAGE_LIST)
        {
            this.m_List.killMenu();
            var _loc3_ = undefined;
            var _loc4_ = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetConsumableListFilteredBySlot_DLC",this.m_ListCategoryFilter));
            var _loc2_ = 0;
            while(_loc2_ < _loc4_.length)
            {
                _loc3_ = screens.MPMatchConsumables.ConsumableListItem(this.m_List.addEntry(_loc2_,{index:_loc2_}));
                _loc3_.addEventListener("VListItem_DoAction",mx.utils.Delegate.create(this,this.onListItemDo));
                _loc3_.Refresh(_loc4_[_loc2_]);
                _loc2_ = _loc2_ + 1;
            }
        }
        this.RefreshList();
    }
    function RefreshList()
    {
        if(this.m_Page == this.PAGE_SLOTS)
        {
            this.m_Scrollbar._visible = false;
            this.m_List._visible = false;
            this.m_DescriptionPanel._visible = false;
            this.m_Message._visible = false;
        }
        else if(this.m_Page == this.PAGE_LIST)
        {
            this.m_List._visible = true;
            this.m_DescriptionPanel._visible = true;
            var _loc7_ = 0;
            var _loc8_ = this.m_List.movementRefElementIndex;
            if(this.m_List.length > 0)
            {
                if(this.m_List.selectedIndex == -1 && _global.SFX.Platform != com.XPlatform.PC)
                {
                    this.m_List.selectedIndex = 0;
                }
                _loc7_ = this.m_List.selectedIndex;
            }
            this.m_ActiveListItem = -1;
            var _loc6_ = undefined;
            var _loc4_ = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetConsumableListFilteredBySlot_DLC",this.m_ListCategoryFilter));
            var _loc3_ = 0;
            while(_loc3_ < _loc4_.length)
            {
                var _loc5_ = this.GetConsumableListIndexWithID(_loc4_[_loc3_].ConsumableID,_loc4_[_loc3_].Version);
                if(_loc5_ >= 0)
                {
                    _loc6_ = screens.MPMatchConsumables.ConsumableListItem(this.m_List.getListItem(_loc5_));
                    _loc6_.Refresh(_loc4_[_loc3_]);
                    if(_loc4_[_loc3_].Active)
                    {
                        this.m_ActiveListItem = _loc5_;
                    }
                }
                _loc3_ = _loc3_ + 1;
            }
            if(_loc7_ >= _loc4_.length)
            {
                _loc7_ = _loc4_.length - 1;
            }
            this.m_List.SnapNextListMovement = true;
            this.m_List.movementRefElementIndex = _loc8_;
            this.m_List.selectedIndex = _loc7_;
            this.m_List.recalcScrollBar();
            this.RefreshSelectionArrows();
            this.m_Message._visible = _loc4_.length == 0;
        }
    }
    function RefreshScreen()
    {
        this.m_Title.text = this.srMatchConsumables;
        this.RefreshSlots();
        this.RefreshInGameConsumables();
        this.BuildList();
        this.RefreshDescription();
        this.RefreshButtons();
    }
    function RefreshDescription()
    {
        if(this.m_Page == this.PAGE_SLOTS)
        {
            this.m_DescriptionPanel._visible = false;
        }
        else if(this.m_Page == this.PAGE_LIST)
        {
            if(this.m_List.length > 0)
            {
                if(this.m_List.selectedIndex == -1 || this.m_List.selectedItem.active == false)
                {
                    if(this.m_ActiveListItem != -1)
                    {
                        this.RefreshDescriptionWithListItem(screens.MPMatchConsumables.ConsumableListItem(this.m_List.getListItem(this.m_ActiveListItem)));
                        this.m_DescriptionPanel._visible = true;
                    }
                    else
                    {
                        this.m_DescriptionPanel._visible = false;
                    }
                }
                else
                {
                    this.RefreshDescriptionWithListItem(screens.MPMatchConsumables.ConsumableListItem(this.m_List.selectedItem));
                    this.m_DescriptionPanel._visible = true;
                }
            }
            else
            {
                this.m_DescriptionPanel._visible = false;
            }
        }
    }
    function RefreshDescriptionWithListItem(item)
    {
        var _loc2_ = flash.external.ExternalInterface.call("GetConsumable_DLC",item.ConsumableID,item.Version);
        this.m_DescriptionPanel.image.Async = true;
        this.m_DescriptionPanel.image.ResourceString = _loc2_.Image;
        this.m_DescriptionPanel.image.FadeIn = false;
        this.m_DescriptionPanel.image.FadeOut = false;
        this.m_DescriptionPanel.title.textAutoSize = "shrink";
        this.m_DescriptionPanel.title.text = _loc2_.Title;
        this.m_DescriptionPanel.description.text = _loc2_.Description;
        this.m_DescriptionPanel.m_Scrollbar._visible = false;
    }
    function GetConsumableListIndexWithID(ConsumableID, Version)
    {
        var _loc2_ = 0;
        while(_loc2_ < this.m_List.length)
        {
            var _loc3_ = screens.MPMatchConsumables.ConsumableListItem(this.m_List.getListItem(_loc2_));
            if(_loc3_.ConsumableID == ConsumableID && _loc3_.Version == Version)
            {
                return _loc2_;
            }
            _loc2_ = _loc2_ + 1;
        }
        return -1;
    }
    function ShowStoreScreen()
    {
        this.m_ControllerButtons.InputDisabled = true;
        flash.external.ExternalInterface.call("ShowStoreScreen");
    }
    function RefreshInGameConsumables()
    {
        var _loc4_ = _root.slots.inGameConsumables;
        var _loc5_ = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetInGameConsumableInfo"));
        if(_global.SFX.Platform == com.XPlatform.PC)
        {
            _loc4_.gotoAndStop("PC");
        }
        else if(_global.SFX.Platform == com.XPlatform.XBox)
        {
            _loc4_.gotoAndStop("Console");
            _loc4_.Dpad.gotoAndStop("xbox");
        }
        else if(_global.SFX.Platform == com.XPlatform.PS3)
        {
            _loc4_.gotoAndStop("Console");
            _loc4_.Dpad.gotoAndStop("ps3");
        }
        _loc4_.m_Title.text = this.srSupplies;
        this.RefreshInGameConsumable(_loc4_.Power01,_loc5_[0]);
        this.RefreshInGameConsumable(_loc4_.Power02,_loc5_[1]);
        this.RefreshInGameConsumable(_loc4_.Power03,_loc5_[2]);
        this.RefreshInGameConsumable(_loc4_.Power04,_loc5_[3]);
    }
    function RefreshInGameConsumable(mc, data)
    {
        mc.icon.RegistrationPoint = com.bioware.masseffect.controls.ResourceLoader.REGISTRATION_TOP_LEFT;
        mc.icon.SetIcon(data.ConsumableIconResource,data.ConsumableIconIndex);
        mc.supply.text = data.ConsumableName;
        mc.capText.text = this.srCap;
        mc.cap.text = Math.min(data.ConsumableCap,data.ConsumableCount);
        mc.countText.text = this.srCount;
        mc.count.text = data.ConsumableCount;
    }
    function NavigateSlots(nDirection)
    {
        var _loc2_ = new Object();
        if(this.SLOT_MAX == 3)
        {
            _loc2_[com.XInput.DPadUp] = [-1,0,0];
            _loc2_[com.XInput.DPadDown] = [1,-1,-1];
            _loc2_[com.XInput.DPadLeft] = [-1,-1,1];
            _loc2_[com.XInput.DPadRight] = [-1,2,-1];
        }
        else if(this.SLOT_MAX == 4)
        {
            _loc2_[com.XInput.DPadUp] = [-1,-1,0,1];
            _loc2_[com.XInput.DPadDown] = [2,3,-1,-1];
            _loc2_[com.XInput.DPadLeft] = [-1,0,-1,2];
            _loc2_[com.XInput.DPadRight] = [1,-1,3,-1];
        }
        var _loc3_ = _loc2_[nDirection][this.m_SelectedSlot];
        if(_loc3_ != -1)
        {
            this.m_SelectedSlot = _loc3_;
            return true;
        }
        return false;
    }
}
