class screens.LoadSave.LoadSaveVListItem extends com.bioware.masseffect.controls.VListItem
{
   var bannerSlot;
   var bannerImage; var bannerDisposed; var bannerGeneration; var bannerResource;
   var imageLoaded; var imageFailed; var wasNear; var nextPoll; var deadline;
   var Action;
   var ActionPC;
   var _data;
   var active;
   var dispatchEvent;
   var info;
   var m_mcBarOn;
   static var RecordTypeSaveGame = 0;
   static var RecordTypeCharacter = 1;
   var RecordType = 0;
   var _maxItemHeight = 73;
   var ActionTextGetsMouse = false;
   var ActionMC = undefined;
   var HasAction = false;
   function LoadSaveVListItem()
   {
      super();
      this.Action._visible = false;
      this.ActionPC._visible = false;
      this.ActionMC = this.GetActionMC();
      this.bannerSlot = this.createEmptyMovieClip("bannerSlot",100);
      this.bannerSlot._x = 280;
      this.bannerSlot._y = 8;
   }
   function updateItemFromData(p_data)
   {
      this.LoadBanner(p_data.resource);
      this.RecordType = p_data.recordType;
      switch(p_data.recordType)
      {
         case screens.LoadSave.LoadSaveVListItem.RecordTypeSaveGame:
            if(!this._data.defaultSaveRecord)
            {
               this.info.infoTxt.text = this._data.gameName;
            }
            else
            {
               this.info.infoTxt.text = this._data.gameName;
            }
            break;
         case screens.LoadSave.LoadSaveVListItem.RecordTypeCharacter:
            this.info.infoTxt.text = this._data.charName;
      }
      if(p_data.enableAButton)
      {
         this.ActionMC._visible = true;
         this.ActionMC.Text.text = p_data.actionText;
      }
   }
   function GetActionMC()
   {
      if(com.SFXScreen.GetPlatformLayout() == com.XPlatform.PC)
      {
         return this.ActionPC;
      }
      return this.Action;
   }
   function onRollOver()
   {
      if(!this.active)
      {
         if(this.m_mcBarOn.hitTest(_root._xmouse,_root._ymouse,true) == false)
         {
            return undefined;
         }
      }
      _global.SFX.PlayGUISound("SaveLoadListItemRollover");
      super.onRollOver();
      this.SetSelectedHover(true);
   }
   function SetSelectedHover(over)
   {
      if(!com.bioware.masseffect.controls.VListItem.SuppressEvents && this.m_mcBarActive != undefined)
      {
         this.m_mcBarActive.gotoAndPlay(over ? "mouseOver" : "mouseOff");
      }
   }
   function onRollOut()
   {
      super.onRollOut();
      this.SetSelectedHover(false);
   }
   function onReleaseOutside()
   {
      super.onReleaseOutside();
      this.SetSelectedHover(false);
   }
   function onPress()
   {
      if(this.active && !com.bioware.masseffect.controls.VListItem.SuppressEvents)
      {
         if(this.ActionMC.AcceptMouse == true && this.ActionMC.hitTest(_root._xmouse,_root._ymouse,true))
         {
            this.ActionMC.gotoAndPlay("selected");
            return undefined;
         }
      }
      super.onPress();
   }
   function onRelease()
   {
      if(this.active && !com.bioware.masseffect.controls.VListItem.SuppressEvents)
      {
         if(this.ActionMC.AcceptMouse == true && this.ActionMC.hitTest(_root._xmouse,_root._ymouse,true))
         {
            this.dispatchEvent({type:"VListItem_DoAction"});
            return undefined;
         }
      }
      super.onRelease();
   }
   function onMouseMove()
   {
      if(this.active && !com.bioware.masseffect.controls.VListItem.SuppressEvents)
      {
         if(this.ActionMC.hitTest(_root._xmouse,_root._ymouse,true))
         {
            if(this.ActionMC.AcceptMouse != true)
            {
               this.ActionMC.gotoAndPlay("startMouseOn");
               this.ActionMC.AcceptMouse = true;
            }
         }
         else if(this.ActionMC.AcceptMouse == true)
         {
            this.ActionMC.gotoAndPlay("startMouseOff");
            this.ActionMC.AcceptMouse = false;
         }
      }
      super.onMouseMove();
   }
   function get MaxHeight()
   {
      return 160;
   }
   function get MaxWidth()
   {
      return 864;
   }
   function LoadBanner(resource)
   {
      this.DisposeBanner();
      this.bannerDisposed = false;
      this.bannerResource = resource;
      this.imageLoaded = false;
      this.imageFailed = false;
      this.wasNear = false;
      this.nextPoll = 0;
      this.deadline = 0;
      this.onEnterFrame = this.RefreshBanner;
   }
   function StopImageLoader()
   {
      if(this.bannerImage != undefined)
      {
         this.bannerImage.OnFadeInComplete = undefined;
         this.bannerImage.mclLoader.removeListener(this.bannerImage);
         this.bannerImage.FadeIn = false;
         this.bannerImage.FadeOut = false;
         this.bannerImage.Clear();
         this.bannerImage.removeMovieClip();
         delete this.bannerImage;
      }
   }
   function DisposeBanner()
   {
      this.bannerDisposed = true;
      this.bannerGeneration = (this.bannerGeneration == undefined ? 0 : this.bannerGeneration)+1;
      this.StopImageLoader();
      delete this.onEnterFrame;
   }
   function onUnload() { this.DisposeBanner(); super.onUnload(); }
   function LoadResolvedImage(resource)
   {
      var row = this;
      var generation = this.bannerGeneration;
      var id = this.data.gameIndex;
      var image = this.bannerSlot.attachMovie("ScreenShotLoader","bannerImage",1);
      this.bannerImage = image;
      image.Async = true;
      image.FadeIn = false;
      image.FadeOut = false;
      image.PreserveAspectRatio = false;
      image.RegistrationPoint = 0;
      image.HAlign = 0;
      image.VAlign = 0;
      image.Width = 560;
      image.Height = 140;
      image.OnFadeInComplete = function()
      {
         if(!row.bannerDisposed && row.bannerGeneration == generation && row.data.gameIndex == id && row.bannerImage == image)
         {
            row.imageLoaded = true;
            row.imageFailed = false;
         }
      };
      var listener = new Object();
      listener.onLoadError = function(event)
      {
         if(!row.bannerDisposed && row.bannerGeneration == generation && row.bannerImage == image)
         {
            row.imageFailed = true;
            row.StopImageLoader();
         }
      };
      image.addEventListener("onLoadError",listener);
      image.ResourceString = resource;
   }
   function DrawRect(target,x,y,w,h)
   {
      target.moveTo(x,y); target.lineTo(x+w,y); target.lineTo(x+w,y+h);
      target.lineTo(x,y+h); target.lineTo(x,y);
   }
   function RefreshBanner()
   {
      if(this.bannerDisposed) { return; }
      var screen = _root.loadSave;
      this.bannerSlot._x = 280+this.info._x+13;
      this.info.infoTxt._width = 240;
      this.info.infoTxt._height = 80;
      this.info.infoTxt.wordWrap = true;
      this.info.infoTxt.multiline = true;
      this.info.infoTxt.text = this.data.gameName+(this.data.gameIndex == screen.equippedId ? "\n"+screen.labels.Equipped : "");
      var format = this.info.infoTxt.getTextFormat();
      format.align = "left";
      this.info.infoTxt.setTextFormat(format);
      if(this.data.gameIndex == 0) { return; }
      if(this.bannerSlot.status == undefined)
      {
         var backing = this.bannerSlot.createEmptyMovieClip("loadingBacking",0);
         backing.beginFill(0x07131F,65);
         this.DrawRect(backing,0,0,560,140);
         backing.endFill();
         this.bannerSlot.createTextField("status",2,12,12,536,100);
         this.bannerSlot.status.embedFonts = this.info.infoTxt.embedFonts;
         this.bannerSlot.status.setNewTextFormat(format);
         this.bannerSlot.status.selectable = false;
      }
      // Include both native fade zones, and one adjacent row for prefetch
      var near = Math.abs(this.data.index-screen.vList.movementRefElementIndex-1) <= 3;
      if(near && this.deadline == 0) { this.deadline = getTimer()+10000; }
      if(near && !this.wasNear && this.imageFailed)
      {
         this.imageFailed = false;
         this.deadline = getTimer()+10000;
      }
      this.wasNear = near;
      if(!this.imageLoaded && !this.imageFailed && this.deadline > 0 && getTimer() > this.deadline)
      {
         this.imageFailed = true;
         this.StopImageLoader();
      }
      if(near && !this.imageLoaded && !this.imageFailed && this.bannerImage == undefined && getTimer() >= this.nextPoll)
      {
         this.nextPoll = getTimer()+250;
         var resource = flash.external.ExternalInterface.call("GetBannerImage",this.data.gameIndex);
         if(resource != undefined && resource != "") { this.LoadResolvedImage(resource); }
      }
      this.bannerSlot.loadingBacking._visible = !this.imageLoaded;
      // Leave pending artwork blank
      // Only display status text after an actual failure
      this.bannerSlot.status._visible = !this.imageLoaded && this.imageFailed;
      this.bannerSlot.status.text = this.imageFailed ? screen.labels.Unavailable : "";
   }
}
