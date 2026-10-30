// MILAN CHANGE - Mgamerz - 2026-10-16
// LocalPlayer can outlive its controller, so remove photo effects before tearing its UI down
public function Destroyed()
{
    if (GameModeManager2 != None && GameModeManager2.GetPhotoMode() != None && GameModeManager2.GetPhotoMode().bMPSpectatorPhoto)
    {
        Class'SFXGUIInteraction'.static.GetInstance().HidePhotoMode(Self);
    }
    // MILAN CHANGE - Mgamerz - 2026-10-28
    if (GameModeManager2 != None && GameModeManager2.GetPhotoMode() != None)
        GameModeManager2.GetPhotoMode().UpdateMPObserverScreenEffects(TRUE);
    // END MILAN CHANGE
    Class'SFXGUIInteraction'.static.GetInstance().RemoveMoviesForPlayer(Self);
    Super.Destroyed();
}
// END MILAN CHANGE
