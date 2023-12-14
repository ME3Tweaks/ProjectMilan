class screens.MPNewLobby.MPNewLobby extends com.SFXScreen
{
    var m_bConnected;
    var leftPage;
    var PreviouslySelectedItem;
    var m_ControllerLegend;
    var m_PCLegend;
    var ActionMappings;
    var m_ArrowLeft;
    var m_ArrowRight;
    var rightPage;
    var tabs;
    static var LSS_None = 0;
    static var LSS_SelectCharacter = 1;
    static var LSS_MissionSetup = 2;
    static var LSS_Character = 3;
    static var LSS_Weapons = 4;
    static var LSS_Store = 5;
    static var LSS_Leaderboards = 6;
    static var LSS_MatchResults = 7;
    static var LSS_MatchRewards = 8;
    static var LSS_Appearance = 9;
    static var LSS_MatchConsumables = 10;
    static var LSS_MultiplayerMenu = 11;
    static var LSS_Lobby = 12;
    static var LSS_Squad = 13;
    var srBack = "NOLOC:Back";
    var srSelect = "NOLOC:Select";
    var srCancel = "NOLOC:Cancel";
    var srReinforcements = "NOLOC:Reinforcements";
    var srInviteFriends = "NOLOC:Invite Friends";
    var srInviteParty = "NOLOC:Invite Xbox LIVE Party";
    var srExitLobby = "NOLOC:Exit Lobby";
    var srExitMultiplayer = "NOLOC:Exit Multiplayer";
    var srMultiplayerMenuTitle = "NOLOC:Multiplayer";
    var srMissionSetup = "NOLOC:Mission Setup";
    var srLobbyTitle = "NOLOC:Lobby";
    var srSquad = "NOLOC:Squad";
    var srCharacter = "NOLOC:Character";
    var srQuickMatch = "NOLOC:Quick Play";
    var srCustomMatch = "NOLOC:Custom Match";
    var srHostNewMission = "NOLOC:Host New Mission";
    var srLeaderboards = "NOLOC:Leaderboards";
    var srSwitchCharacter = "NOLOC:Change Character";
    var srTalentsLevelUp = "NOLOC:Talents/Level Up";
    var srWeapons = "NOLOC:Weapons";
    var srAppearance = "NOLOC:Appearance";
    var srMatchConsumables = "NOLOC:Mission Upgrades";
    var srTeam = "NOLOC:Team";
    var srMap = "NOLOC:Map";
    var srEnemy = "NOLOC:Enemy";
    var srChallenge = "NOLOC:Challenge";
    var srPublic = "NOLOC:Public";
    var srPrivate = "NOLOC:Private";
    var srKit = "NOLOC:Kit";
    var srMissionUpgrades = "NOLOC:Mission Upgrades";
    var srShowGamercard = "NOLOC:Show Gamercard";
    var srConfirm = "NOLOC:Confirm";
    var srLevelUp = "NOLOC:Level Up!";
    var srOptions = "NOLOC:Options";
    var srToggleReady = "NOLOC:Ready";
    var srUnavailable = "NOLOC:Unavailable";
    var srGalaxyAtWar = "NOLOC:Galaxy At War";
    var srNew = "NOLOC:New";
    var srShowPartySessions = "NOLOC:Show Xbox LIVE Party Sessions";
    var srVoteToKick = "NOLOC:Kick player";
    var srUnvoteToKick = "NOLOC:Don\'t kick player";
    var srLeader = "NOLOC:LEADER";
    var srEmpty = "NOLOC:empty";
    var srSearch = "NOLOC:Search";
    var srChatDisabled = "NOLOC:Chat Disabled";
    var srPublicSlot = "NOLOC:Public Slot";
    var srPrivateSlot = "NOLOC:Private Slot";
    var srViewInvitations = "NOLOC:View Invitations";
    var srGalaxyAtWarError = "NOLOC:System Offline - Unable to retrieve Galaxy At War Status";
    var srChallengeTracking = "NOLOC:Challenges";
    var PAGE_CHARACTER = "Character";
    var PAGE_CHARACTER_MENU = "Character Menu";
    var PAGE_LOBBY_MENU = "Lobby Menu";
    var PAGE_GALAXY_AT_WAR = "Galaxy At War";
    var PAGE_MISSION_SETUP = "Mission Setup";
    var PAGE_MULTIPLAYER_MENU = "Multiplayer Menu";
    var PAGE_SQUAD = "Squad";
    var SETTING_PRIVACY = 0;
    var SETTING_MAP = 1;
    var SETTING_ENEMY = 2;
    var SETTING_CHALLENGE = 3;
    var PC_ARROW_OFFSET = 40;
    var bIsHostingNewMission = false;
    var PAGE_TRANSITION_NONE = 0;
    var PAGE_TRANSITION_SLIDE_LEFT = 1;
    var PAGE_TRANSITION_SLIDE_RIGHT = 2;
    var m_PageTransitionType = screens.MPNewLobby.MPNewLobby.prototype.PAGE_TRANSITION_NONE;
    function MPNewLobby()
    {
        super();
    }
    function onLoad()
    {
        super.onLoad();
        this.m_bConnected = false;
        this.LoadStrings();
        this.SetupPageArrows();
        this.SetupButtonLegend();
        var _loc4_ = Number(flash.external.ExternalInterface.call("GetCurrentLobbyTab"));
        this.LoadTab(_loc4_);
        _root.gotoAndStop(2);
    }
    function LoadStrings()
    {
        this.srBack = "$" + _global.SFX.GetIniString("srBack");
        this.srSelect = "$" + _global.SFX.GetIniString("srSelect");
        this.srCancel = "$" + _global.SFX.GetIniString("srCancel");
        this.srReinforcements = "$" + _global.SFX.GetIniString("srReinforcements");
        this.srInviteFriends = "$" + _global.SFX.GetIniString("srInviteFriends");
        this.srInviteParty = "$" + _global.SFX.GetIniString("srInviteParty");
        this.srExitLobby = "$" + _global.SFX.GetIniString("srExitLobby");
        this.srExitMultiplayer = "$" + _global.SFX.GetIniString("srExitMultiplayer");
        this.srMultiplayerMenuTitle = "$" + _global.SFX.GetIniString("srMultiplayerMenuTitle");
        this.srMissionSetup = "$" + _global.SFX.GetIniString("srMissionSetup");
        this.srLobbyTitle = "$" + _global.SFX.GetIniString("srLobbyTitle");
        this.srSquad = "$" + _global.SFX.GetIniString("srSquad");
        this.srCharacter = "$" + _global.SFX.GetIniString("srCharacter");
        this.srQuickMatch = "$" + _global.SFX.GetIniString("srQuickMatch");
        this.srCustomMatch = "$" + _global.SFX.GetIniString("srCustomMatch");
        this.srHostNewMission = "$" + _global.SFX.GetIniString("srHostNewMission");
        this.srLeaderboards = "$" + _global.SFX.GetIniString("srLeaderboards");
        this.srSwitchCharacter = "$" + _global.SFX.GetIniString("srSwitchCharacter");
        this.srTalentsLevelUp = "$" + _global.SFX.GetIniString("srTalentsLevelUp");
        this.srWeapons = "$" + _global.SFX.GetIniString("srWeapons");
        this.srAppearance = "$" + _global.SFX.GetIniString("srAppearance");
        this.srMatchConsumables = "$" + _global.SFX.GetIniString("srMatchConsumables");
        this.srTeam = "$" + _global.SFX.GetIniString("srTeam");
        this.srMap = "$" + _global.SFX.GetIniString("srMap");
        this.srEnemy = "$" + _global.SFX.GetIniString("srEnemy");
        this.srChallenge = "$" + _global.SFX.GetIniString("srChallenge");
        this.srPublic = "$" + _global.SFX.GetIniString("srPublic");
        this.srPrivate = "$" + _global.SFX.GetIniString("srPrivate");
        this.srKit = "$" + _global.SFX.GetIniString("srKit");
        this.srMissionUpgrades = "$" + _global.SFX.GetIniString("srMissionUpgrades");
        this.srShowGamercard = "$" + _global.SFX.GetIniString("srShowGamercard");
        this.srConfirm = "$" + _global.SFX.GetIniString("srConfirm");
        this.srLevelUp = "$" + _global.SFX.GetIniString("srLevelUp");
        this.srOptions = "$" + _global.SFX.GetIniString("srOptions");
        this.srToggleReady = "$" + _global.SFX.GetIniString("srToggleReady");
        this.srUnavailable = "$" + _global.SFX.GetIniString("srUnavailable");
        this.srGalaxyAtWar = "$" + _global.SFX.GetIniString("srGalaxyAtWar");
        this.srNew = "$" + _global.SFX.GetIniString("srNew");
        this.srShowPartySessions = "$" + _global.SFX.GetIniString("srShowPartySessions");
        this.srVoteToKick = "$" + _global.SFX.GetIniString("srVoteToKick");
        this.srUnvoteToKick = "$" + _global.SFX.GetIniString("srUnvoteToKick");
        this.srLeader = "$" + _global.SFX.GetIniString("srLeader");
        this.srEmpty = "$" + _global.SFX.GetIniString("srEmpty");
        this.srSearch = "$" + _global.SFX.GetIniString("srSearch");
        this.srChatDisabled = "$" + _global.SFX.GetIniString("srChatDisabled");
        this.srPublicSlot = "$" + _global.SFX.GetIniString("srPublicSlot");
        this.srPrivateSlot = "$" + _global.SFX.GetIniString("srPrivateSlot");
        this.srViewInvitations = "$" + _global.SFX.GetIniString("srViewInvitations");
        this.srGalaxyAtWarError = "$" + _global.SFX.GetIniString("srGalaxyAtWarError");
        this.srChallengeTracking = "$" + _global.SFX.GetIniString("srChallengeTracking");
    }
    function SetInitialSelectedItem()
    {
        var _loc2_ = this.leftPage.contents.list;
        if(!_loc2_.IsIndexValid(this.PreviouslySelectedItem))
        {
            this.PreviouslySelectedItem = 0;
        }
        _loc2_.selectedIndex = this.PreviouslySelectedItem;
    }
    function SetupButtonLegend()
    {
        this.m_ControllerLegend = _root.mcControllerButtons;
        this.m_PCLegend = _root.PCController;
        if(_global.SFX.Platform == com.XPlatform.PC)
        {
            _root.m_ControlY._visible = false;
            this.m_ControllerLegend._visible = false;
            _root.PCBtnCharacter._visible = true;
            _root.PCBtnCharacter.enabled = true;
            this.m_PCLegend._visible = true;
            this.m_PCLegend.enabled = true;
            _root.PCBtnCharacter.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.onButtonY));
            this.m_PCLegend.PCBtnLeft.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.onButtonY));
            this.m_PCLegend.PCBtnMid1.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.onButtonX));
            this.m_PCLegend.PCBtnMid2.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.onButtonA));
            this.m_PCLegend.PCBtnRight.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.onButtonB));
        }
        else
        {
            _root.PCBtnCharacter._visible = false;
            _root.PCBtnCharacter.enabled = false;
            this.m_PCLegend._visible = false;
            this.m_PCLegend.enabled = false;
            _root.m_ControlY._visible = true;
            this.m_ControllerLegend._visible = true;
            this.m_ControllerLegend.addEventListener("onButtonA",mx.utils.Delegate.create(this,this.onButtonA));
            this.m_ControllerLegend.addEventListener("onButtonB",mx.utils.Delegate.create(this,this.onButtonB));
            this.m_ControllerLegend.addEventListener("onButtonX",mx.utils.Delegate.create(this,this.onButtonX));
            this.m_ControllerLegend.addEventListener("onDPadUp",mx.utils.Delegate.create(this,this.onDPadUp));
            this.m_ControllerLegend.addEventListener("onDPadDown",mx.utils.Delegate.create(this,this.onDPadDown));
            this.m_ControllerLegend.addEventListener("onDPadLeft",mx.utils.Delegate.create(this,this.onDPadLeft));
            this.m_ControllerLegend.addEventListener("onDPadRight",mx.utils.Delegate.create(this,this.onDPadRight));
            this.m_ControllerLegend.addEventListener("onInvalidInput",mx.utils.Delegate.create(this,this.onInvalidInput));
            Key.addListener(this);
        }
        this.ActionMappings = new Object();
    }
    function onKeyUp()
    {
        if(_root.screen.m_ControllerLegend.InputDisabled)
        {
            return undefined;
        }
        if(Key.getCode() == com.XInput.ButtonY)
        {
            this.onButtonY();
        }
    }
    function SetupPageArrows()
    {
        this.m_ArrowLeft = _root.ArrowLeft;
        this.m_ArrowRight = _root.ArrowRight;
        if(_global.SFX.Platform == com.XPlatform.PC)
        {
            this.m_ArrowLeft.contents._x -= this.PC_ARROW_OFFSET;
            this.m_ArrowRight.contents._x += this.PC_ARROW_OFFSET;
            this.m_ArrowLeft.addEventListener("ArrowPressed",this.MakeDelegate(this.HideSquadScreen));
        }
        else
        {
            this.m_ArrowLeft.ShowStickIcon(true);
            this.m_ArrowRight.ShowStickIcon(true);
        }
    }
    function MakeLoadTabDelegate(subscreen)
    {
        return function()
        {
            _root.screen.LoadTab(subscreen);
        };
    }
    function LoadTab(subscreen)
    {
        flash.external.ExternalInterface.call("LoadTab",subscreen);
    }
    function OnTabLoaded(subscreen)
    {
        this.PreviouslySelectedItem = Number(flash.external.ExternalInterface.call("GetPreviouslySelectedItem",subscreen));
        this.m_bConnected = Boolean(flash.external.ExternalInterface.call("IsMPGame"));
        if(subscreen == screens.MPNewLobby.MPNewLobby.LSS_MultiplayerMenu)
        {
            this.SetTitle(this.srMultiplayerMenuTitle);
            this.LoadPage(this.leftPage,this.PAGE_MULTIPLAYER_MENU);
            this.LoadPage(this.rightPage,this.PAGE_GALAXY_AT_WAR);
        }
        else if(subscreen == screens.MPNewLobby.MPNewLobby.LSS_Character)
        {
            this.SetTitle(this.srCharacter);
            this.LoadPage(this.leftPage,this.PAGE_CHARACTER_MENU);
            this.LoadPage(this.rightPage,this.PAGE_CHARACTER);
        }
        else if(subscreen == screens.MPNewLobby.MPNewLobby.LSS_MissionSetup)
        {
            this.SetTitle(this.GetMissionSettingsTabTitle());
            this.LoadPage(this.leftPage,this.PAGE_MISSION_SETUP);
            this.LoadPage(this.rightPage,this.PAGE_GALAXY_AT_WAR);
        }
        else if(subscreen == screens.MPNewLobby.MPNewLobby.LSS_Lobby)
        {
            this.SetTitle(this.srLobbyTitle);
            this.LoadPage(this.leftPage,this.PAGE_LOBBY_MENU);
            this.LoadPage(this.rightPage,this.PAGE_SQUAD);
        }
        else if(subscreen == screens.MPNewLobby.MPNewLobby.LSS_Squad)
        {
            this.SetTitle(this.srSquad);
            this.LoadPage(this.leftPage,this.PAGE_SQUAD);
            this.LoadPage(this.rightPage,this.PAGE_CHARACTER);
        }
        if(this.m_PageTransitionType != this.PAGE_TRANSITION_NONE)
        {
            this.StartPageTransition();
        }
    }
    function SetTitle(sTitle)
    {
        this.tabs.mainTab.title.textAutoSize = "shrink";
        this.tabs.mainTab.title.text = sTitle;
    }
    function StartPageTransition()
    {
        if(this.m_PageTransitionType == this.PAGE_TRANSITION_SLIDE_LEFT)
        {
            this.leftPage._x = 162;
            this.rightPage._x = this.leftPage._x + 590;
        }
        else if(this.m_PageTransitionType == this.PAGE_TRANSITION_SLIDE_RIGHT)
        {
            this.leftPage._x = -38;
            this.rightPage._x = this.leftPage._x + 590;
        }
        this.m_PageTransitionType = this.PAGE_TRANSITION_NONE;
        com.TweenManager.createTween(0,this.leftPage,62,this.leftPage._y,0,0,16,5,"dec");
        com.TweenManager.createTween(1,this.rightPage,652,this.rightPage._y,0,0,16,5,"dec");
        com.TweenManager.createAlphaTween(2,this.leftPage,30,100,16,10);
        com.TweenManager.createAlphaTween(3,this.rightPage,30,100,16,10);
    }
    function LoadPage(pageSlot, sSymbolName)
    {
        if(pageSlot.contents != null)
        {
            pageSlot.contents.removeMovieClip();
        }
        if(sSymbolName != null)
        {
            pageSlot.attachMovie(sSymbolName,"contents",this.leftPage.getNextHighestDepth(),{m_symbolName:sSymbolName});
        }
    }
    function RefreshPage(page, sSymbolName)
    {
        var _loc4_ = Number(flash.external.ExternalInterface.call("GetCurrentLobbyTab"));
        this.PreviouslySelectedItem = Number(flash.external.ExternalInterface.call("GetPreviouslySelectedItem",_loc4_));
        var _loc5_ = page.list;
        var _loc6_ = undefined;
        if(sSymbolName == this.PAGE_MULTIPLAYER_MENU)
        {
            var _loc7_ = Boolean(flash.external.ExternalInterface.call("CanAffordNewStoreItems"));
            var _loc8_ = Boolean(flash.external.ExternalInterface.call("IsChallengeSystemEnabled"));
            if(!_loc8_)
            {
                _loc5_.gotoAndStop("nochallenges");
            }
            _loc5_.item1.contents.title.text = this.srQuickMatch;
            _loc5_.item1.action = this.CustomMatch;
            _loc5_.item2.contents.title.text = this.srHostNewMission;
            _loc5_.item2.action = this.HostNewMission;
            _loc5_.item3.contents.title.text = this.srCharacter;
            _loc5_.item3.action = this.MakeDelegate(this.ShowCharacterScreen);
            _loc5_.item4.contents.title.text = this.srLeaderboards;
            _loc5_.item4.action = this.ShowLeaderboardScreen;
            _loc5_.item5.contents.title.text = this.srReinforcements;
            _loc5_.item5.action = this.ShowStoreScreen;
            _loc5_.item5.SetAlert(_loc7_,this.srNew);
            if(_loc8_)
            {
                _loc5_.item6.contents.title.text = this.srChallengeTracking;
                _loc5_.item6.action = this.MakeDelegate(this.ShowMPChallengeScreen);
            }
            this.RefreshPlayerInfo(page,false);
        }
        else if(sSymbolName == this.PAGE_CHARACTER)
        {
            this.RefreshCharacterSummary();
        }
        else if(sSymbolName == this.PAGE_MISSION_SETUP)
        {
            var _loc9_ = flash.external.ExternalInterface.call("GetMatchSettings");
            var _loc10_ = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetMapList"));
            var _loc11_ = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetPrivacyTypes"));
            var _loc12_ = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetEnemyTypes"));
            var _loc13_ = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetChallengeTypes"));
            this.bIsHostingNewMission = Boolean(flash.external.ExternalInterface.call("IsHostingNewMission"));
            var _loc14_ = com.SFXScreen.IsMPClient;
            if(this.m_bConnected)
            {
                _loc5_.item1.Initialize(this.srTeam,_loc11_,_loc9_.privacy,!_loc14_);
            }
            else if(this.bIsHostingNewMission)
            {
                _loc5_.item1.Initialize(this.srTeam,_loc11_,_loc9_.privacy,!_loc14_);
            }
            else
            {
                _loc10_ = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetMapListForSearching"));
                _loc12_ = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetEnemyTypesForSearching"));
                _loc13_ = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetChallengeTypesForSearching"));
                _loc5_.item1.Initialize(this.srTeam,_loc11_,0,false);
            }
            _loc5_.item1.Refresh();
            if(_loc9_.bRandomMap)
            {
                _loc5_.item2.Initialize(this.srMap,_loc10_,0,!_loc14_);
            }
            else
            {
                _loc5_.item2.Initialize(this.srMap,_loc10_,_loc9_.MapId,!_loc14_);
            }
            _loc5_.item2.Refresh();
            if(_loc9_.bRandomEnemy)
            {
                _loc5_.item3.Initialize(this.srEnemy,_loc12_,0,!_loc14_);
            }
            else
            {
                _loc5_.item3.Initialize(this.srEnemy,_loc12_,_loc9_.Enemy,!_loc14_);
            }
            _loc5_.item3.Refresh();
            _loc5_.item4.Initialize(this.srChallenge,_loc13_,_loc9_.Challenge,!_loc14_);
            _loc5_.item4.Refresh();
        }
        else if(sSymbolName == this.PAGE_SQUAD)
        {
            var _loc15_ = _loc4_ == screens.MPNewLobby.MPNewLobby.LSS_Squad;
            this.RefreshPlayerList(screens.MPNewLobby.PlayerList(_loc5_),_loc15_);
        }
        else if(sSymbolName == this.PAGE_CHARACTER_MENU)
        {
            var _loc16_ = Boolean(flash.external.ExternalInterface.call("CanLevelUp"));
            var _loc17_ = Boolean(flash.external.ExternalInterface.call("HasNewWeapons"));
            var _loc18_ = Boolean(flash.external.ExternalInterface.call("HasNewAppearanceOptions"));
            var _loc19_ = Boolean(flash.external.ExternalInterface.call("HasNewMatchConsumables"));
            _loc7_ = Boolean(flash.external.ExternalInterface.call("CanAffordNewStoreItems"));
            _loc5_.item1.contents.title.text = this.srTalentsLevelUp;
            _loc5_.item1.action = this.ShowTalentsLevelUpScreen;
            _loc5_.item1.SetLevelUpIcon(_loc16_);
            _loc5_.item2.contents.title.text = this.srWeapons;
            _loc5_.item2.action = this.ShowWeaponsScreen;
            _loc5_.item2.SetAlert(_loc17_,this.srNew);
            _loc5_.item3.contents.title.text = this.srAppearance;
            _loc5_.item3.action = this.ShowAppearanceScreen;
            _loc5_.item3.SetAlert(_loc18_,this.srNew);
            _loc5_.item4.contents.title.text = this.srMatchConsumables;
            _loc5_.item4.action = this.ShowMatchConsumablesScreen;
            _loc5_.item4.SetAlert(_loc19_,this.srNew);
            _loc5_.item5.contents.title.text = this.srReinforcements;
            _loc5_.item5.action = this.ShowStoreScreen;
            _loc5_.item5.SetAlert(_loc7_,this.srNew);
            this.RefreshPlayerInfo(page,true);
        }
        else if(sSymbolName == this.PAGE_LOBBY_MENU)
        {
            _loc16_ = Boolean(flash.external.ExternalInterface.call("CanLevelUp"));
            _loc17_ = Boolean(flash.external.ExternalInterface.call("HasNewWeapons"));
            _loc18_ = Boolean(flash.external.ExternalInterface.call("HasNewAppearanceOptions"));
            _loc19_ = Boolean(flash.external.ExternalInterface.call("HasNewMatchConsumables"));
            _loc7_ = Boolean(flash.external.ExternalInterface.call("CanAffordNewStoreItems"));
            _loc5_.item1.contents.title.text = this.srToggleReady;
            _loc5_.item1.action = this.ToggleReady;
            _loc5_.item1._visible = this.m_bConnected;
            _loc5_.item2.contents.title.text = this.srMissionSetup;
            _loc5_.item2.action = this.ShowMissionSetupScreen;
            _loc5_.item2._visible = this.m_bConnected;
            _loc5_.item3.contents.title.text = this.srTalentsLevelUp;
            _loc5_.item3.action = this.ShowTalentsLevelUpScreen;
            _loc5_.item3.SetLevelUpIcon(_loc16_);
            _loc5_.item4.contents.title.text = this.srWeapons;
            _loc5_.item4.action = this.ShowWeaponsScreen;
            _loc5_.item4.SetAlert(_loc17_,this.srNew);
            _loc5_.item5.contents.title.text = this.srAppearance;
            _loc5_.item5.action = this.ShowAppearanceScreen;
            _loc5_.item5.SetAlert(_loc18_,this.srNew);
            _loc5_.item6.contents.title.text = this.srMatchConsumables;
            _loc5_.item6.action = this.ShowMatchConsumablesScreen;
            _loc5_.item6.SetAlert(_loc19_,this.srNew);
            _loc5_.item7.contents.title.text = this.srReinforcements;
            _loc5_.item7.action = this.ShowStoreScreen;
            _loc5_.item7.SetAlert(_loc7_,this.srNew);
            this.RefreshPlayerInfo(page,true);
        }
        else if(sSymbolName == this.PAGE_GALAXY_AT_WAR)
        {
            this.RefreshGalaxyAtWarMap();
        }
        if(page._parent == this.leftPage)
        {
            this.SetInitialSelectedItem();
            this.RefreshButtonLegend();
            var _loc20_ = Boolean(flash.external.ExternalInterface.call("ShouldShowChatDisabledMessage"));
            page.chatDisabled.text = this.srChatDisabled;
            page.chatDisabled._visible = _loc20_ && sSymbolName == this.PAGE_LOBBY_MENU;
        }
        this.RefreshPageArrows();
    }
    function RefreshPageArrows()
    {
        this.m_ArrowLeft._visible = false;
        this.m_ArrowRight._visible = false;
        if(this.leftPage.contents.m_symbolName == this.PAGE_LOBBY_MENU && _global.SFX.Platform != com.XPlatform.PC)
        {
            this.m_ArrowRight._visible = true;
        }
        else if(this.leftPage.contents.m_symbolName == this.PAGE_SQUAD)
        {
            this.m_ArrowLeft._visible = true;
        }
    }
    function RefreshGalaxyAtWarMap()
    {
        if(_global.SFX.IsDemo)
        {
            this.rightPage.contents.title.text = "";
        }
        else
        {
            this.rightPage.contents.title.text = this.srGalaxyAtWar;
        }
        var _loc3_ = this.rightPage.contents.map;
        var _loc4_ = Boolean(flash.external.ExternalInterface.call("HasGAWRatingsError"));
        _loc3_.SetErrorText(_loc4_,this.srGalaxyAtWarError);
        this.RefreshGalaxyAtWarRatings();
        this.RefreshGalaxyAtWarMapPositionMarker();
    }
    function RefreshGalaxyAtWarRatings()
    {
        if(this.rightPage.contents.m_symbolName == this.PAGE_GALAXY_AT_WAR)
        {
            var _loc3_ = this.rightPage.contents.map;
            var _loc4_ = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetGAWRatings"));
            var _loc5_ = 0;
            while(_loc5_ < _loc4_.length)
            {
                _loc3_.SetZoneText(_loc4_[_loc5_].ZoneID,_loc4_[_loc5_].ZoneName);
                _loc3_.SetZoneReadiness(_loc4_[_loc5_].ZoneID,_loc4_[_loc5_].CurrentRating);
                _loc5_ += 1;
            }
            if(_global.SFX.IsDemo)
            {
                _loc3_.SetPercentagesVisible(false);
            }
        }
    }
    function RefreshGalaxyAtWarMapPositionMarker()
    {
        var _loc2_ = this.rightPage.contents.map;
        if(this.leftPage.contents.m_symbolName == this.PAGE_MISSION_SETUP && this.rightPage.contents.m_symbolName == this.PAGE_GALAXY_AT_WAR)
        {
            var _loc3_ = flash.external.ExternalInterface.call("GetMapInfo",this.GetMapSetting());
            var _loc4_ = Number(flash.external.ExternalInterface.call("GetMapZoneID",_loc3_.PackageName));
            this.rightPage.contents.GAWBonusText.textAutoSize = "shrink";
            this.rightPage.contents.GAWBonusText.text = String(flash.external.ExternalInterface.call("GetGAWZoneBonusText",this.GetMapSetting()));
            if(_loc3_.Id > 0 && _loc3_.GalaxyAtWarMapSubtitle != 0)
            {
                _loc2_.SetTextFieldTransparancy(30);
                _loc2_.SetZoneTextFieldTransparency(_loc4_,100);
                _loc2_.SetPositionalMarker(true,"","",_loc3_.GalaxyAtWarMapPosition.X,_loc3_.GalaxyAtWarMapPosition.Y);
                _loc2_.SelectZone(_loc4_);
            }
            else
            {
                _loc2_.SetTextFieldTransparancy(100);
                _loc2_.SetPositionalMarker(false,"","",0,0);
                _loc2_.UnselectCurrentZone();
            }
        }
        else
        {
            _loc2_.SetTextFieldTransparancy(100);
            _loc2_.SetPositionalMarker(false,"","",0,0);
            _loc2_.UnselectCurrentZone();
            this.rightPage.contents.GAWBonusText.text = "";
        }
    }
    function onListItemSelected(list)
    {
        if(this.leftPage.contents.list != list)
        {
            this.leftPage.contents.list.selectedIndex = -1;
        }
        if(this.rightPage.contents.list != list)
        {
            this.rightPage.contents.list.selectedIndex = -1;
        }
        if(this.leftPage.contents.m_symbolName == this.PAGE_SQUAD)
        {
            this.RefreshCharacterSummary();
        }
        this.RefreshButtonLegend();
    }
    function RefreshCharacterSummary()
    {
        var _loc2_ = this.rightPage.contents.summary;
        if(_loc2_ != null)
        {
            _loc2_.Refresh();
        }
    }
    function RefreshScreen()
    {
        this.RefreshPage(this.leftPage.contents,this.leftPage.contents.m_symbolName);
        this.RefreshPage(this.rightPage.contents,this.rightPage.contents.m_symbolName);
    }
    function RefreshButtonLegend()
    {
        var _loc2_ = Number(flash.external.ExternalInterface.call("GetCurrentLobbyTab"));
        if(_loc2_ == screens.MPNewLobby.MPNewLobby.LSS_MultiplayerMenu)
        {
            this.RefreshButtonLegend_MultiplayerMenu();
        }
        else if(_loc2_ == screens.MPNewLobby.MPNewLobby.LSS_Character)
        {
            this.RefreshButtonLegend_Character();
        }
        else if(_loc2_ == screens.MPNewLobby.MPNewLobby.LSS_MissionSetup)
        {
            this.RefreshButtonLegend_MissionSetup();
        }
        else if(_loc2_ == screens.MPNewLobby.MPNewLobby.LSS_Lobby)
        {
            this.RefreshButtonLegend_Lobby();
        }
        else if(_loc2_ == screens.MPNewLobby.MPNewLobby.LSS_Squad)
        {
            this.RefreshButtonLegend_Squad();
        }
        this.m_ControllerLegend.FitLeft();
    }
    function RefreshButtonLegend_MultiplayerMenu()
    {
        var _loc4_ = Boolean(flash.external.ExternalInterface.call("CanInteract"));
        var _loc5_ = Boolean(flash.external.ExternalInterface.call("IsInParty"));
        var _loc6_ = Boolean(flash.external.ExternalInterface.call("CameFromSelectFirstCharacter"));
        if(_global.SFX.Platform == com.XPlatform.PC)
        {
            this.RefreshButton(_root.PCBtnCharacter,com.XInput.ButtonY,this.srSwitchCharacter,this.SwitchCharacter,_loc4_);
            this.RefreshButton(this.m_PCLegend.PCBtnLeft,0,"",undefined,false);
            this.RefreshButton(this.m_PCLegend.PCBtnMid1,com.XInput.ButtonX,"",undefined,false);
            this.RefreshButton(this.m_PCLegend.PCBtnMid2,com.XInput.ButtonA,this.srOptions,this.ShowOptionsScreen,_loc4_);
            if(_loc6_)
            {
                this.RefreshButton(this.m_PCLegend.PCBtnRight,com.XInput.ButtonB,this.srBack,this.GoBackToSelectFirstCharacter,_loc4_);
            }
            else
            {
                this.RefreshButton(this.m_PCLegend.PCBtnRight,com.XInput.ButtonB,this.srExitMultiplayer,this.ExitMultiplayer,_loc4_);
            }
        }
        else
        {
            this.RefreshButton(_root.m_ControlY,com.XInput.ButtonY,this.srSwitchCharacter,this.SwitchCharacter,_loc4_);
            this.RefreshButton(this.m_ControllerLegend.ControlY,0,"",undefined,false);
            if(_global.SFX.Platform == com.XPlatform.XBox)
            {
                this.RefreshButton(this.m_ControllerLegend.ControlX,com.XInput.ButtonX,this.srOptions,this.ShowOptionsScreen,_loc4_);
            }
            else if(_global.SFX.Platform == com.XPlatform.PS3)
            {
                this.RefreshButton(this.m_ControllerLegend.ControlX,com.XInput.ButtonX,this.srViewInvitations,this.ViewInvitations,_loc4_);
            }
            this.RefreshButton(this.m_ControllerLegend.ControlA,com.XInput.ButtonA,this.srSelect,this.ActivateCurrentListItem,_loc4_);
            if(_loc6_)
            {
                this.RefreshButton(this.m_ControllerLegend.ControlB,com.XInput.ButtonB,this.srBack,this.GoBackToSelectFirstCharacter,_loc4_);
            }
            else
            {
                this.RefreshButton(this.m_ControllerLegend.ControlB,com.XInput.ButtonB,this.srExitMultiplayer,this.ExitMultiplayer,_loc4_);
            }
        }
    }
    function RefreshButtonLegend_Character()
    {
        var _loc4_ = Boolean(flash.external.ExternalInterface.call("CanInteract"));
        var _loc5_ = Boolean(flash.external.ExternalInterface.call("IsInParty"));
        if(_global.SFX.Platform == com.XPlatform.PC)
        {
            this.RefreshButton(_root.PCBtnCharacter,com.XInput.ButtonY,this.srSwitchCharacter,this.SwitchCharacter,_loc4_);
            this.RefreshButton(this.m_PCLegend.PCBtnLeft,0,"",undefined,false);
            this.RefreshButton(this.m_PCLegend.PCBtnMid1,com.XInput.ButtonX,"",undefined,false);
            this.RefreshButton(this.m_PCLegend.PCBtnMid2,com.XInput.ButtonA,this.srOptions,this.ShowOptionsScreen,_loc4_);
            this.RefreshButton(this.m_PCLegend.PCBtnRight,com.XInput.ButtonB,this.srBack,this.MakeDelegate(this.HideCharacterScreen),_loc4_);
        }
        else
        {
            this.RefreshButton(_root.m_ControlY,com.XInput.ButtonY,this.srSwitchCharacter,this.SwitchCharacter,_loc4_);
            this.RefreshButton(this.m_ControllerLegend.ControlY,0,"",undefined,false);
            if(_global.SFX.Platform == com.XPlatform.XBox)
            {
                this.RefreshButton(this.m_ControllerLegend.ControlX,com.XInput.ButtonX,this.srOptions,this.ShowOptionsScreen,_loc4_);
            }
            else
            {
                this.RefreshButton(this.m_ControllerLegend.ControlX,com.XInput.ButtonX,"",undefined,false);
            }
            this.RefreshButton(this.m_ControllerLegend.ControlA,com.XInput.ButtonA,this.srSelect,this.ActivateCurrentListItem,_loc4_);
            this.RefreshButton(this.m_ControllerLegend.ControlB,com.XInput.ButtonB,this.srBack,this.MakeDelegate(this.HideCharacterScreen),_loc4_);
        }
    }
    function RefreshButtonLegend_Lobby()
    {
        var _loc4_ = Boolean(flash.external.ExternalInterface.call("CanInteract"));
        var _loc5_ = Boolean(flash.external.ExternalInterface.call("IsInParty"));
        if(_global.SFX.Platform == com.XPlatform.PC)
        {
            this.RefreshButton(_root.PCBtnCharacter,com.XInput.ButtonY,this.srSwitchCharacter,this.SwitchCharacter,_loc4_);
            this.RefreshButton(this.m_PCLegend.PCBtnLeft,0,"",undefined,false);
            this.RefreshButton(this.m_PCLegend.PCBtnMid1,com.XInput.ButtonX,this.srOptions,this.ShowOptionsScreen,_loc4_);
            if(_loc5_)
            {
                this.RefreshButton(this.m_PCLegend.PCBtnMid2,com.XInput.ButtonA,this.srInviteParty,this.InviteParty,_loc4_ && !this.IsGameFull());
            }
            else
            {
                this.RefreshButton(this.m_PCLegend.PCBtnMid2,com.XInput.ButtonA,this.srInviteFriends,this.InviteFriends,_loc4_ && !this.IsGameFull());
            }
            this.RefreshButton(this.m_PCLegend.PCBtnRight,com.XInput.ButtonB,this.srExitLobby,this.ExitLobby,_loc4_);
        }
        else
        {
            this.RefreshButton(_root.m_ControlY,com.XInput.ButtonY,this.srSwitchCharacter,this.SwitchCharacter,_loc4_);
            this.RefreshButton(this.m_ControllerLegend.ControlY,0,"",undefined,false);
            if(_loc5_)
            {
                this.RefreshButton(this.m_ControllerLegend.ControlX,com.XInput.ButtonX,this.srInviteParty,this.InviteParty,_loc4_ && !this.IsGameFull());
            }
            else
            {
                this.RefreshButton(this.m_ControllerLegend.ControlX,com.XInput.ButtonX,this.srInviteFriends,this.InviteFriends,_loc4_ && !this.IsGameFull());
            }
            this.RefreshButton(this.m_ControllerLegend.ControlA,com.XInput.ButtonA,this.srSelect,this.ActivateCurrentListItem,_loc4_);
            this.RefreshButton(this.m_ControllerLegend.ControlB,com.XInput.ButtonB,this.srExitLobby,this.ExitLobby,_loc4_);
        }
    }
    function RefreshButtonLegend_Squad()
    {
        var _loc4_ = Boolean(flash.external.ExternalInterface.call("CanInteract"));
        var _loc5_ = Boolean(flash.external.ExternalInterface.call("IsInParty"));
        if(_global.SFX.Platform == com.XPlatform.PC)
        {
            this.RefreshButton(_root.PCBtnCharacter,0,"",undefined,false);
            var _loc6_ = screens.MPNewLobby.PlayerItem(this.leftPage.contents.list.selectedItem);
            if(_loc6_.isOccupied && !_loc6_.isLocalPlayer)
            {
                var _loc7_ = Boolean(flash.external.ExternalInterface.call("HasVotedToKickPlayerInSlot",this.leftPage.contents.list.selectedIndex));
                this.RefreshButton(this.m_PCLegend.PCBtnLeft,com.XInput.ButtonY,!_loc7_ ? this.srVoteToKick : this.srUnvoteToKick,this.ToggleVoteToKickSelectedPlayer,_loc4_);
            }
            else
            {
                this.RefreshButton(this.m_PCLegend.PCBtnLeft,com.XInput.ButtonY,this.srVoteToKick,this.ToggleVoteToKickSelectedPlayer,false);
            }
            this.RefreshButton(this.m_PCLegend.PCBtnMid1,com.XInput.ButtonX,this.srOptions,this.ShowOptionsScreen,_loc4_);
            if(_loc5_)
            {
                this.RefreshButton(this.m_PCLegend.PCBtnMid2,com.XInput.ButtonA,this.srInviteParty,this.InviteParty,_loc4_ && !this.IsGameFull());
            }
            else
            {
                this.RefreshButton(this.m_PCLegend.PCBtnMid2,com.XInput.ButtonA,this.srInviteFriends,this.InviteFriends,_loc4_ && !this.IsGameFull());
            }
            this.RefreshButton(this.m_PCLegend.PCBtnRight,com.XInput.ButtonB,this.srBack,this.MakeDelegate(this.HideSquadScreen),_loc4_);
        }
        else
        {
            this.RefreshButton(_root.m_ControlY,0,"",undefined,false);
            _loc6_ = screens.MPNewLobby.PlayerItem(this.leftPage.contents.list.selectedItem);
            if(_loc6_.isOccupied && !_loc6_.isLocalPlayer)
            {
                _loc7_ = Boolean(flash.external.ExternalInterface.call("HasVotedToKickPlayerInSlot",this.leftPage.contents.list.selectedIndex));
                this.RefreshButton(this.m_ControllerLegend.ControlY,com.XInput.ButtonY,!_loc7_ ? this.srVoteToKick : this.srUnvoteToKick,this.ToggleVoteToKickSelectedPlayer,_loc4_);
            }
            else
            {
                this.RefreshButton(this.m_ControllerLegend.ControlY,com.XInput.ButtonY,this.srVoteToKick,this.ToggleVoteToKickSelectedPlayer,false);
            }
            if(_loc5_)
            {
                this.RefreshButton(this.m_ControllerLegend.ControlX,com.XInput.ButtonX,this.srInviteParty,this.InviteParty,_loc4_ && !this.IsGameFull());
            }
            else
            {
                this.RefreshButton(this.m_ControllerLegend.ControlX,com.XInput.ButtonX,this.srInviteFriends,this.InviteFriends,_loc4_ && !this.IsGameFull());
            }
            if(_global.SFX.Platform == com.XPlatform.PC)
            {
                this.RefreshButton(this.m_ControllerLegend.ControlA,com.XInput.ButtonA,this.srShowGamercard,this.ShowGamercard,_loc4_ && _loc6_.isOccupied);
            }
            else
            {
                this.RefreshButton(this.m_ControllerLegend.ControlA,com.XInput.ButtonA,"",undefined,false);
            }
            this.RefreshButton(this.m_ControllerLegend.ControlB,com.XInput.ButtonB,this.srBack,this.MakeDelegate(this.HideSquadScreen),_loc4_);
            this.m_ControllerLegend.ControlB.SetVisible(false);
        }
    }
    function RefreshButtonLegend_MissionSetup()
    {
        var _loc4_ = Boolean(flash.external.ExternalInterface.call("CanInteract"));
        var _loc5_ = Boolean(flash.external.ExternalInterface.call("IsInParty"));
        var _loc6_ = com.SFXScreen.IsMPClient == false;
        var _loc7_ = Boolean(flash.external.ExternalInterface.call("IsHostingNewMission"));
        if(this.m_bConnected)
        {
            if(_global.SFX.Platform == com.XPlatform.PC)
            {
                this.RefreshButton(_root.PCBtnCharacter,0,"",undefined,false);
                this.RefreshButton(this.m_PCLegend.PCBtnLeft,com.XInput.ButtonY,"",undefined,false);
                this.RefreshButton(this.m_PCLegend.PCBtnMid1,com.XInput.ButtonX,this.srOptions,this.ShowOptionsScreen,_loc4_);
                if(_loc5_)
                {
                    this.RefreshButton(this.m_PCLegend.PCBtnMid2,com.XInput.ButtonA,this.srInviteParty,this.InviteParty,_loc4_ && !this.IsGameFull());
                }
                else
                {
                    this.RefreshButton(this.m_PCLegend.PCBtnMid2,com.XInput.ButtonA,this.srInviteFriends,this.InviteFriends,_loc4_ && !this.IsGameFull());
                }
                var _loc8_ = this.leftPage.contents.list.getItem(this.SETTING_MAP);
                if(_loc8_.IsValueAvailable(_loc8_.GetActiveValue()))
                {
                    this.RefreshButton(this.m_PCLegend.PCBtnRight,com.XInput.ButtonB,this.srBack,!_loc6_ ? this.CancelMatchSettings : this.ConfirmMatchSettings,_loc4_);
                }
                else
                {
                    this.RefreshButton(this.m_PCLegend.PCBtnRight,com.XInput.ButtonB,this.srBack,this.ConfirmMatchSettings,false);
                }
            }
            else
            {
                this.RefreshButton(_root.m_ControlY,0,"",undefined,false);
                this.RefreshButton(this.m_ControllerLegend.ControlY,com.XInput.ButtonY,this.srOptions,this.ShowOptionsScreen,_loc4_);
                if(_loc5_)
                {
                    this.RefreshButton(this.m_ControllerLegend.ControlX,com.XInput.ButtonX,this.srInviteParty,this.InviteParty,_loc4_ && !this.IsGameFull());
                }
                else
                {
                    this.RefreshButton(this.m_ControllerLegend.ControlX,com.XInput.ButtonX,this.srInviteFriends,this.InviteFriends,_loc4_ && !this.IsGameFull());
                }
                this.RefreshButton(this.m_ControllerLegend.ControlA,com.XInput.ButtonA,"",undefined,false);
                _loc8_ = this.leftPage.contents.list.getItem(this.SETTING_MAP);
                if(_loc8_.IsValueAvailable(_loc8_.GetActiveValue()))
                {
                    this.RefreshButton(this.m_ControllerLegend.ControlB,com.XInput.ButtonB,this.srBack,this.ConfirmMatchSettings,_loc4_);
                }
                else
                {
                    this.RefreshButton(this.m_ControllerLegend.ControlB,com.XInput.ButtonB,this.srBack,this.ConfirmMatchSettings,false);
                }
            }
        }
        else if(_global.SFX.Platform == com.XPlatform.PC)
        {
            this.RefreshButton(_root.PCBtnCharacter,0,"",undefined,false);
            this.RefreshButton(this.m_PCLegend.PCBtnLeft,com.XInput.ButtonY,"",undefined,false);
            this.RefreshButton(this.m_PCLegend.PCBtnMid1,com.XInput.ButtonX,"",undefined,false);
            this.RefreshButton(this.m_PCLegend.PCBtnMid2,com.XInput.ButtonA,!_loc7_ ? this.srSearch : this.srConfirm,this.ConfirmMatchSettings,_loc4_);
            this.RefreshButton(this.m_PCLegend.PCBtnRight,com.XInput.ButtonB,this.srCancel,this.CancelMatchSettings,_loc4_);
        }
        else
        {
            this.RefreshButton(_root.m_ControlY,0,"",undefined,false);
            this.RefreshButton(this.m_ControllerLegend.ControlY,com.XInput.ButtonY,"",undefined,false);
            this.RefreshButton(this.m_ControllerLegend.ControlX,com.XInput.ButtonX,"",undefined,false);
            this.RefreshButton(this.m_ControllerLegend.ControlA,com.XInput.ButtonA,!_loc7_ ? this.srSearch : this.srConfirm,this.ConfirmMatchSettings,_loc4_);
            this.RefreshButton(this.m_ControllerLegend.ControlB,com.XInput.ButtonB,this.srCancel,this.CancelMatchSettings,_loc4_);
        }
    }
    function RefreshButton(mcButton, nButtonID, sLabel, fnAction, bEnabled)
    {
        if(_global.SFX.Platform == com.XPlatform.PC)
        {
            mcButton._visible = fnAction != undefined;
            mcButton.SetEnabled(bEnabled);
            mcButton.text = sLabel;
            if(nButtonID != 0)
            {
                this.ActionMappings[nButtonID] = fnAction;
            }
        }
        else
        {
            mcButton._visible = fnAction != undefined;
            mcButton.text = sLabel;
            mcButton.Active = bEnabled;
            if(nButtonID != 0)
            {
                this.ActionMappings[nButtonID] = fnAction;
            }
        }
    }
    function RefreshPlayerList(list, bInteractive)
    {
        var _loc4_ = Number(flash.external.ExternalInterface.call("GetNumPlayerSlots"));
        var _loc5_ = Number(flash.external.ExternalInterface.call("GetNumPlayers"));
        if(list.selectedIndex >= _loc5_)
        {
            list.selectedIndex = _loc5_ - 1;
        }
        var _loc6_ = 0;
        while(_loc6_ < _loc4_)
        {
            if(_loc6_ < _loc5_)
            {
                var _loc7_ = flash.external.ExternalInterface.call("GetPlayerSlotBasicInfo",_loc6_);
                var _loc8_ = flash.external.ExternalInterface.call("GetPlayerSlotInfo_Patch",_loc6_);
                _loc7_.NumClassPromotions = _loc8_.NumClassPromotions;
                _loc7_.EmblemID = _loc8_.EmblemID;
                _loc7_.NumChallengesComplete = _loc8_.NumChallengesComplete;
                list.SetSlotPlayer(_loc6_,_loc7_);
            }
            else
            {
                list.SetSlotEmpty(_loc6_);
            }
            list.SetSlotPermission(_loc6_,this.IsPrivateMatch());
            _loc6_ += 1;
        }
        list.SetInteractive(bInteractive);
    }
    function RefreshAllSpeakerIcons(VoiceData)
    {
        var _loc3_ = null;
        if(this.leftPage.contents.m_symbolName == this.PAGE_SQUAD)
        {
            _loc3_ = this.leftPage.contents.list;
        }
        else if(this.rightPage.contents.m_symbolName == this.PAGE_SQUAD)
        {
            _loc3_ = this.rightPage.contents.list;
        }
        if(_loc3_ != null)
        {
            var _loc4_ = 0;
            while(_loc4_ < VoiceData.length)
            {
                _loc3_.SetSlotSpeakerIcon(_loc4_,VoiceData[_loc4_] != -1,VoiceData[_loc4_]);
                _loc4_ += 1;
            }
        }
    }
    function RefreshPlayerInfo(page, bShowLevelUp)
    {
        var _loc4_ = flash.external.ExternalInterface.call("GetLocalPlayerBasicInfo");
        var _loc5_ = Boolean(flash.external.ExternalInterface.call("CanLevelUp"));
        page.levelUpOverlay.LevelUpText.text = this.srLevelUp;
        page.levelUpOverlay._visible = bShowLevelUp && _loc5_;
        page.playerInfo.characterName.textAutoSize = "shrink";
        page.playerInfo.characterName.text = _loc4_.PlayerName;
        page.playerInfo.levelAndClass.text = _loc4_.ClassData;
        page.playerInfo.credits.text = _loc4_.Credits;
    }
    function onButtonA(p_event)
    {
        this.ActionMappings[com.XInput.ButtonA].call(this);
    }
    function onButtonB(p_event)
    {
        this.ActionMappings[com.XInput.ButtonB].call(this);
    }
    function onButtonX(p_event)
    {
        this.ActionMappings[com.XInput.ButtonX].call(this);
    }
    function onButtonY(p_event)
    {
        this.ActionMappings[com.XInput.ButtonY].call(this);
    }
    function ActivateCurrentListItem()
    {
        this.leftPage.contents.list.selectedItem.activate();
    }
    function onDPadLeft()
    {
        if(this.leftPage.contents.m_symbolName == this.PAGE_MISSION_SETUP)
        {
            if(this.leftPage.contents.list.selectedItem.bCanChange)
            {
                this.leftPage.contents.list.selectedItem.Decrement();
            }
        }
        else if(this.leftPage.contents.m_symbolName == this.PAGE_SQUAD)
        {
            this.HideSquadScreen();
        }
    }
    function onDPadRight()
    {
        if(this.leftPage.contents.m_symbolName == this.PAGE_MISSION_SETUP)
        {
            if(this.leftPage.contents.list.selectedItem.bCanChange)
            {
                this.leftPage.contents.list.selectedItem.Increment();
            }
        }
        else if(this.rightPage.contents.m_symbolName == this.PAGE_SQUAD)
        {
            this.ShowSquadScreen();
        }
    }
    function onDPadUp()
    {
        var _loc3_ = this.leftPage.contents.list;
        if(_loc3_ != null)
        {
            var _loc4_ = _loc3_.selectedIndex - 1;
            if(_loc3_.IsIndexValid(_loc4_))
            {
                _loc3_.selectedIndex = _loc4_;
                _global.SFX.PlayGUISound("MPLobbyPageItemChange");
            }
            else
            {
                _global.SFX.PlayGUIError();
            }
        }
    }
    function onDPadDown()
    {
        var _loc3_ = this.leftPage.contents.list;
        if(_loc3_ != null)
        {
            var _loc4_ = _loc3_.selectedIndex + 1;
            if(_loc3_.IsIndexValid(_loc4_))
            {
                _loc3_.selectedIndex = _loc4_;
                _global.SFX.PlayGUISound("MPLobbyPageItemChange");
            }
            else
            {
                _global.SFX.PlayGUIError();
            }
        }
    }
    function onInvalidInput(p_event)
    {
        _global.SFX.PlayGUIError();
    }
    function IsGameFull()
    {
        return Boolean(flash.external.ExternalInterface.call("IsGameFull"));
    }
    function IsPrivateMatch()
    {
        return Boolean(flash.external.ExternalInterface.call("IsPrivateMatch"));
    }
    function ExitLobby()
    {
        _root.screen.m_ControllerLegend.InputDisabled = true;
        flash.external.ExternalInterface.call("ExitLobby");
    }
    function ExitMultiplayer()
    {
        _root.screen.m_ControllerLegend.InputDisabled = true;
        flash.external.ExternalInterface.call("ExitMultiplayer");
    }
    function GoBackToSelectFirstCharacter()
    {
        flash.external.ExternalInterface.call("GoBackToSelectFirstCharacter");
    }
    function QuickMatch()
    {
        flash.external.ExternalInterface.call("QuickMatch");
    }
    function InviteFriends()
    {
        flash.external.ExternalInterface.call("InviteFriends");
    }
    function InviteParty()
    {
        flash.external.ExternalInterface.call("InviteParty");
    }
    function ShowPartySessions()
    {
        flash.external.ExternalInterface.call("ShowPartySessions");
    }
    function ViewInvitations()
    {
        flash.external.ExternalInterface.call("ViewInvitations");
    }
    function MakeMatchPublic()
    {
        flash.external.ExternalInterface.call("MakeMatchPublic");
    }
    function ShowGamercard()
    {
        flash.external.ExternalInterface.call("ShowGamercard",this.leftPage.contents.list.selectedIndex);
    }
    function CustomMatch()
    {
        _global.SFX.PlayGUISound("MPMissionSettingsStart");
        flash.external.ExternalInterface.call("CustomMatch");
    }
    function HostNewMission()
    {
        _global.SFX.PlayGUISound("MPMissionSettingsStart");
        flash.external.ExternalInterface.call("HostNewMission");
    }
    function ShowCharacterScreen()
    {
        _global.SFX.PlayGUISound("MPCharacterStart");
        this.LoadTab(screens.MPNewLobby.MPNewLobby.LSS_Character);
    }
    function HideCharacterScreen()
    {
        _global.SFX.PlayGUISound("MPCharacterExit");
        this.LoadTab(screens.MPNewLobby.MPNewLobby.LSS_MultiplayerMenu);
    }
    function ShowTalentsLevelUpScreen()
    {
        _root.screen.m_ControllerLegend.InputDisabled = true;
        flash.external.ExternalInterface.call("ShowTalentsLevelUpScreen");
    }
    function ShowWeaponsScreen()
    {
        _root.screen.m_ControllerLegend.InputDisabled = true;
        flash.external.ExternalInterface.call("ShowWeaponsScreen");
    }
    function ShowStoreScreen()
    {
        _root.screen.m_ControllerLegend.InputDisabled = true;
        flash.external.ExternalInterface.call("ShowStoreScreen");
    }
    function ShowAppearanceScreen()
    {
        _root.screen.m_ControllerLegend.InputDisabled = true;
        flash.external.ExternalInterface.call("ShowAppearanceScreen");
    }
    function ShowLeaderboardScreen()
    {
        _root.screen.m_ControllerLegend.InputDisabled = true;
        flash.external.ExternalInterface.call("ShowLeaderboardScreen");
    }
    function ShowMatchConsumablesScreen()
    {
        _root.screen.m_ControllerLegend.InputDisabled = true;
        flash.external.ExternalInterface.call("ShowMatchConsumablesScreen");
    }
    function ShowMissionSetupScreen()
    {
        _global.SFX.PlayGUISound("MPMissionSettingsStart");
        flash.external.ExternalInterface.call("ShowMatchSettingsScreen");
    }
    function ShowOptionsScreen()
    {
        _root.screen.m_ControllerLegend.InputDisabled = true;
        flash.external.ExternalInterface.call("ShowOptionsScreen");
    }
    function ShowSquadScreen()
    {
        this.m_PageTransitionType = this.PAGE_TRANSITION_SLIDE_LEFT;
        _global.SFX.PlayGUISound("MPSquadStart");
        this.LoadTab(screens.MPNewLobby.MPNewLobby.LSS_Squad);
    }
    function HideSquadScreen()
    {
        this.m_PageTransitionType = this.PAGE_TRANSITION_SLIDE_RIGHT;
        _global.SFX.PlayGUISound("MPSquadExit");
        this.LoadTab(screens.MPNewLobby.MPNewLobby.LSS_Lobby);
    }
    function SwitchCharacter()
    {
        _root.screen.m_ControllerLegend.InputDisabled = true;
        flash.external.ExternalInterface.call("SwitchCharacter");
    }
    function ShowMPChallengeScreen()
    {
        flash.external.ExternalInterface.call("ShowMPChallengeScreen");
    }
    function HasLeaderboardNotifications()
    {
        return Boolean(flash.external.ExternalInterface.call("HasLeaderboardNotifications"));
    }
    function GetLeaderboardNotificationText()
    {
        return String(flash.external.ExternalInterface.call("GetLeaderboardNotificationText"));
    }
    function ConfirmMatchSettings()
    {
        com.TweenManager.stopAllTweens();
        _global.SFX.PlayGUISound("MPMissionSettingsExit");
        flash.external.ExternalInterface.call("ChangeMatchSettings");
    }
    function CancelMatchSettings()
    {
        com.TweenManager.stopAllTweens();
        _global.SFX.PlayGUISound("MPMissionSettingsExit");
        flash.external.ExternalInterface.call("CancelMatchSettings");
    }
    function ToggleReady()
    {
        var _loc1_ = Boolean(flash.external.ExternalInterface.call("IsReady"));
        flash.external.ExternalInterface.call("SetReady",!_loc1_);
    }
    function ToggleVoteToKickSelectedPlayer()
    {
        var _loc2_ = Boolean(flash.external.ExternalInterface.call("HasVotedToKickPlayerInSlot",this.leftPage.contents.list.selectedIndex));
        flash.external.ExternalInterface.call("VoteToKickPlayerInSlot",this.leftPage.contents.list.selectedIndex,!_loc2_);
        this.RefreshButtonLegend();
    }
    function GetPrivacySetting()
    {
        if(this.leftPage.contents.m_symbolName == this.PAGE_MISSION_SETUP)
        {
            return this.leftPage.contents.list.getItem(this.SETTING_PRIVACY).GetActiveValueID();
        }
        return 0;
    }
    function GetMapSetting()
    {
        if(this.leftPage.contents.m_symbolName == this.PAGE_MISSION_SETUP)
        {
            return this.leftPage.contents.list.getItem(this.SETTING_MAP).GetActiveValueID();
        }
        return 0;
    }
    function GetEnemySetting()
    {
        if(this.leftPage.contents.m_symbolName == this.PAGE_MISSION_SETUP)
        {
            return this.leftPage.contents.list.getItem(this.SETTING_ENEMY).GetActiveValueID();
        }
        return 0;
    }
    function GetChallengeSetting()
    {
        if(this.leftPage.contents.m_symbolName == this.PAGE_MISSION_SETUP)
        {
            return this.leftPage.contents.list.getItem(this.SETTING_CHALLENGE).GetActiveValueID();
        }
        return 0;
    }
    function GetMissionSettingsTabTitle()
    {
        if(this.m_bConnected)
        {
            return this.srMissionSetup;
        }
        var _loc2_ = Boolean(flash.external.ExternalInterface.call("IsHostingNewMission"));
        return !_loc2_ ? this.srQuickMatch : this.srHostNewMission;
    }
    function ExitLobbyCancelled()
    {
        _root.screen.m_ControllerLegend.InputDisabled = false;
    }
    function ExitMultiplayerCancelled()
    {
        _root.screen.m_ControllerLegend.InputDisabled = false;
    }
}
