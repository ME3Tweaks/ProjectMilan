// MILAN CHANGE - Mgamerz - 2026-10-28
// Restore player screen effects when exiting spectator mode
public function Deactivated()
{
    ClearTimer('ValidateTarget');
    Super.Deactivated();
    if (Outer.GameModeManager2.GetPhotoMode() != None) {
        Outer.GameModeManager2.GetPhotoMode().UpdateMPObserverScreenEffects();
    }
}
// END MILAN CHANGE
