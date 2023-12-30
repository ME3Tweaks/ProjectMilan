class screens.MPNewLobby.PlayerItem extends screens.MPNewLobby.PageItem
{
   var slot;
   var PlayerTitleBar;
   var leaderHost;
   var onEnterFrame;
   var m_aTickerData;
   var m_EmblemID;
   var m_bInteractive;
   var selection;
   var isOccupied = false;
   var isPrivate = true;
   var isLocalPlayer = false;
   var isLeader = false;
   var m_NumKickVotes = -1;
   function PlayerItem()
   {
      super();
   }
   function onLoad()
   {
      super.onLoad();
      this.SelectOnRollover = false;
   }
   function SetOccupied(oPlayerDetails)
   {
      var _loc5_ = oPlayerDetails.Gamertag != "" && oPlayerDetails.Rating > 0;
      if(!this.isOccupied && _loc5_)
      {
         this.isOccupied = true;
         this.slot.gotoAndStop("occupied");
         this.slot.titleBarHolder.gotoAndPlay("in");
      }
      this.PlayerTitleBar = this.slot.titleBarHolder.titleBar;
      this.PlayerTitleBar.title.text = oPlayerDetails.Gamertag;
      this.PlayerTitleBar.title.textAutoSize = "shrink";
      this.PlayerTitleBar.subtitle.text = oPlayerDetails.ClassData;
      this.PlayerTitleBar.subtitle.textAutoSize = "shrink";
      this.PlayerTitleBar.ready.gotoAndStop(!oPlayerDetails.Ready ? "waiting" : "ready");
      this.SetKickVotes(oPlayerDetails.NumKickVotesReceived);
      this.disabled = false;
      this.isLocalPlayer = oPlayerDetails.IsLocalPlayer;
      this.isLeader = oPlayerDetails.IsLeader;
      this.leaderHost._visible = this.isLeader;
      this.leaderHost.leader.text = _root.screen.srLeader;
      var _loc4_ = new Array();
      _loc4_.push({Value:oPlayerDetails.Rating,Type:"N7Rating"});
      _loc4_.push({Value:oPlayerDetails.NumClassPromotions,Type:"Promotion"});
      _loc4_.push({Value:oPlayerDetails.NumChallengesComplete,Type:"Challenge"});
      this.SetTickerData(_loc4_);
      this.SetEmblemData(oPlayerDetails.EmblemID);
      this.onEnterFrame = function()
      {
         if(this.HasFullyLoaded())
         {
            this.SetTickerData(this.m_aTickerData);
            this.SetEmblemData(this.m_EmblemID);
            delete this.onEnterFrame;
         }
      };
   }
   function SetEmpty()
   {
      this.isOccupied = false;
      this.leaderHost._visible = false;
      this.SetPermission(this.isPrivate);
      this.disabled = true;
   }
   function SetPermission(bPrivate)
   {
      this.isPrivate = bPrivate;
      if(this.isOccupied == false)
      {
         if(this.isPrivate)
         {
            this.slot.gotoAndStop("private");
            this.slot.slotText.text = _root.screen.srPrivateSlot;
         }
         else
         {
            this.slot.gotoAndStop("public");
            this.slot.slotText.text = _root.screen.srPublicSlot;
         }
      }
   }
   function SetInteractive(b)
   {
      this.m_bInteractive = b;
      this.selection._visible = this.m_bInteractive || !this.isOccupied;
   }
   function SetSpeakerIcon(bEnabled, fVolume)
   {
      if(!bEnabled)
      {
         this.PlayerTitleBar.voice.gotoAndStop("inactive");
      }
      else if(fVolume < 0.25)
      {
         this.PlayerTitleBar.voice.gotoAndStop("level0");
      }
      else if(fVolume < 0.5)
      {
         this.PlayerTitleBar.voice.gotoAndStop("level1");
      }
      else if(fVolume < 0.75)
      {
         this.PlayerTitleBar.voice.gotoAndStop("level2");
      }
      else
      {
         this.PlayerTitleBar.voice.gotoAndStop("level3");
      }
   }
   function SetEmblemData(nEmblemID)
   {
      this.m_EmblemID = nEmblemID;
      if(this.HasFullyLoaded())
      {
         var _loc2_ = flash.external.ExternalInterface.call("GetEmblemData",this.m_EmblemID);
         this.PlayerTitleBar.emblemTitle.textAutoSize = "shrink";
         this.PlayerTitleBar.emblemTitle._visible = _loc2_.srTitle != 0;
         this.PlayerTitleBar.emblemTitle.text = "$" + String(_loc2_.srTitle);
         this.PlayerTitleBar.emblemBackground.PreserveAspectRatio = false;
         this.PlayerTitleBar.emblemBackground.ResourceString = _loc2_.BackgroundResource;
      }
   }
   function SetTickerData(aTickerData)
   {
      this.m_aTickerData = aTickerData;
      if(this.HasFullyLoaded())
      {
         this.PlayerTitleBar.ticker.SetTickerData(this.m_aTickerData);
      }
   }
   function HasFullyLoaded()
   {
      return this.PlayerTitleBar.ticker.IsLoaded() && this.PlayerTitleBar.emblemBackground.IsLoaded();
   }
   function onRollOver()
   {
      // MILAN CHANGE DropTheSquid 12/29/2023
      // make sure this does not fire while we are using the gamepad, even if you leave the (invisible) mouse hovering over it.
      if (_root.screen.bUsingGamepad)
      {
         return;
      }
      // END MILAN
      super.onRollOver();
      if(!this.m_bInteractive)
      {
         this.gotoAndPlay("in");
         this.selection._visible = true;
      }
   }
   function onRollOut()
   {
      super.onRollOut();
      if(!this.m_bInteractive)
      {
         this.gotoAndPlay("normal");
         this.selection._visible = !this.isOccupied;
      }
   }
   function onPress()
   {
      if(this.m_bInteractive && this.isOccupied)
      {
         super.onPress();
      }
   }
   function onRelease()
   {
      if(this.isOccupied)
      {
         if(this.PlayerTitleBar.voice.hitTest(_root._xmouse,_root._ymouse))
         {
            this.ToggleMute();
         }
         else if(this.m_bInteractive)
         {
            super.onRelease();
         }
         else
         {
            flash.external.ExternalInterface.call("SetPreviouslySelectedItem",screens.MPNewLobby.MPNewLobby.LSS_Squad,this.m_listIndex);
            _root.screen.ShowSquadScreen();
         }
      }
      else
      {
         _root.screen.InviteFriends();
      }
   }
   function ToggleMute()
   {
      flash.external.ExternalInterface.call("ToggleMuteForSlot",this.m_listIndex);
   }
   function SetKickVotes(newKickVotes)
   {
      var _loc2_ = this.PlayerTitleBar.kickIndicator;
      _loc2_.kickIcon1._visible = newKickVotes >= 1;
      _loc2_.kickIcon2._visible = newKickVotes >= 2;
      _loc2_.kickIcon3._visible = newKickVotes >= 3;
      this.m_NumKickVotes = newKickVotes;
   }
}
