function LogFromAS()
{
   var _loc2_ = "";
   var _loc3_ = 0;
   while(_loc3_ < arguments.length)
   {
      if(_loc2_ == "")
      {
         _loc2_ = arguments[_loc3_].toString();
      }
      else
      {
         _loc2_ = _loc2_ + "," + arguments[_loc3_].toString();
      }
      _loc3_ += 1;
   }
   flash.external.ExternalInterface.call("LogFromAS",_loc2_);
}
function RefreshButtonHelp(bUsingGamepad)
{
   DPadMap._visible = bUsingGamepad;
   PowerMapAnimation._visible = bUsingGamepad;
}
function init()
{
   CONSOLE_SAFE_SCALAR = _global.SFX.GetIniNumber("SafeFrameAdjustment","HUD","UI");
   g_BottomLeftGroup = new com.SFXPositionHelper(DPadMap);
   g_TopRightGroup = new com.SFXPositionHelper(ObjectiveBar,ObjectiveCircles,timerText);
   g_BottomRightGroup = new com.SFXPositionHelper(TickerBar1,TickerBar2,TickerBar3,TickerBar4);
   g_BottomCenterGroup = new com.SFXPositionHelper(ProgressBar,PowerMapAnimation,SpectatorMode);
   g_aTickerBars = new Array(TickerBar1,TickerBar2,TickerBar3,TickerBar4);
   timerText.timerTextMC.timerText.text = "";
   var _loc2_ = 0;
   while(_loc2_ < g_aTickerBars.length)
   {
      SetTickerText(g_aTickerBars[_loc2_],"");
      _loc2_ += 1;
   }
   PowerMapAnimation.PowerMap.Power1.selectable.txtInfo.text = "";
   PowerMapAnimation.PowerMap.Power2.selectable.txtInfo.text = "";
   PowerMapAnimation.PowerMap.Power3.selectable.txtInfo.text = "";
   // MILAN CHANGE DropTheSquid 11/2/2026
   // capturing the original position of the Y icon and setting up the handler to move it when needed
   g_PowerIconCenterBaseY = PowerMapAnimation.PowerMap.ControllerIconCenter._y;
   SetupPowerIconTextPosition();
   // end milan change
   com.SFXScreen.OnResize = ScreenResized;
   ScreenResized();
   com.SFXScreen.RegisterForTriggerStateUpdate(OnTriggerConfigChanged);
   OnTriggerConfigChanged();
   SpectatorMode.SpectatorModeAnim.txtField_title.textAutoSize = "shrink";
   SpectatorMode.SpectatorModeAnim.txtField_info.textAutoSize = "shrink";
   if(com.XPlatform.IsRunningInEngine() == false)
   {
      DEBUGDISPLAY();
   }
}
function ScreenResized()
{
   if(com.SFXScreen.CheckedScaleUpdate())
   {
      return undefined;
   }
   var _loc3_ = com.SFXScreen.GetSafeRect();
   if(_global.SFX.Platform != com.XPlatform.PC && CONSOLE_SAFE_SCALAR != 0)
   {
      _loc3_ = new flash.geom.Rectangle(_loc3_.left - _loc3_.width * CONSOLE_SAFE_SCALAR,_loc3_.top - _loc3_.top * CONSOLE_SAFE_SCALAR,_loc3_.width * (1 + CONSOLE_SAFE_SCALAR * 2),_loc3_.height * (1 + CONSOLE_SAFE_SCALAR * 2));
   }
   var _loc4_ = new flash.geom.Point(_loc3_.left + _loc3_.width * 0.5,_loc3_.top + _loc3_.height * 0.5);
   g_BottomLeftGroup.SnapLeft(_loc3_);
   g_BottomLeftGroup.SnapBottom(_loc3_);
   g_TopRightGroup.SnapRight(_loc3_);
   g_TopRightGroup.SnapTop(_loc3_);
   g_BottomRightGroup.SnapRight(_loc3_);
   g_BottomRightGroup.SnapBottom(_loc3_);
   ProgressBar._x = PowerBarAnimation._x = _loc4_.x;
   g_BottomCenterGroup.SnapBottom(_loc3_);
   g_BottomCenterGroup.CenterHorizontally(_loc3_);
   if(com.XPlatform.IsRunningInEngine() == false)
   {
      _root.clear();
      _root.lineStyle(1,65280,100);
      _root.moveTo(_loc4_.x,_loc3_.top);
      _root.lineTo(_loc4_.x,_loc3_.bottom);
      _root.moveTo(_loc3_.left,_loc4_.y);
      _root.lineTo(_loc3_.right,_loc4_.y);
   }
}
function OnTriggerConfigChanged()
{
   var _loc2_ = false;
   if(_global.SFX.IsTriggerShoulderSwapped())
   {
      _loc2_ = !_loc2_;
   }
   PowerMapAnimation.PowerMap.ControllerIconLeft.Trigger._visible = _loc2_;
   PowerMapAnimation.PowerMap.ControllerIconLeft.Shoulder._visible = !_loc2_;
   PowerMapAnimation.PowerMap.ControllerIconRight.Trigger._visible = _loc2_;
   PowerMapAnimation.PowerMap.ControllerIconRight.Shoulder._visible = !_loc2_;
}
function PowerIconCooldownDone(oIcon)
{
   flash.external.ExternalInterface.call("PowerIconCooldownDone",oIcon);
}
// MILAN CHANGE DropTheSquid 11/2/2026
// added handling for moving the controller Y icon down when there is text below the power icon (as with the Talon Merc's grenades) so it overlaps the text less.
// also edited the tags so that the Y icon is drawn below the text, as there is still slight overlap to avoid touching the bottom of the screen. 
function SetupPowerIconTextPosition()
{
   var powerMap = PowerMapAnimation.PowerMap;
   var power2 = powerMap.Power2;
   var infoField = power2.selectable.TextMC.txtInfo;
   var controllerIcon = powerMap.ControllerIconCenter;
   var iconLowered = false;
   powerMap.onEnterFrame = function()
   {
      if(infoField.text != "")
      {
         if(iconLowered == false)
         {
            controllerIcon._y = g_PowerIconCenterBaseY + g_PowerIconTextOffsetY;
            iconLowered = true;
         }
      }
      else if(iconLowered == true)
      {
         controllerIcon._y = g_PowerIconCenterBaseY;
         iconLowered = false;
      }
   };
}
var g_PowerIconCenterBaseY = 345;
var g_PowerIconTextOffsetY = 6;
// END MILAN CHANGE
function SetDPadVisible(bVisible, bSkipTransition)
{
   if(bSkipTransition == false)
   {
      DPadMap.gotoAndPlay(!bVisible ? "close" : "open");
   }
   else
   {
      DPadMap.gotoAndStop(!bVisible ? "off" : "on");
   }
}
function ResetTickerBar(oTickerMovie)
{
   SetTickerText(oTickerMovie,"");
   oTickerMovie.gotoAndStop("initial");
   oTickerMovie.tickerBarFade.gotoAndStop("normal");
}
function FadeTickerBar(oTickerMovie)
{
   oTickerMovie.tickerBarFade.gotoAndPlay("fade");
}
function SetTickerText(oTickerMovie, sText)
{
   oTickerMovie.tickerBarFade.tickerBar.tickerText.textAutoSize = "shrink";
   oTickerMovie.tickerBarFade.tickerBar.tickerText.html = true;
   oTickerMovie.tickerBarFade.tickerBar.tickerText.htmlText = sText;
}
function TickerFadeComplete(oTickerMC)
{
   ResetTickerBar(oTickerMC);
   flash.external.ExternalInterface.call("OnTickerFadeComplete",oTickerMC.ID);
}
function SetPowerMapVisible(bVisible, bSkipTransition)
{
   if(bSkipTransition)
   {
      PowerMapAnimation.gotoAndStop(!bVisible ? "off" : "on");
   }
   else
   {
      PowerMapAnimation.gotoAndPlay(!bVisible ? "close" : "open");
   }
}
function SetTimerVisible(bVisible)
{
   timerText.gotoAndPlay(!bVisible ? "close" : "open");
}
function SetTimerPulse(bPulse)
{
   if(bPulse)
   {
      timerText.timerTextPulse.gotoAndPlay("pulse");
   }
   else
   {
      timerText.timerTextPulse.gotoAndStop("normal");
   }
}
function SetObjectiveVisible(bVisible, bCircles)
{
   var _loc3_ = !bCircles ? ObjectiveBar : ObjectiveCircles;
   _loc3_.gotoAndPlay(!bVisible ? "close" : "open");
}
function SetProgressBarVisible(bVisible, bSkipTransition)
{
   if(bSkipTransition)
   {
      ProgressBar.gotoAndStop(!bVisible ? "off" : "on");
   }
   else
   {
      ProgressBar.gotoAndPlay(!bVisible ? "close" : "open");
   }
}
function DisplaySubareaText(sSubareaText)
{
   SubareaText.gotoAndPlay("fadeIn");
   SubareaText.Plate.Text.text = sSubareaText;
}
function ShowSpectatorHUD()
{
   SpectatorMode.gotoAndPlay("open");
}
function HideSpectatorHUD()
{
   SpectatorMode.gotoAndPlay("close");
}
function DEBUGDISPLAY()
{
   ScreenResized();
   DPadMap.gotoAndPlay("open");
   TickerBar1.tickerBarFade.tickerBar.tickerText.text = "Ticker Bar 1";
   TickerBar1.gotoAndPlay("slot1");
   TickerBar2.tickerBarFade.tickerBar.tickerText.text = "Ticker Bar 2";
   TickerBar2.gotoAndPlay("slot2");
   TickerBar3.tickerBarFade.tickerBar.tickerText.text = "Ticker Bar 3";
   TickerBar3.gotoAndPlay("slot3");
   TickerBar4.tickerBarFade.tickerBar.tickerText.text = "Ticker Bar 4";
   TickerBar4.gotoAndPlay("slot4");
   PowerMapAnimation.gotoAndPlay("open");
   timerText.timerTextPulse.timerTextMC.timerText.text = "4:20!";
   SetTimerVisible(true);
   SetTimerPulse(true);
   ObjectiveBar.gotoAndPlay("open");
   ObjectiveBar.objectiveBar.gotoAndStop(50);
}
Stage.scaleMode = "showAll";
Stage.align = "TL";
_global.gfxExtensions = true;
_global.noInvisibleAdvance = true;
stop();
var g_BottomLeftGroup;
var g_TopRightGroup;
var g_BottomRightGroup;
var g_BottomCenterGroup;
var g_aTickerBars;
var CONSOLE_SAFE_SCALAR = 0;
init();
SpectatorMode.onPress = function()
{
   this.play();
};
