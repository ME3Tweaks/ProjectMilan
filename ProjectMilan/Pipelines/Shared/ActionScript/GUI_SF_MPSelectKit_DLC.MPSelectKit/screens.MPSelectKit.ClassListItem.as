class screens.MPSelectKit.ClassListItem extends com.bioware.masseffect.controls.VListItem
{
    var newChar;
    var ClassNameField;
    var ClassLevelField;
    var m_NumPromotions;
    var ClassPromotionField;
    var m_NewClass;
    var PromoteImage;
    var LevelUpImage;
    static var ICON_STATE_NONE = 0;
    static var ICON_STATE_PROMOTE = 1;
    static var ICON_STATE_LEVELUP = 2;
    var m_IconState = screens.MPSelectKit.ClassListItem.ICON_STATE_NONE;
    function ClassListItem()
    {
        super();
        this._LISTSPACING = -14;
        this.newChar.text.textAutoSize = "shrink";
        this.newChar.text.text = _root.screen.srNew;
    }
    function SetClassName(ClassName)
    {
        this.ClassNameField.Text.textAutoSize = "shrink";
        this.ClassNameField.Text.text = ClassName;
    }
    function SetClassLevel(ClassLevel)
    {
        this.ClassLevelField.Text.textAutoSize = "shrink";
        this.ClassLevelField.Text.text = ClassLevel;
    }
    function SetPromotions(nNumPromotions)
    {
        this.m_NumPromotions = nNumPromotions;
        this.ClassPromotionField.promotions.text = nNumPromotions;
        this.ClassPromotionField._visible = this.m_NumPromotions > 0;
    }
    function SetNewClass(bNewClass)
    {
        this.m_NewClass = bNewClass;
        this.newChar._visible = this.m_NewClass;
    }
    function RefreshIconState()
    {
        this.PromoteImage._visible = this.m_IconState == screens.MPSelectKit.ClassListItem.ICON_STATE_PROMOTE;
        this.LevelUpImage._visible = this.m_IconState == screens.MPSelectKit.ClassListItem.ICON_STATE_LEVELUP;
    }
    function onRollOver()
    {
		// MILAN CHANGE DropTheSquid 12/18/2023
		// make sure this does not fire while we are using the gamepad, even if you leave the (invisible) mouse hovering over it.
		if (_root.screen.bUsingGamepad || _root.screen.bInputIgnored)
		{
			return;
		}
		// END MILAN
        super.onRollOver();
        _global.SFX.PlayGUISound("MPSelectKitClassChange");
    }
    function onRelease()
    {
        super.onRelease();
        _global.SFX.PlayGUISound("MPSelectKitClassSelect");
    }
    function get IconState()
    {
        return this.m_IconState;
    }
    function set IconState(nIconState)
    {
        this.m_IconState = nIconState;
        this.RefreshIconState();
    }
}
