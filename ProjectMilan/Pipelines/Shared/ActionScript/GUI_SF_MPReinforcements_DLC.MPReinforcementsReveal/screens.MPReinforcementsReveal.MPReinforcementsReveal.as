class screens.MPReinforcementsReveal.MPReinforcementsReveal extends com.SFXScreen
{
    var ControllerButtons;
    var PCContinueButton;
    var LeftArrow;
    var RightArrow;
    var CardClips;
    var CardHolder;
    var nSelectedCardIndex;
    var OpeningClip;
    var srContinue = "NOLOC:Continue";
    var srItems = "NOLOC:Items";
    static var INITIAL_DELAY = 4000;
    static var CARD_DELAY = 1500;
    static var OpenFrame = "open";
    static var CloseFrame = "close";
    var m_bCurrentlyAnimating = false;
    var m_nNumCurrentlyAnimatingCards = 0;
    var m_bLeftArrowPressed = false;
    var m_bRightArrowPressed = false;
	var bUsingGamepad;
	var bIntroFinished;
    function MPReinforcementsReveal()
    {
        super();
    }
    function onLoad()
    {
        super.onLoad();
        this.SetupLocalization();
        this.SetupButtons();
        _root.title.text = this.srItems;
        if(com.XPlatform.IsRunningInEngine() == false)
        {
            this.DEBUG_InitializeScreen();
        }
    }
    function SetupLocalization()
    {
        this.srContinue = "$" + _global.SFX.GetIniString("srContinue");
        this.srItems = "$" + _global.SFX.GetIniString("srItems");
    }
    function SetupButtons()
    {
        this.ControllerButtons = _root.mcControllerButtons;
        this.PCContinueButton = _root.mcContinueButton;
        this.ControllerButtons.addEventListener("onDPadLeft",this.MakeDelegate(this.OnDPadLeft));
        this.ControllerButtons.addEventListener("onDPadRight",this.MakeDelegate(this.OnDPadRight));
        
		this.PCContinueButton.SetVisible(false);
		this.PCContinueButton.SetEnabled(false);
		this.PCContinueButton.SetText(this.srContinue);
		this.PCContinueButton.addEventListener("SFXButton_onRelease",this.MakeDelegate(this.OnContinue));
		this.LeftArrow.addEventListener("SFXButton_onPress",this.MakeDelegate(this.OnLeftArrowPressed));
		this.RightArrow.addEventListener("SFXButton_onPress",this.MakeDelegate(this.OnRightArrowPressed));
		this.LeftArrow.addEventListener("SFXButton_onRelease",this.MakeDelegate(this.OnLeftArrowReleased));
		this.RightArrow.addEventListener("SFXButton_onRelease",this.MakeDelegate(this.OnRightArrowReleased));
		this.LeftArrow.addEventListener("SFXButton_onReleaseOutside",this.MakeDelegate(this.OnLeftArrowReleased));
		this.RightArrow.addEventListener("SFXButton_onReleaseOutside",this.MakeDelegate(this.OnRightArrowReleased));
	
		this.ControllerButtons.addEventListener("onButtonA",this.MakeDelegate(this.OnContinue));
		this.ControllerButtons.addEventListener("onInvalidInput",this.MakeDelegate(this.OnInvalidInput));
		this.ControllerButtons.ControlA.Hidden = true;
		this.ControllerButtons.ControlA.Active = false;
		this.ControllerButtons.ControlA.SetText(this.srContinue);
		this.ControllerButtons.ControlB.Active = false;
		this.ControllerButtons.ControlB.Hidden = true;
		this.ControllerButtons.ControlX.Active = false;
		this.ControllerButtons.ControlX.Hidden = true;
		this.ControllerButtons.ControlY.Active = false;
		this.ControllerButtons.ControlY.Hidden = true;
		this.RefreshButtonHelp(flash.external.ExternalInterface.call("IsUsingGamepad"));

    }
	function RefreshButtonHelp(usingGamepad)
    {
        this.bUsingGamepad = usingGamepad;
        if(!usingGamepad)
        {
			this.ControllerButtons._visible = false;
			this.PCContinueButton.SetVisible(this.bIntroFinished);
            this.PCContinueButton.SetEnabled(this.bIntroFinished);
        }
        else
        {
			this.ControllerButtons._visible = true;
            this.PCContinueButton.SetVisible(false);
			this.ControllerButtons.ControlA.Hidden = !this.bIntroFinished;
            this.ControllerButtons.ControlA.Active = this.bIntroFinished;
            this.ControllerButtons.FitLeft();
        }
    }
    function IntroFinished()
    {
		this.bIntroFinished = true;
		this.RefreshButtonHelp(this.bUsingGamepad);
    }
    function SetupCards(CardData)
    {
        this.CardClips = new Array();
        var _loc8_ = this.MakeDelegate(this.FinishedCardAnimation);
        var _loc7_ = this.CardHolder.getNextHighestDepth();
        var _loc2_ = 0;
        while(_loc2_ < CardData.length)
        {
            var _loc5_ = com.Utilities.Clamp(_loc2_ + screens.MPReinforcementsReveal.CardAnimation.GetMaxAnimationSteps() - screens.MPReinforcementsReveal.CardAnimation.CENTER_STEP - 1,0,screens.MPReinforcementsReveal.CardAnimation.GetMaxAnimationSteps() - 1);
            var _loc6_ = _loc7_ + CardData.length - _loc2_;
            var _loc4_ = screens.MPReinforcementsReveal.CardAnimation(this.CardHolder.attachMovie("CardAnimation","CardAnimation" + _loc2_,_loc6_));
            _loc4_._x = 0;
            _loc4_._y = 0;
            _loc4_.SetCardData(CardData[_loc2_].DisplayName,CardData[_loc2_].DisplayDescription,CardData[_loc2_].TextureReference,CardData[_loc2_].CardTypeText,CardData[_loc2_].CardType,CardData[_loc2_].IsNew,_loc5_);
            _loc4_.SetFinishAnimationCallback(_loc8_);
            this.CardClips.push(_loc4_);
            _loc2_ = _loc2_ + 1;
        }
        this.nSelectedCardIndex = 0;
        this.RefreshArrowStates();
    }
    function FinishedCardAnimation()
    {
        this.m_nNumCurrentlyAnimatingCards = this.m_nNumCurrentlyAnimatingCards - 1;
        if(this.m_nNumCurrentlyAnimatingCards <= 0)
        {
            this.m_bCurrentlyAnimating = false;
            if(Key.isDown(com.XInput.DPadLeft))
            {
                this.OnDPadLeft();
            }
            else if(Key.isDown(com.XInput.DPadRight))
            {
                this.OnDPadRight();
            }
            else if(this.m_bLeftArrowPressed)
            {
                this.OnLeftArrowPressed();
            }
            else if(this.m_bRightArrowPressed)
            {
                this.OnRightArrowPressed();
            }
        }
    }
    function InitializeScreen(SkipIntro)
    {
        this.OpeningClip = _root.OpeningClip;
        if(!SkipIntro)
        {
            this.OpeningClip.text.PackTitle.text = String(flash.external.ExternalInterface.call("GetPackName"));
            this.OpeningClip.holo.Async = true;
            this.OpeningClip.holo.VAlign = com.bioware.masseffect.controls.ResourceLoader.ALIGN_CENTER;
            this.OpeningClip.holo.HAlign = com.bioware.masseffect.controls.ResourceLoader.ALIGN_CENTER;
            this.OpeningClip.holo.ResourceString = String(flash.external.ExternalInterface.call("GetPackIntroHoloTextureRef"));
            this.OpeningClip.holo.UsePlaceholderSize();
            this.OpeningClip.placeholder.Async = true;
            this.OpeningClip.placeholder.VAlign = com.bioware.masseffect.controls.ResourceLoader.ALIGN_CENTER;
            this.OpeningClip.placeholder.HAlign = com.bioware.masseffect.controls.ResourceLoader.ALIGN_CENTER;
            this.OpeningClip.placeholder.ResourceString = String(flash.external.ExternalInterface.call("GetPackIntroTextureRef"));
            this.OpeningClip.placeholder.UsePlaceholderSize();
        }
        else
        {
            this.OpeningClip.gotoAndStop("end");
        }
        var _loc3_ = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetCardsToDisplay"));
        var _loc4_ = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetCardData_DLC",_loc3_));
        this.SetupCards(_loc4_);
    }
    function OnContinue()
    {
        flash.external.ExternalInterface.call("Exit");
    }
    function OnInvalidInput()
    {
        _global.SFX.PlayGUIError();
    }
    function MoveForward()
    {
        if(this.nSelectedCardIndex > 0)
        {
            if(!this.m_bCurrentlyAnimating)
            {
                this.m_nNumCurrentlyAnimatingCards = 0;
                this.m_bCurrentlyAnimating = true;
                var _loc7_ = screens.MPReinforcementsReveal.CardAnimation.GetMaxAnimationSteps() - 1;
                var _loc6_ = 0;
                var _loc5_ = -1;
                var _loc4_ = this.CardClips.length - 1;
                while(_loc4_ >= 0)
                {
                    var _loc3_ = screens.MPReinforcementsReveal.CardAnimation(this.CardClips[_loc4_]);
                    if(_loc3_.GetCurrentAnimationStep() < screens.MPReinforcementsReveal.CardAnimation.GetMaxAnimationSteps() - 1)
                    {
                        if(_loc3_.GetCurrentAnimationStep() == _loc5_)
                        {
                            break;
                        }
                        _loc5_ = _loc3_.GetCurrentAnimationStep();
                        _loc3_.MoveForward();
                        this.m_nNumCurrentlyAnimatingCards = this.m_nNumCurrentlyAnimatingCards + 1;
                        if(_loc3_.GetCurrentAnimationStep() == screens.MPReinforcementsReveal.CardAnimation.CENTER_STEP)
                        {
                            _loc3_.swapDepths(this.CardHolder.getNextHighestDepth());
                        }
                        _loc6_ = _loc6_ + 1;
                    }
                    if(_loc6_ >= _loc7_)
                    {
                        break;
                    }
                    _loc4_ = _loc4_ - 1;
                }
                this.nSelectedCardIndex = this.nSelectedCardIndex - 1;
                this.RefreshArrowStates();
                if(this.nSelectedCardIndex <= 0)
                {
                    this.m_bLeftArrowPressed = false;
                }
                _global.SFX.PlayGUISound("MPReinforcementsRevealChange");
            }
        }
        else
        {
            _global.SFX.PlayGUIError();
        }
    }
    function MoveBack()
    {
        if(this.nSelectedCardIndex < this.CardClips.length - 1)
        {
            if(!this.m_bCurrentlyAnimating)
            {
                this.m_nNumCurrentlyAnimatingCards = 0;
                this.m_bCurrentlyAnimating = true;
                var _loc7_ = screens.MPReinforcementsReveal.CardAnimation.GetMaxAnimationSteps() - 1;
                var _loc6_ = 0;
                var _loc5_ = -1;
                var _loc4_ = 0;
                while(_loc4_ < this.CardClips.length)
                {
                    var _loc3_ = screens.MPReinforcementsReveal.CardAnimation(this.CardClips[_loc4_]);
                    if(_loc3_.GetCurrentAnimationStep() > 0)
                    {
                        if(_loc3_.GetCurrentAnimationStep() == _loc5_)
                        {
                            break;
                        }
                        _loc5_ = _loc3_.GetCurrentAnimationStep();
                        _loc3_.MoveBack();
                        this.m_nNumCurrentlyAnimatingCards = this.m_nNumCurrentlyAnimatingCards + 1;
                        if(_loc3_.GetCurrentAnimationStep() == screens.MPReinforcementsReveal.CardAnimation.CENTER_STEP)
                        {
                            _loc3_.swapDepths(this.CardHolder.getNextHighestDepth());
                        }
                        _loc6_ = _loc6_ + 1;
                    }
                    if(_loc6_ >= _loc7_)
                    {
                        break;
                    }
                    _loc4_ = _loc4_ + 1;
                }
                this.nSelectedCardIndex = this.nSelectedCardIndex + 1;
                this.RefreshArrowStates();
                if(this.nSelectedCardIndex >= this.CardClips.length - 1)
                {
                    this.m_bRightArrowPressed = false;
                }
                _global.SFX.PlayGUISound("MPReinforcementsRevealChange");
            }
        }
        else
        {
            _global.SFX.PlayGUIError();
        }
    }
    function OnDPadLeft()
    {
        this.MoveForward();
    }
    function OnDPadRight()
    {
        this.MoveBack();
    }
    function OnLeftArrowPressed()
    {
        this.m_bLeftArrowPressed = true;
        this.m_bRightArrowPressed = false;
        this.MoveForward();
    }
    function OnRightArrowPressed()
    {
        this.m_bRightArrowPressed = true;
        this.m_bLeftArrowPressed = false;
        this.MoveBack();
    }
    function OnLeftArrowReleased()
    {
        this.m_bLeftArrowPressed = false;
    }
    function OnRightArrowReleased()
    {
        this.m_bRightArrowPressed = false;
    }
    function RefreshArrowStates()
    {
        this.RightArrow.SetEnabled(this.nSelectedCardIndex < this.CardClips.length - 1);
        this.LeftArrow.SetEnabled(this.nSelectedCardIndex > 0);
    }
    function DEBUG_InitializeScreen()
    {
        var _loc4_ = new Array();
        var _loc3_ = 0;
        while(_loc3_ < 9)
        {
            var _loc2_ = new Object();
            _loc2_.DisplayName = "Test Card " + _loc3_;
            _loc2_.DisplayDescription = "This is the description for test card " + _loc3_;
            _loc2_.TextureReference = "";
            _loc2_.CardTypeText = "Rare";
            _loc2_.CardType = _loc3_ % 4;
            _loc4_.push(_loc2_);
            _loc3_ = _loc3_ + 1;
        }
        this.SetupCards(_loc4_);
    }
    function onKeyDown()
    {
        switch(Key.getCode())
        {
            case com.XInput.DPadLeft:
                this.OnDPadLeft();
                break;
            case com.XInput.DPadRight:
                this.OnDPadRight();
                break;
            default:
                _global.SFX.PlayGUIError();
        }
    }
}
