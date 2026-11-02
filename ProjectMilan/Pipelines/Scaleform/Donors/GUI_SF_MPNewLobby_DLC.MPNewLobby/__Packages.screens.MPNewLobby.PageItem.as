class screens.MPNewLobby.PageItem extends com.SFXMovieClip
{
    var LevelUpImage;
    var _parent;
    var alert;
    var gotoAndPlay;
    var m_action;
    var m_rolloverAction;
    var m_slotIndex;
    var SelectOnRollover = true;
    var m_disabled = false;
    var m_active = false;
    var m_pressed = false;
    var m_listIndex = -1;
    function PageItem()
    {
        super();
        this.LevelUpImage._visible = false;
        this.alert._visible = false;
    }
    function get NormalFrame()
    {
        return this.m_disabled ? "normalGrey" : "normal";
    }
    function get SelectedFrame()
    {
        return this.m_disabled ? "inGrey" : "in";
    }
    function get UnSelectedFrame()
    {
        return this.m_disabled ? "outGrey" : "out";
    }
    function get PressFrame()
    {
        return this.m_disabled ? "pressGrey" : "press";
    }
    function Refresh()
    {
        if(this.m_active)
        {
            if(this.m_pressed)
            {
                this.gotoAndPlay(this.PressFrame);
            }
            else
            {
                this.gotoAndPlay(this.SelectedFrame);
            }
        }
        else
        {
            this.gotoAndPlay(this.UnSelectedFrame);
        }
    }
    function set disabled(d)
    {
        if(d != this.m_disabled)
        {
            this.m_disabled = d;
            this.Refresh();
        }
    }
    function get disabled()
    {
        return this.m_disabled;
    }
    function set active(a)
    {
        var CurrentLobbyTab;
        if(a != this.m_active)
        {
            this.m_active = a;
            this.Refresh();
            if(this.m_active)
            {
                if(this.m_rolloverAction != null)
                {
                    this.m_rolloverAction.call(this,this.m_listIndex);
                }
                if(this._parent == _root.screen.leftPage.contents.list)
                {
                    CurrentLobbyTab = Number(flash.external.ExternalInterface.call("GetCurrentLobbyTab"));
                    flash.external.ExternalInterface.call("SetPreviouslySelectedItem",CurrentLobbyTab,this.m_slotIndex == undefined ? this.m_listIndex : this.m_slotIndex);
                }
            }
        }
    }
    function get active()
    {
        return this.m_active;
    }
    function set rolloverAction(f)
    {
        this.m_rolloverAction = f;
    }
    function get rolloverAction()
    {
        return this.m_rolloverAction;
    }
    function set action(f)
    {
        this.m_action = f;
    }
    function get action()
    {
        return this.m_action;
    }
    function activate()
    {
        if(this.m_action != null)
        {
            this.m_action.call();
        }
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
        _global.SFX.PlayGUISound("MPLobbyPageItemChange");
        if(this.SelectOnRollover)
        {
            this._parent.selectedIndex = this.m_listIndex;
        }
    }
    function onRollOut()
    {
    }
    function onPress()
    {
        this.m_pressed = true;
        if(!this.SelectOnRollover)
        {
            this._parent.selectedIndex = this.m_listIndex;
        }
        this.Refresh();
    }
    function onRelease()
    {
        if(this.m_active)
        {
            this.activate();
        }
        this.m_pressed = false;
        this.Refresh();
    }
    function onReleaseOutside()
    {
        this.m_pressed = false;
        this.Refresh();
    }
    function SetAlert(bVisible, sAlertText)
    {
        this.alert._visible = bVisible;
        this.alert.title.text = sAlertText;
    }
    function SetLevelUpIcon(bVisible)
    {
        this.LevelUpImage._visible = bVisible;
    }
}
