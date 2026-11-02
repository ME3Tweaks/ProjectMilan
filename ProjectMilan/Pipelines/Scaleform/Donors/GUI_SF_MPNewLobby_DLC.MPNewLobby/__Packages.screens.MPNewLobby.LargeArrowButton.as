class screens.MPNewLobby.LargeArrowButton extends com.SFXMovieClip
{
    var contents;
    var dispatchEvent;
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
    // MILAN CHANGE DropTheSquid 12/29/2023
    // make sure this does not fire while we are using the gamepad, even if you leave the (invisible) mouse hovering over it.
        if(_root.screen.bUsingGamepad)
        {
            return;
        }
    // END MILAN
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
        this.contents.button.gotoAndPlay(this.NormalFrame);
        this.dispatchEvent({type:"ArrowReleased"});
    }
    function onReleaseOutside()
    {
        this.contents.button.gotoAndPlay(this.NormalFrame);
    }
}
