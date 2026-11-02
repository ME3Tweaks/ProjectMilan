class screens.MPNewLobby.PlayerItem extends screens.MPNewLobby.PageItem
{
    var PlayerTitleBar;
    var SelectOnRollover;
    var disabled;
    var gotoAndPlay;
    var leaderHost;
    var m_EmblemID;
    var m_aTickerData;
    var m_bInteractive;
    var onEnterFrame;
    var selection;
    var slot;
    var m_slotIndex = -1;
    var isOccupied = false;
    var isPrivate = true;
    var isLocalPlayer = false;
    var isLeader = false;
    var m_NumKickVotes = -1;
    var m_nCustomIcon = -1;
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
        var bValidPlayer = oPlayerDetails.Gamertag != "" && oPlayerDetails.Rating > 0;
        if(!this.isOccupied && bValidPlayer)
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
        this.SetCustomIcon(this.m_nCustomIcon);
        this.SetKickVotes(oPlayerDetails.NumKickVotesReceived);
        this.disabled = false;
        this.isLocalPlayer = oPlayerDetails.IsLocalPlayer;
        this.isLeader = oPlayerDetails.IsLeader;
        this.leaderHost._visible = this.isLeader;
        this.leaderHost.leader.text = _root.screen.srLeader;
        var TickerValues = new Array();
        TickerValues.push({Value:oPlayerDetails.Rating,Type:"N7Rating"});
        TickerValues.push({Value:oPlayerDetails.NumClassPromotions,Type:"Promotion"});
        TickerValues.push({Value:oPlayerDetails.NumChallengesComplete,Type:"Challenge"});
        this.SetTickerData(TickerValues);
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
            this.slot.gotoAndStop(bPrivate ? "private" : "public");
            var label = this.slot.slotText;
            // Resolve the existing stringref first, then append an untranslated index.
            // Never concatenate a suffix onto the "$12345" translation key.
            label.noTranslate = false;
            label.text = bPrivate ? _root.screen.srPrivateSlot : _root.screen.srPublicSlot;
            label.noTranslate = true;
            if(this.m_slotIndex >= 0)
            {
                label.appendText(" " + (this.m_slotIndex + 1));
            }
            label.textAutoSize = "shrink";
        }
    }

    function SetInteractive(b)
    {
        this.m_bInteractive = b;
        this.selection._visible = this.m_bInteractive || !this.isOccupied;
    }

    // MILAN CHANGE - 10/04/2026 - Mgamerz
    // Replaces the speaker icon: the voice clip shows the screen this player is on (see SFXPRIMP.LobbyScreen).
    // A negative index shows the empty "none" frame. The index is kept because SetOccupied rebuilds the title bar.
    function SetCustomIcon(nIcon)
    {
        this.m_nCustomIcon = nIcon;
        this.PlayerTitleBar.voice.gotoAndStop(nIcon >= 0 ? "custom" + nIcon : "none");
    }

    function SetEmblemData(nEmblemID)
    {
        this.m_EmblemID = nEmblemID;
        var EmblemData;
        if(this.HasFullyLoaded())
        {
            EmblemData = flash.external.ExternalInterface.call("GetEmblemData",this.m_EmblemID);
            this.PlayerTitleBar.emblemTitle.textAutoSize = "shrink";
            this.PlayerTitleBar.emblemTitle._visible = EmblemData.srTitle != 0;
            this.PlayerTitleBar.emblemTitle.text = "$" + String(EmblemData.srTitle);
            this.PlayerTitleBar.emblemBackground.PreserveAspectRatio = false;
            this.PlayerTitleBar.emblemBackground.ResourceString = EmblemData.BackgroundResource;
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
        if(_root.screen.bUsingGamepad)
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
            if(this.m_bInteractive)
            {
                super.onRelease();
            }
            else
            {
                flash.external.ExternalInterface.call("SetPreviouslySelectedItem",screens.MPNewLobby.MPNewLobby.LSS_Squad,this.m_slotIndex);
                _root.screen.m_SelectedPlayerSlot = this.m_slotIndex;
                _root.screen.ShowSquadScreen();
            }
        }
        else
        {
            _root.screen.InviteFriends();
        }
    }
    function SetKickVotes(newKickVotes)
    {
        var PlayerKickIndicator = this.PlayerTitleBar.kickIndicator;
        PlayerKickIndicator.kickIcon1._visible = newKickVotes >= 1;
        PlayerKickIndicator.kickIcon2._visible = newKickVotes >= 2;
        PlayerKickIndicator.kickIcon3._visible = newKickVotes >= 3;
        this.m_NumKickVotes = newKickVotes;
    }
}
