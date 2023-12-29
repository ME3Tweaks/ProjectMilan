class screens.MessageBox.ChoiceMessageBox extends com.SFXInputMovieClip
{
   var Choices;
   var MessageBoxInner;
   var CancelButton;
   var ConsoleButton;
   var Tint;
   var bClosing;
   var CurrentChoiceIndex;
   function ChoiceMessageBox()
   {
      super();
   }
   function onLoad()
   {
      super.onLoad();
      this.RemoveFromView();
      this.InputDisabled = true;
      this._visible = false;
      this.Choices = new Array(this.MessageBoxInner.choice1,this.MessageBoxInner.choice2,undefined);
      this.CancelButton = this.MessageBoxInner.CancelButton;
      this.ConsoleButton = this.MessageBoxInner.ConsoleButton;
      this.MessageBoxInner.choice1.OptionIndex = 0;
	  // Removed some button visibility stuff that needs to be based on input style and made dynamic, rather than on platform and only at load
      this.MessageBoxInner.choice2.OptionIndex = 1;
      this.MessageBoxInner.choice3.OptionIndex = 2;
      this.addEventListener("onInvalidInput",this.MakeDelegate(this.HandleInvalidInput));
      this.addEventListener("onDPadUp",this.MakeDelegate(this.MoveSelectionUp));
      this.addEventListener("onDPadDown",this.MakeDelegate(this.MoveSelectionDown));
      // set up event handlers for both mouse and controller events unconditionally
      this.CancelButton.addEventListener("SFXButton_onRelease",this.MakeDelegate(this.CancelChoice));
      this.AddKeyUpEvent(13,"onEnter");
      this.AddKeyUpEvent(32,"onSpace");
      this.AddKeyUpEvent(27,"onEscape");
      this.addEventListener("onEnter",this.MakeDelegate(this.SelectOption));
      this.addEventListener("onSpace",this.MakeDelegate(this.SelectOption));
      this.addEventListener("onEscape",this.MakeDelegate(this.CancelChoice));
      this.addEventListener("onButtonA",this.MakeDelegate(this.SelectOption));
      this.addEventListener("onButtonB",this.MakeDelegate(this.CancelChoice));
   }
   // added to handle input mode changes
   function RefreshButtonHelp(usingGamepad)
   {
      if (!usingGamepad)
      {
         this.ConsoleButton.SetVisible(false);
         this.CancelButton.SetVisible(true);
         this.MessageBoxInner.choice1.ButtonAB._visible = false;
         this.MessageBoxInner.choice2.ButtonAB._visible = false;
         this.MessageBoxInner.choice3.ButtonAB._visible = false;
      }
      else
      {
         this.ConsoleButton.SetVisible(true);
         this.CancelButton.SetVisible(false);
         this.MessageBoxInner.choice1.ButtonAB._visible = true;
         this.MessageBoxInner.choice2.ButtonAB._visible = true;
         this.MessageBoxInner.choice3.ButtonAB._visible = true;
         if(this.CurrentChoiceIndex == undefined)
         {
            this.SelectChoice(0);
            return undefined;
         }
      }
   }
   function show(bSkipTransition)
   {
      // added to ensure UI looks correct when it first shows up
      this.RefreshButtonHelp(flash.external.ExternalInterface.call("IsUsingGamepad"));
      this._visible = true;
      this.Reposition();
      this.InputDisabled = false;
      if(bSkipTransition)
      {
         this.gotoAndStop("Visible");
         this.Tint.gotoAndStop("Visible");
      }
      else
      {
         this.gotoAndPlay("FadeIn");
         this.Tint.gotoAndPlay("FadeIn");
      }
      _global.SFX.PlayGUISound("MessageBoxChoice-Open");
      this.bClosing = false;
   }
   function hide(bSkipTransition)
   {
      this.InputDisabled = true;
      if(bSkipTransition)
      {
         this.gotoAndStop("Hidden");
         this.Tint.gotoAndStop("off");
         this.onFadeoutComplete();
      }
      else
      {
         this.gotoAndPlay("FadeOut");
         this.Tint.gotoAndPlay("FadeOut");
      }
      _global.SFX.PlayGUISound("MessageBoxChoice-Close");
      this.bClosing = true;
   }
   function SetOptions(sMessage, sCancelText, sOption1, nOption1ID, bOption1Enabled, sOption2, nOption2ID, bOption2Enabled, sOption3, nOption3ID, bOption3Enabled)
   {
      if(sOption3 == "")
      {
         this.MessageBoxInner.gotoAndStop(1);
         this.Choices[2] = undefined;
      }
      else
      {
         this.MessageBoxInner.gotoAndStop(2);
         this.Choices[2] = this.MessageBoxInner.choice3;
      }
      this.MessageBoxInner.Text.text = sMessage;
      this.SetupChoiceButton(this.Choices[0],sOption1,bOption1Enabled,nOption1ID,this.MakeDelegate(this.OptionSelected),0);
      this.SetupChoiceButton(this.Choices[1],sOption2,bOption2Enabled,nOption2ID,this.MakeDelegate(this.OptionSelected),1);
      if(sOption3 != "" && this.Choices[2] != undefined)
      {
         this.SetupChoiceButton(this.Choices[2],sOption3,bOption3Enabled,nOption3ID,this.MakeDelegate(this.OptionSelected),2);
      }
      this.SetButton(sCancelText);
      if(_global.SFX.Platform != com.XPlatform.PC)
      {
         this.SelectChoice(0);
      }
   }
   function SetButton(sCancelText)
   {
      // set for both mouse and keyboard mode
      this.CancelButton.SetText(sCancelText);
      this.ConsoleButton.SetText(sCancelText);
   }
   function MoveSelectionUp()
   {
      if(this.CurrentChoiceIndex == undefined)
      {
         this.SelectChoice(0);
         return undefined;
      }
      if(this.CurrentChoiceIndex <= 0)
      {
         this.HandleInvalidInput();
         return undefined;
      }
      this.SelectChoice(this.CurrentChoiceIndex - 1);
   }
   function MoveSelectionDown()
   {
      if(this.CurrentChoiceIndex == undefined)
      {
         this.SelectChoice(0);
         return undefined;
      }
      if(this.Choices[this.CurrentChoiceIndex + 1] == undefined)
      {
         this.HandleInvalidInput();
         return undefined;
      }
      this.SelectChoice(this.CurrentChoiceIndex + 1);
   }
   function SelectChoice(nChoiceIndex)
   {
      if(nChoiceIndex < 0 || this.Choices[nChoiceIndex] == undefined)
      {
         _global.SFX.PlayGUIError();
         return undefined;
      }
      if(this.CurrentChoiceIndex != undefined)
      {
         this.Choices[this.CurrentChoiceIndex].gotoAndPlay(!this.Choices[this.CurrentChoiceIndex].Enabled ? "toDisabledOut" : "toOut");
      }
      this.CurrentChoiceIndex = nChoiceIndex;
      if(this.CurrentChoiceIndex != undefined)
      {
         this.Choices[this.CurrentChoiceIndex].gotoAndPlay(!this.Choices[this.CurrentChoiceIndex].Enabled ? "toDisabledOver" : "toOver");
         _global.SFX.PlayGUISound("MessageBoxChoice-Hover");
      }
   }
   function SetupChoiceButton(mcButton, sOptionText, bEnabled, nOptionID, fnCallback, nArg)
   {
      mcButton.ChoiceID = nOptionID;
      mcButton.Enabled = bEnabled;
      if(!bEnabled)
      {
         mcButton.textMCBlue.gotoAndStop("disabled");
         mcButton.gotoAndStop("disabled");
      }
      mcButton.textMCRed.text.text = sOptionText;
      mcButton.textMCBlue.text.text = sOptionText;
      this.SetupInputHandlingForButton(mcButton,fnCallback,nArg);
   }
   function SetupInputHandlingForButton(mcButton, fnCallback, nArg)
   {
      var _this = this;
      mcButton.hitArea = mcButton.HitArea;
      mcButton.bMouseOver = false;
      mcButton.onRollOver = function()
      {
         if(!mcButton.bMouseOver)
         {
            _this.SelectChoice(nArg);
         }
         mcButton.bMouseOver = true;
      };
      mcButton.onRollOut = function()
      {
         if(mcButton.bMouseOver)
         {
            this.gotoAndPlay(!mcButton.Enabled ? "toDisabledOut" : "toOut");
         }
         mcButton.bMouseOver = false;
      };
      mcButton.onRelease = function()
      {
         if(mcButton.bMouseOver)
         {
            this.gotoAndPlay(!mcButton.Enabled ? "disabledPress" : "press");
            if(mcButton.Enabled && fnCallback != undefined)
            {
               fnCallback(nArg);
            }
            else
            {
               _global.SFX.PlayGUIError();
            }
         }
      };
      mcButton.onReleaseDblClick = mcButton.onRelease;
   }
   function HandleInvalidInput()
   {
      _global.SFX.PlayGUIError();
   }
   function SelectOption()
   {
      if(this.Choices[this.CurrentChoiceIndex].Enabled)
      {
         this.OptionSelected(this.CurrentChoiceIndex);
      }
      else
      {
         _global.SFX.PlayGUIError();
      }
   }
   function OptionSelected(nOptionIndex)
   {
      if(nOptionIndex < 0 || nOptionIndex >= this.Choices.length || this.bClosing)
      {
         return undefined;
      }
      flash.external.ExternalInterface.call("ChoiceSelected",this.Choices[nOptionIndex].ChoiceID);
      _global.SFX.PlayGUISound("MessageBoxChoice-SelectionMade");
      this.hide(false);
   }
   function CancelChoice()
   {
      if(this.bClosing)
      {
         return undefined;
      }
      _global.SFX.PlayGUISound("MessageBoxChoice-SelectionMade");
      flash.external.ExternalInterface.call("CancelChoice");
      this.hide(false);
   }
   function onFadeoutComplete()
   {
      flash.external.ExternalInterface.call("CloseChoice");
      this.RemoveFromView();
   }
   function RemoveFromView()
   {
      this._x = -100000;
   }
   function Reposition()
   {
      if(!this._visible)
      {
         return undefined;
      }
      var _loc2_ = com.SFXScreen.GetSafeRect();
      var _loc3_ = com.SFXScreen.GetVisibleRect();
      this._x = _loc2_.left + _loc2_.width * 0.5;
      this._y = _loc2_.top + _loc2_.height * 0.5;
      this.Tint._width = _loc3_.width;
      this.Tint._height = _loc3_.height;
   }
}
