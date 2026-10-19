// MILAN CHANGE - Mgamerz - 2026-10-16
// Custom photo mode subclass for multiplayer
Class SFXSFHandler_PhotoMode_Milan extends SFXSFHandler_PhotoMode;

var transient SFXPRIMP SelectedPhotoPlayer;
var transient bool bFollowPhotoPlayer;
var transient float RosterRefreshCountdown;
var transient string LastRosterSignature;
// MILAN CHANGE - Mgamerz - 2026-10-17
var transient bool bLoggedPhotoMarkerUpdate;
// END MILAN CHANGE

public function bool HandleInputEvent(BioGuiEvents Event, optional float fValue = 1.0)
{
    local BioPlayerController PC;

    PC = BioPlayerController(GetPC());
    // Superclass UI can consume the mouse event before the input bind executes we use for moving camera
    // Keep camera capture in sync with the same RMB events that show/hide its cursor
    if (PC != None && PhotoMode != None && PhotoMode.bMPSpectatorPhoto)
    {
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
public function MovieLoaded()
{
    local ASParams Param;
    local array<ASParams> Params;

    Super.MovieLoaded();
    bFollowPhotoPlayer = FALSE;
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
    Param.sVar = string($49875788);
    Params.AddItem(Param);
    Param.sVar = string($49875789);
    Params.AddItem(Param);
    Param.sVar = string($49875790);
    Params.AddItem(Param);
    Param.Type = ASParamTypes.ASParam_Float;
    Param.fVar = float(PhotoMode.MPPhotoSpeedIndex);
    Params.AddItem(Param);
    Param.fVar = float(PhotoMode.MPPhotoSmoothingIndex);
    Params.AddItem(Param);
    Param.Type = ASParamTypes.ASParam_Boolean;
    Param.bVar = !PhotoMode.bMPPhotoNoCollision;
    Params.AddItem(Param);
    oPanel.InvokeMethodArgs("PhotoMode.setCameraControlOptions", Params);
    // END MILAN CHANGE
    RefreshPhotoPlayers(TRUE);
}

// MILAN CHANGE - Mgamerz - 2026-10-17
public function SetMPPhotoCameraOptions(int SpeedIndex, int SmoothingIndex, bool bCollision)
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
        && PhotoMode.bIsActive && Class'SFXGUIValue_MarkerPlayerHealth'.default.bHideInPhotoMode;
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
    // MILAN CHANGE - Mgamerz - 2026-10-17
    ApplyPhotoPlayerMarkers(TRUE);
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

defaultproperties
{
}
