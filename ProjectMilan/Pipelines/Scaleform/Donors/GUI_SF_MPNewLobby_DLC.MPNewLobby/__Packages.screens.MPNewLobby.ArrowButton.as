class screens.MPNewLobby.ArrowButton extends com.bioware.masseffect.controls.buttonClasses.SFXButton
{
    var RollOverFrame = "rollover";
    var PressFrame = "press";
    var ReleaseFrame = "normal";
    var ReleaseOutsideFrame = "normal";
    var RollOutFrame = "normal";
    function ArrowButton()
    {
        super();
    }
    function onRollOver()
    {
        // MILAN CHANGE DropTheSquid 12/29/2023
        // make sure this does not fire while we are using the gamepad, even if you leave the (invisible) mouse hovering over it.
        if (_root.screen.bUsingGamepad)
        {
            return;
        }
        // END MILAN
        super.onRollOver();
    }
}
