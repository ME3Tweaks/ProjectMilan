class screens.MPMatchConsumables.SlotItem extends com.SFXMovieClip
{
    var NormalColorTransform;
    var DisabledColorTransform;
    var slotText;
    var newTag;
    var empty;
    var image;
    var m_Action;
    var NormalFrame = "normal";
    var SelectedFrame = "on";
    var PressedFrame = "pressed";
    var m_Selected = false;
    var m_Pressed = false;
    var m_bHasAnyAvailable = false;
    function SlotItem()
    {
        super();
    }
    function onLoad()
    {
        super.onLoad();
        this.NormalColorTransform = new flash.geom.ColorTransform(1,1,1,1,0,0,0,0);
        this.DisabledColorTransform = new flash.geom.ColorTransform(0,0,0,1,100,100,100,0);
        _root.screen.OnSlotLoaded();
    }
    function Initialize(slotID, slotName)
    {
        this.m_bHasAnyAvailable = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetConsumableListFilteredBySlot_DLC",slotID)).length > 0;
        var _loc3_ = Boolean(flash.external.ExternalInterface.call("HasNewConsumablesOfSlotType",slotID));
        this.slotText.slotName.text = slotName;
        this.newTag.text.text = _root.screen.srNew;
        this.newTag._visible = _loc3_;
        if(this.m_bHasAnyAvailable)
        {
            this.empty.text = _root.screen.srEmpty;
            this.transform.colorTransform = this.NormalColorTransform;
        }
        else
        {
            this.empty.text = _root.screen.srNone;
            this.transform.colorTransform = this.DisabledColorTransform;
        }
        this.SetConsumable(null);
    }
    function SetConsumable(consumable)
    {
        if(consumable == undefined || consumable == null)
        {
            this.slotText.powerName._visible = false;
            this.image._visible = false;
            this.empty._visible = true;
        }
        else
        {
            this.slotText.powerName.textAutoSize = "shrink";
            this.slotText.powerName.text = consumable.Title;
            this.slotText.powerName._visible = true;
            this.image.Async = true;
            this.image.ResourceString = consumable.Image;
            this.image.UsePlaceholderSize();
            this.image.RegistrationPoint = com.bioware.masseffect.controls.ResourceLoader.REGISTRATION_TOP_LEFT;
            this.image.HAlign = com.bioware.masseffect.controls.ResourceLoader.ALIGN_CENTER;
            this.image.VAlign = com.bioware.masseffect.controls.ResourceLoader.ALIGN_CENTER;
            this.image.FadeIn = false;
            this.image.FadeOut = false;
            this.image._visible = true;
            this.empty._visible = false;
        }
    }
    function Refresh()
    {
        if(this.m_Pressed)
        {
            this.gotoAndStop(this.PressedFrame);
        }
        else if(this.m_Selected)
        {
            this.gotoAndStop(this.SelectedFrame);
        }
        else
        {
            this.gotoAndStop(this.NormalFrame);
        }
    }
    function set selected(b)
    {
        this.m_Selected = b;
        if(!b)
        {
            this.m_Pressed = false;
        }
        this.Refresh();
    }
    function get selected()
    {
        return this.m_Selected;
    }
    function set pressed(b)
    {
        this.m_Pressed = b;
        this.Refresh();
    }
    function get pressed()
    {
        return this.m_Pressed;
    }
    function set action(f)
    {
        this.m_Action = f;
    }
    function get action()
    {
        return this.m_Action;
    }
    function Activate()
    {
        if(this.m_Action != null && this.m_bHasAnyAvailable)
        {
            _global.SFX.PlayGUISound("MPMatchConsumablesGroupSelect");
            this.m_Action();
        }
        else
        {
            _global.SFX.PlayGUIError();
        }
    }
    function onRollOver()
    {
		// MILAN CHANGE DropTheSquid 12/30/2023
		// make sure this does not fire while we are using the gamepad, even if you leave the (invisible) mouse hovering over it.
		if (_root.screen.bUsingGamepad || _root.screen.bIgnoreMouseHover)
		{
			return;
		}
		// END MILAN
        this.selected = true;
        _global.SFX.PlayGUISound("MPMatchConsumablesGroupChanged");
    }
    function onRollOut()
    {
		// MILAN CHANGE DropTheSquid 12/30/2023
		// make sure this does not fire while we are using the gamepad, even if you leave the (invisible) mouse hovering over it.
		if (_root.screen.bUsingGamepad || _root.screen.bIgnoreMouseHover)
		{
			return;
		}
		// END MILAN
        this.selected = false;
    }
    function onPress()
    {
        this.pressed = true;
    }
    function onRelease()
    {
        this.Activate();
        this.pressed = false;
    }
    function onReleaseOutside()
    {
        this.pressed = false;
        this.selected = false;
    }
}
