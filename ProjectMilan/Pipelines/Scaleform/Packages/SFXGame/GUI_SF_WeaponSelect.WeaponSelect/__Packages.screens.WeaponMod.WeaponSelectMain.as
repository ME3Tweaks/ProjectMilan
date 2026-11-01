class screens.WeaponMod.WeaponSelectMain extends com.SFXInputMovieClip
{
   var ActionButtonCallback;
   var ActionButtonText;
   var CurrentWeaponSlot;
   var InputTitle;
   var IsLoaded;
   var LastBottomSlot;
   var LastTopSlot;
   var MakeDelegate;
   var ModDisplay;
   var SelectedWeaponSlot;
   var ShowingInfo;
   var Slot1;
   var Slot2;
   var Slot3;
   var Slot4;
   var Slot5;
   var Slot6;
   var bHeavyFocused = false;
   var bEditingHeavy = false;
   var HeavyModFade;
   var HeavyModTarget = 100;
   var HeavyModTime;
   var Slots;
   var State;
   var Stats;
   var WeaponSelect;
   var _visible;
   var addEventListener;
   var gotoAndPlay;
   var m_fnBackAction;
   var m_fnMainAction;
   var m_fnWeapAction;
   var m_sChangeWeaponButtonText;
   var m_sDescriptionButtonText;
   var m_sEquipButtonText;
   var m_sExitButtonText;
   var m_sReturnToLoadoutText;
   var m_sSelectWeaponButtonText;
   var m_sStatsButtonText;
   var onEnterFrame;
   var weaponInfoMC;
   var weightDisplay;
   var wpnCategoryText;
   var wpnNoWeapText;
   static var STATE_NAVIGATE_LOADOUT = 0;
   static var STATE_NAVIGATE_INVENTORY = 1;
   var bUsingGamepad = false;
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
      this.Slots = new Array(this.Slot1,this.Slot2,this.Slot3,this.Slot4,this.Slot5,this.Slot6);
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
      // The movie is shared with SP: its sixth slot is enabled only by the MP handler.
      this.Slot6._visible = _global.SFX.IsMPLobby;
      if(!_global.SFX.IsMPLobby)
      {
         this.Slot1._x = -361.95;
         this.Slot2._x = -120;
      }
      if(_global.SFX.IsMPLobby)
      {
         this.FitTopConnector(this.Slot1,-7239,9164);
         this.FitTopConnector(this.Slot2,-2400,4364);
         this.FitTopConnector(this.Slot6,-7239,9164);
      }
      this.SetLoading(true);
      this.m_fnMainAction = this.MakeDelegate(this.PerformAction);
      this.m_fnBackAction = this.MakeDelegate(this.PerformBackAction);
      this.m_fnWeapAction = this.MakeDelegate(this.PerformWeaponAction);
      if(_global.SFX.Platform == com.XPlatform.PC)
      {
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
         this.WeaponSelect.addEventListener("toggleInfoDisplay",this.MakeDelegate(this.ToggleInfoDisplay));
         _root.PCButtonRight.SetText(this.m_sExitButtonText);
         _root.PCButtonRight.addEventListener("SFXButton_onRelease",this.MakeDelegate(this.m_fnBackAction));
         _root.PCButtonMiddle.addEventListener("SFXButton_onRelease",this.MakeDelegate(this.m_fnWeapAction));
         _root.PCButtonLeft.SetText(this.m_sSelectWeaponButtonText);
         _root.PCButtonLeft.addEventListener("SFXButton_onRelease",this.MakeDelegate(this.m_fnMainAction));
         this.ModDisplay.onRelease = this.MakeDelegate(this.m_fnWeapAction);
      }
      this.addEventListener("onInvalidInput",this.MakeDelegate(this.HandleInvalidInput));
      this.addEventListener("onDPadUp",this.MakeDelegate(this.MoveSelectionUp));
      this.addEventListener("onDPadDown",this.MakeDelegate(this.MoveSelectionDown));
      this.addEventListener("onDPadLeft",this.MakeDelegate(this.MoveSelectionLeft));
      this.addEventListener("onDPadRight",this.MakeDelegate(this.MoveSelectionRight));
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
      _root.ConsoleButtons.ControlB.SetText(this.m_sExitButtonText);
      _root.ConsoleButtons.ControlX.SetText("");
      _root.ConsoleButtons.ControlY.SetText(this.m_sDescriptionButtonText);
      _root.ConsoleButtons.FitLeft();
      if(_global.SFX.Platform == com.XPlatform.PC && !this.bUsingGamepad)
      {
         _root.ConsoleButtons._visible = false;
         _root.PCButtonRight.SetVisible(true);
         _root.PCButtonMiddle.SetVisible(false);
         _root.PCButtonLeft.SetVisible(false);
      }
      else
      {
         _root.ConsoleButtons._visible = true;
         _root.ConsoleButtons.ControlA.SetVisible(false);
         _root.ConsoleButtons.ControlB.SetVisible(false);
         _root.ConsoleButtons.ControlX.SetVisible(false);
         _root.ConsoleButtons.ControlY.SetVisible(false);
         _root.ConsoleButtons.FitLeft();
         _root.PCButtonLeft.SetVisible(false);
         _root.PCButtonMiddle.SetVisible(false);
         _root.PCButtonRight.SetVisible(false);
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
      var _loc5_ = this.ModDisplay.wpnModsText._x + this.ModDisplay.wpnModsText._width * 0.5 + this.ModDisplay.wpnModsText.textWidth * 0.5;
      this.ModDisplay.ConsoleBtnX._x = _loc5_ + this.ModDisplay.ConsoleBtnX._width * 0.5;
      this.ModDisplay.ConsoleBtnX._visible = false;
   }
   function TurnOnWeaponSlot(nSlotID)
   {
      if(nSlotID < 0 || nSlotID >= this.Slots.length)
      {
         return undefined;
      }
      var _loc4_;
      if(this.SelectedWeaponSlot == undefined)
      {
         this.Slots[nSlotID].SetDesiredState(screens.WeaponMod.WeaponSlot.STATE_ON);
         this.CurrentWeaponSlot = this.Slots[nSlotID];
         this.SetHeavyFocus(nSlotID == 5);
         if(_global.SFX.IsMPLobby) flash.external.ExternalInterface.call("HeavyWeaponFocused",nSlotID == 5);
         if(nSlotID != 5)
         {
            flash.external.ExternalInterface.call("WeaponLoadoutItemChanged",this.CurrentWeaponSlot.WeaponID,this.CurrentWeaponSlot.CategoryID);
         }
         _global.SFX.PlayGUISound("WeaponGUIListMove");
         _loc4_ = 0;
         while(_loc4_ < this.Slots.length)
         {
            if(_loc4_ != nSlotID)
            {
               this.Slots[_loc4_].SetDesiredState(screens.WeaponMod.WeaponSlot.STATE_OFF);
            }
            _loc4_ = _loc4_ + 1;
         }
         _root.ConsoleButtons.ControlA.SetText(!this.CurrentWeaponSlot.SlotIsEmpty() ? this.m_sChangeWeaponButtonText : this.m_sEquipButtonText);
         if(_global.SFX.Platform != com.XPlatform.PC || this.bUsingGamepad)
         {
            _root.ConsoleButtons.ControlA.SetVisible(true);
            _root.ConsoleButtons.ControlX.SetVisible(this.CheckCanModify());
            _root.ConsoleButtons.ControlY.SetVisible(!this.bHeavyFocused && !this.CurrentWeaponSlot.SlotIsEmpty());
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
            if(nSlotID != 5)
            {
               flash.external.ExternalInterface.call("WeaponLoadoutItemChanged",-1,-1);
            }
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
      var _loc4_;
      if(this.SelectedWeaponSlot != undefined && this.SelectedWeaponSlot != this.Slots[nSlotID])
      {
         _loc4_ = this.SelectedWeaponSlot.SlotID;
         // Leaving a slot confirms its current choice, as for regular weapons.
         this.ToggleSelectWeaponSlot(_loc4_);
         // A regular weapon can refuse to equip; keep its selection in that case.
         if(this.SelectedWeaponSlot != undefined) return undefined;
         this.TurnOffWeaponSlot(_loc4_);
         this.TurnOnWeaponSlot(nSlotID);
      }
      if(nSlotID == 5)
      {
         // Mouse hover cannot move focus while another slot is selected.
         // Bind the action to the clicked slot before beginning its selection.
         if(this.CurrentWeaponSlot != this.Slot6) this.TurnOnWeaponSlot(5);
         if(!this.bEditingHeavy && this.Slot6.WeaponsInCategory == 0)
         {
            _global.SFX.PlayGUIError();
            return undefined;
         }
         _global.SFX.PlayGUISound(this.bEditingHeavy ? "WeaponGUIAcceptSelection" : "WeaponGUIListSelectionChange");
         flash.external.ExternalInterface.call(this.bEditingHeavy ? "AcceptHeavyWeaponSelection" : "BeginHeavyWeaponSelection");
         return undefined;
      }
      var _loc5_;
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
         _loc5_ = Boolean(flash.external.ExternalInterface.call("CheckCanEquipWeapon",this.SelectedWeaponSlot.CategoryID));
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
      return this.LastTopSlot == 0 ? 2 : (this.LastTopSlot == 5 ? 3 : 4);
   }
   function GetBestTopRowSlot()
   {
      return this.LastBottomSlot == 2 ? 0 : (this.LastBottomSlot == 3 ? 5 : 1);
   }
   // Six physical positions; slot IDs retain the existing regular category mapping.
   // Top: sniper, heavy, assault. Bottom: SMG, shotgun, pistol.
   function MoveGridSelection(dx,dy)
   {
      if(this.State != screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_LOADOUT || this.SelectedWeaponSlot != undefined)
      {
         _global.SFX.PlayGUIError();
         return undefined;
      }
      if(this.CurrentWeaponSlot == undefined)
      {
         this.TurnOnWeaponSlot(0);
         return undefined;
      }
      var grid = [[0,5,1],[2,3,4]];
      for(var row = 0; row < 2; row++)
      {
         for(var col = 0; col < 3; col++)
         {
            if(grid[row][col] == this.CurrentWeaponSlot.SlotID)
            {
               var nextRow = row + dy;
               var nextCol = col + dx;
               if(nextRow < 0 || nextRow >= 2 || nextCol < 0 || nextCol >= 3)
               {
                  _global.SFX.PlayGUIError();
                  return undefined;
               }
               this.LastTopSlot = grid[0][col];
               this.LastBottomSlot = grid[1][col];
               var nextSlot = grid[nextRow][nextCol];
               if(nextSlot == 5 && !this.Slot6._visible)
               {
                  if(dx != 0)
                  {
                     nextCol += dx;
                     if(nextCol < 0 || nextCol >= 3) return undefined;
                     nextSlot = grid[nextRow][nextCol];
                  }
                  else
                  {
                     nextSlot = 0;
                  }
               }
               this.SelectWeaponSlot(nextSlot);
               return undefined;
            }
         }
      }
   }
   function MoveSelectionUp()
   {
      this.MoveGridSelection(0,-1);
   }
   function MoveSelectionDown()
   {
      this.MoveGridSelection(0,1);
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
      this.MoveGridSelection(-1,0);
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
      this.MoveGridSelection(1,0);
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
      if(this.CurrentWeaponSlot != undefined && this.CurrentWeaponSlot.SlotID == 5)
      {
         var openingHeavy = !this.bEditingHeavy;
         this.ToggleSelectWeaponSlot(5);
         if(openingHeavy && this.Slot6.WeaponsInCategory > 0) _global.SFX.PlayGUISound("WeaponGUIOpenSelect");
         return undefined;
      }
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
      if(this.CurrentWeaponSlot != undefined && this.CurrentWeaponSlot.SlotID == 5)
      {
         return false;
      }
      if(this.CurrentWeaponSlot == undefined || this.CurrentWeaponSlot.SlotIsEmpty() && this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_LOADOUT || this.CurrentWeaponSlot.Valid == false || this.ActionButtonCallback == "" || this.WeaponSelect.m_nCurrentWeap == 0 && this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_INVENTORY || this.CurrentWeaponSlot.HasModsAvailable == false)
      {
         return false;
      }
      return true;
   }
   function PerformWeaponAction()
   {
      if(this.bHeavyFocused) return undefined;
      if(!(this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_INVENTORY || _global.SFX.Platform != com.XPlatform.PC || this.bUsingGamepad))
      {
         _global.SFX.PlayGUIError();
         return undefined;
      }
      if(this.CheckCanModify() == false)
      {
         _global.SFX.PlayGUIError();
         return undefined;
      }
      _global.SFX.PlayGUISound("WeaponGUIModify");
      flash.external.ExternalInterface.call(this.ActionButtonCallback);
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
         if(_global.SFX.Platform == com.XPlatform.PC)
         {
            _root.PCButtonRight.SetText(this.m_sReturnToLoadoutText);
         }
         _root.ConsoleButtons.ControlA.SetText(this.m_sSelectWeaponButtonText);
         _root.ConsoleButtons.ControlB.SetText(this.m_sReturnToLoadoutText);
         if(_global.SFX.Platform != com.XPlatform.PC || this.bUsingGamepad)
         {
            _root.ConsoleButtons.ControlB.SetVisible(false);
            _root.ConsoleButtons.ControlX.SetVisible(this.CheckCanModify());
            _root.ConsoleButtons.ControlY.SetVisible(!this.bHeavyFocused && this.WeaponSelect.m_nCurrentWeap != 0);
            this.wpnNoWeapText._visible = false;
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
      if(_global.SFX.Platform == com.XPlatform.PC)
      {
         _root.PCButtonRight.SetText(this.m_sExitButtonText);
      }
      if(_global.SFX.Platform == com.XPlatform.PC && !this.bUsingGamepad)
      {
         _root.PCButtonMiddle.SetVisible(false);
         _root.PCButtonLeft.SetVisible(false);
      }
      else
      {
         _root.ConsoleButtons.ControlA.SetText(!this.CurrentWeaponSlot.SlotIsEmpty() ? this.m_sChangeWeaponButtonText : this.m_sEquipButtonText);
         _root.ConsoleButtons.ControlA.SetVisible(true);
         _root.ConsoleButtons.ControlB.SetText(this.m_sExitButtonText);
         _root.ConsoleButtons.ControlB.SetVisible(true);
         _root.ConsoleButtons.ControlY.SetVisible(!this.bHeavyFocused && !this.CurrentWeaponSlot.SlotIsEmpty());
         _root.ConsoleButtons.ControlX.SetVisible(this.CheckCanModify());
         this.wpnNoWeapText._visible = this.CurrentWeaponSlot.SlotIsEmpty();
      }
   }
   function SelectNextWeapon()
   {
      if(this.bEditingHeavy)
      {
         if(this.WeaponSelect.m_nCurrentWeap < this.WeaponSelect.m_nTotalWeaps) this.Slot6.ShiftAnim(true);
         flash.external.ExternalInterface.call("CycleHeavyWeapon",1);
         return undefined;
      }
      if(this.SelectedWeaponSlot != undefined)
      {
         this.SelectedWeaponSlot.ShiftAnim(true);
      }
      _global.SFX.PlayGUISound("WeaponGUIListMoveWeapon");
      flash.external.ExternalInterface.call("SelectNextWeapon");
   }
   function SelectPrevWeapon()
   {
      if(this.bEditingHeavy)
      {
         if(this.WeaponSelect.m_nCurrentWeap > 1) this.Slot6.ShiftAnim(false);
         flash.external.ExternalInterface.call("CycleHeavyWeapon",-1);
         return undefined;
      }
      if(this.SelectedWeaponSlot != undefined)
      {
         this.SelectedWeaponSlot.ShiftAnim(false);
      }
      _global.SFX.PlayGUISound("WeaponGUIListMoveWeapon");
      flash.external.ExternalInterface.call("SelectPrevWeapon");
   }
   function ToggleInfoDisplay()
   {
      if(this.bHeavyFocused) return undefined;
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
      if(this.ShowingInfo)
      {
         _root.ConsoleButtons.ControlY.SetText(this.m_sStatsButtonText);
      }
      else
      {
         _root.ConsoleButtons.ControlY.SetText(this.m_sDescriptionButtonText);
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
      if(_global.SFX.Platform == com.XPlatform.PC && !this.bUsingGamepad)
      {
         _root.ConsoleButtons.SetVisible(false);
      }
      else
      {
         _root.ConsoleButtons.ControlB.SetVisible(bVisible);
         _root.ConsoleButtons.SetVisible(bVisible);
      }
   }
   function SetLoading(bLoading, sText)
   {
      _root.LoadingMain._visible = bLoading;
      _root.LoadingMain.TextMovie.LoadingText.text = sText != undefined ? sText : "";
      if(!bLoading && _global.SFX.IsMPLobby)
      {
         flash.external.ExternalInterface.call("InitializeHeavyWeaponSelector");
      }
      this.SetVisible(!bLoading);
   }
   function SetWeaponAction(sText, sAction)
   {
      this.ActionButtonText = sText;
      this.ActionButtonCallback = sAction;
      if(_global.SFX.Platform == com.XPlatform.PC)
      {
         _root.PCButtonMiddle.SetText(this.ActionButtonText);
      }
      _root.ConsoleButtons.ControlX.SetText(this.ActionButtonText);
      if(_global.SFX.Platform == com.XPlatform.PC && !this.bUsingGamepad)
      {
         _root.PCButtonMiddle.SetVisible(this.CheckCanModify());
      }
      else
      {
         _root.ConsoleButtons.ControlX.SetVisible(this.CheckCanModify());
         this.ModDisplay.ConsoleBtnX._visible = this.CheckCanModify();
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
      if(this.bEditingHeavy)
      {
         this.WeaponSelect.wpnSwitch.arrowLeft._visible = nNum > 1;
         this.WeaponSelect.wpnSwitch.arrowRight._visible = nNum < nTotal;
      }
      var _loc4_;
      if(this.ActionButtonText != "")
      {
         if(_global.SFX.Platform == com.XPlatform.PC && !this.bUsingGamepad)
         {
            _root.PCButtonMiddle.SetVisible(this.CheckCanModify());
         }
         else
         {
            _root.ConsoleButtons.ControlY.SetVisible(!this.bHeavyFocused && nNum != 0);
            _loc4_ = this.CheckCanModify();
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
   function RefreshButtonHelp(usingGamepad)
   {
      this.bUsingGamepad = usingGamepad;
      // MILAN CHANGE - Mgamerz - 2026-10-17
      // Forward live input mode to the mouse-only weapon description button.
      this.WeaponSelect.RefreshButtonHelp(usingGamepad);
      // END MILAN CHANGE
      if(_global.SFX.Platform == com.XPlatform.PC && !this.bUsingGamepad)
      {
         _root.ConsoleButtons._visible = false;
         this.ModDisplay.ConsoleBtnX._visible = false;
         _root.PCButtonLeft.SetVisible(false);
         _root.PCButtonMiddle.SetVisible(this.CheckCanModify());
         _root.PCButtonRight.SetVisible(true);
      }
      else
      {
         _root.ConsoleButtons._visible = true;
         _root.ConsoleButtons.ControlA.SetVisible(true);
         _root.ConsoleButtons.ControlB.SetVisible(this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_LOADOUT);
         if(this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_INVENTORY)
         {
            _root.ConsoleButtons.ControlY.SetVisible(!this.bHeavyFocused && this.WeaponSelect.m_nCurrentWeap != 0);
         }
         else if(this.State == screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_LOADOUT)
         {
            _root.ConsoleButtons.ControlY.SetVisible(!this.bHeavyFocused && !this.CurrentWeaponSlot.SlotIsEmpty());
         }
         _root.ConsoleButtons.ControlX.SetVisible(this.CheckCanModify());
         this.ModDisplay.ConsoleBtnX._visible = this.CheckCanModify();
         _root.PCButtonLeft.SetVisible(false);
         _root.PCButtonMiddle.SetVisible(false);
         _root.PCButtonRight.SetVisible(false);
      }
         this.RefreshHeavyButtonHelp();
   }
   function ShutdownHeavySelector()
   {
      this.SetHeavyFocus(false);
      if(this.HeavyModFade != undefined) this.HeavyModFade.removeMovieClip();
      this.HeavyModFade = undefined;
      this.bHeavyFocused = false;
      this.bEditingHeavy = false;
      this.SelectedWeaponSlot = undefined;
      this.CurrentWeaponSlot = undefined;
      this.State = screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_LOADOUT;
      this.Slot6.Selected = false;
      this.ModDisplay._alpha = 100;
      this.ModDisplay._visible = true;
      this.ModDisplay.enabled = true;
      this.Stats._visible = true;
      this.WeaponSelect.ExitSelectionMode();
   }
   function SetHeavySlot(id, shortName, iconResource, iconIndex, category, count)
   {
      this.Slot6._visible = true;
      var loader = this.Slot6.weaponSlot.weaponIcon;
      if(!loader.HeavyRestingStateBound)
      {
         loader.addEventListener("onIconLoadComplete",this.MakeDelegate(this.SetHeavyIconRestingState));
         loader.HeavyRestingStateBound = true;
      }
      this.Slot6.SetDisplay(id,iconResource,iconIndex,count,false,-1,true,false);
      this.SetHeavyIconRestingState();
      this.SetHeavyFocus(this.bHeavyFocused);
   }
   function SetHeavyIconRestingState()
   {
      var loader = this.Slot6.weaponSlot.weaponIcon;
      // Frame 1 is the resting outline; later frames are animations or filled states.
      loader.SetFrame(1);
      var outline = loader.mcResource.WeaponIcon;
      if(outline != undefined)
      {
         // Match the native LE3 Titan outline; LE2 donor resting outlines are orange.
         var tint = new Color(outline);
         tint.setRGB(0x67C2FE);
      }
   }
   // The top slots moved, but the connector must still end at the same title anchor.
   // Extents are the authored path's right edge in twips; timeline fades stay intact.
   function FitTopConnector(slot, originalX, extent)
   {
      slot.connector._xscale = 100 * (extent + originalX - slot._x * 20) / extent;
      // Scaleform can retain the initial alpha once a connector transform is scripted.
      // Keep the authored selected/deselected fade while anchoring its new geometry.
      slot.onEnterFrame = function()
      {
         var frame = this._currentframe;
         this.connector._alpha = frame >= 11 && frame <= 20 ? 100 : (frame >= 21 && frame <= 30 ? 100 * (30 - frame) / 9 : 0);
      };
   }
   function SetHeavySelection(selecting)
   {
      this.bEditingHeavy = selecting;
      this.State = selecting ? screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_INVENTORY : screens.WeaponMod.WeaponSelectMain.STATE_NAVIGATE_LOADOUT;
      this.SelectedWeaponSlot = selecting ? this.Slot6 : undefined;
      this.Slot6.Selected = selecting;
      if(selecting)
      {
         this.WeaponSelect.EnterSelectionMode();
      }
      else this.WeaponSelect.ExitSelectionMode();
      this.RefreshButtonHelp(this.bUsingGamepad);
   }
   function SetHeavyFocus(heavy)
   {
      // ShowingInfo remains the regular-weapon preference while heavy forces description.
      if(heavy != this.bHeavyFocused && !this.ShowingInfo)
      {
         this.gotoAndPlay(heavy ? "toInfo" : "toStats");
      }
      this.bHeavyFocused = heavy;
      this.WeaponSelect.SetInfoToggleEnabled(!heavy);
      this.ModDisplay.enabled = !heavy;
      this.Stats._visible = !heavy && !this.ShowingInfo;
      this.HeavyModTarget = heavy ? 0 : 100;
      if(!heavy) this.ModDisplay._visible = true;
      if(this.HeavyModFade == undefined)
      {
         // The authored description/stat timeline must not replace the fade controller.
         this.HeavyModFade = _root.createEmptyMovieClip("MilanHeavyModFade",_root.getNextHighestDepth());
         this.HeavyModFade.Owner = this;
         this.HeavyModFade.onEnterFrame = function(){ this.Owner.AdvanceHeavyModFade(); };
      }
      this.HeavyModTime = getTimer();
      this.RefreshHeavyButtonHelp();
   }
   function AdvanceHeavyModFade()
   {
      // The slot timeline can replace its loader after crossing empty/filled states.
      this.SetHeavyIconRestingState();
      var now = getTimer();
      var step = Math.max(0,now - this.HeavyModTime) * 0.6;
      this.HeavyModTime = now;
      var target = this.bHeavyFocused || this.ShowingInfo ? 0 : 100;
      var current = this.ModDisplay._alpha;
      this.ModDisplay._alpha = current < target ? Math.min(target,current + step) : Math.max(target,current - step);
      this.ModDisplay._visible = target > 0 || this.ModDisplay._alpha > 0;
      this.ModDisplay.enabled = !this.bHeavyFocused;
      if(this.bHeavyFocused) this.Stats._visible = false;
   }
   function RefreshHeavyButtonHelp()
   {
      if(!this.bHeavyFocused) return undefined;
      _root.ConsoleButtons.ControlX.SetVisible(false);
      _root.ConsoleButtons.ControlY.SetVisible(false);
      _root.PCButtonMiddle.SetVisible(false);
      this.ModDisplay.ConsoleBtnX._visible = false;
      this.ModDisplay.enabled = false;
      if(_global.SFX.Platform != com.XPlatform.PC || this.bUsingGamepad)
      {
         _root.ConsoleButtons.ControlB.SetVisible(true);
         _root.ConsoleButtons.ControlA.SetText(this.bEditingHeavy ? this.m_sSelectWeaponButtonText : this.m_sChangeWeaponButtonText);
         _root.ConsoleButtons.ControlB.SetText(this.bEditingHeavy ? this.m_sReturnToLoadoutText : this.m_sExitButtonText);
      }
      else _root.PCButtonRight.SetText(this.bEditingHeavy ? this.m_sReturnToLoadoutText : this.m_sExitButtonText);
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
