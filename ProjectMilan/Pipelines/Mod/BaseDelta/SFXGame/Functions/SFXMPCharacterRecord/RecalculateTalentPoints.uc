public function RecalculateTalentPoints()
{
    local int PowerIdx;
    local int TotalTalentPoints;
    local int UsedTalentPoints;
    local PowerRecord PowerRec;
    local Class<SFXPowerCustomActionBase> PowerClass;
    local SFXMPClassRecord ParentClass;
    
    ParentClass = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager.GetClassRecord(className);
    UsedTalentPoints = 0;
    TotalTalentPoints = Class'BioLevelUpSystem'.static.GetTalentPointSum(ParentClass.Level, FALSE);
    for (PowerIdx = 0; PowerIdx < Powers.Length; ++PowerIdx)
    {
        PowerRec = Powers[PowerIdx];
        // MILAN CHANGE 09/16/2026 - Mgamerz
        // Change code path to not rely on the default power loading mechanism
        // This was the source of the 6/6/6/6/6 power glitch for MP4 kits, it stopped shipping
        // Seek free power classes which causes recalc to not work properly
        // Original logic was removed and is not left here as a comment.
        if (PowerRec.bUsesTalentPoints)
        {
            UsedTalentPoints += GetPointsSpentAtRank(int(PowerRec.CurrentRank));
        }
        // END MILAN CHANGE
    }
    TalentPointsAvailable = TotalTalentPoints - UsedTalentPoints;
    TalentPointsInitialized = TRUE;
}