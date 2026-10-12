// MILAN CHANGE 
// 09/28/2026 - Stumpy
// Handler for the Adhesion text slider in settings

Class AATGUI_Option_Adhesion extends SFXGUI_OptionsObject within BioSFHandler_Options
    native;

var bool bInitialized;
var int sliderIndex;
var int DefaultValue;
var int DefaultMergedValue;
var int AATModTlkNumeralStartId;
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
    sliderIndex = nValue;
    LogInternal("CurrentValue: " $ sliderIndex, );
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
    finalValue = (sliderIndex << bitOffset) + otherValues;
    // save values in Setting_AimAssist
    oEngine.GetProfileSettings().SetProfileSettingValueInt(aimAssistSettingID, finalValue);
    LogInternal("value applied: " $ ToHex(finalValue), );
}
public event function ConstructTextSliderOption(out TextSliderOption Option)
{
    local SFXEngine oEngine;
    
    LogInternal(string(Name), );
    LogInternal(string(Option.Id), );
    if (!bInitialized)
    {
        oEngine = SFXEngine(Class'SFXEngine'.static.GetEngine());
        oEngine.GetProfileSettings().GetProfileSettingValueInt(aimAssistSettingID, settingValueSnapshot);
        sliderIndex = (settingValueSnapshot & ~bitMask) >> bitOffset;
        // Reset to default if the game's default value is detected
        if (settingValueSnapshot == 1)
        {
            oEngine.GetProfileSettings().SetProfileSettingValueInt(aimAssistSettingID, DefaultMergedValue);
            ResetToDefault();
            sliderIndex = 10;
        }
    }
    // if the slider is out of bounds, something went wrong. Resetting it
    if (sliderIndex < minValue)
    {
        sliderIndex = 10;
    }
    else if (sliderIndex > MaxValue)
    {
        sliderIndex = 10;
    }
    RebuildSliderOptions(sliderIndex, Option);
}
public event function int GetOptionValue()
{
    return sliderIndex;
}
public event function bool OptionIsAvailable()
{
    return TRUE;
}
public event function ResetToDefault()
{
    local TextSliderOption Option;
    
    RebuildSliderOptions(DefaultValue, Option);
    ApplyOptionValue(DefaultValue);
}
public function RebuildSliderOptions(int currentAdhesionValue, out TextSliderOption Option)
{
    local OptionText oValue;
    local int adhesionValue;
    
    LogInternal("Building adhesion slider. Default slider should result in current adhesion " $ currentAdhesionValue, );
    for (adhesionValue = minValue; adhesionValue <= MaxValue; adhesionValue++)
    {
        oValue.Label = stringref(AATModTlkNumeralStartId + adhesionValue);
        oValue.Story = Option.Story;
        oValue.Value = adhesionValue;
        Option.Values.AddItem(oValue);
        if (currentAdhesionValue == adhesionValue)
        {
            LogInternal("Found default adhesion slider index at " $ adhesionValue, );
            sliderIndex = adhesionValue;
            Option.DefaultVal = adhesionValue;
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    sComment = "-4033 == 11111111 11111111 11110000 00111111"
    bitMask = -4033
    bitOffset = 6
    sliderIndex = 10
    DefaultValue = 10
    DefaultMergedValue = -2147442048
    AATModTlkNumeralStartId = 49875634
    minValue = 0
    MaxValue = 30
    aimAssistSettingID = 31
}