// MILAN CHANGE - Mgamerz - 2026-10-16
// Custom photo mode subclass for multiplayer
Class SFXSFHandler_PhotoMode_Milan extends SFXSFHandler_PhotoMode;

var transient SFXPRIMP SelectedPhotoPlayer;
var transient bool bFollowPhotoPlayer;
var transient float RosterRefreshCountdown;
var transient string LastRosterSignature;
// MILAN CHANGE - Mgamerz - 2026-10-17
var transient bool bLoggedPhotoMarkerUpdate;
// MILAN CHANGE - Mgamerz - 2026-10-19
struct PhotoHiddenClip
{
    var GFxValue Clip;
    var bool bWasVisible;
    var bool bTouched;
};
var transient array<PhotoHiddenClip> HiddenPhotoClips;
var transient SFXGUI_Markers PhotoPopupMovie;
var transient GFxValue PhotoPopupClip;
// MILAN CHANGE - Mgamerz - 2026-10-20
var transient bool bRestoringPhotoSettings;
// END MILAN CHANGE

public function bool HandleInputEvent(BioGuiEvents Event, optional float fValue = 1.0)
{
    local BioPlayerController PC;

    PC = BioPlayerController(GetPC());
    // Superclass UI can consume the mouse event before the input bind executes we use for moving camera
    // Keep camera capture in sync with the same RMB events that show/hide its cursor
    if (PC != None && PhotoMode != None && PhotoMode.bMPSpectatorPhoto)
    {
        // MILAN CHANGE - Mgamerz - 2026-10-25
        if (PhotoMode.HandleMPPhotoPlayerButton(Event)) return TRUE;
        // END MILAN CHANGE
        if (Event == BioGuiEvents.BIOGUI_EVENT_MOUSE_BUTTON_RIGHT)
        {
            PC.bPhotoModeCameraUnlocked = TRUE;
        }
        else if (Event == BioGuiEvents.BIOGUI_EVENT_MOUSE_BUTTON_RIGHT_RELEASE)
        {
            PC.bPhotoModeCameraUnlocked = FALSE;
        }
    }
    return Super.HandleInputEvent(Event, fValue);
}

// Custom MP only items
// Mgamerz - 2026-10-20
// Read default values when showing photo mode
public function OnPanelAdded()
{
    local int i;
    local int Index;

    Super.OnPanelAdded();
    if (PhotoMode == None) 
    {
        return;
    }
    PhotoMode.EnsureMPPhotoMatchSettings();
    for (i = 0; i < TextSliderOptions.Length; i++)
    {
        Index = Class'SFXSFHandler_PhotoMode'.default.TextSliderOptions.Find('Id', TextSliderOptions[i].Id);
        if (Index != -1) 
        {
            TextSliderOptions[i].DefaultValue = Class'SFXSFHandler_PhotoMode'.default.TextSliderOptions[Index].DefaultValue;
        }
        Index = PhotoMode.MPPhotoSavedOptions.Find('Id', int(TextSliderOptions[i].Id));
        if (Index != -1) 
        {
            TextSliderOptions[i].DefaultValue = Clamp(int(PhotoMode.MPPhotoSavedOptions[Index].Value), 0, TextSliderOptions[i].Values.Length - 1);
        }
    }
    for (i = 0; i < RangeSliderOptions.Length; i++)
    {
        Index = Class'SFXSFHandler_PhotoMode'.default.RangeSliderOptions.Find('Id', RangeSliderOptions[i].Id);
        if (Index != -1) 
        {
            RangeSliderOptions[i].DefaultValue = Class'SFXSFHandler_PhotoMode'.default.RangeSliderOptions[Index].DefaultValue;
        }
        Index = PhotoMode.MPPhotoSavedOptions.Find('Id', int(RangeSliderOptions[i].Id));
        if (Index != -1) 
        {
            RangeSliderOptions[i].DefaultValue = FClamp(PhotoMode.MPPhotoSavedOptions[Index].Value, RangeSliderOptions[i].Range.X, RangeSliderOptions[i].Range.Y);
        }
    }
    for (i = 0; i < SliderOptions.Length; i++)
    {
        Index = Class'SFXSFHandler_PhotoMode'.default.SliderOptions.Find('Id', SliderOptions[i].Id);
        if (Index != -1) 
        {
            SliderOptions[i].DefaultValue = Class'SFXSFHandler_PhotoMode'.default.SliderOptions[Index].DefaultValue;
        }
        Index = PhotoMode.MPPhotoSavedOptions.Find('Id', int(SliderOptions[i].Id));
        if (Index != -1)
        {
            SliderOptions[i].DefaultValue = FClamp(PhotoMode.MPPhotoSavedOptions[Index].Value, 0.0, SliderOptions[i].MaxValue);
        }
    }
}

public function MovieLoaded()
{
    local ASParams Param;
    local array<ASParams> Params;
    local int i;
    local int Index;
    local SFXPRIMP PRI;

    // MILAN CHANGE - Mgamerz - 2026-10-20
    bRestoringPhotoSettings = TRUE;
    Super.MovieLoaded();
    bFollowPhotoPlayer = FALSE;
    Index = TextSliderOptions.Find('Id', PhotoModeOptionType.PhotoOption_CameraMode);
    if (Index != -1) 
    {
        bFollowPhotoPlayer = TextSliderOptions[Index].DefaultValue == 1;
    }
    for (i = 0; i < TextSliderOptions.Length; i++)
    {
        if (int(TextSliderOptions[i].Id) > 0 && int(TextSliderOptions[i].Id) < 16) 
        {
            Super.SetOption(TextSliderOptions[i].Id, float(TextSliderOptions[i].DefaultValue));
        }
    }
    for (i = 0; i < RangeSliderOptions.Length; i++)
    {
        if (int(RangeSliderOptions[i].Id) > 0 && int(RangeSliderOptions[i].Id) < 16) 
        {
            Super.SetOption(RangeSliderOptions[i].Id, RangeSliderOptions[i].DefaultValue);
        }
    }
    for (i = 0; i < SliderOptions.Length; i++)
    {
        if (int(SliderOptions[i].Id) > 0 && int(SliderOptions[i].Id) < 16) 
        {
            Super.SetOption(SliderOptions[i].Id, SliderOptions[i].DefaultValue);
        }
    }
    if (GetPC().WorldInfo.GRI != None)
    {
        for (i = 0; i < GetPC().WorldInfo.GRI.PRIArray.Length; i++)
        {
            PRI = SFXPRIMP(GetPC().WorldInfo.GRI.PRIArray[i]);
            if (PRI != None && PRI.PlayerID == PhotoMode.MPPhotoSavedPlayerID) 
            {
                SelectedPhotoPlayer = PRI;
            }
        }
    }
    bRestoringPhotoSettings = FALSE;
    // END MILAN CHANGE
    Param.Type = ASParamTypes.ASParam_String;
    Param.sVar = string($49875780);
    Params.AddItem(Param);
    Param.sVar = string($49875781);
    Params.AddItem(Param);
    Param.sVar = string($49875782);
    Params.AddItem(Param);
    Param.sVar = string($49875783);
    Params.AddItem(Param);
    oPanel.InvokeMethodArgs("PhotoMode.setMultiplayerLabels", Params);
    Params.Length = 0;
    Param.sVar = string($49875784);
    Params.AddItem(Param);
    Param.sVar = string($653223);
    Params.AddItem(Param);
    Param.sVar = string($653225);
    Params.AddItem(Param);
    Param.Type = ASParamTypes.ASParam_Boolean;
    Param.bVar = !Class'SFXGUIValue_MarkerPlayerHealth'.default.bHideInPhotoMode;
    Params.AddItem(Param);
    oPanel.InvokeMethodArgs("PhotoMode.setPlayerMarkerOptions", Params);
    // MILAN CHANGE - Mgamerz - 2026-10-17
    Params.Length = 0;
    Param.Type = ASParamTypes.ASParam_String;
    Param.sVar = string($49875785);
    Params.AddItem(Param);
    Param.sVar = string($49875786);
    Params.AddItem(Param);
    Param.sVar = string($49875787);
    Params.AddItem(Param);
    Param.sVar = string($817903);
    Params.AddItem(Param);
    Param.sVar = string($817904);
    Params.AddItem(Param);
    Param.sVar = string($817905);
    Params.AddItem(Param);
    Param.Type = ASParamTypes.ASParam_Float;
    Param.fVar = float(PhotoMode.MPPhotoSpeedIndex);
    Params.AddItem(Param);
    Param.fVar = float(PhotoMode.MPPhotoSmoothingIndex);
    Params.AddItem(Param);
    Param.Type = ASParamTypes.ASParam_Boolean;
    Param.bVar = !PhotoMode.bMPPhotoNoCollision;
    Params.AddItem(Param);
    // MILAN CHANGE - Mgamerz - 2026-10-19
    Param.Type = ASParamTypes.ASParam_String;
    Param.sVar = string($49875794);
    Params.AddItem(Param);
    Param.Type = ASParamTypes.ASParam_Float;
    Param.fVar = float(PhotoMode.MPPhotoMovementSmoothingIndex);
    Params.AddItem(Param);
    oPanel.InvokeMethodArgs("PhotoMode.setCameraControlOptions", Params);
    // MILAN CHANGE - Mgamerz - 2026-10-28
    // Overlay arguments start at zero; camera labels/values must not prefix this call.
    Params.Length = 0;
    // END MILAN CHANGE
    Param.Type = ASParamTypes.ASParam_String;
    Param.sVar = string($49875791);
    Params.AddItem(Param);
    Param.sVar = string($49875792);
    Params.AddItem(Param);
    Param.sVar = string($49875793);
    Params.AddItem(Param);
    Param.Type = ASParamTypes.ASParam_Boolean;
    Param.bVar = !PhotoMode.bMPPhotoOverlaysHidden;
    Params.AddItem(Param);
    Param.bVar = !PhotoMode.bMPPhotoHintsHidden;
    Params.AddItem(Param);
    Param.bVar = !PhotoMode.bMPPhotoGrenadesHidden;
    Params.AddItem(Param);
    Param.Type = ASParamTypes.ASParam_String;
    Param.sVar = string($49875795);
    Params.AddItem(Param);
    Param.Type = ASParamTypes.ASParam_Boolean;
    Param.bVar = !PhotoMode.bMPPhotoOutlinesHidden;
    Params.AddItem(Param);
    oPanel.InvokeMethodArgs("PhotoMode.setPhotoOverlayOptions", Params);
    ApplyPhotoOverlays(FALSE);
    PhotoMode.MPPhotoCycleCallback = CycleHiddenPhotoPlayer;
    RefreshPhotoPlayers(TRUE);
    Params.Length = 0;
    Param.Type = ASParamTypes.ASParam_Boolean;
    Param.bVar = bFollowPhotoPlayer;
    Params.AddItem(Param);
    oPanel.InvokeMethodArgs("PhotoMode.setMultiplayerCameraMode", Params);
    bOptionsHidden = FALSE;
    LogInternal("MilanPhoto: restored match settings" @ PhotoMode.MPPhotoSavedOptions.Length @ "follow" @ bFollowPhotoPlayer @ "distance/height" @ PhotoMode.MPPhotoFollowDistance @ PhotoMode.MPPhotoFollowHeight);
    // END MILAN CHANGE
}

// MILAN CHANGE - Mgamerz - 2026-10-17
public function SetMPPhotoCameraOptions(int SpeedIndex, int SmoothingIndex, bool bCollision, int MovementSmoothingIndex)
{
    if (PhotoMode != None && PhotoMode.bMPSpectatorPhoto)
    {
        PhotoMode.MPPhotoSpeedIndex = Clamp(SpeedIndex, 0, 6);
        if (PhotoMode.MPPhotoSmoothingIndex != SmoothingIndex)
        {
            PhotoMode.MPPhotoDesiredRotation = PhotoMode.MPPhotoRotation;
        }
        PhotoMode.MPPhotoSmoothingIndex = Clamp(SmoothingIndex, 0, 3);
        PhotoMode.bMPPhotoNoCollision = !bCollision;
        // MILAN CHANGE - Mgamerz - 2026-10-20
        MovementSmoothingIndex = Clamp(MovementSmoothingIndex, 0, 3);
        if (PhotoMode.MPPhotoMovementSmoothingIndex != MovementSmoothingIndex)
        {
            PhotoMode.ResetMPPhotoMovement();
        }
        PhotoMode.MPPhotoMovementSmoothingIndex = MovementSmoothingIndex;
        // END MILAN CHANGE
    }
}
// END MILAN CHANGE

// Show/hide player markers
public function SetPhotoPlayerMarkers(bool bShow)
{
    local int UpdatedMarkers;

    if (PhotoMode != None && PhotoMode.bMPSpectatorPhoto)
    {
        Class'SFXGUIValue_MarkerPlayerHealth'.default.bHideInPhotoMode = !bShow;
        // MILAN CHANGE - Mgamerz - 2026-10-17
        UpdatedMarkers = ApplyPhotoPlayerMarkers(FALSE);
        LogInternal("MilanPhoto: player markers shown" @ bShow @ "updated" @ UpdatedMarkers);
        // END MILAN CHANGE
    }
}

// MILAN CHANGE - Mgamerz - 2026-10-17
// The native marker movie calls its C++ value update directly, not the script override.
public function int ApplyPhotoPlayerMarkers(bool bRestore)
{
    local SFXGUIInteraction GUI;
    local SFXGUI_Markers MarkerMovie;
    local SFXGUIValue_Marker Marker;
    local SFXGUIValue_MarkerPlayerHealth PlayerMarker;
    local bool bHide;
    local int Count;

    GUI = Class'SFXGUIInteraction'.static.GetInstance();
    if (GUI == None || GetPC() == None)
    {
        return 0;
    }
    MarkerMovie = SFXGUI_Markers(GUI.GetMovie(GetPC(), 'Markers'));
    if (MarkerMovie == None)
    {
        return 0;
    }
    bHide = !bRestore && PhotoMode != None && PhotoMode.bMPSpectatorPhoto
        && PhotoMode.bIsActive && (PhotoMode.bMPPhotoOverlaysHidden || Class'SFXGUIValue_MarkerPlayerHealth'.default.bHideInPhotoMode);
    foreach MarkerMovie.Markers(Marker)
    {
        PlayerMarker = SFXGUIValue_MarkerPlayerHealth(Marker);
        if (PlayerMarker != None)
        {
            PlayerMarker.SetPhotoMarkerHidden(bHide && PlayerMarker.Player != None);
            Count++;
        }
    }
    if (!bRestore && Count > 0 && !bLoggedPhotoMarkerUpdate)
    {
        bLoggedPhotoMarkerUpdate = TRUE;
        LogInternal("MilanPhoto: explicit marker update connected" @ Count);
    }
    return Count;
}
// END MILAN CHANGE

public event function Update(float fDeltaT)
{
    Super.Update(fDeltaT);
    // MILAN CHANGE - Mgamerz - 2026-10-17
    ApplyPhotoPlayerMarkers(FALSE);
    ApplyPhotoOverlays(FALSE);
    // END MILAN CHANGE
    if (!bInitialized || oPanel == None)
    {
        return;
    }
    RosterRefreshCountdown -= fDeltaT;
    if (RosterRefreshCountdown <= 0.0)
    {
        RosterRefreshCountdown = 0.25;
        RefreshPhotoPlayers(FALSE);
    }
}

public function RefreshPhotoPlayers(bool bForce)
{
    local PlayerController PC;
    local SFXPRIMP PRI;
    local array<SFXPRIMP> Players;
    local Actor ViewSubject;
    local bool bSelectedPresent;
    local string Signature;
    local int i;
    local ASParams Param;
    local array<ASParams> Params;

    PC = GetPC();
    if (PC == None || PC.WorldInfo.GRI == None || oPanel == None)
    {
        return;
    }
    if (PC.PlayerCamera != None)
    {
        ViewSubject = PC.PlayerCamera.PendingViewTarget.Target;
        if (ViewSubject == None)
        {
            ViewSubject = PC.PlayerCamera.ViewTarget.Target;
        }
    }
    for (i = 0; i < PC.WorldInfo.GRI.PRIArray.Length; i++)
    {
        PRI = SFXPRIMP(PC.WorldInfo.GRI.PRIArray[i]);
        // Only skip pawns that are deleted/removed from game
        if (PRI == None || PRI.bDeleteMe || PRI.bIsInactive || PRI.bOnlySpectator || PRI.SFXPawn == None || PRI.SFXPawn.bDeleteMe)
        {
            continue;
        }
        Players.AddItem(PRI);
        if (PRI == SelectedPhotoPlayer)
        {
            bSelectedPresent = TRUE;
        }
    }
    if (!bSelectedPresent)
    {
        SelectedPhotoPlayer = None;
        for (i = 0; i < Players.Length; i++)
        {
            if (Players[i].SFXPawn == ViewSubject)
            {
                SelectedPhotoPlayer = Players[i];
                break;
            }
        }
        if (SelectedPhotoPlayer == None && Players.Length > 0)
        {
            SelectedPhotoPlayer = Players[0];
        }
    }
    if (Players.Length == 0)
    {
        bFollowPhotoPlayer = FALSE;
    }
    ApplyPhotoSubject();
    // MILAN CHANGE - Mgamerz - 2026-10-20
    if (PhotoMode != None && SelectedPhotoPlayer != None) 
    {
        PhotoMode.MPPhotoSavedPlayerID = SelectedPhotoPlayer.PlayerID;
    }
    // END MILAN CHANGE
    if (SelectedPhotoPlayer != None)
    {
        Signature = string(SelectedPhotoPlayer.PlayerID);
    }
    for (i = 0; i < Players.Length; i++)
    {
        Signature $= "|" $ Players[i].PlayerID $ ":" $ Len(Players[i].PlayerName) $ ":" $ Players[i].PlayerName $ ":" $ Players[i].SFXPawn.IsInState('Downed');
    }
    if (!bForce && Signature == LastRosterSignature)
    {
        return;
    }
    LastRosterSignature = Signature;
    Param.Type = ASParamTypes.ASParam_String;
    Param.sVar = SelectedPhotoPlayer != None ? string(SelectedPhotoPlayer.PlayerID) : "";
    Params.AddItem(Param);
    oPanel.InvokeMethodArgs("PhotoMode.beginMultiplayerPlayers", Params);
    for (i = 0; i < Players.Length; i++)
    {
        Params.Length = 0;
        Param.Type = ASParamTypes.ASParam_String;
        Param.sVar = string(Players[i].PlayerID);
        Params.AddItem(Param);
        Param.sVar = Players[i].PlayerName;
        Params.AddItem(Param);
        Param.Type = ASParamTypes.ASParam_Boolean;
        Param.bVar = Players[i].SFXPawn.IsInState('Downed');
        Params.AddItem(Param);
        oPanel.InvokeMethodArgs("PhotoMode.addMultiplayerPlayer", Params);
    }
    Params.Length = 0;
    oPanel.InvokeMethodArgs("PhotoMode.endMultiplayerPlayers", Params);
}

public function SelectPhotoPlayer(string PlayerKey)
{
    local PlayerController PC;
    local SFXPRIMP PRI;
    local int i;

    PC = GetPC();
    if (PC == None || PC.WorldInfo.GRI == None)
    {
        return;
    }
    for (i = 0; i < PC.WorldInfo.GRI.PRIArray.Length; i++)
    {
        PRI = SFXPRIMP(PC.WorldInfo.GRI.PRIArray[i]);
        if (PRI != None && !PRI.bDeleteMe && !PRI.bIsInactive && !PRI.bOnlySpectator && PRI.SFXPawn != None && !PRI.SFXPawn.bDeleteMe && string(PRI.PlayerID) == PlayerKey)
        {
            SelectedPhotoPlayer = PRI;
            LogInternal("MilanPhoto: selected player" @ PRI.PlayerID @ PRI.PlayerName);
            RefreshPhotoPlayers(TRUE);
            return;
        }
    }

    // The player may have disconnected between drawing the row and receiving its callback.
    RefreshPhotoPlayers(TRUE);
}

public function SetOption(PhotoModeOptionType OptionId, float ValueIdx)
{
    // Actor hiding requires lots of stuff that does not work well in MP - actor ownership, controller, etc,
    // which can get real ugly in replicated environment, so unfortunately have to just disable it
    if (OptionId >= PhotoModeOptionType.PhotoOption_HidePlayer)
    {
        return;
    }
    // MILAN CHANGE - Mgamerz - 2026-10-20
    // Save choices before we restore the UI
    if (!bRestoringPhotoSettings && PhotoMode != None && PhotoMode.bMPSpectatorPhoto) 
    {
        PhotoMode.SaveMPPhotoOption(int(OptionId), ValueIdx);
    }
    // END MILAN CHANGE
    if (OptionId == PhotoModeOptionType.PhotoOption_CameraMode)
    {
        bFollowPhotoPlayer = ValueIdx == 1.0 && SelectedPhotoPlayer != None;
        LogInternal("MilanPhoto: UI camera mode follow" @ bFollowPhotoPlayer @ "photo mode" @ PhotoMode);
        ApplyPhotoSubject();
        return;
    }
    Super.SetOption(OptionId, ValueIdx);
}

public function ApplyPhotoSubject()
{
    if (PhotoMode != None && PhotoMode.bMPSpectatorPhoto)
    {
        PhotoMode.SetMPPhotoSubject(SelectedPhotoPlayer != None ? SelectedPhotoPlayer.SFXPawn : None, bFollowPhotoPlayer);
    }
}

public function OnPanelRemoved()
{
    local BioPlayerController PC;

    PC = BioPlayerController(GetPC());
    // MILAN CHANGE - Mgamerz - 2026-10-25
    if (PhotoMode != None) 
    {
        PhotoMode.MPPhotoCycleCallback = None;
    }
    // END MILAN CHANGE
    // MILAN CHANGE - Mgamerz - 2026-10-17
    ApplyPhotoPlayerMarkers(TRUE);
    ApplyPhotoOverlays(TRUE);
    if (PhotoMode != None) 
    {
        PhotoMode.ApplyMPPhotoHintVisibility(TRUE);
    }
    bLoggedPhotoMarkerUpdate = FALSE;
    // END MILAN CHANGE
    // Also clean up when a higher-priority screen removes the movie without ShowMenu.
    if (PhotoMode != None && PhotoMode.bMPSpectatorPhoto && PC != None)
    {
        PC.GameModeManager2.DisableMode(14);
    }
    SetMouseShown(FALSE);
    SelectedPhotoPlayer = None;
    LastRosterSignature = "";
    RosterRefreshCountdown = 0.0;
    bFollowPhotoPlayer = FALSE;
    bInitialized = FALSE;
    Super.OnPanelRemoved();
}

// MILAN CHANGE - Mgamerz - 2026-10-19
public function SetPhotoOverlayOptions(bool bShowAll, bool bShowHints, bool bShowGrenades, bool bShowOutlines)
{
    if (PhotoMode == None || !PhotoMode.bMPSpectatorPhoto) 
    {
        return;
    }
    PhotoMode.bMPPhotoOverlaysHidden = !bShowAll;
    PhotoMode.bMPPhotoHintsHidden = !bShowHints;
    PhotoMode.bMPPhotoGrenadesHidden = !bShowGrenades;
    // MILAN CHANGE - Mgamerz - 2026-10-25
    PhotoMode.bMPPhotoOutlinesHidden = !bShowOutlines;
    PhotoMode.ApplyMPPhotoVisuals(FALSE);
    // END MILAN CHANGE
    ApplyPhotoPlayerMarkers(FALSE);
    ApplyPhotoOverlays(FALSE);
    LogInternal("MilanPhoto: overlays" @ bShowAll @ "hints" @ bShowHints @ "grenades" @ bShowGrenades @ "outlines" @ bShowOutlines);
}

public final function ApplyPhotoOverlays(bool bRestore)
{
    local SFXGUIInteraction GUI;
    local SFXGUI_Markers MarkerMovie;
    local SFXGUIValue_Marker Marker;
    local bool bActive;
    local bool bHideHints;
    local bool bHideGrenades;
    local int i;

    for (i = 0; i < HiddenPhotoClips.Length; i++) 
    {
        HiddenPhotoClips[i].bTouched = FALSE;
    }
    bActive = !bRestore && PhotoMode != None && PhotoMode.bMPSpectatorPhoto && PhotoMode.bIsActive;
    bHideHints = bActive && (PhotoMode.bMPPhotoOverlaysHidden || PhotoMode.bMPPhotoHintsHidden);
    bHideGrenades = bActive && (PhotoMode.bMPPhotoOverlaysHidden || PhotoMode.bMPPhotoGrenadesHidden);
    GUI = Class'SFXGUIInteraction'.static.GetInstance();
    if (GUI != None && GetPC() != None)
    {
        MarkerMovie = SFXGUI_Markers(GUI.GetMovie(GetPC(), 'Markers'));
        if (MarkerMovie != None)
        {
            if (bHideHints)
            {
                // GetVariableObject may return a fresh wrapper. Retain one reference per movie
                // so it cannot be mistaken for a removed clip and restored in this same update
                if (PhotoPopupMovie != MarkerMovie || PhotoPopupClip == None)
                {
                    PhotoPopupMovie = MarkerMovie;
                    PhotoPopupClip = MarkerMovie.GetVariableObject("PopupAnimation");
                }
                HidePhotoClip(PhotoPopupClip);
            }
            if (bHideGrenades)
            {
                foreach MarkerMovie.Markers(Marker)
                {
                    if (SFXGUIValue_MarkerGrenade(Marker) != None && Marker.FullyInitialized)
                    {
                        HidePhotoClip(Marker.MarkerClip);
                    }
                }
            }
        }
    }
    // Restore toggled categories and remove references to UI elements
    for (i = HiddenPhotoClips.Length - 1; i >= 0; i--)
    {
        if (!HiddenPhotoClips[i].bTouched)
        {
            if (HiddenPhotoClips[i].Clip != None) 
            {
                HiddenPhotoClips[i].Clip.SetVisible(HiddenPhotoClips[i].bWasVisible);
            }
            HiddenPhotoClips.Remove(i, 1);
        }
    }
    if (!bHideHints)
    {
        PhotoPopupClip = None;
        PhotoPopupMovie = None;
    }
    if (PhotoMode != None) 
    {
        PhotoMode.ApplyMPPhotoHintVisibility(bRestore);
    }
}

public final function HidePhotoClip(GFxValue Clip)
{
    local int i;
    local PhotoHiddenClip Entry;
    local ASDisplayInfo DisplayInfo;

    if (Clip == None) 
    {   
        return;
    }
    for (i = 0; i < HiddenPhotoClips.Length; i++)
    {
        if (HiddenPhotoClips[i].Clip == Clip) 
        {
            break;
        }
    }
    if (i == HiddenPhotoClips.Length)
    {
        Entry.Clip = Clip;
        DisplayInfo = Clip.GetDisplayInfo();
        Entry.bWasVisible = DisplayInfo.visible;
        HiddenPhotoClips.AddItem(Entry);
    }
    HiddenPhotoClips[i].bTouched = TRUE;
    Clip.SetVisible(FALSE);
}
// END MILAN CHANGE

// MILAN CHANGE - Mgamerz - 2026-10-25
public function ToggleOptions()
{
    Super.ToggleOptions();
    if (PhotoMode != None && PhotoMode.bMPSpectatorPhoto)
    {
        if (!bOptionsHidden) 
        {
            RefreshPhotoPlayers(TRUE);
        }
    }
}

// Handles cycling through players, forward or backwards
public function CycleHiddenPhotoPlayer(int Direction)
{
    local BioPlayerController PC;
    local SFXPRIMP PRI;
    local array<SFXPRIMP> Players;
    local int i;
    local int Index;

    if (!bInitialized || !bOptionsHidden || PhotoMode == None || !PhotoMode.bMPSpectatorPhoto || !PhotoMode.bIsActive || !PhotoMode.bMPPhotoFollow) 
    {
        return;
    }
    PC = BioPlayerController(GetPC());
    if (PC == None || PC.WorldInfo.GRI == None || PC.GameModeManager2 == None || PC.GameModeManager2.CurrentMode != 14) 
    {
        return;
    }
    RefreshPhotoPlayers(FALSE);
    Index = -1;
    for (i = 0; i < PC.WorldInfo.GRI.PRIArray.Length; i++)
    {
        PRI = SFXPRIMP(PC.WorldInfo.GRI.PRIArray[i]);
        // Don't show stuff about to be deleted. This filters out palyers joining or leaving where
        // state may not be correct
        if (PRI == None || PRI.bDeleteMe || PRI.bIsInactive || PRI.bOnlySpectator || PRI.SFXPawn == None || PRI.SFXPawn.bDeleteMe) 
        {
            continue;
        }
        if (PRI == SelectedPhotoPlayer) 
        {
            Index = Players.Length;
        }
        Players.AddItem(PRI);
    }
    if (Players.Length < 2) 
    {
        return;
    }
    if (Index == -1)
    {
        Index = Direction < 0 ? Players.Length - 1 : 0;
    }
    else
    {
        Index = (Index + (Direction < 0 ? -1 : 1) + Players.Length) % Players.Length;
    }
    SelectPhotoPlayer(string(Players[Index].PlayerID));
}
// END MILAN CHANGE

defaultproperties
{
}
