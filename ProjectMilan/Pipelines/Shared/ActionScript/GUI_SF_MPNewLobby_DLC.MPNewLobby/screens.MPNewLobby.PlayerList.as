class screens.MPNewLobby.PlayerList extends screens.MPNewLobby.PageItemList
{
   var _parent;
   var _x;
   var getItem;
   var numItems;
   function PlayerList()
   {
      super();
   }
   function SetSlotPlayer(nSlotIndex, oPlayerDetails)
   {
      var _loc2_ = screens.MPNewLobby.PlayerItem(this.getItem(nSlotIndex));
      _loc2_.SetOccupied(oPlayerDetails);
   }
   function SetSlotEmpty(nSlotIndex)
   {
      var _loc2_ = screens.MPNewLobby.PlayerItem(this.getItem(nSlotIndex));
      _loc2_.SetEmpty();
   }
   function SetSlotPermission(nSlotIndex, bPrivate)
   {
      var _loc2_ = screens.MPNewLobby.PlayerItem(this.getItem(nSlotIndex));
      _loc2_.SetPermission(bPrivate);
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
      var _loc2_ = 0;
      while(_loc2_ < this.numItems)
      {
         this.getItem(_loc2_).SetInteractive(bInteractive);
         _loc2_ += 1;
      }
   }
   // MILAN CHANGE - 10/04/2026 - Mgamerz
   // Replaces the speaker icon call: sets the custom icon (the screen the player is on) for a lobby slot.
   function SetSlotCustomIcon(i, nIcon)
   {
      var _loc2_ = screens.MPNewLobby.PlayerItem(this.getItem(i));
      _loc2_.SetCustomIcon(nIcon);
   }
}
