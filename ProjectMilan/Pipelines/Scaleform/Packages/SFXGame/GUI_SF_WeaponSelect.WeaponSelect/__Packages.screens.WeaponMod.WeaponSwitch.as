class screens.WeaponMod.WeaponSwitch extends com.SFXMovieClip
{
   var PCInfoButton;
   var bUsingGamepad = false;
   var bInfoToggleEnabled = true;
   var bHasWeaponImage = false;
   var glow;
   var gotoAndPlay;
   var m_aSwitchImageHolders;
   var m_bGlowUp;
   var m_bInSelection;
   var m_bSlideInFromLeft;
   var m_nCurrentWeap;
   var m_nCurrentWeaponImage;
   var m_nImageXPosition;
   var m_nSlideDistance;
   var m_nTotalWeaps;
   var wpnImageLoader;
   var wpnNameText;
   var wpnSwitch;
   static var SLIDE_TIME = 0.4;
   function WeaponSwitch()
   {
      super();
   }
   function onLoad()
   {
      super.onLoad();
      this.m_bGlowUp = false;
      this.wpnImageLoader.HAlign = com.bioware.masseffect.controls.ResourceLoader.ALIGN_CENTER;
      this.wpnImageLoader.VAlign = com.bioware.masseffect.controls.ResourceLoader.ALIGN_CENTER;
      this.wpnImageLoader.FadeIn = false;
      this.wpnImageLoader.FadeOut = false;
      this.wpnImageLoader.UsePlaceholderSize();
      this.m_nImageXPosition = this.wpnSwitch.Images.Image1._x;
      this.m_nSlideDistance = this.wpnSwitch.Images.Image1._width + 50;
      this.m_nCurrentWeaponImage = 0;
      this.m_aSwitchImageHolders = new Array(this.wpnSwitch.Images.Image1,this.wpnSwitch.Images.Image2);
      var _loc4_ = 0;
      while(_loc4_ < this.m_aSwitchImageHolders.length)
      {
         this.m_aSwitchImageHolders[_loc4_].wpnImageLoader.HAlign = com.bioware.masseffect.controls.ResourceLoader.ALIGN_CENTER;
         this.m_aSwitchImageHolders[_loc4_].wpnImageLoader.VAlign = com.bioware.masseffect.controls.ResourceLoader.ALIGN_CENTER;
         this.m_aSwitchImageHolders[_loc4_].wpnImageLoader.FadeIn = false;
         this.m_aSwitchImageHolders[_loc4_].wpnImageLoader.FadeOut = false;
         this.m_aSwitchImageHolders[_loc4_].wpnImageLoader.UsePlaceholderSize();
         _loc4_ = _loc4_ + 1;
      }
      this.m_bInSelection = false;
      this.SetupInputHandlingForButton(this.wpnSwitch.arrowRight,this.MakeDelegate(this.OnRightArrow));
      this.SetupInputHandlingForButton(this.wpnSwitch.arrowLeft,this.MakeDelegate(this.OnLeftArrow));
      if(_global.SFX.Platform == com.XPlatform.PC)
      {
         this.SetupInputHandlingForButton(this.PCInfoButton,this.MakeDelegate(this.OnInfoButton));
      }
      else
      {
         this.PCInfoButton._visible = false;
      }
   }
   function SetImage(sImageResource)
   {
      this.wpnImageLoader.ResourceString = sImageResource;
      this.bHasWeaponImage = sImageResource != "";
      this.RefreshInfoButton();
      this.SetGlow(sImageResource != "");
   }
   // MILAN CHANGE - Mgamerz - 2026-10-17
   // Keep the mouse-only description button synchronized with input mode and weapon changes.
   function RefreshButtonHelp(usingGamepad)
   {
      this.bUsingGamepad = usingGamepad;
      this.RefreshInfoButton();
   }
   function SetInfoToggleEnabled(enabled)
   {
      this.bInfoToggleEnabled = enabled;
      this.RefreshInfoButton();
   }
   function RefreshInfoButton()
   {
      var showInfo = this.bInfoToggleEnabled && _global.SFX.Platform == com.XPlatform.PC && !this.bUsingGamepad && this.bHasWeaponImage;
      this.PCInfoButton._visible = showInfo;
      this.PCInfoButton.enabled = showInfo;
   }
   // END MILAN CHANGE
   function SetName(sName)
   {
      this.wpnNameText.text = sName;
   }
   function SetSwitchWeapon(sName, sImageResource, bNew, nNum, nTotal, bFlourish, sRarity)
   {
      if(bFlourish)
      {
         this.SetupSlidingImage(this.m_bSlideInFromLeft);
      }
      this.m_aSwitchImageHolders[this.m_nCurrentWeaponImage].WeapNum.numWpnText.text = nNum + "/" + nTotal;
      this.m_nCurrentWeap = nNum;
      this.m_nTotalWeaps = nTotal;
      if(this.wpnSwitch.arrowLeft._visible == false && this.m_nCurrentWeap > 0)
      {
         this.wpnSwitch.arrowLeft.gotoAndStop("out");
      }
      if(this.wpnSwitch.arrowRight._visible == false && this.m_nCurrentWeap < this.m_nTotalWeaps)
      {
         this.wpnSwitch.arrowRight.gotoAndStop("out");
      }
      this.wpnSwitch.arrowLeft._visible = this.m_nCurrentWeap > 0;
      this.wpnSwitch.arrowRight._visible = this.m_nCurrentWeap < this.m_nTotalWeaps;
      if(sRarity != "")
      {
         if(bNew)
         {
            this.m_aSwitchImageHolders[this.m_nCurrentWeaponImage].newTag.gotoAndStop("RarityDisplay");
         }
         this.wpnSwitch.panel.gotoAndStop(sRarity);
      }
      else
      {
         if(bNew)
         {
            this.m_aSwitchImageHolders[this.m_nCurrentWeaponImage].newTag.gotoAndStop("NormalDisplay");
         }
         this.wpnSwitch.panel.gotoAndStop(0);
      }
      if(bNew)
      {
         this.m_aSwitchImageHolders[this.m_nCurrentWeaponImage].newTag._visible = true;
         this.m_aSwitchImageHolders[this.m_nCurrentWeaponImage].newTag.text.text = "$" + _global.SFX.GetIniNumber("NewWeaponText");
      }
      else
      {
         this.m_aSwitchImageHolders[this.m_nCurrentWeaponImage].newTag._visible = false;
      }
      this.SetSwitchIcon(sImageResource,bFlourish);
      this.bHasWeaponImage = sImageResource != "";
      this.RefreshInfoButton();
      this.SetName(sName);
   }
   function SetupSlidingImage(bFromLeft)
   {
      var _loc2_ = this.m_nCurrentWeaponImage != 1 ? 1 : 0;
      var mcOld = this.m_aSwitchImageHolders[this.m_nCurrentWeaponImage];
      var mcNew = this.m_aSwitchImageHolders[_loc2_];
      var _loc4_ = this.m_nImageXPosition + (!bFromLeft ? this.m_nSlideDistance : - this.m_nSlideDistance);
      var _loc3_ = this.m_nImageXPosition - (!bFromLeft ? this.m_nSlideDistance : - this.m_nSlideDistance);
      mcOld.tween = new mx.transitions.Tween(mcOld,"_x",mx.transitions.easing.Strong.easeOut,this.m_nImageXPosition,_loc3_,screens.WeaponMod.WeaponSwitch.SLIDE_TIME,true);
      mcOld.tween.onMotionFinished = function()
      {
         mcOld.tween.onMotionFinished = undefined;
         delete mcOld.tween;
         mcOld.tween = undefined;
      };
      mcNew.tween = new mx.transitions.Tween(mcNew,"_x",mx.transitions.easing.Strong.easeOut,_loc4_,this.m_nImageXPosition,screens.WeaponMod.WeaponSwitch.SLIDE_TIME,true);
      mcNew.tween.onMotionFinished = function()
      {
         mcNew.tween.onMotionFinished = undefined;
         delete mcNew.tween;
         mcNew.tween = undefined;
      };
      this.m_nCurrentWeaponImage = _loc2_;
   }
   function SetSwitchIcon(sIconResource, bFlourish)
   {
      this.m_aSwitchImageHolders[this.m_nCurrentWeaponImage].wpnImageLoader.ResourceString = sIconResource;
   }
   function EnterSelectionMode()
   {
      if(this.m_bInSelection)
      {
         return undefined;
      }
      this.gotoAndPlay("toSwitch");
      this.SetGlow(false);
      this.m_bInSelection = true;
   }
   function SetGlow(bTurnOn)
   {
      if(this.m_bGlowUp != bTurnOn)
      {
         this.glow.gotoAndPlay(!bTurnOn ? "stopGlow" : "startGlow");
         this.m_bGlowUp = bTurnOn;
      }
   }
   function ExitSelectionMode()
   {
      if(!this.m_bInSelection)
      {
         return undefined;
      }
      this.gotoAndPlay("toSelected");
      this.m_bInSelection = false;
   }
   function SetupInputHandlingForButton(mcButton, fnCallback)
   {
      mcButton.hitArea = mcButton.HitArea;
      mcButton.bMouseOver = false;
      mcButton.onRollOver = function()
      {
         if(!mcButton.bMouseOver)
         {
            this.gotoAndPlay("toOver");
         }
         mcButton.bMouseOver = true;
      };
      mcButton.onRollOut = function()
      {
         if(mcButton.bMouseOver)
         {
            this.gotoAndPlay("toOut");
         }
         mcButton.bMouseOver = false;
      };
      mcButton.onRelease = function()
      {
         if(mcButton.bMouseOver)
         {
            this.gotoAndPlay("press");
            if(fnCallback != undefined)
            {
               fnCallback();
            }
         }
      };
      mcButton.onReleaseDblClick = mcButton.onRelease;
   }
   function OnRightArrow(bFlourish)
   {
      if(this.m_nCurrentWeap >= this.m_nTotalWeaps)
      {
         _global.SFX.PlayGUIError();
         return undefined;
      }
      if(bFlourish == true)
      {
         this.wpnSwitch.arrowRight.gotoAndPlay("consolePress");
      }
      this.m_bSlideInFromLeft = false;
      this.dispatchEvent({type:"selectNextWeapon"});
   }
   function OnLeftArrow(bFlourish)
   {
      if(this.m_nCurrentWeap <= 0)
      {
         _global.SFX.PlayGUIError();
         return undefined;
      }
      if(bFlourish == true)
      {
         this.wpnSwitch.arrowLeft.gotoAndPlay("consolePress");
      }
      this.m_bSlideInFromLeft = true;
      this.dispatchEvent({type:"selectPrevWeapon"});
   }
   function OnInfoButton()
   {
      if(!this.bInfoToggleEnabled) return undefined;
      this.dispatchEvent({type:"toggleInfoDisplay"});
   }
}
