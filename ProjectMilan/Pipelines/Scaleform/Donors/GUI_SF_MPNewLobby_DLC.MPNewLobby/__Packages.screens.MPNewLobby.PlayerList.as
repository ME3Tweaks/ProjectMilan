class screens.MPNewLobby.PlayerList extends screens.MPNewLobby.PageItemList
{
    var _parent;
    var _x;
    var numItems;

    function PlayerList()
    {
        super();
    }

    function SetSlotPlayer(nSlotIndex, oPlayerDetails)
    {
        var Slot = screens.MPNewLobby.PlayerItem(this.getItem(nSlotIndex));
        Slot.SetOccupied(oPlayerDetails);
    }

    function SetSlotEmpty(nSlotIndex)
    {
        var Slot = screens.MPNewLobby.PlayerItem(this.getItem(nSlotIndex));
        Slot.SetEmpty();
    }

    function SetSlotPermission(nSlotIndex, bPrivate)
    {
        var Slot = screens.MPNewLobby.PlayerItem(this.getItem(nSlotIndex));
        Slot.SetPermission(bPrivate);
    }

    function IsIndexValid(i)
    {
        return super.IsIndexValid(i);
    }

    function SetInteractive(bInteractive)
    {
        if(bInteractive)
        {
            this._x = 40;
        }
        this._parent.background._visible = !bInteractive;
        var idx = 0;
        while(idx < this.numItems)
        {
            this.getItem(idx).SetInteractive(bInteractive);
            idx += 1;
        }
    }

    // MILAN CHANGE - 10/04/2026 - Mgamerz
    // Replaces the speaker icon call: sets the custom icon (the screen the player is on) for a lobby slot.
    function SetSlotCustomIcon(i, nIcon)
    {
        var Slot = screens.MPNewLobby.PlayerItem(this.getItem(i));
        Slot.SetCustomIcon(nIcon);
    }
}
