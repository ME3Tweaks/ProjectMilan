// This does not get automatically compiled into the build. It is only included for documentation and a building point for further changes
// we can include comments and more intuitive syntax without it going through the compiler/decompiler cycle of JPEXS
class screens.MPSelectKit.KitPanelItem extends com.bioware.masseffect.controls.VListItem
{
    var LockedImage;
    var LockedText;
    var UndeployedImage;
    var UndeployedText;
    var LevelUpImage;
    var LevelUpText;
    var IconBackground;
    var KitItemHitArea;
    var Portrait;
    var PortraitLocked;
    var m_CharacterImageRef;
    var m_PowerIcon1Resource;
    var m_PowerIcon1Index;
    var PowerBar;
    var m_PowerName1;
    var m_PowerIcon2Resource;
    var m_PowerIcon2Index;
    var m_PowerName2;
    var m_PowerIcon3Resource;
    var m_PowerIcon3Index;
    var m_PowerName3;
    var KitName;
    var CharacterName;
    var m_mcBarOn;
    var _data;
    static var ICON_STATE_NONE = 0;
    static var ICON_STATE_LOCKED = 1;
    static var ICON_STATE_UNDEPLOYED = 2;
    static var ICON_STATE_LEVELUP = 3;
    var m_IconState = screens.MPSelectKit.KitPanelItem.ICON_STATE_NONE;
    var m_bHovered = false;
    function KitPanelItem()
    {
        super();
        this._LISTSPACING = -135;
    }
    function RefreshIconState()
    {
        this.LockedImage._visible = this.m_IconState == screens.MPSelectKit.KitPanelItem.ICON_STATE_LOCKED;
        this.LockedText._visible = this.m_IconState == screens.MPSelectKit.KitPanelItem.ICON_STATE_LOCKED;
        this.UndeployedImage._visible = this.m_IconState == screens.MPSelectKit.KitPanelItem.ICON_STATE_UNDEPLOYED;
        this.UndeployedText._visible = this.m_IconState == screens.MPSelectKit.KitPanelItem.ICON_STATE_UNDEPLOYED;
        this.LevelUpImage._visible = this.m_IconState == screens.MPSelectKit.KitPanelItem.ICON_STATE_LEVELUP;
        this.LevelUpText._visible = this.m_IconState == screens.MPSelectKit.KitPanelItem.ICON_STATE_LEVELUP;
        this.IconBackground._visible = this.m_IconState != screens.MPSelectKit.KitPanelItem.ICON_STATE_NONE;
    }
    function onLoad()
    {
        super.onLoad();
        this.hitArea = this.KitItemHitArea;
        this.KitItemHitArea._alpha = 0;
        this.Portrait.PreserveAspectRatio = false;
        this.Portrait.FadeIn = true;
        this.Portrait.FadeOut = false;
        this.Portrait.Async = true;
        if(this.m_IconState == screens.MPSelectKit.KitPanelItem.ICON_STATE_LOCKED)
        {
            this.Portrait.ResourceString = "";
            this.PortraitLocked.ResourceString = this.m_CharacterImageRef;
        }
        else
        {
            this.Portrait.ResourceString = this.m_CharacterImageRef;
            this.PortraitLocked.ResourceString = "";
        }
        this.PowerBar.PowerIcon1.SetIcon(this.m_PowerIcon1Resource,this.m_PowerIcon1Index);
        this.PowerBar.PowerIcon1.power.textAutoSize = "shrink";
        this.PowerBar.PowerIcon1.power.text = this.m_PowerName1;
        this.PowerBar.PowerIcon2.SetIcon(this.m_PowerIcon2Resource,this.m_PowerIcon2Index);
        this.PowerBar.PowerIcon2.power.textAutoSize = "shrink";
        this.PowerBar.PowerIcon2.power.text = this.m_PowerName2;
        this.PowerBar.PowerIcon3.SetIcon(this.m_PowerIcon3Resource,this.m_PowerIcon3Index);
        this.PowerBar.PowerIcon3.power.textAutoSize = "shrink";
        this.PowerBar.PowerIcon3.power.text = this.m_PowerName3;
        this.LockedText.text = _root.screen.srLocked;
        this.UndeployedText.text = _root.screen.srNew;
        this.LevelUpText.text = _root.screen.srLevelUp;
        this.RefreshIconState();
        this.PowerBar._visible = this.m_bHovered;
        this.KitName._visible = this.m_bHovered;
        this.CharacterName._visible = this.m_bHovered && this.IsDeployed();
        if(this.m_bHovered)
        {
            this.m_mcBarOn.gotoAndPlay(this.MouseOverFrame);
        }
    }
	// MILAN CHANGE DropTheSquid 12/19/2023
	// This is called every frame while the list is animating. it allows the PC info button to move and fade/in out with the selected item as the list animates
	function refreshPCInfoButton()
	{
		if(!_root.screen.bUsingGamepad && this.m_bHovered)
		{
			this.ShowPCInfoButton();
		}
	}
	// END MILAN
    function get IconState()
    {
        return this.m_IconState;
    }
    function set IconState(nIconState)
    {
        this.m_IconState = nIconState;
        this.RefreshIconState();
    }
    function SetHovered(bHovered)
    {
        if(this.m_bHovered != bHovered)
        {
            this.m_bHovered = bHovered;
            this.PowerBar._visible = this.m_bHovered;
            this.KitName._visible = this.m_bHovered;
            this.CharacterName._visible = this.m_bHovered && this.IsDeployed();
            var _loc3_ = !this.m_bHovered ? this.MouseOffFrame : this.MouseOverFrame;
            this.m_mcBarOn.gotoAndPlay(_loc3_);
            // MILAN CHANGE DropTheSquid 12/12/2023
			// Changed this from going off of Platform (not dynamic) to the bUsingGamepad of the other class, which is dynamic
            if(!_root.screen.bUsingGamepad && this.m_bHovered)
            {
                this.ShowPCInfoButton();
            }
            else
            {
                this.HidePCInfoButton();
            }
			// also set this on the other screen so we can make the PC info button show up if we switch back to keyboard/mouse which this is selected
            _root.screen.currentKitPanelItem = this;
            // END MILAN
        }
    }
    function onRollOver()
    {
		// MILAN CHANGE DropTheSquid 12/18/2023
		// make sure this does not fire while we are using the gamepad, even if you leave the (invisible) mouse hovering over it.
		// also not while the list is moving in general, which covers the same use case for scrolling with keyboard/mouse
		if (_root.screen.bUsingGamepad || this.parentList.IsListMoving)
		{
			return;
		}
		// END MILAN
        super.onRollOver();
        this.parentList.unselectAllItems();
        this.parentList.selectedItem = this;
        _global.SFX.PlayGUISound("MPSelectKitCharacterChange");
    }
	// MILAN CHANGE DropTheSquid 12/18/2023
	// make override of OnRollout so we can do nothing if the mouse is invisible or the list is moving
	function onRollOut()
    {
		if (_root.screen.bUsingGamepad || this.parentList.IsListMoving)
		{
			return;
		}
        super.onRollOut();
    }
	// END MILAN
    function onRelease()
    {
        super.onRelease();
        this.dispatchEvent({type:"VListItem_DoAction",data:this._data});
    }
    function SetCharacterImageReference(ref)
    {
        this.m_CharacterImageRef = ref;
    }
    function SetPowerIcon1(Resource, nIndex, PowerName)
    {
        this.m_PowerIcon1Resource = Resource;
        this.m_PowerIcon1Index = nIndex;
        this.m_PowerName1 = PowerName;
    }
    function SetPowerIcon2(Resource, nIndex, PowerName)
    {
        this.m_PowerIcon2Resource = Resource;
        this.m_PowerIcon2Index = nIndex;
        this.m_PowerName2 = PowerName;
    }
    function SetPowerIcon3(Resource, nIndex, PowerName)
    {
        this.m_PowerIcon3Resource = Resource;
        this.m_PowerIcon3Index = nIndex;
        this.m_PowerName3 = PowerName;
    }
    function SetActive(bActive)
    {
        this.SetHovered(bActive);
    }
    function IsDeployed()
    {
        return this.m_IconState != screens.MPSelectKit.KitPanelItem.ICON_STATE_UNDEPLOYED && this.m_IconState != screens.MPSelectKit.KitPanelItem.ICON_STATE_LOCKED;
    }
    function ShowPCInfoButton()
    {
        var _loc3_ = {x:this.PowerBar._x,y:this.PowerBar._y};
        this.localToGlobal(_loc3_);
        _root.screen.globalToLocal(_loc3_);
        _root.screen.PCInfoButton._x = _loc3_.x - 7;
        _root.screen.PCInfoButton._y = _loc3_.y - 42;
		// MILAN CHANGE DropTheSquid 12/19/2023
		// allows the PC info button to fade in/out with an item as the list scrolls
		_root.screen.PCInfoButton._alpha = this._alpha;
		if (this._alpha == 0)
		{
			_root.screen.PCInfoButton._visible = false;
		}
		// END MILAN
        _root.screen.PCInfoButton._visible = true;
    }
    function HidePCInfoButton()
    {
        _root.screen.PCInfoButton._visible = false;
    }
}
