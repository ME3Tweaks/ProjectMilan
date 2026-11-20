// MILAN CHANGE - Mgamerz - 11/17/2026
// Add text-entry dialog mode
class screens.MessageBox.MessageBoxWindow extends com.SFXMovieClip
{
   var m_bTextEntry = false;
   var m_bEntryInput = false;
   var m_mcEntry;
   var m_txtEntry;
   var m_oEntryKeys;
   var m_nEntryHeight = 0;
   var m_nEntryGap = 12;
   var m_nEntryMinWidth = 460;
   var m_fnButtonA;
   var m_fnButtonB;
   // END MILAN CHANGE
   var Background;
   var MessageBoxInner;
   var MessageIcon;
   var PC_ATextButton;
   var PC_BTextButton;
   var Text;
   var Tint;
   var XB_AButton;
   var XB_BButton;
   var _visible;
   var _x;
   var _y;
   var gotoAndPlay;
   var gotoAndStop;
   var lineStyle;
   var lineTo;
   var m_bClosing;
   var m_fnOnHide;
   var m_nMinTextWidth;
   var m_nMinWidth;
   var m_nXBButtonBaseFromBottom;
   var m_nXBButtonSpaceY;
   var m_oSliceOffsets;
   var m_oStartBGDimensions;
   var m_ptTextStart;
   var moveTo;
   static var ICONSET_None = 0;
   static var ICONSET_Company = 1;
   static var ICONSET_Talent = 2;
   static var ICONSET_Plot = 3;
   static var ICONSET_Xmods = 4;
   var m_nMaxWidth = 900;
   var m_nMaxTextHeight = 600;
   var m_nElementPadding = 5;
   var bShowAButton = false;
   var bShowBButton = false;
   var bUsingGamepad = false;
   static var TEXTURE_YSCALE_ADJUST = 0;
   function MessageBoxWindow()
   {
      super();
      this.Text = this.MessageBoxInner.Text;
      this.Background = this.MessageBoxInner.Background;
      this.PC_ATextButton = this.MessageBoxInner.PC_ATextButton;
      this.PC_BTextButton = this.MessageBoxInner.PC_BTextButton;
      this.XB_AButton = this.MessageBoxInner.XB_AButton;
      this.XB_BButton = this.MessageBoxInner.XB_BButton;
      this.MessageIcon = this.MessageBoxInner.MessageIcon;
   }
   function onLoad()
   {
      super.onLoad();
      this.RemoveFromView();
      this._visible = false;
      this.m_bClosing = false;
      this.m_nMinWidth = this.Background._width;
      this.m_nMinTextWidth = this.Text._width;
      this.m_ptTextStart = new flash.geom.Point(this.Text._x,this.Text._y);
      var _loc3_ = {xMin:this.Background._x,xMax:this.Background._x + this.Background._width,yMin:this.Background._y,yMax:this.Background._y + this.Background._height};
      this.m_oStartBGDimensions = {width:_loc3_.xMax - _loc3_.xMin,height:_loc3_.yMax - _loc3_.yMin};
      this.Text.text = "Ay";
      this.m_oSliceOffsets = {top:this.Text._y,bottom:_loc3_.yMax - (this.Text._y + this.Text._height),left:this.Text._x - _loc3_.xMin,right:_loc3_.xMax - (this.Text._x + this.Text._width),buttonHeight:0};
      this.XB_AButton.BackgroundOn = false;
      this.XB_BButton.BackgroundOn = false;
      this.XB_AButton.SetVisible(false);
      this.XB_BButton.SetVisible(false);
      this.PC_ATextButton.SetVisible(false);
      this.PC_BTextButton.SetVisible(false);
      this.PC_ATextButton.fromBottom = _loc3_.yMin + this.m_oStartBGDimensions.height - this.PC_ATextButton._y;
      this.PC_ATextButton.fromTextLeft = this.PC_ATextButton._x - this.Text._x;
      this.PC_BTextButton.fromBottom = _loc3_.yMax - this.PC_BTextButton._y;
      this.PC_BTextButton.fromTextRight = this.Text._x + this.Text._width - this.PC_BTextButton._x;
      this.PC_ATextButton.addEventListener("SFXButton_onRelease",this.MakeDelegate(this.PCButtonRelease));
      this.PC_BTextButton.addEventListener("SFXButton_onRelease",this.MakeDelegate(this.PCButtonRelease));
      var _loc5_ = this.XB_AButton.GetVisibleRect();
      var _loc4_ = this.XB_BButton.GetVisibleRect();
      this.m_nXBButtonBaseFromBottom = _loc3_.yMax - _loc4_.bottom;
      this.m_nXBButtonSpaceY = _loc4_.top - _loc5_.bottom;
      if(this.MessageIcon != undefined)
      {
         this.MessageIcon.fromLeft = this.MessageIcon._x - this.Background._x;
         this.MessageIcon._visible = false;
      }
      this.Text.text = "";
      this.Text._height = this.m_nMaxTextHeight;
   }
   function get text()
   {
      return this.Text.text;
   }
   function set text(s)
   {
      this.Text.htmlText = s;
      this.FitText();
   }
   function Show(bSkipFade, bShowBackground)
   {
      this.m_bClosing = false;
      this.Tint._visible = bShowBackground;
      this._visible = true;
      this.Reposition();
      if(bSkipFade == true)
      {
         this.gotoAndStop("Visible");
         if(bShowBackground)
         {
            this.Tint.gotoAndStop("Visible");
         }
      }
      else
      {
         this.gotoAndPlay("FadeIn");
         if(bShowBackground)
         {
            this.Tint.gotoAndPlay("FadeIn");
         }
      }
      _global.SFX.PlayGUISound("MessageBox-Open");
   }
   function Hide(bSkipFade, fnOnHideComplete)
   {
      if(this.m_bClosing != false)
      {
         return undefined;
      }
      this.m_bClosing = true;
      if(bSkipFade == true)
      {
         this.gotoAndStop(0);
         this.onFadeoutComplete();
         fnOnHideComplete();
      }
      else
      {
         this.m_fnOnHide = fnOnHideComplete;
         this.gotoAndPlay("FadeOut");
         if(this.Tint._visible)
         {
            this.Tint.gotoAndPlay("FadeOut");
         }
      }
      Key.removeListener(this);
      this.EndEntryInput();
      _global.SFX.PlayGUISound("MessageBox-Close");
   }
   function onFadeoutComplete()
   {
      this._visible = false;
      if(this.m_fnOnHide != undefined)
      {
         this.m_fnOnHide();
      }
      this.RemoveFromView();
   }
   function RemoveFromView()
   {
      this._x = -100000;
   }
   function GetAButton()
   {
      if(_global.SFX.Platform == com.XPlatform.PC && !this.bUsingGamepad)
      {
         return this.PC_ATextButton;
      }
      return this.XB_AButton;
   }
   function GetBButton()
   {
      if(_global.SFX.Platform == com.XPlatform.PC && !this.bUsingGamepad)
      {
         return this.PC_BTextButton;
      }
      return this.XB_BButton;
   }
   function buttonWidth()
   {
      var _loc5_ = this.GetAButton();
      var _loc4_ = this.GetBButton();
      var _loc3_ = 0;
      var _loc6_;
      var _loc7_;
      if(_global.SFX.Platform == com.XPlatform.PC && !this.bUsingGamepad)
      {
         if(_loc4_._visible == true)
         {
            _loc3_ += _loc4_._width;
         }
         _loc3_ += !_loc5_._visible ? 0 : this.m_nElementPadding;
      }
      else
      {
         _loc6_ = !_loc5_._visible ? 0 : _loc5_.GetVisibleRect().width;
         _loc7_ = !_loc4_._visible ? 0 : _loc4_.GetVisibleRect().width;
         _loc3_ = Math.max(_loc6_,_loc7_);
      }
      return _loc3_;
   }
   function contentWidth()
   {
      var _loc2_ = Math.max(this.buttonWidth(),this.Text._width);
      return _loc2_ + (!(this.MessageIcon != undefined && this.MessageIcon._visible) ? 0 : this.MessageIcon._width + this.m_nElementPadding);
   }
   function contentHeight()
   {
      var _loc2_ = this.Text.textHeight + this.m_oSliceOffsets.buttonHeight + this.EntryBlockHeight();
      if(this.MessageIcon != undefined && this.MessageIcon._visible == true && this.MessageIcon._height > _loc2_)
      {
         return this.MessageIcon._height;
      }
      return _loc2_;
   }
   function SetButtons(sButtonAText, fnButtonA, sButtonBText, fnButtonB)
   {
      this.bShowAButton = sButtonAText != "";
      this.bShowBButton = sButtonBText != "";
      this.m_fnButtonA = fnButtonA;
      this.m_fnButtonB = fnButtonB;
      this.m_oSliceOffsets.buttonHeight = 0;
      if(_global.SFX.Platform == com.XPlatform.PC)
      {
         if(this.bShowAButton && !this.bShowBButton)
         {
            this.PC_BTextButton.SetText(sButtonAText);
            this.PC_BTextButton.fnCallback = fnButtonA;
         }
         else
         {
            if(this.bShowAButton)
            {
               this.PC_ATextButton.SetText(sButtonAText);
               this.PC_ATextButton.fnCallback = fnButtonA;
               this.m_oSliceOffsets.buttonHeight = this.PC_ATextButton._height;
            }
            if(this.bShowBButton)
            {
               this.PC_BTextButton.SetText(sButtonBText);
               this.PC_BTextButton.fnCallback = fnButtonB;
               this.m_oSliceOffsets.buttonHeight = this.PC_BTextButton._height;
            }
         }
      }
      if(this.bShowAButton)
      {
         this.XB_AButton.SetText(sButtonAText);
         this.XB_AButton.fnCallback = fnButtonA;
         this.m_oSliceOffsets.buttonHeight = this.XB_AButton.GetVisibleRect().height;
      }
      if(this.bShowBButton)
      {
         this.XB_BButton.SetText(sButtonBText);
         this.XB_BButton.fnCallback = fnButtonB;
         this.m_oSliceOffsets.buttonHeight += this.XB_BButton.GetVisibleRect().height;
         if(this.bShowAButton)
         {
            this.m_oSliceOffsets.buttonHeight += this.m_nXBButtonSpaceY;
         }
      }
      if(this.bShowAButton || this.bShowBButton)
      {
         Key.addListener(this);
      }
      this.RefreshButtonHelp(this.bUsingGamepad);
      if(this.m_oSliceOffsets.buttonHeight != 0)
      {
         this.m_oSliceOffsets.buttonHeight += 10;
      }
      this.FitText();
   }
   function PCButtonRelease(oData)
   {
      if(oData == undefined || oData.target == undefined)
      {
         return undefined;
      }
      if(oData.target.fnCallback != undefined)
      {
         oData.target.fnCallback();
      }
   }
   function SetIcon(nIconSet, nIconIndex)
   {
      if(this.MessageIcon == undefined)
      {
         return undefined;
      }
      var _loc2_;
      if(nIconSet != screens.MessageBox.MessageBoxWindow.ICONSET_None)
      {
         _loc2_ = null;
         switch(nIconSet)
         {
            case screens.MessageBox.MessageBoxWindow.ICONSET_Company:
               _loc2_ = this.MessageIcon.CompanyIcons;
               break;
            case screens.MessageBox.MessageBoxWindow.ICONSET_Talent:
               _loc2_ = this.MessageIcon.TalentIcons;
               break;
            case screens.MessageBox.MessageBoxWindow.ICONSET_Plot:
               _loc2_ = this.MessageIcon.PlotIcons;
               break;
            case screens.MessageBox.MessageBoxWindow.ICONSET_Xmods:
               _loc2_ = this.MessageIcon.XmodIcons;
         }
         if(_loc2_ != null)
         {
            this.MessageIcon._visible = true;
            this.MessageIcon.CompanyIcons._visible = _loc2_ == this.MessageIcon.CompanyIcons;
            this.MessageIcon.TalentIcons._visible = _loc2_ == this.MessageIcon.TalentIcons;
            this.MessageIcon.PlotIcons._visible = _loc2_ == this.MessageIcon.PlotIcons;
            this.MessageIcon.XmodIcons._visible = _loc2_ == this.MessageIcon.XmodIcons;
            _loc2_.gotoAndStop(nIconIndex);
         }
      }
      else
      {
         this.MessageIcon._visible = false;
      }
      this.FitText();
   }
   function FitText()
   {
      var _loc6_ = 0.4;
      var _loc3_ = 0;
      if(this.MessageIcon != undefined && this.MessageIcon._visible == true)
      {
         _loc3_ = this.MessageIcon._width + this.m_nElementPadding;
      }
      var _loc4_ = this.m_nMinWidth;
      if(_global.SFX.Platform == com.XPlatform.PC)
      {
         _loc4_ = Math.max(this.m_nMinWidth,this.buttonWidth() + _loc3_);
      }
      var _loc8_ = 0;
      var _loc5_ = this.contentWidth();
      var _loc7_ = 50;
      if(this.contentWidth() * _loc6_ < this.Text.textHeight)
      {
         _loc7_ = 50;
         while(this.contentWidth() * _loc6_ < this.Text.textHeight && this.contentWidth() < this.m_nMaxWidth)
         {
            _loc5_ = this.Text._width;
            this.Text._width = this.contentWidth() + 10 - _loc3_;
            if(_loc5_ == this.Text._width || this.contentWidth() > this.m_nMaxWidth)
            {
               this.Text._width = this.m_nMaxWidth - _loc3_;
               break;
            }
            if((_loc7_ = _loc7_ - 1) <= 0)
            {
               break;
            }
         }
      }
      else if(this.contentWidth() * _loc6_ > this.Text.textHeight)
      {
         _loc7_ = 50;
         while(this.contentWidth() * _loc6_ > this.Text.textHeight && this.contentWidth() > _loc4_)
         {
            _loc5_ = this.Text._width;
            this.Text._width = this.contentWidth() - 10 - _loc3_;
            if(this.contentWidth() < _loc4_)
            {
               this.Text._width = _loc4_ - _loc3_;
               break;
            }
            if((_loc7_ = _loc7_ - 1) <= 0)
            {
               break;
            }
         }
      }
      if(this.m_bTextEntry && this.Text._width < this.m_nEntryMinWidth - _loc3_)
      {
         this.Text._width = this.m_nEntryMinWidth - _loc3_;
      }
      this.Background._width = this.contentWidth() + this.m_oSliceOffsets.left + this.m_oSliceOffsets.right;
      this.Background._x = (this.m_oStartBGDimensions.width - this.Background._width) / 2;
      this.Text._x = this.Background._x + _loc3_ + this.m_oSliceOffsets.left;
      this.Background._height = this.contentHeight() + this.m_oSliceOffsets.top + this.m_oSliceOffsets.bottom;
      this.Background._y = (this.m_oStartBGDimensions.height - this.Background._height) / 2;
      this.Text._y = this.Background._y + this.m_oSliceOffsets.top;
      if(this.MessageIcon != undefined)
      {
         this.MessageIcon._x = this.Background._x + this.MessageIcon.fromLeft;
         this.MessageIcon._y = this.Background._y + this.Background._height * 0.5 - 15 - this.Background._height * screens.MessageBox.MessageBoxWindow.TEXTURE_YSCALE_ADJUST * 0.5;
      }
      this.RepositionEntry();
      this.RepositionButtons();
   }
   function DebugDrawBorder(oObj, nColor)
   {
      this.lineStyle(1,nColor);
      this.moveTo(this.MessageBoxInner._x + oObj._x,this.MessageBoxInner._y + oObj._y);
      this.lineTo(this.MessageBoxInner._x + oObj._x + oObj._width,this.MessageBoxInner._y + oObj._y);
      this.lineTo(this.MessageBoxInner._x + oObj._x + oObj._width,this.MessageBoxInner._y + oObj._y + oObj._height);
      this.lineTo(this.MessageBoxInner._x + oObj._x,this.MessageBoxInner._y + oObj._y + oObj._height);
      this.lineTo(this.MessageBoxInner._x + oObj._x,this.MessageBoxInner._y + oObj._y);
   }
   function RepositionButtons()
   {
      var _loc3_ = this.GetAButton();
      var _loc4_ = this.GetBButton();
      var _loc5_;
      var _loc8_;
      var _loc6_;
      var _loc7_;
      if(_global.SFX.Platform == com.XPlatform.PC && !this.bUsingGamepad)
      {
         _loc3_._y = this.Background._y + this.Background._height - _loc3_.fromBottom - screens.MessageBox.MessageBoxWindow.TEXTURE_YSCALE_ADJUST;
         _loc4_._y = this.Background._y + this.Background._height - _loc4_.fromBottom - screens.MessageBox.MessageBoxWindow.TEXTURE_YSCALE_ADJUST;
         _loc3_._x = this.Text._x + _loc3_.fromTextLeft;
         _loc4_._x = this.Text._x + this.Text._width - _loc4_.fromTextRight;
      }
      else
      {
         _loc5_ = 0;
         _loc8_ = _loc3_.GetVisibleRect();
         _loc6_ = _loc4_.GetVisibleRect();
         if(_loc3_._visible == true)
         {
            _loc5_ = _loc8_.width;
         }
         if(_loc4_._visible == true)
         {
            _loc5_ = Math.max(_loc5_,_loc6_.width);
         }
         _loc7_ = this.Text._x + this.Text._width * 0.5 - _loc5_ * 0.5;
         _loc3_._x = _loc7_;
         _loc4_._x = _loc7_;
         _loc3_._y = this.Background._y + this.Background._height - screens.MessageBox.MessageBoxWindow.TEXTURE_YSCALE_ADJUST - this.m_nXBButtonBaseFromBottom - _loc8_.height * 1.5;
         if(_loc3_._visible == true && _loc4_._visible == true)
         {
            _loc3_._y -= _loc6_.height + this.m_nXBButtonSpaceY;
         }
         _loc4_._y = this.Background._y + this.Background._height - screens.MessageBox.MessageBoxWindow.TEXTURE_YSCALE_ADJUST - this.m_nXBButtonBaseFromBottom - _loc6_.height * 1.5;
      }
   }
   function onKeyUp()
   {
      var _loc3_;
      if(this.m_bTextEntry)
      {
         return undefined;
      }
      switch(Key.getCode())
      {
         case com.XInput.ButtonA:
            _loc3_ = this.GetAButton();
            if(_loc3_._visible == true)
            {
               _loc3_.fnCallback();
            }
            else
            {
               _global.SFX.PlayGUIError();
            }
            return;
         case com.XInput.ButtonB:
            _loc3_ = this.GetBButton();
            if(_loc3_._visible == true)
            {
               _loc3_.fnCallback();
            }
            else
            {
               _global.SFX.PlayGUIError();
            }
            return;
         default:
            _global.SFX.PlayGUIError();
            return;
      }
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
   function RefreshButtonHelp(usingGamepad)
   {
      this.bUsingGamepad = usingGamepad;
      if(_global.SFX.Platform == com.XPlatform.PC && !this.bUsingGamepad)
      {
         this.XB_AButton.SetVisible(false);
         this.XB_BButton.SetVisible(false);
         if(this.bShowAButton && !this.bShowBButton)
         {
            this.PC_ATextButton.SetVisible(this.bShowBButton);
            this.PC_BTextButton.SetVisible(this.bShowAButton);
         }
         else
         {
            this.PC_ATextButton.SetVisible(this.bShowAButton);
            this.PC_BTextButton.SetVisible(this.bShowBButton);
         }
      }
      else
      {
         this.PC_ATextButton.SetVisible(false);
         this.PC_BTextButton.SetVisible(false);
         this.XB_AButton.SetVisible(this.bShowAButton);
         this.XB_BButton.SetVisible(this.bShowBButton);
      }
      this.RepositionButtons();
      // Typing goes to the field only with keyboard and mouse; a gamepad uses the platform keyboard.
      if(this.m_bTextEntry && this._visible && !this.m_bClosing)
      {
         if(this.bUsingGamepad)
         {
            this.EndEntryInput();
         }
         else
         {
            this.BeginEntryInput();
         }
      }
   }
   // MILAN CHANGE - Mgamerz - 11/17/2026 - text entry mode
   function SetTextEntry(bEnabled, sDefault, nMaxChars)
   {
      this.m_bTextEntry = bEnabled == true;
      if(this.m_bTextEntry)
      {
         this.CreateEntry();
         this.m_txtEntry.text = sDefault == undefined ? "" : String(sDefault);
         this.m_txtEntry.maxChars = nMaxChars > 0 ? nMaxChars : null;
         this.m_mcEntry._visible = true;
      }
      else if(this.m_mcEntry != undefined)
      {
         this.EndEntryInput();
         this.m_mcEntry._visible = false;
      }
      this.FitText();
   }
   function GetEntryText()
   {
      if(this.m_txtEntry == undefined)
      {
         return "";
      }
      return this.m_txtEntry.text;
   }
   function SetEntryText(sText)
   {
      if(this.m_txtEntry != undefined)
      {
         this.m_txtEntry.text = sText == undefined ? "" : String(sText);
         if(this.m_bEntryInput)
         {
            Selection.setSelection(this.m_txtEntry.text.length,this.m_txtEntry.text.length);
         }
      }
   }
   function EntryBlockHeight()
   {
      if(!this.m_bTextEntry)
      {
         return 0;
      }
      return this.m_nEntryHeight + this.m_nEntryGap * 2;
   }
   function CreateEntry()
   {
      if(this.m_mcEntry != undefined)
      {
         return undefined;
      }
      this.m_mcEntry = this.MessageBoxInner.createEmptyMovieClip("MilanTextEntry",this.MessageBoxInner.getNextHighestDepth());
      this.m_mcEntry.createEmptyMovieClip("Frame",1);
      this.m_mcEntry.attachMovie("MilanTextEntryField","FieldClip",2,{_x:8,_y:5});
      this.m_txtEntry = this.m_mcEntry.FieldClip.Field;
      this.m_nEntryHeight = Math.round(this.m_txtEntry._height) + 10;
      this.m_txtEntry.html = false;
      this.m_txtEntry.text = "";
      this.m_oEntryKeys = new Object();
      this.m_oEntryKeys.onKeyDown = this.MakeDelegate(this.OnEntryKeyDown);
   }
   function RepositionEntry()
   {
      if(this.m_mcEntry == undefined || !this.m_bTextEntry)
      {
         return undefined;
      }
      var _loc3_ = Math.max(40,this.Text._width);
      var _loc2_ = this.m_mcEntry.Frame;
      this.m_mcEntry._x = this.Text._x;
      this.m_mcEntry._y = this.Text._y + this.Text.textHeight + this.m_nEntryGap;
      this.m_txtEntry._width = _loc3_ - 16;
      _loc2_.clear();
      _loc2_.lineStyle(1,9417920,100);
      _loc2_.beginFill(0,60);
      _loc2_.moveTo(0,0);
      _loc2_.lineTo(_loc3_,0);
      _loc2_.lineTo(_loc3_,this.m_nEntryHeight);
      _loc2_.lineTo(0,this.m_nEntryHeight);
      _loc2_.lineTo(0,0);
      _loc2_.endFill();
   }
   function BeginEntryInput()
   {
      if(!this.m_bTextEntry || this.m_txtEntry == undefined)
      {
         return undefined;
      }
      Selection.setFocus(this.m_txtEntry);
      Selection.setSelection(this.m_txtEntry.text.length,this.m_txtEntry.text.length);
      if(!this.m_bEntryInput)
      {
         Key.addListener(this.m_oEntryKeys);
         fscommand(com.UnrealMessages.SetTextInputStream,"Yes");
         this.m_bEntryInput = true;
      }
   }
   function EndEntryInput()
   {
      if(!this.m_bEntryInput)
      {
         return undefined;
      }
      this.m_bEntryInput = false;
      Key.removeListener(this.m_oEntryKeys);
      fscommand(com.UnrealMessages.SetTextInputStream,"No");
      Selection.setFocus(null);
   }
   function OnEntryKeyDown()
   {
      var _loc2_ = Key.getCode();
      if(_loc2_ == 13)
      {
         this.m_fnButtonA();
      }
      else if(_loc2_ == 27)
      {
         this.m_fnButtonB();
      }
      else if(_loc2_ == 86 && Key.isDown(17) || _loc2_ == 45 && Key.isDown(16))
      {
         this.PasteEntryText();
      }
   }
   // Paste the first line of the clipboard at the caret
   function PasteEntryText()
   {
      var _loc6_ = flash.external.ExternalInterface.call("GetClipboardText");
      if(_loc6_ == undefined || _loc6_ == null)
      {
         return undefined;
      }
      var _loc2_ = String(_loc6_);
      var _loc3_ = this.m_txtEntry.text;
      var _loc4_ = Selection.getBeginIndex();
      var _loc5_ = Selection.getEndIndex();
      if(_loc4_ < 0 || _loc5_ < _loc4_)
      {
         _loc4_ = _loc3_.length;
         _loc5_ = _loc3_.length;
      }
      if(this.m_txtEntry.maxChars > 0)
      {
         _loc2_ = _loc2_.substr(0,Math.max(0,this.m_txtEntry.maxChars - (_loc3_.length - (_loc5_ - _loc4_))));
      }
      if(_loc2_.length == 0)
      {
         return undefined;
      }
      this.m_txtEntry.text = _loc3_.substr(0,_loc4_) + _loc2_ + _loc3_.substr(_loc5_);
      Selection.setSelection(_loc4_ + _loc2_.length,_loc4_ + _loc2_.length);
   }
}
