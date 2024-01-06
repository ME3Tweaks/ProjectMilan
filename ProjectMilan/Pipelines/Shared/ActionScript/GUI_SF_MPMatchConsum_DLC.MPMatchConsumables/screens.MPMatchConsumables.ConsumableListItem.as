class screens.MPMatchConsumables.ConsumableListItem extends com.bioware.masseffect.controls.VListItem
{
    var ConsumableID;
    var Version;
    var m_Slot;
    var newTag;
    var m_disabled = false;
    function ConsumableListItem()
    {
        super();
    }
    function get NormalFrame()
    {
        return !!this.m_disabled ? "normalGrey" : "normal";
    }
    function get SelectedFrame()
    {
        return !!this.m_disabled ? "inGrey" : "in";
    }
    function get UnSelectedFrame()
    {
        return !!this.m_disabled ? "outGrey" : "out";
    }
    function get PressFrame()
    {
        return !!this.m_disabled ? "pressGrey" : "press";
    }
    function set Disabled(bVal)
    {
        if(this.m_disabled != bVal)
        {
            this.m_disabled = bVal;
            this.RefreshState();
        }
    }
    function get Disabled()
    {
        return this.m_disabled;
    }
    function RefreshState()
    {
        if(this._active)
        {
            this.gotoAndPlay(this.SelectedFrame);
        }
        else
        {
            this.gotoAndPlay(this.UnSelectedFrame);
        }
    }
    function Refresh(data)
    {
        var _loc4_ = _root.screen.m_ListCategoryFilter == _root.screen.SLOT_GEAR;
        this.ConsumableID = data.ConsumableID;
        this.Version = data.Version;
        this.m_Slot.title.textAutoSize = "shrink";
        this.m_Slot.title.text = data.Title;
        this.m_Slot.count.num.text = !data.Active ? data.Count : data.Count - 1;
        this.m_Slot.count.num._visible = !_loc4_ && this.m_Slot.count.num.text != "0";
        this.SetChecked(data.Active);
        this.newTag.text.text = _root.screen.srNew;
        this.newTag._visible = data.New;
    }
    function SetChecked(bChecked)
    {
        this.m_Slot.checkbox.gotoAndStop(!bChecked ? "off" : "on");
    }
    function onRollOver()
    {
		// MILAN CHANGE DropTheSquid 12/30/2023
		// make sure this does not fire while we are using the gamepad, even if you leave the (invisible) mouse hovering over it.
		// also not while the list is moving in general, which covers the same use case for scrolling with keyboard/mouse
		if (_root.screen.bUsingGamepad || _root.screen.bIgnoreMouseHover)
		{
			return;
		}
		// END MILAN
        super.onPress();
        super.onRelease();
        _global.SFX.PlayGUISound("MPMatchConsumablesChanged");
    }
    function onRollOut()
    {
		// MILAN CHANGE DropTheSquid 12/30/2023
		// make sure this does not fire while we are using the gamepad, even if you leave the (invisible) mouse hovering over it.
		// also not while the list is moving in general, which covers the same use case for scrolling with keyboard/mouse
		if (_root.screen.bUsingGamepad || _root.screen.bIgnoreMouseHover)
		{
			return;
		}
		// END MILAN
        this.parentList.unselectAllItems();
    }
    function onPress()
    {
        super.onRollOver();
    }
    function onRelease()
    {
        if(!this.Disabled)
        {
            super.onReleaseDblClick();
            _global.SFX.PlayGUISound("MPMatchConsumablesSelect");
        }
    }
    function onReleaseOutside()
    {
        super.onRollOut();
    }
    function onReleaseDblClick()
    {
    }
    function SetActive(bActive)
    {
        if(!bActive)
        {
            _root.screen.RefreshDescription();
        }
    }
}
