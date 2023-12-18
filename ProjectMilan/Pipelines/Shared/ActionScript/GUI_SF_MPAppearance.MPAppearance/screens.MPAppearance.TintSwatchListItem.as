class screens.MPAppearance.TintSwatchListItem extends com.bioware.masseffect.controls.VListItem
{
    var Swatch1;
    var Swatch2;
    var Swatch3;
    var ColorPanelColorTransform;
    var m_SelectedCallback = null;
    var m_HoveredCallback = null;
    var m_HoveredEndCallback = null;
    var m_nSwatch1ID = -1;
    var m_nSwatch2ID = -1;
    var m_nSwatch3ID = -1;
    static var NormalFrame = "normal";
    static var HoverFrame = "hover";
    static var SelectedFrame = "selected";
    static var FullSelectFrame = "fullSelect";
    var m_bRolledOver = false;
    var m_RolledOverSwatch = null;
    function TintSwatchListItem()
    {
        super();
    }
    function SetSwatch1ID(nID)
    {
        this.m_nSwatch1ID = nID;
    }
    function SetSwatch2ID(nID)
    {
        this.m_nSwatch2ID = nID;
    }
    function SetSwatch3ID(nID)
    {
        this.m_nSwatch3ID = nID;
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
    function SetSwatch1Visible(bVisible)
    {
        this.Swatch1._visible = bVisible;
    }
    function SetSwatch2Visible(bVisible)
    {
        this.Swatch2._visible = bVisible;
    }
    function SetSwatch3Visible(bVisible)
    {
        this.Swatch3._visible = bVisible;
    }
    function SetSwatch1Color(fR, fG, fB)
    {
        this.ColorPanelColorTransform = new flash.geom.ColorTransform(fR,fG,fB,1,0,0,0,0);
        this.Swatch1.ColorPanel.transform.colorTransform = this.ColorPanelColorTransform;
    }
    function SetSwatch2Color(fR, fG, fB)
    {
        this.ColorPanelColorTransform = new flash.geom.ColorTransform(fR,fG,fB,1,0,0,0,0);
        this.Swatch2.ColorPanel.transform.colorTransform = this.ColorPanelColorTransform;
    }
    function SetSwatch3Color(fR, fG, fB)
    {
        this.ColorPanelColorTransform = new flash.geom.ColorTransform(fR,fG,fB,1,0,0,0,0);
        this.Swatch3.ColorPanel.transform.colorTransform = this.ColorPanelColorTransform;
    }
    function OnSwatch1RollOver()
    {
        if(this.m_HoveredCallback != null)
        {
            this.m_HoveredCallback({ID:this.m_nSwatch1ID,Swatch:this.Swatch1});
        }
    }
    function OnSwatch1RollOut()
    {
        if(this.m_HoveredEndCallback != null)
        {
            this.m_HoveredEndCallback({ID:this.m_nSwatch1ID,Swatch:this.Swatch1});
        }
    }
    function OnSwatch1Click()
    {
        if(this.m_SelectedCallback != null)
        {
            this.m_SelectedCallback({ID:this.m_nSwatch1ID,Swatch:this.Swatch1});
        }
    }
    function OnSwatch2RollOver()
    {
        if(this.m_HoveredCallback != null)
        {
            this.m_HoveredCallback({ID:this.m_nSwatch2ID,Swatch:this.Swatch2});
        }
    }
    function OnSwatch2RollOut()
    {
        if(this.m_HoveredEndCallback != null)
        {
            this.m_HoveredEndCallback({ID:this.m_nSwatch2ID,Swatch:this.Swatch2});
        }
    }
    function OnSwatch2Click()
    {
        if(this.m_SelectedCallback != null)
        {
            this.m_SelectedCallback({ID:this.m_nSwatch2ID,Swatch:this.Swatch2});
        }
    }
    function OnSwatch3RollOver()
    {
        if(this.m_HoveredCallback != null)
        {
            this.m_HoveredCallback({ID:this.m_nSwatch3ID,Swatch:this.Swatch3});
        }
    }
    function OnSwatch3RollOut()
    {
        if(this.m_HoveredEndCallback != null)
        {
            this.m_HoveredEndCallback({ID:this.m_nSwatch3ID,Swatch:this.Swatch3});
        }
    }
    function OnSwatch3Click()
    {
        if(this.m_SelectedCallback != null)
        {
            this.m_SelectedCallback({ID:this.m_nSwatch3ID,Swatch:this.Swatch3});
        }
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
        super.onRollOver();
        this.m_bRolledOver = true;
        this.FindAndProcessHoveredSwatch();
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
        super.onRollOut();
        this.m_bRolledOver = false;
        if(this.m_RolledOverSwatch != null)
        {
            if(this.m_RolledOverSwatch == this.Swatch1)
            {
                this.OnSwatch1RollOut();
            }
            else if(this.m_RolledOverSwatch == this.Swatch2)
            {
                this.OnSwatch2RollOut();
            }
            else if(this.m_RolledOverSwatch == this.Swatch3)
            {
                this.OnSwatch3RollOut();
            }
            this.m_RolledOverSwatch = null;
        }
    }
    function onMouseMove()
    {
        super.onMouseMove();
        this.FindAndProcessHoveredSwatch();
    }
    function FindAndProcessHoveredSwatch()
    {
        if(this.m_bRolledOver)
        {
            if(this.Swatch1.hitTest(_root._xmouse,_root._ymouse))
            {
                if(this.m_RolledOverSwatch != this.Swatch1)
                {
                    if(this.m_RolledOverSwatch == this.Swatch2)
                    {
                        this.OnSwatch2RollOut();
                    }
                    else if(this.m_RolledOverSwatch == this.Swatch3)
                    {
                        this.OnSwatch3RollOut();
                    }
                    this.m_RolledOverSwatch = this.Swatch1;
                    this.OnSwatch1RollOver();
                    _global.SFX.PlayGUISound("MPAppearanceSwatchChanged");
                }
            }
            else if(this.Swatch2.hitTest(_root._xmouse,_root._ymouse))
            {
                if(this.m_RolledOverSwatch != this.Swatch2)
                {
                    if(this.m_RolledOverSwatch == this.Swatch1)
                    {
                        this.OnSwatch1RollOut();
                    }
                    else if(this.m_RolledOverSwatch == this.Swatch3)
                    {
                        this.OnSwatch3RollOut();
                    }
                    this.m_RolledOverSwatch = this.Swatch2;
                    this.OnSwatch2RollOver();
                    _global.SFX.PlayGUISound("MPAppearanceSwatchChanged");
                }
            }
            else if(this.Swatch3.hitTest(_root._xmouse,_root._ymouse))
            {
                if(this.m_RolledOverSwatch != this.Swatch3)
                {
                    if(this.m_RolledOverSwatch == this.Swatch1)
                    {
                        this.OnSwatch1RollOut();
                    }
                    else if(this.m_RolledOverSwatch == this.Swatch2)
                    {
                        this.OnSwatch2RollOut();
                    }
                    this.m_RolledOverSwatch = this.Swatch3;
                    this.OnSwatch3RollOver();
                    _global.SFX.PlayGUISound("MPAppearanceSwatchChanged");
                }
            }
        }
    }
    function onRelease()
    {
        if(this.m_RolledOverSwatch != null)
        {
            if(this.m_RolledOverSwatch == this.Swatch1)
            {
                this.OnSwatch1Click();
                _global.SFX.PlayGUISound("MPAppearanceSwatchConfirm");
            }
            else if(this.m_RolledOverSwatch == this.Swatch2)
            {
                this.OnSwatch2Click();
                _global.SFX.PlayGUISound("MPAppearanceSwatchConfirm");
            }
            else if(this.m_RolledOverSwatch == this.Swatch3)
            {
                this.OnSwatch3Click();
                _global.SFX.PlayGUISound("MPAppearanceSwatchConfirm");
            }
        }
    }
}
