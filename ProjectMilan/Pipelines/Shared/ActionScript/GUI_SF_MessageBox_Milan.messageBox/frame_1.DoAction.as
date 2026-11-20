// MILAN CHANGE - 11/17/2026 - Mgamerz
// Text entry mode for Milan dialog
function Initialize()
{
   Stage.scaleMode = "noBorders";
   _global.noInvisibleAdvance = true;
   _global.gfxExtensions = true;
   com.SFXScreen.OnResize = OnResize;
   OnResize();
}
function AddShowHideMethods(obj)
{
   if(obj.Show == undefined)
   {
      obj.Show = function(bSkipFade)
      {
         if(bSkipFade == true)
         {
            obj.gotoAndStop("Visible");
         }
         else
         {
            obj.gotoAndPlay("FadeIn");
         }
      };
   }
   if(obj.Hide == undefined)
   {
      obj.Hide = function(bSkipFade)
      {
         if(bSkipFade == true)
         {
            obj.gotoAndStop(0);
            _root.onMessageBoxHidden();
         }
         else
         {
            obj.fnOnFadeOutComplete = _root.onMessageBoxHidden;
            obj.gotoAndPlay("FadeOut");
         }
      };
   }
}
function ShowHintMessage(sGamepadMessage, sPCMessage, usingGamepad, nPosition)
{
   if(nPosition == undefined)
   {
      nPosition = POSITION_BOTTOM;
   }
   gamepadHintString = sGamepadMessage;
   pcHintString = sPCMessage;
   g_oCurrentMessage = mcTutorial;
   mcTutorial.position = nPosition;
   mcTutorial.Show(false);
   RefreshButtonHelp(usingGamepad);
}
function ShowMessageBox(sMessage, sKBMMessage, sAText, sBText, bNoFade, nIconSet, nIconIndex, nBGType, nTextAlign)
{
   pcBoxString = sKBMMessage;
   gamepadBoxString = sMessage;
   switch(nBGType)
   {
      case g_BG_Normal:
         g_oCurrentMessage = MessageMain;
         g_oCurrentMessageBox = MessageMain;
         if(MessageMain_D1.getDepth() > MessageMain.getDepth())
         {
            MessageMain.swapDepths(MessageMain_D1);
         }
         break;
      case g_BG_DesignerSkin1:
         g_oCurrentMessage = MessageMain_D1;
         g_oCurrentMessageBox = MessageMain_D1;
         if(MessageMain.getDepth() > MessageMain_D1.getDepth())
         {
            MessageMain_D1.swapDepths(MessageMain);
         }
   }
   g_oCurrentMessageBox.SetIcon(nIconSet,nIconIndex);
   g_oCurrentMessageBox.SetButtons(sAText,onAButtonPress,sBText,onBButtonPress);
   AddShowHideMethods(g_oCurrentMessageBox);
   g_oCurrentMessageBox.Show(bNoFade,true);
   RefreshButtonHelp(bUsingGamepad);
}
function onAButtonPress()
{
   _global.SFX.PlayGUISound("MessageBoxA");
   g_sPendingEvent = "MessageBoxAPressed";
   g_oCurrentMessageBox.Hide(false,onMessageBoxHidden);
}
function onBButtonPress()
{
   _global.SFX.PlayGUISound("MessageBoxB");
   g_sPendingEvent = "MessageBoxBPressed";
   g_oCurrentMessageBox.Hide(false,onMessageBoxHidden);
}
// MILAN CHANGE - Mgamerz - 11/17/2026
// Text entry box for SFXGUI_MilanTextEntryBox
function ShowTextEntryBox(sMessage, sKBMMessage, sAText, sBText, sDefault, nMaxChars)
{
   pcBoxString = sKBMMessage;
   gamepadBoxString = sMessage;
   g_bTextEntry = true;
   g_sPendingText = "";
   g_sPendingEvent = "";
   g_oCurrentMessage = MessageMain;
   g_oCurrentMessageBox = MessageMain;
   if(MessageMain_D1.getDepth() > MessageMain.getDepth())
   {
      MessageMain.swapDepths(MessageMain_D1);
   }
   g_oCurrentMessageBox.SetIcon(0,0);
   g_oCurrentMessageBox.SetTextEntry(true,sDefault,nMaxChars);
   g_oCurrentMessageBox.SetButtons(sAText,onTextEntryAccept,sBText,onTextEntryCancel);
   AddShowHideMethods(g_oCurrentMessageBox);
   g_oCurrentMessageBox.Show(false,true);
   RefreshButtonHelp(bUsingGamepad);
}
function onTextEntryAccept()
{
   if(!g_bTextEntry || g_sPendingEvent != "" || g_oCurrentMessageBox == undefined)
   {
      return undefined;
   }
   g_sPendingText = g_oCurrentMessageBox.GetEntryText();
   _global.SFX.PlayGUISound("MessageBoxA");
   g_sPendingEvent = "MessageBoxAPressed";
   g_oCurrentMessageBox.Hide(false,onMessageBoxHidden);
}
function onTextEntryCancel()
{
   if(!g_bTextEntry || g_sPendingEvent != "" || g_oCurrentMessageBox == undefined)
   {
      return undefined;
   }
   _global.SFX.PlayGUISound("MessageBoxB");
   g_sPendingEvent = "MessageBoxBPressed";
   g_oCurrentMessageBox.Hide(false,onMessageBoxHidden);
}

function AcceptTextEntry(sText)
{
   if(sText != undefined && g_oCurrentMessageBox != undefined)
   {
      g_oCurrentMessageBox.SetEntryText(sText);
   }
   onTextEntryAccept();
}
function CancelTextEntry()
{
   onTextEntryCancel();
}
function GetTextEntryText()
{
   if(!g_bTextEntry || g_oCurrentMessageBox == undefined)
   {
      return "";
   }
   return g_oCurrentMessageBox.GetEntryText();
}

function onMessageBoxHidden()
{
   var bAccepted;
   var sText;
   if(g_bTextEntry)
   {
      bAccepted = g_sPendingEvent == "MessageBoxAPressed";
      sText = !bAccepted ? "" : g_sPendingText;
      g_bTextEntry = false;
      g_sPendingText = "";
      g_sPendingEvent = "";
      MessageMain.SetTextEntry(false);
      g_oCurrentMessageBox = undefined;
      flash.external.ExternalInterface.call("OnTextEntryClosed",bAccepted,sText);
      return undefined;
   }
   if(g_sPendingEvent == "")
   {
      g_sPendingEvent = "MessageBoxRemoved";
   }
   flash.external.ExternalInterface.call(g_sPendingEvent);
   g_sPendingEvent = "";
   g_oCurrentMessageBox = undefined;
}
function HideMessageBox(bSkipFade)
{
   if(g_oCurrentMessage != undefined)
   {
      g_oCurrentMessage.Hide(bSkipFade);
      g_oCurrentMessage = undefined;
   }
   else
   {
      onMessageBoxHidden();
   }
}
function UpdatePlatformLayout(nLayoutCode)
{
   MessageMain.SetPlatformLayout(nLayoutCode);
   MessageMain_D1.SetPlatformLayout(nLayoutCode);
}
function scrollText(nScroll)
{
   var _loc1_;
   if(g_oCurrentMessage != undefined)
   {
      _loc1_ = g_oCurrentMessage.scrollingWidget;
      if(_loc1_ != undefined)
      {
         if(Math.abs(nScroll) >= 0.2)
         {
            _loc1_.scrollByTime(nScroll >= 0 ? com.bioware.masseffect.controls.Marquee.SCROLL_CONTENT_DOWN : com.bioware.masseffect.controls.Marquee.SCROLL_CONTENT_UP,Math.abs(nScroll));
         }
         else
         {
            _loc1_.ResetScrollTime();
         }
      }
   }
}
function OnResize()
{
   if(com.SFXScreen.CheckedScaleUpdate())
   {
      return undefined;
   }
   MessageMain.Reposition();
   MessageMain_D1.Reposition();
   mcTutorial.Reposition();
   MessageChoice.Reposition();
   WeaponChoice.Reposition();
}
function RefreshButtonHelp(usingGamepad)
{
   bUsingGamepad = usingGamepad;
   if(ScreenLayout == com.XPlatform.PC && !bUsingGamepad)
   {
      mcTutorial.text = pcHintString;
      g_oCurrentMessageBox.text = pcBoxString;
   }
   else
   {
      mcTutorial.text = gamepadHintString;
      g_oCurrentMessageBox.text = gamepadBoxString;
   }
   MessageMain.RefreshButtonHelp(bUsingGamepad);
   MessageMain_D1.RefreshButtonHelp(bUsingGamepad);
   MessageChoice.RefreshButtonHelp(bUsingGamepad);
   WeaponChoice.RefreshButtonHelp(bUsingGamepad);
}
var g_sPendingEvent = "";
var g_bTextEntry = false;
var g_sPendingText = "";
var g_oCurrentMessage;
var g_oCurrentMessageBox;
var g_BG_Normal = 0;
var g_BG_DesignerSkin1 = 1;
var bUsingGamepad = false;
var gamepadHintString = "";
var pcHintString = "";
var gamepadBoxString = "";
var pcBoxString = "";
var ScreenLayout = 1;
Initialize();
stop();
