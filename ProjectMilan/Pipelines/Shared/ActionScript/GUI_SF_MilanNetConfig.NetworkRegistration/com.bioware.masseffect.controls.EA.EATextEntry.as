// MILAN CHANGE - Mgamerz - 2026-10-10
// A gamepad taking over mid-edit ends keyboard text input; the field then uses the platform keyboard on execute.
// Disabled fields ignore execute.
class com.bioware.masseffect.controls.EA.EATextEntry extends com.bioware.masseffect.controls.EA.EANetworkControl
{
   var m_ScreenLayout;
   var m_bDisabled;
   var m_active;
   var m_dataTxt;
   var m_sGameSideFunction;
   var onEnterFrame;
   var m_bEnteringText = false;
   var m_sFallbackChar;
   var m_sTextAtKeyDown;
   function EATextEntry()
   {
      super();
   }
   function Execute()
   {
      if(this.m_bDisabled)
      {
         return undefined;
      }
      if(this.m_ScreenLayout != com.XPlatform.PC)
      {
         flash.external.ExternalInterface.call(this.m_sGameSideFunction,this.Data);
      }
      else
      {
         this.BeginTextInput();
      }
   }
   function onKeyDown()
   {
      var _loc2_ = Key.getCode();
      if(_loc2_ == 27 || _loc2_ == 13)
      {
         this.EndTextInput();
      }
      else if(_loc2_ == 86 && Key.isDown(17) || _loc2_ == 45 && Key.isDown(16))
      {
         this.PasteText();
      }
      else if(!Key.isDown(17))
      {
         if(_loc2_ == 186 && Key.isDown(16))
         {
            this.QueueFallbackChar(":");
         }
         else if(_loc2_ == 191 && !Key.isDown(16) || _loc2_ == 111)
         {
            this.QueueFallbackChar("/");
         }
      }
   }
   function PasteText()
   {
      var _loc2_ = flash.external.ExternalInterface.call("GetClipboardText");
      if(_loc2_ != undefined && _loc2_ != null && String(_loc2_).length > 0)
      {
         this.InsertText(String(_loc2_));
      }
   }
   function QueueFallbackChar(sChar)
   {
      this.m_sFallbackChar = sChar;
      this.m_sTextAtKeyDown = this.m_dataTxt.text;
      this.onEnterFrame = this.ApplyFallbackChar;
   }
   function ApplyFallbackChar()
   {
      delete this.onEnterFrame;
      if(this.m_bEnteringText && this.m_dataTxt.text == this.m_sTextAtKeyDown)
      {
         this.InsertText(this.m_sFallbackChar);
      }
   }
   function InsertText(sText)
   {
      var _loc3_ = this.m_dataTxt.text;
      var _loc4_ = Selection.getBeginIndex();
      var _loc5_ = Selection.getEndIndex();
      if(_loc4_ < 0 || _loc5_ < _loc4_)
      {
         _loc4_ = _loc3_.length;
         _loc5_ = _loc3_.length;
      }
      if(this.m_dataTxt.maxChars > 0)
      {
         sText = sText.substr(0,Math.max(0,this.m_dataTxt.maxChars - (_loc3_.length - (_loc5_ - _loc4_))));
      }
      if(sText.length == 0)
      {
         return undefined;
      }
      this.m_dataTxt.text = _loc3_.substr(0,_loc4_) + sText + _loc3_.substr(_loc5_);
      Selection.setSelection(_loc4_ + sText.length,_loc4_ + sText.length);
   }
   function set Data(sVal)
   {
      this.m_dataTxt.text = sVal;
   }
   function get Data()
   {
      return this.m_dataTxt.text;
   }
   function BeginTextInput()
   {
      Selection.setFocus(this.m_dataTxt);
      Key.addListener(this);
      this.m_bEnteringText = true;
      fscommand(com.UnrealMessages.SetTextInputStream,"Yes");
      _global.SFX.PlayGUISound("EANetworkOnExecute");
   }
   function EndTextInput()
   {
      fscommand(com.UnrealMessages.SetTextInputStream,"No");
      Selection.setFocus(null);
      Key.removeListener(this);
      this.m_bEnteringText = false;
   }
   function SetPlatformLayout(nPlatformID)
   {
      super.SetPlatformLayout(nPlatformID);
      if(nPlatformID != com.XPlatform.PC && this.m_bEnteringText)
      {
         this.EndTextInput();
      }
   }
   function set GameSideTextFunction(sVal)
   {
      this.m_sGameSideFunction = sVal;
   }
   function set Password(bVal)
   {
      this.m_dataTxt.password = bVal;
   }
   function get Password()
   {
      return this.m_dataTxt.password;
   }
   function set maxChars(nVal)
   {
      this.m_dataTxt.maxChars = nVal;
   }
   function get maxChars()
   {
      return this.m_dataTxt.maxChars;
   }
   function set active(bVal)
   {
      super.active = bVal;
      this.m_active = bVal;
      if(!bVal)
      {
         this.EndTextInput();
      }
   }
}
