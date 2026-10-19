// MILAN CHANGE - Mgamerz - 2026-10-17
// The movie Update event uses script dispatch; native per-marker Update uses the C++ vtable.
public event function Update(float fDeltaT)
{
    local SFXGUIValue_Marker MarkerIter;
    local SFXGUIValue_MarkerPlayer PlayerMarker;

    Super.Update(fDeltaT);
    foreach Markers(MarkerIter)
    {
        PlayerMarker = SFXGUIValue_MarkerPlayer(MarkerIter);
        if (PlayerMarker != None && PlayerMarker.FullyInitialized)
        {
            PlayerMarker.UpdateAppearance(fDeltaT);
        }
    }
}
// END MILAN CHANGE
