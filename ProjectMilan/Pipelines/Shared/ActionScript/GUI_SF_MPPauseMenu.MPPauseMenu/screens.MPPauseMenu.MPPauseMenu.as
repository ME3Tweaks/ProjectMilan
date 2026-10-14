class screens.MPPauseMenu.MPPauseMenu extends com.SFXScreen
{
   var MakeDelegate;
   var Menu;
   var gotoAndPlay;
   var gotoAndStop;
   static var FadeInFrame = "fadeIn";
   static var FadeOutFrame = "fadeOut";
   static var NormalFrame = "normal";
   static var HiddenFrame = "hidden";
   var bShouldAnimate = true;
   function MPPauseMenu()
   {
      super();
   }
   function onLoad()
   {
      super.onLoad();
      this.bShouldAnimate = Boolean(flash.external.ExternalInterface.call("ShouldAnimate"));
      if(this.bShouldAnimate)
      {
         this.gotoAndPlay(screens.MPPauseMenu.MPPauseMenu.FadeInFrame);
      }
      else
      {
         this.gotoAndPlay(screens.MPPauseMenu.MPPauseMenu.NormalFrame);
      }
      this.Menu.ButtonsMC.addEventListener("ReturnToGameButton",this.MakeDelegate(this.ExitScreen));
      this.Menu.ButtonsMC.addEventListener("OptionsButton",this.MakeDelegate(this.OpenOptions));
      this.Menu.ButtonsMC.addEventListener("ExitToLobbyButton",this.MakeDelegate(this.ExitMatch));
      this.Menu.ButtonsMC.addEventListener("InviteButton",this.MakeDelegate(this.InviteFriends));
   }
   function ExitScreen(p_event)
   {
      if(this.bShouldAnimate)
      {
         this.gotoAndPlay(screens.MPPauseMenu.MPPauseMenu.FadeOutFrame);
      }
      else
      {
         this.gotoAndStop(screens.MPPauseMenu.MPPauseMenu.HiddenFrame);
      }
   }
   function OnFadeOutComplete()
   {
      flash.external.ExternalInterface.call("Exit");
   }
   function OpenOptions()
   {
      flash.external.ExternalInterface.call("OpenOptions");
   }
   function ExitMatch()
   {
      flash.external.ExternalInterface.call("ExitMatch");
   }
   function InviteFriends()
   {
      flash.external.ExternalInterface.call("InviteFriends");
   }
}

