class screens.MPNewLobby.CharacterSummary extends com.SFXMovieClip
{
    var _visible;
    var kitSection;
    var onEnterFrame;
    var upgradesSection;
    var weaponsSection;
    var xpSection;
    function CharacterSummary()
    {
        super();
    }
    function onLoad()
    {
        super.onLoad();
        if(!_root.screen.m_bConnected)
        {
            this.kitSection.onPress = _root.screen.ShowTalentsLevelUpScreen;
            this.weaponsSection.onPress = _root.screen.ShowWeaponsScreen;
            this.upgradesSection.onPress = _root.screen.ShowMatchConsumablesScreen;
        }
        this.onEnterFrame = function()
        {
            this.Refresh();
            delete this.onEnterFrame;
        };
    }
    function Refresh()
    {
        var _loc3_ = _root.screen.leftPage;
        var _loc5_;
        var _loc4_;
        if(_loc3_.contents.m_symbolName == _root.screen.PAGE_CHARACTER_MENU)
        {
            _loc5_ = flash.external.ExternalInterface.call("GetLocalPlayerDetailedInfo_DLC");
            this.RefreshWithPlayerDetails(_loc5_);
            this._visible = true;
        }
        else if(_loc3_.contents.m_symbolName == _root.screen.PAGE_SQUAD)
        {
            _loc4_ = _loc3_.contents.list;
            if(screens.MPNewLobby.PlayerItem(_loc4_.selectedItem).isOccupied)
            {
                _loc5_ = flash.external.ExternalInterface.call("GetPlayerSlotDetailedInfo_DLC",_loc4_.selectedItem.m_slotIndex);
                this.RefreshWithPlayerDetails(_loc5_);
                this._visible = true;
            }
            else
            {
                this._visible = false;
            }
        }
        else
        {
            this._visible = false;
        }
    }
    function RefreshWithPlayerDetails(details)
    {
        this.xpSection.characterName.text = details.PlayerName;
        this.xpSection.levelAndClass.text = details.ClassData;
        this.xpSection.classIcon.ResourceString = details.ClassIcon;
        this.xpSection.XPBar.gotoAndStop(details.XPPercentage + 1);
        this.xpSection.XPBar.XpTotal.XPText.text = details.NextLevelXPString;
        this.xpSection.XPBar.XPCurrent.XPTextCurrent.text = details.CurrentXPString;
        this.kitSection.title.text = _root.screen.srKit;
        this.kitSection.PowerBar.PowerIcon1.RegistrationPoint = com.bioware.masseffect.controls.ResourceLoader.REGISTRATION_TOP_LEFT;
        this.kitSection.PowerBar.PowerIcon1.SetIcon(details.PowerData[0].PowerIconResource,details.PowerData[0].PowerIconIndex);
        this.kitSection.PowerBar.PowerIcon1.power.textAutoSize = "shrink";
        this.kitSection.PowerBar.PowerIcon1.power.text = details.PowerData[0].PowerName;
        this.kitSection.PowerBar.PowerIcon2.RegistrationPoint = com.bioware.masseffect.controls.ResourceLoader.REGISTRATION_TOP_LEFT;
        this.kitSection.PowerBar.PowerIcon2.SetIcon(details.PowerData[1].PowerIconResource,details.PowerData[1].PowerIconIndex);
        this.kitSection.PowerBar.PowerIcon2.power.textAutoSize = "shrink";
        this.kitSection.PowerBar.PowerIcon2.power.text = details.PowerData[1].PowerName;
        this.kitSection.PowerBar.PowerIcon3.RegistrationPoint = com.bioware.masseffect.controls.ResourceLoader.REGISTRATION_TOP_LEFT;
        this.kitSection.PowerBar.PowerIcon3.SetIcon(details.PowerData[2].PowerIconResource,details.PowerData[2].PowerIconIndex);
        this.kitSection.PowerBar.PowerIcon3.power.textAutoSize = "shrink";
        this.kitSection.PowerBar.PowerIcon3.power.text = details.PowerData[2].PowerName;
        this.weaponsSection.title.text = _root.screen.srWeapons;
        if(details.WeaponData.length == 0)
        {
            this.weaponsSection.loading._visible = true;
            this.weaponsSection.weapon1._visible = false;
            this.weaponsSection.weapon2._visible = false;
        }
        else
        {
            this.weaponsSection.loading._visible = false;
            this.weaponsSection.weapon1.weaponName.text = details.WeaponData[0].WeaponName;
            this.weaponsSection.weapon1.weaponImage.RegistrationPoint = com.bioware.masseffect.controls.ResourceLoader.REGISTRATION_TOP_LEFT;
            this.weaponsSection.weapon1.weaponImage.Async = true;
            this.weaponsSection.weapon1.weaponImage.ResourceString = details.WeaponData[0].WeaponImage;
            this.weaponsSection.weapon1.weaponImage.FadeIn = true;
            this.weaponsSection.weapon1.weaponImage.FadeOut = false;
            this.RefreshWeaponMod(this.weaponsSection.weapon1.modImage1,details.WeaponData[0].WeaponMod1Reference);
            this.RefreshWeaponMod(this.weaponsSection.weapon1.modImage2,details.WeaponData[0].WeaponMod2Reference);
            this.weaponsSection.weapon2.weaponName.text = details.WeaponData[1].WeaponName;
            this.weaponsSection.weapon2.weaponImage.RegistrationPoint = com.bioware.masseffect.controls.ResourceLoader.REGISTRATION_TOP_LEFT;
            this.weaponsSection.weapon2.weaponImage.Async = true;
            this.weaponsSection.weapon2.weaponImage.ResourceString = details.WeaponData[1].WeaponImage;
            this.weaponsSection.weapon2.weaponImage.FadeIn = true;
            this.weaponsSection.weapon2.weaponImage.FadeOut = false;
            this.RefreshWeaponMod(this.weaponsSection.weapon2.modImage1,details.WeaponData[1].WeaponMod1Reference);
            this.RefreshWeaponMod(this.weaponsSection.weapon2.modImage2,details.WeaponData[1].WeaponMod2Reference);
            this.weaponsSection.weapon1._visible = true;
            this.weaponsSection.weapon2._visible = true;
        }
        this.upgradesSection.title.text = _root.screen.srMissionUpgrades;
        this.RefreshMissionUpgrade(this.upgradesSection.activeItem1,undefined);
        this.RefreshMissionUpgrade(this.upgradesSection.activeItem2,undefined);
        this.RefreshMissionUpgrade(this.upgradesSection.activeItem3,undefined);
        this.RefreshMissionUpgrade(this.upgradesSection.activeItem4,undefined);
        var _loc4_ = 0;
        var _loc5_;
        while(_loc4_ < details.MatchConsumableData.length)
        {
            _loc5_ = Number(flash.external.ExternalInterface.call("GetMatchConsumableSlotTypeForCategory",details.MatchConsumableData[_loc4_].Category));
            this.RefreshMissionUpgrade(this.upgradesSection["activeItem" + (_loc5_ + 1)],details.MatchConsumableData[_loc4_]);
            _loc4_ += 1;
        }
        var _loc6_ = Number(flash.external.ExternalInterface.call("GetMaxActiveConsumables"));
        if(_loc6_ == 4)
        {
            this.upgradesSection.gotoAndStop("Slots4");
        }
        else
        {
            this.upgradesSection.gotoAndStop("Slots3");
        }
    }
    function RefreshWeaponMod(mc, modImage)
    {
        var _loc3_ = modImage == "None";
        if(_loc3_)
        {
            mc.empty.text = _root.screen.srEmpty;
            mc.empty._visible = true;
            mc.ResourceString = "";
        }
        else
        {
            mc.empty._visible = false;
            mc.Async = true;
            mc.ResourceString = modImage;
        }
        mc.UsePlaceholderSize();
        mc.FadeIn = true;
        mc.FadeOut = false;
    }
    function RefreshMissionUpgrade(mc, upgradeInfo)
    {
        var _loc4_ = upgradeInfo == undefined || upgradeInfo.MatchConsumableName == undefined;
        if(_loc4_)
        {
            mc.empty.text = _root.screen.srEmpty;
            mc.empty._visible = true;
            mc.title._visible = false;
            mc.icon._visible = false;
        }
        else
        {
            mc.empty.text = _root.screen.srEmpty;
            mc.empty._visible = false;
            mc.title.textAutoSize = "shrink";
            mc.title.text = upgradeInfo.MatchConsumableName;
            mc.title._visible = true;
            mc.icon.Async = true;
            mc.icon.ResourceString = upgradeInfo.MatchConsumableIconRef;
            mc.icon.UsePlaceholderSize();
            mc.icon.RegistrationPoint = com.bioware.masseffect.controls.ResourceLoader.REGISTRATION_TOP_LEFT;
            mc.icon.HAlign = com.bioware.masseffect.controls.ResourceLoader.ALIGN_CENTER;
            mc.icon.VAlign = com.bioware.masseffect.controls.ResourceLoader.ALIGN_CENTER;
            mc.icon.FadeIn = true;
            mc.icon.FadeOut = false;
            mc.icon._visible = true;
        }
    }
}
