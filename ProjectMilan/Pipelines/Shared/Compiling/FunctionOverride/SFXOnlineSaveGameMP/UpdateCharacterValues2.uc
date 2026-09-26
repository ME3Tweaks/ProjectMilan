// MILAN CHANGE - Mgamerz - 2026-09-24
// Serialize up to 200 kits into the local profile strings. The original online
// player storage still owns only setting IDs 9-86; MilanHost stores later kits
// in its separate extension range.
private final function UpdateCharacterValues2(const out SFXSaveManagerMP MPSaveManager)
{
    local string NewString;
    local string PendingString;
    local string PriorString;
    local int idx;
    local int OldIndex;
    local int NextSpareIndex;
    local array<SFXMPCharacterRecord> CharacterRecords;
    local array<string> OriginalStrings;
    local array<string> OriginalKitNames;
    local array<string> StringParts;
    local array<bool> OriginalUsed;

    CharacterRecords = MPSaveManager.GetAllCharacterRecords();
    OriginalStrings = ServerCharacterStrings;
    OriginalKitNames.Length = OriginalStrings.Length;
    OriginalUsed.Length = OriginalStrings.Length;
    for (OldIndex = 0; OldIndex < OriginalStrings.Length; ++OldIndex)
    {
        if (OriginalStrings[OldIndex] != "")
        {
            StringParts.Length = 0;
            ParseStringIntoArray(OriginalStrings[OldIndex], StringParts, ";", FALSE);
            if (StringParts.Length > 2)
            {
                OriginalKitNames[OldIndex] = StringParts[2];
            }
        }
    }
    if (ServerCharacterStrings.Length < 200)
    {
        ServerCharacterStrings.Length = 200;
    }

    for (idx = 0; idx < CharacterRecords.Length; ++idx)
    {
        if (idx >= 200)
        {
            LogInternal(GetFuncName() $ ": More than 200 MP kits; remaining kits cannot be saved", );
            break;
        }

        // Old profile slots follow kit order. Find the same kit before a new kit
        // shifts its index, including kits whose DLC is not currently installed.
        PriorString = "";
        for (OldIndex = 0; OldIndex < OriginalStrings.Length; ++OldIndex)
        {
            if (!OriginalUsed[OldIndex] &&
                OriginalKitNames[OldIndex] == string(CharacterRecords[idx].KitName))
            {
                PriorString = OriginalStrings[OldIndex];
                OriginalUsed[OldIndex] = TRUE;
                break;
            }
        }
        ServerCharacterStrings[idx] = PriorString;
        NewString = GetCharacter2(CharacterRecords[idx], MPSaveManager, idx);
        if (idx < 78 && Len(NewString) > CachedOnlinePlayerStorage.iMaxBytesPerStorage)
        {
            LogInternal("ERROR - " $ GetFuncName() $ ": Character Server string too long!!! Cannot store in Blaze.", );
            LogInternal("String Data: Length - " $ Len(NewString) $ " Data - '" $ NewString $ "'", );
            DisplayErrorBox("Character " $ idx);
            NewString = "";
        }

        if (NewString != "")
        {
            ServerCharacterStrings[idx] = NewString;
        }

        if (idx < 78)
        {
            PendingString = ServerCharacterStrings[idx];
            if (idx < OriginalStrings.Length && PendingString == OriginalStrings[idx])
            {
                PendingString = "";
            }
            CachedOnlinePlayerStorage.SetProfileSettingValue(9 + idx, PendingString);
        }
    }

    // Keep strings for kits absent from the current build in spare local slots.
    NextSpareIndex = Min(CharacterRecords.Length, 200);
    for (OldIndex = 0; OldIndex < OriginalStrings.Length; ++OldIndex)
    {
        if (!OriginalUsed[OldIndex] && OriginalStrings[OldIndex] != "")
        {
            if (NextSpareIndex >= 200)
            {
                LogInternal(GetFuncName() $ ": No spare local profile slot for an unavailable kit", );
                break;
            }
            ServerCharacterStrings[NextSpareIndex++] = OriginalStrings[OldIndex];
        }
    }
    for (idx = NextSpareIndex; idx < 200; ++idx)
    {
        ServerCharacterStrings[idx] = "";
    }
}
// END MILAN CHANGE
