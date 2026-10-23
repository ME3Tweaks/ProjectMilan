// MILAN CHANGE 09/26/2026 - Mgamerz
// This is a brand new class
// GUI markers for players that tint by their health and living status
class SFXGUIValue_MarkerPlayerHealth extends SFXGUIValue_MarkerPlayer
    within SFXGUI_Markers
    transient;

var float CriticalHealthPct;
var float HealthTintAtCritical;
var float PulseAngularSpeed;
var float PulseMinimumRed;

// MILAN CHANGE - Mgamerz - 2026-10-16
// Hide only the player marker's visuals during local photo mode, preserving native updates.
var bool bPhotoMarkerHidden;
var bool bPhotoMarkerWasVisible;
// The class default is a local process preference shared by newly created player markers.
var bool bHideInPhotoMode;
// END MILAN CHANGE

// MILAN CHANGE - Mgamerz - 2026-10-17
// The movie's script Update event dispatches this hook; native marker Update bypasses script overrides.
public function UpdateAppearance(float DeltaSeconds)
{
    local BioPawn MarkerPawn;
    local SFXModule_MarkerPlayer MarkerModule;
    local float HealthPct;
    local float HealthBlend;
    local float Pulse;
    local float GreenBlue;
    local float TimeNow;

    Super.UpdateAppearance(DeltaSeconds);

    MarkerPawn = Player;
    if (MarkerPawn == None || MarkerMiscTextClipAnim == None)
    {
        return;
    }

    MarkerModule = SFXModule_MarkerPlayer(
        MarkerPawn.GetModule(Class'SFXModule_MarkerPlayer'));

    if (MarkerModule == None)
    {
        SetMarkerTint(1.0, 1.0, 1.0, 1.0);
        return;
    }

    if (MarkerModule.PlayerIsDead)
    {
        SetMarkerTint(0.0, 0.0, 0.0, 1.0);
        return;
    }

    HealthPct = MarkerPawn.GetHealthPct();
    if (HealthPct < 0.0)
    {
        HealthPct = 0.0;
    }
    else if (HealthPct > 1.0)
    {
        HealthPct = 1.0;
    }

    // Downed state pulses regardless of the health percentage.
    if (MarkerModule.PlayerIsDown || HealthPct <= CriticalHealthPct)
    {
        TimeNow = MarkerPawn.WorldInfo.TimeSeconds;
        Pulse = PulseMinimumRed
            + (1.0 - PulseMinimumRed)
            * (1.0 + Sin(TimeNow * PulseAngularSpeed))
            * 0.5;

        SetMarkerTint(Pulse, 0.0, 0.0, 1.0);
        return;
    }

    // A positive shield value means the marker stays white.
    if (MarkerPawn.GetCurrentShields() > 0.0)
    {
        SetMarkerTint(1.0, 1.0, 1.0, 1.0);
        return;
    }

    // With shields down, move from white at full health to muted red at 5%.
    HealthBlend = (1.0 - HealthPct) / (1.0 - CriticalHealthPct);
    if (HealthBlend < 0.0)
    {
        HealthBlend = 0.0;
    }
    else if (HealthBlend > 1.0)
    {
        HealthBlend = 1.0;
    }

    GreenBlue = 1.0 - ((1.0 - HealthTintAtCritical) * HealthBlend);
    SetMarkerTint(1.0, GreenBlue, GreenBlue, 1.0);
}

// END MILAN CHANGE

// MILAN CHANGE - Mgamerz - 2026-10-17
// Called explicitly by the photo handler: the native marker loop bypasses script Update.
public final function SetPhotoMarkerHidden(bool bHide)
{
    local ASDisplayInfo DisplayInfo;

    if (MarkerClip == None)
    {
        return;
    }
    if (bHide)
    {
        if (!bPhotoMarkerHidden)
        {
            DisplayInfo = MarkerClip.GetDisplayInfo();
            bPhotoMarkerWasVisible = DisplayInfo.visible;
            bPhotoMarkerHidden = TRUE;
        }
        // The root's native visibility/position cache remains owned by the native update.
        MarkerClip.SetVisible(FALSE);
    }
    else if (bPhotoMarkerHidden)
    {
        MarkerClip.SetVisible(bPhotoMarkerWasVisible);
        bPhotoMarkerHidden = FALSE;
    }
}
// END MILAN CHANGE

private final function SetMarkerTint(
    float Red,
    float Green,
    float Blue,
    float Alpha)
{
    local ASColorTransform Tint;

    if (MarkerMiscTextClipAnim == None)
    {
        return;
    }

    Tint.Multiply.R = Red;
    Tint.Multiply.G = Green;
    Tint.Multiply.B = Blue;
    Tint.Multiply.A = Alpha;

    Tint.Add.R = 0.0;
    Tint.Add.G = 0.0;
    Tint.Add.B = 0.0;
    Tint.Add.A = 0.0;

    // MILAN CHANGE - Mgamerz - 2026-10-20
    // SetText uses miscTextAnim for the player name
    MarkerMiscTextClipAnim.SetColorTransform(Tint);
    // END MILAN CHANGE
}

defaultproperties
{
    CriticalHealthPct=0.05
    HealthTintAtCritical=0.35
    PulseAngularSpeed=5.0
    PulseMinimumRed=0.65
}
