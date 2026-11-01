class screens.MPAppearance.AppearanceMenuList extends com.bioware.masseffect.controls.VList
{
    var SetNumVisibleElements;
    var addListEntry;
    var length;
    var removeEntry;
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
        this.SetNumVisibleElements(NUM_VISIBLE_ELEMENTS);
    }
    function AddNewItem(Text, ItemState, alertText, SelectedCallback, ActivatedCallback)
    {
        var listItem;
        listItem = screens.MPAppearance.AppearanceMenuListItem(this.addListEntry(this.length,{index:this.length}));
        listItem.SetIndex(this.length - 1);
        listItem.SetText(Text);
        listItem.SetAlertText(alertText);
        switch(ItemState)
        {
            case APPEARANCE_ITEM_NORMAL:
                listItem.SetAlertVisible(false);
                listItem.SetEnabled(true);
                break;
            case APPEARANCE_ITEM_DISABLED:
                listItem.SetAlertVisible(false);
                listItem.SetEnabled(false);
                break;
            case APPEARANCE_ITEM_NEW:
                listItem.SetAlertVisible(true);
                listItem.SetEnabled(true);
        }
        listItem.SetSelectedCallback(SelectedCallback);
        listItem.SetActivatedCallback(ActivatedCallback);
        // MILAN CHANGE DropTheSquid 12/12/2023
        // adding a return so I can do something with it
        return listItem;
        // END MILAN
    }
    // adding this so that I can remove the item when switching input modes
    function removeLastItem()
    {
        this.removeEntry(this.length - 1);
    }
}
