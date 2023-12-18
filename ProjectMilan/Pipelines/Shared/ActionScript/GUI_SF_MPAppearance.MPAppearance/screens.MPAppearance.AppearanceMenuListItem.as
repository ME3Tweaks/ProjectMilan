class screens.MPAppearance.AppearanceMenuListItem extends com.bioware.masseffect.controls.VListItem
{
    var LevelUpImage;
    var contents;
    var alert;
    var parentList;
    var active;
    var PressFrame;
    var SelectedFrame;
    var UnSelectedFrame;
    var m_bPressed = false;
    var m_bHovered = false;
    var m_bEnabled = true;
    var m_ActivatedCalback = null;
    var m_SelectedCallback = null;
    var m_HoveredCallback = null;
    var m_HoveredEndCallback = null;
    var m_nID = -1;
    var m_nIndex = -1;
    function AppearanceMenuListItem()
    {
        super();
        this._LISTSPACING = -14;
        this.LevelUpImage._alpha = 0;
    }
    function get NormalFrame()
    {
        return !this.m_bEnabled ? "normalGrey" : "normal";
    }
    function get SelectedFrame()
    {
        return !this.m_bEnabled ? "inGrey" : "in";
    }
    function get UnSelectedFrame()
    {
        return !this.m_bEnabled ? "outGrey" : "out";
    }
    function get PressFrame()
    {
        return !this.m_bEnabled ? "pressGrey" : "press";
    }
    function onLoad()
    {
        this.Refresh();
        this.SetLevelUpVisible(false);
    }
    function SetID(nID)
    {
        this.m_nID = nID;
    }
    function SetIndex(nIndex)
    {
        this.m_nIndex = nIndex;
    }
    function SetText(Text)
    {
        this.contents.title.text = Text;
    }
    function SetLevelUpVisible(bVisible)
    {
        this.LevelUpImage._alpha = 100;
        this.LevelUpImage._visible = bVisible;
    }
    function SetAlertVisible(bVisible)
    {
        this.alert._visible = bVisible;
    }
    function SetAlertText(Text)
    {
        this.alert.title.text = Text;
    }
    function IsEnabled()
    {
        return this.m_bEnabled;
    }
    function Activate()
    {
        this.parentList.selectedItem = this;
        if(this.m_ActivatedCalback != null)
        {
            this.m_ActivatedCalback(this.m_nID,this.m_nIndex);
        }
    }
    function SetEnabled(bEnabled)
    {
        this.m_bEnabled = bEnabled;
        this.Refresh();
    }
    function SetSelectedCallback(callback)
    {
        this.m_SelectedCallback = callback;
    }
    function SetHoveredCallback(callback)
    {
        this.m_HoveredCallback = callback;
    }
    function SetHoveredEndCallback(callback)
    {
        this.m_HoveredEndCallback = callback;
    }
    function SetActivatedCallback(callback)
    {
        this.m_ActivatedCalback = callback;
    }
    function Refresh()
    {
        if(this.m_bHovered || this.parentList.selectedItem == this && this.active)
        {
            if(this.m_bPressed)
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
    function onPress()
    {
        super.onPress();
        this.m_bPressed = true;
        this.Refresh();
    }
    function onRelease()
    {
        this.Activate();
        _global.SFX.PlayGUISound("MPAppearanceMenuItemSelected");
        this.m_bPressed = false;
        this.Refresh();
    }
    function onReleaseOutside()
    {
        this.m_bPressed = false;
        this.Refresh();
    }
    function onRollOver()
    {
		// MILAN CHANGE DropTheSquid 12/18/2023
		// make sure this does not fire while we are using the gamepad, even if you leave the (invisible) mouse hovering over it.
		if (_root.screen.bUsingGamepad)
		{
			return;
		}
		// END MILAN
        this.m_bHovered = true;
        if(this.m_HoveredCallback != null)
        {
            this.m_HoveredCallback(this.m_nID,this.m_nIndex);
        }
        this.Refresh();
        _global.SFX.PlayGUISound("MPAppearanceMenuItemHover");
    }
    function onRollOut()
    {
		// MILAN CHANGE DropTheSquid 12/18/2023
		// make sure this does not fire while we are using the gamepad, even if you leave the (invisible) mouse hovering over it.
		if (_root.screen.bUsingGamepad)
		{
			return;
		}
		// END MILAN
        this.m_bHovered = false;
        this.m_bPressed = false;
        if(this.m_HoveredEndCallback != null)
        {
            this.m_HoveredEndCallback(this.m_nID,this.m_nIndex);
        }
        this.Refresh();
    }
    function TriggerItemSelectionCallback()
    {
        if(this.m_SelectedCallback != null)
        {
            this.m_SelectedCallback(this.m_nID,this.m_nIndex);
        }
    }
    function SetActive(bActive)
    {
        if(bActive && this.m_SelectedCallback != null)
        {
            this.m_SelectedCallback(this.m_nID,this.m_nIndex);
        }
    }
}
