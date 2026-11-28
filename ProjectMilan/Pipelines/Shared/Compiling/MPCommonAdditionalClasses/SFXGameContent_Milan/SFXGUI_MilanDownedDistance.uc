// NEW to Milan - Mgamerz - 11/16/2026
// Shows the distance to the nearest living teammate while downed
Class SFXGUI_MilanDownedDistance extends SFXGUIMovie
    config(UI);

// Values for m_nShownValue that are not a distance
const SHOWN_NOTHING = -2;
const SHOWN_NOT_AVAILABLE = -1;

var config stringref srTitle;
var config stringref srUnit;
var config stringref srNotAvailable;
var config string sCounterPosition;
var config int nDistanceColor;
var config int nNotAvailableColor;
// Slide variables
var config float fObjectiveShiftX;
var config float fSlideTime;
var config float fSlideBackDelay;

var transient int m_nShownValue;
var transient bool m_bSlideInitialized;
var transient bool m_bShifted;
var transient float m_fSlideBackTimeLeft;
// DO NOT REMOVE: Forced references to prevent GC
var GFxMovieInfo CounterMovie;
var GFxMovieInfo SharedDesignMovie;

// Opens the counter for the player, or returns the one already open
public static function SFXGUI_MilanDownedDistance ShowForPlayer(PlayerController PC)
{
    local SFXGUIInteraction GUI;
    local SFXGUI_MilanDownedDistance Movie;

    GUI = Class'SFXGUIInteraction'.static.GetInstance();
    if (GUI == None || PC == None)
    {
        return None;
    }
    Movie = SFXGUI_MilanDownedDistance(GUI.CastGetMovie(Class'SFXGUI_MilanDownedDistance', PC, 'MilanDownedDistance'));
    if (Movie == None)
    {
        Movie = SFXGUI_MilanDownedDistance(GUI.CastOpenMovie(Class'SFXGUI_MilanDownedDistance', PC, 'MilanDownedDistance', TRUE));
    }
    return Movie;
}
// Closes the counter for the player if it is open
public static function HideForPlayer(PlayerController PC)
{
    local SFXGUIInteraction GUI;

    GUI = Class'SFXGUIInteraction'.static.GetInstance();
    if (GUI == None || PC == None)
    {
        return;
    }
    if (GUI.GetMovie(PC, 'MilanDownedDistance') != None)
    {
        GUI.RemoveMovie(PC, 'MilanDownedDistance');
    }
}
public event function OnStart()
{
    Super.OnStart();
    // Start UI hidden until something tells it to show
    m_nShownValue = SHOWN_NOTHING;
}
// Copy of countdown Update() for visibility
public event function Update(float fDeltaT)
{
    local BioPlayerController PC;
    local bool bShouldShow;

    PC = BioPlayerController(GetPC());
    if (PC == None || PC.GameModeManager2 == None)
    {
        return;
    }
    bShouldShow = !PC.GameModeManager2.IsActive(9) && (PC.GameModeManager2.ShouldShowHUD() || PC.GameModeManager2.IsActive(20) == TRUE || PC.GameModeManager2.IsActive(21) == TRUE);
    if (bShouldShow != GetVisible())
    {
        SetVisible(bShouldShow);
    }
    UpdateObjectiveClearance(PC, fDeltaT);
}
// Slides left of the MP HUD objective panel while it is open
private final function UpdateObjectiveClearance(PlayerController PC, float fDeltaT)
{
    local SFXGUIInteraction GUI;
    local SFXGUI_MPHUD HUD;
    local bool bShift;

    GUI = Class'SFXGUIInteraction'.static.GetInstance();
    if (GUI != None)
    {
        HUD = SFXGUI_MPHUD(GUI.GetMovie(PC, 'MPHUD'));
    }
    bShift = HUD != None && (HUD.ObjectiveBarVisible || HUD.ObjectiveCirclesVisible);
    if (bShift)
    {
        m_fSlideBackTimeLeft = fSlideBackDelay;
    }
    else if (m_bShifted)
    {
        m_fSlideBackTimeLeft -= fDeltaT;
        bShift = m_fSlideBackTimeLeft > 0.0;
    }
    if (!m_bSlideInitialized)
    {
        // First placement is instant
        m_bSlideInitialized = TRUE;
        m_bShifted = bShift;
        ASSlideTo(bShift ? -fObjectiveShiftX : 0.0, 0.0);
    }
    else if (bShift != m_bShifted)
    {
        m_bShifted = bShift;
        ASSlideTo(bShift ? -fObjectiveShiftX : 0.0, fSlideTime);
    }
}
public final function ShowDistance(int nMeters)
{
    if (nMeters < 0)
    {
        nMeters = 0;
    }
    if (nMeters == m_nShownValue)
    {
        return;
    }
    if (m_nShownValue < 0)
    {
        // Ensure we set the label, layout, and color
        ApplyLayout();
        ASSetCounterUnit(GetUIString(srUnit));
        ASSetCounterColor(nDistanceColor);
    }
    m_nShownValue = nMeters;
    ASSetCounterValue(string(nMeters));
}

// Every other player is downed or dead
public final function ShowNotAvailable()
{
    if (m_nShownValue == SHOWN_NOT_AVAILABLE)
    {
        return;
    }
    if (m_nShownValue == SHOWN_NOTHING)
    {
        ApplyLayout();
    }
    m_nShownValue = SHOWN_NOT_AVAILABLE;
    ASSetCounterUnit("");
    ASSetCounterColor(nNotAvailableColor);
    ASSetCounterValue(GetUIString(srNotAvailable));
}
private final function ApplyLayout()
{
    if (m_nShownValue != SHOWN_NOTHING)
    {
        return;
    }
    ASSetPosition(sCounterPosition);
    ASSetCounterTitle(GetUIString(srTitle));
}
private final function ASSetPosition(string frameName)
{
    ActionScriptVoid("SetPosition");
}
private final function ASSetCounterTitle(string txtTitle)
{
    ActionScriptVoid("SetCounterTitle");
}
private final function ASSetCounterValue(string txtValue)
{
    ActionScriptVoid("SetCounterValue");
}
private final function ASSetCounterUnit(string txtUnit)
{
    ActionScriptVoid("SetCounterUnit");
}
private final function ASSetCounterColor(int txtColor)
{
    ActionScriptVoid("SetCounterColor");
}
private final function ASSlideTo(float nX, float nSeconds)
{
    ActionScriptVoid("SlideTo");
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    srTitle = $49875982
    srUnit = $49875983
    srNotAvailable = $49875984
    sCounterPosition = "topright2"
    nDistanceColor = 16777215
    nNotAvailableColor = 9211020
    // This clears all objectives but technically doesn't size to the smaller one. Maybe on a 
    // later pass we can clean it up
    fObjectiveShiftX = 350.0
    fSlideTime = 0.25
    fSlideBackDelay = 0.5
    CounterMovie = GFxMovieInfo'GUI_DesignUI_Counter_Milan.DesignUI_Counter'
    SharedDesignMovie = GFxMovieInfo'GUI_DesignUI_SharedDesign.SharedDesign'
}
