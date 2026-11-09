// NEW to Milan - Mgamerz - 2026-10-26
// Helper class for packing values into an integer
class MilanProfileBits extends Object;

// Get profile settings instance
public static function SFXProfileSettings GetProfile()
{
    local SFXEngine Engine;

    Engine = SFXEngine(Class'Engine'.static.GetEngine());
    if (Engine == None)
    {
        return None;
    }
    return Engine.GetProfileSettings();
}

// Is the requested offset/size valid
public static function bool IsValidRange(int BitOffset, int BitCount)
{
    return BitCount > 0 && BitCount < 32 && BitOffset >= 0 && BitOffset <= 32 - BitCount;
}

// Get the value for the given setting ID, unpack the bits and return the masked value
public static function int Get(int SettingId, int BitOffset, int BitCount)
{
    local SFXProfileSettings Profile;
    local int Packed;

    if (!IsValidRange(BitOffset, BitCount))
    {
        return 0;
    }
    Profile = GetProfile();
    if (Profile == None || !Profile.GetProfileSettingValueInt(SettingId, Packed))
    {
        return 0;
    }
    return (Packed >>> BitOffset) & ((1 << BitCount) - 1);
}

// Set the value of the given setting id, at the given bit offset, with bitcount - masking the value into the window
// This preserves existing bits
public static function bool Set(int SettingId, int BitOffset, int BitCount, int Value)
{
    local SFXProfileSettings Profile;
    local int Packed;
    local int Mask;

    if (!IsValidRange(BitOffset, BitCount))
    {
        return FALSE;
    }
    Mask = (1 << BitCount) - 1;
    if (Value < 0 || Value > Mask)
    {
        return FALSE;
    }
    Profile = GetProfile();
    if (Profile == None)
    {
        return FALSE;
    }
    Profile.AddMissingDefaultSettings();
    if (!Profile.GetProfileSettingValueInt(SettingId, Packed))
    {
        return FALSE;
    }
    Packed = (Packed & ~(Mask << BitOffset)) | (Value << BitOffset);
    return Profile.SetProfileSettingValueInt(SettingId, Packed);
}