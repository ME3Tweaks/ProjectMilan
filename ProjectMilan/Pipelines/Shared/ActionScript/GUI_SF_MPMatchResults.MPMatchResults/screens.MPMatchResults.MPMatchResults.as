class screens.MPMatchResults.MPMatchResults extends com.SFXScreen
{
    var PlayerBarClips;
    var PlayerBar1;
    var PlayerBar2;
    var PlayerBar3;
    var PlayerBar4;
    var PC_ContinueButton;
    var ControllerButtons;
    var ScreenHeader;
    var SquadMedals;
    var MatchHeader;
    var SquadTotalText;
    var SquadXP;
    var SquadCredits;
    var SquadBonusXP;
    var CreditsIcon;
    var Intro;
    var IntroBackground;
    var m_IntroEventList;
    var TotalXPBar;
    var srContinue = "NOLOC:Continue";
    var srSkip = "NOLOC:Skip";
    var srShowGamerCard = "NOLOC:Show Gamercard";
    var srSquadTotal = "NOLOC:Squad Total";
    var srMissionSuccessful = "NOLOC:MISSION SUCCESSFUL";
    var srMissionFailed = "NOLOC:MISSION FAILED";
    static var FOCUSED_FIELD_PLAYER_BARS = 0;
    static var FOCUSED_FIELD_SQUAD_MEDALS = 1;
    static var GAW_GREEN_THRESHOLD = 75;
    var m_CurrentFocusedField = screens.MPMatchResults.MPMatchResults.FOCUSED_FIELD_PLAYER_BARS;
    var m_CurrentFocusedPlayerBarIndex = 0;
    var m_LocalPlayerBarIndex = -1;
    var m_bProcessingIntroEvents = false;
	var bUsingGamepad;
	var bIgnoreMouseHover;
    static var INTRO_BACKGROUND_FADEOUT_FRAME = "fadeOut";
    function MPMatchResults()
    {
        super();
        this.PlayerBarClips = new Array();
        this.PlayerBarClips.push(this.PlayerBar1);
        this.PlayerBarClips.push(this.PlayerBar2);
        this.PlayerBarClips.push(this.PlayerBar3);
        this.PlayerBarClips.push(this.PlayerBar4);
    }
    function onLoad()
    {
        super.onLoad();
        this.InitializeLocalizedStrings();
        this.SetupHeader();
    }
    function InitializeLocalizedStrings()
    {
        this.srContinue = "$" + _global.SFX.GetIniString("srContinue");
        this.srSquadTotal = "$" + _global.SFX.GetIniString("srSquadTotal");
        this.srMissionSuccessful = "$" + _global.SFX.GetIniString("srMissionSuccessful");
        this.srMissionFailed = "$" + _global.SFX.GetIniString("srMissionFailed");
        this.srShowGamerCard = "$" + _global.SFX.GetIniString("srShowGamerCard");
        this.srSkip = "$" + _global.SFX.GetIniString("srSkip");
    }
	// MILAN CHANGE DropTheSquid 1/8/2024
	// adding a mouse listener so we can better distinguish mouse/keyboard input modes
	function SetupMouse()
	{
		var mouseListener = new Object();
		mouseListener.onMouseMove = function () {
			_root.screen.bIgnoreMouseHover = false;
		};
		mouseListener.onMouseWheel = function(delta, scrollTarget) {
			// this counts as a mouse action and we want things to react to the mouse over them
			_root.screen.bIgnoreMouseHover = false;
		}
		Mouse.addListener(mouseListener);
	}
	// added this new method which takes all the button visibility code from RefreshButtons
	// and makes it reusable (not just run once at init) so we can switch dynamically
    function RefreshButtonHelp(usingGamepad)
    {
		this.bUsingGamepad = usingGamepad;
		if(!usingGamepad)
        {
			this.ControllerButtons._visible = false;
            this.PC_ContinueButton.SetVisible(true);
            this.PC_ContinueButton.SetEnabled(true);
        }
        else
        {
			this.PC_ContinueButton.SetVisible(false);
            this.PC_ContinueButton.SetEnabled(false);
            this.ControllerButtons._visible = true;
        }
    }
	// END MILAN
    function SetupButtons()
    {
        this.PC_ContinueButton = _root.PC_ContinueButton;
        this.ControllerButtons = _root.mcConsoleButtons;
        
		this.PC_ContinueButton.SetText(this.srContinue);
		this.PC_ContinueButton.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.OnPCContinueButtonRelease));
	
		this.ControllerButtons.addEventListener("onButtonA",mx.utils.Delegate.create(this,this.OnConsoleAButton));
		this.ControllerButtons.addEventListener("onDPadLeft",mx.utils.Delegate.create(this,this.OnDPadLeft));
		this.ControllerButtons.addEventListener("onDPadRight",mx.utils.Delegate.create(this,this.OnDPadRight));
		this.ControllerButtons.addEventListener("onDPadUp",mx.utils.Delegate.create(this,this.OnDPadUp));
		this.ControllerButtons.addEventListener("onDPadDown",mx.utils.Delegate.create(this,this.OnDPadDown));
		this.ControllerButtons.addEventListener("onInvalidInput",mx.utils.Delegate.create(this,this.OnInvalidInput));
		this.ControllerButtons.ControlA.SetText(this.srContinue);
		
		this.ControllerButtons.ControlY.Active = false;
		this.ControllerButtons.ControlY.SetVisible(false);
		
		this.ControllerButtons.ControlX.Active = false;
		this.ControllerButtons.ControlX.Hidden = true;
		this.ControllerButtons.ControlB.Active = false;
		this.ControllerButtons.ControlB.Hidden = true;
		this.ControllerButtons.FitLeft();
        
		this.RefreshButtonHelp(flash.external.ExternalInterface.call("IsUsingGamepad"));
    }
    function SetupHeader()
    {
        var _loc2_ = Boolean(flash.external.ExternalInterface.call("GetMissionResult"));
        this.ScreenHeader.text = !_loc2_ ? this.srMissionFailed : this.srMissionSuccessful;
    }
    function InitializeScreen()
    {
        var _loc4_ = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetPlayerData"));
        var _loc16_ = 0;
        var _loc3_ = 0;
        while(_loc3_ < this.PlayerBarClips.length)
        {
            if(_loc3_ < _loc4_.length)
            {
                this.PlayerBarClips[_loc3_]._visible = true;
                this.PlayerBarClips[_loc3_].SetPlayerData(_loc4_[_loc3_].PlayerDataIdx,_loc4_[_loc3_].PlayerName,_loc4_[_loc3_].ClassData,_loc4_[_loc3_].ClassIconRef,com.SFXScreen.ObjectToArray(_loc4_[_loc3_].Medals),_loc4_[_loc3_].TotalMatchXP,_loc4_[_loc3_].MatchXPPercentage,_loc4_[_loc3_].bExtracted);
                this.PlayerBarClips[_loc3_].addEventListener("hoverOver",this.MakeDelegate(this.OnPlayerBarHovered));
                if(_loc4_[_loc3_].bIsLocal)
                {
                    this.m_CurrentFocusedPlayerBarIndex = _loc3_;
                    this.m_LocalPlayerBarIndex = _loc3_;
                }
            }
            else
            {
                this.PlayerBarClips[_loc3_]._visible = false;
            }
            _loc3_ = _loc3_ + 1;
        }
        var _loc6_ = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetSquadMedals"));
        var _loc14_ = this.SquadMedals._x;
        this.SquadMedals.SetMedalData(_loc6_);
        this.SquadMedals._x = _loc14_ - this.SquadMedals._width / 2;
        this.SetupTotalXPBar();
        var _loc15_ = String(flash.external.ExternalInterface.call("GetMatchMap"));
        var _loc11_ = String(flash.external.ExternalInterface.call("GetMatchEnemy"));
        var _loc12_ = String(flash.external.ExternalInterface.call("GetMatchChallenge"));
        var _loc7_ = String(flash.external.ExternalInterface.call("GetMatchWave"));
        var _loc8_ = Number(flash.external.ExternalInterface.call("GetMatchTime"));
        var _loc13_ = com.Utilities.FormatTimeStringMinutesSeconds(_loc8_);
        this.MatchHeader.SetMatchData(_loc15_,_loc11_,_loc12_,_loc7_,_loc13_);
        this.SquadTotalText.text = this.srSquadTotal;
        var _loc10_ = flash.external.ExternalInterface.call("GetSquadTotalXP");
        this.SquadXP.text = String(flash.external.ExternalInterface.call("GetPlusFormattedValue",_loc10_));
        var _loc9_ = flash.external.ExternalInterface.call("GetSquadTotalCredits");
        this.SquadCredits.text = String(flash.external.ExternalInterface.call("GetPlusFormattedValue",_loc9_));
        var _loc5_ = flash.external.ExternalInterface.call("GetSquadBonusXP");
        if(_loc5_ > 0)
        {
            this.SquadBonusXP.text = "(" + String(flash.external.ExternalInterface.call("GetPlusFormattedValue",_loc5_)) + ")";
        }
        else
        {
            this.SquadBonusXP._visible = false;
            this.CreditsIcon._x = this.SquadXP._x + this.SquadXP._width;
            this.SquadCredits._x = this.CreditsIcon._x + this.CreditsIcon._width;
        }
		// TODO will need to do something about this. 
        if(_global.SFX.Platform != com.XPlatform.PC)
        {
            this.PlayerBarClips[this.m_CurrentFocusedPlayerBarIndex].SetHovered(true);
            this.PlayerBarClips[this.m_CurrentFocusedPlayerBarIndex].SetHoveredMedalIndex(0);
        }
        this.SetupButtons();
        this.SetupIntroEvents();
		// MILAN CHANGE DropTheSquid 1/8/2024
		// actually call the new method
		this.SetupMouse();
		// END MILAN
    }
    function SetupIntroEvents()
    {
        this.Intro = _root.EventIntro;
        this.IntroBackground = _root.IntroBackground;
        this.Intro.addEventListener("IntroEventFinished",this.MakeDelegate(this.ProcessIntroEvents));
        this.m_IntroEventList = new Array();
        var _loc6_ = Boolean(flash.external.ExternalInterface.call("HasOverallRatingsIncrease"));
        if(_loc6_)
        {
            var _loc8_ = String(flash.external.ExternalInterface.call("GetOverallRatingsString"));
            this.m_IntroEventList.push({ModeID:screens.MPMatchResults.IntroEvents.EVENT_MODE_GALAXY_BONUS,Text:_loc8_,SoundTag:"MPMatchResultsEventGAWGlobal"});
        }
        var _loc9_ = Number(flash.external.ExternalInterface.call("GetGAWMapID"));
        var _loc10_ = Number(flash.external.ExternalInterface.call("GetGAWMapRating"));
        var _loc14_ = Number(flash.external.ExternalInterface.call("GetGAWMapRatingIncrease"));
        if(_loc14_ > 0)
        {
            var _loc13_ = String(flash.external.ExternalInterface.call("GetGAWMapString"));
            this.m_IntroEventList.push({ModeID:screens.MPMatchResults.IntroEvents.EVENT_MODE_GALAXY,Text:_loc13_,SoundTag:"MPMatchResultsEventGAWMap",OptionalParameter1:_loc9_,OptionalParameter2:_loc10_});
        }
        var _loc12_ = Boolean(flash.external.ExternalInterface.call("LeveledUp"));
        if(_loc12_)
        {
            var _loc11_ = String(flash.external.ExternalInterface.call("GetLeveledUpString"));
            this.m_IntroEventList.push({ModeID:screens.MPMatchResults.IntroEvents.EVENT_MODE_LEVELUP,Text:_loc11_,SoundTag:"MPMatchResultsEventLevelUp"});
        }
        var _loc4_ = Number(flash.external.ExternalInterface.call("GetSquadTotalCredits"));
        if(_loc4_ > 0)
        {
            var _loc5_ = String(flash.external.ExternalInterface.call("GetPlusFormattedValue",_loc4_));
            this.m_IntroEventList.push({ModeID:screens.MPMatchResults.IntroEvents.EVENT_MODE_CREDITS,Text:_loc5_,SoundTag:"MPMatchResultsEventCredits"});
        }
        var _loc3_ = Number(flash.external.ExternalInterface.call("GetSquadTotalXP"));
        if(_loc3_ > 0)
        {
            var _loc7_ = String(flash.external.ExternalInterface.call("GetPlusFormattedValue",_loc3_));
            this.m_IntroEventList.push({ModeID:screens.MPMatchResults.IntroEvents.EVENT_MODE_XP,Text:_loc7_,SoundTag:"MPMatchResultsEventXP"});
        }
        this.m_bProcessingIntroEvents = true;
        if(this.m_IntroEventList.length == 0)
        {
            this.IntroBackground._visible = false;
        }
        this.ProcessIntroEvents();
        this.RefreshContinueButton();
    }
    function ProcessIntroEvents()
    {
        if(this.m_IntroEventList.length > 0)
        {
            this.Intro.SetEventData(this.m_IntroEventList[this.m_IntroEventList.length - 1].ModeID,this.m_IntroEventList[this.m_IntroEventList.length - 1].Text,this.m_IntroEventList[this.m_IntroEventList.length - 1].OptionalParameter1,this.m_IntroEventList[this.m_IntroEventList.length - 1].OptionalParameter2);
            _global.SFX.PlayGUISound(this.m_IntroEventList[this.m_IntroEventList.length - 1].SoundTag);
            this.m_IntroEventList.pop();
            this.Intro.Start();
        }
        else
        {
            this.m_bProcessingIntroEvents = false;
            this.IntroBackground.gotoAndPlay(screens.MPMatchResults.MPMatchResults.INTRO_BACKGROUND_FADEOUT_FRAME);
            this.StartBarAnimations();
        }
        this.RefreshContinueButton();
    }
    function RefreshContinueButton()
    {
		// MILAN CHANGE DropTheSquid 1/8/2024
		// always run both of these instead of having it be based on platform
		this.PC_ContinueButton.SetText(!this.m_bProcessingIntroEvents ? this.srContinue : this.srSkip);
		this.ControllerButtons.ControlA.SetText(!this.m_bProcessingIntroEvents ? this.srContinue : this.srSkip);
		// END MILAN
    }
    function StartBarAnimations()
    {
        var _loc2_ = 0;
        while(_loc2_ < this.PlayerBarClips.length)
        {
            if(this.PlayerBarClips[_loc2_]._visible)
            {
                this.PlayerBarClips[_loc2_].StartXPBarAnimation();
            }
            _loc2_ = _loc2_ + 1;
        }
        this.TotalXPBar.StartBarAnimation();
    }
    function OnPlayerBarHovered(p_event)
    {
        var _loc2_ = 0;
        while(_loc2_ < this.PlayerBarClips.length)
        {
            if(this.PlayerBarClips[_loc2_]._visible && this.PlayerBarClips[_loc2_] != p_event.data && this.PlayerBarClips[_loc2_].GetHovered())
            {
                this.PlayerBarClips[_loc2_].SetHovered(false);
            }
            _loc2_ = _loc2_ + 1;
        }
    }
    function SetupTotalXPBar()
    {
        this.TotalXPBar = _root.TotalXPBar;
        this.TotalXPBar.addEventListener("onLevelUp",this.MakeDelegate(this.OnRewardBarLevelUp));
        var _loc3_ = Number(flash.external.ExternalInterface.call("GetOriginalExperience"));
        var _loc4_ = Number(flash.external.ExternalInterface.call("GetFinalExperience"));
        var _loc5_ = Number(flash.external.ExternalInterface.call("GetLevelFromXP",_loc3_));
        this.TotalXPBar.SetBarData(_loc3_,_loc4_);
        this.TotalXPBar.SetupRewardBar();
    }
    function OnPCContinueButtonRelease()
    {
        this.OnContinue();
    }
    function OnConsoleAButton()
    {
        this.OnContinue();
    }
    function OnConsoleYButton()
    {
        flash.external.ExternalInterface.call("ShowGamerCard",this.PlayerBarClips[this.m_CurrentFocusedPlayerBarIndex].PlayerDataIdx);
    }
    function OnContinue()
    {
        if(this.m_bProcessingIntroEvents)
        {
            this.Intro.StopEvent();
            this.m_bProcessingIntroEvents = false;
            this.IntroBackground.gotoAndPlay(screens.MPMatchResults.MPMatchResults.INTRO_BACKGROUND_FADEOUT_FRAME);
            this.StartBarAnimations();
        }
        else
        {
            flash.external.ExternalInterface.call("OnContinue");
        }
        this.RefreshContinueButton();
    }
    function OnInvalidInput()
    {
        _global.SFX.PlayGUIError();
    }
    function OnDPadUp()
    {
        if(this.m_CurrentFocusedField == screens.MPMatchResults.MPMatchResults.FOCUSED_FIELD_PLAYER_BARS)
        {
            if(this.m_CurrentFocusedPlayerBarIndex == 0)
            {
                _global.SFX.PlayGUIError();
                return undefined;
            }
            var _loc3_ = this.FindPrevVisiblePlayerBar(this.m_CurrentFocusedPlayerBarIndex - 1);
            if(_loc3_ >= 0)
            {
                this.PlayerBarClips[this.m_CurrentFocusedPlayerBarIndex].SetHovered(false);
                var _loc4_ = this.PlayerBarClips[this.m_CurrentFocusedPlayerBarIndex].GetHoveredMedalIndex();
                this.PlayerBarClips[this.m_CurrentFocusedPlayerBarIndex].ClearHoveredMedal();
                this.m_CurrentFocusedPlayerBarIndex = _loc3_;
                this.PlayerBarClips[this.m_CurrentFocusedPlayerBarIndex].SetHovered(true);
                this.PlayerBarClips[this.m_CurrentFocusedPlayerBarIndex].SetHoveredMedalIndex(_loc4_);
                _global.SFX.PlayGUISound("MPMatchResultsBarSelect");
            }
        }
        else
        {
            this.SquadMedals.ClearHoveredMedal();
            this.m_CurrentFocusedField = screens.MPMatchResults.MPMatchResults.FOCUSED_FIELD_PLAYER_BARS;
            _loc3_ = this.FindPrevVisiblePlayerBar(this.PlayerBarClips.length - 1);
            if(_loc3_ >= 0)
            {
                this.m_CurrentFocusedPlayerBarIndex = _loc3_;
                this.PlayerBarClips[this.m_CurrentFocusedPlayerBarIndex].SetHovered(true);
                this.PlayerBarClips[this.m_CurrentFocusedPlayerBarIndex].SetHoveredMedalIndex(0);
                _global.SFX.PlayGUISound("MPMatchResultsBarSelect");
            }
        }
    }
    function OnDPadDown()
    {
        if(this.m_CurrentFocusedField == screens.MPMatchResults.MPMatchResults.FOCUSED_FIELD_PLAYER_BARS)
        {
            var _loc3_ = this.FindNextVisiblePlayerBar(this.m_CurrentFocusedPlayerBarIndex + 1);
            if(_loc3_ >= 0)
            {
                this.PlayerBarClips[this.m_CurrentFocusedPlayerBarIndex].SetHovered(false);
                var _loc4_ = this.PlayerBarClips[this.m_CurrentFocusedPlayerBarIndex].GetHoveredMedalIndex();
                this.PlayerBarClips[this.m_CurrentFocusedPlayerBarIndex].ClearHoveredMedal();
                this.m_CurrentFocusedPlayerBarIndex = _loc3_;
                this.PlayerBarClips[this.m_CurrentFocusedPlayerBarIndex].SetHovered(true);
                this.PlayerBarClips[this.m_CurrentFocusedPlayerBarIndex].SetHoveredMedalIndex(_loc4_);
                _global.SFX.PlayGUISound("MPMatchResultsBarSelect");
            }
            else if(this.SquadMedals.GetNumMedals() > 0)
            {
                this.PlayerBarClips[this.m_CurrentFocusedPlayerBarIndex].SetHovered(false);
                this.PlayerBarClips[this.m_CurrentFocusedPlayerBarIndex].ClearHoveredMedal();
                this.m_CurrentFocusedField = screens.MPMatchResults.MPMatchResults.FOCUSED_FIELD_SQUAD_MEDALS;
                this.SquadMedals.SetHoveredMedalIndex(0);
                _global.SFX.PlayGUISound("MPMatchResultsBarSelect");
            }
            else
            {
                _global.SFX.PlayGUIError();
            }
        }
        else
        {
            _global.SFX.PlayGUIError();
        }
    }
    function FindPrevVisiblePlayerBar(nStartIndex)
    {
        if(nStartIndex < 0 || nStartIndex >= this.PlayerBarClips.length)
        {
            return -1;
        }
        var _loc2_ = nStartIndex;
        while(_loc2_ >= 0)
        {
            if(this.PlayerBarClips[_loc2_]._visible)
            {
                return _loc2_;
            }
            _loc2_ = _loc2_ - 1;
        }
        return -1;
    }
    function FindNextVisiblePlayerBar(nStartIndex)
    {
        if(nStartIndex < 0 || nStartIndex >= this.PlayerBarClips.length)
        {
            return -1;
        }
        var _loc2_ = nStartIndex;
        while(_loc2_ < this.PlayerBarClips.length)
        {
            if(this.PlayerBarClips[_loc2_]._visible)
            {
                return _loc2_;
            }
            _loc2_ = _loc2_ + 1;
        }
        return -1;
    }
    function OnDPadLeft()
    {
        if(this.m_CurrentFocusedField == screens.MPMatchResults.MPMatchResults.FOCUSED_FIELD_PLAYER_BARS)
        {
            this.PlayerBarClips[this.m_CurrentFocusedPlayerBarIndex].MoveHoveredMedalLeft();
        }
        else
        {
            this.SquadMedals.MoveHoverLeft();
        }
    }
    function OnDPadRight()
    {
        if(this.m_CurrentFocusedField == screens.MPMatchResults.MPMatchResults.FOCUSED_FIELD_PLAYER_BARS)
        {
            this.PlayerBarClips[this.m_CurrentFocusedPlayerBarIndex].MoveHoveredMedalRight();
        }
        else
        {
            this.SquadMedals.MoveHoverRight();
        }
    }
    function onKeyDown()
    {
        switch(Key.getCode())
        {
            case com.XInput.DPadUp:
                this.OnDPadUp();
                break;
            case com.XInput.DPadDown:
                this.OnDPadDown();
                break;
            case com.XInput.DPadLeft:
                this.OnDPadLeft();
                break;
            case com.XInput.DPadRight:
                this.OnDPadRight();
                break;
            default:
                _global.SFX.PlayGUIError();
        }
    }
    function OnRewardBarLevelUp(p_event)
    {
        var _loc2_ = p_event._Data;
        var _loc3_ = String(flash.external.ExternalInterface.call("GetLocalPlayerClassData",_loc2_));
        this.PlayerBarClips[this.m_LocalPlayerBarIndex].SetPlayerClassData(_loc3_);
    }
}
