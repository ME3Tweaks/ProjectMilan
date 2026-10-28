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

// ProfileIndex selects two bits in the profile setting
// NEVER reuse or reorder them!
struct OverlayDefinition
{
    var name Overlay;
    var int ProfileIndex;
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
var config int ProfileSettingId;

public static function int GetOverlayLevel(name Overlay)
{
    local int Index;
    local int Level;
    local int StoredValue;

    Index = default.Overlays.Find('Overlay', Overlay);
    if (Index == -1)
    {
        return LEVEL_NORMAL;
    }
    Level = default.Overlays[Index].DefaultLevel;
    StoredValue = Class'MilanProfileBits'.static.Get(default.ProfileSettingId, 2 * default.Overlays[Index].ProfileIndex, 2);
    if (StoredValue != 0)
    {
        Level = StoredValue - 1;
    }
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
                ApplyLiveMaterials(MIC, Target.Field, Value, Color, FALSE);
            }
            break;
        case EOverlayTargetType.OTT_VectorParameter:
            MIC = MaterialInstanceConstant(FindObject(Target.ObjectPath, Class'MaterialInstanceConstant'));
            if (MIC != None)
            {
                Color = Level == LEVEL_NONE ? Target.OffColor : (Level == LEVEL_REDUCED ? Target.ReducedColor : Target.NormalColor);
                MIC.SetVectorParameterValue(Target.Field, Color);
                ApplyLiveMaterials(MIC, Target.Field, Value, Color, TRUE);
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

// Helper function to apply changes to live materials such as frame buffer materials
private static function ApplyLiveMaterials(MaterialInstanceConstant Source, name Field, float Value, LinearColor Color, bool bVector)
{
    local Engine Engine;
    local int i;
    local int j;
    local LocalPlayer Player;

    Engine = Class'Engine'.static.GetEngine();
    if (Engine == None)
    {
        return;
    }
    for (i = 0; i < Engine.GamePlayers.Length; i++)
    {
        Player = Engine.GamePlayers[i];
        if (Player != None)
        {
            ApplyLiveChain(Player.PlayerPostProcess, Source, Field, Value, Color, bVector);
            for (j = 0; j < Player.PlayerPostProcessChains.Length; j++)
            {
                ApplyLiveChain(Player.PlayerPostProcessChains[j], Source, Field, Value, Color, bVector);
            }
        }
    }
}

private static function ApplyLiveChain(PostProcessChain Chain, MaterialInstanceConstant Source, name Field, float Value, LinearColor Color, bool bVector)
{
    local int i;
    local MaterialEffect Effect;
    local MaterialInstanceConstant MIC;
    local MaterialInstance Ancestor;

    if (Chain == None)
    {
        return;
    }
    for (i = 0; i < Chain.Effects.Length; i++)
    {
        Effect = MaterialEffect(Chain.Effects[i]);
        if (Effect == None)
        {
            continue;
        }
        MIC = MaterialInstanceConstant(Effect.Material);
        Ancestor = MIC;
        while (Ancestor != None && Ancestor != Source)
        {
            Ancestor = MaterialInstance(Ancestor.Parent);
        }
        if (MIC != None && Ancestor == Source)
        {
            if (bVector)
            {
                MIC.SetVectorParameterValue(Field, Color);
            }
            else
            {
                MIC.SetScalarParameterValue(Field, Value);
            }
        }
    }
}

defaultproperties
{
    ProfileSettingId = 4
}