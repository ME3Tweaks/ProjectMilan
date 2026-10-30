// MILAN CHANGE - Mgamerz - 2026-10-28
// Suppress the local player's screen effects as soon as spectating begins
public function Activated()
{
    SetTimer(0.5, TRUE, 'ValidateTarget');
    Super.Activated();
    if (Outer.GameModeManager2.GetPhotoMode() != None) {
        Outer.GameModeManager2.GetPhotoMode().UpdateMPObserverScreenEffects();
    }
}
// END MILAN CHANGE
