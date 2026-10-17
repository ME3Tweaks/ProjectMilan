class com.bioware.masseffect.views.PhotoMode extends MovieClip
{
   var ScreenLayout;
   var _activeHeaderIndex;
   var btnLegend;
   var headerButtons;
   var headerClips;
   var headerContainer;
   var list;
   var onEnterFrame;
   var optionData;
   var position;
   var srTakePhoto = "$817972";
   var srHideUI = "$817973";
   var srClose = "$817974";
   var srCamera = "$817975";
   var srCameraPC = "$817976";
   static var UI_PADDING_HEADER = 5;
   var adjustingControl = false;
   // MILAN CHANGE - Mgamerz - 2026-10-14
   // Keep the multiplayer subject selector separate from the native photo-option enum.
   static var OPTION_FOLLOWED_PLAYER = 1000;
   var multiplayerPlayers;
   var pendingMultiplayerPlayers;
   var selectedPlayerKey = "";
   var pendingPlayerKey = "";
   var suppressPlayerCallbacks = false;
   var followedPlayerLabel = "$49875780";
   var noPlayersLabel = "$49875781";
   var downedLabel = "$49875782";
   var followLabel = "$49875783";
   var menuBackdrop;
   var playerLayoutWidth = 74;
   var menuValueWidth = 0;
   // MILAN CHANGE - Mgamerz - 2026-10-16
   static var OPTION_PLAYER_MARKERS = 1001;
   var playerMarkersLabel = "$49875784";
   var markersOffLabel = "$653223";
   var markersOnLabel = "$653225";
   var showPlayerMarkers = true;
   var markerPageIndex = -1;
   // END MILAN CHANGE
   // END MILAN CHANGE
   function PhotoMode()
   {
      super();
   }
   function onLoad()
   {
      this.list.addEventListener("onChange",mx.utils.Delegate.create(this,this.onChange));
      this.list.addEventListener("onSettingChange",mx.utils.Delegate.create(this,this.onSettingChange));
      this.list.addEventListener("SFXMenuItem_onRollOver",mx.utils.Delegate.create(this,this.onMenuItemRollover));
      this.list.addEventListener("SFXMenuItem_onLeftArrowPress",mx.utils.Delegate.create(this,this.onDPadLeft));
      this.list.addEventListener("SFXMenuItem_onRightArrowPress",mx.utils.Delegate.create(this,this.onDPadRight));
      this.onEnterFrame = function()
      {
         flash.external.ExternalInterface.call("MovieLoaded");
         delete this.onEnterFrame;
      };
   }
   function initializePhotoMode()
   {
      this.initializeOptions();
   }
   function setOptionsVisible(p_visible)
   {
      this._visible = p_visible;
   }
   function initializeOptions()
   {
      // MILAN CHANGE - Mgamerz - 2026-10-16
      // Keep the original visibility tab, replacing its SP actor options with MP controls.
      var pages = new Array();
      this.markerPageIndex = -1;
      for(var pageIndex = 0; pageIndex < this.optionData.length; pageIndex++)
      {
         var children = new Array();
         var visibilityPage = false;
         for(var childIndex = 0; childIndex < this.optionData[pageIndex].children.length; childIndex++)
         {
            var child = this.optionData[pageIndex].children[childIndex];
            if(child.optionId >= 16 && child.optionId <= 20) visibilityPage = true;
            else children.push(child);
         }
         if(children.length > 0 || visibilityPage)
         {
            if(visibilityPage) this.markerPageIndex = pages.length;
            this.optionData[pageIndex].children = children;
            pages.push(this.optionData[pageIndex]);
         }
      }
      this.optionData = pages;
      this.multiplayerPlayers = new Array();
      this.rebuildPlayerOption();
      this.rebuildMarkerOption();
      // END MILAN CHANGE
      this._activeHeaderIndex = 0;
      this.headerClips = new Array();
      var _loc2_ = 0;
      var _loc3_;
      while(_loc2_ < this.optionData.length)
      {
         _loc3_ = com.bioware.masseffect.controls.PhotoModeHeader(this.headerContainer.attachMovie("PhotoModeHeader","header_" + _loc2_,this.headerContainer.getNextHighestDepth()));
         _loc3_.addEventListener("SFXButton_onRelease",this.onHeaderButton);
         _loc3_.index = _loc2_;
         if(_loc2_ != 0)
         {
            _loc3_._x = _loc3_._width * _loc2_ + com.bioware.masseffect.views.PhotoMode.UI_PADDING_HEADER * _loc2_;
         }
         this.headerClips.push(_loc3_);
         _loc2_ = _loc2_ + 1;
      }
      this.list.dataProvider = this.optionData[0].children;
      this.configurePlayerControl();
   }
   function initializePCButtons()
   {
      this.headerButtons.btnHeaderLeft.SFXButton_onReleaseHandler = this.onHeaderArrowButton;
      this.headerButtons.btnHeaderRight.SFXButton_onReleaseHandler = this.onHeaderArrowButton;
   }
   function updateScreenLayout(bUsingGamepad)
   {
      if(this.ScreenLayout == com.XPlatform.XBox)
      {
         this.btnLegend.gotoAndStop("xbox");
         this.headerButtons.gotoAndStop("xbox");
         com.TextFieldEx.SetText(this.btnLegend.hideUILabel,this.srHideUI,true,12);
         com.TextFieldEx.SetText(this.btnLegend.closeLabel,this.srClose,true,12);
         com.TextFieldEx.SetText(this.btnLegend.cameraLabel,this.srCamera,true,12);
      }
      else if(this.ScreenLayout == com.XPlatform.PS3)
      {
         this.btnLegend.gotoAndStop("ps");
         this.headerButtons.gotoAndStop("ps");
         com.TextFieldEx.SetText(this.btnLegend.hideUILabel,this.srHideUI,true,12);
         com.TextFieldEx.SetText(this.btnLegend.closeLabel,this.srClose,true,12);
         com.TextFieldEx.SetText(this.btnLegend.cameraLabel,this.srCamera,true,12);
      }
      else if(this.ScreenLayout == com.XPlatform.PC && bUsingGamepad)
      {
         this.btnLegend.gotoAndStop("pccontroller");
         this.headerButtons.gotoAndStop("pccontroller");
         com.TextFieldEx.SetText(this.btnLegend.takePhotoLabel,this.srTakePhoto,true,12);
         com.TextFieldEx.SetText(this.btnLegend.hideUILabel,this.srHideUI,true,12);
         com.TextFieldEx.SetText(this.btnLegend.closeLabel,this.srClose,true,12);
         com.TextFieldEx.SetText(this.btnLegend.cameraLabel,this.srCamera,true,12);
      }
      else
      {
         this.btnLegend.gotoAndStop("pckbm");
         this.headerButtons.gotoAndStop("pckbm");
         this.initializePCButtons();
         com.TextFieldEx.SetText(this.btnLegend.takePhotoLabel,this.srTakePhoto,true,12);
         com.TextFieldEx.SetText(this.btnLegend.hideUILabel,this.srHideUI,true,12);
         com.TextFieldEx.SetText(this.btnLegend.closeLabel,this.srClose,true,12);
         com.TextFieldEx.SetText(this.btnLegend.cameraLabel,this.srCameraPC,true,12);
      }
   }
   function modifyListPosition(p_delta)
   {
      this.adjustingControl = false;
      if(p_delta > 0 && this.position + p_delta < this.list.dataProvider.length)
      {
         this.position += p_delta;
         this.list.selectedIndex = this.position;
         fscommand(com.UnrealMessages.PlaySound,"MainMenuChangeOption");
      }
      else if(p_delta < 0 && this.position + p_delta >= 0)
      {
         this.position += p_delta;
         this.list.selectedIndex = this.position;
         fscommand(com.UnrealMessages.PlaySound,"MainMenuChangeOption");
      }
   }
   function set activeHeaderIndex(p_index)
   {
      if(p_index != this._activeHeaderIndex)
      {
         this.headerClips[this._activeHeaderIndex].selected = false;
         this._activeHeaderIndex = p_index;
         this.headerClips[this._activeHeaderIndex].selected = true;
         this.list.dataProvider = this.optionData[this._activeHeaderIndex].children;
         this.configurePlayerControl();
      }
   }
   function get activeHeaderIndex()
   {
      return this._activeHeaderIndex;
   }
   function onHeaderButton(p_event)
   {
      var _loc2_ = p_event.target;
      if(_loc2_.index != _root.PhotoMode.activeHeaderIndex)
      {
         _root.PhotoMode.activeHeaderIndex = _loc2_.index;
         fscommand(com.UnrealMessages.PlaySound,"MainMenuChangeOption");
      }
   }
   function onMenuItemRollover(p_event)
   {
      var _loc3_ = p_event.target;
      if(_loc3_.nIndex - this.position != 0)
      {
         _root.PhotoMode.modifyListPosition(_loc3_.nIndex - this.position);
      }
   }
   function onHeaderArrowButton(p_event)
   {
      if(p_event.target == _root.PhotoMode.headerButtons.btnHeaderLeft)
      {
         _root.PhotoMode.onLBPressed();
      }
      if(p_event.target == _root.PhotoMode.headerButtons.btnHeaderRight)
      {
         _root.PhotoMode.onRBPressed();
      }
   }
   function onDPadUp()
   {
      _root.PhotoMode.modifyListPosition(-1);
   }
   function onDPadDown()
   {
      _root.PhotoMode.modifyListPosition(1);
   }
   function onDPadLeft()
   {
      _root.PhotoMode.adjustingControl = true;
      _root.PhotoMode.list.selectedItem.decreaseSetting();
   }
   function onDPadRight()
   {
      _root.PhotoMode.adjustingControl = true;
      _root.PhotoMode.list.selectedItem.increaseSetting();
   }
   function onLBPressed()
   {
      if(_root.PhotoMode.activeHeaderIndex - 1 >= 0)
      {
         _root.PhotoMode.adjustingControl = false;
         _root.PhotoMode.activeHeaderIndex -= 1;
         fscommand(com.UnrealMessages.PlaySound,"MainMenuSwitchMenus");
      }
      else
      {
         fscommand(com.UnrealMessages.PlaySound,"guierror");
      }
   }
   function onRBPressed()
   {
      if(_root.PhotoMode.activeHeaderIndex + 1 < _root.PhotoMode.headerClips.length)
      {
         _root.PhotoMode.adjustingControl = false;
         _root.PhotoMode.activeHeaderIndex += 1;
         fscommand(com.UnrealMessages.PlaySound,"MainMenuSwitchMenus");
      }
      else
      {
         fscommand(com.UnrealMessages.PlaySound,"guierror");
      }
   }
   function onChange(p_event)
   {
      _root.PhotoMode.list.selectedIndex = _root.PhotoMode.position = 0;
   }
   function onSettingChange(p_event)
   {
      // MILAN CHANGE - Mgamerz - 2026-10-14
      // Roster refreshes must not select a different player merely by recreating a slider.
      if(this.suppressPlayerCallbacks) return;
      // MILAN CHANGE - Mgamerz - 2026-10-16
      if(p_event.optionId == com.bioware.masseffect.views.PhotoMode.OPTION_PLAYER_MARKERS)
      {
         if(this.adjustingControl)
         {
            this.showPlayerMarkers = p_event.numerator == 1;
            flash.external.ExternalInterface.call("SetPhotoPlayerMarkers",this.showPlayerMarkers);
         }
         return;
      }
      // END MILAN CHANGE
      if(p_event.optionId == com.bioware.masseffect.views.PhotoMode.OPTION_FOLLOWED_PLAYER)
      {
         if(this.adjustingControl && this.multiplayerPlayers.length > 0)
         {
            var player = this.multiplayerPlayers[p_event.numerator];
            if(player != undefined)
            {
               this.selectedPlayerKey = player.key;
               flash.external.ExternalInterface.call("SelectPhotoPlayer",player.key);
            }
         }
         return;
      }
      // END MILAN CHANGE
      _root.PhotoMode._numerator = p_event.numerator;
      _root.PhotoMode._denominator = p_event.denominator;
      if(_root.PhotoMode.adjustingControl)
      {
         if(p_event.value_ == undefined)
         {
            _root.PhotoMode.setOption(p_event.optionId,p_event.numerator);
            fscommand(com.UnrealMessages.PlaySound,"MainMenuChangeOption");
         }
         else
         {
            _root.PhotoMode.setOption(p_event.optionId,p_event.value_);
            fscommand(com.UnrealMessages.PlaySound,"MainMenuChangeOption");
         }
      }
   }
   function setOption(p_id, p_value)
   {
      flash.external.ExternalInterface.call("SetOption",p_id,p_value);
   }
   // MILAN CHANGE - Mgamerz - 2026-10-14
   // The handler sends complete roster snapshots keyed by PRI PlayerID, never transient list indices.
   function setMultiplayerLabels(playerLabel, emptyLabel, statusLabel, followModeLabel)
   {
      this.followedPlayerLabel = playerLabel;
      this.noPlayersLabel = emptyLabel;
      this.downedLabel = statusLabel;
      this.followLabel = followModeLabel;
   }
   // MILAN CHANGE - Mgamerz - 2026-10-16
   function setPlayerMarkerOptions(label, offLabel, onLabel, showMarkers)
   {
      this.playerMarkersLabel = label;
      this.markersOffLabel = offLabel;
      this.markersOnLabel = onLabel;
      this.showPlayerMarkers = showMarkers;
      this.rebuildMarkerOption();
      if(this.activeHeaderIndex == this.markerPageIndex)
      {
         this.list.dataProvider = this.optionData[this.markerPageIndex].children;
         this.configurePlayerControl();
      }
   }
   // END MILAN CHANGE
   function beginMultiplayerPlayers(playerKey)
   {
      this.pendingPlayerKey = playerKey;
      this.pendingMultiplayerPlayers = new Array();
   }
   function addMultiplayerPlayer(playerKey, playerName, downed)
   {
      this.pendingMultiplayerPlayers.push({key:playerKey,name:playerName,downed:downed});
   }
   function endMultiplayerPlayers()
   {
      this.multiplayerPlayers = this.pendingMultiplayerPlayers;
      this.selectedPlayerKey = this.pendingPlayerKey;
      this.pendingMultiplayerPlayers = undefined;
      this.suppressPlayerCallbacks = true;
      this.adjustingControl = false;
      this.rebuildPlayerOption();
      if(this.activeHeaderIndex == 0)
      {
         var oldPosition = this.position;
         this.list.dataProvider = this.optionData[0].children;
         this.position = Math.max(0,Math.min(oldPosition,this.list.dataProvider.length - 1));
         this.list.selectedIndex = this.position;
         this.configurePlayerControl();
      }
      this.suppressPlayerCallbacks = false;
   }
   function rebuildPlayerOption()
   {
      if(this.optionData == undefined || this.optionData.length == 0) return;
      var rows = this.optionData[0].children;
      for(var i = rows.length - 1; i >= 0; i--)
      {
         if(rows[i].optionId == com.bioware.masseffect.views.PhotoMode.OPTION_FOLLOWED_PLAYER || rows[i].optionId == com.bioware.masseffect.views.PhotoMode.OPTION_PLAYER_MARKERS) rows.splice(i,1);
         else if(rows[i].optionId == 0)
         {
            var freeLabel = rows[i].control.children[0].label;
            rows[i].control.children = [{label:freeLabel},{label:this.followLabel}];
            if(this.multiplayerPlayers.length == 0)
            {
               rows[i].control.children.splice(1,1);
               rows[i].control.defaultValue = 0;
            }
         }
      }
      var choices = new Array();
      var selectedIndex = 0;
      for(var j = 0; j < this.multiplayerPlayers.length; j++)
      {
         var player = this.multiplayerPlayers[j];
         choices.push({label:player.name});
         if(player.key == this.selectedPlayerKey) selectedIndex = j;
      }
      if(choices.length == 0) choices.push({label:this.noPlayersLabel});
      rows.splice(1,0,{label:this.followedPlayerLabel,optionId:com.bioware.masseffect.views.PhotoMode.OPTION_FOLLOWED_PLAYER,type:"TextSliderEx",enabled:this.multiplayerPlayers.length > 0,control:{children:choices,defaultValue:selectedIndex}});
   }
   // MILAN CHANGE - Mgamerz - 2026-10-16
   function rebuildMarkerOption()
   {
      if(this.markerPageIndex < 0) return;
      var rows = this.optionData[this.markerPageIndex].children;
      for(var i = rows.length - 1; i >= 0; i--)
      {
         if(rows[i].optionId == com.bioware.masseffect.views.PhotoMode.OPTION_PLAYER_MARKERS) rows.splice(i,1);
      }
      rows.push({label:this.playerMarkersLabel,optionId:com.bioware.masseffect.views.PhotoMode.OPTION_PLAYER_MARKERS,type:"TextSliderEx",control:{children:[{label:this.markersOffLabel},{label:this.markersOnLabel}],defaultValue:this.showPlayerMarkers ? 1 : 0}});
   }
   // All pages use the same value column, including choice and numeric controls.
   function configureMenuWidth()
   {
      for(var i = 0; i < this.list.rawChildren.length; i++)
      {
         if(!this.list.rawChildren[i].loaded) return false;
      }
      if(this.menuValueWidth == 0)
      {
         this.createTextField("menuWidthProbe",this.getNextHighestDepth(),0,0,1000,22);
         var probe = this.menuWidthProbe;
         probe._visible = false;
         probe.embedFonts = this.list.rawChildren[0].labelTxt.embedFonts;
         var format = this.list.rawChildren[0].labelTxt.getTextFormat();
         format.size = 14;
         probe.setNewTextFormat(format);
         probe.text = "00000000000000000000";
         probe.setTextFormat(format);
         this.menuValueWidth = Math.ceil(probe.textWidth) + 8;
         probe.removeTextField();
      }
      var width = this.menuValueWidth;
      var extra = width - this.playerLayoutWidth;
      if(extra != 0)
      {
         var backdropLeft = this.menuBackdrop.getBounds(this).xMin;
         this.menuBackdrop._width += extra;
         this.menuBackdrop._x += backdropLeft - this.menuBackdrop.getBounds(this).xMin;
         this.playerLayoutWidth = width;
      }
      for(i = 0; i < this.list.rawChildren.length; i++)
      {
         var item = this.list.rawChildren[i];
         item.rightArrow._x = 201.6 + width + 6;
         if(item.valueMask != undefined)
         {
            var maskLeft = item.valueMask.getBounds(item).xMin;
            item.valueMask._width = width;
            item.valueMask._x += maskLeft - item.valueMask.getBounds(item).xMin;
            item.textSpacing = width + 50;
            for(var j = 0; j < item.menuItems.length; j++)
            {
               item.menuItems[j]._x = j * item.textSpacing;
               item.menuItems[j].labelTxt._width = width - 4;
               item.menuItems[j].labelTxt.textAutoSize = "shrink";
            }
            item.endX = item.MENUHOLDER_X - item._selectedIndex * item.textSpacing;
            item.menuHolder._x = item.endX;
         }
         if(item.txt != undefined) item.txt._width = width - 4;
         if(item.percentTxt != undefined) item.percentTxt._width = width - 4;
      }
      return true;
   }
   // END MILAN CHANGE
   function configurePlayerControl()
   {
      // Attached controls acquire optionId in onLoad, on the next advance rather than synchronously.
      var owner = this;
      var sync = this.createEmptyMovieClip("milanPlayerControlSync",this.getNextHighestDepth());
      sync.onEnterFrame = function()
      {
         if(!owner.configureMenuWidth()) return;
         var index = owner.list.GetOptionIndex(com.bioware.masseffect.views.PhotoMode.OPTION_FOLLOWED_PLAYER);
         if(index >= 0)
         {
            var item = owner.list.rawChildren[index];
            item.setEnabled(owner.multiplayerPlayers.length > 0);
            // MILAN CHANGE - Mgamerz - 2026-10-16
            // Use a fixed twenty-character viewport and a separate value label. The stock
            // row color transform overrides child text colors, and its carousel is too narrow.
            item.createTextField("photoPlayerLabel",1000,item.MENUHOLDER_X,1,1000,22);
            var field = item.photoPlayerLabel;
            field.selectable = false;
            field.embedFonts = item.menuItems[0].labelTxt.embedFonts;
            var format = item.menuItems[0].labelTxt.getTextFormat();
            format.size = item.textSize;
            format.align = "center";
            field.setNewTextFormat(format);
            var width = owner.menuValueWidth;
            field._width = width;
            field.textAutoSize = "shrink";
            field.text = "";
            // Keep native selection/arrow logic, but draw only the selected name. This also
            // avoids sliding neighboring names through the viewport on roster rebuilds.
            item.menuHolder._visible = false;
            item.onEnterFrame = function()
            {
               var enabled = this.IsEnabled();
               var color = !enabled ? com.bioware.masseffect.controls.BaseMenuItem.DISABLED_COLOR : (this.active ? com.bioware.masseffect.controls.PhotoModeControl.ACTIVE_COLOR : com.bioware.masseffect.controls.PhotoModeControl.INACTIVE_COLOR);
               var tint = new Color(this);
               tint.setTransform({ra:100,rb:0,ga:100,gb:0,ba:100,bb:0,aa:enabled ? 100 : 40,ab:0});
               this.labelTxt.textColor = color;
               new Color(this.leftArrow).setRGB(color);
               new Color(this.rightArrow).setRGB(color);
               var player = owner.multiplayerPlayers[this._selectedIndex];
               var name = player == undefined ? owner.noPlayersLabel : player.name;
               if(name.length > 20) name = name.substr(0,19) + "\u2026";
               if(this.photoPlayerLabel.text != name)
               {
                  com.TextFieldEx.SetText(this.photoPlayerLabel,name,true,14);
               }
               this.photoPlayerLabel.textColor = player != undefined && player.downed ? 0xE08080 : color;
            };
            item.onEnterFrame();
            // END MILAN CHANGE
         }
         this.removeMovieClip();
      };
   }
   // END MILAN CHANGE
}
