class screens.MPStore.StoreListItem extends com.bioware.masseffect.controls.VListItem
{
    var Title;
    var Promo;
    static var FullSelectFrame = "fullSelect";
    static var CostPanelFrames = new Array("credits","platform","creditsAndPlatform","none");
    function StoreListItem()
    {
        super();
    }
    function SetItemData(TitleText, PromoText)
    {
        this.Title.text = TitleText;
        if(PromoText != "")
        {
            this.Promo._visible = true;
            this.Promo.text.text = PromoText;
        }
        else
        {
            this.Promo._visible = false;
        }
    }
    function onRelease()
    {
        super.onRelease();
        _global.SFX.PlayGUISound("MPStoreChange");
    }
    function onRollOver()
    {
		// adding this so it doesn't react to hover if we are using controller or arrow keys. 
		if (_root.screen.bUsingGamepad || _root.screen.bIgnoreMouseHover)
		{
			return;
		}
        super.onRollOver();
        _global.SFX.PlayGUISound("MPStoreHover");
    }
	// adding this override to avoid showing the rollout animation when it will actually result in the hover quickly popping in briefly
	function onRollOut()
    {
		// do not show the rollout animation if we are already in the rolled out state
		if (this.m_mcBarOn._currentframe == 1 || this.m_mcBarOn._currentframe > 8)
		{
			return;
		}
		super.onRollOut();
    }
    function onReleaseOutside()
    {
        if(!com.bioware.masseffect.controls.VListItem.SuppressEvents)
        {
            super.onReleaseOutside();
            this.gotoAndPlay(this.UnSelectedFrame);
        }
    }
}
