class screens.MPPromotion.MPPromotion extends com.SFXScreen
{
    var Image;
    var Text;
    var Title;
    var PCContinueButton;
    var PCReinforcementsButton;
    var ControllerButtons;
    var LoadingClip;
    var srContinue = "NOLOC:Continue";
    var srReinforcements = "NOLOC:Reinforcements";
    function MPPromotion()
    {
        super();
    }
    function onLoad()
    {
        super.onLoad();
        this.Image._visible = false;
        this.Text.textAutoSize = "shrink";
        this.Title.textAutoSize = "shrink";
        this.InitializeLocalization();
        this.InitializeButtons();
    }
    function SetPromotionalText(PromoTitle, PromoText)
    {
        this.Text.text = PromoText;
        this.Title.text = PromoTitle;
    }
    function InitializeLocalization()
    {
        this.srContinue = "$" + _global.SFX.GetIniString("srContinue");
        this.srReinforcements = "$" + _global.SFX.GetIniString("srReinforcements");
    }
	// MILAN CHANGE DropTheSquid 12/12/2023
	// added this new method which takes all the button visibility code from RefreshButtons
	// and makes it reusable (not just run once at init) so we can switch dynamically
    function RefreshButtonHelp(usingGamepad)
    {
		if(!usingGamepad)
        {
			this.ControllerButtons._visible = false;
            this.PCContinueButton.SetEnabled(true);
            this.PCContinueButton.SetVisible(true);
			this.PCReinforcementsButton.SetEnabled(true);
            this.PCReinforcementsButton.SetVisible(true);
        }
        else
        {
			this.PCContinueButton.SetEnabled(false);
            this.PCContinueButton.SetVisible(false);
            this.PCReinforcementsButton.SetEnabled(false);
            this.PCReinforcementsButton.SetVisible(false);
            this.ControllerButtons._visible = true;
			this.ControllerButtons.ControlB.Active = false;
            this.ControllerButtons.ControlB.Hidden = true;
            this.ControllerButtons.ControlX.Active = false;
            this.ControllerButtons.ControlX.Hidden = true;
        }
    }
    // END MILAN
    function InitializeButtons()
    {
        this.PCContinueButton = _root.PCContinueButton;
        this.PCReinforcementsButton = _root.PCReinforcementsButton;
        this.ControllerButtons = _root.ControllerButtons;
		// MILAN CHANGE DropTheSquid 12/12/2023
		// unconditionally do initial setup for both PC and controller buttons
		// PC
		this.PCContinueButton.SetText(this.srContinue);
		this.PCReinforcementsButton.SetText(this.srReinforcements);
		this.PCContinueButton.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.OnContinue));
		this.PCReinforcementsButton.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.OnReinforcements));
		// controller
		this.ControllerButtons.ControlA.SetText(this.srContinue);
		this.ControllerButtons.ControlY.SetText(this.srReinforcements);
		this.ControllerButtons.addEventListener("onButtonA",this.MakeDelegate(this.OnContinue));
		this.ControllerButtons.addEventListener("onButtonY",this.MakeDelegate(this.OnReinforcements));
		this.ControllerButtons.addEventListener("onInvalidInput",this.MakeDelegate(this.OnInvalidInput));
		this.ControllerButtons.addEventListener("ConsoleButtonGroupLoaded",function()
		{
			_root.ControllerButtons.FitLeft();
		}
		);
		// set initial visibility
        this.RefreshButtonHelp(flash.external.ExternalInterface.call("IsUsingGamepad"));
		// END MILAN
    }
    function SetLoadingClipVisible(bVisible)
    {
        this.LoadingClip._visible = bVisible;
    }
    function SetImageVisible(bVisible)
    {
        this.Image._visible = bVisible;
    }
    function OnContinue()
    {
        flash.external.ExternalInterface.call("OnContinue");
    }
    function OnReinforcements()
    {
        flash.external.ExternalInterface.call("OnReinforcements");
    }
    function SetInputEnabled(bEnabled)
    {
        // if(_global.SFX.Platform == com.XPlatform.PC)
        // {
            this.PCContinueButton.SetEnabled(bEnabled);
            this.PCReinforcementsButton.SetEnabled(bEnabled);
        // }
        // else
        // {
            this.ControllerButtons.ControlA.Active = bEnabled;
            this.ControllerButtons.ControlY.Active = bEnabled;
        // }
    }
    function OnInvalidInput()
    {
        _global.SFX.PlayGUIError();
    }
}
