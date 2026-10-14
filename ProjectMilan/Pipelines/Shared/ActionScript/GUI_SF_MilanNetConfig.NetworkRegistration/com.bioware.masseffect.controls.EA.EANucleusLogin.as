// MILAN CHANGE - Mgamerz - 2026-10-10
// The EA Nucleus login panel is repurposed as the Project Milan multiplayer settings panel: profile
// name, matchmaking on/off, matchmaking server default/custom, custom server address and password,
// then Accept / Cancel. The server switch is disabled while matchmaking is off, and the address and
// password are only enabled for a custom server. Read-only mode (outside the multiplayer menu) disables
// everything except Cancel. All text comes from script so it is localized.
// The class keeps its original name so the sprite's class registration is unchanged.
class com.bioware.masseffect.controls.EA.EANucleusLogin extends com.bioware.masseffect.controls.EA.EASubScreen
{
   var RegisterControl;
   var Title;
   var m_mcName;
   var m_mcMatchmaking;
   var m_mcServerType;
   var m_mcServer;
   var m_mcPassword;
   var m_mcAccept;
   var m_mcCancel;
   var m_txtMessage;
   var m_bReadOnly = false;
   function EANucleusLogin()
   {
      super();
   }
   function Init()
   {
      super.Init();
      this.m_mcPassword.Password = true;
      this.RegisterControl(this.m_mcName);
      this.RegisterControl(this.m_mcMatchmaking);
      this.RegisterControl(this.m_mcServerType);
      this.RegisterControl(this.m_mcServer);
      this.RegisterControl(this.m_mcPassword);
      this.RegisterControl(this.m_mcAccept);
      this.RegisterControl(this.m_mcCancel);
      this.m_mcName.GameSideTextFunction = "EnterPlayerName";
      this.m_mcServer.GameSideTextFunction = "EnterServer";
      this.m_mcPassword.GameSideTextFunction = "EnterServerPassword";
      this.m_mcMatchmaking.RegisterChangeFunction(this,this.RefreshEnabled);
      this.m_mcServerType.RegisterChangeFunction(this,this.RefreshEnabled);
      this.m_mcAccept.RegisterExecuteFunction(this,this.onAccept);
      this.m_mcCancel.RegisterExecuteFunction(this,this.onCancel);
   }
   function SetLabels(sTitle, sMessage, sName, sMatchmaking, sServerType, sServer, sPassword, sOn, sOff, sDefault, sCustom, sAccept, sCancel)
   {
      this.Title = sTitle;
      this.m_txtMessage.text = sMessage;
      this.m_mcName.text = sName;
      this.m_mcMatchmaking.text = sMatchmaking;
      this.m_mcServerType.text = sServerType;
      this.m_mcServer.text = sServer;
      this.m_mcPassword.text = sPassword;
      this.m_mcMatchmaking.SetOptionText(sOn,sOff);
      this.m_mcServerType.SetOptionText(sCustom,sDefault);
      this.m_mcAccept.text = sAccept;
      this.m_mcCancel.text = sCancel;
   }
   function RefreshEnabled()
   {
      var _loc4_ = this.m_bReadOnly == true;
      var _loc2_ = this.m_mcMatchmaking.YesNo == true;
      var _loc3_ = _loc2_ && this.m_mcServerType.YesNo == true;
      if(_loc4_)
      {
         this.m_mcName.EndTextInput();
      }
      this.m_mcName.Disabled = _loc4_;
      this.m_mcMatchmaking.Disabled = _loc4_;
      this.m_mcServerType.Disabled = _loc4_ || !_loc2_;
      if(_loc4_ || !_loc3_)
      {
         this.m_mcServer.EndTextInput();
         this.m_mcPassword.EndTextInput();
      }
      this.m_mcServer.Disabled = _loc4_ || !_loc3_;
      this.m_mcPassword.Disabled = _loc4_ || !_loc3_;
      this.m_mcAccept.Disabled = _loc4_;
      if(this.m_SelectedControl != null && this.m_SelectedControl.Disabled)
      {
         this.ClearSelectedControl();
         if(this.m_ScreenLayout != com.XPlatform.PC)
         {
            this.MoveSelection(1);
         }
      }
   }
   function EndTextInput()
   {
      this.m_mcName.EndTextInput();
      this.m_mcServer.EndTextInput();
      this.m_mcPassword.EndTextInput();
   }
   function Submit(bAccept)
   {
      this.EndTextInput();
      flash.external.ExternalInterface.call("SubmitNetConfig",this.m_mcName.Data,this.m_mcMatchmaking.YesNo == true,this.m_mcServerType.YesNo == true,this.m_mcServer.Data,this.m_mcPassword.Data,bAccept);
   }
   function onAccept()
   {
      this.Submit(true);
   }
   function onCancel()
   {
      this.Submit(false);
   }
   function SetValues(sName, bMatchmaking, bCustomServer, sServer, sPassword, bReadOnly)
   {
      this.m_bReadOnly = bReadOnly == true;
      this.m_mcName.Data = sName;
      this.m_mcServer.Data = sServer;
      this.m_mcPassword.Data = sPassword;
      this.m_mcServerType.YesNo = bCustomServer;
      this.m_mcMatchmaking.YesNo = bMatchmaking;
      this.RefreshEnabled();
   }
   function SetInputFieldMaxChar(nNameMaxChar, nServerMaxChar, nPasswordMaxChar)
   {
      this.m_mcName.maxChars = nNameMaxChar;
      this.m_mcServer.maxChars = nServerMaxChar;
      this.m_mcPassword.maxChars = nPasswordMaxChar;
   }
}
