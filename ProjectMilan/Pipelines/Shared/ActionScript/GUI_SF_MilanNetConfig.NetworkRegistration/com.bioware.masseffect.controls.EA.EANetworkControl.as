// MILAN CHANGE - Mgamerz - 2026-10-10
// The layout now switches at runtime, so the controller button icon has to come back when a gamepad takes over.
// Disabled greys a control out and stops mouse input; EASubScreen navigation skips it.
class com.bioware.masseffect.controls.EA.EANetworkControl extends MovieClip
{
   var dispatchEvent;
   var m_IndexWithinController;
   var m_ScreenLayout;
   var m_labelTxt;
   var m_mcButton;
   static var c_bSuppressEvents = false;
   var m_active = false;
   var m_ExecuteObject = null;
   var m_ExecuteFunction = null;
   var m_Delegate = null;
   var m_bDisabled = false;
   function EANetworkControl()
   {
      super();
      mx.events.EventDispatcher.initialize(this);
   }
   function set text(sString)
   {
      this.m_labelTxt.htmlText = sString;
   }
   function get text()
   {
      return this.m_labelTxt.htmlText;
   }
   function set Index(p_Index)
   {
      this.m_IndexWithinController = p_Index;
   }
   function get Index()
   {
      return this.m_IndexWithinController;
   }
   function set active(bVal)
   {
      this.m_active = bVal;
      if(bVal)
      {
         this.gotoAndPlay("selected");
      }
      else
      {
         this.gotoAndPlay("normal");
      }
   }
   function set Disabled(bVal)
   {
      this.m_bDisabled = bVal;
      this.enabled = !bVal;
      this._alpha = !bVal ? 100 : 35;
      if(bVal && this.m_active)
      {
         this.active = false;
      }
   }
   function get Disabled()
   {
      return this.m_bDisabled;
   }
   function Execute()
   {
      if(this.m_ExecuteFunction != null)
      {
         this.m_ExecuteFunction.call(this.m_ExecuteObject);
      }
      _global.SFX.PlayGUISound("EANetworkOnExecute");
   }
   function ScrollControl(nScroll)
   {
   }
   function RegisterExecuteFunction(p_obj, p_function)
   {
      this.m_ExecuteObject = p_obj;
      this.m_ExecuteFunction = p_function;
   }
   static function set SuppressEvents(bVal)
   {
      com.bioware.masseffect.controls.EA.EANetworkControl.c_bSuppressEvents = bVal;
   }
   static function get SuppressEvents()
   {
      return com.bioware.masseffect.controls.EA.EANetworkControl.c_bSuppressEvents;
   }
   function onPress()
   {
      if(com.bioware.masseffect.controls.EA.EANetworkControl.c_bSuppressEvents)
      {
         return undefined;
      }
      this.gotoAndPlay("pressed");
      super.onPress();
   }
   function onRelease()
   {
      if(com.bioware.masseffect.controls.EA.EANetworkControl.c_bSuppressEvents)
      {
         return undefined;
      }
      super.onRelease();
      if(!this.m_active)
      {
         this.gotoAndPlay("rollOff");
      }
      else
      {
         this.gotoAndPlay("selected");
      }
      this.dispatchEvent({type:"EANetworkControl_onRelease",target:this});
   }
   function onReleaseOutside()
   {
      if(com.bioware.masseffect.controls.EA.EANetworkControl.c_bSuppressEvents)
      {
         return undefined;
      }
      super.onReleaseOutside();
      if(!this.m_active)
      {
         this.gotoAndPlay("rollOff");
      }
      else
      {
         this.gotoAndPlay("selected");
      }
   }
   function onRollOut()
   {
      if(com.bioware.masseffect.controls.EA.EANetworkControl.c_bSuppressEvents)
      {
         return undefined;
      }
      super.onRollOut();
      if(!this.m_active)
      {
         this.gotoAndPlay("rollOff");
      }
   }
   function onRollOver()
   {
      if(com.bioware.masseffect.controls.EA.EANetworkControl.c_bSuppressEvents)
      {
         return undefined;
      }
      super.onRollOver();
      if(!this.m_active)
      {
         this.gotoAndPlay("rollOn");
         _global.SFX.PlayGUISound("EANetworkOnSelect");
      }
   }
   function OnInputLeft()
   {
   }
   function OnInputRight()
   {
   }
   function SetPlatformLayout(nPlatformID)
   {
      this.m_ScreenLayout = nPlatformID;
      this.m_mcButton._visible = nPlatformID != com.XPlatform.PC;
   }
   function OnHandleInputConfigurations(bMenuAdvanceSwapped, bStickSouthpaw, bTriggerSouthpaw, bTriggersShouldersSwapped)
   {
      this.m_mcButton.mcButtonAorB.mcButtonA._visible = !bMenuAdvanceSwapped;
      this.m_mcButton.mcButtonAorB.mcButtonB._visible = bMenuAdvanceSwapped;
   }
}
