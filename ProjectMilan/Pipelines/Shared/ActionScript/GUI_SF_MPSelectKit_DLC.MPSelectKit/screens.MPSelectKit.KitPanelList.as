class screens.MPSelectKit.KitPanelList extends com.bioware.masseffect.controls.VList
{
    static var NUM_VISIBLE_ELEMENTS = 5;
    function KitPanelList()
    {
        super();
        this.scrollMode = com.bioware.masseffect.controls.VList.SCROLLMODE_HORIZONTAL;
        this.SetNumVisibleElements(screens.MPSelectKit.KitPanelList.NUM_VISIBLE_ELEMENTS);
    }
    function get listItemExportID()
    {
        return "KitPanelItem";
    }
	// MILAN CHANGE DropTheSquid 12/19/2023
	// overriding this function which is called every frame during list animation to allow
	// items to fade in and out on the edge of the list. This lets us also fade in/out and move the PC info button
	function recalculateListItemAlphaAndEnabled()
	{
		// _root.screen.LogFromAS("recalculateListItemAlphaAndEnabled");
		super.recalculateListItemAlphaAndEnabled();
		var i = 0;
        while(i < this.m_counter)
        {
            item = this._dataProvider[i];
			item.refreshPCInfoButton();
            i = i + 1;
        }
	}
	// END MILAN
}
