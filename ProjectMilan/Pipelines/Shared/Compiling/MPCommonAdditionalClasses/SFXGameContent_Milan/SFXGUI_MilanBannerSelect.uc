// MILAN CHANGE - Mgamerz - 2026-10-21
// The save/load-derived picker shows owned rewards, and equips raw emblem IDs through MP storage.
Class SFXGUI_MilanBannerSelect extends SFXGUIMovieLegacyAdapter config(UI);

struct BannerItem
{
    var int Id;
    var string Title;
    var string Resource;
};
struct BannerLabels
{
    var string Title;
    var string Subtitle;
    var string NoneLabel;
    var string Equip;
    var string Back;
    var string Equipped;
    var string Loading;
    var string Unavailable;
    var string SaveFailed;
    var string Select;
    var string Cancel;
};
struct BannerImageRequest
{
    var SFXOnlineImageRequest Request;
};
var transient array<BannerImageRequest> Images;
var transient bool bPickerOpen;
var GFxMovieInfo BannerMovie;

// Used to retain banner textures so GC doesn't kill them
// due to LE3 engine bugs
struct RetainedBannerTexture
{
    var string Resource;
    var Texture2D Texture;
};
var transient array<RetainedBannerTexture> RetainedTextures;

// Scaleform's resource paths do not keep the textures alive across Unreal GC
// Retain each requested image until panel disposal
private final function Texture2D RetainBannerTexture(string Resource, optional Texture2D Image)
{
    local int Index;
    local BioDefine.EAsyncLoadStatus AsyncStatus;
    local RetainedBannerTexture Retained;

    if (Resource == "")
    {
        return None;
    }
    for (Index = 0; Index < RetainedTextures.Length; ++Index)
    {
        if (RetainedTextures[Index].Resource ~= Resource)
        {
            if (Image != None)
            {
                RetainedTextures[Index].Texture = Image;
            }
            if (RetainedTextures[Index].Texture != None)
            {
                return RetainedTextures[Index].Texture;
            }
        }
    }
    if (Image == None)
    {
        Image = Texture2D(Class'SFXEngine'.static.LoadSeekFreeObjectAsync(Resource, Class'Texture2D', AsyncStatus));
    }
    if (Image == None)
    {
        return None;
    }
    Retained.Resource = Resource;
    Retained.Texture = Image;
    RetainedTextures.AddItem(Retained);
    return Image;
}

public static final function SFXGUI_MilanBannerSelect ShowBannerSelect(PlayerController PC, optional delegate<SFXGUIMovie.OnMovieClosedDelegate> OnClosed)
{
    local SFXGUI_MilanBannerSelect Movie;
    Movie = SFXGUI_MilanBannerSelect(Class'SFXGUIInteraction'.static.GetInstance().CastOpenMovie(Class'SFXGUI_MilanBannerSelect', PC, 'MilanBannerSelect', TRUE));
    if (Movie != None && OnClosed != None)
    {
        Movie.AddOnMovieClosedDelegate(OnClosed);
    }
    return Movie;
}
public event function OnPanelAdded()
{
    Super.OnPanelAdded();
    bPickerOpen = TRUE;
    oPanel.SetExternalInterface(Self);
    SetMouseShown(!oPanel.bUsingGamepad);
    oPanel.InvokeMethod("Initialize");
    SetFocus(TRUE);
}
public event function OnPanelRemoved()
{
    bPickerOpen = FALSE;
    oPanel.InvokeMethod("DisposePicker");
    Images.Length = 0;
    RetainedTextures.Length = 0;
    Super.OnPanelRemoved();
}
public function onExternalInitialize()
{
    local BannerLabels Labels;
    local array<ASParams> Params;

    // Native FNames can expose different member casing (e.g. SubTitle) to case-sensitive AS2.
    // Send localized strings positionally, as the other legacy-backed menus do.
    Labels = GetBannerLabels();
    AddLabelParam(Params, Labels.Title);
    AddLabelParam(Params, Labels.Subtitle);
    AddLabelParam(Params, Labels.NoneLabel);
    AddLabelParam(Params, Labels.Equip);
    AddLabelParam(Params, Labels.Back);
    AddLabelParam(Params, Labels.Equipped);
    AddLabelParam(Params, Labels.Loading);
    AddLabelParam(Params, Labels.Unavailable);
    AddLabelParam(Params, Labels.SaveFailed);
    AddLabelParam(Params, Labels.Select);
    AddLabelParam(Params, Labels.Cancel);
    oPanel.InvokeMethodArgs("SetBannerLabels", Params);
    HandleButtonHelpRefresh(oPanel.bUsingGamepad);
    oPanel.InvokeMethod("ShowPicker");
}
private static final function AddLabelParam(out array<ASParams> Params, string Text)
{
    local ASParams Param;
    Param.Type = ASParamTypes.ASParam_String;
    Param.sVar = Text;
    Params.AddItem(Param);
}
public final function BannerLabels GetBannerLabels()
{
    local BannerLabels Labels;
    Labels.Title = GetUIString($49875800);
    Labels.Subtitle = GetUIString($49875801);
    Labels.NoneLabel = GetUIString($706892);
    Labels.Equip = GetUIString($371717);
    Labels.Back = GetUIString($598887);
    Labels.Equipped = GetUIString($49875805);
    Labels.Loading = GetUIString($49875806);
    Labels.Unavailable = GetUIString($49875807);
    Labels.SaveFailed = GetUIString($49875808);
    Labels.Select = GetUIString($598888);
    Labels.Cancel = GetUIString($315182);
    return Labels;
}
public final function array<BannerItem> GetBanners()
{
    local array<BannerItem> Items;
    local SFXPRIMP.EmblemDisplayInfo Emblem;
    local BannerItem Item;

    Item.Id = 0;
    Item.Title = GetUIString($706892);
    Items.AddItem(Item);
    foreach Class'SFXPRIMP'.default.EmblemList(Emblem)
    {
        if (Emblem.Id > 0 && Items.Find('Id', Emblem.Id) == -1 && Class'SFXMilanBannerRewards'.static.IsUnlocked(Emblem.Id))
        {
            Item.Id = Emblem.Id;
            Item.Title = GetUIString(Emblem.srTitle);
            Item.Resource = Emblem.BackgroundResource;
            Items.AddItem(Item);
        }
    }
    return Items;
}
public final function int GetEquippedBanner()
{
    local SFXAccomplishmentManager Manager;
    local int Id;
    local int Level;
    Manager = Class'SFXMilanBannerRewards'.static.GetManager();
    if (Manager != None)
    {
        Manager.GetCurrentReward(Id, Level);
    }
    return Id;
}
public final function bool EquipBanner(int EmblemID)
{
    return bPickerOpen && Class'SFXMilanBannerRewards'.static.EquipBanner(GetPC(), EmblemID);
}
// Only rows near the viewport poll this cache. Completions never hold or update a row reference.
public final function string GetBannerImage(int EmblemID)
{
    local string Resource;
    local int Index;
    local BannerImageRequest NewRequest;

    if (!bPickerOpen || EmblemID <= 0 || !Class'SFXMilanBannerRewards'.static.IsUnlocked(EmblemID))
    {
        return "";
    }
    Index = Class'SFXPRIMP'.default.EmblemList.Find('Id', EmblemID);
    if (Index == -1)
    {
        return "";
    }
    Resource = Class'SFXPRIMP'.default.EmblemList[Index].BackgroundResource;
    if (Resource == "")
    {
        return "";
    }
    if (Class'SFXEngine'.static.IsSeekFreeObjectSupported(Resource))
    {
        if (RetainBannerTexture(Resource) == None)
        {
            return "";
        }
        return Resource;
    }
    for (Index = 0; Index < Images.Length; ++Index)
    {
        if (Images[Index].Request.mImageName == Resource)
        {
            if (Images[Index].Request.mCompleted && Images[Index].Request.mDynamicImage != None)
            {
                RetainBannerTexture(Resource, Images[Index].Request.mDynamicImage);
                return PathName(Images[Index].Request.mDynamicImage);
            }
            return "";
        }
    }
    // Register before dispatch: a cached image may complete synchronously.
    NewRequest.Request.mImageName = Resource;
    Images.AddItem(NewRequest);
    Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentImageManager().RequestImage(Resource, OnRequestImageComplete);
    return "";
}
private final function OnRequestImageComplete(SFXOnlineImageRequest Result)
{
    local int Index;
    if (!bPickerOpen)
    {
        return;
    }
    for (Index = 0; Index < Images.Length; ++Index)
    {
        if (Images[Index].Request.mImageName == Result.mImageName)
        {
            Images[Index].Request = Result;
            if (Result.mDynamicImage != None)
            {
                RetainBannerTexture(Result.mImageName, Result.mDynamicImage);
            }
        }
    }
}
public function ClosePicker()
{
    bPickerOpen = FALSE;
    oPanel.InvokeMethod("DisposePicker");
    Close(TRUE);
}
public function GFxScreenVisibilityChange(bool bNewValue);
public function HandleButtonHelpRefresh(bool usingGamepad)
{
    local array<ASParams> Params;
    local ASParams Param;
    SetMouseShown(!usingGamepad);
    Param.Type = ASParamTypes.ASParam_Boolean;
    Param.bVar = usingGamepad;
    Params.AddItem(Param);
    oPanel.InvokeMethodArgs("RefreshButtonHelp", Params);
}
// As in SFXSFHandler_PCLoad, leave native controls unconsumed so the legacy key
// stream reaches SFXInputMovieClip. Its key-down events include held-stick/D-pad repeat;
// handling only CONTROL_*_RELEASE here prevented repeat and moved again on release.
public event function HandleButtonRefresh(bool usingGamepad)
{
    HandleButtonHelpRefresh(usingGamepad);
}

defaultproperties
{
    // Keep the multiplayer menu's UI world rendered while its lobby movie is closed.
    m_bRequiresUIWorld = TRUE
    ScreenLayout = GUILayout.GUILayout_PC
    m_bUseThumbstickAsDPad = TRUE
    BannerMovie = GFxMovieInfo'GUI_SF_MilanBannerSelect.LoadSave'
}
// END MILAN CHANGE
