class screens.MPNewLobby.LargeArrowButton extends com.SFXMovieClip
{
    var contents;
    var NormalFrame = "normal";
    var RolloverFrame = "press";
    var PressFrame = "rollover";
    function LargeArrowButton()
    {
        super();
    }
    function onLoad()
    {
        super.onLoad();
        this.ShowStickIcon(false);
    }
    function ShowStickIcon(bShow)
    {
        if(bShow)
        {
            this.contents.Darken._visible = true;
            this.contents.icon._visible = true;
        }
        else
        {
            this.contents.Darken._visible = false;
            this.contents.icon._visible = false;
        }
    }
    function onRollOver()
    {
		// MILAN CHANGE DropTheSquid 12/19/2023
		// prevent it from getting hovered again under the invisible mouse
		if(_root.screen.bUsingGamepad)
		{
			return;
		}
		// END Milan
        this.contents.button.gotoAndPlay(this.RolloverFrame);
    }
    function onRollOut()
    {
        this.contents.button.gotoAndPlay(this.NormalFrame);
    }
    function onPress()
    {
        this.contents.button.gotoAndPlay(this.PressFrame);
        this.dispatchEvent({type:"ArrowPressed"});
    }
    function onRelease()
    {
		// MILAN CHANGE DropTheSquid 12/19/2023
		// this only gets pressed when you are already hovering it, so it makes sense to go back to the hovering frame
        this.contents.button.gotoAndPlay(this.RolloverFrame);
		// END MILAN
        this.dispatchEvent({type:"ArrowReleased"});
    }
    function onReleaseOutside()
    {
        this.contents.button.gotoAndPlay(this.NormalFrame);
    }
}
