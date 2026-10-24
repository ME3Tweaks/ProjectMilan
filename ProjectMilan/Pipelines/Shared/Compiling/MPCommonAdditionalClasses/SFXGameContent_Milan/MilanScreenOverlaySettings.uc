// MILAN CHANGE - Mgamerz - 2026-10-21
// Allows configuring MIC and distributions for accessibility
Class MilanScreenOverlaySettings extends Object
    config(Game);

const LEVEL_NORMAL = 0;
const LEVEL_REDUCED = 1;
const LEVEL_NONE = 2;

enum EOverlayTargetType
{
    // MaterialInstanceConstant scalar parameter named by Field
    OTT_ScalarParameter,
    // MaterialInstanceConstant vector parameter named by Field, using the Color values
    OTT_VectorParameter,
    // DistributionFloatParameterBase output range: Field is MaxOutput or MinOutput
    OTT_DistributionOutput,
};

// ProfileIndex is the overlay's byte in the profile setting: never reuse or reorder one
struct OverlayDefinition
{
    var name Overlay;
    var int ProfileIndex;
    // Used until the profile setting exists, and for a profile that has no byte for this overlay yet
    var int DefaultLevel;
    // Without it, None is treated as Reduced
    var bool bAllowNone;
};

struct OverlayTarget
{
    var name Overlay;
    var EOverlayTargetType Type;
    // memory path of the object
    var string ObjectPath;
    var name Field;
    var float Normal;
    var float Reduced;
    var float Off;
    var LinearColor NormalColor;
    var LinearColor ReducedColor;
    var LinearColor OffColor;
};

var config array<OverlayDefinition> Overlays;
var config array<OverlayTarget> Targets;

public static function int GetOverlayLevel(name Overlay)
{
    local int Index;
    local int Level;

    Index = default.Overlays.Find('Overlay', Overlay);
    if (Index == -1)
    {
        return LEVEL_NORMAL;
    }
    Level = default.Overlays[Index].DefaultLevel;
    if (Level == LEVEL_NONE && !default.Overlays[Index].bAllowNone)
    {
        return LEVEL_REDUCED;
    }
    if (Level < LEVEL_NORMAL || Level > LEVEL_NONE)
    {
        return LEVEL_NORMAL;
    }
    return Level;
}

public static function ApplyAll()
{
    local int Index;

    for (Index = 0; Index < default.Targets.Length; Index++)
    {
        ApplyTarget(default.Targets[Index], GetOverlayLevel(default.Targets[Index].Overlay));
    }
}

public static function ApplyTarget(OverlayTarget Target, int Level)
{
    local float Value;
    local LinearColor Color;
    local MaterialInstanceConstant MIC;
    local DistributionFloatParameterBase Distribution;

    Value = Level == LEVEL_NONE ? Target.Off : (Level == LEVEL_REDUCED ? Target.Reduced : Target.Normal);
    switch (Target.Type)
    {
        case EOverlayTargetType.OTT_ScalarParameter:
            MIC = MaterialInstanceConstant(FindObject(Target.ObjectPath, Class'MaterialInstanceConstant'));
            if (MIC != None)
            {
                MIC.SetScalarParameterValue(Target.Field, Value);
            }
            break;
        case EOverlayTargetType.OTT_VectorParameter:
            MIC = MaterialInstanceConstant(FindObject(Target.ObjectPath, Class'MaterialInstanceConstant'));
            if (MIC != None)
            {
                Color = Level == LEVEL_NONE ? Target.OffColor : (Level == LEVEL_REDUCED ? Target.ReducedColor : Target.NormalColor);
                MIC.SetVectorParameterValue(Target.Field, Color);
            }
            break;
        case EOverlayTargetType.OTT_DistributionOutput:
            Distribution = DistributionFloatParameterBase(FindObject(Target.ObjectPath, Class'DistributionFloatParameterBase'));
            if (Distribution != None)
            {
                if (Target.Field == 'MinOutput')
                {
                    Distribution.MinOutput = Value;
                }
                else
                {
                    Distribution.MaxOutput = Value;
                }
            }
            break;
    }
}