// NEW to Milan - 11/25/2026 - Mgamerz
// Holds extended character record data. We can't add varaibles to the base
// class as it's native and will blow the game up randomly

class SFXMilanCharacterRecord extends SFXMPCharacterRecord;

var int HeavyWeaponId;

// Heavy weapon ID of a record, which has 0 (Cobra) if it has none (the default)
public static final function int GetHeavyWeaponId(SFXMPCharacterRecord Record)
{
    local SFXMilanCharacterRecord MilanRecord;

    MilanRecord = SFXMilanCharacterRecord(Record);
    if (MilanRecord == None)
    {
        return 0;
    }
    return MilanRecord.HeavyWeaponId;
}

public static final function SetHeavyWeaponId(SFXMPCharacterRecord Record, int Id)
{
    local SFXMilanCharacterRecord MilanRecord;

    MilanRecord = SFXMilanCharacterRecord(Record);
    if (MilanRecord != None)
    {
        MilanRecord.HeavyWeaponId = Id;
    }
}

// Reset must remove additions this class adds
public function ResetCharacter(bool RetainCustomization)
{
    Super.ResetCharacter(RetainCustomization);
    if (!RetainCustomization)
    {
        HeavyWeaponId = 0;
    }
}

defaultproperties {

}