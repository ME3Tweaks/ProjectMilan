// MILAN CHANGE - Mgamerz - 2026-10-27
// Serialize heavy weapon ID to end of character string
// MILAN CHANGE - Mgamerz - 2026-11-01
// Serialize appearance colors as #RRGGBB instead of palette IDs
private final function string GetCharacter2(const out SFXMPCharacterRecord CharacterRecord, const out SFXSaveManagerMP MPSaveManager, int nCharacterIndex)
{
    local string KitName;
    local string CharacterName;
    local string Tint1ID;
    local string Tint2ID;
    local string PatternID;
    local string PatternColorID;
    local string PhongID;
    local string EmissiveID;
    local string SkinToneID;
    local string SecondsPlayed;
    local string TimeStamp;
    local string Powers;
    local string HotKeys;
    local string Weapons;
    local string WeaponMods;
    local string Deployed;
    local string LeveledUp;
    local int KitDataIndex;
    local array<int> RequiredDLC;
    local array<string> ServerCharacterDataParts;
    
    KitName = string(CharacterRecord.KitName);
    KitDataIndex = MPSaveManager.MPKits.Find('KitName', CharacterRecord.KitName);
    if (KitDataIndex < 0)
    {
        return "";
    }
    RequiredDLC = MPSaveManager.MPKits[KitDataIndex].RequiredDLCModuleIDs;
    if (!Class'SFXEngine'.static.HasRequiredDLC(RequiredDLC))
    {
        ParseStringIntoArray(ServerCharacterStrings[nCharacterIndex], ServerCharacterDataParts, ";", FALSE);
        if (ServerCharacterDataParts[2] == KitName)
        {
            return "";
        }
    }
    CharacterName = Repl(CharacterRecord.CharacterName, ";", "", TRUE);
    // MILAN CHANGE - colors are written as #RRGGBB, or empty for no override. 
    // Patterns aren't colors so they can just stay an ID
    Tint1ID = Class'MilanColor'.static.ToHexString(CharacterRecord.Tint1ID);
    Tint2ID = Class'MilanColor'.static.ToHexString(CharacterRecord.Tint2ID);
    PatternID = string(CharacterRecord.PatternID);
    PatternColorID = Class'MilanColor'.static.ToHexString(CharacterRecord.PatternColorID);
    PhongID = Class'MilanColor'.static.ToHexString(CharacterRecord.PhongID);
    EmissiveID = Class'MilanColor'.static.ToHexString(CharacterRecord.EmissiveID);
    SkinToneID = Class'MilanColor'.static.ToHexString(CharacterRecord.SkinToneID);
    // END MILAN CHANGE
    SecondsPlayed = string(int(CharacterRecord.SecondsPlayed));
    TimeStamp = CharacterRecord.TimeStamp.Year $ ";" $ CharacterRecord.TimeStamp.Month $ ";" $ CharacterRecord.TimeStamp.Day $ ";" $ CharacterRecord.TimeStamp.SecondsSinceMidnight;
    Powers = GetPowers(CharacterRecord.Powers);
    HotKeys = "";
    Weapons = GetWeapons(CharacterRecord.Weapons);
    WeaponMods = GetWeaponMods(CharacterRecord.WeaponMods);
    Deployed = string(CharacterRecord.Deployed);
    LeveledUp = string(CharacterRecord.LeveledUp);
    return CachedOnlinePlayerStorage.VersionNumber $ ";" $ DevelopmentVersionNumber $ ";" $ KitName $ ";" $ CharacterName $ ";" $ Tint1ID $ ";" $ Tint2ID $ ";" $ PatternID $ ";" $ PatternColorID $ ";" $ PhongID $ ";" $ EmissiveID $ ";" $ SkinToneID $ ";" $ SecondsPlayed $ ";" $ TimeStamp $ ";" $ Powers $ ";" $ HotKeys $ ";" $ Weapons $ ";" $ WeaponMods $ ";" $ Deployed $ ";" $ LeveledUp $ ";" $ CharacterRecord.HeavyWeaponId;
}
// END MILAN CHANGE
