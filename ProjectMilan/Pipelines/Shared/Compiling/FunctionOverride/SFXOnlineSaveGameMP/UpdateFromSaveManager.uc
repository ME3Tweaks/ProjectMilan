// MILAN CHANGE - Mgamerz - 2026-09-24
// Use the script character serializer so the local profile can save all 200 kits.
// Keep the existing base, class, reinforcement, and face-code update paths.
public function UpdateFromSaveManager(const out SFXSaveManagerMP MPSaveManager, optional bool ForceResaveBase)
{
    local string OldStr;
    local string Str;
    local array<string> OldStrs;
    local array<string> Strs;
    local int idx;

    if (bDebugSaving)
    {
        UpdateBaseValues2(MPSaveManager, ForceResaveBase);
        CachedOnlinePlayerStorage.GetProfileSettingValue(0, OldStr);
        UpdateBaseValues(MPSaveManager, ForceResaveBase);
        CachedOnlinePlayerStorage.GetProfileSettingValue(0, Str);
        if (OldStr != Str)
        {
            LogInternal("Error, values don't match!", );
            LogInternal("Old:" @ OldStr, );
            LogInternal("New:" @ Str, );
        }
        UpdateNewReinforcementsValues(MPSaveManager);
        UpdateClassValues2(MPSaveManager);
        OldStrs.Length = MPSaveManager.Classes.Length;
        for (idx = 0; idx < MPSaveManager.Classes.Length; idx++)
        {
            CachedOnlinePlayerStorage.GetProfileSettingValue(1 + idx, OldStrs[idx]);
        }
        UpdateClassValues(MPSaveManager);
        Strs.Length = MPSaveManager.Classes.Length;
        for (idx = 0; idx < MPSaveManager.Classes.Length; idx++)
        {
            CachedOnlinePlayerStorage.GetProfileSettingValue(1 + idx, Strs[idx]);
        }
        for (idx = 0; idx < MPSaveManager.Classes.Length; idx++)
        {
            if (OldStrs[idx] != Strs[idx])
            {
                LogInternal("Error, class values don't match!", );
                LogInternal("Old:" @ OldStrs[idx], );
                LogInternal("New:" @ Strs[idx], );
            }
        }
        UpdateCharacterValues2(MPSaveManager);
        UpdateFaceCodeValues(MPSaveManager);
    }
    else if (bUseOldSavingSystem)
    {
        UpdateBaseValues2(MPSaveManager, ForceResaveBase);
        UpdateNewReinforcementsValues(MPSaveManager);
        UpdateClassValues2(MPSaveManager);
        UpdateCharacterValues2(MPSaveManager);
        UpdateFaceCodeValues(MPSaveManager);
    }
    else
    {
        UpdateBaseValues(MPSaveManager, ForceResaveBase);
        UpdateNewReinforcementsValues(MPSaveManager);
        UpdateClassValues(MPSaveManager);
        UpdateCharacterValues2(MPSaveManager);
        UpdateFaceCodeValues(MPSaveManager);
    }
}
// END MILAN CHANGE
