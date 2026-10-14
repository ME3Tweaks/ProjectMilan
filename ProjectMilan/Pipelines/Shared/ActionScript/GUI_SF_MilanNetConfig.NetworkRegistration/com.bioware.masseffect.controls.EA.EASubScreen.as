// MILAN CHANGE - Mgamerz - 2026-10-10
// Switching to a gamepad at runtime selects the first control, since PC layout leaves nothing selected.
// Up/down navigation skips disabled controls.
class com.bioware.masseffect.controls.EA.EASubScreen extends MovieClip
{
   var m_Controls;
   var m_ScreenLayout;
   var m_SelectedControl;
   var m_SelectedControlIndex;
   var m_mcDimensions;
   var mc_Background;
   var txtTitle;
   static var c_BackgroundBorderExt = 50;
   static var c_TEXT_BTN_YES = "$315179";
   static var c_TEXT_BTN_NO = "$315180";
   static var c_TEXT_BTN_CANCEL = "$315182";
   static var c_TEXT_BTN_CONTINUE = "$315181";
   static var c_TEXT_BTN_ACCEPT = "$315178";
   static var c_TEXT_BTN_DECLINE = "$315177";
   static var c_TEXT_BTN_MOREINFO = "$315193";
   var m_bMenuAdvanceSwapped = false;
   var m_bStickSouthpaw = false;
   var m_bTriggerSouthpaw = false;
   var m_bTriggersShouldersSwapped = false;
   function EASubScreen()
   {
      super();
      mx.events.EventDispatcher.initialize(this);
      this.m_Controls = new Array();
      this.m_mcDimensions._visible = false;
      this.mc_Background._width = this.m_mcDimensions._width;
   }
   function Init()
   {
      this.tabChildren = false;
      this.tabEnabled = false;
   }
   function SetPlatformLayout(nPlatformID)
   {
      var _loc2_ = 0;
      this.m_ScreenLayout = nPlatformID;
      _loc2_ = 0;
      var _loc3_;
      while(_loc2_ < this.m_Controls.length)
      {
         _loc3_ = com.bioware.masseffect.controls.EA.EANetworkControl(this.m_Controls[_loc2_]);
         if(_loc3_ != null)
         {
            _loc3_.SetPlatformLayout(nPlatformID);
         }
         _loc2_ = _loc2_ + 1;
      }
      if(nPlatformID == com.XPlatform.PC)
      {
         this.ClearSelectedControl();
      }
      else if(this.m_SelectedControl == null && this.m_Controls.length > 0)
      {
         this.MoveSelection(1);
      }
   }
   function set Title(sVal)
   {
      this.txtTitle.htmlText = sVal;
   }
   function get Title()
   {
      return this.txtTitle.htmlText;
   }
   function set SelectedControlIndex(p_controlIndex)
   {
      if(p_controlIndex < 0 || p_controlIndex > this.m_Controls.length - 1)
      {
         _global.SFX.PlayGUIError();
         return;
      }
      if(this.m_SelectedControlIndex == p_controlIndex)
      {
         return;
      }
      if(this.m_SelectedControl != null)
      {
         this.m_SelectedControl.active = false;
      }
      if(this.m_SelectedControlIndex == undefined || this.m_SelectedControlIndex < 0)
      {
         _global.SFX.PlayGUISound("EANetworkOnSelect");
      }
      this.m_SelectedControl = this.m_Controls[p_controlIndex];
      this.m_SelectedControl.active = true;
      this.m_SelectedControlIndex = p_controlIndex;
   }
   function get SelectedControlIndex()
   {
      return this.m_SelectedControlIndex;
   }
   function ClearSelectedControl()
   {
      if(this.m_SelectedControl != null)
      {
         this.m_SelectedControl.active = false;
         this.m_SelectedControl = null;
         this.m_SelectedControlIndex = -1;
      }
   }
   function RegisterControl(p_control)
   {
      p_control.OnHandleInputConfigurations(this.m_bMenuAdvanceSwapped,this.m_bStickSouthpaw,this.m_bTriggerSouthpaw,this.m_bTriggersShouldersSwapped);
      this.m_Controls.push(p_control);
      p_control.Index = this.m_Controls.length - 1;
      if(p_control.m_Delegate != null)
      {
         p_control.removeEventListener("EANetworkControl_onRelease",p_control.m_Delegate);
      }
      p_control.m_Delegate = mx.utils.Delegate.create(this,this.onControlReleased);
      p_control.addEventListener("EANetworkControl_onRelease",p_control.m_Delegate);
      if(this.m_ScreenLayout != com.XPlatform.PC && this.m_Controls.length == 1)
      {
         this.SelectedControlIndex = 0;
      }
   }
   function onControlReleased(p_event)
   {
      var _loc2_ = com.bioware.masseffect.controls.EA.EANetworkControl(p_event.target);
      if(_loc2_ != null)
      {
         if(this.SelectedControlIndex != _loc2_.Index)
         {
            this.SelectedControlIndex = _loc2_.Index;
         }
         _loc2_.Execute();
      }
   }
   function NextControl()
   {
      this.MoveSelection(1);
   }
   function PreviousControl()
   {
      this.MoveSelection(-1);
   }
   function MoveSelection(nDirection)
   {
      var _loc2_ = this.m_SelectedControlIndex;
      if(_loc2_ == undefined || _loc2_ < 0)
      {
         _loc2_ = nDirection > 0 ? -1 : this.m_Controls.length;
      }
      _loc2_ += nDirection;
      while(_loc2_ >= 0 && _loc2_ < this.m_Controls.length && this.m_Controls[_loc2_].Disabled)
      {
         _loc2_ += nDirection;
      }
      this.SelectedControlIndex = _loc2_;
   }
   function OnInputLeft()
   {
      this.m_Controls[this.SelectedControlIndex].OnInputLeft();
   }
   function OnInputRight()
   {
      this.m_Controls[this.SelectedControlIndex].OnInputRight();
   }
   function ExecuteControl()
   {
      this.m_Controls[this.SelectedControlIndex].Execute();
   }
   function ScrollControl(nScroll)
   {
      this.m_Controls[this.SelectedControlIndex].ScrollControl(nScroll);
   }
   function SetActiveInputField(sVal)
   {
      var _loc2_ = null;
      _loc2_ = this.m_Controls[this.SelectedControlIndex];
      if(_loc2_ != null)
      {
         _loc2_.Data = sVal;
      }
   }
   function OnHandleInputConfigurations(bMenuAdvanceSwapped, bStickSouthpaw, bTriggerSouthpaw, bTriggersShouldersSwapped)
   {
      var _loc2_ = 0;
      this.m_bMenuAdvanceSwapped = bMenuAdvanceSwapped;
      this.m_bStickSouthpaw = bStickSouthpaw;
      this.m_bTriggerSouthpaw = bTriggerSouthpaw;
      this.m_bTriggersShouldersSwapped = bTriggersShouldersSwapped;
      _loc2_ = 0;
      var _loc3_;
      while(_loc2_ < this.m_Controls.length)
      {
         _loc3_ = com.bioware.masseffect.controls.EA.EANetworkControl(this.m_Controls[_loc2_]);
         if(_loc3_ != null)
         {
            _loc3_.OnHandleInputConfigurations(bMenuAdvanceSwapped,bStickSouthpaw,bTriggerSouthpaw,bTriggersShouldersSwapped);
         }
         _loc2_ = _loc2_ + 1;
      }
   }
}
