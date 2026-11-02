// Stumpy - 2026/11/03 - Name variables and update from scaleform
class screens.MPNewLobby.MPNewLobby extends com.SFXScreen
{
    // MILAN CHANGE - Mgamerz - 2026-10-10
    // Four physical cards are rebound to absolute lobby slots. Menu indices remain local.
    var m_FirstVisibleSlot = 0;
    var m_SelectedPlayerSlot = -1;
    var m_PlayerSlotCount = 0;
    var m_CustomPlayerIcons;
    var m_BindingPlayerRows = false;
    var m_ScrollDirection = 0;
    var m_NextScrollRepeat = 0;
    var m_ViewStickDirection = 0;
    var m_PlayerViewPending = false;
    var m_PlayerInputTimer;

    var m_bConnected;
    var leftPage;
    var PreviouslySelectedItem;
    var m_ControllerLegend;
    var m_PCLegend;
    var ActionMappings;
    var MakeDelegate;
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
    // just chosen to not overlap with com.xbox.button* values
    var PCMid2Event = 64;
    var leftArrowOriginalX;
    var rightArrayOriginalX;
    var bUsingGamepad;
    function MPNewLobby()
    {
        super();
    }
    function onLoad()
    {
        Mouse.addListener(this);
        this.m_PlayerInputTimer = setInterval(this,"TickPlayerInput",50);

        super.onLoad();
        this.m_bConnected = false;
        this.LoadStrings();
        this.SetupPageArrows();
        this.SetupButtonLegend();
        var CurrentLobbyTab = Number(flash.external.ExternalInterface.call("GetCurrentLobbyTab"));
        this.LoadTab(CurrentLobbyTab);
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
        if(this.leftPage.contents.m_symbolName == this.PAGE_SQUAD)
        {
            return;
        }
        var PageList = this.leftPage.contents.list;
        if(!PageList.IsIndexValid(this.PreviouslySelectedItem))
        {
            this.PreviouslySelectedItem = 0;
        }
        PageList.selectedIndex = this.PreviouslySelectedItem;
    }
    function SetupButtonLegend()
    {
        this.m_ControllerLegend = _root.mcControllerButtons;
        this.m_PCLegend = _root.PCController;
        // set up PC handlers
        _root.PCBtnCharacter.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.onButtonY));
        this.m_PCLegend.PCBtnLeft.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.onButtonY));
        this.m_PCLegend.PCBtnMid1.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.onButtonX));
        // they did a weird thing and mapped this button using the controller A event, which is also triggered with enter, but that is often not what you want enter to do,
        // so I separated it out to a separate event and manually mapped A/Enter to confirm/activate current item for each subscreen mode
        this.m_PCLegend.PCBtnMid2.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.onPCMid2));
        this.m_PCLegend.PCBtnRight.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.onButtonB));
        // set up controller handlers
        this.m_ControllerLegend.addEventListener("onButtonA",mx.utils.Delegate.create(this,this.onButtonA));
        this.m_ControllerLegend.addEventListener("onButtonB",mx.utils.Delegate.create(this,this.onButtonB));
        this.m_ControllerLegend.addEventListener("onButtonX",mx.utils.Delegate.create(this,this.onButtonX));
        this.m_ControllerLegend.addEventListener("onDPadUp",mx.utils.Delegate.create(this,this.onDPadUp));
        this.m_ControllerLegend.addEventListener("onDPadDown",mx.utils.Delegate.create(this,this.onDPadDown));
        this.m_ControllerLegend.addEventListener("onDPadLeft",mx.utils.Delegate.create(this,this.onDPadLeft));
        this.m_ControllerLegend.addEventListener("onDPadRight",mx.utils.Delegate.create(this,this.onDPadRight));
        this.m_ControllerLegend.addEventListener("onInvalidInput",mx.utils.Delegate.create(this,this.onInvalidInput));
        Key.addListener(this);
        this.RefreshButtonHelp(flash.external.ExternalInterface.call("IsUsingGamepad"));
        this.ActionMappings = new Object();
    }
    function RefreshButtonHelp(usingGamepad)
    {
        this.bUsingGamepad = usingGamepad;
        var bIsInDeployFlow = Boolean(flash.external.ExternalInterface.call("IsInDeployFlow"));
        if(!this.bUsingGamepad)
        {
            this.m_ArrowLeft.contents._x = this.leftArrowOriginalX - this.PC_ARROW_OFFSET;
            this.m_ArrowRight.contents._x = this.rightArrayOriginalX + this.PC_ARROW_OFFSET;
            this.m_ArrowLeft.ShowStickIcon(false);
            this.m_ArrowRight.ShowStickIcon(false);

            _root.m_ControlY._visible = false;
            this.m_ControllerLegend._visible = false;
            _root.PCBtnCharacter._visible = true;
            _root.PCBtnCharacter.enabled = true;
            this.m_PCLegend._visible = true;
            this.m_PCLegend.enabled = true;
        }
        else
        {
            this.m_ArrowLeft.ShowStickIcon(true);
            this.m_ArrowRight.ShowStickIcon(true);
            this.m_ArrowLeft.contents._x = this.leftArrowOriginalX;
            this.m_ArrowRight.contents._x = this.rightArrayOriginalX;

            _root.PCBtnCharacter._visible = false;
            _root.PCBtnCharacter.enabled = false;
            this.m_PCLegend._visible = false;
            this.m_PCLegend.enabled = false;
            _root.m_ControlY._visible = true;
            this.m_ControllerLegend._visible = true;
        }
        this.RefreshButtonLegend();
        this.RefreshPageArrows();
    }
    function onKeyUp()
    {
        if(_root.screen.m_ControllerLegend.InputDisabled)
        {
            return;
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
        this.leftArrowOriginalX = this.m_ArrowLeft.contents._x;
        this.rightArrayOriginalX = this.m_ArrowRight.contents._x;
        this.m_ArrowLeft.addEventListener("ArrowPressed",this.MakeDelegate(this.HideSquadScreen));
        this.m_ArrowRight.addEventListener("ArrowPressed",this.MakeDelegate(this.ShowSquadScreen));
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
        this.m_PlayerViewPending = false;
        this.m_ScrollDirection = 0;
        if(subscreen == LSS_Squad)
        {
            this.m_SelectedPlayerSlot = Number(flash.external.ExternalInterface.call("GetPreviouslySelectedItem",subscreen));
        }
        this.PreviouslySelectedItem = Number(flash.external.ExternalInterface.call("GetPreviouslySelectedItem",subscreen));
        this.m_bConnected = Boolean(flash.external.ExternalInterface.call("IsMPGame"));
        if(subscreen == LSS_MultiplayerMenu)
        {
            this.SetTitle(this.srMultiplayerMenuTitle);
            this.LoadPage(this.leftPage,this.PAGE_MULTIPLAYER_MENU);
            this.LoadPage(this.rightPage,this.PAGE_GALAXY_AT_WAR);
        }
        else if(subscreen == LSS_Character)
        {
            this.SetTitle(this.srCharacter);
            this.LoadPage(this.leftPage,this.PAGE_CHARACTER_MENU);
            this.LoadPage(this.rightPage,this.PAGE_CHARACTER);
        }
        else if(subscreen == LSS_MissionSetup)
        {
            this.SetTitle(this.GetMissionSettingsTabTitle());
            this.LoadPage(this.leftPage,this.PAGE_MISSION_SETUP);
            this.LoadPage(this.rightPage,this.PAGE_GALAXY_AT_WAR);
        }
        else if(subscreen == LSS_Lobby)
        {
            this.SetTitle(this.srLobbyTitle);
            this.LoadPage(this.leftPage,this.PAGE_LOBBY_MENU);
            this.LoadPage(this.rightPage,this.PAGE_SQUAD);
        }
        else if(subscreen == LSS_Squad)
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
        var CurrentLobbyTab = Number(flash.external.ExternalInterface.call("GetCurrentLobbyTab"));
        this.PreviouslySelectedItem = Number(flash.external.ExternalInterface.call("GetPreviouslySelectedItem", CurrentLobbyTab));
        var PageList = page.list;
        var bCanAffordNewStoreItems;
        var IsChallengeSystemEnabled;
        var MatchSettings;
        var MapList;
        var PrivacyTypes;
        var EnemyTypes;
        var ChallengeTypes;
        var bIsMPClient;
        var bCurrentTabIsLSS_Squad;
        var bCanLevelUp;
        var bHasNewWeapons;
        var bHasNewAppearanceOptions;
        var bHasNewMatchConsumables;
        if(sSymbolName == this.PAGE_MULTIPLAYER_MENU)
        {
            bCanAffordNewStoreItems = Boolean(flash.external.ExternalInterface.call("CanAffordNewStoreItems"));
            IsChallengeSystemEnabled = Boolean(flash.external.ExternalInterface.call("IsChallengeSystemEnabled"));
            if(!IsChallengeSystemEnabled)
            {
                PageList.gotoAndStop("nochallenges");
            }
            PageList.item1.contents.title.text = this.srQuickMatch;
            PageList.item1.action = this.CustomMatch;
            PageList.item2.contents.title.text = this.srHostNewMission;
            PageList.item2.action = this.HostNewMission;
            PageList.item3.contents.title.text = this.srCharacter;
            PageList.item3.action = this.MakeDelegate(this.ShowCharacterScreen);
            PageList.item4.contents.title.text = this.srLeaderboards;
            PageList.item4.action = this.ShowLeaderboardScreen;
            PageList.item5.contents.title.text = this.srReinforcements;
            PageList.item5.action = this.ShowStoreScreen;
            PageList.item5.SetAlert(bCanAffordNewStoreItems,this.srNew);
            if(IsChallengeSystemEnabled)
            {
                PageList.item6.contents.title.text = this.srChallengeTracking;
                PageList.item6.action = this.MakeDelegate(this.ShowMPChallengeScreen);
            }
            this.RefreshPlayerInfo(page,false);
        }
        else if(sSymbolName == this.PAGE_CHARACTER)
        {
            this.RefreshCharacterSummary();
        }
        else if(sSymbolName == this.PAGE_MISSION_SETUP)
        {
            MatchSettings = flash.external.ExternalInterface.call("GetMatchSettings");
            MapList = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetMapList"));
            PrivacyTypes = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetPrivacyTypes"));
            EnemyTypes = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetEnemyTypes"));
            ChallengeTypes = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetChallengeTypes"));
            this.bIsHostingNewMission = Boolean(flash.external.ExternalInterface.call("IsHostingNewMission"));
            bIsMPClient = com.SFXScreen.IsMPClient;
            if(this.m_bConnected)
            {
                PageList.item1.Initialize(this.srTeam, PrivacyTypes,MatchSettings.privacy, !bIsMPClient);
            }
            else if(this.bIsHostingNewMission)
            {
                PageList.item1.Initialize(this.srTeam, PrivacyTypes,MatchSettings.privacy, !bIsMPClient);
            }
            else
            {
                MapList = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetMapListForSearching"));
                EnemyTypes = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetEnemyTypesForSearching"));
                ChallengeTypes = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetChallengeTypesForSearching"));
                PageList.item1.Initialize(this.srTeam,PrivacyTypes, 0, false);
            }
            PageList.item1.Refresh();
            if(MatchSettings.bRandomMap)
            {
                PageList.item2.Initialize(this.srMap, MapList, 0, !bIsMPClient);
            }
            else
            {
                PageList.item2.Initialize(this.srMap, MapList,MatchSettings.MapId, !bIsMPClient);
            }
            PageList.item2.Refresh();
            if(MatchSettings.bRandomEnemy)
            {
                PageList.item3.Initialize(this.srEnemy, EnemyTypes, 0, !bIsMPClient);
            }
            else
            {
                PageList.item3.Initialize(this.srEnemy, EnemyTypes, MatchSettings.Enemy, !bIsMPClient);
            }
            PageList.item3.Refresh();
            PageList.item4.Initialize(this.srChallenge, ChallengeTypes, MatchSettings.Challenge, !bIsMPClient);
            PageList.item4.Refresh();
        }
        else if(sSymbolName == this.PAGE_SQUAD)
        {
            bCurrentTabIsLSS_Squad = CurrentLobbyTab == LSS_Squad;
            this.RefreshPlayerList(screens.MPNewLobby.PlayerList(PageList), bCurrentTabIsLSS_Squad);
        }
        else if(sSymbolName == this.PAGE_CHARACTER_MENU)
        {
            bCanLevelUp = Boolean(flash.external.ExternalInterface.call("CanLevelUp"));
            bHasNewWeapons = Boolean(flash.external.ExternalInterface.call("HasNewWeapons"));
            bHasNewAppearanceOptions = Boolean(flash.external.ExternalInterface.call("HasNewAppearanceOptions"));
            bHasNewMatchConsumables = Boolean(flash.external.ExternalInterface.call("HasNewMatchConsumables"));
            bCanAffordNewStoreItems = Boolean(flash.external.ExternalInterface.call("CanAffordNewStoreItems"));
            PageList.item1.contents.title.text = this.srTalentsLevelUp;
            PageList.item1.action = this.ShowTalentsLevelUpScreen;
            PageList.item1.SetLevelUpIcon(bCanLevelUp);
            PageList.item2.contents.title.text = this.srWeapons;
            PageList.item2.action = this.ShowWeaponsScreen;
            PageList.item2.SetAlert(bHasNewWeapons, this.srNew);
            PageList.item3.contents.title.text = this.srAppearance;
            PageList.item3.action = this.ShowAppearanceScreen;
            PageList.item3.SetAlert(bHasNewAppearanceOptions, this.srNew);
            PageList.item4.contents.title.text = this.srMatchConsumables;
            PageList.item4.action = this.ShowMatchConsumablesScreen;
            PageList.item4.SetAlert(bHasNewMatchConsumables, this.srNew);
            PageList.item5.contents.title.text = this.srReinforcements;
            PageList.item5.action = this.ShowStoreScreen;
            PageList.item5.SetAlert(bCanAffordNewStoreItems,this.srNew);
            this.RefreshPlayerInfo(page,true);
        }
        else if(sSymbolName == this.PAGE_LOBBY_MENU)
        {
            bCanLevelUp = Boolean(flash.external.ExternalInterface.call("CanLevelUp"));
            bHasNewWeapons = Boolean(flash.external.ExternalInterface.call("HasNewWeapons"));
            bHasNewAppearanceOptions = Boolean(flash.external.ExternalInterface.call("HasNewAppearanceOptions"));
            bHasNewMatchConsumables = Boolean(flash.external.ExternalInterface.call("HasNewMatchConsumables"));
            bCanAffordNewStoreItems = Boolean(flash.external.ExternalInterface.call("CanAffordNewStoreItems"));
            PageList.item1.contents.title.text = this.srToggleReady;
            PageList.item1.action = this.ToggleReady;
            PageList.item1._visible = this.m_bConnected;
            PageList.item2.contents.title.text = this.srMissionSetup;
            PageList.item2.action = this.ShowMissionSetupScreen;
            PageList.item2._visible = this.m_bConnected;
            PageList.item3.contents.title.text = this.srTalentsLevelUp;
            PageList.item3.action = this.ShowTalentsLevelUpScreen;
            PageList.item3.SetLevelUpIcon(bCanLevelUp);
            PageList.item4.contents.title.text = this.srWeapons;
            PageList.item4.action = this.ShowWeaponsScreen;
            PageList.item4.SetAlert(bHasNewWeapons, this.srNew);
            PageList.item5.contents.title.text = this.srAppearance;
            PageList.item5.action = this.ShowAppearanceScreen;
            PageList.item5.SetAlert(bHasNewAppearanceOptions, this.srNew);
            PageList.item6.contents.title.text = this.srMatchConsumables;
            PageList.item6.action = this.ShowMatchConsumablesScreen;
            PageList.item6.SetAlert(bHasNewMatchConsumables, this.srNew);
            PageList.item7.contents.title.text = this.srReinforcements;
            PageList.item7.action = this.ShowStoreScreen;
            PageList.item7.SetAlert(bCanAffordNewStoreItems, this.srNew);
            this.RefreshPlayerInfo(page, true);
        }
        else if(sSymbolName == this.PAGE_GALAXY_AT_WAR)
        {
            this.RefreshGalaxyAtWarMap();
        }
        var bShouldShowChatDisabledMessage;
        if(page._parent == this.leftPage)
        {
            this.SetInitialSelectedItem();
            this.RefreshButtonLegend();
            bShouldShowChatDisabledMessage = Boolean(flash.external.ExternalInterface.call("ShouldShowChatDisabledMessage"));
            page.chatDisabled.text = this.srChatDisabled;
            page.chatDisabled._visible = bShouldShowChatDisabledMessage && sSymbolName == this.PAGE_LOBBY_MENU;
        }
        this.RefreshPageArrows();
    }

    function RefreshPageArrows()
    {
        this.m_ArrowLeft._visible = false;
        this.m_ArrowRight._visible = false;
        if(this.leftPage.contents.m_symbolName == this.PAGE_LOBBY_MENU)
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
        var GAWMap = this.rightPage.contents.map;
        var bHasGAWRatingsError = Boolean(flash.external.ExternalInterface.call("HasGAWRatingsError"));
        GAWMap.SetErrorText(bHasGAWRatingsError, this.srGalaxyAtWarError);
        this.RefreshGalaxyAtWarRatings();
        this.RefreshGalaxyAtWarMapPositionMarker();
    }

    function RefreshGalaxyAtWarRatings()
    {
        var GAWMap;
        var GAWRatings;
        var GAWZoneIdx;
        if(this.rightPage.contents.m_symbolName == this.PAGE_GALAXY_AT_WAR)
        {
            GAWMap = this.rightPage.contents.map;
            GAWRatings = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetGAWRatings"));
            GAWZoneIdx = 0;
            while(GAWZoneIdx < GAWRatings.length)
            {
                GAWMap.SetZoneText(GAWRatings[GAWZoneIdx].ZoneID,GAWRatings[GAWZoneIdx].ZoneName);
                GAWMap.SetZoneReadiness(GAWRatings[GAWZoneIdx].ZoneID,GAWRatings[GAWZoneIdx].CurrentRating);
                GAWZoneIdx += 1;
            }
            // MILAN CHANGE - Mgamerz - 2026-10-16
            // Hide readiness percentages while retaining their fields and updates.
            GAWMap.SetPercentagesVisible(false);
            // END MILAN CHANGE
        }
    }

    function RefreshGalaxyAtWarMapPositionMarker()
    {
        // MILAN CHANGE - Mgamerz - 2026-10-16
        // Retain the readiness bonus text and updates, but hide its display.
        var GAWMap = this.rightPage.contents.map;
        this.rightPage.contents.GAWBonusText._visible = false;
        // END MILAN CHANGE
        var MapInfo;
        var MapZoneID;
        if(this.leftPage.contents.m_symbolName == this.PAGE_MISSION_SETUP && this.rightPage.contents.m_symbolName == this.PAGE_GALAXY_AT_WAR)
        {
            MapInfo = flash.external.ExternalInterface.call("GetMapInfo",this.GetMapSetting());
            MapZoneID = Number(flash.external.ExternalInterface.call("GetMapZoneID",MapInfo.PackageName));
            this.rightPage.contents.GAWBonusText.textAutoSize = "shrink";
            this.rightPage.contents.GAWBonusText.text = String(flash.external.ExternalInterface.call("GetGAWZoneBonusText",this.GetMapSetting()));
            if(MapInfo.Id > 0 && MapInfo.GalaxyAtWarMapSubtitle != 0)
            {
                GAWMap.SetTextFieldTransparancy(30);
                GAWMap.SetZoneTextFieldTransparency(MapZoneID,100);
                GAWMap.SetPositionalMarker(true,"","",MapInfo.GalaxyAtWarMapPosition.X,MapInfo.GalaxyAtWarMapPosition.Y);
                GAWMap.SelectZone(MapZoneID);
            }
            else
            {
                GAWMap.SetTextFieldTransparancy(100);
                GAWMap.SetPositionalMarker(false,"","",0,0);
                GAWMap.UnselectCurrentZone();
            }
        }
        else
        {
            GAWMap.SetTextFieldTransparancy(100);
            GAWMap.SetPositionalMarker(false,"","",0,0);
            GAWMap.UnselectCurrentZone();
            this.rightPage.contents.GAWBonusText.text = "";
        }
    }

    function onListItemSelected(list)
    {
        if(this.m_BindingPlayerRows)
        {
            return;
        }
        if(list == this.GetPlayerWindowList() && list.selectedItem != undefined)
        {
            this.m_SelectedPlayerSlot = list.selectedItem.m_slotIndex;
        }
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
        var CharacterSummary = this.rightPage.contents.summary;
        if(CharacterSummary != null)
        {
            CharacterSummary.Refresh();
        }
    }

    function RefreshScreen()
    {
        this.RefreshPage(this.leftPage.contents,this.leftPage.contents.m_symbolName);
        this.RefreshPage(this.rightPage.contents,this.rightPage.contents.m_symbolName);
    }

    function RefreshButtonLegend()
    {
        var CurrentLobbyTab = Number(flash.external.ExternalInterface.call("GetCurrentLobbyTab"));
        if(CurrentLobbyTab == LSS_MultiplayerMenu)
        {
            this.RefreshButtonLegend_MultiplayerMenu();
        }
        else if(CurrentLobbyTab == LSS_Character)
        {
            this.RefreshButtonLegend_Character();
        }
        else if(CurrentLobbyTab == LSS_MissionSetup)
        {
            this.RefreshButtonLegend_MissionSetup();
        }
        else if(CurrentLobbyTab == LSS_Lobby)
        {
            this.RefreshButtonLegend_Lobby();
        }
        else if(CurrentLobbyTab == LSS_Squad)
        {
            this.RefreshButtonLegend_Squad();
        }
        this.m_ControllerLegend.FitLeft();
    }

    function RefreshButtonLegend_MultiplayerMenu()
    {
        var bCanInteract = Boolean(flash.external.ExternalInterface.call("CanInteract"));
        // var bIsInParty = Boolean(flash.external.ExternalInterface.call("IsInParty"));
        var bCameFromSelectFirstCharacter = Boolean(flash.external.ExternalInterface.call("CameFromSelectFirstCharacter"));
        if(!this.bUsingGamepad)
        {
            this.RefreshButton(_root.PCBtnCharacter,com.XInput.ButtonY,this.srSwitchCharacter,this.SwitchCharacter,bCanInteract);
            this.RefreshButton(this.m_PCLegend.PCBtnLeft,0,"",undefined,false);
            this.RefreshButton(this.m_PCLegend.PCBtnMid1,com.XInput.ButtonX,"",undefined,false);
            // map xbox A/Enter to "select current item"
            this.RefreshButton(undefined,com.XInput.ButtonA,"",this.ActivateCurrentListItem,bCanInteract);
            // map PC mid button 2 to options without affecting enter mapping
            this.RefreshButton(this.m_PCLegend.PCBtnMid2,PCMid2Event,this.srOptions,this.ShowOptionsScreen,bCanInteract);
            if(bCameFromSelectFirstCharacter)
            {
                this.RefreshButton(this.m_PCLegend.PCBtnRight,com.XInput.ButtonB,this.srBack,this.GoBackToSelectFirstCharacter,bCanInteract);
            }
            else
            {
                this.RefreshButton(this.m_PCLegend.PCBtnRight,com.XInput.ButtonB,this.srExitMultiplayer,this.ExitMultiplayer,bCanInteract);
            }
        }
        else
        {
            this.RefreshButton(_root.m_ControlY,com.XInput.ButtonY,this.srSwitchCharacter,this.SwitchCharacter,bCanInteract,true);
            this.RefreshButton(this.m_ControllerLegend.ControlY,0,"",undefined,false,true);
            this.RefreshButton(this.m_ControllerLegend.ControlX,com.XInput.ButtonX,this.srOptions,this.ShowOptionsScreen,bCanInteract,true);
            this.RefreshButton(this.m_ControllerLegend.ControlA,com.XInput.ButtonA,this.srSelect,this.ActivateCurrentListItem,bCanInteract,true);
            if(bCameFromSelectFirstCharacter)
            {
                this.RefreshButton(this.m_ControllerLegend.ControlB,com.XInput.ButtonB,this.srBack,this.GoBackToSelectFirstCharacter,bCanInteract,true);
            }
            else
            {
                this.RefreshButton(this.m_ControllerLegend.ControlB,com.XInput.ButtonB,this.srExitMultiplayer,this.ExitMultiplayer,bCanInteract,true);
            }
        }
    }

    function RefreshButtonLegend_Character()
    {
        var bCanInteract = Boolean(flash.external.ExternalInterface.call("CanInteract"));
        // var isInParty = Boolean(flash.external.ExternalInterface.call("IsInParty"));
        if(!this.bUsingGamepad)
        {
            this.RefreshButton(_root.PCBtnCharacter,com.XInput.ButtonY,this.srSwitchCharacter,this.SwitchCharacter,bCanInteract);
            this.RefreshButton(this.m_PCLegend.PCBtnLeft,0,"",undefined,false);
            this.RefreshButton(this.m_PCLegend.PCBtnMid1,com.XInput.ButtonX,"",undefined,false);
            this.RefreshButton(undefined,com.XInput.ButtonA,"",this.ActivateCurrentListItem,bCanInteract);
            // map PC mid button 2 to options without affecting enter mapping
            this.RefreshButton(this.m_PCLegend.PCBtnMid2,PCMid2Event,this.srOptions,this.ShowOptionsScreen,bCanInteract);
            this.RefreshButton(this.m_PCLegend.PCBtnRight,com.XInput.ButtonB,this.srBack,this.MakeDelegate(this.HideCharacterScreen),bCanInteract);
        }
        else
        {
            this.RefreshButton(_root.m_ControlY,com.XInput.ButtonY,this.srSwitchCharacter,this.SwitchCharacter,bCanInteract,true);
            this.RefreshButton(this.m_ControllerLegend.ControlY,0,"",undefined,false,true);
            this.RefreshButton(this.m_ControllerLegend.ControlX,com.XInput.ButtonX,this.srOptions,this.ShowOptionsScreen,bCanInteract,true);
            this.RefreshButton(this.m_ControllerLegend.ControlA,com.XInput.ButtonA,this.srSelect,this.ActivateCurrentListItem,bCanInteract,true);
            this.RefreshButton(this.m_ControllerLegend.ControlB,com.XInput.ButtonB,this.srBack,this.MakeDelegate(this.HideCharacterScreen),bCanInteract,true);
        }
    }

    function RefreshButtonLegend_Lobby()
    {
        var bCanInteract = Boolean(flash.external.ExternalInterface.call("CanInteract"));
        var bIsInParty = Boolean(flash.external.ExternalInterface.call("IsInParty"));
        if(!this.bUsingGamepad)
        {
            this.RefreshButton(_root.PCBtnCharacter,com.XInput.ButtonY,this.srSwitchCharacter,this.SwitchCharacter,bCanInteract);
            this.RefreshButton(this.m_PCLegend.PCBtnLeft,0,"",undefined,false);
            this.RefreshButton(this.m_PCLegend.PCBtnMid1,com.XInput.ButtonX,this.srOptions,this.ShowOptionsScreen,bCanInteract);
            this.RefreshButton(undefined,com.XInput.ButtonA,"",this.ActivateCurrentListItem,bCanInteract);
            // map PC mid button 2 to options without affecting enter mapping
            if(bIsInParty)
            {
                this.RefreshButton(this.m_PCLegend.PCBtnMid2,PCMid2Event,this.srInviteParty,this.InviteParty,bCanInteract && !this.IsGameFull());
            }
            else
            {
                this.RefreshButton(this.m_PCLegend.PCBtnMid2,PCMid2Event,this.srInviteFriends,this.InviteFriends,bCanInteract && !this.IsGameFull());
            }
            this.RefreshButton(this.m_PCLegend.PCBtnRight,com.XInput.ButtonB,this.srExitLobby,this.ExitLobby,bCanInteract);
        }
        else
        {
            this.RefreshButton(_root.m_ControlY,com.XInput.ButtonY,this.srSwitchCharacter,this.SwitchCharacter,bCanInteract,true);
            this.RefreshButton(this.m_ControllerLegend.ControlY,0,"",undefined,false,true);
            if(bIsInParty)
            {
                this.RefreshButton(this.m_ControllerLegend.ControlX,com.XInput.ButtonX,this.srInviteParty,this.InviteParty,bCanInteract && !this.IsGameFull(),true);
            }
            else
            {
                this.RefreshButton(this.m_ControllerLegend.ControlX,com.XInput.ButtonX,this.srInviteFriends,this.InviteFriends,bCanInteract && !this.IsGameFull(),true);
            }
            this.RefreshButton(this.m_ControllerLegend.ControlA,com.XInput.ButtonA,this.srSelect,this.ActivateCurrentListItem,bCanInteract,true);
            this.RefreshButton(this.m_ControllerLegend.ControlB,com.XInput.ButtonB,this.srExitLobby,this.ExitLobby,bCanInteract,true);
        }
    }

    function RefreshButtonLegend_Squad()
    {
        var bCanInteract = Boolean(flash.external.ExternalInterface.call("CanInteract"));
        var bIsInParty = Boolean(flash.external.ExternalInterface.call("IsInParty"));
        var SelectedPlayer;
        var bHasVotedToKickPlayerInSlot;
        if(!this.bUsingGamepad)
        {
            this.RefreshButton(_root.PCBtnCharacter,0,"",undefined,false);
            SelectedPlayer = screens.MPNewLobby.PlayerItem(this.leftPage.contents.list.selectedItem);
            if(SelectedPlayer.isOccupied && !SelectedPlayer.isLocalPlayer)
            {
                bHasVotedToKickPlayerInSlot = Boolean(flash.external.ExternalInterface.call("HasVotedToKickPlayerInSlot",this.GetSelectedPlayerSlot()));
                this.RefreshButton(this.m_PCLegend.PCBtnLeft,com.XInput.ButtonY,!bHasVotedToKickPlayerInSlot ? this.srVoteToKick : this.srUnvoteToKick,this.ToggleVoteToKickSelectedPlayer,bCanInteract);
            }
            else
            {
                this.RefreshButton(this.m_PCLegend.PCBtnLeft,com.XInput.ButtonY,this.srVoteToKick,this.ToggleVoteToKickSelectedPlayer,false);
            }
            this.RefreshButton(this.m_PCLegend.PCBtnMid1,com.XInput.ButtonX,this.srOptions,this.ShowOptionsScreen,bCanInteract);
            this.RefreshButton(undefined,com.XInput.ButtonA,"",this.ActivateCurrentListItem,bCanInteract);
            if(bIsInParty)
            {
                this.RefreshButton(this.m_PCLegend.PCBtnMid2,PCMid2Event,this.srInviteParty,this.InviteParty,bCanInteract && !this.IsGameFull());
            }
            else
            {
                this.RefreshButton(this.m_PCLegend.PCBtnMid2,PCMid2Event,this.srInviteFriends,this.InviteFriends,bCanInteract && !this.IsGameFull());
            }
            this.RefreshButton(this.m_PCLegend.PCBtnRight,com.XInput.ButtonB,this.srBack,this.MakeDelegate(this.HideSquadScreen),bCanInteract);
        }
        else
        {
            this.RefreshButton(_root.m_ControlY,0,"",undefined,false,true);
            SelectedPlayer = screens.MPNewLobby.PlayerItem(this.leftPage.contents.list.selectedItem);
            if(SelectedPlayer.isOccupied && !SelectedPlayer.isLocalPlayer)
            {
                bHasVotedToKickPlayerInSlot = Boolean(flash.external.ExternalInterface.call("HasVotedToKickPlayerInSlot",this.GetSelectedPlayerSlot()));
                this.RefreshButton(this.m_ControllerLegend.ControlY,com.XInput.ButtonY,!bHasVotedToKickPlayerInSlot ? this.srVoteToKick : this.srUnvoteToKick,this.ToggleVoteToKickSelectedPlayer,bCanInteract,true);
            }
            else
            {
                this.RefreshButton(this.m_ControllerLegend.ControlY,com.XInput.ButtonY,this.srVoteToKick,this.ToggleVoteToKickSelectedPlayer,false,true);
            }
            if(bIsInParty)
            {
                this.RefreshButton(this.m_ControllerLegend.ControlX,com.XInput.ButtonX,this.srInviteParty,this.InviteParty,bCanInteract && !this.IsGameFull(),true);
            }
            else
            {
                this.RefreshButton(this.m_ControllerLegend.ControlX,com.XInput.ButtonX,this.srInviteFriends,this.InviteFriends,bCanInteract && !this.IsGameFull(),true);
            }
            this.RefreshButton(this.m_ControllerLegend.ControlA,com.XInput.ButtonA,"",undefined,false,true);
            this.RefreshButton(this.m_ControllerLegend.ControlB,com.XInput.ButtonB,this.srBack,this.MakeDelegate(this.HideSquadScreen),bCanInteract,true);
            this.m_ControllerLegend.ControlB.SetVisible(false);
        }
    }

    function RefreshButtonLegend_MissionSetup()
    {
        var bCanInteract = Boolean(flash.external.ExternalInterface.call("CanInteract"));
        var bIsInParty = Boolean(flash.external.ExternalInterface.call("IsInParty"));
        var bIsMPHost = com.SFXScreen.IsMPClient == false;
        var bIsHostingNewMission = Boolean(flash.external.ExternalInterface.call("IsHostingNewMission"));
        var SelectedMap;
        if(this.m_bConnected)
        {
            if(!this.bUsingGamepad)
            {
                this.RefreshButton(_root.PCBtnCharacter,0,"",undefined,false);
                this.RefreshButton(this.m_PCLegend.PCBtnLeft,com.XInput.ButtonY,"",undefined,false);
                this.RefreshButton(this.m_PCLegend.PCBtnMid1,com.XInput.ButtonX,this.srOptions,this.ShowOptionsScreen,bCanInteract);
                // TODO should enter do anything in this case?
                // this.RefreshButton(undefined,com.XInput.ButtonA,"",this.ActivateCurrentListItem,canInteract);
                if(bIsInParty)
                {
                    this.RefreshButton(this.m_PCLegend.PCBtnMid2,PCMid2Event,this.srInviteParty,this.InviteParty,bCanInteract && !this.IsGameFull());
                }
                else
                {
                    this.RefreshButton(this.m_PCLegend.PCBtnMid2,PCMid2Event,this.srInviteFriends,this.InviteFriends,bCanInteract && !this.IsGameFull());
                }
                SelectedMap = this.leftPage.contents.list.getItem(this.SETTING_MAP);
                if(SelectedMap.IsValueAvailable(SelectedMap.GetActiveValue()))
                {
                    this.RefreshButton(this.m_PCLegend.PCBtnRight,com.XInput.ButtonB,this.srBack,!bIsMPHost ? this.CancelMatchSettings : this.ConfirmMatchSettings,bCanInteract);
                }
                else
                {
                    this.RefreshButton(this.m_PCLegend.PCBtnRight,com.XInput.ButtonB,this.srBack,this.ConfirmMatchSettings,false);
                }
            }
            else
            {
                this.RefreshButton(_root.m_ControlY,0,"",undefined,false,true);
                this.RefreshButton(this.m_ControllerLegend.ControlY,com.XInput.ButtonY,this.srOptions,this.ShowOptionsScreen,bCanInteract,true);
                if(bIsInParty)
                {
                    this.RefreshButton(this.m_ControllerLegend.ControlX,com.XInput.ButtonX,this.srInviteParty,this.InviteParty,bCanInteract && !this.IsGameFull(),true);
                }
                else
                {
                    this.RefreshButton(this.m_ControllerLegend.ControlX,com.XInput.ButtonX,this.srInviteFriends,this.InviteFriends,bCanInteract && !this.IsGameFull(),true);
                }
                this.RefreshButton(this.m_ControllerLegend.ControlA,com.XInput.ButtonA,"",undefined,false,true);
                SelectedMap = this.leftPage.contents.list.getItem(this.SETTING_MAP);
                if(SelectedMap.IsValueAvailable(SelectedMap.GetActiveValue()))
                {
                    this.RefreshButton(this.m_ControllerLegend.ControlB,com.XInput.ButtonB,this.srBack,this.ConfirmMatchSettings,bCanInteract,true);
                }
                else
                {
                    this.RefreshButton(this.m_ControllerLegend.ControlB,com.XInput.ButtonB,this.srBack,this.ConfirmMatchSettings,false,true);
                }
            }
        }
        else if(!this.bUsingGamepad)
        {
            this.RefreshButton(_root.PCBtnCharacter,0,"",undefined,false);
            this.RefreshButton(this.m_PCLegend.PCBtnLeft,com.XInput.ButtonY,"",undefined,false);
            this.RefreshButton(this.m_PCLegend.PCBtnMid1,com.XInput.ButtonX,"",undefined,false);
            // Enter will confirm match settings, so will the button
            this.RefreshButton(undefined,com.XInput.ButtonA,"",this.ConfirmMatchSettings,bCanInteract);
            this.RefreshButton(this.m_PCLegend.PCBtnMid2,PCMid2Event,!bIsHostingNewMission ? this.srSearch : this.srConfirm,this.ConfirmMatchSettings,bCanInteract);
            this.RefreshButton(this.m_PCLegend.PCBtnRight,com.XInput.ButtonB,this.srCancel,this.CancelMatchSettings,bCanInteract);
        }
        else
        {
            this.RefreshButton(_root.m_ControlY, 0, "", undefined, false, true);
            this.RefreshButton(this.m_ControllerLegend.ControlY, com.XInput.ButtonY, "",undefined,false, true);
            this.RefreshButton(this.m_ControllerLegend.ControlX, com.XInput.ButtonX, "",undefined,false, true);
            this.RefreshButton(this.m_ControllerLegend.ControlA, com.XInput.ButtonA, !bIsHostingNewMission ? this.srSearch : this.srConfirm,this.ConfirmMatchSettings,bCanInteract,true);
            this.RefreshButton(this.m_ControllerLegend.ControlB, com.XInput.ButtonB, this.srCancel, this.CancelMatchSettings,bCanInteract,true);
        }
    }

    // made it so this does not rely on platform or current input mode, but a hardcoded bool of whether this button is a PC button or a controller button
    function RefreshButton(mcButton, nButtonID, sLabel, fnAction, bEnabled, bIsControllerButton)
    {
        mcButton._visible = fnAction != undefined;
        mcButton.text = sLabel;
        if(nButtonID != 0)
        {
            this.ActionMappings[nButtonID] = fnAction;
        }
        if(!bIsControllerButton)
        {
            mcButton.SetEnabled(bEnabled);
        }
        else
        {
            mcButton.Active = bEnabled;
        }
    }

    function RefreshPlayerList(list, bInteractive)
    {
        this.m_PlayerSlotCount = Math.max(0,Number(flash.external.ExternalInterface.call("GetNumPlayerSlots")));
        this.m_FirstVisibleSlot = Math.max(0,Math.min(this.m_FirstVisibleSlot,Math.max(0,this.m_PlayerSlotCount - 4)));
        if(this.m_SelectedPlayerSlot < 0)
        {
            this.m_SelectedPlayerSlot = Number(flash.external.ExternalInterface.call("GetPreviouslySelectedItem",LSS_Squad));
        }
        this.m_SelectedPlayerSlot = this.m_PlayerSlotCount == 0 ? -1 : Math.max(this.m_FirstVisibleSlot,Math.min(this.m_SelectedPlayerSlot,Math.min(this.m_PlayerSlotCount - 1,this.m_FirstVisibleSlot + 3)));
        this.m_BindingPlayerRows = true;
        // Deactivate before rebinding, even if the selected physical row is unchanged.
        list.selectedIndex = -1;
        var privateMatch = this.IsPrivateMatch();
        var row = 0;
        while(row < list.numItems)
        {
            var slot = this.m_FirstVisibleSlot + row;
            var card = list.getItem(row);
            card.m_slotIndex = slot;
            card._visible = slot < this.m_PlayerSlotCount;
            card.SetCustomIcon(-1);
            if(card._visible && Boolean(flash.external.ExternalInterface.call("IsPlayerSlotOccupied",slot)))
            {
                var basic = flash.external.ExternalInterface.call("GetPlayerSlotBasicInfo",slot);
                var patch = flash.external.ExternalInterface.call("GetPlayerSlotInfo_Patch",slot);
                basic.NumClassPromotions = patch.NumClassPromotions;
                basic.EmblemID = patch.EmblemID;
                basic.NumChallengesComplete = patch.NumChallengesComplete;
                list.SetSlotPlayer(row,basic);
            }
            else
            {
                list.SetSlotEmpty(row);
            }
            list.SetSlotPermission(row,privateMatch);
            row++;
        }
        list.SetInteractive(bInteractive);
        this.ApplyPlayerIcons(list);
        if(bInteractive)
        {
            list.selectedIndex = this.m_SelectedPlayerSlot - this.m_FirstVisibleSlot;
        }
        else
        {
            var i = 0;
            while(i < list.numItems)
            {
                list.getItem(i).active = false;
                // Empty cards use selection for their outline, not just a highlight.
                if(this.bUsingGamepad)
                {
                    list.getItem(i).selection._visible = !list.getItem(i).isOccupied;
                }
                i++;
            }
        }
        this.m_BindingPlayerRows = false;
        if(this.m_SelectedPlayerSlot >= 0)
        {
            flash.external.ExternalInterface.call("SetPreviouslySelectedItem",LSS_Squad,this.m_SelectedPlayerSlot);
        }
        this.RefreshPlayerScrollArrows();
        if(bInteractive)
        {
            this.RefreshCharacterSummary();
            this.RefreshButtonLegend();
        }
    }

    // MILAN CHANGE - 10/04/2026 - Mgamerz
    // The voice icon now shows what screen each player is on. IconData is indexed by lobby slot:
    // -1 for none, otherwise the index of the custom icon frame (custom0 - custom9).
    function RefreshAllCustomIcons(IconData)
    {
        this.m_CustomPlayerIcons = IconData;
        this.ApplyPlayerIcons(this.GetPlayerWindowList());
    }

    function RefreshPlayerInfo(page, bShowLevelUp)
    {
        var LocalPlayerBasicInfo = flash.external.ExternalInterface.call("GetLocalPlayerBasicInfo");
        var bCanLevelUp = Boolean(flash.external.ExternalInterface.call("CanLevelUp"));
        page.levelUpOverlay.LevelUpText.text = this.srLevelUp;
        page.levelUpOverlay._visible = bShowLevelUp && bCanLevelUp;
        page.playerInfo.characterName.textAutoSize = "shrink";
        page.playerInfo.characterName.text = LocalPlayerBasicInfo.PlayerName;
        page.playerInfo.levelAndClass.text = LocalPlayerBasicInfo.ClassData;
        page.playerInfo.credits.text = LocalPlayerBasicInfo.Credits;
    }

    function onButtonA(p_event)
    {
        this.ActionMappings[com.XInput.ButtonA].call(this);
    }

    // added to separately handle controller A/Enter and the PC mid 2 button press
    function onPCMid2(p_event)
    {
        this.ActionMappings[PCMid2Event].call(this);
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
        if(this.leftPage.contents.m_symbolName == this.PAGE_SQUAD)
        {
            this.MovePlayerSelection(-1);
            return;
        }
        var PageList = this.leftPage.contents.list;
        var PreviousItem;
        if(PageList != null)
        {
            PreviousItem = PageList.selectedIndex - 1;
            if(PageList.IsIndexValid(PreviousItem))
            {
                PageList.selectedIndex = PreviousItem;
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
        if(this.leftPage.contents.m_symbolName == this.PAGE_SQUAD)
        {
            this.MovePlayerSelection(1);
            return;
        }
        var PageList = this.leftPage.contents.list;
        var NextItem;
        if(PageList != null)
        {
            NextItem = PageList.selectedIndex + 1;
            if(PageList.IsIndexValid(NextItem))
            {
                PageList.selectedIndex = NextItem;
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
        flash.external.ExternalInterface.call("ShowGamercard",this.GetSelectedPlayerSlot());
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
        this.LoadTab(LSS_Character);
    }

    function HideCharacterScreen()
    {
        _global.SFX.PlayGUISound("MPCharacterExit");
        this.LoadTab(LSS_MultiplayerMenu);
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
        if(this.rightPage.contents.m_symbolName != this.PAGE_SQUAD || !this.CanScrollPlayers())
        {
            return;
        }
        this.m_PlayerViewPending = true;
        this.m_ScrollDirection = 0;

        this.m_PageTransitionType = this.PAGE_TRANSITION_SLIDE_LEFT;
        _global.SFX.PlayGUISound("MPSquadStart");
        this.LoadTab(LSS_Squad);
    }

    function HideSquadScreen()
    {
        if(this.leftPage.contents.m_symbolName != this.PAGE_SQUAD || !this.CanScrollPlayers())
        {
            return;
        }
        this.m_PlayerViewPending = true;
        this.m_ScrollDirection = 0;

        this.m_PageTransitionType = this.PAGE_TRANSITION_SLIDE_RIGHT;
        _global.SFX.PlayGUISound("MPSquadExit");
        this.LoadTab(LSS_Lobby);
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
        var bIsReady = Boolean(flash.external.ExternalInterface.call("IsReady"));
        flash.external.ExternalInterface.call("SetReady",!bIsReady);
    }

    function ToggleVoteToKickSelectedPlayer()
    {
        var bHasVotedToKickPlayerInSlot = Boolean(flash.external.ExternalInterface.call("HasVotedToKickPlayerInSlot",this.GetSelectedPlayerSlot()));
        flash.external.ExternalInterface.call("VoteToKickPlayerInSlot",this.GetSelectedPlayerSlot(),!HasVotedToKickPlayerInSlot);
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
        var bIsHostingNewMission = Boolean(flash.external.ExternalInterface.call("IsHostingNewMission"));
        return !bIsHostingNewMission ? this.srQuickMatch : this.srHostNewMission;
    }

    function ExitLobbyCancelled()
    {
        _root.screen.m_ControllerLegend.InputDisabled = false;
    }

    function ExitMultiplayerCancelled()
    {
        _root.screen.m_ControllerLegend.InputDisabled = false;
    }

    function GetPlayerWindowList()
    {
        if(this.leftPage.contents.m_symbolName == this.PAGE_SQUAD)
        {
            return this.leftPage.contents.list;
        }
        if(this.rightPage.contents.m_symbolName == this.PAGE_SQUAD)
        {
            return this.rightPage.contents.list;
        }
        return null;
    }

    function CanScrollPlayers()
    {
        return !this.m_PlayerViewPending && this.m_bConnected && !this.m_ControllerLegend.InputDisabled && this.GetPlayerWindowList().numItems > 0 && Boolean(flash.external.ExternalInterface.call("CanInteract"));
    }

    function GetSelectedPlayerSlot()
    {
        return this.leftPage.contents.list.selectedItem.m_slotIndex;
    }

    function ApplyPlayerIcons(list)
    {
        if(list == null)
        {
            return;
        }
        var row = 0;
        while(row < list.numItems)
        {
            var icon = this.m_CustomPlayerIcons[list.getItem(row).m_slotIndex];
            list.SetSlotCustomIcon(row,icon == undefined ? -1 : icon);
            row++;
        }
    }

    function RefreshPlayerScrollArrows()
    {
        var list = this.GetPlayerWindowList();
        if(list == null || list.numItems == 0)
        {
            return;
        }
        var page = list._parent;
        if(page.playerScrollUp == undefined)
        {
            page.attachMovie("MilanPlayerScrollArrow","playerScrollUp",page.getNextHighestDepth());
            page.attachMovie("MilanPlayerScrollArrow","playerScrollDown",page.getNextHighestDepth());
            page.playerScrollUp.addEventListener("ArrowPressed",this.MakeDelegate(this.ScrollPlayersUp));
            page.playerScrollDown.addEventListener("ArrowPressed",this.MakeDelegate(this.ScrollPlayersDown));
            page.playerScrollUp._rotation = -90;
            page.playerScrollDown._rotation = 90;
        }
        var first = list.getItem(0);
        var last = list.getItem(list.numItems - 1);
      // Keep the complete pulse inside the card strip, clear of the footer buttons.
      // Card pitch excludes selection glows and other decorative bounds.
        var cardPitch = list.numItems > 1 ? list.getItem(1)._y - first._y : 121.7;
        page.playerScrollUp._x = list._x + 420;
        page.playerScrollDown._x = list._x + 420;
        page.playerScrollUp._y = list._y + first._y + 18;
        page.playerScrollDown._y = list._y + last._y + cardPitch - 18;
        page.playerScrollUp.contents._x = 0;
        page.playerScrollUp.contents._y = 0;
        page.playerScrollDown.contents._x = 0;
        page.playerScrollDown.contents._y = 0;
        page.playerScrollUp.contents._xscale = 35;
        page.playerScrollUp.contents._yscale = 25;
        page.playerScrollDown.contents._xscale = 35;
        page.playerScrollDown.contents._yscale = 25;
        page.playerScrollUp.ShowStickIcon(false);
        page.playerScrollDown.ShowStickIcon(false);
        page.playerScrollUp.m_ScrollAvailable = this.m_FirstVisibleSlot > 0;
        page.playerScrollDown.m_ScrollAvailable = this.m_FirstVisibleSlot + 4 < this.m_PlayerSlotCount;
        page.playerScrollUp._visible = page.playerScrollUp.m_ScrollAvailable || page.playerScrollUp.m_ScrollFlashStart != undefined;
        page.playerScrollDown._visible = page.playerScrollDown.m_ScrollAvailable || page.playerScrollDown.m_ScrollFlashStart != undefined;
    }

    function ShiftPlayerWindow(delta)
    {
        if(!this.CanScrollPlayers())
        {
            return false;
        }
        var count = Math.max(0,Number(flash.external.ExternalInterface.call("GetNumPlayerSlots")));
        var next = Math.max(0,Math.min(this.m_FirstVisibleSlot + delta,Math.max(0,count - 4)));
        if(next == this.m_FirstVisibleSlot)
        {
            return false;
        }
        this.m_FirstVisibleSlot = next;
        this.RefreshPlayerList(this.GetPlayerWindowList(),this.leftPage.contents.m_symbolName == this.PAGE_SQUAD);
        this.FlashPlayerScrollArrow(delta);
        _global.SFX.PlayGUISound("SaveLoadMove");
        return true;
    }

    function ScrollPlayersUp()
    {
        this.ShiftPlayerWindow(-1);
    }

    function ScrollPlayersDown()
    {
        this.ShiftPlayerWindow(1);
    }

    function onMouseWheel(delta, target)
    {
        var list = this.GetPlayerWindowList();
        if(list == null || delta == 0)
        {
            return;
        }
        // Target ownership includes nested card clips and the two scroll arrows.
        var node = target;
        while(node != undefined && node != list._parent && node != _root)
        {
            node = node._parent;
        }
        if(node == list._parent || target == undefined && this.IsMouseOverPlayers())
        {
            this.ShiftPlayerWindow(delta > 0 ? -1 : 1);
        }
    }

    function IsMouseOverPlayers()
    {
        var list = this.GetPlayerWindowList();
        if(list == null)
        {
            return false;
        }
        var bounds = list.getBounds(list);
        return list._xmouse >= bounds.xMin && list._xmouse <= bounds.xMax && list._ymouse >= bounds.yMin && list._ymouse <= bounds.yMax;
    }

    function ScrollPlayersWheel(value)
    {
        if(!this.CanScrollPlayers() || !this.IsMouseOverPlayers())
        {
            return 0;
        }
        this.ShiftPlayerWindow(value > 0 ? -1 : 1);
        return 1;
    }

    function ScrollPlayersAnalog(value)
    {
        // BioGUI Y follows content movement: positive scrolls content up (later slots).
        // Match the game's MPStore DetailsScrollMarquee.ScrollPanel convention.
        var direction = Math.abs(value) < 0.35 ? 0 : (value > 0 ? 1 : -1);
        if(!this.CanScrollPlayers())
        {
            direction = 0;
        }
        if(direction != this.m_ScrollDirection)
        {
            this.m_ScrollDirection = direction;
            if(direction != 0)
            {
                this.ShiftPlayerWindow(direction);
            }
            this.m_NextScrollRepeat = getTimer() + 350;
        }
    }

    function TickPlayerInput()
    {
        this.UpdatePlayerScrollFeedback();
        // Keep occupied lobby cards unhighlighted without hiding empty-card borders.
        // Run while input is gated too: card timelines can replace selection clips.
        if(this.bUsingGamepad && this.rightPage.contents.m_symbolName == this.PAGE_SQUAD)
        {
            var list = this.GetPlayerWindowList();
            var row = 0;
            while(row < list.numItems)
            {
                list.getItem(row).selection._visible = !list.getItem(row).isOccupied;
                row++;
            }
        }
        if(!this.CanScrollPlayers())
        {
            this.m_ScrollDirection = 0;
            return;
        }
        if(this.m_ScrollDirection != 0 && getTimer() >= this.m_NextScrollRepeat)
        {
            this.ShiftPlayerWindow(this.m_ScrollDirection);
            this.m_NextScrollRepeat = getTimer() + 150;
        }
    }

    function SwitchPlayersViewAnalog(value)
    {
        var direction = Math.abs(value) < 0.55 ? 0 : (value > 0 ? 1 : -1);
        if(direction == this.m_ViewStickDirection)
        {
            return;
        }
        this.m_ViewStickDirection = direction;
        if(!this.CanScrollPlayers())
        {
            return;
        }
        if(direction > 0)
        {
            this.ShowSquadScreen();
        }
        else if(direction < 0)
        {
            this.HideSquadScreen();
        }
    }

    function MovePlayerSelection(delta)
    {
        if(!this.CanScrollPlayers())
        {
            return;
        }
        var count = Math.max(0,Number(flash.external.ExternalInterface.call("GetNumPlayerSlots")));
        var next = Math.max(0,Math.min(count - 1,this.m_SelectedPlayerSlot + delta));
        if(count == 0 || next == this.m_SelectedPlayerSlot)
        {
            return;
        }
        var previousWindow = this.m_FirstVisibleSlot;
        this.m_SelectedPlayerSlot = next;
        if(next < this.m_FirstVisibleSlot)
        {
            this.m_FirstVisibleSlot = next;
        }
        if(next >= this.m_FirstVisibleSlot + 4)
        {
            this.m_FirstVisibleSlot = next - 3;
        }
        this.RefreshPlayerList(this.GetPlayerWindowList(),true);
        if(this.m_FirstVisibleSlot != previousWindow)
        {
            this.FlashPlayerScrollArrow(this.m_FirstVisibleSlot - previousWindow);
        }
        _global.SFX.PlayGUISound("SaveLoadMove");
    }

    function onUnload()
    {
        clearInterval(this.m_PlayerInputTimer);
        Mouse.removeListener(this);
        Key.removeListener(this);
    }

    function FlashPlayerScrollArrow(delta)
    {
        var list = this.GetPlayerWindowList();
        if(list == null)
        {
            return;
        }
        var arrow = delta < 0 ? list._parent.playerScrollUp : list._parent.playerScrollDown;
        if(arrow == undefined)
        {
            return;
        }
        if(arrow.m_ScrollColor == undefined)
        {
            arrow.m_ScrollColor = new Color(arrow);
            arrow.m_NormalScrollColor = arrow.m_ScrollColor.getTransform();
        }
        arrow.m_ScrollFlashStart = getTimer();
        // Hold the pulse at its fully visible frame while the activation tint fades.
        arrow.contents.gotoAndStop(39);
        arrow._visible = true;
        this.UpdatePlayerScrollArrowFeedback(arrow);
    }

    function UpdatePlayerScrollArrowFeedback(arrow)
    {
        if(arrow == undefined || arrow.m_ScrollFlashStart == undefined)
        {
            return;
        }
        var elapsed = getTimer() - arrow.m_ScrollFlashStart;
        var normal = arrow.m_NormalScrollColor;
        if(elapsed >= 600)
        {
            arrow.m_ScrollColor.setTransform(normal);
            delete arrow.m_ScrollFlashStart;
            arrow.contents.play();
            arrow._visible = arrow.m_ScrollAvailable;
            return;
        }
        var amount = 1 - Math.max(0,elapsed - 120) / 480;
        arrow.m_ScrollColor.setTransform({ra:normal.ra * (1 - amount),ga:normal.ga * (1 - amount),ba:normal.ba * (1 - amount),rb:normal.rb * (1 - amount) + 255 * amount,gb:normal.gb * (1 - amount) + 180 * amount,bb:normal.bb * (1 - amount) + 64 * amount,aa:normal.aa,ab:normal.ab});
    }

    function UpdatePlayerScrollFeedback()
    {
        var list = this.GetPlayerWindowList();
        if(list == null)
        {
            return;
        }
        this.UpdatePlayerScrollArrowFeedback(list._parent.playerScrollUp);
        this.UpdatePlayerScrollArrowFeedback(list._parent.playerScrollDown);
    }
}
