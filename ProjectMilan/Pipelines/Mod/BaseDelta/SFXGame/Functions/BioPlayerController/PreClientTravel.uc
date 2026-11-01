// MILAN CHANGE - Mgamerz - 2026-10-16
// Remove local photo effects/input state before travel
public event function PreClientTravel(string PendingURL, ETravelType TravelType, bool bIsSeamlessTravel)
{
    if (GameModeManager2 != None && GameModeManager2.GetPhotoMode() != None && GameModeManager2.GetPhotoMode().bMPSpectatorPhoto)
    {
        Class'SFXGUIInteraction'.static.GetInstance().HidePhotoMode(Self);
    }
    // MILAN CHANGE - Mgamerz - 2026-10-28
    if (GameModeManager2 != None && GameModeManager2.GetPhotoMode() != None)
        GameModeManager2.GetPhotoMode().UpdateMPObserverScreenEffects(TRUE);
    // END MILAN CHANGE
    if (!Class'WorldInfo'.static.IsMenuLevel())
    {
        SaveProfile();
    }
    Super.PreClientTravel(PendingURL, TravelType, bIsSeamlessTravel);
}
// END MILAN CHANGE
