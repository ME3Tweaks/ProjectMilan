class screens.MPPromotion.MPPromotion extends com.SFXScreen
{
    var Image;
    var PromoTextMC;
    var Title;
    var PCContinueButton;
    var PCReinforcementsButton;
    var ControllerButtons;
    var LoadingClip;
    var srContinue = "NOLOC:Continue";
    var srReinforcements = "NOLOC:Reinforcements";
	var bUsingGamepad;
	var bInputEnabled = true;
    function MPPromotion()
    {
        super();
    }
    function onLoad()
    {
        super.onLoad();
        this.Image._visible = false;
        this.PromoTextMC.PlatformLayout = _global.SFX.Platform;
        this.Title.textAutoSize = "shrink";
        this.InitializeLocalization();
        this.InitializeButtons();
    }
	// MILAN CHANGE DropTheSquid 1/5/2024
	// added this new method which takes all the button visibility code from RefreshButtons
	// and makes it reusable (not just run once at init) so we can switch dynamically
    function RefreshButtonHelp(usingGamepad)
    {
		this.bUsingGamepad = usingGamepad;
		if(!usingGamepad)
        {
            this.ControllerButtons._visible = false;
            this.PCContinueButton.SetEnabled(this.bInputEnabled);
            this.PCContinueButton.SetVisible(true);
            this.PCReinforcementsButton.SetEnabled(this.bInputEnabled);
            this.PCReinforcementsButton.SetVisible(true);
			this.ControllerButtons.ControlA.Active = false;
			this.ControllerButtons.ControlY.Active = false;
        }
        else
        {
			this.ControllerButtons._visible = true;
            this.PCContinueButton.SetEnabled(false);
            this.PCContinueButton.SetVisible(false);
            this.PCReinforcementsButton.SetEnabled(false);
            this.PCReinforcementsButton.SetVisible(false);
			this.ControllerButtons.ControlA.Active = this.bInputEnabled;
			this.ControllerButtons.ControlY.Active = this.bInputEnabled;
        }
    }
    // END MILAN
    function SetPromotionalText(PromoTitle, PromoText)
    {
        this.PromoTextMC.text = PromoText;
        this.Title.text = PromoTitle;
    }
    function InitializeLocalization()
    {
        this.srContinue = "$" + _global.SFX.GetIniString("srContinue");
        this.srReinforcements = "$" + _global.SFX.GetIniString("srReinforcements");
    }
    function InitializeButtons()
    {
        this.PCContinueButton = _root.PCContinueButton;
        this.PCReinforcementsButton = _root.PCReinforcementsButton;
        this.ControllerButtons = _root.ControllerButtons;
		// handlers (always run)
		this.PCContinueButton.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.OnContinue));
		this.PCReinforcementsButton.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.OnReinforcements));
		this.ControllerButtons.addEventListener("onButtonA",this.MakeDelegate(this.OnContinue));
		this.ControllerButtons.addEventListener("onButtonY",this.MakeDelegate(this.OnReinforcements));
		this.ControllerButtons.addEventListener("onInvalidInput",this.MakeDelegate(this.OnInvalidInput));
		this.ControllerButtons.addEventListener("ConsoleButtonGroupLoaded",function()
		{
			_root.ControllerButtons.FitLeft();
		});

		// one time setup
		this.PCContinueButton.SetText(this.srContinue);
		this.PCReinforcementsButton.SetText(this.srReinforcements);
		this.ControllerButtons.ControlA.SetText(this.srContinue);
		this.ControllerButtons.ControlY.SetText(this.srReinforcements);
		this.ControllerButtons.ControlB.Active = false;
		this.ControllerButtons.ControlB.Hidden = true;
		this.ControllerButtons.ControlX.Active = false;
		this.ControllerButtons.ControlX.Hidden = true;
		this.RefreshButtonHelp(flash.external.ExternalInterface.call("IsUsingGamepad"));
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
		this.bInputEnabled = bEnabled;
		// MILAN CHANGE DropTheSquid 1/5/2024
		// these were each running or not based on platform
		// with dynamic input, it should always run both and take into account the current input mode
		this.PCContinueButton.SetEnabled(this.bInputEnabled && !this.bUsingGamepad);
		this.PCReinforcementsButton.SetEnabled(this.bInputEnabled && !this.bUsingGamepad);
	
		this.ControllerButtons.ControlA.Active = this.bInputEnabled && this.bUsingGamepad;
		this.ControllerButtons.ControlY.Active = this.bInputEnabled && this.bUsingGamepad;
    }
    function OnInvalidInput()
    {
        _global.SFX.PlayGUIError();
    }
}
