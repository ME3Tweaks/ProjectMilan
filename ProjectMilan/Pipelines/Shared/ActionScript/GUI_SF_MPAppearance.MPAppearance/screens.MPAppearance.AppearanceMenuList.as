class screens.MPAppearance.AppearanceMenuList extends com.bioware.masseffect.controls.VList
{
    static var NUM_VISIBLE_ELEMENTS = 8;
    static var APPEARANCE_ITEM_NORMAL = 0;
    static var APPEARANCE_ITEM_DISABLED = 1;
    static var APPEARANCE_ITEM_NEW = 2;
    function AppearanceMenuList()
    {
        super();
    }
    function get listItemExportID()
    {
        return "AppearanceMenuListItem";
    }
    function onLoad()
    {
        super.onLoad();
        this.SetNumVisibleElements(screens.MPAppearance.AppearanceMenuList.NUM_VISIBLE_ELEMENTS);
    }
    function AddNewItem(Text, ItemState, alertText, SelectedCallback, ActivatedCallback)
    {
        var _loc2_ = undefined;
        _loc2_ = screens.MPAppearance.AppearanceMenuListItem(this.addListEntry(this.length,{index:this.length}));
        _loc2_.SetIndex(this.length - 1);
        _loc2_.SetText(Text);
        _loc2_.SetAlertText(alertText);
        switch(ItemState)
        {
            case screens.MPAppearance.AppearanceMenuList.APPEARANCE_ITEM_NORMAL:
                _loc2_.SetAlertVisible(false);
                _loc2_.SetEnabled(true);
                break;
            case screens.MPAppearance.AppearanceMenuList.APPEARANCE_ITEM_DISABLED:
                _loc2_.SetAlertVisible(false);
                _loc2_.SetEnabled(false);
                break;
            case screens.MPAppearance.AppearanceMenuList.APPEARANCE_ITEM_NEW:
                _loc2_.SetAlertVisible(true);
                _loc2_.SetEnabled(true);
        }
        _loc2_.SetSelectedCallback(SelectedCallback);
        _loc2_.SetActivatedCallback(ActivatedCallback);
		// MILAN CHANGE DropTheSquid 12/12/2023
		// adding a return so I can do something with it
		return _loc2_;
		// END MILAN
    }
	// adding this so that I can remove the item when switching input modes
	function removeLastItem()
	{
		this.removeEntry(this.length - 1);
	}
}
