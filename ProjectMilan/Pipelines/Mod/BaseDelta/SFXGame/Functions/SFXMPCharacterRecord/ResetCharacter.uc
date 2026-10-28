// MILAN CHANGE - Mgamerz - 2026-10-27
// Reset without customization removes heavy weapon ID
public function ResetCharacter(bool RetainCustomization)
{
    local SFXSaveManagerMP MPSaveManager;
    
    if (!RetainCustomization)
    {
        MPSaveManager = Class'SFXEngine'.static.GetSFXEngine().MPSaveManager;
        CharacterName = MPSaveManager.GetUniqueCharacterName(KitName);
        Tint1ID = default.Tint1ID;
        Tint2ID = default.Tint2ID;
        PatternID = default.PatternID;
        PatternColorID = default.PatternColorID;
        PhongID = default.PhongID;
        EmissiveID = default.EmissiveID;
        SkinToneID = default.SkinToneID;
        // MILAN CHANGE
        // Reset Heavy Weapon ID
        HeavyWeaponId = 0;
        // END MILAN CHANGE
        Weapons.Length = 0;
        WeaponMods.Length = 0;
        Deployed = FALSE;
    }
    LeveledUp = TRUE;
    ResetPowers();
    bSerializedFromBlaze = FALSE;
}