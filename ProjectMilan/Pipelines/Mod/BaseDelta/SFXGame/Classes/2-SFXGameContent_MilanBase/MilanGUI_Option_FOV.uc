// MILAN CHANGE - Stumpy - 2026-10-23
// New class to handle general FOV offset
Class MilanGUI_Option_FOV extends SFXGUI_OptionsObject within BioSFHandler_Options;

var int sliderIndex;
var bool bInitialized;
var int fovModTlkNumeralStartId;
var int MinVal;
var int MaxVal;
var int DefaultVal;
var int Multiplier;

public event function ApplyOptionValue(int nValue)
{
    LogInternal(string(Name), );
    LogInternal("CurrentValue: " $ sliderIndex, );
    LogInternal("Current nValue: " $ nValue, );
    if (nValue + MinVal > MaxVal || nValue - MaxVal < MinVal)
    {
        LogInternal("Value " $ nValue - MaxVal $ "does not fit between" $ MinVal $ " and " $ MaxVal, );
        return;
    }
    sliderIndex = nValue;
}
public function UpdateCamera(int nValue)
{
    local BioWorldInfo BWI;
    local PlayerController PC;
    local SFXEngine Engine;
    local SFXPlayerCamera Camera;
    local SFXCameraMode CameraMode;
    
    LogInternal(string(Name), );
    if (nValue + MinVal > MaxVal || nValue - MaxVal < MinVal)
    {
        LogInternal("Value " $ nValue - MaxVal $ "does not fit between" $ MinVal $ " and " $ MaxVal, );
        return;
    }
    sliderIndex = nValue;
    BWI = BioWorldInfo(Class'Engine'.static.GetCurrentWorldInfo());
    PC = BWI.GetLocalPlayerController();
    if (PC == None || PC.PlayerCamera == None)
    {
        return;
    }
    if (SFXPlayerCamera(PC.PlayerCamera) == None || SFXPlayerCamera(PC.PlayerCamera).CurrentCameraMode == None)
    {
        return;
    }
    SFXPlayerCamera(PC.PlayerCamera).CurrentCameraMode.Initialize();
}
public event function SaveOption()
{
    local BioPlayerController PC;
    
    if (sliderIndex + MinVal > MaxVal)
    {
        LogInternal("SET FOV too high (" $ sliderIndex + MinVal $ "), clamping to " $ MaxVal, );
        sliderIndex = MaxVal;
    }
    else if (sliderIndex - MaxVal < MinVal)
    {
        LogInternal("SET FOV too low (" $ sliderIndex - MaxVal $ "), clamping to " $ MinVal, );
        sliderIndex = MinVal;
    }
    Class'MilanProfile'.static.SetMilanFOV(sliderIndex + MinVal);
    UpdateCamera(sliderIndex);
    ApplyOptionValue(sliderIndex);
}
public event function ConstructTextSliderOption(out BioSFHandler_Options.TextSliderOption Option)
{
    LogInternal(string(Name), );
    if (!bInitialized)
    {
        Class'MilanProfile'.static.GetMilanFOV(sliderIndex);
        sliderIndex = sliderIndex + MaxVal;
        if (sliderIndex + MinVal > MaxVal)
        {
            LogInternal("GET FOV too high (" $ sliderIndex + MinVal $ "), clamping to " $ MaxVal, );
            sliderIndex = MaxVal;
        }
        else if (sliderIndex - MaxVal < MinVal)
        {
            LogInternal("GET FOV too low (" $ sliderIndex - MaxVal $ "), clamping to " $ MinVal, );
            sliderIndex = MinVal;
        }
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
    local BioSFHandler_Options.TextSliderOption Option;
    
    RebuildSliderOptions(DefaultVal, Option);
}
public function RebuildSliderOptions(int currentFOVValue, out BioSFHandler_Options.TextSliderOption Option)
{
    local BioSFHandler_Options.OptionText oValue;
    local int fovValue;
    
    LogInternal("Building FOV slider. Default slider should result in FOV " $ currentFOVValue, );
    for (fovValue = MinVal; fovValue <= MaxVal; fovValue++)
    {
        oValue.Label = stringref(fovModTlkNumeralStartId + fovValue);
        oValue.Story = Option.Story;
        oValue.Value = fovValue;
        Option.Values.AddItem(oValue);
        LogInternal("Adding slider: " $ fovValue $ "Stringref: " $ fovModTlkNumeralStartId + fovValue, );
        if (currentFOVValue == fovValue)
        {
            LogInternal("Found default FOV slider index at " $ fovValue, );
            sliderIndex = fovValue;
            Option.DefaultVal = fovValue;
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    sliderIndex = 0
    fovModTlkNumeralStartId = 49875920
    MinVal = -12
    DefaultVal = 0
    MaxVal = 12
    Multiplier = 5
}