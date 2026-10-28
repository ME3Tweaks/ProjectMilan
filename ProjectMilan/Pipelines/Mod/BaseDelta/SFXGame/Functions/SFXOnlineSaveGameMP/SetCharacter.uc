// MILAN CHANGE - Mgamerz - 2026-10-27
// Serialize heavy weapon ID from end of character string
private final function EMPSerializationResult SetCharacter(int CharacterIndex, const out SFXSaveManagerMP MPSaveManager)
{
    local string KitName;
    local SFXMPCharacterRecord CharacterRecord;
    local int CharacterCursor;
    local int Version;
    local int DevelopmentVersion;
    local array<string> CharacterParts;
    
    if (ServerCharacterStrings[CharacterIndex] == "")
    {
        return EMPSerializationResult.EMPSerializationResult_Success;
    }
    ParseStringIntoArray(ServerCharacterStrings[CharacterIndex], CharacterParts, ";", FALSE);
    CharacterCursor = 0;
    Version = int(CharacterParts[CharacterCursor++]);
    if (Version < 13)
    {
        return EMPSerializationResult.EMPSerializationResult_TooOld;
    }
    else if (Version > CachedOnlinePlayerStorage.VersionNumber)
    {
        LogInternal("Server version too new for this version of the game.", );
        return EMPSerializationResult.EMPSerializationResult_TooNew;
    }
    DevelopmentVersion = int(CharacterParts[CharacterCursor++]);
    if (DevelopmentVersion < DevelopmentVersionNumber)
    {
        return EMPSerializationResult.EMPSerializationResult_ForcedWipe;
    }
    KitName = CharacterParts[CharacterCursor++];
    CharacterRecord = MPSaveManager.GetCharacterRecord(Name(KitName));
    if (CharacterRecord == None)
    {
        LogInternal("Cannot find pre-existing character record '" $ KitName $ "'", );
        return EMPSerializationResult.EMPSerializationResult_Failure;
    }
    else if (CharacterRecord.bSerializedFromBlaze)
    {
        LogInternal("Character record '" $ KitName $ "' already serialized...skipping duplicates", );
        return EMPSerializationResult.EMPSerializationResult_Failure;
    }
    CharacterRecord.CharacterName = CharacterParts[CharacterCursor++];
    CharacterRecord.Tint1ID = int(CharacterParts[CharacterCursor++]);
    CharacterRecord.Tint2ID = int(CharacterParts[CharacterCursor++]);
    CharacterRecord.PatternID = int(CharacterParts[CharacterCursor++]);
    CharacterRecord.PatternColorID = int(CharacterParts[CharacterCursor++]);
    if (Version >= 15)
    {
        CharacterRecord.PhongID = int(CharacterParts[CharacterCursor++]);
        CharacterRecord.EmissiveID = int(CharacterParts[CharacterCursor++]);
    }
    CharacterRecord.SkinToneID = int(CharacterParts[CharacterCursor++]);
    CharacterRecord.SecondsPlayed = float(int(CharacterParts[CharacterCursor++]));
    CharacterRecord.TimeStamp.Year = int(CharacterParts[CharacterCursor++]);
    CharacterRecord.TimeStamp.Month = int(CharacterParts[CharacterCursor++]);
    CharacterRecord.TimeStamp.Day = int(CharacterParts[CharacterCursor++]);
    CharacterRecord.TimeStamp.SecondsSinceMidnight = int(CharacterParts[CharacterCursor++]);
    SetPowers(CharacterParts[CharacterCursor++], CharacterRecord.Powers, Version);
    CharacterCursor++;
    SetWeapons(CharacterParts[CharacterCursor++], CharacterRecord.Weapons);
    SetWeaponMods(CharacterParts[CharacterCursor++], CharacterRecord.WeaponMods);
    CharacterRecord.Deployed = bool(CharacterParts[CharacterCursor++]);
    if (Version >= 20)
    {
        CharacterRecord.LeveledUp = bool(CharacterParts[CharacterCursor++]);
    }
    // MILAN CHANGE - Ready heavy weapon ID
    // Default to Cobra, then read the heavy weapon ID if parser has more to read
    CharacterRecord.HeavyWeaponId = 0;
    if (CharacterCursor < CharacterParts.Length)
    {
        CharacterRecord.HeavyWeaponId = Max(0, int(CharacterParts[CharacterCursor]));
    }
    // END MILAN CHANGE
    CharacterRecord.bSerializedFromBlaze = TRUE;
    return EMPSerializationResult.EMPSerializationResult_Success;
}
