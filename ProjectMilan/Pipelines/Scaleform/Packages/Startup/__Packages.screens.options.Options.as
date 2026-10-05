// Milan Change
// Stumpy 2026/10/04
// Add new dropdown items

class screens.options.Options extends com.SFXScreen
{
   var HDRWarning;
   var MainOptionsGroup;
   var PC_ButtonA;
   var PC_ButtonB;
   var PC_ButtonX;
   var _denominator;
   var _numerator;
   var _previousSubTitles;
   var bindingStory;
   var list;
   var m_ControllerButtons;
   var masterTitle;
   var mode;
   var oldNumerator;
   var optionsData;
   var position;
   var scrollBarMC;
   var srBindingsPrimaryColumnHeader;
   var srBindingsSecondaryColumnHeader;
   var srOptionsButtonContinue;
   var srOptionsButtonPrevious;
   var srOptionsButtonResetToDefaults;
   var srOptionsButtonSelect;
   var srSaveAndExitLabel;
   var srSaveAndExitStory;
   var srScreenTitle;
   var subTitle;
   static var OPTION_Resolution = 10;
   // Milan Change - New variables for dropdown IDs (maybe make this into an array instead)
   static var OPTION_WindowMode = 11;
   static var OPTION_CappedFramerate = 53;
   static var OPTION_Difficulty = 1;
   static var OPTION_SquadPower = 4;
   static var OPTION_Gamma = 12;
   static var OPTION_HDREnabled = 47;
   static var OPTION_HDRBrightness = 48;
   static var OPTION_HDRContrast = 49;
   static var OPTION_AimAssist = 29;
   static var OPTION_VSYNC = 46;
   static var OPTION_FRAMERATE = 53;
   var history = [];
   var lastSelectedIndex = [];
   var menuLevel = 0;
   var useStory = true;
   var adjustingControl = false;
   var unlockDifficulty = 3;
   var bDirty = false;
   var bSuppressUpdate = false;
   var InputDisabled = false;
   var OPTION_GUI_BROWSER_WHEEL = 0;
   var OPTION_GUI_MAINMENU = 1;
   var OPTION_GUI_CHARACTER_CREATION = 2;
   var bUsingGamepad = false;
   function Options()
   {
      super();
   }
   function onLoad()
   {
      this.init();
   }
   function SetupInputHandling()
   {
      this.m_ControllerButtons = _root.options.mcControllerButtons;
      this.m_ControllerButtons.addEventListener("onDPadUp",mx.utils.Delegate.create(this,this.onDPadUp));
      this.m_ControllerButtons.addEventListener("onDPadDown",mx.utils.Delegate.create(this,this.onDPadDown));
      this.m_ControllerButtons.addEventListener("onDPadLeft",mx.utils.Delegate.create(this,this.onDPadLeft));
      this.m_ControllerButtons.addEventListener("onDPadRight",mx.utils.Delegate.create(this,this.onDPadRight));
      this.m_ControllerButtons.addEventListener("onButtonB",mx.utils.Delegate.create(this,this.onButtonB));
      this.m_ControllerButtons.ControlX.text = this.srOptionsButtonResetToDefaults;
      this.m_ControllerButtons.ControlX.Active = true;
      this.m_ControllerButtons.ControlY.Hidden = true;
      this.m_ControllerButtons.ControlB.text = this.srOptionsButtonPrevious;
      this.m_ControllerButtons.ControlB.Active = false;
      this.m_ControllerButtons.ControlA.text = this.srOptionsButtonSelect;
      this.m_ControllerButtons.ControlA.Active = true;
      this.m_ControllerButtons.addEventListener("onButtonX",mx.utils.Delegate.create(this,this.onButtonX));
      this.m_ControllerButtons.addEventListener("onButtonA",mx.utils.Delegate.create(this,this.onButtonA));
      this.m_ControllerButtons.addEventListener("onButtonY",mx.utils.Delegate.create(this,this.onInvalidInput));
      this.m_ControllerButtons.FitLeft();
   }
   function RefreshButtonHelp(usingGamepad)
   {
      this.bUsingGamepad = usingGamepad;
      this.m_ControllerButtons = _root.options.mcControllerButtons;
      if(_global.Platform == com.XPlatform.PC)
      {
         this.PC_ButtonB._visible = !usingGamepad;
         this.PC_ButtonB.enabled = !usingGamepad;
      }
      if(usingGamepad || _global.Platform != com.XPlatform.PC)
      {
         this.m_ControllerButtons._alpha = 100;
      }
      else
      {
         this.m_ControllerButtons._alpha = 0;
      }
      this.updateController();
   }
   function init()
   {
      Stage.scaleMode = "showAll";
      this.HDRWarning = _root.options.mcN7HDR.HDRWarning;
      this.HDRWarning._visible = false;
      this.LoadStrings();
      this.masterTitle._visible = !_global.SFX.IsMPLobby;
      this.masterTitle.text = this.srScreenTitle;
      this._previousSubTitles = new Array();
      this.SetupInputHandling();
      this.list.addEventListener("onMenuOutStart",mx.utils.Delegate.create(this,this.startMenuOut));
      this.list.addEventListener("onMenuInEnd",mx.utils.Delegate.create(this,this.finishMenuIn));
      this.list.addEventListener("onChange",mx.utils.Delegate.create(this,this.onChange));
      this.list.addEventListener("onSettingChange",mx.utils.Delegate.create(this,this.onSettingChange));
      this.list.addEventListener("SFXMenuItem_onRollOver",mx.utils.Delegate.create(this,this.onMenuItemRollover));
      this.list.addEventListener("SFXMenuItem_onRelease",mx.utils.Delegate.create(this,this.onButtonA));
      this.list.addEventListener("CapturingBind",mx.utils.Delegate.create(this,this.onCapturingBind));
      this.list.addEventListener("CapturingBindCompleted",mx.utils.Delegate.create(this,this.onCapturingBindComplete));
      this.list.addEventListener("SFXMenuItem_onLeftArrowPress",mx.utils.Delegate.create(this,this.onDPadLeft));
      this.list.addEventListener("SFXMenuItem_onRightArrowPress",mx.utils.Delegate.create(this,this.onDPadRight));
      this.list.setupScrollBar(this.scrollBarMC);
      this.PC_ButtonA.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.onButtonA));
      this.PC_ButtonA.text = this.srOptionsButtonSelect;
      this.PC_ButtonX.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.onButtonX));
      this.PC_ButtonX.text = this.srOptionsButtonResetToDefaults;
      this.PC_ButtonB.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.onButtonB));
      this.PC_ButtonB.text = this.srOptionsButtonPrevious;
      this.bDirty = false;
      flash.external.ExternalInterface.call("MovieLoaded");
      this.ReSizeScreen();
   }
   function ReSizeScreen()
   {
      var _loc7_ = new Object();
      _loc7_.onResize = function(incomingRect)
      {
         var _loc4_ = com.SFXScreen.GetSafeRect();
         var _loc3_ = 100;
         var _loc7_ = 120;
         var _loc5_ = 100;
         var _loc6_ = incomingRect.width / incomingRect.height;
         if(_loc6_ >= 1.7)
         {
            _loc3_ = _loc7_;
         }
         else
         {
            _loc3_ = _loc5_;
         }
         _root.options._xscale = _root.options._yscale = _loc3_;
         if(this.MainOptionsGroup == undefined)
         {
            this.MainOptionsGroup = new com.SFXPositionHelper(_root.options);
         }
         this.MainOptionsGroup.CenterHorizontally(_loc4_);
         this.MainOptionsGroup.CenterVertically(_loc4_);
      };
   }
   function LoadStrings()
   {
      this.srScreenTitle = "$" + _global.SFX.GetIniString("srScreenTitle");
      this.srBindingsPrimaryColumnHeader = "$" + _global.SFX.GetIniString("srBindingsPrimaryColumnHeader");
      this.srBindingsSecondaryColumnHeader = "$" + _global.SFX.GetIniString("srBindingsSecondaryColumnHeader");
      this.srSaveAndExitLabel = "$" + _global.SFX.GetIniString("srSaveAndExitLabel");
      this.srSaveAndExitStory = "$" + _global.SFX.GetIniString("srSaveAndExitStory");
      this.srOptionsButtonPrevious = "$" + _global.SFX.GetIniString("srOptionsButtonPrevious");
      this.srOptionsButtonSelect = "$" + _global.SFX.GetIniString("srOptionsButtonSelect");
      this.srOptionsButtonContinue = "$" + _global.SFX.GetIniString("srOptionsButtonContinue");
      this.srOptionsButtonResetToDefaults = "$" + _global.SFX.GetIniString("srOptionsButtonResetToDefaults");
   }
   function onCapturingBind(p_event)
   {
      _global.DissabledInput = true;
   }
   function onCapturingBindComplete(p_event)
   {
      _global.DissabledInput = false;
      this.bDirty = true;
   }
   function onMenuItemRollover(p_event)
   {
      var _loc4_;
      var _loc3_;
      if(!_global.DissabledInput)
      {
         _loc4_ = p_event.target;
         _loc3_ = _loc4_.nIndex - this.position;
         if(_loc3_ > 0)
         {
            this.HandleDPadDown(_loc3_);
         }
         else if(_loc3_ < 0)
         {
            this.HandleDPadUp(_loc3_);
         }
      }
   }
   function finishMenuIn(p_event)
   {
      this.list.fadeInSelectionBar();
      this.setStory();
      this.m_ControllerButtons.InputDisabled = false;
      this.InputDisabled = false;
      flash.external.ExternalInterface.call("SetHDRStatus");
      this.updateN7Glyph(true,false);
   }
   function startMenuOut(p_event)
   {
      this.scrollBarMC._visible = false;
      this.m_ControllerButtons.InputDisabled = true;
      this.InputDisabled = true;
   }
   function setDefaultView()
   {
      this.position = 0;
      var _loc4_;
      var _loc3_;
      if(_global.Platform == com.XPlatform.PC)
      {
         _loc4_ = 0;
         while(_loc4_ < this.optionsData.length)
         {
            _loc3_ = 0;
            while(_loc3_ < this.optionsData[_loc4_].children.length)
            {
               if(this.optionsData[_loc4_].children[_loc3_].optionId == screens.options.Options.OPTION_Resolution)
               {
                  this.optionsData[_loc4_].children[_loc3_].type = "DropDownScrollLong";
               }
               // Milan Change - replace more items with dropdowns
               if(this.optionsData[_loc4_].children[_loc3_].optionId == screens.options.Options.OPTION_WindowMode)
               {
                  this.optionsData[_loc4_].children[_loc3_].type = "DropDownScrollLong";
               }
               if(this.optionsData[_loc4_].children[_loc3_].optionId == screens.options.Options.OPTION_CappedFramerate)
               {
                  this.optionsData[_loc4_].children[_loc3_].type = "DropDownScrollLong";
               }
               // Milan Change End
               _loc3_ = _loc3_ + 1;
            }
            _loc4_ = _loc4_ + 1;
         }
      }
      this.list.dataProvider = this.optionsData;
      this.subTitle.text = "";
      this.updateController();
      this.setStory();
   }
   function disableButtons()
   {
      this.m_ControllerButtons.ControlA.Active = false;
      this.m_ControllerButtons.ControlB.Active = false;
      this.m_ControllerButtons.ControlX.Active = false;
   }
   function setStory()
   {
      if(this.list.dataProvider[this.position] == undefined)
      {
         return undefined;
      }
      this.list.SetSelectionBarVisibility(this.list.dataProvider[this.position].type != "ControlBindingHeader");
      if(this.list.dataProvider[this.position].type == "TextSlider" || this.list.dataProvider[this.position].type.indexOf("DropDown") != -1)
      {
         this.bSuppressUpdate = true;
         this.list.selectedItem.onSettingChange();
      }
      else if(this.list.dataProvider[this.position].type == "ControlBindingItem" || this.list.dataProvider[this.position].type == "ControlBindingHeader")
      {
         this.list.setStory(this.bindingStory);
      }
      else
      {
         this.list.setStory(this.list.dataProvider[this.position].story);
      }
   }
   function isAEnabled()
   {
      var _loc2_ = false;
      var _loc0_;
      if(this.list.dataProvider[this.position].type == "ControlBindingItem" || this.list.dataProvider[this.position].type == "ControlBindingHeader")
      {
         _loc2_ = !this.bUsingGamepad ? true : false;
      }
      else if(this.list.dataProvider[this.position].type.indexOf("DropDown") != -1)
      {
         _loc2_ = this.bUsingGamepad;
      }
      else if((_loc0_ = this.mode) !== this.OPTION_GUI_CHARACTER_CREATION)
      {
         _loc2_ = this.list.dataProvider[this.position].children != undefined || this.list.dataProvider[this.position].type == "BaseMenuItem" && this.list.dataProvider[this.position].children == undefined;
      }
      else
      {
         _loc2_ = true;
      }
      return _loc2_;
   }
   function isXEnabled()
   {
      var _loc2_ = false;
      var _loc0_;
      if(this.list.dataProvider[this.position].type == "ControlBindingItem" || this.list.dataProvider[this.position].type == "ControlBindingHeader")
      {
         _loc2_ = !this.bUsingGamepad ? true : false;
      }
      else if((_loc0_ = this.mode) !== this.OPTION_GUI_CHARACTER_CREATION)
      {
         _loc2_ = true;
      }
      else
      {
         _loc2_ = false;
      }
      return _loc2_;
   }
   function IsListAtBaseMenuItem()
   {
      return Boolean(this.list.dataProvider[this.position].type == "BaseMenuItem");
   }
   function updateController()
   {
      var _loc3_ = this.isXEnabled();
      var _loc4_ = this.isAEnabled();
      this.m_ControllerButtons.ControlX.Active = _loc3_;
      this.m_ControllerButtons.ControlA.Active = _loc4_;
      this.m_ControllerButtons.ControlB.text = this.srOptionsButtonPrevious;
      this.m_ControllerButtons.FitLeft();
      if(_global.Platform == com.XPlatform.PC && !this.bUsingGamepad)
      {
         if(this.list.dataProvider[this.position].type == "ControlBindingItem" || this.list.dataProvider[this.position].type == "ControlBindingHeader")
         {
            this.PC_ButtonA._visible = false;
            this.PC_ButtonA.enabled = false;
         }
         else
         {
            this.PC_ButtonA._visible = false;
            this.PC_ButtonA.enabled = false;
         }
         this.PC_ButtonX._visible = _loc3_;
         this.PC_ButtonX.enabled = _loc3_;
      }
      else
      {
         this.PC_ButtonX._visible = false;
      }
      var _loc0_;
      if((_loc0_ = this.mode) !== this.OPTION_GUI_CHARACTER_CREATION)
      {
         this.m_ControllerButtons.ControlB.Active = true;
         this.m_ControllerButtons.ControlA.text = this.srOptionsButtonSelect;
         if(_global.Platform == com.XPlatform.PC && !this.bUsingGamepad)
         {
            this.PC_ButtonB._visible = true;
            this.PC_ButtonB.enabled = true;
         }
      }
      else
      {
         this.m_ControllerButtons.ControlB.Active = false;
         this.m_ControllerButtons.ControlA.text = this.srOptionsButtonContinue;
         if(_global.Platform == com.XPlatform.PC && !this.bUsingGamepad)
         {
            this.PC_ButtonB._visible = false;
            this.PC_ButtonB.enabled = false;
            this.PC_ButtonA.text = this.srOptionsButtonContinue;
            this.PC_ButtonA._visible = true;
            this.PC_ButtonA.enabled = true;
         }
      }
   }
   function onInvalidInput(p_event)
   {
      com.SFXScreen.PlayGUIError();
   }
   function onButtonA(p_event)
   {
      if(this.InputDisabled)
      {
         return undefined;
      }
      com.SFXScreen.PlayGUISound("OptionsSelect");
      var _loc0_;
      if((_loc0_ = this.mode) !== this.OPTION_GUI_CHARACTER_CREATION)
      {
         if(_global.Platform == com.XPlatform.PC && p_event.target == this.PC_ButtonA)
         {
            if(this.list.dataProvider[this.position].type == "ControlBindingItem" || this.list.dataProvider[this.position].type == "ControlBindingHeader")
            {
               flash.external.ExternalInterface.call("ResetPCBindings");
               this.bDirty = true;
               return undefined;
            }
            return undefined;
         }
         if(this.list.dataProvider[this.position].type == "ControlBindingHeader" || this.list.dataProvider[this.position].type == "ControlBindingItem" || this.list.dataProvider[this.position].type == "BaseMenuItem" && this.list.dataProvider[this.position].children == undefined)
         {
            this.list.dataProvider.position.functionName();
         }
         else if(this.list.dataProvider[this.position].type.indexOf("DropDown") != -1)
         {
            this.list.selectedItem.execEnter();
         }
         else
         {
            this.SubMenuOpen();
         }
      }
      else if(_global.Platform == com.XPlatform.PC)
      {
         if(p_event.target == this.PC_ButtonA)
         {
            this.saveAndExit();
         }
      }
      else
      {
         this.saveAndExit();
      }
   }
   function onButtonB(p_event)
   {
      if(this.InputDisabled)
      {
         return undefined;
      }
      if(this.menuLevel > 0)
      {
         com.SFXScreen.PlayGUISound("MessageBoxA");
      }
      if(this.list.dataProvider[this.position].type.indexOf("DropDown") != -1 && this.list.selectedItem.bActive)
      {
         this.list.selectedItem.execEscape();
      }
      else
      {
         this.SubMenuClose();
      }
   }
   function onButtonX(p_event)
   {
      if(this.InputDisabled)
      {
         return undefined;
      }
      com.SFXScreen.PlayGUISound("OptionsSelect");
      if(_global.Platform == com.XPlatform.PC && p_event.target == this.PC_ButtonX)
      {
         if(this.list.dataProvider[this.position].type == "ControlBindingItem" || this.list.dataProvider[this.position].type == "ControlBindingHeader")
         {
            flash.external.ExternalInterface.call("ResetPCBindings");
            this.bDirty = true;
            return undefined;
         }
      }
      var _loc4_;
      var _loc3_;
      if(this.menuLevel == 0)
      {
         flash.external.ExternalInterface.call("ResetToDefaults","");
      }
      else
      {
         _loc4_ = new Array();
         _loc3_ = 0;
         while(_loc3_ < this.list.dataProvider.length)
         {
            if(this.list.dataProvider[_loc3_].optionId != undefined)
            {
               _loc4_.push(this.list.dataProvider[_loc3_].optionId);
            }
            _loc3_ = _loc3_ + 1;
         }
         if(_loc4_.length > 0)
         {
            flash.external.ExternalInterface.call("ResetToDefaults",_loc4_.join());
         }
      }
      this.bDirty = true;
   }
   function onButtonY(p_event)
   {
      com.SFXScreen.PlayGUIError();
   }
   function onDPadRight(p_event)
   {
      this.adjustingControl = true;
      if(this._numerator < this._denominator - 1 && !this.IsListAtBaseMenuItem() && this.list.selectedItem.IsEnabled())
      {
         this.list.selectedItem.increaseSetting();
      }
      else
      {
         this.onInvalidInput();
      }
   }
   function onDPadLeft(p_event)
   {
      this.adjustingControl = true;
      var _loc2_;
      if(this._numerator > 0 && !this.IsListAtBaseMenuItem() && this.list.selectedItem.IsEnabled())
      {
         this.list.selectedItem.decreaseSetting();
         if(this.list.selectedItem.optionId == screens.options.Options.OPTION_Difficulty && this.list.selectedItem.selectedIndex == 0)
         {
            _loc2_ = this.list.GetOptionIndex(screens.options.Options.OPTION_SquadPower);
            this.list.SetItemValue(_loc2_,0);
            _loc2_ = this.list.GetOptionIndex(screens.options.Options.OPTION_AimAssist);
            this.list.SetItemValue(_loc2_,0);
         }
      }
      else
      {
         this.onInvalidInput();
      }
   }
   function HandleDPadUp(Diff)
   {
      if(this.list.dataProvider[this.position].type.indexOf("DropDown") != -1 && this.list.selectedItem.bActive)
      {
         this.list.selectedItem.execUp();
      }
      else
      {
         this.adjustingControl = false;
         if(this.position + Diff >= 0)
         {
            com.SFXScreen.PlayGUISound("OptionsMove");
            this.position += Diff;
            this.list.selectedIndex = this.position;
            this.updateController();
            this.setStory();
         }
         else
         {
            this.onInvalidInput();
         }
      }
   }
   function onDPadUp(p_event)
   {
      this.HandleDPadUp(-1);
   }
   function HandleDPadDown(Diff)
   {
      if(this.list.dataProvider[this.position].type.indexOf("DropDown") != -1 && this.list.selectedItem.bActive)
      {
         this.list.selectedItem.execDown();
      }
      else
      {
         this.adjustingControl = false;
         if(this.position + Diff <= this.list.dataProvider.length - 1)
         {
            com.SFXScreen.PlayGUISound("OptionsMove");
            this.position += Diff;
            this.list.selectedIndex = this.position;
            this.updateController();
            this.setStory();
         }
         else
         {
            this.onInvalidInput();
         }
      }
   }
   function onDPadDown(p_event)
   {
      this.HandleDPadDown(1);
   }
   function onChange(p_event)
   {
      if(this.menuLevel == 0 && this.lastSelectedIndex[this.menuLevel] != undefined)
      {
         this.list.selectedIndex = this.position = this.lastSelectedIndex[this.menuLevel];
      }
      else
      {
         this.list.selectedIndex = this.position = 0;
      }
      this.updateController();
      this.useStory = false;
      this.setStory();
   }
   function setHDROn(bHDROn)
   {
      if(bHDROn)
      {
         this.adjustActiveOptions(screens.options.Options.OPTION_HDREnabled,1);
      }
      else
      {
         this.adjustActiveOptions(screens.options.Options.OPTION_HDREnabled,0);
      }
   }
   function setVSYNCOn()
   {
      if(this.list.GetItemValue(this.list.GetOptionIndex(screens.options.Options.OPTION_VSYNC)) == 0)
      {
         this.list.setOptionActive(screens.options.Options.OPTION_FRAMERATE,false);
      }
      else if(this.list.GetItemValue(this.list.GetOptionIndex(screens.options.Options.OPTION_VSYNC)) == 1)
      {
         this.list.setOptionActive(screens.options.Options.OPTION_FRAMERATE,true);
      }
   }
   function adjustActiveOptions(optionID, optionValue)
   {
      var _loc0_;
      if((_loc0_ = optionID) === screens.options.Options.OPTION_HDREnabled)
      {
         switch(optionValue)
         {
            case 0:
               this.list.setOptionActive(screens.options.Options.OPTION_Gamma,true);
               this.list.setOptionActive(screens.options.Options.OPTION_HDRBrightness,false);
               this.list.setOptionActive(screens.options.Options.OPTION_HDRContrast,false);
               this.HDRWarning._visible = true;
               break;
            case 1:
               this.list.setOptionActive(screens.options.Options.OPTION_Gamma,false);
               this.list.setOptionActive(screens.options.Options.OPTION_HDRBrightness,true);
               this.list.setOptionActive(screens.options.Options.OPTION_HDRContrast,true);
         }
      }
   }
   function onSettingChange(p_event)
   {
      if(this.useStory && p_event.story)
      {
         this.list.setStory(p_event.story);
      }
      this.updateN7Glyph(true,false);
      if(!this.bSuppressUpdate)
      {
         this._numerator = p_event.numerator;
         this._denominator = p_event.denominator;
         this.updateController();
         this.useStory = true;
         if(this.adjustingControl || p_event.adjustingControl != undefined && p_event.adjustingControl)
         {
            this.bDirty = true;
            if(p_event.value_ == undefined)
            {
               if(this.list.selectedItem.optionId != screens.options.Options.OPTION_Gamma || p_event.numerator != undefined)
               {
                  this.setOption(p_event.optionId,p_event.numerator);
               }
            }
            else
            {
               this.setOption(p_event.optionId,p_event.value_);
            }
            if(this._numerator != this.oldNumerator)
            {
               com.SFXScreen.PlayGUISound("OptionsChange");
               this.oldNumerator = this._numerator;
            }
         }
      }
      else
      {
         this.bSuppressUpdate = false;
      }
   }
   function saveAndExit()
   {
      flash.external.ExternalInterface.call("SaveAndExit");
   }
   function setOption(p_id, p_value)
   {
      flash.external.ExternalInterface.call("SetOption",p_id,p_value);
   }
   function quit()
   {
      flash.external.ExternalInterface.call("CloseGui");
   }
   function SubMenuOpen()
   {
      this.bindingStory = "";
      var _loc2_ = this.list.dataProvider[this.position].label;
      var _loc3_ = this.subTitle.text;
      if(this.list.dataProvider[this.position].bShowColumnHeaders == true)
      {
         this.updateShowColumnHeaders(true,false);
      }
      this._previousSubTitles.push(new String(_loc3_));
      this.lastSelectedIndex[this.menuLevel] = this.list.selectedIndex;
      this.history[this.menuLevel] = this.list.dataProvider;
      this.menuLevel = this.menuLevel + 1;
      this.list.dataProvider = this.list.dataProvider[this.position].children;
      this.subTitle.text = _loc2_;
      this.disableButtons();
   }
   function SubMenuClose()
   {
      var _loc2_;
      if(this.menuLevel > 0)
      {
         this.menuLevel = this.menuLevel - 1;
         this.list.dataProvider = this.history[this.menuLevel];
         _loc2_ = this._previousSubTitles.pop();
         this.subTitle.text = _loc2_.toString();
         this._numerator = this._denominator = 0;
         this.disableButtons();
         this.updateShowColumnHeaders(false,false);
         this.updateN7Glyph(false,false);
      }
      else if(this.bDirty)
      {
         flash.external.ExternalInterface.call("SaveAndExit");
      }
      else
      {
         this.quit();
      }
   }
   function SetOptions(p_mode, p_ScreenLayout, p_options)
   {
      this.mode = p_mode;
      _global.Platform = p_ScreenLayout;
      this.updateScreenLayout();
      this.menuLevel = 0;
      this.optionsData = p_options;
      this.setDefaultView();
   }
   function SetSingleOption(optionId, option)
   {
      if(optionId == screens.options.Options.OPTION_Resolution && _global.Platform == com.XPlatform.PC)
      {
         option.type = "DropDownScrollLong";
      }
      // Milan Change - replace more items with dropdowns
      if(optionId == screens.options.Options.OPTION_WindowMode && _global.Platform == com.XPlatform.PC)
      {
         option.type = "DropDownScrollLong";
      }
      if(optionId == screens.options.Options.OPTION_CappedFramerate && _global.Platform == com.XPlatform.PC)
      {
         option.type = "DropDownScrollLong";
      }
      this.list.SetSingleOption(optionId,option);
   }
   function SetSingleOptionValue(optionId, optionVal)
   {
      this.list.SetItemValue(optionId,optionVal);
   }
   function UpdateControllerBindEntry(p_Bind1, p_Bind2)
   {
      this.list.UpdateControllerBindEntry(p_Bind1,p_Bind2);
   }
   function UpdateControllerBindEntryByIdx(p_Index, p_Bind1, p_Bind2)
   {
      this.list.UpdateControllerBindEntryByIndex(p_Index,p_Bind1,p_Bind2);
   }
   function SetBindingStory(p_Story)
   {
      this.bindingStory = p_Story;
      this.setStory();
   }
   function updateScreenLayout()
   {
      this.PC_ButtonA._visible = false;
      this.PC_ButtonA.enabled = false;
      this.PC_ButtonX._visible = false;
      this.PC_ButtonX.enabled = false;
      this.PC_ButtonB._visible = false;
      this.PC_ButtonB.enabled = false;
      if(_global.Platform == com.XPlatform.PC && !this.bUsingGamepad)
      {
         this.m_ControllerButtons._alpha = 0;
         this.PC_ButtonB._visible = true;
         this.PC_ButtonB.enabled = true;
      }
      else
      {
         this.m_ControllerButtons._alpha = 100;
      }
      this.updateN7Glyph(false,true);
      this.updateShowColumnHeaders(false,true);
   }
   function updateN7Glyph(bAllowed, bForce)
   {
      var _loc4_ = bAllowed && !this.InputDisabled && this.list.selectedItem.optionId == screens.options.Options.OPTION_Gamma;
      var _loc3_ = bAllowed && !this.InputDisabled && (this.list.selectedItem.optionId == screens.options.Options.OPTION_HDRBrightness || this.list.selectedItem.optionId == screens.options.Options.OPTION_HDRContrast);
      this.updateFadeable(_root.options.mcN7Brightness,_loc4_,bForce);
      this.updateFadeable(_root.options.mcN7HDR,_loc3_,bForce);
      _root.options.mcN7HDR.optionId = !_loc3_ ? -1 : this.list.selectedItem.optionId;
   }
   function updateShowColumnHeaders(bOn, bForce)
   {
      if(bOn)
      {
         _root.options.mcColumnHeaders.Item_mc.priBindTxt.text = this.srBindingsPrimaryColumnHeader;
         _root.options.mcColumnHeaders.Item_mc.secBindTxt.text = this.srBindingsSecondaryColumnHeader;
      }
      this.updateFadeable(_root.options.mcColumnHeaders,bOn,bForce);
   }
   function updateFadeable(fadeableClip, bOn, bForce)
   {
      var _loc3_ = fadeableClip.bOn;
      if(bForce)
      {
         if(bOn)
         {
            fadeableClip.gotoAndStop("on");
         }
         else
         {
            this.HDRWarning._visible = false;
            fadeableClip.gotoAndStop("off");
         }
      }
      else if(bOn && !_loc3_)
      {
         fadeableClip.gotoAndPlay("fadein");
      }
      else if(!bOn && _loc3_)
      {
         this.HDRWarning._visible = false;
         fadeableClip.gotoAndPlay("fadeout");
      }
   }
}
