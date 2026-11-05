// MILAN CHANGE - Mgamerz - 2026-10-10
// Root timeline for the Project Milan multiplayer settings screen. Only the settings panel (the
// repurposed Nucleus login) and the message box remain on stage; the other EA registration screens
// are no longer placed. All text and the platform layout come from SFXGUI_MilanNetConfig.
function GlobalVisible(bVal)
{
   mcNetConfig._visible = bVal;
   mcMessageBox._visible = bVal;
   mcBackground._visible = bVal;
   WaitIndicator._visible = bVal;
}
function SetWaitIndicatorVisibility(bVal)
{
   WaitIndicator._visible = bVal;
   mcBackground._visible = bVal;
}
function Initialize()
{
   mcNetConfig.Init();
   mcMessageBox.Init();
   WaitIndicator.htmlText = "$345713";
   WaitIndicator._visible = false;
   flash.external.ExternalInterface.call("onExternalInitialize");
}
function onGameSideInit(nPlatformID, nNameMaxChar, nServerMaxChar, nPasswordMaxChar)
{
   SetPlatformLayout(nPlatformID);
   mcNetConfig.SetInputFieldMaxChar(nNameMaxChar,nServerMaxChar,nPasswordMaxChar);
}
function SetLabels(sTitle, sMessage, sName, sMatchmaking, sServerType, sServer, sPassword, sOn, sOff, sDefault, sCustom, sAccept, sCancel)
{
   mcNetConfig.SetLabels(sTitle,sMessage,sName,sMatchmaking,sServerType,sServer,sPassword,sOn,sOff,sDefault,sCustom,sAccept,sCancel);
}
function SetPlatformLayout(nPlatformID)
{
   _global.PlatformID = nPlatformID;
   mcNetConfig.SetPlatformLayout(nPlatformID);
   mcMessageBox.SetPlatformLayout(nPlatformID);
}
function SetBGVisibility(bNewValue)
{
   if(bNewValue != mcBackground._visible)
   {
      flash.external.ExternalInterface.call("GFxScreenVisibilityChange",bNewValue);
      mcBackground._visible = bNewValue;
   }
}
function ShowSubscreen_NetConfig(sName, bMatchmaking, bCustomServer, sServer, sPassword, bReadOnly)
{
   ClearActiveSubscreen();
   mcActiveSubscreen = mcNetConfig;
   mcNetConfig.SetValues(sName,bMatchmaking,bCustomServer,sServer,sPassword,bReadOnly);
   mcNetConfig._visible = true;
   SetBGVisibility(true);
}
function ShowSubscreen_MessageBox(sTitle, sMessage, sButton1Text, sButton2Text, sButton3Text)
{
   ClearActiveSubscreen();
   mcActiveSubscreen = mcMessageBox;
   mcMessageBox.Reset(false);
   mcMessageBox.Title = sTitle;
   mcMessageBox.text = sMessage;
   if(sButton1Text != null && sButton1Text != undefined && sButton1Text != "")
   {
      mcMessageBox.RegisterExItem1(null,null,sButton1Text);
   }
   if(sButton2Text != null && sButton2Text != undefined && sButton2Text != "")
   {
      mcMessageBox.RegisterExItem2(null,null,sButton2Text);
   }
   if(sButton3Text != null && sButton3Text != undefined && sButton3Text != "")
   {
      mcMessageBox.RegisterExItem3(null,null,sButton3Text);
   }
   mcMessageBox.SetPlatformLayout(_global.PlatformID);
   mcMessageBox._visible = true;
   SetBGVisibility(true);
}
function ClearActiveSubscreen()
{
   SetBGVisibility(false);
   if(mcActiveSubscreen != null)
   {
      mcActiveSubscreen._visible = false;
   }
   mcActiveSubscreen = null;
   _root.SetWaitIndicatorVisibility(false);
}
function NextControl()
{
   if(mcActiveSubscreen != null)
   {
      mcActiveSubscreen.NextControl();
   }
}
function PreviousControl()
{
   if(mcActiveSubscreen != null)
   {
      mcActiveSubscreen.PreviousControl();
   }
}
function ExecuteControl()
{
   if(mcActiveSubscreen != null)
   {
      mcActiveSubscreen.ExecuteControl();
   }
}
function OnInputLeft()
{
   if(mcActiveSubscreen != null)
   {
      mcActiveSubscreen.OnInputLeft();
   }
}
function OnInputRight()
{
   if(mcActiveSubscreen != null)
   {
      mcActiveSubscreen.OnInputRight();
   }
}
function ScrollControl(nScroll)
{
   if(mcActiveSubscreen != null)
   {
      mcActiveSubscreen.ScrollControl(nScroll);
   }
}
function SetActiveInputField(sVal)
{
   if(mcActiveSubscreen != null)
   {
      mcActiveSubscreen.SetActiveInputField(sVal);
   }
}
// LE3 removes Slash from its native GFx key map, before AS2 onKeyDown can see it.
// The screen's scoped raw-key delegate forwards only Slash presses/repeats here.
function QueueNativeSlash()
{
   var field = _root.milanTextInput;
   if(mcActiveSubscreen == mcNetConfig && mcNetConfig._visible && field != undefined && field.m_bEnteringText && !field.m_bDisabled && Selection.getFocus() == String(field.m_dataTxt) && !Key.isDown(16) && !Key.isDown(17) && !Key.isDown(18))
   {
      field.QueueFallbackChar("/");
   }
}
function OnHandleInputConfigurations(bMenuAdvanceSwapped, bStickSouthpaw, bTriggerSouthpaw, bTriggersShouldersSwapped)
{
   mcNetConfig.OnHandleInputConfigurations(bMenuAdvanceSwapped,bStickSouthpaw,bTriggerSouthpaw,bTriggersShouldersSwapped);
   mcMessageBox.OnHandleInputConfigurations(bMenuAdvanceSwapped,bStickSouthpaw,bTriggerSouthpaw,bTriggersShouldersSwapped);
}
com.SFXScreen.RegisterCallback_HandleInputConfigurations(null,OnHandleInputConfigurations);
Stage.scaleMode = "noBorder";
_global.gfxExtensions = true;
var mcNetConfig = m_mcNetConfig;
var mcMessageBox = m_mcMessageBox;
var WaitIndicator = m_WaitIndicator;
var mcActiveSubscreen = null;
GlobalVisible(false);
OnHandleInputConfigurations(false,false,false,false);
stop();
