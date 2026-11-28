function Initalize()
{
   com.SFXScreen.PrepareScreen("showAll");
   Stage.align = "TL";
   com.SFXScreen.OnResize = Reposition;
   Reposition();
   g_Counter = CounterPos.Counter;
   g_Counter._visible = false;
   stop();
}
function Reposition()
{
   if(com.SFXScreen.CheckedScaleUpdate())
   {
      return undefined;
   }
   var _loc3_ = com.SFXScreen.GetVisibleRect();
   var _loc2_ = com.SFXScreen.GetSafeRect();
   var _loc1_;
   if(CounterPos.Offset == undefined)
   {
      _loc1_ = com.SFXScreen.GetOriginalRect();
      CounterPos.Offset = {x:CounterPos._x - _loc1_.right,y:_loc1_.top + CounterPos._y};
   }
   // MILAN CHANGE - 11/26/2026 - Mgamerz
   // Slide offset on top of the anchor
   CounterPos._x = _loc2_.right + CounterPos.Offset.x + g_SlideX;
   // END MILAN CHANGE
   CounterPos._y = _loc2_.top + CounterPos.Offset.y;
}
// MILAN CHANGE - 11/26/2026 - Mgamerz
// Slides the counter horizontally to nX in twips over nSeconds
function SlideTo(nX, nSeconds)
{
   g_SlideFrom = g_SlideX;
   g_SlideTarget = nX;
   if(nSeconds <= 0 || g_SlideFrom == nX)
   {
      delete CounterPos.onEnterFrame;
      g_SlideX = nX;
      Reposition();
      return undefined;
   }
   g_SlideStart = getTimer();
   g_SlideDuration = nSeconds * 1000;
   CounterPos.onEnterFrame = SlideStep;
}
function SlideStep()
{
   var _loc1_ = Math.min(1,(getTimer() - g_SlideStart) / g_SlideDuration);
   var _loc2_ = 1 - Math.pow(1 - _loc1_,3);
   g_SlideX = g_SlideFrom + (g_SlideTarget - g_SlideFrom) * _loc2_;
   Reposition();
   if(_loc1_ >= 1)
   {
      delete CounterPos.onEnterFrame;
   }
}
// END MILAN CHANGE
function SetCounterTitle(txtTitle)
{
   Reposition();
   g_Counter._visible = true;
   g_Counter.txtCounterTitle.text = txtTitle;
   CenterText();
}
function SetCounterValue(txtValue)
{
   Reposition();
   g_Counter._visible = true;
   g_Counter.txtCounterValue.text = txtValue;
   CenterText();
}
function SetCounterColor(txtColor)
{
   Reposition();
   g_Counter._visible = true;
   g_Counter.txtCounterValue.textColor = txtColor;
}
function SetCounterUnit(txtUnit)
{
   g_Counter._visible = true;
   g_Counter.txtCounterUnit.text = txtUnit;
   CenterText();
}
function SetPosition(frameName)
{
   CounterPos.gotoAndStop(frameName);
   g_Counter._visible = true;
   Reposition();
}
function CenterText()
{
   var _loc1_ = g_Counter.txtCounterUnit.textWidth;
   var _loc2_ = g_Counter.txtCounterValue.textWidth;
   var _loc5_ = _loc1_ + _loc2_;
   var _loc3_ = 75;
   g_Counter.Background._width = Math.max(_loc5_,g_Counter.txtCounterTitle.textWidth) + _loc3_;
   g_Counter.Background._x = (- g_Counter.Background._width) / 2;
   var _loc4_ = 5;
   g_Counter.txtCounterUnit._x = g_Counter.Background._x - _loc1_ / 2 + _loc2_ / 2;
   g_Counter.txtCounterValue._x = g_Counter.txtCounterUnit._x - g_Counter.txtCounterValue._width - _loc4_;
   g_Counter.txtCounterTitle._x = g_Counter.Background._x - g_Counter.txtCounterTitle._width / 2;
   Reposition();
}
var g_Counter;
// MILAN CHANGE - 11/26/2026 - Mgamerz
// Slide vars
var g_SlideX = 0;
var g_SlideFrom = 0;
var g_SlideTarget = 0;
var g_SlideStart = 0;
var g_SlideDuration = 0;
// END MILAN CHANGE
Initalize();
if(com.XPlatform.IsRunningInEngine() == false)
{
   var gTickCount = 0;
   _root.onEnterFrame = function()
   {
      gTickCount++;
      if(gTickCount == 30)
      {
         SetCounterTitle("Distance to Target:");
         SetCounterValue(10);
         SetCounterUnit("m");
         SetCounterColor(16711680);
      }
      if(gTickCount == 90)
      {
         SetCounterValue(200);
      }
      if(gTickCount == 270)
      {
         SetCounterValue(98573);
         gTickCount = 0;
      }
   };
}
stop();

