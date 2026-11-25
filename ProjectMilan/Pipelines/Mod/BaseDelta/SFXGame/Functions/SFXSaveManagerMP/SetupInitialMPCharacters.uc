// MILAN CHANGE - 11/25/2026 - Mgamerz
// Use subclass SFXMilanCharacterRecord due to original class being native
public function SetupInitialMPCharacters()
{
    local int ClassIdx;
    local int KitIdx;
    local SFXMPClassRecord ClassRecord;
    local SFXMPCharacterRecord CharacterRecord;

    Classes.Length = 0;
    Characters.Length = 0;
    for (ClassIdx = 0; ClassIdx < MPClasses.Length; ++ClassIdx)
    {
        ClassRecord = new Class'SFXMPClassRecord';
        ClassRecord.className = MPClasses[ClassIdx].className;
        for (KitIdx = 0; KitIdx < MPKits.Length; ++KitIdx)
        {
            if (MPKits[KitIdx].BaseMPClassName == MPClasses[ClassIdx].className)
            {
                // MILAN CHANGE - 11/25/2026 - Mgamerz
                CharacterRecord = new Class'SFXMilanCharacterRecord';
                // END MILAN CHANGE
                CharacterRecord.className = MPClasses[ClassIdx].className;
                CharacterRecord.KitName = MPKits[KitIdx].KitName;
                CharacterRecord.Deployed = FALSE;
                CharacterRecord.CharacterName = GetUniqueCharacterName(CharacterRecord.KitName);
                ClassRecord.Characters.AddItem(CharacterRecord);
                Characters.AddItem(CharacterRecord);
            }
        }
        Classes.AddItem(ClassRecord);
    }
}
