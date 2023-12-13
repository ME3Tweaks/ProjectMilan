class screens.MPStore.MPStore extends com.SFXScreen
{
    var Details;
    var DetailsMarquee;
    var StoreItemsScrollBar;
    var scrollbar;
    var StoreImage;
    var ControllerButtons;
    var PCPurchaseButton;
    var PCBackButton;
    var PCShowReinforcementsButton;
    var PCStore;
    var XBoxStore;
    var PS3Store;
    var PS3StoreSD;
    var StoreItems;
    var ListLoadingClip;
    var ImageLoadingClip;
    var MainTitle;
    var PurchaseTitle;
    var CreditsTitle;
    var StoreItemData;
    var PCPointsTitle;
    var PCPoints;
    var PromoBanner;
    var ExpirationIntervalID;
    var CantPurchaseWhileReady;
    var Credits;
    var srReinforcements = "NOLOC:Reinforcements";
    var srReinforcementsPurchase = "NOLOC:Reinforcements Purchase";
    var srCredits = "NOLOC:Current Credits";
    var srPurchase = "NOLOC:Purchase";
    var srBack = "NOLOC:Back";
    var srAvailableBiowarePoints = "NOLOC:Available BioWare Points";
    var srRedeem = "NOLOC:Redeem";
    var srCantPurchaseWhileReady = "NOLOC:You can\'t purchase items while Ready.";
    var srShowReinforcements = "NOLOC:Show Last Award";
    static var EXPIRATION_TIMER_INTERVAL = 60000;
    static var CREDITS_ONLY = 0;
    static var PLATFORM_ONLY = 1;
    static var CREDITS_AND_PLATFORM = 2;
    static var FREE = 3;
    var m_bInputEnabled = false;
    function MPStore()
    {
        super();
    }
    function onLoad()
    {
        super.onLoad();
        this.Details = this.DetailsMarquee.GetDetailsPanel();
        this.StoreItemsScrollBar = new com.PCScrollBar(this.scrollbar,this.scrollbar.bar,this.scrollbar.sliderNew,this.scrollbar.ResScrlUp,this.scrollbar.ResScrlDown,this.scrollbar.scrollbarVisibleBg,false);
        this.StoreItemsScrollBar.SetLeftStickIcon(true);
        this.StoreItemsScrollBar.SetPlatformLayout(_global.SFX.Platform);
        this.SetupLocalization();
        this.SetupButtons();
        this.SetupStoreIcons();
        if(!com.XPlatform.IsRunningInEngine())
        {
            this.StoreImage.SourcePrefix = "";
            this.StoreImage.SetImageData(screens.MPStore.StoreImageLoader.IMAGE_MODE_DEFAULT,"");
        }
    }
    function SetupLocalization()
    {
        this.srReinforcements = "$" + _global.SFX.GetIniString("srReinforcements");
        this.srReinforcementsPurchase = "$" + _global.SFX.GetIniString("srReinforcementsPurchase");
        this.srCredits = "$" + _global.SFX.GetIniString("srCredits");
        this.srPurchase = "$" + _global.SFX.GetIniString("srPurchase");
        this.srBack = "$" + _global.SFX.GetIniString("srBack");
        this.srAvailableBiowarePoints = "$" + _global.SFX.GetIniString("srAvailableBiowarePoints");
        this.srRedeem = "$" + _global.SFX.GetIniString("srRedeem");
        this.srCantPurchaseWhileReady = "$" + _global.SFX.GetIniString("srCantPurchaseWhileReady");
        this.srShowReinforcements = "$" + _global.SFX.GetIniString("srShowReinforcements");
    }
    function SetupButtons()
    {
        this.ControllerButtons = _root.mcControllerButtons;
        this.PCPurchaseButton = _root.mcPurchaseButton;
        this.PCBackButton = _root.mcBackButton;
        this.PCShowReinforcementsButton = _root.mcShowReinforcementsButton;
        var _loc4_ = Boolean(flash.external.ExternalInterface.call("CanShowReinforcementsRevealScreen"));
        if(_global.SFX.Platform == com.XPlatform.PC)
        {
            this.ControllerButtons._visible = false;
            this.PCPurchaseButton.SetVisible(true);
            this.PCBackButton.SetVisible(true);
            this.PCShowReinforcementsButton.SetVisible(true);
            this.PCBackButton.SetText(this.srBack);
            this.PCPurchaseButton.SetText(this.srPurchase);
            this.PCShowReinforcementsButton.SetText(this.srShowReinforcements);
            this.PCPurchaseButton.addEventListener("SFXButton_onRelease",this.MakeDelegate(this.OnPurchase));
            this.PCBackButton.addEventListener("SFXButton_onRelease",this.MakeDelegate(this.OnBack));
            this.PCShowReinforcementsButton.addEventListener("SFXButton_onRelease",this.MakeDelegate(this.OnManualReinforcementsReveal));
            this.PCShowReinforcementsButton.SetEnabled(_loc4_);
        }
        else
        {
            this.ControllerButtons._visible = true;
            this.PCPurchaseButton.SetVisible(false);
            this.PCBackButton.SetVisible(false);
            this.PCShowReinforcementsButton.SetVisible(false);
            this.ControllerButtons.addEventListener("onButtonA",this.MakeDelegate(this.OnPurchase));
            this.ControllerButtons.addEventListener("onButtonB",this.MakeDelegate(this.OnBack));
            this.ControllerButtons.addEventListener("onButtonY",this.MakeDelegate(this.OnManualReinforcementsReveal));
            this.ControllerButtons.addEventListener("onDPadUp",this.MakeDelegate(this.OnDPadUp));
            this.ControllerButtons.addEventListener("onDPadDown",this.MakeDelegate(this.OnDPadDown));
            this.ControllerButtons.addEventListener("onInvalidInput",this.MakeDelegate(this.OnInvalidInput));
            this.ControllerButtons.ControlA.SetText(this.srPurchase);
            this.ControllerButtons.ControlB.SetText(this.srBack);
            this.ControllerButtons.ControlY.SetText(this.srShowReinforcements);
            this.ControllerButtons.ControlY.Active = _loc4_;
            this.ControllerButtons.ControlX.Active = false;
            this.ControllerButtons.ControlX.Hidden = true;
            this.ControllerButtons.FitLeft();
        }
    }
    function SetupStoreIcons()
    {
        this.PCStore._visible = false;
        this.XBoxStore._visible = false;
        this.PS3Store._visible = false;
        this.PS3StoreSD._visible = false;
        if(!_global.SFX.IsDemo)
        {
            if(_global.SFX.Platform == com.XPlatform.XBox)
            {
                this.PCStore._visible = true;
            }
            else if(_global.SFX.Platform == com.XPlatform.PS3)
            {
                if(com.SFXScreen.IsHD())
                {
                    this.PS3Store._visible = true;
                }
                else
                {
                    this.PS3StoreSD._visible = true;
                }
            }
        }
    }
    function ClearScreen()
    {
        this.StoreItems.killMenu();
        this.Details.ClearPanel();
    }
    function SetInputEnabled(bEnabled)
    {
        this.m_bInputEnabled = bEnabled;
        this.RefreshButtonStates();
    }
    function SetListLoadingClipVisible(bVisible)
    {
        this.ListLoadingClip._visible = bVisible;
    }
    function SetImageLoadingClipVisible(bVisible)
    {
        this.ImageLoadingClip._visible = bVisible;
    }
    function InitializeScreen()
    {
        this.MainTitle.text = this.srReinforcements;
        this.PurchaseTitle.text = this.srReinforcementsPurchase;
        this.CreditsTitle.text = this.srCredits;
        this.ClearScreen();
        this.StoreItemData = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetStoreItems"));
        var _loc3_ = undefined;
        var _loc2_ = 0;
        while(_loc2_ < this.StoreItemData.length)
        {
            _loc3_ = screens.MPStore.StoreListItem(this.StoreItems.addListEntry(_loc2_,{index:_loc2_}));
            var _loc6_ = String(flash.external.ExternalInterface.call("GetPlatformCostString",this.StoreItemData[_loc2_].nID));
            var _loc5_ = String(flash.external.ExternalInterface.call("GetCreditCostString",this.StoreItemData[_loc2_].nID));
            _loc3_.SetItemData(this.StoreItemData[_loc2_].DisplayTitle,this.StoreItemData[_loc2_].PromoText);
            _loc3_.addEventListener("VListItem_DoAction",this.MakeDelegate(this.OnPurchase));
            _loc2_ = _loc2_ + 1;
        }
        this.StoreItems.addEventListener("onChange",this.MakeDelegate(this.OnSelectedStoreItemChange));
        this.StoreItems.setupScrollBar(this.scrollbar);
        this.scrollbar._visible = this.StoreItems.length > this.StoreItems.NUM_VISIBLE;
        this.RefreshCredits();
        this.RefreshSelection();
        this.SetupPCPointsTitle();
    }
    function SetupPCPointsTitle()
    {
        if(_global.SFX.Platform == com.XPlatform.XBox && !_global.SFX.IsDemo)
        {
            this.PCPointsTitle._visible = true;
            this.PCPoints._visible = true;
            this.PCPointsTitle.text = this.srAvailableBiowarePoints;
            this.PCPointsTitle.textAutoSize = "shrink";
        }
        else
        {
            this.PCPointsTitle._visible = false;
            this.PCPoints._visible = false;
        }
    }
    function RefreshPCPoints()
    {
        this.PCPoints.text = String(flash.external.ExternalInterface.call("GetAvailablePCPoints"));
    }
    function RefreshSelection()
    {
        var _loc4_ = Number(flash.external.ExternalInterface.call("GetInitialSelectedID"));
        var _loc3_ = -1;
        var _loc2_ = 0;
        while(_loc2_ < this.StoreItemData.length)
        {
            if(this.StoreItemData[_loc2_].nID == _loc4_)
            {
                _loc3_ = _loc2_;
                break;
            }
            _loc2_ = _loc2_ + 1;
        }
        if(_loc3_ >= 0)
        {
            this.StoreItems.selectedIndex = _loc3_;
        }
        else
        {
            this.StoreItems.selectedIndex = 0;
        }
        this.StoreItems.selectedItem.gotoAndStop(screens.MPStore.StoreListItem.FullSelectFrame);
    }
    function OnSelectedStoreItemChange()
    {
        var _loc2_ = this.StoreItems.selectedIndex;
        var _loc3_ = String(flash.external.ExternalInterface.call("GetPlatformCostString",this.StoreItemData[_loc2_].nID));
        var _loc5_ = String(flash.external.ExternalInterface.call("GetCreditCostString",this.StoreItemData[_loc2_].nID));
        var _loc4_ = Boolean(flash.external.ExternalInterface.call("CanPurchaseItemWithCredits",this.StoreItemData[_loc2_].nID));
        this.DetailsMarquee.moveContentTo(0,true);
        this.Details.SetDetailsData(this.StoreItemData[_loc2_].DescriptionTitle,this.StoreItemData[_loc2_].Description,_loc3_,_loc5_,_loc4_,"");
        if(this.StoreItemData[_loc2_].PromoText != "")
        {
            this.PromoBanner._visible = true;
            this.PromoBanner.text.text = this.StoreItemData[_loc2_].PromoText;
        }
        else
        {
            this.PromoBanner._visible = false;
        }
        this.DetailsMarquee.ReCalculateOrigin();
        this.DetailsMarquee.RefreshScrollBar();
        this.SetImageLoadingClipVisible(false);
        this.StoreImage.SetImageData(this.StoreItemData[_loc2_].ImageData.ImageLocation,this.StoreItemData[_loc2_].ImageData.ImageReference);
        clearInterval(this.ExpirationIntervalID);
        if(this.StoreItemData[_loc2_].bExpires)
        {
            this.ExpirationIntervalID = setInterval(this.MakeDelegate(this.UpdateExpirationText),screens.MPStore.MPStore.EXPIRATION_TIMER_INTERVAL);
            this.UpdateExpirationText();
        }
        this.RefreshButtonStates();
    }
    function RefreshButtonStates()
    {
        var _loc4_ = this.CanPurchaseSelectedItem();
        var _loc7_ = this.StoreItems.selectedIndex;
        var _loc5_ = Boolean(flash.external.ExternalInterface.call("IsItemFree",this.StoreItemData[_loc7_].nID));
        var _loc3_ = Boolean(flash.external.ExternalInterface.call("CanManuallyShowReinforcementsRevealScreen"));
        if(_global.SFX.Platform == com.XPlatform.PC)
        {
            this.PCPurchaseButton.SetEnabled(this.m_bInputEnabled && _loc4_);
            this.PCPurchaseButton.SetText(!_loc5_ ? this.srPurchase : this.srRedeem);
            this.PCBackButton.SetEnabled(this.m_bInputEnabled);
            this.PCBackButton.SetText(this.srBack);
            this.PCShowReinforcementsButton.SetEnabled(_loc3_);
            this.PCShowReinforcementsButton.SetText(this.srShowReinforcements);
        }
        else
        {
            this.ControllerButtons.ControlA.Active = this.m_bInputEnabled && _loc4_;
            this.ControllerButtons.ControlA.SetText(!_loc5_ ? this.srPurchase : this.srRedeem);
            this.ControllerButtons.ControlB.Active = this.m_bInputEnabled;
            this.ControllerButtons.ControlB.SetText(this.srBack);
            this.ControllerButtons.ControlY.Active = _loc3_;
            this.ControllerButtons.ControlY.SetText(this.srShowReinforcements);
            this.ControllerButtons.FitLeft();
        }
        var _loc6_ = Boolean(flash.external.ExternalInterface.call("IsReady"));
        this.CantPurchaseWhileReady.text = this.srCantPurchaseWhileReady;
        this.CantPurchaseWhileReady._visible = _loc6_;
    }
    function OnPurchase()
    {
        if(this.CanPurchaseSelectedItem())
        {
            flash.external.ExternalInterface.call("PurchaseItem",this.StoreItemData[this.StoreItems.selectedIndex].nID);
        }
        else
        {
            _global.SFX.PlayGUIError();
        }
    }
    function OnBack()
    {
        flash.external.ExternalInterface.call("Exit");
    }
    function OnDPadUp()
    {
        if(this.StoreItems.selectedIndex > 0)
        {
            this.StoreItems.selectedIndex -= 1;
            _global.SFX.PlayGUISound("MPStoreChange");
        }
        else
        {
            _global.SFX.PlayGUIError();
        }
    }
    function OnDPadDown()
    {
        if(this.StoreItems.selectedIndex < this.StoreItems.length - 1)
        {
            this.StoreItems.selectedIndex += 1;
            _global.SFX.PlayGUISound("MPStoreChange");
        }
        else
        {
            _global.SFX.PlayGUIError();
        }
    }
    function OnManualReinforcementsReveal()
    {
        var _loc2_ = Boolean(flash.external.ExternalInterface.call("CanManuallyShowReinforcementsRevealScreen"));
        if(_loc2_)
        {
            flash.external.ExternalInterface.call("ShowReinforcementsRevealScreen",true);
        }
        else
        {
            _global.SFX.PlayGUIError();
        }
    }
    function OnInvalidInput()
    {
        _global.SFX.PlayGUIError();
    }
    function RefreshCredits()
    {
        var _loc2_ = String(flash.external.ExternalInterface.call("GetTotalCreditString"));
        this.Credits.text = _loc2_;
    }
    function UpdateExpirationText()
    {
        var _loc3_ = String(flash.external.ExternalInterface.call("GetExpirationTimeString",this.StoreItemData[this.StoreItems.selectedIndex].nID));
        if(_loc3_ == "")
        {
            this.StoreItemData[this.StoreItems.selectedIndex].bHasExpired = true;
            clearInterval(this.ExpirationIntervalID);
            _loc3_ = "$" + _global.SFX.GetIniString("srItemExpiredText");
        }
        else
        {
            this.StoreItemData[this.StoreItems.selectedIndex].bHasExpired = false;
        }
        this.Details.SetExpires(_loc3_);
    }
    function CanPurchaseSelectedItem()
    {
        var _loc2_ = Boolean(flash.external.ExternalInterface.call("CanPurchaseItem",this.StoreItemData[this.StoreItems.selectedIndex].nID));
        var _loc3_ = this.StoreItemData[this.StoreItems.selectedIndex].bHasExpired;
        return _loc2_ && !_loc3_;
    }
    function ShowDefaultStoreImage()
    {
        this.StoreImage.SetImageMode(screens.MPStore.StoreImageLoader.IMAGE_MODE_DEFAULT);
    }
    function ShowRemoteStoreImage()
    {
        this.StoreImage.SetImageMode(screens.MPStore.StoreImageLoader.IMAGE_MODE_REMOTE);
    }
    function ScrollDetails(nValue)
    {
        this.DetailsMarquee.ScrollPanel(nValue);
    }
}
