// MILAN CHANGE - 12/26/2023
// By Mgamerz
// Purpose: Turian sniper reticle - use higher res asset from LE
Class SFXGUI_TurianSniperZoomReticle extends SFXGUI_CerberusSniperZoomReticle within SFXSFHandler_Reticle
    config(UI);

// Variables
var float fCurrentZoom;

// Functions
public event function ResetReticle(optional bool bUnsubscribe = FALSE)
{
    Super(SFXGUI_WeaponReticleBase).ResetReticle(bUnsubscribe);
    SetZoomValue(2.0);
}
public event function SetZoomValue(float fZoom)
{
    if (Abs(fCurrentZoom - fZoom) > 0.00999999978)
    {
        if (fZoom > 0.0)
        {
            m_oAmmoText.SetText(Class'BioDefine'.static.PrettyFloat(fZoom, 1) $ "X");
        }
        else
        {
            m_oAmmoText.SetText("");
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    fCurrentZoom = -999.0
    m_oMovieResource = GFxMovieInfo'GUI_SF_WpnReticleTurian_GUN01.WpnReticleTurianSniper' // MILAN CHANGE - Use GUN01 LE asset
    m_bMonitorDistance = TRUE
}