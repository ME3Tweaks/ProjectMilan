// NEW to Milan - 11/26/2026 - Mgamerz
// Player toggles for showing GUI elements, cached for per-frame checks
Class MilanGUIVisibility extends Object
    config(Game);

// Slots 0-15
const SETTING_ID = 9;
// Slots 16-31
const SETTING_ID_2 = 10;

// Value is the element's slot in the setting packed int. NEVER reuse or reorder!
enum EMilanGUIElement
{
    GUIElement_NearestTeammate,
    // Add more here as you go
};

struct GUIElementDefault
{
    var EMilanGUIElement Element;
    var bool bDefaultVisible;
};

var config array<GUIElementDefault> Defaults;
var transient int VisibleMask;
var transient bool bCacheValid;

public static function bool IsVisible(EMilanGUIElement Element)
{
    if (!default.bCacheValid)
    {
        // Update cache so we don't have to do bit lookups again
        RefreshCache();
    }
    return (default.VisibleMask & (1 << int(Element))) != 0;
}
// Updates the cached visibilities. We cache onto default.VisibleMask
public static function RefreshCache()
{
    local SFXProfileSettings Profile;
    local int Mask;
    local int Packed;
    local int Slot;
    local int Stored;
    local int i;

    // Unlisted elements are visible
    Mask = -1;
    for (i = 0; i < default.Defaults.Length; i++)
    {
        if (!default.Defaults[i].bDefaultVisible)
        {
            Mask = Mask & ~(1 << int(default.Defaults[i].Element));
        }
    }
    Profile = Class'MilanProfileBits'.static.GetProfile();
    if (Profile == None)
    {
        default.VisibleMask = Mask;
        default.bCacheValid = FALSE;
        return;
    }
    for (Slot = 0; Slot < 32; Slot++)
    {
        if (Slot == 0)
        {
            Packed = 0;
            Profile.GetProfileSettingValueInt(SETTING_ID, Packed);
        }
        else if (Slot == 16)
        {
            // Roll to new packed number
            Packed = 0;
            Profile.GetProfileSettingValueInt(SETTING_ID_2, Packed);
        }
        // 0 default, 1 shown, 2 hidden, 3 reserved
        Stored = (Packed >>> ((Slot % 16) * 2)) & 3;
        if (Stored == 1)
        {
            Mask = Mask | (1 << Slot);
        }
        else if (Stored == 2)
        {
            Mask = Mask & ~(1 << Slot);
        }
    }
    default.VisibleMask = Mask;
    default.bCacheValid = TRUE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    VisibleMask = -1
}
