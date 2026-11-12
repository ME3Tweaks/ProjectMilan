class screens.Credits.Credits extends com.SFXInputMovieClip
{
   var MakeDelegate;
   var _x;
   var addEventListener;
   var attachMovie;
   var createEmptyMovieClip;
   var getNextHighestDepth;
   var m_FadeCreditField;
   var m_SafeRect;
   var m_ScrollContainer;
   var m_VisibleRect;
   var m_aScrollSections;
   var m_nColumnPadding;
   var m_nScrollStartPosition;
   var m_nTotalScrollDistance;
   var m_nVisibleScrollingFieldsEnd;
   var m_nVisibleScrollingFieldsStart;
   var onEnterFrame;
   var m_nTotalHeight = 0;
   function Credits()
   {
      super();
   }
   function onLoad()
   {
      super.onLoad();
      this.init();
   }
   function init()
   {
      com.SFXScreen.PrepareScreen();
      com.SFXScreen.OnResize = this.OnScreenResized;
      this.OnScreenResized();
      this.m_aScrollSections = [];
      this.m_nColumnPadding = 30;
      this.m_nTotalHeight = 0;
      this.m_nVisibleScrollingFieldsStart = 0;
      this.m_nVisibleScrollingFieldsEnd = 0;
      this.m_ScrollContainer = this.createEmptyMovieClip("scrollContainer",this.getNextHighestDepth());
      this.m_ScrollContainer._visible = false;
      this.m_FadeCreditField = this.attachMovie("FadeCreditField","fadeCreditField",this.getNextHighestDepth());
      this.m_FadeCreditField._alpha = 0;
      if(_global.SFX.Platform == com.XPlatform.PC || com.XPlatform.IsRunningInEngine() == false)
      {
         this.AddKeyUpEvent(27,"onEscape");
         this.addEventListener("onEscape",this.MakeDelegate(this.ExitCredits));
      }
      else
      {
         this.addEventListener("onButtonB",this.MakeDelegate(this.ExitCredits));
      }
      if(com.XPlatform.IsRunningInEngine() == false)
      {
         this.DEBUG_TestScrollingCredits();
      }
      flash.external.ExternalInterface.call("OnCreditsMovieLoaded");
   }
   function ExitCredits()
   {
      flash.external.ExternalInterface.call("TryExitCredits");
   }
   function OnScreenResized()
   {
      this.m_VisibleRect = com.SFXScreen.GetVisibleRect();
      this.m_SafeRect = com.SFXScreen.GetSafeRect();
      if(com.XPlatform.IsRunningInEngine() == false)
      {
         this.m_VisibleRect = com.SFXScreen.GetOriginalRect();
         this.m_SafeRect = new flash.geom.Rectangle(this.m_VisibleRect.width * 0.05,this.m_VisibleRect.height * 0.05,this.m_VisibleRect.width * 0.9,this.m_VisibleRect.height * 0.9);
      }
      this._x = this.m_SafeRect.left + this.m_SafeRect.width * 0.5;
   }
   function SetParameters(nColumnPadding)
   {
      this.m_nColumnPadding = nColumnPadding;
   }
   function InitializeEntryColumns(entry, nColumns)
   {
      entry.aCols = new Array(nColumns);
      if(nColumns > 1)
      {
         var nColumn = 0;
         while(nColumn < nColumns)
         {
            entry.aCols[nColumn] = {text:"",textArea:eval("entry.bodyTxt" + (nColumn + 1))};
            entry.aCols[nColumn].textArea.autoSize = "center";
            nColumn++;
         }
      }
      else
      {
         entry.bodyTxt.autoSize = "center";
      }
      this.SizeTextColumns(entry,true);
   }
   function SizeTextColumns(entry, bUseMaxWidth)
   {
      var _loc7_ = Math.min(this.m_SafeRect.width,this.m_VisibleRect.width - 10);
      var _loc6_ = 0;
      var _loc4_ = 0;
      var _loc2_ = 0;
      while(_loc2_ < entry.aCols.length)
      {
         _loc4_ = Math.max(_loc4_,entry.aCols[_loc2_].textArea.textWidth + 50);
         _loc2_ = _loc2_ + 1;
      }
      var _loc8_;
      var _loc5_;
      if(entry.aCols.length == 1)
      {
         entry.bodyTxt._width = _loc7_;
         entry.bodyTxt._x = - _loc7_ * 0.5;
      }
      else if(entry.aCols.length == 2)
      {
         _loc8_ = this.m_nColumnPadding * 0.5;
         _loc6_ = _loc7_ * 0.5 - _loc8_;
         _loc5_ = !bUseMaxWidth ? Math.min(_loc6_,_loc4_) : _loc6_;
         entry.aCols[0].textArea._width = _loc5_;
         entry.aCols[0].textArea._x = - (_loc5_ + _loc8_);
         entry.aCols[1].textArea._width = _loc5_;
         entry.aCols[1].textArea._x = _loc8_;
      }
      else if(entry.aCols.length == 3)
      {
         _loc6_ = (_loc7_ - this.m_nColumnPadding * 2) / 3;
         _loc5_ = !bUseMaxWidth ? Math.min(_loc6_,_loc4_) : _loc6_;
         entry.aCols[0].textArea._width = _loc5_;
         entry.aCols[0].textArea._x = - (_loc5_ * 1.5 + this.m_nColumnPadding);
         entry.aCols[1].textArea._width = _loc5_;
         entry.aCols[1].textArea._x = - _loc5_ * 0.5;
         entry.aCols[2].textArea._width = _loc5_;
         entry.aCols[2].textArea._x = _loc5_ * 0.5 + this.m_nColumnPadding;
      }
   }
   function AddScrollingCreditSection(sTitle, sNames, nColumns, nSpace, fFontScale)
   {
      var _loc5_ = this.m_ScrollContainer.attachMovie("ScrollCreditField","field",this.m_ScrollContainer.getNextHighestDepth());
      this.m_aScrollSections.push(_loc5_);
      _loc5_.titleTxt._width = Math.min(this.m_SafeRect.width,this.m_VisibleRect.width - 10);
      _loc5_.titleTxt.autoSize = "center";
      _loc5_.titleTxt.fontScaleFactor = fFontScale;
      _loc5_.titleTxt.text = sTitle;
      _loc5_.titleTxt._x = - _loc5_.titleTxt._width * 0.5;
      var _loc3_ = _loc5_.attachMovie("ScrollEntry_" + int(nColumns),"entry",_loc5_.getNextHighestDepth());
      _loc3_._x = 0;
      _loc3_._y = _loc5_.titleTxt._height;
      this.InitializeEntryColumns(_loc3_,nColumns);
      var _loc7_;
      var _loc2_;
      var _loc4_;
      if(nColumns > 1)
      {
         _loc7_ = sNames.split("\n");
         _loc2_ = 0;
         _loc4_ = 0;
         while(_loc4_ < _loc7_.length)
         {
            if(_loc3_.aCols[_loc2_].text != "")
            {
               _loc3_.aCols[_loc2_].text += "\n";
            }
            _loc3_.aCols[_loc2_].text += _loc7_[_loc4_];
            _loc2_ = _loc2_ + 1;
            if(_loc2_ >= nColumns)
            {
               _loc2_ = 0;
            }
            _loc4_ = _loc4_ + 1;
         }
         _loc2_ = 0;
         while(_loc2_ < nColumns)
         {
            _loc3_.aCols[_loc2_].textArea.fontScaleFactor = fFontScale;
            _loc3_.aCols[_loc2_].textArea.text = _loc3_.aCols[_loc2_].text;
            _loc2_ = _loc2_ + 1;
         }
         this.SizeTextColumns(_loc3_,false);
      }
      else
      {
         _loc3_.bodyTxt.fontScaleFactor = fFontScale;
         _loc3_.bodyTxt.text = sNames;
      }
      this.m_nTotalHeight += nSpace;
      _loc5_._x = 0;
      _loc5_._y = this.m_nTotalHeight;
      this.m_nTotalHeight += _loc5_._height;
      _loc5_._visible = false;
   }
   function AddScrollingCreditLineBreak(nSpace)
   {
      this.m_nTotalHeight += nSpace;
   }
   function AddScrollingCreditHeading(sTitle, nSpace, fFontScale)
   {
      var _loc2_ = this.m_ScrollContainer.attachMovie("ScrollCreditHeading","field",this.m_ScrollContainer.getNextHighestDepth());
      this.m_aScrollSections.push(_loc2_);
      this.m_nTotalHeight += nSpace;
      _loc2_._x = 0;
      _loc2_._y = this.m_nTotalHeight;
      _loc2_.headingTxt._width = Math.min(this.m_SafeRect.width,this.m_VisibleRect.width - 10);
      _loc2_.headingTxt.autoSize = "center";
      _loc2_.headingTxt.fontScaleFactor = fFontScale;
      _loc2_.headingTxt.text = sTitle;
      _loc2_.headingTxt._x = - _loc2_.headingTxt._width * 0.5;
      this.m_nTotalHeight += _loc2_._height;
      _loc2_._visible = false;
   }
   function ScrollToPosition(nScrollPosition)
   {
      var _loc3_ = 0;
      var _loc4_ = com.SFXScreen.GetVisibleRect();
      this.m_ScrollContainer._y = this.m_nScrollStartPosition - this.m_nTotalScrollDistance * nScrollPosition;
      var _loc2_ = this.m_nVisibleScrollingFieldsStart;
      while(_loc2_ < this.m_aScrollSections.length)
      {
         _loc3_ = this.m_ScrollContainer._y + this.m_aScrollSections[_loc2_]._y;
         if(_loc3_ >= _loc4_.bottom)
         {
            break;
         }
         if(_loc3_ + this.m_aScrollSections[_loc2_]._height < _loc4_.top)
         {
            this.m_aScrollSections[_loc2_]._visible = false;
            this.m_nVisibleScrollingFieldsStart = _loc2_ + 1;
         }
         else
         {
            this.m_aScrollSections[_loc2_]._visible = true;
         }
         _loc2_ = _loc2_ + 1;
      }
      if(this.m_ScrollContainer._y <= - this.m_nTotalHeight)
      {
         flash.external.ExternalInterface.call("CreditsFinished");
      }
   }
   function StartScrolling()
   {
      this.m_nScrollStartPosition = this.m_VisibleRect.bottom;
      this.m_nTotalScrollDistance = this.m_nTotalHeight + this.m_VisibleRect.height * 0.5;
      this.m_ScrollContainer._y = this.m_nScrollStartPosition;
      this.m_ScrollContainer._visible = true;
   }
   function SetFlashingCredit(sTitle, sNames, fFontScale)
   {
      this.m_FadeCreditField.titleTxt.autoSize = this.m_FadeCreditField.bodyTxt.autoSize = "center";
      this.m_FadeCreditField.titleTxt._height = 30;
      this.m_FadeCreditField.bodyTxt._height = 30;
      this.m_FadeCreditField.titleTxt._width = Math.min(this.m_SafeRect.width,this.m_VisibleRect.width - 10);
      this.m_FadeCreditField.bodyTxt._width = Math.min(this.m_SafeRect.width,this.m_VisibleRect.width - 10);
      this.m_FadeCreditField.titleTxt._x = - this.m_FadeCreditField.titleTxt._width * 0.5;
      this.m_FadeCreditField.bodyTxt._x = - this.m_FadeCreditField.bodyTxt._width * 0.5;
      this.m_FadeCreditField.titleTxt.fontScaleFactor = fFontScale;
      this.m_FadeCreditField.bodyTxt.fontScaleFactor = fFontScale;
      this.m_FadeCreditField.titleTxt.text = sTitle;
      this.m_FadeCreditField.bodyTxt._y = this.m_FadeCreditField.titleTxt._height;
      this.m_FadeCreditField.bodyTxt.text = sNames;
      this.m_FadeCreditField._y = this.m_VisibleRect.top + this.m_VisibleRect.height * 0.5 - this.m_FadeCreditField._height * 0.5;
      return this.m_FadeCreditField;
   }
   function DEBUG_BuildNames(nNum, sPrefix)
   {
      var _loc5_ = "abcdefghijklmnopqrstuvwxyz";
      var _loc3_ = "";
      var _loc1_ = 0;
      var _loc2_;
      var _loc4_;
      while(_loc1_ < nNum)
      {
         if(_loc3_ != "")
         {
            _loc3_ += "\n";
         }
         _loc2_ = int(Math.random() * 10);
         _loc4_ = _loc5_.substring(_loc2_,int(Math.random() * 16) + _loc2_);
         _loc3_ += sPrefix + _loc4_;
         _loc1_ = _loc1_ + 1;
      }
      return _loc3_;
   }
   function DEBUG_TestScrollingCredits()
   {
      var _loc2_ = this.DEBUG_BuildNames(10,"Name ");
      var _loc4_ = this.DEBUG_BuildNames(30,"Name ");
      var _loc5_ = this.DEBUG_BuildNames(50,"Name ");
      this.AddScrollingCreditHeading("This is a heading",60);
      this.AddScrollingCreditSection("Single-column Section",_loc2_,1,75);
      this.AddScrollingCreditSection("Double-column Section",_loc4_,2,75);
      this.AddScrollingCreditSection("Triple-column Section",_loc5_,3,75);
      this.AddScrollingCreditSection("Very long heading with lots of text in it and very few names benieth it asdf asd fasdf asd fad f",_loc2_,1,75);
      this.AddScrollingCreditSection("long name","my name is very very long and nothing, can stop me from, ever shortening it, so there!asd a asdf asd fasdf asdf asdf asdf asdf asf asdf asdf asdf asdf asdf ",1,75);
      this.AddScrollingCreditHeading("Another Heading, with 50px spacer beneath",100);
      this.AddScrollingCreditLineBreak(50);
      this.AddScrollingCreditHeading("Another Heading, with 100px spacer beneath",0);
      this.AddScrollingCreditLineBreak(100);
      this.AddScrollingCreditHeading("End of line break tests",0);
      this.StartScrolling();
      var nScrollTime = 20000;
      var nStart = new Date().getTime();
      var bDone = false;
      this.onEnterFrame = function()
      {
         var _loc3_ = new Date().getTime();
         var _loc4_ = _loc3_ - nStart;
         var _loc2_ = _loc4_ / nScrollTime;
         this.ScrollToPosition(_loc2_);
         if(_loc2_ > 1 && bDone == false)
         {
            trace("Done scrolling");
            bDone = true;
         }
         if(this.m_ScrollContainer._y < - this.m_nTotalHeight)
         {
            trace("Finished");
            delete this.onEnterFrame;
         }
      };
   }
}
