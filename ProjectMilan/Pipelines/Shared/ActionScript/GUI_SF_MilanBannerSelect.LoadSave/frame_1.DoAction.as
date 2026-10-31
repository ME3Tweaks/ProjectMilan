// MILAN CHANGE - Mgamerz - 2026-10-21
_global.gfxExtensions = true;
var pickerRequested = false;
var pickerStarted = false;
var pickerUsingGamepad = false;
var bannerLabels;
function Initialize()
{
    pickerRequested = true;
    this.onEnterFrame = function()
    {
        if(pickerRequested && !pickerStarted && loadSave.ready && mcConsoleButtons.IsLoaded())
        {
            pickerStarted = true;
            delete this.onEnterFrame;
            flash.external.ExternalInterface.call("onExternalInitialize");
        }
    };
}
function SetBannerLabels(title,subtitle,noneLabel,equip,back,equipped,loading,unavailable,saveFailed,select,cancel)
{
    bannerLabels = {Title:title,Subtitle:subtitle,NoneLabel:noneLabel,Equip:equip,Back:back,Equipped:equipped,Loading:loading,Unavailable:unavailable,SaveFailed:saveFailed,Select:select,Cancel:cancel};
}
function ShowPicker()
{
    var labels = bannerLabels;
    var entries = com.SFXScreen.ObjectToArray(flash.external.ExternalInterface.call("GetBanners"));
    loadSave.BeginBanners(entries,labels,flash.external.ExternalInterface.call("GetEquippedBanner"));
}
function RefreshButtonHelp(gamepad)
{
    pickerUsingGamepad = gamepad;
    if(loadSave.ready && loadSave.labels != undefined) { loadSave.RefreshButtonHelp(gamepad); }
}
function EquipSelected() { loadSave.EquipSelected(); }
function NextBanner() { loadSave.MoveSelection(1); }
function PreviousBanner() { loadSave.MoveSelection(-1); }
function DisposePicker() { pickerRequested = false; delete this.onEnterFrame; loadSave.DisposePicker(); }
function GFxScreenVisibilityChange(bNewValue) { }
