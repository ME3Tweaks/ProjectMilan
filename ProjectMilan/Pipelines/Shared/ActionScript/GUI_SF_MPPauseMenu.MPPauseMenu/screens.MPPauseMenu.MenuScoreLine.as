class screens.MPPauseMenu.MenuScoreLine extends com.bioware.masseffect.controls.buttonClasses.SFXButton
{
   var PlayerName;
   var PlayerScore;
   var PlayerPing;
   var LocalPlayerPlate;
   var IsLocal = false;
   var IsSelected = false;
   var NormalNameColor;
   var DeadNameColor;
   var _visible;
   function MenuScoreLine()
   {
      super();
   }
   function SetLineInfo(bVisible, sDisplayName, sScore, sPing, bLocal, bDead)
   {
      this._visible = bVisible;
      this.IsLocal = bLocal == true;
      // Keep the local-player background present independently of focus.
      this.LocalPlayerPlate._visible = bVisible && this.IsLocal;
      if(this.NormalNameColor == undefined)
      {
         this.NormalNameColor = this.PlayerName.textColor;
         var red = Math.round(((this.NormalNameColor >> 16) & 255) * 0.55);
         var green = Math.round(((this.NormalNameColor >> 8) & 255) * 0.55);
         var blue = Math.round((this.NormalNameColor & 255) * 0.55);
         this.DeadNameColor = (red << 16) | (green << 8) | blue;
      }
      this.PlayerName.textColor = bDead == true ? this.DeadNameColor : this.NormalNameColor;
      this.PlayerName.text = sDisplayName;
      this.PlayerName.textAutoSize = "shrink";
      this.PlayerName._x = -196.75;
      this.PlayerName._width = 184;
      this.PlayerScore.text = sScore;
      this.PlayerScore.textAutoSize = "shrink";
      this.PlayerScore._x = 1.75;
      this.PlayerScore._width = 80;
      this.PlayerPing._x = 100.75;
      this.PlayerPing._width = 96;
      this.PlayerPing.selectable = false;
      this.PlayerPing.text = sPing == undefined ? "" : sPing;
      this.PlayerPing.textAutoSize = "shrink";
      var pingMs = parseInt(sPing,10);
      if(!isNaN(pingMs) && pingMs > 250)
      {
         this.PlayerPing.textColor = 0xFF5555;
      }
      else if(!isNaN(pingMs) && pingMs >= 100)
      {
         this.PlayerPing.textColor = 0xFFD34D;
      }
      else
      {
         this.PlayerPing.textColor = this.NormalNameColor;
      }
   }
   function SetSelected(bSelected)
   {
      this.IsSelected = bSelected == true;
      this.LocalPlayerPlate._visible = this._visible && this.IsLocal;
   }
}
