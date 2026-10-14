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
   var m_bEnteringText = false;
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
      switch(Key.getCode())
      {
         case 27:
         case 13:
            this.EndTextInput();
         default:
            return;
      }
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
