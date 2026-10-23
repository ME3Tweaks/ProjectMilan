class screens.MPPauseMenu.MenuButtons extends com.SFXMovieClip
{
   var ButtonEvents;
   var Buttons;
   var IntervalID;
   var Line1;
   var Line2;
   var Line3;
   var Line4;
   var SelectedButtonPlate;
   var ScrollUpArrow;
   var ScrollDownArrow;
   var keyListener;
   var mouseListener;
   var ScoreData = new Array();
   var InviteFeedbackTimer;
   var InviteFeedbackFadeTimer;
   var InviteFeedbackFadeStart;
   var InviteFeedbackFadeFrom;
   var InviteFeedbackFadeTo;
   var InviteFeedbackFadeDuration;
   var InviteFeedbackDuration = 3000;
   var InviteEnabled = false;
   var MenuText;
   var ScrollOffset = 0;
   var InitialScrollStarted = false;
   var InitialScrollTarget = 0;
   var InitialScrollStep = 1;
   var InitialScrollDelay;
   var InitialScrollTimer;
   var tweenIntervals = new Array();
   var nNumScoreLines = 4;
   var nFocusedButtonIndex = -1;
   static var UpdateScoreboardInterval = 1000;
   function MenuButtons()
   {
      super();
   }
   function createTween(seed, targetMC, targetX, targetY, xVel, yVel, interval, steps, tweenType)
   {
      if(steps == undefined)
      {
         clearInterval(this.tweenIntervals[seed]);
         this.tweenIntervals[seed] = setInterval(this.moveTween,interval,seed,targetMC,targetX,targetY,xVel,yVel,steps);
      }
      else if(tweenType == "dec")
      {
         clearInterval(this.tweenIntervals[seed]);
         this.tweenIntervals[seed] = setInterval(this.moveTweenDec,interval,seed,targetMC,targetX,targetY,steps);
      }
      else if(tweenType == "accdec")
      {
         clearInterval(this.tweenIntervals[seed]);
         var oTargetMC = eval(targetMC);
         this.tweenIntervals[seed] = setInterval(this.moveTweenAccDec,interval,seed,targetMC,targetX,targetY,oTargetMC._x,oTargetMC._y,steps);
      }
   }
   function destroyTween(seed)
   {
      clearInterval(this.tweenIntervals[seed]);
   }
   function moveTween(seed, targetMC, targetX, targetY, xVel, yVel, steps)
   {
      var oTargetMC = typeof targetMC != "string" ? targetMC : eval(targetMC);
      if(oTargetMC != undefined)
      {
         with(oTargetMC)
         {
            if(Math.abs(_x - targetX) < xVel)
            {
               _x = targetX;
            }
            else if(_x < targetX)
            {
               _x += xVel;
            }
            else if(_x > targetX)
            {
               _x -= xVel;
            }
            if(Math.abs(_y - targetY) < yVel)
            {
               _y = targetY;
            }
            else if(_y < targetY)
            {
               _y += yVel;
            }
            else if(_y > targetY)
            {
               _y -= yVel;
            }
            if(_y == targetY && _x == targetX)
            {
               clearInterval(tweenIntervals[seed]);
            }
         }
      }
      else
      {
         clearInterval(this.tweenIntervals[seed]);
      }
   }
   function moveTweenDec(seed, targetMC, targetX, targetY, steps)
   {
      var oTargetMC = typeof targetMC != "string" ? targetMC : eval(targetMC);
      if(oTargetMC != undefined)
      {
         with(oTargetMC)
         {
            _x += (targetX - _x) / steps;
            _y += (targetY - _y) / steps;
            if(Math.abs(targetX - _x) < 0.05 && Math.abs(targetY - _y) < 0.05)
            {
               _x = targetX;
               _y = targetY;
               clearInterval(tweenIntervals[seed]);
            }
         }
      }
      else
      {
         clearInterval(this.tweenIntervals[seed]);
      }
   }
   function moveTweenAccDec(seed, targetMC, targetX, targetY, initialX, initialY, steps)
   {
      var oTargetMC = typeof targetMC != "string" ? targetMC : eval(targetMC);
      if(oTargetMC != undefined)
      {
         with(oTargetMC)
         {
            if(Math.abs(initialX - _x) <= Math.abs(targetX - _x))
            {
               if(targetX < initialX)
               {
                  _x -= (initialX + 500 / steps - _x) / steps;
               }
               else
               {
                  _x += (initialX + 500 / steps - _x) / steps;
               }
            }
            else
            {
               _x += (targetX - _x) / steps;
            }
            if(Math.abs(initialY - _y) <= Math.abs(targetY - _y))
            {
               if(targetY < initialY)
               {
                  _y -= (initialY + 500 / steps - _y) / steps;
               }
               else
               {
                  _y += (initialY + 500 / steps - _y) / steps;
               }
            }
            else
            {
               _y += (targetY - _y) / steps;
            }
            if(Math.abs(targetX - _x) < 0.01 && Math.abs(targetY - _y) < 0.01)
            {
               clearInterval(tweenIntervals[seed]);
            }
         }
      }
      else
      {
         clearInterval(this.tweenIntervals[seed]);
      }
   }
   function onLoad()
   {
      super.onLoad();
      this.Buttons = new Array();
      this.ButtonEvents = new Array();
      this.SetupButtons();
      this.UpdateScoreboard();
      this.IntervalID = setInterval(this.MakeDelegate(this.UpdateScoreboard),screens.MPPauseMenu.MenuButtons.UpdateScoreboardInterval);
   }
   function SetupButtons()
   {
      this.MenuText = flash.external.ExternalInterface.call("GetPauseMenuText");
      if(this.MenuText == undefined)
      {
         this.MenuText = new Object();
      }
      this.SetupScoreLine(this.Line1);
      this.SetupScoreLine(this.Line2);
      this.SetupScoreLine(this.Line3);
      this.SetupScoreLine(this.Line4);
      var optionsY = this.OptionsButton._y;
      var exitY = this.ExitToLobbyButton._y;
      this.OptionsButton.duplicateMovieClip("InviteButton", this.getNextHighestDepth());
      this.InviteButton._y = optionsY;
      this.OptionsButton._y = exitY;
      this.ExitToLobbyButton._y = exitY + (exitY - optionsY);
      this.SetupButton("ReturnToGameButton","$" + _global.SFX.GetIniString("srReturnToGame"));
      this.SetupButton("InviteButton",this.MenuText.InviteLabel);
      this.SetupButton("OptionsButton","$" + _global.SFX.GetIniString("srOptions"));
      this.SetupButton("ExitToLobbyButton","$" + _global.SFX.GetIniString("srExitToLobby"));
      this.ApplyInviteEnabled();
      this.NameHeader._width = 184;
      this.ScoreHeader._width = 80;
      this.PingHeader._width = 96;
      this.NameHeader.text = this.MenuText.NameLabel;
      this.ScoreHeader.text = this.MenuText.ScoreLabel;
      this.PingHeader.text = this.MenuText.PingLabel;
      this.NameHeader.selectable = false;
      this.ScoreHeader.selectable = false;
      this.PingHeader.selectable = false;
      this.InviteFeedback._width = 500;
      this.InviteFeedback._x = -250;
      this.InviteFeedback.text = "";
      this.InviteFeedback.textAutoSize = "shrink";
      this.InviteFeedback.selectable = false;
      this.InviteFeedback._visible = false;
      this.InviteFeedback._alpha = 0;
      this.SetupScrollArrow(this.ScrollUpArrow,true);
      this.SetupScrollArrow(this.ScrollDownArrow,false);
      this.keyListener = new Object();
      this.FocusedButtonIndex = 4;
      this.keyListener.onKeyDown = this.MakeDelegate(this.OnButtonDown);
      Key.addListener(this.keyListener);
      this.mouseListener = new Object();
      this.mouseListener.onMouseWheel = this.MakeDelegate(this.OnMouseWheel);
      Mouse.addListener(this.mouseListener);
   }
   function SetupScoreLine(ScoreLine)
   {
      this.Buttons.push(ScoreLine);
      ScoreLine.addEventListener("SFXButton_onRelease",this.MakeDelegate(this.OnScoreLineSelected));
      ScoreLine.addEventListener("SFXButton_onRollOver",this.MakeDelegate(this.OnButtonRollover));
   }
   function SetupButton(ButtonName, Text)
   {
      var _loc2_;
      _loc2_ = this[ButtonName];
      this.ButtonEvents.push(ButtonName);
      this.Buttons.push(_loc2_);
      _loc2_.Text.text = Text;
      _loc2_.addEventListener("SFXButton_onRelease",this.MakeDelegate(this.OnButtonSelected));
      _loc2_.addEventListener("SFXButton_onRollOver",this.MakeDelegate(this.OnButtonRollover));
   }
   function OnButtonDown()
   {
      switch(Key.getCode())
      {
         case com.XInput.ButtonA:
            this.Buttons[this.FocusedButtonIndex].onPress();
            this.Buttons[this.FocusedButtonIndex].onRelease();
            return;
         case com.XInput.ButtonB:
         case com.XInput.ButtonStart:
            this.dispatchEvent({type:"ReturnToGameButton",target:this});
            return;
         case com.XInput.DPadUp:
            this.CancelInitialScroll();
            if(this.FocusedButtonIndex == 0 && this.ScrollOffset > 0)
            {
               --this.ScrollOffset;
               this.UpdateScoreboard();
            }
            else
            {
               --this.FocusedButtonIndex;
            }
            return;
         case com.XInput.DPadDown:
            this.CancelInitialScroll();
            if(this.FocusedButtonIndex == this.nNumScoreLines - 1 && this.ScrollOffset + this.nNumScoreLines < this.ScoreData.length)
            {
               ++this.ScrollOffset;
               this.UpdateScoreboard();
            }
            else
            {
               ++this.FocusedButtonIndex;
            }
            return;
         case com.XInput.ButtonX:
            // Pause-menu kick voting is deferred.
            return;
         case com.XInput.ButtonY:
            if(this.InviteEnabled)
            {
               flash.external.ExternalInterface.call("InviteFriends");
            }
            else
            {
               _global.SFX.PlayGUIError();
            }
            return;
      }
      _global.SFX.PlayGUIError();
   }
   function OnMouseWheel(delta)
   {
      this.CancelInitialScroll();
      var nextOffset = this.ScrollOffset - delta;
      this.ScrollOffset = Math.max(0,Math.min(nextOffset,this.MaxScrollOffset()));
      this.UpdateScoreboard();
   }
   function SetupScrollArrow(arrow, up)
   {
      arrow._xscale = 35;
      arrow._yscale = 25;
      arrow._rotation = up ? -90 : 90;
      arrow.gotoAndStop("normal");
      arrow._visible = false;
      arrow.onRollOver = function()
      {
         if(!_root.screen.bUsingGamepad)
         {
            this.gotoAndStop("rollover");
         }
      };
      arrow.onRollOut = function()
      {
         this.gotoAndStop("normal");
      };
      arrow.onPress = function()
      {
         this.gotoAndStop("press");
      };
      arrow.onReleaseOutside = arrow.onRollOut;
      arrow.onRelease = this.MakeDelegate(up ? this.ScrollPlayersUp : this.ScrollPlayersDown);
   }
   function ScrollPlayersUp()
   {
      this.ScrollUpArrow.gotoAndStop("normal");
      this.OnMouseWheel(1);
   }
   function ScrollPlayersDown()
   {
      this.ScrollDownArrow.gotoAndStop("normal");
      this.OnMouseWheel(-1);
   }
   function MaxScrollOffset()
   {
      return Math.max(0,this.ScoreData.length - this.nNumScoreLines);
   }
   function CancelInitialScroll()
   {
      clearInterval(this.InitialScrollDelay);
      clearInterval(this.InitialScrollTimer);
   }
   function BeginInitialScroll()
   {
      clearInterval(this.InitialScrollDelay);
      this.InitialScrollTimer = setInterval(this.MakeDelegate(this.AdvanceInitialScroll),45);
   }
   function AdvanceInitialScroll()
   {
      var target = Math.min(this.InitialScrollTarget,this.MaxScrollOffset());
      if(this.ScrollOffset >= target)
      {
         this.CancelInitialScroll();
         return;
      }
      this.ScrollOffset = Math.min(target,this.ScrollOffset + this.InitialScrollStep);
      this.UpdateScoreboard();
      if(this.ScrollOffset >= target)
      {
         this.CancelInitialScroll();
      }
   }
   function ShowInviteFeedback()
   {
      clearInterval(this.InviteFeedbackTimer);
      clearInterval(this.InviteFeedbackFadeTimer);
      this.InviteFeedback._visible = true;
      this.InviteFeedback._alpha = 0;
      this.FadeInviteFeedback(100,180);
      this.InviteFeedbackTimer = setInterval(this.MakeDelegate(this.HideInviteFeedback),this.InviteFeedbackDuration);
   }
   function HideInviteFeedback()
   {
      clearInterval(this.InviteFeedbackTimer);
      this.FadeInviteFeedback(0,160);
   }
   function FadeInviteFeedback(target, duration)
   {
      clearInterval(this.InviteFeedbackFadeTimer);
      this.InviteFeedbackFadeStart = getTimer();
      this.InviteFeedbackFadeFrom = this.InviteFeedback._alpha;
      this.InviteFeedbackFadeTo = target;
      this.InviteFeedbackFadeDuration = duration;
      this.InviteFeedbackFadeTimer = setInterval(this.MakeDelegate(this.AdvanceInviteFeedbackFade),33);
   }
   function AdvanceInviteFeedbackFade()
   {
      var amount = Math.min(1,(getTimer() - this.InviteFeedbackFadeStart) / this.InviteFeedbackFadeDuration);
      this.InviteFeedback._alpha = this.InviteFeedbackFadeFrom + (this.InviteFeedbackFadeTo - this.InviteFeedbackFadeFrom) * amount;
      if(amount >= 1)
      {
         clearInterval(this.InviteFeedbackFadeTimer);
         if(this.InviteFeedbackFadeTo == 0)
         {
            this.InviteFeedback._visible = false;
         }
      }
   }
   function ApplyInviteEnabled()
   {
      var enabled = this.InviteEnabled == true;
      this.InviteButton.enabled = enabled;
      this.InviteButton._alpha = enabled ? 100 : 35;
      if(!enabled && this.FocusedButtonIndex == this.nNumScoreLines + 1)
      {
         this.FocusedButtonIndex = this.nNumScoreLines + 2;
      }
   }
   function get FocusedButtonIndex()
   {
      return this.nFocusedButtonIndex;
   }
   function set FocusedButtonIndex(nIndex)
   {
      if(nIndex == undefined || nIndex < -1 || nIndex >= this.Buttons.length)
      {
         return;
      }
      while(nIndex >= 0 && nIndex < this.Buttons.length && (!this.Buttons[nIndex]._visible || this.Buttons[nIndex].enabled == false))
      {
         if(nIndex > this.nFocusedButtonIndex)
         {
            nIndex = nIndex + 1;
         }
         else
         {
            nIndex = nIndex - 1;
         }
      }
      if(nIndex >= -1 && nIndex < this.Buttons.length)
      {
         this.SelectedButtonPlate._visible = nIndex >= 0;
         if(nIndex >= 0)
         {
            // Keep the selection outline the same size for players and menu options.
            this.SelectedButtonPlate._yscale = 76.9989;
            if(this.nFocusedButtonIndex < 0)
            {
               this.SelectedButtonPlate._y = this.Buttons[nIndex]._y;
            }
            else
            {
               this.createTween(0,this.SelectedButtonPlate.toString(),this.SelectedButtonPlate._x,this.Buttons[nIndex]._y,0,0,16,4,"dec");
            }
         }
         this.nFocusedButtonIndex = nIndex;
         this.UpdateRowHighlights();
      }
      else if(nIndex != this.nFocusedButtonIndex)
      {
         _global.SFX.PlayGUIError();
      }
   }
   function UpdateRowHighlights()
   {
      for(var i = 0; i < this.nNumScoreLines; ++i)
      {
         this.Buttons[i].SetSelected(i == this.FocusedButtonIndex);
      }
   }
   function OnButtonRollover(p_event)
   {
      var _loc2_ = 0;
      while(_loc2_ < this.Buttons.length)
      {
         if(this.Buttons[_loc2_] == p_event.target)
         {
            this.FocusedButtonIndex = _loc2_;
            break;
         }
         _loc2_ = _loc2_ + 1;
      }
   }
   function OnScoreLineSelected(p_event)
   {
      var _loc2_ = 0;
      while(_loc2_ < this.Buttons.length && _loc2_ < this.nNumScoreLines)
      {
         if(this.Buttons[_loc2_] == p_event.target)
         {
            flash.external.ExternalInterface.call("ShowGamerCard",this.ScrollOffset + _loc2_);
            break;
         }
         _loc2_ = _loc2_ + 1;
      }
   }
   function OnButtonSelected(p_event)
   {
      var _loc2_ = this.nNumScoreLines;
      while(_loc2_ < this.Buttons.length)
      {
         if(this.Buttons[_loc2_] == p_event.target)
         {
            if(p_event.target.enabled == false)
            {
               _global.SFX.PlayGUIError();
               return;
            }
            this.dispatchEvent({type:this.ButtonEvents[_loc2_ - this.nNumScoreLines],target:this});
            break;
         }
         _loc2_ = _loc2_ + 1;
      }
   }
   function UpdateScoreboard()
   {
      var _loc3_ = flash.external.ExternalInterface.call("GetScoreData");
      if(_loc3_ == undefined)
      {
         _loc3_ = new Array();
      }
      this.ScoreData = _loc3_;
      if(!this.InitialScrollStarted && _loc3_.length > 0)
      {
         this.InitialScrollStarted = true;
         var localIndex = -1;
         for(var i = 0; i < _loc3_.length; ++i)
         {
            if(_loc3_[i].IsLocal == true)
            {
               localIndex = i;
               break;
            }
         }
         if(localIndex >= 0 && _loc3_.length > this.nNumScoreLines)
         {
            var localSlot = localIndex < _loc3_.length / 2 ? 1 : 2;
            this.InitialScrollTarget = Math.min(Math.max(0,localIndex - localSlot),this.MaxScrollOffset());
            if(this.InitialScrollTarget > 0)
            {
               this.InitialScrollStep = Math.max(1,Math.ceil(this.InitialScrollTarget / 6));
               this.InitialScrollDelay = setInterval(this.MakeDelegate(this.BeginInitialScroll),180);
            }
         }
      }
      this.ScrollOffset = Math.max(0,Math.min(this.ScrollOffset,this.MaxScrollOffset()));
      var _loc2_ = 0;
      while(_loc2_ < this.nNumScoreLines)
      {
         if(this.ScrollOffset + _loc2_ < _loc3_.length)
         {
            var entry = _loc3_[this.ScrollOffset + _loc2_];
            this.Buttons[_loc2_].SetLineInfo(true,entry.DisplayName,entry.Score,entry.Ping,entry.IsLocal,entry.IsDead);
         }
         else
         {
            this.Buttons[_loc2_].SetLineInfo(false,"","","",false,false);
         }
         _loc2_ = _loc2_ + 1;
      }
      if(this.FocusedButtonIndex >= 0 && this.FocusedButtonIndex < this.nNumScoreLines && this.ScrollOffset + this.FocusedButtonIndex >= _loc3_.length)
      {
         this.FocusedButtonIndex = _loc3_.length > 0 ? Math.min(this.nNumScoreLines - 1,_loc3_.length - this.ScrollOffset - 1) : this.nNumScoreLines;
      }
      this.ScrollUpArrow._visible = this.ScrollOffset > 0;
      this.ScrollDownArrow._visible = this.ScrollOffset < this.MaxScrollOffset();
      this.UpdateRowHighlights();
   }
   function CleanupScoreboardTimer()
   {
      clearInterval(this.IntervalID);
      clearInterval(this.InviteFeedbackTimer);
      clearInterval(this.InviteFeedbackFadeTimer);
      this.CancelInitialScroll();
      Key.removeListener(this.keyListener);
      Mouse.removeListener(this.mouseListener);
   }
}
