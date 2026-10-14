public function UpdateMapsCompletedHelper(Name MapName, Name PlayedMaps, Name PlayedMapsCount, array<Name> MapNames)
{
    local SFXAccomplishmentManager AccomplishmentManager;
    local int BitMask;
    local int MapsPlayed;
    local int NumMapsPlayed;
    local int MapIndex;
    
    AccomplishmentManager = SFXEngine(Class'Engine'.static.GetEngine()).AccomplishmentManager;
    if (AccomplishmentManager == None)
    {
        return;
    }
    MapIndex = MapNames.Find(MapName);
    BitMask = 0;
    if (MapIndex >= 0)
    {
        BitMask = 1 << MapIndex;
    }
    if (BitMask > 0)
    {
        MapsPlayed = AccomplishmentManager.GetGrinderAccomplishmentProgress(PlayedMaps, Self);
        // MILAN CHANGE - Mgamerz - 2026-10-13
        // -1 means the progress name isn't configured. >> is arithmetic, so the
        // bit-count loop below never terminates on -1 and the game hangs at match end.
        if (MapsPlayed < 0)
        {
            return;
        }
        // END MILAN CHANGE
        if (MapsPlayed > -1 && (MapsPlayed & BitMask) == 0)
        {
            MapsPlayed = MapsPlayed | BitMask;
            AccomplishmentManager.SetGrinderAccomplishmentProgress(PlayedMaps, MapsPlayed, Self);
        }
        NumMapsPlayed = 0;
        while (MapsPlayed != 0)
        {
            NumMapsPlayed += MapsPlayed & 1;
            MapsPlayed = MapsPlayed >> 1;
        }
        if (AccomplishmentManager.SetGrinderAccomplishmentProgressWithUpdate(PlayedMapsCount, NumMapsPlayed, Self))
        {
            AccomplishmentManager.Save();
        }
    }
}