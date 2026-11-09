// MILAN CHANGE - Stumpy - 2026/10/23
// Add method for getting and setting FOV settings
// MILAN CHANGE - Stumpy - 2026/11/09
// Move FOV methods and props to its own class
Class MilanProfile;

struct FovSetting 
{
    var EFovSettings Setting;
    var int bitOffset;
    var int Size;
};
enum EFovSettings
{
    General,
    Zoomed,
};

var array<FovSetting> FovSettings;

public static function bool GetMilanFOV(out int FOV)
{
    local FovSetting Item;
    local int ProfileSettingValue;
    local int moveBy;
    local SFXProfileSettings Profile;
    
    Profile = Class'MilanProfileBits'.static.GetProfile();
    if (!Profile.GetProfileSettingValueInt(3, ProfileSettingValue))
    {
        LogInternal("GETFOV - Setting missing, adding...", );
        Profile.AddSettingInt(3);
    }
    // LogInternal("GETFOV - Got setting value: " $ ProfileSettingValue, );
    foreach FovSettings(Item, )
    {
        if (Item.Setting == EFovSettings.General)
        {
            moveBy = 32 - Item.bitOffset - Item.Size;
            FOV = ProfileSettingValue << moveBy >>> moveBy + Item.bitOffset;
            // check if value is negative
            if (FOV >>> Item.Size - 1 == 1)
            {
                moveBy = 32 - Item.Size + 1;
                FOV = FOV << moveBy >>> moveBy;
                // Clear the left-most bit
                FOV = ~FOV + 1;
                // Return signed integer
            }
            // LogInternal("GETFOV - Got FOV: " $ FOV, );
        }
    }
    return TRUE;
}
public static function bool SetMilanFOV(int Value)
{
    local FovSetting Item;
    local int OriginalProfileSettingValue;
    local int FinalProfileSettingValue;
    local int MilanFOV;
    local int Mask;
    local SFXProfileSettings Profile;
    
    Profile = Class'MilanProfileBits'.static.GetProfile();
    // LogInternal("SETFOV - Got FOV Value: " $ Value, );
    if (!Profile.GetProfileSettingValueInt(3, OriginalProfileSettingValue))
    {
        LogInternal("SETFOV - Setting missing, adding...", );
        Profile.AddSettingInt(3);
    }
    foreach FovSettings(Item, )
    {
        if (Item.Setting == EFovSettings.General)
        {
            Mask = (1 << Item.Size) - 1 << Item.bitOffset;
            if (Value < 0)
            {
                // LogInternal("Value PRE: " $ Value, );
                // Make sure the sign bit is set and invert the Value
                Value = 1 << Item.Size - 1 | ~Value + 1;
                // LogInternal("Value POST: " $ Value, );
            }
            FinalProfileSettingValue = OriginalProfileSettingValue & ~Mask | Value << Item.bitOffset;
            Profile.SetProfileSettingValueInt(3, FinalProfileSettingValue);
            LogInternal("SETFOV - Set Profile value: " $ FinalProfileSettingValue, );
            return TRUE;
        }
    }
    return FALSE;
}
public static function bool GetMilanZoomFov(out int FOV)
{
    local FovSetting Item;
    local int ProfileSettingValue;
    local int moveBy;
    local SFXProfileSettings Profile;
    
    Profile = Class'MilanProfileBits'.static.GetProfile();
    if (!Profile.GetProfileSettingValueInt(3, ProfileSettingValue))
    {
        LogInternal("GETFOVZoom - Setting missing, adding...", );
        Profile.AddSettingInt(3);
    }
    // LogInternal("GETFOVZoom - Got setting value: " $ ProfileSettingValue, );
    foreach FovSettings(Item, )
    {
        if (Item.Setting == EFovSettings.Zoomed)
        {
            moveBy = 32 - Item.bitOffset - Item.Size;
            FOV = ProfileSettingValue << moveBy >>> moveBy + Item.bitOffset;
            // check if value is negative
            if (FOV >>> Item.Size - 1 == 1)
            {
                moveBy = 32 - Item.Size + 1;
                FOV = FOV << moveBy >>> moveBy;
                // Clear the left-most bit
                FOV = ~FOV + 1;
                // Return signed integer
            }
            // LogInternal("GETFOV - Got FOV: " $ FOV, );
        }
    }
    return TRUE;
}
public static function bool SetMilanZoomFOV(int Value)
{
    local FovSetting Item;
    local int OriginalProfileSettingValue;
    local int FinalProfileSettingValue;
    local int MilanFOV;
    local int Mask;
    local SFXProfileSettings Profile;
    
    Profile = Class'MilanProfileBits'.static.GetProfile();
    // LogInternal("SETFOVZoom - Got FOV Value: " $ Value, );
    if (!Profile.GetProfileSettingValueInt(3, OriginalProfileSettingValue))
    {
        LogInternal("SETFOVZoom - Setting missing, adding...", );
        Profile.AddSettingInt(3);
    }
    foreach FovSettings(Item, )
    {
        if (Item.Setting == EFovSettings.Zoomed)
        {
            Mask = (1 << Item.Size) - 1 << Item.bitOffset;
            if (Value < 0)
            {
                // LogInternal("Value PRE: " $ Value, );
                // Make sure the sign bit is set and invert the Value
                Value = 1 << Item.Size - 1 | ~Value + 1;
                // LogInternal("Value POST: " $ Value, );
            }
            FinalProfileSettingValue = OriginalProfileSettingValue & ~Mask | Value << Item.bitOffset;
            Profile.SetProfileSettingValueInt(3, FinalProfileSettingValue);
            LogInternal("SETFOVZoom - Set Profile value: " $ FinalProfileSettingValue, );
            return TRUE;
        }
    }
    return FALSE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    FovSettings = ({Setting = EFovSettings.General, bitOffset = 8, Size = 8}, 
                   {Setting = EFovSettings.Zoomed, bitOffset = 16, Size = 8}
                  )
}