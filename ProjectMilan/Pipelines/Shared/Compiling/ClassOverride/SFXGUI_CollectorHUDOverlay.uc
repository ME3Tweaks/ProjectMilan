Class SFXGUI_CollectorHUDOverlay extends SFXGUIMovie
    config(UI);

// Types
struct CollectorSwarmOverlay 
{
    var string Id;
    var Vector2D Offset;
    var GFxValue Overlay;
    var SFXGUIValue_PowerIcon PowerIcon;
	// MILAN CHANGE DropTheSquid 1/10/2024
	// added this so that we can distinguish between the PC and controller icons to control visibility according to the current input mode
	var bool gamepad;
	// END MILAN
};

// Variables
var array<CollectorSwarmOverlay> m_aSwarmOverlays;
var config Vector2D PCQuickSlotOffset;
var config Vector2D MPHUDIconOffset;
var transient SFXSFHandler_HUD m_oSPHUD;
var transient SFXSFHandler_PCPowerWheel m_oPCPowerWheel;
var transient SFXGUI_MPHUD m_oMPHUD;
var config float PCQuickSlotScale;
var config float MPHUDIconScale;
var config int NumDrones;
var config int NumFlashes;
var config int NumSweeps;
var config int DroneFrequency;
var config int FlashFrequency;
var config int SweepFrequency;
var config int SwarmFrequency;
var config float PositionPowerIconOverlaysPeriod;
var GFxMovieInfo CollectorHUDOverlayResource;
var bool m_bInitialized;
var bool m_bCooldownOverrideOn;
// MILAN CHANGE - Mgamerz - 2026-10-17
// The center cooldown clips live here, but the native HUD owns their updates.
var transient GFxValue MilanOriginalPowerLeft;
var transient GFxValue MilanOriginalPowerRight;
var transient BioPawn MilanPowerHUDPawn;
var transient bool MilanPowerHUDVisible;
// END MILAN CHANGE

// Functions
// MILAN CHANGE DropTheSquid 1/10/2024
// added so that we can react to input changes to update the UI
public event function HandleButtonRefresh(bool usingGamepad)
{
    local SFXGUIInteraction oGUIs;
    
    Super.HandleButtonRefresh(usingGamepad);
	oGUIs = GetSFXUIController();
    m_oPCPowerWheel = SFXSFHandler_PCPowerWheel(oGUIs.GetMovie(GetPC(), oGUIs.MovieTag_PowerWheel));
	// clear everything
    ClearSwarmOverlays();
	// set up the overlays again
    InitializeMPHUDPowerIconOverlays();
    InitializePCQuickslotIconOverlays();
}
// added this so that things can update as soon as the input mode/visibility changes, and also adjust the position as icons move, as with hiding the quickslots bar
public event function Update(float fDeltaT)
{
	super.Update(fDeltaT);
    // MILAN CHANGE - Mgamerz - 2026-10-17
    // Synchronize relocated HUD clips even across downed/camera transitions.
    MilanSynchronizePowerHUD();
    // END MILAN CHANGE
}
// END MILAN
public event function OnStart()
{
    Super.OnStart();
    InternalOnStart();
    // MILAN CHANGE - Mgamerz - 2026-10-17
    // A hidden movie will stop updating. The controller timer also handles reopening it.
    GetPC().SetTimer(0.05, TRUE, 'MilanSynchronizePowerHUD', Self);
    MilanSynchronizePowerHUD();
    // END MILAN CHANGE
}
public function OnClose()
{
    // MILAN CHANGE - Mgamerz - 2026-10-17
    if (GetPC() != None)
    {
        GetPC().ClearTimer('MilanSynchronizePowerHUD', Self);
        GetPC().ClearTimer('InternalOnStart', Self);
        GetPC().ClearTimer('PositionPowerIconOverlays', Self);
    }
    // Restore only references still owned by this movie.
    if (m_oSPHUD != None)
    {
        if (m_oSPHUD.PlayerPowerLeft == GetVariableObject("PlayerPower1"))
        {
            m_oSPHUD.PlayerPowerLeft = MilanOriginalPowerLeft;
        }
        if (m_oSPHUD.PlayerPowerRight == GetVariableObject("PlayerPower2"))
        {
            m_oSPHUD.PlayerPowerRight = MilanOriginalPowerRight;
        }
    }
    MilanOriginalPowerLeft = None;
    MilanOriginalPowerRight = None;
    MilanPowerHUDPawn = None;
    MilanPowerHUDVisible = FALSE;
    m_bInitialized = FALSE;
    m_bCooldownOverrideOn = FALSE;
    // END MILAN CHANGE
    m_oSPHUD = None;
    m_oPCPowerWheel = None;
    m_oMPHUD = None;
    ClearSwarmOverlays();
    Super.OnClose();
}
public final function GFxValue AS_GetCollectorCooldownForPowerIcon(string sIconID)
{
    return ActionScriptObject("GetCollectorCooldownForPowerIcon");
}
public final function AS_ResetCooldownPowerIcons()
{
    ActionScriptVoid("ResetCooldownPowerIcons");
}
private final function CheckInitialize()
{
    local SFXGUIInteraction oGUIs;
    
    oGUIs = GetSFXUIController();
    if (m_bInitialized)
    {
        return;
    }
    m_oSPHUD = SFXSFHandler_HUD(oGUIs.GetMovie(GetPC(), oGUIs.MovieTag_HUD));
    if ((m_oSPHUD == None || m_oSPHUD.PlayerPowerLeft == None) || m_oSPHUD.m_oShepardInfo.pPawn == None)
    {
        return;
    }
	// MILAN CHANGE DropTheSquid 1/10/2024
	// previously, this keyed off of whether this was a console build. It grabbed either the PC power wheel or the MP HUD
	// and if the PC power wheel isn't there, it returns. 
	// this is wrong for dynamic input. The PC power wheel will not be present if you are using a controller. MP HUD will always be present (in multiplayer)
	// we also want this to someday work in SP, maybe, so relying on that being always present is also dumb. 
	// so just grab both and don't fail if they are not there
    m_oPCPowerWheel = SFXSFHandler_PCPowerWheel(oGUIs.GetMovie(GetPC(), oGUIs.MovieTag_PowerWheel));
	m_oMPHUD = SFXGUI_MPHUD(oGUIs.GetMovie(GetPC(), oGUIs.MovieTag_MPHUD));
	// END MILAN
    // MILAN CHANGE - Mgamerz - 2026-10-17
    // Save native HUD ownership for movie close/reopen.
    MilanOriginalPowerLeft = m_oSPHUD.PlayerPowerLeft;
    MilanOriginalPowerRight = m_oSPHUD.PlayerPowerRight;
    // END MILAN CHANGE
    m_oSPHUD.PlayerPowerLeft = GetVariableObject("PlayerPower1");
    m_oSPHUD.PlayerPowerRight = GetVariableObject("PlayerPower2");
    ClearSwarmOverlays();
    InitializePCQuickslotIconOverlays();
    InitializeMPHUDPowerIconOverlays();
    PositionPowerIconOverlays();
    m_bInitialized = TRUE;
}
public final function ClearSwarmOverlays()
{
    local int nOverlay;
    
    for (nOverlay = 0; nOverlay < m_aSwarmOverlays.Length; ++nOverlay)
    {
        m_aSwarmOverlays[nOverlay].PowerIcon = None;
    }
    m_aSwarmOverlays.Length = 0;
    AS_ResetCooldownPowerIcons();
}
public final function bool GetGlobalPosition(GFxValue val, out float X, out float Y)
{
    local GFxValue ParentVal;
    
    ParentVal = val.GetObject("_parent");
    if (val == None || ParentVal == None)
    {
        return FALSE;
    }
    X = 0.0;
    Y = 0.0;
    do {
        X *= val.GetNumber("_xscale") / float(100);
        Y *= val.GetNumber("_yscale") / float(100);
        X += val.GetNumber("_x");
        Y += val.GetNumber("_y");
        val = ParentVal;
        ParentVal = val.GetObject("_parent");
    } until (ParentVal == None);
    return TRUE;
}
public final function InitializeMPHUDPowerIconOverlays()
{
    if (m_oMPHUD == None)
    {
        return;
    }
	// passing in the new parameter of true because these are gamepad power icons
    InitializePowerIconOverlay(m_oMPHUD.CenterIconLeft, MPHUDIconScale, MPHUDIconOffset, true);
    InitializePowerIconOverlay(m_oMPHUD.CenterIconCenter, MPHUDIconScale, MPHUDIconOffset, true);
    InitializePowerIconOverlay(m_oMPHUD.CenterIconRight, MPHUDIconScale, MPHUDIconOffset, true);
}
public final function InitializePCQuickslotIconOverlays()
{
    local int nIconIndex;
    
    if (m_oPCPowerWheel == None)
	{
        return;
    }
    for (nIconIndex = 0; nIconIndex < 8; ++nIconIndex)
    {
		// passing in the new parameter of false for gamepad, because these are PC icons
        InitializePowerIconOverlay(m_oPCPowerWheel.m_aQuickSlotIcons[nIconIndex], PCQuickSlotScale, PCQuickSlotOffset, false);
    }
}
// MILAN CHANGE DropTheSquid 1/10/2024
// I added a new parameter to this so we can tell whether the swarm overlay should be shown according to the input mode.
public final function int InitializePowerIconOverlay(SFXGUIValue_PowerIcon oPowerIcon, float fScale, const out Vector2D vOffset, bool gamepad)
{
    local CollectorSwarmOverlay oNewOverlay;
    local ASDisplayInfo DisplayInfo;
    
    if (oPowerIcon == None)
    {
        return -1;
    }
    oNewOverlay.Id = string(oPowerIcon.Name);
    oNewOverlay.PowerIcon = oPowerIcon;
    oNewOverlay.Overlay = AS_GetCollectorCooldownForPowerIcon(oNewOverlay.Id);
    oNewOverlay.Overlay.SetVisible(FALSE);
    DisplayInfo = oNewOverlay.Overlay.GetDisplayInfo();
    DisplayInfo.XScale = fScale;
    DisplayInfo.YScale = fScale;
    oNewOverlay.Overlay.SetDisplayInfo(DisplayInfo);
    oNewOverlay.Offset = vOffset;
	// and I assign it here
	oNewOverlay.gamepad = gamepad;
    m_aSwarmOverlays.AddItem(oNewOverlay);
    return m_aSwarmOverlays.Length - 1;
}
// END MILAN
private final function InternalOnStart()
{
    CheckInitialize();
    if (!m_bInitialized)
    {
        GetPC().SetTimer(0.00999999978, FALSE, 'InternalOnStart', Self);
    }
}
public final function PositionPowerIconOverlays()
{
    local int nOverlayIndex;
    local float fX;
    local float fY;
    
    for (nOverlayIndex = 0; nOverlayIndex < m_aSwarmOverlays.Length; ++nOverlayIndex)
    {
        if (m_aSwarmOverlays[nOverlayIndex].Overlay != None && m_aSwarmOverlays[nOverlayIndex].PowerIcon != None)
        {
            if (GetGlobalPosition(m_aSwarmOverlays[nOverlayIndex].PowerIcon, fX, fY))
            {
                fX += m_aSwarmOverlays[nOverlayIndex].Offset.X;
                fY += m_aSwarmOverlays[nOverlayIndex].Offset.Y;
                m_aSwarmOverlays[nOverlayIndex].Overlay.SetPosition(fX, fY);
            }
        }
    }
}
// MILAN CHANGE - Mgamerz - 2026-10-17
// Keep the separate movie in step with the native HUD which normally drives its clips.
public final function MilanSynchronizePowerHUD()
{
    local BioPlayerController PC;
    local BioPawn PlayerPawn;
    local bool bShowPowerHUD;

    PC = GetPC();
    if (PC == None)
    {
        return;
    }
    if (!m_bInitialized)
    {
        CheckInitialize();
    }
    PlayerPawn = BioPawn(PC.Pawn);
    bShowPowerHUD = m_bInitialized && PlayerPawn != None;
    if (bShowPowerHUD)
    {
        // Always use our own pawn: spectator view targets must not supply cooldowns.
        bShowPowerHUD = !PlayerPawn.bIsDowned && !PlayerPawn.bIsDead
            && PC.myHUD != None && PC.myHUD.bShowHUD
            && m_oSPHUD.GetVisible()
            && PC.GameModeManager2.ShouldShowHUD()
            && !PC.GameModeManager2.IsActive(20)
            && !PC.GameModeManager2.IsActive(21)
            && !PC.GameModeManager2.IsActive(14)
            && CameraActor(PC.ViewTarget) == None;
    }
    if (PlayerPawn != None && PlayerPawn.PowerManager != None)
    {
        m_bCooldownOverrideOn = PlayerPawn.PowerManager.IsInForcedCooldown();
    }
    else
    {
        m_bCooldownOverrideOn = FALSE;
    }
    if (bShowPowerHUD && (!MilanPowerHUDVisible || PlayerPawn != MilanPowerHUDPawn))
    {
        // Refresh before exposing the movie, including when cooldown expired while hidden.
        m_oSPHUD.MilanRefreshPlayerPowerCooldown(PlayerPawn);
    }
    MilanPowerHUDPawn = PlayerPawn;
    MilanPowerHUDVisible = bShowPowerHUD;
    UpdateCooldownOverride();
    if (GetVisible() != bShowPowerHUD)
    {
        SetVisible(bShowPowerHUD);
    }
}
// END MILAN CHANGE
public final function ResetForcedCooldown()
{
    if (m_bCooldownOverrideOn)
    {
        m_bCooldownOverrideOn = FALSE;
        UpdateCooldownOverride();
        if (!Class'WorldInfo'.static.IsConsoleBuild(0))
        {
            GetPC().ClearTimer('PositionPowerIconOverlays', Self);
        }
    }
}
public final function SetForcedCooldown()
{
    if (!m_bCooldownOverrideOn)
    {
        m_bCooldownOverrideOn = TRUE;
        UpdateCooldownOverride();
        if (!Class'WorldInfo'.static.IsConsoleBuild(0))
        {
            GetPC().SetTimer(PositionPowerIconOverlaysPeriod, FALSE, 'PositionPowerIconOverlays', Self);
        }
    }
}
public final function UpdateCooldownOverride()
{
    local int nOverlayIndex;
    local SFXGuiValue_PowerIcon icon;
    
    if (m_oSPHUD == None)
    {
        return;
    }
    SetVariableBool("g_bCooldownOverloadActivated", m_bCooldownOverrideOn);
    for (nOverlayIndex = 0; nOverlayIndex < m_aSwarmOverlays.Length; ++nOverlayIndex)
    {
        icon = m_aSwarmOverlays[nOverlayIndex].PowerIcon;
        // MILAN CHANGE - Mgamerz - 2026-10-17
        // Extra icons share the relocated center clips' visibility lifecycle
        if (MilanPowerHUDVisible && m_bCooldownOverrideOn && icon != None && icon.pPower != None && icon.pPower.UsesSharedCooldown && icon.pPower.IsEnabled() && icon.pPower.Rank > 0)
        {
            m_aSwarmOverlays[nOverlayIndex].Overlay.SetVisible(m_aSwarmOverlays[nOverlayIndex].gamepad == bUsingGamepad);
            continue;
        }
        // END MILAN CHANGE
        m_aSwarmOverlays[nOverlayIndex].Overlay.SetVisible(false);
    }
    if (m_bCooldownOverrideOn)
    {
        PositionPowerIconOverlays();
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    PCQuickSlotOffset = {X = 18.0, Y = 24.0}
    MPHUDIconOffset = {X = 8.0, Y = -10.0}
    PCQuickSlotScale = 65.0
    MPHUDIconScale = 100.0
    NumDrones = 3
    NumFlashes = 3
    DroneFrequency = 15
    FlashFrequency = 15
    SweepFrequency = 15
    SwarmFrequency = 5
    PositionPowerIconOverlaysPeriod = 0.100000001
    CollectorHUDOverlayResource = GFxMovieInfo'GUI_SF_DLC_MP4_CollectorHUD.DLC_MP4_CollectorHUD'
}