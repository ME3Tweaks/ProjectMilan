// MILAN CHANGE 
// 09/28/2026 - Stumpy
// Handler for ZoomSnap toggle in settings

Class AATGUI_Option_ZoomSnap extends SFXGUI_OptionsObject within BioSFHandler_Options
    native;

var bool bInitialized;
var int radioIndex;
var int DefaultValue;
var int DefaultMergedValue;
var int AATModTlkOnId;
var int AATModTlkOffId;
var int bitOffset;
var int minValue;
var int MaxValue;
var int aimAssistSettingID;
var int settingValueSnapshot;
var int bitMask;
var transient string sComment;

public event function ApplyOptionValue(int nValue)
{
    local int i;
    
    LogInternal(string(Name), );
    if (nValue < minValue || nValue > MaxValue)
    {
        return;
    }
    radioIndex = nValue;
    LogInternal("CurrentValue: " $ radioIndex, );
    SaveOption();
}
public event function SaveOption()
{
    local SFXEngine oEngine;
    local int otherValues;
    local int finalValue;
    
    oEngine = SFXEngine(Class'Engine'.static.GetEngine());
    // clear specific bits for the new value, then set by simple addition
    oEngine.GetProfileSettings().GetProfileSettingValueInt(aimAssistSettingID, settingValueSnapshot);
    otherValues = settingValueSnapshot & bitMask;
    finalValue = (radioIndex << bitOffset) + otherValues;
    // save values in Setting_AimAssist
    oEngine.GetProfileSettings().SetProfileSettingValueInt(aimAssistSettingID, finalValue);
    LogInternal("Value applied: " $ ToHex(finalValue), );
}
public event function ConstructRadioGroupOption(out RadioGroupOption Option)
{
    local SFXEngine oEngine;
    
    LogInternal(string(Option.Id), );
    if (!bInitialized)
    {
        oEngine = SFXEngine(Class'SFXEngine'.static.GetEngine());
        oEngine.GetProfileSettings().GetProfileSettingValueInt(aimAssistSettingID, settingValueSnapshot);
        radioIndex = (settingValueSnapshot & ~bitMask) >> bitOffset;
        // Reset to default if the game's default value is detected
        if (settingValueSnapshot == 1)
        {
            oEngine.GetProfileSettings().SetProfileSettingValueInt(aimAssistSettingID, DefaultMergedValue);
            ResetToDefault();
            radioIndex = 1;
        }
    }
    if (radioIndex < minValue)
    {
        radioIndex = 1;
    }
    else if (radioIndex > MaxValue)
    {
        radioIndex = 0;
    }
    RebuildSliderOptions(radioIndex, Option);
}
public event function int GetOptionValue()
{
    return radioIndex;
}
public event function bool OptionIsAvailable()
{
    return TRUE;
}
public event function ResetToDefault()
{
    local RadioGroupOption Option;
    
    RebuildSliderOptions(DefaultValue, Option);
    ApplyOptionValue(DefaultValue);
}
public function RebuildSliderOptions(int currentZoomSnapValue, out RadioGroupOption Option)
{
    local OptionText oValue0;
    local OptionText oValue1;
    
    LogInternal("Building ZoomSnap RadioGroup with value - " $ currentZoomSnapValue, );
    oValue0.Label = stringref(AATModTlkOnId);
    oValue0.Story = Option.Story;
    oValue0.Value = 0;
    oValue1.Label = stringref(AATModTlkOffId);
    oValue1.Story = Option.Story;
    oValue1.Value = 1;
    Option.Value1 = oValue1;
    Option.Value0 = oValue0;
    Option.DefaultVal = currentZoomSnapValue;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    sComment = "2147483647 == 01111111 11111111 11111111 11111111"
    bitMask = 2147483647
    bitOffset = 31
    radioIndex = 1
    DefaultValue = 1
    DefaultMergedValue = -2147442048
    AATModTlkOnId = 653223
    AATModTlkOffId = 653225
    minValue = 0
    MaxValue = 1
    aimAssistSettingID = 31
}