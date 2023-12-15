class screens.Leaderboard.LeaderboardGUI extends com.SFXScreen
{
    var m_Table;
    var m_Scrollbar;
    var m_PCButtonExit;
    var m_PCButtonMe;
    var m_PCButtonTop;
    var m_PCButtonNextRB;
    var m_PCButtonPrevLB;
    var m_ConsoleButtons;
    var m_ConsoleRB;
    var m_ConsoleLB;
    var m_Title;
    var m_bDisplayingFriends;
    var srClose = "(NOLOC) Close";
    var srShowGamerCard = "(NOLOC) Gamer Card";
    var srMe = "(NOLOC) Me";
    var srTop = "(NOLOC) Top";
    var srNextLeaderboard = "(NOLOC) Next";
    var srPrevLeaderboard = "(NOLOC) Previous";
    var RESULT_NAME_INDEX = 0;
    function LeaderboardGUI()
    {
        super();
    }
    function Leaderboard()
    {
        super();
    }
    function onLoad()
    {
        super.onLoad();
        this.LoadStrings();
        this.m_Table.addEventListener("onLoad_Table",this.MakeDelegate(this.OnTableLoaded));
        this.m_Table.addEventListener("onListAnimationStart",this.MakeDelegate(this.OnTableListAnimationStart));
        this.m_Table.addEventListener("onListAnimationComplete",this.MakeDelegate(this.OnTableListAnimationComplete));
        this.m_Table.addEventListener("onShowGamerCard",this.MakeDelegate(this.ShowGamerCard));
    }
    function LoadStrings()
    {
        this.srClose = "$" + _global.SFX.GetIniString("srClose");
        this.srShowGamerCard = "$" + _global.SFX.GetIniString("srShowGamerCard");
        this.srMe = "$" + _global.SFX.GetIniString("srMe");
        this.srTop = "$" + _global.SFX.GetIniString("srTop");
        this.srNextLeaderboard = "$" + _global.SFX.GetIniString("srNextLeaderboard");
        this.srPrevLeaderboard = "$" + _global.SFX.GetIniString("srPrevLeaderboard");
    }
    function OnTableLoaded(p_event)
    {
        this.Initialize();
        if(!com.XPlatform.IsRunningInEngine())
        {
            var _loc2_ = undefined;
            var _loc4_ = undefined;
            var _loc5_ = undefined;
            var _loc3_ = 0;
            _loc5_ = new Array({Heading:"Rank",Width_Px:75},{Heading:"Name",Width_Px:250},{Heading:"Score",Width_Px:250});
            this.DefineColumns(_loc5_);
            _loc4_ = new Array();
            _loc3_ = 0;
            while(_loc3_ < 100)
            {
                _loc2_ = new Object();
                _loc2_.nRank = _loc3_;
                _loc2_.sRecordData = new Array();
                _loc2_.sRecordData.push("UserName_" + _loc3_);
                _loc2_.sRecordData.push(1000 + _loc3_);
                _loc4_.push(_loc2_);
                false;
                _loc3_ = _loc3_ + 1;
            }
            this.AddRecords(_loc4_);
        }
        flash.external.ExternalInterface.call("Ext_LeaderboardInitalized");
        this.m_Table.m_bOverrideSelectedRow = true;
    }
    function Initialize()
    {
        this.m_Table.setupScrollBar(this.m_Scrollbar);
        if(_global.SFX.Platform == com.XPlatform.PC || _global.SFX == undefined)
        {
            this.m_Scrollbar._visible = true;
            this.m_PCButtonExit._visible = true;
            this.m_PCButtonExit.text = this.srClose;
            this.m_PCButtonMe._visible = true;
            this.m_PCButtonMe.text = this.srMe;
            this.m_PCButtonTop._visible = true;
            this.m_PCButtonTop.text = this.srTop;
            this.m_PCButtonNextRB.text = this.srNextLeaderboard;
            this.m_PCButtonPrevLB.text = this.srPrevLeaderboard;
            this.m_ConsoleButtons._alpha = 0;
            this.m_ConsoleRB._visible = false;
            this.m_ConsoleLB._visible = false;
            this.m_PCButtonExit.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.onExitGui));
            this.m_PCButtonMe.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.onGoToMe));
            this.m_PCButtonTop.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.onGoToTop));
            this.m_PCButtonNextRB.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.onNextLeaderboard));
            this.m_PCButtonPrevLB.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.onPrevLeaderboard));
        }
        else
        {
            this.m_PCButtonExit._visible = false;
            this.m_PCButtonMe._visible = false;
            this.m_PCButtonTop._visible = false;
            this.m_PCButtonNextRB._visible = false;
            this.m_PCButtonPrevLB._visible = false;
            this.m_ConsoleButtons._alpha = 100;
            this.m_ConsoleRB._visible = true;
            this.m_ConsoleLB._visible = true;
            this.m_ConsoleButtons.addEventListener("onDPadUp",mx.utils.Delegate.create(this,this.onDPadUp));
            this.m_ConsoleButtons.addEventListener("onDPadDown",mx.utils.Delegate.create(this,this.onDPadDown));
            this.m_ConsoleButtons.addEventListener("onButtonB",mx.utils.Delegate.create(this,this.onExitGui));
            this.m_ConsoleButtons.addEventListener("onButtonX",mx.utils.Delegate.create(this,this.onGoToMe));
            this.m_ConsoleButtons.addEventListener("onButtonY",mx.utils.Delegate.create(this,this.onGoToTop));
            this.m_ConsoleButtons.addEventListener("onShoulderLeft",mx.utils.Delegate.create(this,this.onPrevLeaderboard));
            this.m_ConsoleButtons.addEventListener("onShoulderRight",mx.utils.Delegate.create(this,this.onNextLeaderboard));
            this.m_ConsoleButtons.addEventListener("onDPadLeft",mx.utils.Delegate.create(this,this.onInvalidInput));
            this.m_ConsoleButtons.addEventListener("onDPadRight",mx.utils.Delegate.create(this,this.onInvalidInput));
            this.m_ConsoleButtons.addEventListener("onButtonBack",mx.utils.Delegate.create(this,this.onInvalidInput));
            this.m_ConsoleButtons.addEventListener("onButtonStart",mx.utils.Delegate.create(this,this.onInvalidInput));
            this.m_ConsoleButtons.addEventListener("onThumbstickRight",mx.utils.Delegate.create(this,this.onInvalidInput));
            this.m_ConsoleButtons.addEventListener("onThumbstickLeft",mx.utils.Delegate.create(this,this.onInvalidInput));
            this.m_ConsoleButtons.addEventListener("onInvalidInput",mx.utils.Delegate.create(this,this.onInvalidInput));
            this.m_ConsoleButtons.addEventListener("onTriggerRight",mx.utils.Delegate.create(this,this.onInvalidInput));
            this.m_ConsoleButtons.addEventListener("onTriggerLeft",mx.utils.Delegate.create(this,this.onInvalidInput));
            this.m_ConsoleButtons.ControlB.text = this.srClose;
            this.m_ConsoleButtons.ControlX.text = this.srMe;
            this.m_ConsoleButtons.ControlY.text = this.srTop;
            if(_global.SFX.Platform == com.XPlatform.XBox)
            {
                this.m_ConsoleButtons.addEventListener("onButtonA",mx.utils.Delegate.create(this,this.onShowGamerCard));
                this.m_ConsoleButtons.ControlA.text = this.srShowGamerCard;
            }
            else
            {
                this.m_ConsoleButtons.addEventListener("onButtonA",mx.utils.Delegate.create(this,this.onInvalidInput));
                this.m_ConsoleButtons.ControlA.Hidden = true;
            }
            this.m_ConsoleButtons.addEventListener("ConsoleButtonGroupLoaded",mx.utils.Delegate.create(this,function()
            {
                this.m_ConsoleButtons.FitLeft();
            }
            ));
        }
    }
    function onDPadUp(p_event)
    {
        if(this.m_Table.selectedIndex > 0)
        {
            this.m_Table.selectedIndex = this.m_Table.selectedIndex - 1;
            _global.SFX.PlayGUISound("MPLeaderboardSelectUp");
        }
        else
        {
            this.onInvalidInput();
        }
    }
    function onDPadDown(p_event)
    {
        if(this.m_Table.selectedIndex < this.m_Table.dataProvider.length - 1)
        {
            this.m_Table.selectedIndex = this.m_Table.selectedIndex + 1;
            _global.SFX.PlayGUISound("MPLeaderboardSelectDown");
        }
        else
        {
            this.onInvalidInput();
        }
    }
    function onExitGui()
    {
        flash.external.ExternalInterface.call("ExitScreen");
    }
    function onNextLeaderboard()
    {
        _global.SFX.PlayGUISound("MPLeaderboardNext");
        this.m_Title.Scroll(false);
        flash.external.ExternalInterface.call("Ext_NextSecondaryIndex");
        this.m_Table.m_bOverrideSelectedRow = true;
    }
    function onPrevLeaderboard()
    {
        _global.SFX.PlayGUISound("MPLeaderboardPrior");
        this.m_Title.Scroll(true);
        flash.external.ExternalInterface.call("Ext_PrevSecondaryIndex");
        this.m_Table.m_bOverrideSelectedRow = true;
    }
    function onShowGamerCard()
    {
        _global.SFX.PlayGUISound("MPLeaderboardShowGamerCard");
        this.ShowGamerCard();
    }
    function onGoToMe()
    {
        if(!this.m_bDisplayingFriends)
        {
            flash.external.ExternalInterface.call("Ext_GetLeaderboardDataCentredOnLocalPlayer");
            this.m_Table.m_bOverrideSelectedRow = true;
            _global.SFX.PlayGUISound("MPLeaderboardSelectUp");
        }
        else
        {
            _global.SFX.PlayGUIError();
        }
    }
    function onGoToTop()
    {
        flash.external.ExternalInterface.call("Ext_GetNewLeaderboardData",1);
        this.m_Table.m_bOverrideSelectedRow = true;
        _global.SFX.PlayGUISound("MPLeaderboardSelectDown");
    }
    function onInvalidInput(p_event)
    {
        _global.SFX.PlayGUIError();
    }
    function DefineColumns(i_ColumnDefs)
    {
        var _loc3_ = 0;
        _loc3_ = 0;
        while(_loc3_ < i_ColumnDefs.length)
        {
            var _loc2_ = i_ColumnDefs[_loc3_];
            this.m_Table.AddColumn(_loc2_.Heading,_loc2_.Width_Px,_loc2_.HeaderMovieClip,_loc2_.RowEntryMovieClip);
            _loc3_ = _loc3_ + 1;
        }
        this.m_Table.ProcessColumns();
    }
    function AddRecords(i_Records, NumRanks, TopRank, RankToMoveTo, RankToSelect, bFriends)
    {
        var _loc10_ = String(flash.external.ExternalInterface.call("GetLocalUsername"));
        var _loc7_ = this.GetLocalUserRank(i_Records);
        var _loc2_ = 0;
        var _loc9_ = 0;
        var _loc8_ = 0;
        var _loc13_ = 0;
        _loc2_ = 0;
        while(_loc2_ < i_Records.length)
        {
            var _loc4_ = new Array();
            if(i_Records[_loc2_].nRank <= RankToSelect)
            {
                _loc9_ = _loc2_;
            }
            if(i_Records[_loc2_].nRank <= RankToMoveTo)
            {
                _loc8_ = _loc2_;
            }
            _loc4_.push(i_Records[_loc2_].nRank);
            _loc4_ = _loc4_.concat(i_Records[_loc2_].sRecordData);
            var _loc5_ = screens.Leaderboard.LeaderboardRow(this.m_Table.AddRow(_loc2_,_loc4_));
            var _loc6_ = Boolean(flash.external.ExternalInterface.call("NeedsNotification",i_Records[_loc2_].sRecordData[this.RESULT_NAME_INDEX]));
            if(_loc6_ && i_Records[_loc2_].sRecordData[this.RESULT_NAME_INDEX] != _loc10_ && _loc7_ >= 0)
            {
                if(i_Records[_loc2_].nRank > _loc7_)
                {
                    _loc5_.ShowDownArrow();
                }
                else
                {
                    _loc5_.ShowUpArrow();
                }
            }
            else
            {
                _loc5_.HideArrows();
            }
            _loc2_ = _loc2_ + 1;
        }
        _loc13_ = RankToMoveTo - _loc8_;
        this.m_Table.PostAddRows(NumRanks,TopRank,_loc8_,_loc9_);
        this.m_bDisplayingFriends = bFriends;
        this.m_PCButtonMe.SetEnabled(!this.m_bDisplayingFriends);
        this.m_ConsoleButtons.ControlX.SetEnabled(!this.m_bDisplayingFriends);
    }
    function GetLocalUserRank(Records)
    {
        var _loc4_ = String(flash.external.ExternalInterface.call("GetLocalUsername"));
        var _loc2_ = 0;
        while(_loc2_ < Records.length)
        {
            if(Records[_loc2_].sRecordData[this.RESULT_NAME_INDEX] == _loc4_)
            {
                return Records[_loc2_].nRank;
            }
            _loc2_ = _loc2_ + 1;
        }
        return -1;
    }
    function ClearHeader()
    {
        this.m_Table.ResetColumns();
    }
    function ClearRows()
    {
        this.m_Table.killMenu();
    }
    function SetLeaderboardHeaderText(sNewTitle)
    {
        this.m_Title.SetNextTitle(sNewTitle);
    }
    function OnTableListAnimationStart()
    {
        flash.external.ExternalInterface.call("Ext_CancelLeaderboardRequests");
    }
    function OnTableListAnimationComplete()
    {
        if(this.m_Table.needsNewData())
        {
            this.m_Table.PreStreamLeaderboard();
            var _loc2_ = undefined;
            if(this.m_Table.dataProvider[this.m_Table.movementRefElementIndex].data != null)
            {
                _loc2_ = this.m_Table.dataProvider[this.m_Table.movementRefElementIndex].data._data[0];
            }
            else
            {
                _loc2_ = this.m_Table.movementRefElementIndex + this.m_Table.m_RankOfTopEntry;
            }
            flash.external.ExternalInterface.call("Ext_GetNewLeaderboardData",_loc2_);
        }
    }
    function ShowGamerCard()
    {
        flash.external.ExternalInterface.call("Ext_ShowGamerCard",this.m_Table.selectedIndex);
    }
}
