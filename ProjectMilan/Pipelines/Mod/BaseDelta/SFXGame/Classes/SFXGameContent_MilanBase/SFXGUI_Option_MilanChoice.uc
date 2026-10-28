// NEW to Milan
// 10/25/2026 - Mgamerz
// GUI option for options that pulls from profile IDs that take callbacks when options are changed
class SFXGUI_Option_MilanChoice extends SFXGUI_OptionsObject within BioSFHandler_Options
    config(Game);

struct MilanChoiceOption
{
    var EGuiOptions OptionId;
    var int SettingId;
    var int BitOffset;
    var int BitCount;
    var int DefaultValue;
    var int DefaultChoice;
    var name ChangeHook;
    var name Overlay;
    var array<OptionText> Values;
};

var config array<MilanChoiceOption> Choices;

public event function bool OptionIsAvailable()
{
    return TRUE;
}

public event function ConstructTextSliderOption(out TextSliderOption Option)
{
    local int Index;

    OptionId = Option.Id;
    Index = default.Choices.Find('OptionId', OptionId);
    if (Index != -1)
    {
        Option.Values = default.Choices[Index].Values;
        Option.DefaultVal = GetOptionValue();
    }
}

public event function int GetOptionValue()
{
    local int Index;
    local int Value;
    local MilanChoiceOption Choice;

    Index = default.Choices.Find('OptionId', OptionId);
    if (Index == -1)
    {
        return 0;
    }
    Choice = default.Choices[Index];
    Value = Class'MilanProfileBits'.static.Get(Choice.SettingId, Choice.BitOffset, Choice.BitCount);
    if (Value == Choice.DefaultValue)
    {
        if (Choice.ChangeHook == 'ScreenOverlays')
        {
            return Class'MilanScreenOverlaySettings'.static.GetOverlayLevel(Choice.Overlay);
        }
        return Choice.DefaultChoice;
    }
    return Clamp(Value - 1, 0, Choice.Values.Length - 1);
}

public event function ApplyOptionValue(int nValue)
{
    local int Index;
    local MilanChoiceOption Choice;

    Index = default.Choices.Find('OptionId', OptionId);
    if (Index == -1)
    {
        return;
    }
    Choice = default.Choices[Index];
    if (nValue >= 0 && nValue < Choice.Values.Length && Class'MilanProfileBits'.static.Set(Choice.SettingId, Choice.BitOffset, Choice.BitCount, nValue + 1))
    {
        ApplyChange(Choice.ChangeHook);
    }
}

public event function SaveOption()
{
    // ApplyOptionValue writes before SaveAndExit saves
}

public event function ResetToDefault()
{
    local int Index;
    local MilanChoiceOption Choice;

    if (Outer.m_lstOptsToReset.Length > 0 && Outer.m_lstOptsToReset.Find(int(OptionId)) == -1)
    {
        return;
    }
    Index = default.Choices.Find('OptionId', OptionId);
    if (Index != -1)
    {
        Choice = default.Choices[Index];
        if (Class'MilanProfileBits'.static.Set(Choice.SettingId, Choice.BitOffset, Choice.BitCount, Choice.DefaultValue))
        {
            ApplyChange(Choice.ChangeHook);
        }
    }
}

private function ApplyChange(name Hook)
{
    // Apply hooks here
    if (Hook == 'ScreenOverlays')
    {
        Class'MilanScreenOverlaySettings'.static.ApplyAll();
    }
}