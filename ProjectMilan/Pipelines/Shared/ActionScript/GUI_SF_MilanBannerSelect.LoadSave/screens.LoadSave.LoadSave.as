// MILAN CHANGE - Mgamerz - 2026-10-21
// Load/Save list artwork and movement, with a banner-specific game interface
class screens.LoadSave.LoadSave extends com.SFXScreen
{
    var vList; var listScrollbar; var mainTitleTxt; var subTitleTxt;
    var rightPane; var rightPaneCharacterSelect; var ImportRightPane;
    var characterNameTxt; var characterTypeTxt; var mcPCButtons;
    var PCButtonA; var PCButtonB; var m_ConsoleButtons;
    var labels; var equippedId; var ready; var disposed; var bannerListMask;
    var sliderScaleX; var sliderScaleY; var subtitleFrameMask; var subtitleFrameBands; var selectionSoundEnabled;
    function LoadSave() { super(); }
    function onLoad()
    {
        super.onLoad();
        this._alpha = 0;
        this.ready = true;
        this.disposed = false;
        this.selectionSoundEnabled = false;
        this.m_ConsoleButtons = _root.mcConsoleButtons;
        this.PCButtonA = this.mcPCButtons.PCButtonA;
        this.PCButtonB = this.mcPCButtons.PCButtonB;
        this.rightPane._visible = false;
        this.rightPaneCharacterSelect._visible = false;
        this.ImportRightPane._visible = false;
        this.characterNameTxt._visible = false;
        this.characterTypeTxt._visible = false;
        this.mcPCButtons.PCButtonX.SetVisible(false);
        this.mcPCButtons.PCButtonY.SetVisible(false);
        this.m_ConsoleButtons.ControlX.Hidden = true;
        this.m_ConsoleButtons.ControlY.Hidden = true;
        // Match Save/Load: directions arrive on key-down, including native repeat events.
        this.m_ConsoleButtons.addEventListener("onDPadUp",mx.utils.Delegate.create(this,this.OnNavigateUp));
        this.m_ConsoleButtons.addEventListener("onDPadDown",mx.utils.Delegate.create(this,this.OnNavigateDown));
        this.m_ConsoleButtons.addEventListener("onButtonA",mx.utils.Delegate.create(this,this.EquipSelected));
        this.m_ConsoleButtons.addEventListener("onButtonB",mx.utils.Delegate.create(this,this.ClosePicker));
        this.PCButtonA.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.EquipSelected));
        this.PCButtonB.addEventListener("SFXButton_onRelease",mx.utils.Delegate.create(this,this.ClosePicker));
        this.vList.addEventListener("onChange",mx.utils.Delegate.create(this,this.OnBannerSelectionChanged));
        this.vList.addEventListener("VListItem_DoAction",mx.utils.Delegate.create(this,this.EquipSelected));
        this.vList.SetNumVisibleElements(3);
        this.vList._x = 184;
        this.vList._y = 122;
        this.vList._listGlobalCoords = {x:0,y:0};
        this.vList.localToGlobal(this.vList._listGlobalCoords);
        this.listScrollbar._x = 1082;
        this.listScrollbar._y -= 100;
        var extra = (480-358.5-32)/(this.listScrollbar._yscale/100);
        this.listScrollbar.bar._height += extra;
        this.listScrollbar.ResScrlDown._y += extra;
        this.listScrollbar.scrollbarVisibleBg._height += extra;
        this.sliderScaleX = this.listScrollbar.sliderNew._xscale;
        this.sliderScaleY = this.listScrollbar.sliderNew._yscale;
        this.vList.setupScrollBar(this.listScrollbar);
        this.bannerListMask = this.createEmptyMovieClip("bannerListMask",900);
        this.bannerListMask.beginFill(0xFFFFFF,100);
        this.bannerListMask.moveTo(176,118); this.bannerListMask.lineTo(1076,118);
        this.bannerListMask.lineTo(1076,618); this.bannerListMask.lineTo(176,618);
        this.bannerListMask.endFill(); this.vList.setMask(this.bannerListMask);
    }
    function BeginBanners(entries,labels,equippedId)
    {
        this.selectionSoundEnabled = false;
        this.labels = labels;
        this.equippedId = equippedId;
        this.mainTitleTxt.text = labels.Title;
        this.subTitleTxt._x = this.mainTitleTxt._x;
        this.SetSubtitle(labels.Subtitle);
        this.PCButtonA.SetText(labels.Equip);
        this.PCButtonB.SetText(labels.Back);
        this.m_ConsoleButtons.ControlA.text = labels.Equip;
        this.m_ConsoleButtons.ControlB.text = labels.Cancel;
        this.m_ConsoleButtons.ControlA.Active = true;
        this.m_ConsoleButtons.ControlB.Active = true;
        this.m_ConsoleButtons.FitLeft();
        // Resolve the row/loader classes before registering their dynamic linkage symbols.
        Object.registerClass("LoadSaveVListItem",screens.LoadSave.LoadSaveVListItem);
        Object.registerClass("ScreenShotLoader",com.bioware.masseffect.controls.TextureLoader);
        this.vList.killMenu();
        var selected = 0;
        for(var i=0;i<entries.length;i++)
        {
            this.vList.addEntry(i,entries[i].Id,entries[i].Title,"","","",entries[i].Resource,"","",0,false,false,false,"");
            if(entries[i].Id == equippedId) { selected = i; }
        }
        this.vList.SnapNextListMovement = true;
        // Open directly on the equipped row; normal later navigation still animates.
        this.vList.movementRefElementIndex = Math.max(0,selected-this.vList.NUM_VISIBLE+1);
        this.vList.selectedIndex = selected;
        this.selectionSoundEnabled = true;
        this.vList.GiveFocus();
        this.RefreshButtonHelp(_root.pickerUsingGamepad);
        this._alpha = 100;
    }
    function RefreshButtonHelp(usingGamepad)
    {
        this.mcPCButtons._visible = !usingGamepad;
        this.m_ConsoleButtons._visible = usingGamepad;
        this.m_ConsoleButtons._alpha = usingGamepad ? 100 : 0;
        this.m_ConsoleButtons.ControlA.Hidden = false;
        this.m_ConsoleButtons.ControlB.Hidden = false;
        this.m_ConsoleButtons.ControlA.SetVisible(true);
        this.m_ConsoleButtons.ControlB.SetVisible(true);
        this.m_ConsoleButtons.ControlA.text = this.labels.Equip;
        this.m_ConsoleButtons.ControlB.text = this.labels.Cancel;
        this.m_ConsoleButtons.FitLeft();
        this.ConfigureScrollbar(usingGamepad);
        this.PCButtonA.SetText(this.labels.Equip);
        this.PCButtonB.SetText(this.labels.Back);
        this.LayoutPCButtons();
    }
    function LayoutPCButtons()
    {
        // Keep Back anchored to the native footer edge and join Equip directly to it.
        var equipBounds = this.PCButtonA.getBounds(this.mcPCButtons);
        var backBounds = this.PCButtonB.getBounds(this.mcPCButtons);
        this.PCButtonA._x += backBounds.xMin-equipBounds.xMax;
    }
    function ConfigureScrollbar(usingGamepad)
    {
        var slider = this.listScrollbar.sliderNew;
        // CounterScale multiplies the current transform.
        // Always start with the original
        slider._xscale = this.sliderScaleX;
        slider._yscale = this.sliderScaleY;
        var platform = usingGamepad ? com.XPlatform.XBox : com.XPlatform.PC;
        this.vList.m_PlatformLayout = platform;
        this.vList.scrollBar.SetLeftStickIcon(usingGamepad);
        if(usingGamepad) { this.vList.scrollBar.SetPlatformLayout(platform); }
        else
        {
            slider.gotoAndStop(1);
            this.vList.scrollBar.m_PlatformID = platform;
        }
        // Restore calculated scrollbar
        this.vList.recalcScrollBar();
        this.vList.recalcScrollbarVisibility();
        this.vList.repositionScrollBar();
    }
    function OnBannerSelectionChanged()
    {
        if(this.selectionSoundEnabled && !this.disposed)
        {
            _global.SFX.PlayGUISound("SaveLoadMove");
        }
    }
    function OnNavigateUp() { this.MoveSelection(-1); }
    function OnNavigateDown() { this.MoveSelection(1); }
    function MoveSelection(step)
    {
        if(!this.disposed) { this.vList.selectedIndex = Math.max(0,Math.min(this.vList.length-1,this.vList.selectedIndex+step)); }
    }
    function EquipSelected()
    {
        if(this.disposed || this.vList.selectedItem == undefined) { return; }
        var id = this.vList.selectedItem.data.gameIndex;
        if(flash.external.ExternalInterface.call("EquipBanner",id))
        {
            this.equippedId = id;
            this.SetSubtitle(this.labels.Subtitle);
            _global.SFX.PlayGUISound("SaveGame");
        }
        else
        {
            this.SetSubtitle(this.labels.SaveFailed);
            _global.SFX.PlayGUIError();
        }
    }
    function SetSubtitle(text)
    {
        this.subTitleTxt.text = text;
        this.LayoutSubtitleFrame();
    }
    function MaskRect(mc,x,y,width,height)
    {
        mc.moveTo(x,y); mc.lineTo(x+width,y); mc.lineTo(x+width,y+height);
        mc.lineTo(x,y+height); mc.lineTo(x,y);
    }
    function LayoutSubtitleFrame()
    {
        var frame = _root.bannerFrame;
        if(frame == undefined) { return; }
        for(var i=0;i<this.subtitleFrameBands.length;i++)
        {
            this.subtitleFrameBands[i].clip.removeMovieClip();
            this.subtitleFrameBands[i].mask.removeMovieClip();
        }
        this.subtitleFrameMask.removeMovieClip();
        this.subtitleFrameBands = [];
        // TextField is not a MovieClip in AS2; convert its authored corners explicitly.
        var start = {x:this.subTitleTxt._x,y:this.subTitleTxt._y};
        var end = {x:this.subTitleTxt._x+this.subTitleTxt.textWidth,y:this.subTitleTxt._y+this.subTitleTxt._height};
        this.localToGlobal(start); this.localToGlobal(end);
        var left = start.x-4;
        var right = end.x+12;
        var top = start.y-4;
        var height = end.y-start.y+8;
        var fade = 24;
        var mask = _root.createEmptyMovieClip("subtitleFrameMask",700);
        mask.beginFill(0xFFFFFF,100);
        this.MaskRect(mask,0,0,1280,top);
        this.MaskRect(mask,0,top+height,1280,1024-top-height);
        this.MaskRect(mask,0,top,left-fade,height);
        this.MaskRect(mask,right+fade,top,1280-right-fade,height);
        mask.endFill(); frame.setMask(mask);
        this.subtitleFrameMask = mask;
        for(var i=0;i<16;i++)
        {
            var edge = frame.duplicateMovieClip("subtitleFrameBand"+i,710+i);
            var band = _root.createEmptyMovieClip("subtitleFrameBandMask"+i,740+i);
            var x0 = fade*i/16;
            var x1 = fade*(i+1)/16;
            band.beginFill(0xFFFFFF,100);
            this.MaskRect(band,left-fade+x0,top,x1-x0,height);
            this.MaskRect(band,right+fade-x1,top,x1-x0,height);
            band.endFill(); edge.setMask(band); edge._alpha = (15.5-i)*100/16;
            this.subtitleFrameBands.push({clip:edge,mask:band});
        }
    }
    function ClosePicker() { if(!this.disposed) { flash.external.ExternalInterface.call("ClosePicker"); } }
    function DisposePicker()
    {
        if(this.disposed) { return; }
        this.disposed = true;
        this.m_ConsoleButtons.InputDisabled = true;
        for(var i=0;i<this.vList.length;i++) { this.vList.getListItem(i).DisposeBanner(); }
        this.vList.killMenu();
    }
    function onUnload() { this.DisposePicker(); super.onUnload(); }
}
