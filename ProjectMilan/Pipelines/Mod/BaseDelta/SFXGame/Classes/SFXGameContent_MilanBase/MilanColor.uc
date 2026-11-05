// NEW to Milan - Mgamerz - 2026-11-01
// Helpers for MP appearance colors

class MilanColor extends Object
    abstract;

// Used to convert old values to new packed versions, indexed by the swatch ID
// Tint1, Tint2, PatternColor and Phong all used the same 54 colors
// DO NOT EDIT
var array<int> LegacyTintColors;
var array<int> LegacyEmissiveColors;
var array<int> LegacySkinToneColors;

// Pack a color into 0xRRGGBB, ignoring alpha
public static function int PackRGB(LinearColor C)
{
    return (ChannelToByte(C.R) << 16) | (ChannelToByte(C.G) << 8) | ChannelToByte(C.B);
}

public static function int ChannelToByte(float Channel)
{
    return Clamp(int(Channel * 255.0 + 0.5), 0, 255);
}

// Unpack 0xRRGGBB into a color with alpha 1
public static function LinearColor UnpackRGB(int Packed)
{
    local LinearColor C;

    C.R = float((Packed >>> 16) & 255) / 255.0;
    C.G = float((Packed >>> 8) & 255) / 255.0;
    C.B = float(Packed & 255) / 255.0;
    C.A = 1.0;
    return C;
}

// Does this value override the default?
public static function bool HasColor(int Packed)
{
    return Packed >= 0;
}

// #RRGGBB, or an empty string if there is no color
public static function string ToHexString(int Packed)
{
    if (!HasColor(Packed))
    {
        return "";
    }
    // ToHex returns 8 uppercase digits with leading zeros, so we mask off the high byte and take the rightmost 6 digits
    return "#" $ Right(ToHex(Packed & 16777215), 6);
}

// Parse #RRGGBB
// Returns FALSE and leaves Packed alone if the string isn't in the correct format
public static function bool ParseHexString(string S, out int Packed)
{
    local int I;
    local int Digit;
    local int Value;

    if (Len(S) != 7 || Left(S, 1) != "#")
    {
        // Wrong format - wrong len or doesn't start with #
        return FALSE;
    }
    for (I = 1; I < 7; I++)
    {
        Digit = InStr("0123456789ABCDEF", Caps(Mid(S, I, 1)));
        if (Digit < 0)
        {
            return FALSE;
        }
        Value = (Value << 4) | Digit;
    }
    Packed = Value;
    return TRUE;
}

// Is the string an optionally negative decimal integer?
public static function bool IsInteger(string S)
{
    local int I;
    local int Start;

    Start = Left(S, 1) == "-" ? 1 : 0;
    if (Len(S) <= Start)
    {
        return FALSE;
    }
    for (I = Start; I < Len(S); I++)
    {
        if (InStr("0123456789", Mid(S, I, 1)) < 0)
        {
            return FALSE;
        }
    }
    return TRUE;
}

// Reads a color field from the MP profile character string. Inputs can vary:
// #RRGGBB = that color
// bare integer = old palette ID
// empty = no override
// anything else = DefaultColor.
// Palette: 
// 0 = tint list 
// 1 = emissive 
// 2 = skin tone
private static function int ParseColorField(string Field, int Palette, int DefaultColor)
{
    local int Packed;
    local int Id;

    if (Field == "")
    {
        return -1;
    }
    if (ParseHexString(Field, Packed))
    {
        // It's a hex color
        return Packed;
    }
    if (!IsInteger(Field))
    {
        return DefaultColor;
    }
    // Old swatch IDs
    // Ensure in range, if not, just do nothing.
    Id = int(Field);
    if (Id < 0)
    {
        return -1;
    }
    switch (Palette)
    {
        case 0:
            return Id < default.LegacyTintColors.Length ? default.LegacyTintColors[Id] : -1;
        case 1:
            return Id < default.LegacyEmissiveColors.Length ? default.LegacyEmissiveColors[Id] : -1;
        case 2:
            return Id < default.LegacySkinToneColors.Length ? default.LegacySkinToneColors[Id] : -1;
    }
    return -1;
}

// Read other fields
public static function int ParseTintField(string Field, int DefaultColor)
{
    return ParseColorField(Field, 0, DefaultColor);
}

public static function int ParseEmissiveField(string Field, int DefaultColor)
{
    return ParseColorField(Field, 1, DefaultColor);
}

public static function int ParseSkinToneField(string Field, int DefaultColor)
{
    return ParseColorField(Field, 2, DefaultColor);
}

defaultproperties
{
    // Old swatch colors
    LegacyTintColors = (7995393, 15538980, 16160633, 8072704, 15951139, 16428417, 8210688, 16225309, 16631691,
                        8616704, 16708096, 16775066, 4220696, 9291583, 12902300, 24096, 3847498, 10671004,
                        22867, 108702, 8113607, 65280, 42578, 65535, 255, 16711680, 16711935,
                        88958, 44527, 7262455, 13924, 29371, 8300247, 852301, 3027346, 8946366,
                        3342411, 6696593, 10651582, 4980810, 9578383, 12357311, 7995429, 15537243, 16226462,
                        0, 6447714, 16777215, 3682349, 7562070, 13087129, 6306066, 9200184, 13015918)
    LegacyEmissiveColors = (65280, 16711680, 15951139, 42578, 9578383, 16711935, 16708096, 44527, 65535,
                            16777215, 0, 255)
    LegacySkinToneColors = (10607601, 11051225, 14596830, 10075366, 10671004, 12248757, 14085808, 13087129, 15782039,
                            16777215)
}
