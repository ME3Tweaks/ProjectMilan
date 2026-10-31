class com.ButtonGroup.ConsoleButtonGroup extends com.SFXInputMovieClip
{
    var dispatchEvent;
    var m_ControlA;
    var m_ControlB;
    var m_ControlBack;
    var m_ControlStart;
    var m_ControlX;
    var m_ControlY;
    var m_FitType;
    var m_OrderedButtons;
    static var FIT_NONE = 0;
    static var FIT_LEFT = 1;
    static var FIT_RIGHT = 2;
    function ConsoleButtonGroup()
    {
        super();
        this.m_FitType = FIT_NONE;
    }
    function onLoad()
    {
        super.onLoad();
        this.m_OrderedButtons = new Array();
        this.m_OrderedButtons.push(this.m_ControlY);
        this.m_OrderedButtons.push(this.m_ControlX);
        this.m_OrderedButtons.push(this.m_ControlA);
        this.m_OrderedButtons.push(this.m_ControlB);
        this.m_ControlY.addAsTextListener(this);
        this.m_ControlX.addAsTextListener(this);
        this.m_ControlA.addAsTextListener(this);
        this.m_ControlB.addAsTextListener(this);
        this.m_ControlY.addEventListener("onHiddenChanged",mx.utils.Delegate.create(this,this.onControlHidden));
        this.m_ControlX.addEventListener("onHiddenChanged",mx.utils.Delegate.create(this,this.onControlHidden));
        this.m_ControlA.addEventListener("onHiddenChanged",mx.utils.Delegate.create(this,this.onControlHidden));
        this.m_ControlB.addEventListener("onHiddenChanged",mx.utils.Delegate.create(this,this.onControlHidden));
        this.m_ControlY.addEventListener("onVisibleChanged",mx.utils.Delegate.create(this,this.onControlVisibleChanged));
        this.m_ControlX.addEventListener("onVisibleChanged",mx.utils.Delegate.create(this,this.onControlVisibleChanged));
        this.m_ControlA.addEventListener("onVisibleChanged",mx.utils.Delegate.create(this,this.onControlVisibleChanged));
        this.m_ControlB.addEventListener("onVisibleChanged",mx.utils.Delegate.create(this,this.onControlVisibleChanged));
        // Register Start button
        this.m_OrderedButtons.push(this.m_ControlStart);
        this.m_ControlStart.addAsTextListener(this);
        this.m_ControlStart.addEventListener("onHiddenChanged",mx.utils.Delegate.create(this,this.onControlHidden));
        this.m_ControlStart.addEventListener("onVisibleChanged",mx.utils.Delegate.create(this,this.onControlVisibleChanged));
        // Register Back button
        this.m_OrderedButtons.push(this.m_ControlBack);
        this.m_ControlBack.addAsTextListener(this);
        this.m_ControlBack.addEventListener("onHiddenChanged",mx.utils.Delegate.create(this,this.onControlHidden));
        this.m_ControlBack.addEventListener("onVisibleChanged",mx.utils.Delegate.create(this,this.onControlVisibleChanged));
        this.dispatchEvent({type:"ConsoleButtonGroupLoaded"});
    }
    function IsLoaded()
    {
        return this.m_OrderedButtons != undefined;
    }
    function get ControlY()
    {
        return this.m_ControlY;
    }
    function get ControlX()
    {
        return this.m_ControlX;
    }
    function get ControlA()
    {
        return _global.SFX.AdvanceButtonSwapped ? this.m_ControlB : this.m_ControlA;
    }
    function get ControlB()
    {
        return _global.SFX.AdvanceButtonSwapped ? this.m_ControlA : this.m_ControlB;
    }
    // Start and Back getters
    function get ControlStart()
    {
        return this.m_ControlStart;
    }
    function get ControlBack()
    {
        return this.m_ControlStart;
    }
    function set ControlY(x)
    {
    }
    function set ControlX(x)
    {
    }
    function set ControlA(x)
    {
    }
    function set ControlB(x)
    {
    }
    // Start and Back setters
    function set ControlStart(x)
    {
    }
    function set ControlBack(x)
    {
    }
    function Fit(FitType)
    {
        switch(FitType)
        {
            case FIT_LEFT:
                this.FitLeft();
                break;
            case FIT_RIGHT:
                this.FitRight();
            default:
                return;
        }
    }
    function FitRight()
    {
        if(this.m_OrderedButtons == undefined)
        {
            trace("ERROR: FitRight(): Console button group not loaded yet!");
            return undefined;
        }
        if(this.m_OrderedButtons.length < 1)
        {
            trace("ERROR: FitRight(): No buttons in the group!");
            return undefined;
        }
        this.m_FitType = FIT_RIGHT;
        var _loc2_;
        var _loc5_ = -1;
        var _loc3_ = this.m_OrderedButtons.length - 1;
        var _loc4_ = this.m_OrderedButtons[_loc3_]._x;
        _loc3_ = _loc3_ - 1;
        while(_loc3_ > _loc5_)
        {
            _loc2_ = com.ButtonGroup.ConsoleButton(this.m_OrderedButtons[_loc3_]);
            if(_loc2_ != null && _loc2_ != undefined && _loc2_.Hidden == false && _loc2_._visible == true)
            {
                _loc2_._x = _loc4_ - _loc2_.GetFitRectangle().width;
                _loc4_ = _loc2_._x;
            }
            _loc3_ = _loc3_ - 1;
        }
    }
    function FitLeft()
    {
        if(this.m_OrderedButtons == undefined)
        {
            trace("ERROR: FitLeft(): Console button group not loaded yet!");
            return undefined;
        }
        if(this.m_OrderedButtons.length < 1)
        {
            trace("ERROR: FitLeft(): No buttons in the group!");
            return undefined;
        }
        this.m_FitType = FIT_LEFT;
        var _loc3_ = 0;
        var _loc2_ = com.ButtonGroup.ConsoleButton(this.m_OrderedButtons[_loc3_]);
        var _loc4_ = _loc2_._x;
        var _loc5_ = this.m_OrderedButtons.length;
        while(_loc3_ < _loc5_)
        {
            _loc2_ = com.ButtonGroup.ConsoleButton(this.m_OrderedButtons[_loc3_]);
            if(_loc2_ != null && _loc2_ != undefined && _loc2_.Hidden == false && _loc2_._visible == true)
            {
                _loc2_._x = _loc4_;
                _loc4_ += _loc2_.GetFitRectangle().width;
            }
            _loc3_ = _loc3_ + 1;
        }
    }
    function onControlVisibleChanged(p_event)
    {
        p_event._Data = !p_event._Data;
        this.onControlHidden(p_event);
    }
    function onControlHidden(p_event)
    {
        this.Fit(this.m_FitType);
    }
    function onChanged(textfield_txt)
    {
        this.Fit(this.m_FitType);
    }
    function GetControlByName(sName)
    {
        var _loc2_ = null;
        if(sName.toUpperCase() == "A")
        {
            _loc2_ = this.ControlA;
        }
        else if(sName.toUpperCase() == "B")
        {
            _loc2_ = this.ControlB;
        }
        else if(sName.toUpperCase() == "X")
        {
            _loc2_ = this.ControlX;
        }
        else if(sName.toUpperCase() == "Y")
        {
            _loc2_ = this.ControlY;
        }
        else
        {
            trace("Requesting invalid control with name = " + sName);
        }
        return _loc2_;
    }
    function onKeyUp()
    {
        var _loc3_ = false;
        switch(Key.getCode())
        {
            case com.SFXInputMovieClip.ButtonA:
                _loc3_ = this.ControlA.Hidden || !this.ControlA.Active;
                break;
            case com.SFXInputMovieClip.ButtonB:
                _loc3_ = this.ControlB.Hidden || !this.ControlB.Active;
                break;
            case com.SFXInputMovieClip.ButtonX:
                _loc3_ = this.ControlX.Hidden || !this.ControlX.Active;
                break;
            case com.SFXInputMovieClip.ButtonY:
                _loc3_ = this.ControlY.Hidden || !this.ControlY.Active;
        }
        if(_loc3_)
        {
            this.dispatchEvent({type:"onInvalidInput"});
        }
        else
        {
            super.onKeyUp();
        }
    }
}
