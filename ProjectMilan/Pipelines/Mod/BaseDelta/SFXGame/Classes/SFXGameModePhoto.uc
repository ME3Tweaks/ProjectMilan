Class SFXGameModePhoto extends SFXGameModeBase within BioPlayerController
    config(Input);

struct CachedActorState
{
    var Actor A;
    var bool bWasHidden;
};

var PostProcessSettings PostProcessSettings;
var config InterpCurveFloat ButtonCooldownCurve;
var transient array<CachedActorState> CachedPlayer;
var transient array<CachedActorState> CachedParty;
var transient array<CachedActorState> CachedEnemies;
var transient array<CachedActorState> CachedVehicles;
var transient array<CachedActorState> CachedNPCs;
var config array<string> CharacterMeshFilter;
var config array<string> FilterMaterialPaths;
var transient array<MaterialEffect> FilterEffects;
var transient array<float> ButtonPressTimes;
var(SFXGameModePhoto) WwiseEvent TakePhotoSound;
var(SFXGameModePhoto) export SFXCameraMode_PhotoFree PhotoCamFree;
var(SFXGameModePhoto) export SFXCameraMode_PhotoOrbit PhotoCamOrbit;
var(SFXGameModePhoto) export SFXCameraTransition_GalaxyMap InstantTransition;
var export MaterialEffect ME_ScreenEffect;
var(SFXGameModePhoto) float CamTransitionTime;
var(SFXGameModePhoto) config float DefaultPP_DOF_Radius;
var(SFXGameModePhoto) config float DefaultPP_DOF_FalloffExponent;
var(SFXGameModePhoto) config float DefaultPP_DOF_BlurKernelSize;
var(SFXGameModePhoto) config float DefaultPP_DOF_BlurBloomKernelSize;
var transient bool bUseOrbitCam;
var transient bool bOldAllowFilmGrain;
var transient bool bPlayerHidden;
var transient bool bPartyHidden;
var transient bool bEnemiesHidden;
var transient bool bVehiclesHidden;
var transient bool bNPCsHidden;
var transient byte bOldIgnoreMoveInput;
var transient byte bOldIgnoreLookInput;

// MILAN CHANGE - Mgamerz - 2026-10-16
// Append fields after all stock fields to retain their layout for native photo UI initialization.
var transient bool bMPSpectatorPhoto;
var transient bool bMPPhotoFollow;
var transient bool bMPPhotoOldCameraUnlocked;
var transient bool bMPPhotoOldGrainOverride;
var transient Pawn MPPhotoSubject;
var transient TPOV MPPhotoPOV;
var transient Rotator MPPhotoRotation;
var transient Vector MPPhotoVelocity;
var transient float MPPhotoFollowDistance;
var transient float MPPhotoFollowHeight;
var transient float MPPhotoBlendRemaining;
var transient float MPPhotoEntryTime;
var transient float MPPhotoOldGrainScale;
var transient Name MPPhotoOldCameraStyle;
var transient bool bMPPhotoOldCollisionEnabled;
var transient array<StaticKeyBind> MPPhotoOldPCBinds;
var transient array<StaticKeyBind> MPPhotoOldConsoleBinds;
var transient Vector MPPhotoTetherOrigin;
var transient bool bMPPhotoLoggedDispatch;
var transient bool bMPPhotoLoggedCamera;
var transient bool bMPPhotoLoggedUIInput;
var transient bool bMPPhotoLoggedAxes;
// MILAN CHANGE - Mgamerz - 2026-10-17
var transient bool bMPPhotoStateExiting;
var transient int MPPhotoSpeedIndex;
var transient int MPPhotoSmoothingIndex;
var transient bool bMPPhotoNoCollision;
var transient Rotator MPPhotoDesiredRotation;
// END MILAN CHANGE
// END MILAN CHANGE
public function Activated()
{
    local float LocalDefaultFOV;
    local Actor A;
    local SFXSelectionModule SelMod;

    // MILAN CHANGE - Mgamerz - 2026-10-16
    if (bMPSpectatorPhoto)
    {
        ActivateMPPhoto();
        return;
    }
    // END MILAN CHANGE
    Super.Activated();
    Outer.GameModeManager2.DisableInput();
    SetTimer(0.5, FALSE, 'EnableInputWrapper');
    Outer.PushState('PlayerPhotoMode');
    Outer.WorldInfo.PauseGame(TRUE);
    PhotoCamFree.ExternalModifyPPSettings = ModifyPostProcessSettings;
    PhotoCamOrbit.ExternalModifyPPSettings = ModifyPostProcessSettings;
    LocalDefaultFOV = Class'SFXSFHandler_PhotoMode'.static.GetDefaultFloatOption(2);
    PhotoCamFree.InitFromMode(LocalDefaultFOV);
    PhotoCamOrbit.InitFromMode(LocalDefaultFOV);
    bUseOrbitCam = Class'SFXSFHandler_PhotoMode'.static.GetDefaultBoolOption(0);
    PostProcessSettings = Class'Engine'.static.GetCurrentWorldInfo().DefaultPostProcessSettings;
    bOldAllowFilmGrain = IsSystemFilmgrainEnabled();
    SetSystemFilmgrainEnabled(TRUE);
    LocalPlayer(Outer.Player).BioAddPostProcessEffect(ME_ScreenEffect, Self, 1);
    InitializePostProcessSettings();
    InitializeFilters();
    SetFilmGrainStrength(Class'SFXSFHandler_PhotoMode'.static.GetDefaultFloatOption(14));
    SetSaturation(Class'SFXSFHandler_PhotoMode'.static.GetDefaultFloatOption(7));
    SetBrightness(Class'SFXSFHandler_PhotoMode'.static.GetDefaultFloatOption(8));
    SetContrast(Class'SFXSFHandler_PhotoMode'.static.GetDefaultFloatOption(9));
    ButtonPressTimes.Length = 53;
    Outer.GameModeManager2.Helper_SetStaticPCBinding('SpaceBar', "");
    Outer.GameModeManager2.Helper_SetStaticConsoleBinding('XboxTypeS_LeftX', "");
    Outer.GameModeManager2.Helper_SetStaticConsoleBinding('XboxTypeS_LeftY', "");
    bOldIgnoreMoveInput = Outer.bIgnoreMoveInput;
    bOldIgnoreLookInput = Outer.bIgnoreLookInput;
    Outer.bIgnoreMoveInput = 0;
    Outer.bIgnoreLookInput = 0;
    SFXPlayerCamera(Outer.PlayerCamera).ScreenShakeModifier.RemoveAllScreenShakes();
    Outer.ForceFeedbackManager.PauseWaveform(TRUE);
    Outer.m_oPlayerSelection.SelectionFlareComp.SetHidden(TRUE);
    foreach BioWorldInfo(Outer.WorldInfo).SelectableActors(A, )
    {
        SelMod = A.GetModule(Class'SFXSelectionModule');
        if (SelMod != None && SelMod.LensFlareComp != None)
        {
            SelMod.LensFlareComp.SetHidden(TRUE);
        }
    }
    Class'SFXEngine'.static.ResetForcedInactiveParticleSystems();
}
public function Deactivated()
{
    // MILAN CHANGE - Mgamerz - 2026-10-16
    if (bMPSpectatorPhoto)
    {
        DeactivateMPPhoto();
        return;
    }
    // END MILAN CHANGE
    Super.Deactivated();
    SetPlayerHidden(FALSE);
    SetPartyHidden(FALSE);
    SetEnemiesHidden(FALSE);
    SetNPCsHidden(FALSE);
    SetVehicleHidden(FALSE);
    PhotoCamFree.ResetRoll();
    PhotoCamOrbit.ResetRoll();
    SetSystemFilmgrainEnabled(bOldAllowFilmGrain);
    LocalPlayer(Outer.Player).BioRemovePostProcessEffect(ME_ScreenEffect);
    LocalPlayer(Outer.Player).ViewportClient.FilmGrain_ScaleOverride = FALSE;
    ResetFilters();
    Outer.PopState();
    Outer.WorldInfo.PauseGame(FALSE);
    Outer.GameModeManager2.Helper_ResetStaticPCBindings();
    Outer.GameModeManager2.Helper_ResetStaticConsoleBindings();
    Outer.bIgnoreMoveInput = bOldIgnoreMoveInput;
    Outer.bIgnoreLookInput = bOldIgnoreLookInput;
    bOldIgnoreMoveInput = 0;
    bOldIgnoreLookInput = 0;
    Outer.ForceFeedbackManager.PauseWaveform(FALSE);
}
public exec function DisableCamera()
{
    Outer.bPhotoModeCameraUnlocked = FALSE;
}
public function ModifyPostProcessSettings(out PostProcessSettings PPSettings)
{
    PPSettings.bEnableDOF = PostProcessSettings.bEnableDOF;
    PPSettings.DOF_FocusDistance = PostProcessSettings.DOF_FocusDistance;
    PPSettings.DOF_FocusInnerRadius = PostProcessSettings.DOF_FocusInnerRadius;
    PPSettings.DOF_FStop = PostProcessSettings.DOF_FStop;
    PPSettings.DOF_MaxFarBlurAmount = PostProcessSettings.DOF_MaxFarBlurAmount;
    PPSettings.DOF_MaxNearBlurAmount = PostProcessSettings.DOF_MaxNearBlurAmount;
    PPSettings.bEnableFilmGrain = PostProcessSettings.bEnableFilmGrain;
    PPSettings.bEnableVignette = PostProcessSettings.bEnableVignette;
    PPSettings.PP_DesaturationMultiplier = PostProcessSettings.PP_DesaturationMultiplier;
    PPSettings.PP_HighlightsMultiplier = PostProcessSettings.PP_HighlightsMultiplier;
    PPSettings.PP_MidTonesMultiplier = PostProcessSettings.PP_MidTonesMultiplier;
    PPSettings.PP_ShadowsMultiplier = PostProcessSettings.PP_ShadowsMultiplier;
    PPSettings.bEnableBloom = PostProcessSettings.bEnableBloom;
    PPSettings.Bloom_Scale = PostProcessSettings.Bloom_Scale;
    PPSettings.Bloom_Threshold = PostProcessSettings.Bloom_Threshold;
}
public exec function ShowMenu()
{
    local bool bWasMPPhoto;

    bWasMPPhoto = bMPSpectatorPhoto;
    Class'SFXGUIInteraction'.static.GetInstance().HidePhotoMode(Outer);
    // MILAN CHANGE - Mgamerz - 2026-10-16
    // Spectator mode remains underneath mode 14. Closing MP photo mode simply reveals it.
    if (!bWasMPPhoto)
    {
        Class'SFXGUIInteraction'.static.GetInstance().ShowBrowserWheel(Outer, FALSE);
    }
    // END MILAN CHANGE
}
public exec function EnableCamera()
{
    Outer.bPhotoModeCameraUnlocked = TRUE;
}
public function EnableInputWrapper()
{
    Outer.GameModeManager2.EnableInput();
}
public function SFXCameraMode GetCameraMode(SFXCameraMode OldCameraMode, out int PreserveTarget, out float TransitionTime, out SFXCameraMode_Interpolate Transition)
{
    local SFXCameraMode NewCameraMode;

    // MILAN CHANGE - Mgamerz - 2026-10-16
    if (bMPSpectatorPhoto)
    {
        Transition = InstantTransition;
        TransitionTime = 0.0;
        PreserveTarget = 0;
        return PhotoCamFree;
    }
    // END MILAN CHANGE
    if (bUseOrbitCam)
    {
        NewCameraMode = PhotoCamOrbit;
    }
    else
    {
        NewCameraMode = PhotoCamFree;
    }
    if (OldCameraMode == PhotoCamFree && NewCameraMode == PhotoCamOrbit || OldCameraMode == PhotoCamOrbit && NewCameraMode == PhotoCamFree)
    {
        TransitionTime = CamTransitionTime;
        PreserveTarget = 0;
    }
    else
    {
        Transition = InstantTransition;
        TransitionTime = 0.0;
        PreserveTarget = 0;
    }
    return NewCameraMode;
}
public exec function GuiKey(BioGuiEvents Event)
{
    local float ButtonCooldown;

    // MILAN CHANGE - Mgamerz - 2026-10-16
    if (bMPSpectatorPhoto && !bMPPhotoLoggedUIInput)
    {
        bMPPhotoLoggedUIInput = TRUE;
        LogInternal("MilanPhoto: first GUI input" @ Event @ "mode" @ Outer.GameModeManager2.CurrentMode);
    }
    // END MILAN CHANGE
    switch (Event)
    {
        case BioGuiEvents.BIOGUI_EVENT_CONTROL_UP:
        case BioGuiEvents.BIOGUI_EVENT_CONTROL_DOWN:
        case BioGuiEvents.BIOGUI_EVENT_CONTROL_LEFT:
        case BioGuiEvents.BIOGUI_EVENT_CONTROL_RIGHT:
            if (ButtonPressTimes[int(Event)] == float(0))
            {
                ButtonPressTimes[int(Event)] = Outer.WorldInfo.TimeSeconds;
            }
            ButtonCooldown = EvalInterpCurveFloat(ButtonCooldownCurve, Outer.WorldInfo.TimeSeconds - ButtonPressTimes[int(Event)]);
            break;
        case BioGuiEvents.BIOGUI_EVENT_CONTROL_UP_RELEASE:
            ButtonPressTimes[14] = 0.0;
            break;
        case BioGuiEvents.BIOGUI_EVENT_CONTROL_DOWN_RELEASE:
            ButtonPressTimes[11] = 0.0;
            break;
        case BioGuiEvents.BIOGUI_EVENT_CONTROL_LEFT_RELEASE:
            ButtonPressTimes[12] = 0.0;
            break;
        case BioGuiEvents.BIOGUI_EVENT_CONTROL_RIGHT_RELEASE:
            ButtonPressTimes[13] = 0.0;
            break;
        default:
    }
    Class'SFXGUIInteraction'.static.GetInstance().HandleInputEvent(Outer.GetPlayerControllerId(), Event, ButtonCooldown);
}
public function bool HasCharacterMesh(Actor TestActor)
{
    local SkeletalMeshActor CheckSMA;
    local SFXStuntActor CheckStunt;
    local BioPawn ChkPawn;
    local SkeletalMeshComponent MeshComp;
    local int idx;
    local string Path;

    CheckSMA = SkeletalMeshActor(TestActor);
    CheckStunt = SFXStuntActor(TestActor);
    ChkPawn = BioPawn(TestActor);
    if (ChkPawn != None)
    {
        return TRUE;
    }
    else if (CheckSMA != None)
    {
        MeshComp = CheckSMA.SkeletalMeshComponent;
    }
    else if (CheckStunt != None)
    {
        MeshComp = CheckStunt.BodyMesh;
    }
    if (MeshComp != None)
    {
        Path = string(MeshComp.SkeletalMesh);
        for (idx = 0; idx < CharacterMeshFilter.Length; idx++)
        {
            if (InStr(Path, CharacterMeshFilter[idx], , TRUE, ) != -1)
            {
                return TRUE;
            }
        }
    }
    return FALSE;
}
public function HideAttachedActors(out array<CachedActorState> InHiddenActors)
{
    local Actor ChkActor;
    local int idx;
    local CachedActorState CachedState;

    foreach Outer.WorldInfo.AllActors(Class'Actor', ChkActor, )
    {
        if (ChkActor != None && ChkActor.Base != None)
        {
            idx = InHiddenActors.Find('A', ChkActor.Base);
            if (idx != -1)
            {
                CachedState.A = ChkActor;
                CachedState.bWasHidden = ChkActor.bHidden;
                InHiddenActors.AddItem(CachedState);
                ChkActor.SetHidden(TRUE);
            }
        }
    }
}
public function InitializeFilters()
{
    local int idx;
    local MaterialInstanceConstant MIC;
    local MaterialEffect Effect;

    if (FilterMaterialPaths.Length > 0)
    {
        FilterEffects.AddItem(None);
    }
    for (idx = 0; idx < FilterMaterialPaths.Length; idx++)
    {
        MIC = MaterialInstanceConstant(DynamicLoadObject(FilterMaterialPaths[idx], Class'MaterialInstanceConstant'));
        if (MIC != None)
        {
            Effect = new (Self) Class'MaterialEffect';
            Effect.EffectName = Name("PhotoMode_Filter" $ idx);
            Effect.bMergePostUber = TRUE;
            Effect.Material = MIC;
            FilterEffects.AddItem(Effect);
        }
    }
}
public function InitializePostProcessSettings()
{
    PostProcessSettings.bEnableDOF = Class'SFXSFHandler_PhotoMode'.static.GetDefaultBoolOption(3);
    PostProcessSettings.DOF_FocusDistance = Class'SFXSFHandler_PhotoMode'.static.GetDefaultFloatOption(4) * 100.0;
    PostProcessSettings.DOF_FStop = Class'SFXSFHandler_PhotoMode'.static.GetDefaultFloatOption(5);
    PostProcessSettings.DOF_MaxNearBlurAmount = Class'SFXSFHandler_PhotoMode'.static.GetDefaultFloatOption(6) / 100.0;
    PostProcessSettings.DOF_MaxFarBlurAmount = Class'SFXSFHandler_PhotoMode'.static.GetDefaultFloatOption(6) / 100.0;
    PostProcessSettings.DOF_FocusInnerRadius = DefaultPP_DOF_Radius;
    PostProcessSettings.DOF_FalloffExponent = DefaultPP_DOF_FalloffExponent;
    PostProcessSettings.DOF_BlurKernelSize = DefaultPP_DOF_BlurKernelSize;
    PostProcessSettings.DOF_BlurBloomKernelSize = DefaultPP_DOF_BlurBloomKernelSize;
    PostProcessSettings.bEnableBloom = TRUE;
    PostProcessSettings.Bloom_Scale = Class'SFXSFHandler_PhotoMode'.static.GetDefaultFloatOption(11);
    PostProcessSettings.Bloom_Threshold = Class'SFXSFHandler_PhotoMode'.static.GetDefaultFloatOption(12);
    PostProcessSettings.bEnableFilmGrain = Class'SFXSFHandler_PhotoMode'.static.GetDefaultBoolOption(13);
    PostProcessSettings.bEnableVignette = Class'SFXSFHandler_PhotoMode'.static.GetDefaultBoolOption(15);
}
public function ResetFilters()
{
    local int idx;

    for (idx = 0; idx < FilterEffects.Length; idx++)
    {
        if (FilterEffects[idx] != None)
        {
            LocalPlayer(Outer.Player).BioRemovePostProcessEffect(FilterEffects[idx]);
        }
    }
    FilterEffects.Length = 0;
}
public function SetBloomIntensity(float Value)
{
    PostProcessSettings.Bloom_Scale = Value;
}
public function SetBloomThreshold(float Value)
{
    PostProcessSettings.Bloom_Threshold = Value;
}
public function SetBrightness(float Value)
{
    local MaterialInstanceConstant MIC;

    MIC = MaterialInstanceConstant(ME_ScreenEffect.Material);
    if (MIC != None)
    {
        MIC.SetScalarParameterValue('Brightness', Value / 100.0);
    }
}
public function SetCameraFOV(float NewFOV)
{
    PhotoCamFree.TargetFOV = NewFOV;
    PhotoCamOrbit.TargetFOV = NewFOV;
}
public function SetCameraRoll(float NewRoll)
{
    PhotoCamFree.TargetRoll = NewRoll * 182.044449;
    PhotoCamOrbit.TargetRoll = NewRoll * 182.044449;
}
public function SetContrast(float Value)
{
    local MaterialInstanceConstant MIC;

    MIC = MaterialInstanceConstant(ME_ScreenEffect.Material);
    if (MIC != None)
    {
        MIC.SetScalarParameterValue('Contrast', Value / 100.0);
    }
}
public function SetDOFDistance(float Value)
{
    PostProcessSettings.DOF_FocusDistance = Value * 100.0;
}
public function SetDOFEnabled(bool bValue)
{
    PostProcessSettings.bEnableDOF = bValue;
}
public function SetDOFFStop(float Value)
{
    PostProcessSettings.DOF_FStop = Value;
}
public function SetDOFIntensity(float Value)
{
    PostProcessSettings.DOF_MaxNearBlurAmount = Value / 100.0;
    PostProcessSettings.DOF_MaxFarBlurAmount = Value / 100.0;
}
public function SetEffectFilter(int Value)
{
    local int idx;
    local MaterialEffect Effect;

    for (idx = 0; idx < FilterEffects.Length; idx++)
    {
        Effect = FilterEffects[idx];
        if (Effect != None)
        {
            LocalPlayer(Outer.Player).BioRemovePostProcessEffect(Effect);
        }
    }
    LocalPlayer(Outer.Player).BioAddPostProcessEffect(FilterEffects[Value - 1], Self, 1);
}
public function SetEnemiesHidden(bool bValue)
{
    local BioPawn ChkPawn;
    local CachedActorState CachedState;
    local int idx;

    if (bValue != bEnemiesHidden)
    {
        if (bValue)
        {
            CachedEnemies.Length = 0;
            foreach Outer.WorldInfo.AllPawns(Class'BioPawn', ChkPawn)
            {
                if (ChkPawn != Outer.Pawn && !ChkPawn.bNoTick && ChkPawn.IsHostile(Outer.Pawn))
                {
                    CachedState.A = ChkPawn;
                    CachedState.bWasHidden = ChkPawn.bHidden;
                    CachedEnemies.AddItem(CachedState);
                    ChkPawn.SetHidden(TRUE);
                }
            }
            HideAttachedActors(CachedEnemies);
        }
        else
        {
            for (idx = 0; idx < CachedEnemies.Length; idx++)
            {
                CachedEnemies[idx].A.SetHidden(CachedEnemies[idx].bWasHidden);
                CachedEnemies[idx].A.ForceUpdateComponents(TRUE, FALSE);
            }
            CachedEnemies.Length = 0;
        }
        bEnemiesHidden = bValue;
    }
}
public function SetFilmGrainEnabled(bool bValue)
{
    PostProcessSettings.bEnableFilmGrain = bValue;
}
public function SetFilmGrainStrength(float Value)
{
    local LocalPlayer LP;

    LP = LocalPlayer(Outer.Player);
    if (LP != None)
    {
        LP.ViewportClient.FilmGrain_ScaleOverride = TRUE;
        LP.ViewportClient.FilmGrain_Scale = Value / 100.0;
    }
}
public function SetNPCsHidden(bool bValue)
{
    local BioBaseSquad Squad;
    local Actor ChkActor;
    local BioPawn ChkPawn;
    local CachedActorState CachedState;
    local int idx;

    if (bValue != bNPCsHidden)
    {
        Squad = BioPawn(Outer.Pawn).Squad;
        if (Squad != None)
        {
            if (bValue)
            {
                CachedNPCs.Length = 0;
                foreach Outer.WorldInfo.AllActors(Class'Actor', ChkActor, )
                {
                    ChkPawn = BioPawn(ChkActor);
                    if (HasCharacterMesh(ChkActor) && (ChkPawn == None || ChkPawn != Outer.Pawn && !ChkPawn.bNoTick && !ChkPawn.IsHostile(Outer.Pawn) && Squad.Members.Find(ChkPawn) == -1))
                    {
                        CachedState.A = ChkActor;
                        CachedState.bWasHidden = ChkActor.bHidden;
                        CachedNPCs.AddItem(CachedState);
                        ChkActor.SetHidden(TRUE);
                    }
                }
                HideAttachedActors(CachedNPCs);
            }
            else
            {
                for (idx = 0; idx < CachedNPCs.Length; idx++)
                {
                    CachedNPCs[idx].A.SetHidden(CachedNPCs[idx].bWasHidden);
                    CachedNPCs[idx].A.ForceUpdateComponents(TRUE, FALSE);
                }
                CachedNPCs.Length = 0;
            }
        }
        bNPCsHidden = bValue;
    }
}
public function SetOrbitCam(bool bValue)
{
    // MILAN CHANGE - Mgamerz - 2026-10-16
    if (bMPSpectatorPhoto)
    {
        SetMPPhotoSubject(MPPhotoSubject, bValue);
        return;
    }
    // END MILAN CHANGE
    if (bValue != bUseOrbitCam)
    {
        if (bValue)
        {
            PhotoCamOrbit.CurrentRoll = PhotoCamFree.CurrentRoll;
            PhotoCamOrbit.CurrentFOV = PhotoCamFree.CurrentFOV;
            Outer.DisablePhotoModeCameraCollision();
        }
        else
        {
            PhotoCamFree.CurrentRoll = PhotoCamOrbit.CurrentRoll;
            PhotoCamFree.CurrentFOV = PhotoCamOrbit.CurrentFOV;
            Outer.EnablePhotoModeCameraCollision();
        }
        bUseOrbitCam = bValue;
    }
}
public function SetPartyHidden(bool bValue)
{
    local BioBaseSquad Squad;
    local BioPawn SquadMate;
    local CachedActorState CachedState;
    local int idx;
    local int SquadIdx;

    if (bValue != bPartyHidden)
    {
        Squad = BioPawn(Outer.Pawn).Squad;
        if (Squad != None)
        {
            if (bValue)
            {
                CachedParty.Length = 0;
                for (SquadIdx = 0; SquadIdx < Squad.Members.Length; SquadIdx++)
                {
                    SquadMate = BioPawn(Squad.Members[SquadIdx]);
                    if (SquadMate != None && SquadMate != Outer.Pawn)
                    {
                        CachedState.A = SquadMate;
                        CachedState.bWasHidden = SquadMate.bHidden;
                        CachedParty.AddItem(CachedState);
                        SquadMate.SetHidden(TRUE);
                    }
                }
                HideAttachedActors(CachedParty);
            }
            else
            {
                for (idx = 0; idx < CachedParty.Length; idx++)
                {
                    CachedParty[idx].A.SetHidden(CachedParty[idx].bWasHidden);
                    CachedParty[idx].A.ForceUpdateComponents(TRUE, FALSE);
                }
                CachedParty.Length = 0;
            }
        }
        bPartyHidden = bValue;
    }
}
public function SetPlayerHidden(bool bValue)
{
    local CachedActorState CachedState;
    local int idx;

    if (BioPawn(Outer.Pawn) != None && bValue != bPlayerHidden)
    {
        if (bValue)
        {
            CachedPlayer.Length = 0;
            CachedState.A = Outer.Pawn;
            CachedState.bWasHidden = Outer.Pawn.bHidden;
            CachedPlayer.AddItem(CachedState);
            Outer.Pawn.SetHidden(TRUE);
            HideAttachedActors(CachedPlayer);
        }
        else
        {
            for (idx = 0; idx < CachedPlayer.Length; idx++)
            {
                CachedPlayer[idx].A.SetHidden(CachedPlayer[idx].bWasHidden);
                CachedPlayer[idx].A.ForceUpdateComponents(TRUE, FALSE);
            }
            CachedPlayer.Length = 0;
        }
        bPlayerHidden = bValue;
    }
}
public function SetSaturation(float Value)
{
    local MaterialInstanceConstant MIC;

    MIC = MaterialInstanceConstant(ME_ScreenEffect.Material);
    if (MIC != None)
    {
        MIC.SetScalarParameterValue('Saturation', Value / 100.0);
    }
}
public function SetVehicleHidden(bool bValue);

public function SetVignetteEnabled(bool bValue)
{
    PostProcessSettings.bEnableVignette = bValue;
}
public exec function TakePhoto()
{
    // MILAN CHANGE - Mgamerz - 2026-10-16
    // Space/X entered this mode; do not take a photo from that same press.
    if (bMPSpectatorPhoto && Outer.WorldInfo.TimeSeconds - MPPhotoEntryTime < 0.35)
    {
        return;
    }
    // END MILAN CHANGE
    if (!Class'WorldInfo'.static.IsConsoleBuild())
    {
        Outer.PlaySound(TakePhotoSound);
        Outer.ConsoleCommand("screenshot");
    }
}
public exec function ToggleOptions()
{
    local SFXSFHandler_PhotoMode PhotoModeHandler;

    PhotoModeHandler = Class'SFXGUIInteraction'.static.GetInstance().GetPhotoModeHandler(Outer);
    if (PhotoModeHandler != None)
    {
        PhotoModeHandler.ToggleOptions();
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
// MILAN CHANGE - Mgamerz - 2026-10-16
// The spectator's camera is local data: never move a viewed pawn or its controller.
public function ActivateMPPhoto()
{
    local LocalPlayer LP;
    local BioPlayerInput Input;

    bIsActive = TRUE;
    LP = LocalPlayer(Outer.Player);
    MPPhotoOldCameraStyle = Outer.PlayerCamera.CameraStyle;
    bMPPhotoOldCameraUnlocked = Outer.bPhotoModeCameraUnlocked;
    MPPhotoPOV = Outer.PlayerCamera.CameraCache.POV;
    MPPhotoTetherOrigin = MPPhotoPOV.Location;
    MPPhotoRotation = MPPhotoPOV.Rotation;
    MPPhotoRotation.Roll = 0;
    MPPhotoDesiredRotation = MPPhotoRotation;
    MPPhotoEntryTime = Outer.WorldInfo.TimeSeconds;
    bMPPhotoLoggedDispatch = FALSE;
    bMPPhotoLoggedCamera = FALSE;
    bMPPhotoLoggedUIInput = FALSE;
    bMPPhotoLoggedAxes = FALSE;
    bMPPhotoStateExiting = FALSE;
    MPPhotoVelocity = vect(0,0,0);
    MPPhotoBlendRemaining = 0.0;
    MPPhotoFollowDistance = 300.0;
    MPPhotoFollowHeight = 50.0;
    bMPPhotoFollow = FALSE;
    Outer.PlayerCamera.CameraStyle = 'Default';
    Outer.bPhotoModeCameraUnlocked = FALSE;
    bOldIgnoreMoveInput = Outer.bIgnoreMoveInput;
    bOldIgnoreLookInput = Outer.bIgnoreLookInput;
    Outer.bIgnoreMoveInput = 0;
    Outer.bIgnoreLookInput = 0;
    Outer.GameModeManager2.ResetKeyPresses();
    // These static binds take precedence over game-mode aliases. Empty commands suppress
    // the mode's axes, so bind the camera axes explicitly and restore the live arrays on exit.
    Input = BioPlayerInput(Outer.PlayerInput);
    if (Input != None)
    {
        MPPhotoOldPCBinds = Input.StaticPCBinds;
        MPPhotoOldConsoleBinds = Input.StaticConsoleBinds;
        Outer.GameModeManager2.Helper_SetStaticPCBinding('SpaceBar', "");
        Outer.GameModeManager2.Helper_SetStaticPCBinding('W', "Axis aBaseY Speed=1.0");
        Outer.GameModeManager2.Helper_SetStaticPCBinding('S', "Axis aBaseY Speed=-1.0");
        Outer.GameModeManager2.Helper_SetStaticPCBinding('A', "Axis aStrafe Speed=-1.0");
        Outer.GameModeManager2.Helper_SetStaticPCBinding('D', "Axis aStrafe Speed=1.0");
        Outer.GameModeManager2.Helper_SetStaticPCBinding('E', "MPPhotoCyclePlayer 1 | Axis aUp Speed=1.0");
        Outer.GameModeManager2.Helper_SetStaticPCBinding('Q', "MPPhotoCyclePlayer -1 | Axis aUp Speed=-1.0");
        Outer.GameModeManager2.Helper_SetStaticPCBinding('MouseX', "Count bXAxis | Axis aMouseX");
        Outer.GameModeManager2.Helper_SetStaticPCBinding('MouseY', "Count bYAxis | Axis aMouseY");
        Outer.GameModeManager2.Helper_SetStaticPCBinding('RightMouseButton', "EnableCamera | OnRelease DisableCamera");
        Outer.GameModeManager2.Helper_SetStaticConsoleBinding('XboxTypeS_LeftX', "Axis aStrafe Speed=1.0 DeadZone=0.1");
        Outer.GameModeManager2.Helper_SetStaticConsoleBinding('XboxTypeS_LeftY', "Axis aBaseY Speed=1.0 DeadZone=0.1");
        Outer.GameModeManager2.Helper_SetStaticConsoleBinding('XboxTypeS_RightX', "Axis aTurn Speed=1.0 DeadZone=0.2");
        Outer.GameModeManager2.Helper_SetStaticConsoleBinding('XboxTypeS_RightY', "Axis aLookUp Speed=1.0 DeadZone=0.2");
        Outer.GameModeManager2.Helper_SetStaticConsoleBinding('XboxTypeS_RightTrigger', "Axis aUp Speed=1.0 DeadZone=0.2");
        Outer.GameModeManager2.Helper_SetStaticConsoleBinding('XboxTypeS_LeftTrigger', "Axis aUp Speed=-1.0 DeadZone=0.2");
        // Route D-pad navigation to the native photo handler instead of gameplay/squad binds.
        Outer.GameModeManager2.Helper_SetStaticConsoleBinding('XboxTypeS_DPad_Up', "Repeat GuiKey BIOGUI_EVENT_CONTROL_UP | OnRelease GuiKey BIOGUI_EVENT_CONTROL_UP_RELEASE");
        Outer.GameModeManager2.Helper_SetStaticConsoleBinding('XboxTypeS_DPad_Down', "Repeat GuiKey BIOGUI_EVENT_CONTROL_DOWN | OnRelease GuiKey BIOGUI_EVENT_CONTROL_DOWN_RELEASE");
        Outer.GameModeManager2.Helper_SetStaticConsoleBinding('XboxTypeS_DPad_Left', "Repeat GuiKey BIOGUI_EVENT_CONTROL_LEFT | OnRelease GuiKey BIOGUI_EVENT_CONTROL_LEFT_RELEASE");
        Outer.GameModeManager2.Helper_SetStaticConsoleBinding('XboxTypeS_DPad_Right', "Repeat GuiKey BIOGUI_EVENT_CONTROL_RIGHT | OnRelease GuiKey BIOGUI_EVENT_CONTROL_RIGHT_RELEASE");
    }
    Outer.PushState('MilanPhotoMode');
    PhotoCamFree.ExternalModifyPPSettings = ModifyPostProcessSettings;
    PhotoCamFree.InitFromMode(Class'SFXSFHandler_PhotoMode'.static.GetDefaultFloatOption(2));
    bMPPhotoOldCollisionEnabled = PhotoCamFree.bCollisionEnabled;
    // Collision is handled by local world sweeps, not the watched pawn's native camera hook.
    PhotoCamFree.bCollisionEnabled = FALSE;
    PhotoCamOrbit.InitFromMode(PhotoCamFree.CurrentFOV);
    bUseOrbitCam = FALSE;
    PostProcessSettings = Outer.WorldInfo.DefaultPostProcessSettings;
    bOldAllowFilmGrain = IsSystemFilmgrainEnabled();
    SetSystemFilmgrainEnabled(TRUE);
    bMPPhotoOldGrainOverride = LP.ViewportClient.FilmGrain_ScaleOverride;
    MPPhotoOldGrainScale = LP.ViewportClient.FilmGrain_Scale;
    LP.BioAddPostProcessEffect(ME_ScreenEffect, Self, 1);
    InitializePostProcessSettings();
    InitializeFilters();
    SetFilmGrainStrength(Class'SFXSFHandler_PhotoMode'.static.GetDefaultFloatOption(14));
    SetSaturation(Class'SFXSFHandler_PhotoMode'.static.GetDefaultFloatOption(7));
    SetBrightness(Class'SFXSFHandler_PhotoMode'.static.GetDefaultFloatOption(8));
    SetContrast(Class'SFXSFHandler_PhotoMode'.static.GetDefaultFloatOption(9));
    ButtonPressTimes.Length = 53;
    SetTimer(0.25, TRUE, 'ValidateMPPhoto');
    LogInternal("MilanPhoto: entered local, unpaused spectator photo mode");
}

public function DeactivateMPPhoto()
{
    local LocalPlayer LP;
    local BioPlayerInput Input;
    local bool bReturnToSpectator;

    // MILAN CHANGE - Mgamerz - 2026-10-17
    // Revive can already have reset movement and entered PlayerWalking. Do not put the
    // old spectator/death input locks or camera style back over the resumed game state.
    bReturnToSpectator = !bMPPhotoStateExiting && Outer.IsInState('MilanPhotoMode')
        && Outer.GameModeManager2.IsActive(20);
    // END MILAN CHANGE
    // Disable first: UI removal and mode changes can both request cleanup.
    bIsActive = FALSE;
    bMPSpectatorPhoto = FALSE;
    ClearTimer('ValidateMPPhoto');
    LP = LocalPlayer(Outer.Player);
    if (LP != None)
    {
        ResetFilters();
        LP.BioRemovePostProcessEffect(ME_ScreenEffect);
        if (LP.ViewportClient != None)
        {
            LP.ViewportClient.FilmGrain_ScaleOverride = bMPPhotoOldGrainOverride;
            LP.ViewportClient.FilmGrain_Scale = MPPhotoOldGrainScale;
        }
    }
    SetSystemFilmgrainEnabled(bOldAllowFilmGrain);
    PhotoCamFree.ExternalModifyPPSettings = None;
    PhotoCamFree.bCollisionEnabled = bMPPhotoOldCollisionEnabled;
    PhotoCamFree.ResetRoll();
    PhotoCamOrbit.ResetRoll();
    if (bReturnToSpectator && Outer.PlayerCamera != None)
    {
        Outer.PlayerCamera.CameraStyle = MPPhotoOldCameraStyle;
    }
    // MILAN CHANGE - Mgamerz - 2026-10-17
    Outer.bPhotoModeCameraUnlocked = bReturnToSpectator && bMPPhotoOldCameraUnlocked;
    if (bReturnToSpectator)
    {
        // A different mode may have installed its own lock while photo mode was open.
        if (Outer.bIgnoreMoveInput == 0)
        {
            Outer.bIgnoreMoveInput = bOldIgnoreMoveInput;
        }
        if (Outer.bIgnoreLookInput == 0)
        {
            Outer.bIgnoreLookInput = bOldIgnoreLookInput;
        }
    }
    // END MILAN CHANGE
    Input = BioPlayerInput(Outer.PlayerInput);
    if (Input != None)
    {
        Input.StaticPCBinds = MPPhotoOldPCBinds;
        Input.StaticConsoleBinds = MPPhotoOldConsoleBinds;
    }
    MPPhotoOldPCBinds.Length = 0;
    MPPhotoOldConsoleBinds.Length = 0;
    if (!bMPPhotoStateExiting && Outer.IsInState('MilanPhotoMode'))
    {
        Outer.PopState();
    }
    MPPhotoSubject = None;
    MPPhotoVelocity = vect(0,0,0);
    bMPPhotoFollow = FALSE;
    // MILAN CHANGE - Mgamerz - 2026-10-17
    bMPPhotoStateExiting = FALSE;
    LogInternal("MilanPhoto: removed local effects/input; return to spectator" @ bReturnToSpectator @ "state" @ Outer.GetStateName() @ "ignore move/look" @ Outer.bIgnoreMoveInput @ Outer.bIgnoreLookInput);
    // END MILAN CHANGE
}

// MILAN CHANGE - Mgamerz - 2026-10-17
// EndState/PoppedState may be called from inside a revive GotoState. Close immediately,
// without popping the state stack again or restoring the old spectator input locks.
public final function MPPhotoControllerStateEnded()
{
    local SFXGUIInteraction UI;

    if (!bMPSpectatorPhoto || !bIsActive)
    {
        return;
    }
    bMPPhotoStateExiting = TRUE;
    UI = Class'SFXGUIInteraction'.static.GetInstance();
    if (UI != None)
    {
        UI.HidePhotoMode(Outer);
    }
    if (bMPSpectatorPhoto && bIsActive)
    {
        Outer.GameModeManager2.DisableMode(14);
    }
}
// END MILAN CHANGE

public function ValidateMPPhoto()
{
    if (!bMPSpectatorPhoto || !bIsActive)
    {
        return;
    }
    if (!bMPPhotoLoggedDispatch)
    {
        bMPPhotoLoggedDispatch = TRUE;
        LogInternal("MilanPhoto: dispatch mode" @ Outer.GameModeManager2.CurrentMode @ "state" @ Outer.GetStateName() @ "camera" @ SFXPlayerCamera(Outer.PlayerCamera).CurrentCameraMode @ "photo camera outer" @ PhotoCamFree.Outer @ "expected" @ Self @ "gamepad" @ Outer.PlayerInput.bUsingGamepad);
    }
    if (!Outer.GameModeManager2.IsActive(20) || !Outer.IsInState('MilanPhotoMode') || Outer.bDeleteMe || Outer.WorldInfo.GRI == None || Outer.WorldInfo.GRI.bMatchIsOver || Outer.WorldInfo.TimeSeconds - MPPhotoEntryTime > 10.0 && Class'SFXGUIInteraction'.static.GetInstance().GetPhotoModeHandler(Outer) == None)
    {
        Class'SFXGUIInteraction'.static.GetInstance().HidePhotoMode(Outer);
    }
}

public function SetMPPhotoSubject(Pawn Subject, bool bFollow)
{
    if (Subject != MPPhotoSubject || bFollow != bMPPhotoFollow)
    {
        MPPhotoBlendRemaining = 0.35;
        MPPhotoVelocity = vect(0,0,0);
        MPPhotoDesiredRotation = MPPhotoRotation;
    }
    MPPhotoSubject = Subject;
    bMPPhotoFollow = bFollow && Subject != None && !Subject.bDeleteMe;
}

public function Vector CollideMPPhoto(Vector Start, Vector Destination)
{
    local Vector HitLocation;
    local Vector HitNormal;
    local Actor Hit;

    // MILAN CHANGE - Mgamerz - 2026-10-17
    if (bMPPhotoNoCollision)
    {
        return Destination;
    }
    // END MILAN CHANGE
    // World geometry and blocking volumes, without colliding with the photographed players.
    Hit = Outer.Trace(HitLocation, HitNormal, Destination, Start, FALSE, vect(12,12,12));
    if (Hit != None)
    {
        return HitLocation + HitNormal * 2.0;
    }
    return Destination;
}

// Consume input during PlayerController.PlayerMove, immediately after PlayerInput.PlayerInput.
// Camera Tick only presents that state; it must not consume mouse deltas a second time.
public function ProcessMPPhotoInput(float DeltaTime)
{
    local PlayerInput Input;
    local Vector X;
    local Vector Y;
    local Vector Z;
    local Vector Movement;
    local Rotator R;
    local float MoveScale;
    local bool bCameraInput;
    local Rotator TurnDelta;
    local float TurnAlpha;
    local float SmoothingTime;
    local SFXSFHandler_PhotoMode PhotoHandler;

    Input = Outer.PlayerInput;
    if (Input == None || !bIsActive || !bMPSpectatorPhoto)
    {
        return;
    }
    DeltaTime = FClamp(DeltaTime, 0.0, 0.1);
    bCameraInput = Input.bUsingGamepad || Outer.bPhotoModeCameraUnlocked;
    // A higher-priority GUI (disconnect dialog, etc.) must retain its input.
    bCameraInput = bCameraInput && Outer.GameModeManager2.CurrentMode == 14;
    if (!bMPPhotoLoggedAxes && (Input.aForward != 0.0 || Input.aStrafe != 0.0 || Input.aUp != 0.0 || Input.aTurn != 0.0 || Input.aLookUp != 0.0))
    {
        bMPPhotoLoggedAxes = TRUE;
        LogInternal("MilanPhoto: controller input pass axes" @ Input.aForward @ Input.aStrafe @ Input.aUp @ Input.aTurn @ Input.aLookUp @ "capture" @ bCameraInput @ "mode" @ Outer.GameModeManager2.CurrentMode);
    }
    // MILAN CHANGE - Mgamerz - 2026-10-17
    SmoothingTime = GetMPPhotoSmoothingTime();
    R = !bMPPhotoFollow && SmoothingTime > 0.0 ? MPPhotoDesiredRotation : MPPhotoRotation;
    if (bCameraInput)
    {
        R.Yaw += int(Input.aTurn);
        R.Pitch = Clamp(Normalize(R).Pitch + int(Input.aLookUp), -16000, 16000);
    }
    if (Outer.GameModeManager2.CurrentMode != 14) R = MPPhotoRotation;
    R.Roll = 0;
    MPPhotoDesiredRotation = R;
    if (!bMPPhotoFollow && SmoothingTime > 0.0 && Outer.GameModeManager2.CurrentMode == 14)
    {
        // Integrate input into a target first, then ease the shortest angular difference.
        // This preserves mouse deltas and gives stick starts/stops a gentle acceleration/tail.
        TurnDelta = Normalize(R - MPPhotoRotation);
        TurnAlpha = 1.0 - Exp(-DeltaTime / SmoothingTime);
        MPPhotoRotation.Yaw += int(float(TurnDelta.Yaw) * TurnAlpha);
        MPPhotoRotation.Pitch += int(float(TurnDelta.Pitch) * TurnAlpha);
        if (Abs(TurnDelta.Yaw) < 8) MPPhotoRotation.Yaw = R.Yaw;
        if (Abs(TurnDelta.Pitch) < 8) MPPhotoRotation.Pitch = R.Pitch;
        MPPhotoRotation.Roll = 0;
    }
    else
    {
        MPPhotoRotation = R;
    }
    if (Outer.GameModeManager2.CurrentMode != 14) MPPhotoDesiredRotation = MPPhotoRotation;
    GetAxes(MPPhotoRotation, X, Y, Z);
    // END MILAN CHANGE
    if (bMPPhotoFollow)
    {
        if (bCameraInput)
        {
            MPPhotoFollowDistance = FClamp(MPPhotoFollowDistance - FClamp(Input.aForward, -1.0, 1.0) * 300.0 * DeltaTime, 40.0, 1500.0);
            // MILAN CHANGE - Mgamerz - 2026-10-17
            // Follow: the left stick only changes distance; the right stick handles orbit.
            // Retain the keyboard's existing A/D orbit controls.
            if (!Input.bUsingGamepad)
            {
                MPPhotoRotation.Yaw += int(FClamp(Input.aStrafe, -1.0, 1.0) * 12000.0 * DeltaTime);
            }
            // END MILAN CHANGE
            // Hidden Follow uses Q/E for subjects; controller triggers still adjust height.
            PhotoHandler = Class'SFXGUIInteraction'.static.GetInstance().GetPhotoModeHandler(Outer);
            if (Input.bUsingGamepad || PhotoHandler == None || !PhotoHandler.bOptionsHidden)
            {
                MPPhotoFollowHeight = FClamp(MPPhotoFollowHeight + FClamp(Input.aUp, -1.0, 1.0) * 300.0 * DeltaTime, -100.0, 500.0);
            }
        }
    }
    else
    {
        if (bCameraInput)
        {
            Movement = Input.aForward * X + Input.aStrafe * Y + Input.aUp * vect(0,0,1);
            MoveScale = FMin(VSize(Movement), 1.0);
            Movement = Normal(Movement) * MoveScale * Outer.PhotoModeCameraSpeed * GetMPPhotoSpeedScale();
        }
        MPPhotoVelocity = VLerp(MPPhotoVelocity, Movement, FMin(DeltaTime * 8.0, 1.0));
    }
}

// MILAN CHANGE - Mgamerz - 2026-10-17
public final function float GetMPPhotoSpeedScale()
{
    return 2.0 ** float(Clamp(MPPhotoSpeedIndex, 0, 6) - 2);
}

public final function float GetMPPhotoSmoothingTime()
{
    switch (MPPhotoSmoothingIndex)
    {
        case 1: return 0.08;
        case 2: return 0.16;
        case 3: return 0.32;
    }
    return 0.0;
}

public final exec function MPPhotoCyclePlayer(int Direction)
{
    local SFXSFHandler_PhotoMode PhotoHandler;
    local ASParams Param;
    local array<ASParams> Params;

    if (!bMPSpectatorPhoto || !bIsActive || !bMPPhotoFollow || Outer.GameModeManager2.CurrentMode != 14)
    {
        return;
    }
    PhotoHandler = Class'SFXGUIInteraction'.static.GetInstance().GetPhotoModeHandler(Outer);
    if (PhotoHandler == None || !PhotoHandler.bOptionsHidden || PhotoHandler.oPanel == None)
    {
        return;
    }
    Param.Type = ASParamTypes.ASParam_Float;
    Param.fVar = float(Direction);
    Params.AddItem(Param);
    PhotoHandler.oPanel.InvokeMethodArgs("PhotoMode.cycleHiddenPlayer", Params);
}
// END MILAN CHANGE

public function UpdateMPPhoto(float DeltaTime)
{
    local Vector Destination;
    local Vector Hook;
    local float Alpha;

    if (!bIsActive)
    {
        return;
    }
    if (!bMPPhotoLoggedCamera)
    {
        bMPPhotoLoggedCamera = TRUE;
        LogInternal("MilanPhoto: local camera tick" @ Self @ "owner" @ Outer @ "mode" @ Outer.GameModeManager2.CurrentMode);
    }
    DeltaTime = FClamp(DeltaTime, 0.0, 0.1);
    if (MPPhotoSubject == None || MPPhotoSubject.bDeleteMe)
    {
        bMPPhotoFollow = FALSE;
    }
    else
    {
        // Retain the last valid anchor if the subject disappears before the roster refresh.
        MPPhotoTetherOrigin = MPPhotoSubject.Location;
    }
    if (bMPPhotoFollow)
    {
        Hook = MPPhotoSubject.Location + vect(0,0,1) * MPPhotoFollowHeight;
        Destination = CollideMPPhoto(Hook, Hook - Vector(MPPhotoRotation) * MPPhotoFollowDistance);
    }
    else
    {
        Destination = MPPhotoPOV.Location + MPPhotoVelocity * DeltaTime;
    }
    if (MPPhotoBlendRemaining > 0.0)
    {
        Alpha = FMin(DeltaTime / MPPhotoBlendRemaining, 1.0);
        Destination = VLerp(MPPhotoPOV.Location, Destination, Alpha);
        MPPhotoBlendRemaining = FMax(MPPhotoBlendRemaining - DeltaTime, 0.0);
    }
    if (bMPPhotoFollow)
    {
        // The boom sweep is relative to the new subject. Sweeping from the previous player's
        // position would leave the camera stuck behind a wall when switching rooms.
        MPPhotoPOV.Location = Destination;
    }
    else
    {
        // MILAN CHANGE - Mgamerz - 2026-10-16
        // Use the same configured tether as stock free photo mode, without requiring Outer.Pawn.
        if (VSize(Destination - MPPhotoTetherOrigin) > Outer.PhotoModeTetherDistance)
        {
            Destination = MPPhotoTetherOrigin + Normal(Destination - MPPhotoTetherOrigin) * Outer.PhotoModeTetherDistance;
        }
        // END MILAN CHANGE
        MPPhotoPOV.Location = CollideMPPhoto(MPPhotoPOV.Location, Destination);
    }
    MPPhotoPOV.Rotation = MPPhotoRotation;
    PhotoCamFree.m_pov = MPPhotoPOV;
    PhotoCamFree.UpdateRollAndFOV(DeltaTime);
    MPPhotoPOV = PhotoCamFree.m_pov;
}
// END MILAN CHANGE

defaultproperties
{
    // MILAN CHANGE - Mgamerz - 2026-10-17
    MPPhotoSpeedIndex = 3
    // END MILAN CHANGE
    Begin Object Class=MaterialEffect Name=PPEffect0
        Material = MaterialInstanceConstant'BIOG_PhotoMode.PhotoMode_Effects_INST'
        EffectName = 'PhotoMode'
        bMergePostUber = TRUE
    End Object
    Begin Object Class=SFXCameraMode_PhotoFree Name=PhotoCam1
    End Object
    Begin Object Class=SFXCameraMode_PhotoOrbit Name=PhotoCam0
    End Object
    Begin Object Class=SFXCameraTransition_GalaxyMap Name=InstantTransition0
    End Object
    PostProcessSettings = {
                           ColorGradingLUT = {
                                              LUTTextures = (),
                                              LUTWeights = ()
                                             },
                           RimShader_Color = {R = 0.47044, G = 0.585973024, B = 0.827726007, A = 1.0},
                           DOF_FocusPosition = {X = 0.0, Y = 0.0, Z = 0.0},
                           Scene_HighLights = {X = 1.0, Y = 1.0, Z = 1.0},
                           Scene_MidTones = {X = 1.0, Y = 1.0, Z = 1.0},
                           Scene_Shadows = {X = 0.0, Y = 0.0, Z = 0.0},
                           ColorGrading_LookupTable = None,
                           Bloom_Scale = 1.0,
                           Bloom_Threshold = 1.0,
                           Bloom_Tint = {B = 255, G = 255, R = 255, A = 0},
                           Bloom_ScreenBlendThreshold = 10.0,
                           Bloom_InterpolationDuration = 1.0,
                           DOF_FalloffExponent = 4.0,
                           DOF_FStop = 10.0,
                           DOF_BlurKernelSize = 8.0,
                           DOF_BlurBloomKernelSize = 8.0,
                           DOF_MaxNearBlurAmount = 0.100000001,
                           DOF_MaxFarBlurAmount = 0.300000012,
                           DOF_ModulateBlurColor = {B = 255, G = 255, R = 255, A = 255},
                           DOF_FocusInnerRadius = 2000.0,
                           DOF_FocusDistance = 0.0,
                           DOF_InterpolationDuration = 1.0,
                           MotionBlur_MaxVelocity = 1.0,
                           MotionBlur_Amount = 0.5,
                           MotionBlur_CameraRotationThreshold = 45.0,
                           MotionBlur_CameraTranslationThreshold = 10000.0,
                           MotionBlur_InterpolationDuration = 1.0,
                           Scene_Desaturation = 0.0,
                           Scene_InterpolationDuration = 1.0,
                           RimShader_InterpolationDuration = 1.0,
                           PP_DesaturationMultiplier = 0.0,
                           PP_HighlightsMultiplier = 1.0,
                           PP_MidTonesMultiplier = 1.0,
                           PP_ShadowsMultiplier = 0.0,
                           bOverride_EnableBloom = TRUE,
                           bOverride_EnableDOF = TRUE,
                           bOverride_EnableMotionBlur = TRUE,
                           bOverride_EnableSceneEffect = TRUE,
                           bOverride_AllowAmbientOcclusion = TRUE,
                           bOverride_OverrideRimShaderColor = TRUE,
                           bOverride_Bloom_Scale = TRUE,
                           bOverride_Bloom_Threshold = TRUE,
                           bOverride_Bloom_Tint = TRUE,
                           bOverride_Bloom_ScreenBlendThreshold = TRUE,
                           bOverride_Bloom_InterpolationDuration = TRUE,
                           bOverride_DOF_FalloffExponent = TRUE,
                           bOverride_DOF_FStop = TRUE,
                           bOverride_DOF_BlurKernelSize = TRUE,
                           bOverride_DOF_BlurBloomKernelSize = TRUE,
                           bOverride_DOF_MaxNearBlurAmount = TRUE,
                           bOverride_DOF_MaxFarBlurAmount = TRUE,
                           bOverride_DOF_ModulateBlurColor = TRUE,
                           bOverride_DOF_FocusType = TRUE,
                           bOverride_DOF_FocusInnerRadius = TRUE,
                           bOverride_DOF_FocusDistance = TRUE,
                           bOverride_DOF_FocusPosition = TRUE,
                           bOverride_DOF_InterpolationDuration = TRUE,
                           bOverride_MotionBlur_MaxVelocity = TRUE,
                           bOverride_MotionBlur_Amount = TRUE,
                           bOverride_MotionBlur_FullMotionBlur = TRUE,
                           bOverride_MotionBlur_CameraRotationThreshold = TRUE,
                           bOverride_MotionBlur_CameraTranslationThreshold = TRUE,
                           bOverride_MotionBlur_InterpolationDuration = TRUE,
                           bOverride_Scene_Desaturation = TRUE,
                           bOverride_Scene_HighLights = TRUE,
                           bOverride_Scene_MidTones = TRUE,
                           bOverride_Scene_Shadows = TRUE,
                           bOverride_Scene_InterpolationDuration = TRUE,
                           bOverride_RimShader_Color = TRUE,
                           bOverride_RimShader_InterpolationDuration = TRUE,
                           bEnableBloom = TRUE,
                           bEnableDOF = FALSE,
                           bEnableMotionBlur = TRUE,
                           bEnableSceneEffect = TRUE,
                           bAllowAmbientOcclusion = TRUE,
                           bOverrideRimShaderColor = FALSE,
                           bOverride_EnableFilmic = TRUE,
                           bEnableFilmic = TRUE,
                           bOverride_EnableVignette = TRUE,
                           bEnableVignette = TRUE,
                           bOverride_EnableFilmGrain = TRUE,
                           bEnableFilmGrain = TRUE,
                           MotionBlur_FullMotionBlur = TRUE,
                           DOF_FocusType = EFocusType.FOCUS_Distance
                          }
    ButtonCooldownCurve = {
                           Points = ({InVal = 0.0, OutVal = 0.349999994, ArriveTangent = 0.0, LeaveTangent = 0.0, InterpMode = EInterpCurveMode.CIM_Linear},
                                     {InVal = 0.349999994, OutVal = 0.100000001, ArriveTangent = 0.0, LeaveTangent = 0.0, InterpMode = EInterpCurveMode.CIM_Linear},
                                     {InVal = 1.0, OutVal = 0.100000001, ArriveTangent = 0.0, LeaveTangent = 0.0, InterpMode = EInterpCurveMode.CIM_Linear},
                                     {InVal = 4.0, OutVal = 0.0120000001, ArriveTangent = 0.0, LeaveTangent = 0.0, InterpMode = EInterpCurveMode.CIM_Linear}
                                    ),
                           InterpMethod = EInterpMethodType.IMT_UseFixedTangentEvalAndNewAutoTangents
                          }
    CharacterMeshFilter = ("ALN_TRO",
                           "AMB_KEE",
                           "ASA_ARM",
                           "ATA_Lav",
                           "BIOG_RPR_MTR",
                           "CBT_MAW",
                           "CBT_MDG",
                           "CBT_MHV",
                           "CBT_OCU",
                           "CBT_PRA",
                           "CBT_SPD",
                           "CBT_VAR",
                           "COL_ARM",
                           "CRB_ATA",
                           "DRL_ARM",
                           "GTH_ARM",
                           "GTH_FLM",
                           "GTH_RKT",
                           "GTH_STP",
                           "GTH_TRO",
                           "HMF_ARM",
                           "HMM_ARM",
                           "KRO_ARM",
                           "MCH_HEX",
                           "MCH_LGT",
                           "NCA_EDI",
                           "NCA_ELC",
                           "NCA_FAC_VOL",
                           "NCA_HAN",
                           "NCA_VOL",
                           "PRN_ARM",
                           "QEN_NKD",
                           "QRN_ARM",
                           "QRN_FAC_ARM",
                           "RBT_DRO",
                           "RBT_HDR",
                           "RBT_ROB",
                           "RBT_TNK",
                           "RPR_CAN",
                           "RPR_HRV",
                           "RPR_HSK",
                           "RPR_MAR",
                           "RPR_SCR",
                           "RPR_SWR",
                           "SAL_ARM",
                           "SAL_ARM",
                           "SCI_ARM",
                           "TUF_ARM",
                           "TUR_ARM",
                           "VOR_ARM",
                           "YAH_NKD",
                           "YAH_SBR",
                           "CRD_",
                           "LC_ASA",
                           "LC_HMF",
                           "LC_HMM",
                           "LC_QRN",
                           "LC_KRO",
                           "LC_PRN",
                           "LC_TUR"
                          )
    TakePhotoSound = WwiseEvent'Wwise_Generic_GUI.Play_WeaponGUIModAttachLaser'
    PhotoCamFree = PhotoCam1
    PhotoCamOrbit = PhotoCam0
    InstantTransition = InstantTransition0
    ME_ScreenEffect = PPEffect0
    CamTransitionTime = 1.0
    DefaultPP_DOF_Radius = 0.00999999978
    DefaultPP_DOF_FalloffExponent = 5.0
    DefaultPP_DOF_BlurKernelSize = 5.0
    DefaultPP_DOF_BlurBloomKernelSize = 5.0
    Bindings = ({
                 Command = "Console_LookX",
                 Name = 'XboxTypeS_RightX',
                 Control = FALSE,
                 Shift = FALSE,
                 Alt = FALSE,
                 bIgnoreCtrl = FALSE,
                 bIgnoreShift = FALSE,
                 bIgnoreAlt = FALSE
                },
                {
                 Command = "Console_LookY",
                 Name = 'XboxTypeS_RightY',
                 Control = FALSE,
                 Shift = FALSE,
                 Alt = FALSE,
                 bIgnoreCtrl = FALSE,
                 bIgnoreShift = FALSE,
                 bIgnoreAlt = FALSE
                },
                {
                 Command = "Console_PhotoStrafe",
                 Name = 'XboxTypeS_LeftX',
                 Control = FALSE,
                 Shift = FALSE,
                 Alt = FALSE,
                 bIgnoreCtrl = FALSE,
                 bIgnoreShift = FALSE,
                 bIgnoreAlt = FALSE
                },
                {
                 Command = "Console_PhotoMovement",
                 Name = 'XboxTypeS_LeftY',
                 Control = FALSE,
                 Shift = FALSE,
                 Alt = FALSE,
                 bIgnoreCtrl = FALSE,
                 bIgnoreShift = FALSE,
                 bIgnoreAlt = FALSE
                },
                {
                 Command = "Console_Menu",
                 Name = 'XboxTypeS_Start',
                 Control = FALSE,
                 Shift = FALSE,
                 Alt = FALSE,
                 bIgnoreCtrl = FALSE,
                 bIgnoreShift = FALSE,
                 bIgnoreAlt = FALSE
                },
                {
                 Command = "Console_MoveUp",
                 Name = 'XboxTypeS_RightTrigger',
                 Control = FALSE,
                 Shift = FALSE,
                 Alt = FALSE,
                 bIgnoreCtrl = FALSE,
                 bIgnoreShift = FALSE,
                 bIgnoreAlt = FALSE
                },
                {
                 Command = "Console_MoveDown",
                 Name = 'XboxTypeS_LeftTrigger',
                 Control = FALSE,
                 Shift = FALSE,
                 Alt = FALSE,
                 bIgnoreCtrl = FALSE,
                 bIgnoreShift = FALSE,
                 bIgnoreAlt = FALSE
                },
                {
                 Command = "Console_Screenshot",
                 Name = 'XboxTypeS_X',
                 Control = FALSE,
                 Shift = FALSE,
                 Alt = FALSE,
                 bIgnoreCtrl = FALSE,
                 bIgnoreShift = FALSE,
                 bIgnoreAlt = FALSE
                },
                {
                 Command = "Console_TogglePhotoOptions",
                 Name = 'XboxTypeS_B',
                 Control = FALSE,
                 Shift = FALSE,
                 Alt = FALSE,
                 bIgnoreCtrl = FALSE,
                 bIgnoreShift = FALSE,
                 bIgnoreAlt = FALSE
                },
                {
                 Command = "PC_LookX",
                 Name = 'MouseX',
                 Control = FALSE,
                 Shift = FALSE,
                 Alt = FALSE,
                 bIgnoreCtrl = FALSE,
                 bIgnoreShift = FALSE,
                 bIgnoreAlt = FALSE
                },
                {
                 Command = "PC_LookY",
                 Name = 'MouseY',
                 Control = FALSE,
                 Shift = FALSE,
                 Alt = FALSE,
                 bIgnoreCtrl = FALSE,
                 bIgnoreShift = FALSE,
                 bIgnoreAlt = FALSE
                },
                {
                 Command = "PC_TogglePhotoCamera",
                 Name = 'RightMouseButton',
                 Control = FALSE,
                 Shift = FALSE,
                 Alt = FALSE,
                 bIgnoreCtrl = FALSE,
                 bIgnoreShift = FALSE,
                 bIgnoreAlt = FALSE
                },
                {
                 Command = "PC_Screenshot",
                 Name = 'SpaceBar',
                 Control = FALSE,
                 Shift = FALSE,
                 Alt = FALSE,
                 bIgnoreCtrl = FALSE,
                 bIgnoreShift = FALSE,
                 bIgnoreAlt = FALSE
                },
                {
                 Command = "PC_Menu",
                 Name = 'Escape',
                 Control = FALSE,
                 Shift = FALSE,
                 Alt = FALSE,
                 bIgnoreCtrl = FALSE,
                 bIgnoreShift = FALSE,
                 bIgnoreAlt = FALSE
                },
                {
                 Command = "PC_TogglePhotoOptions",
                 Name = 'Tab',
                 Control = FALSE,
                 Shift = FALSE,
                 Alt = FALSE,
                 bIgnoreCtrl = FALSE,
                 bIgnoreShift = FALSE,
                 bIgnoreAlt = FALSE
                },
                {
                 Command = "PC_TogglePhotoOptions",
                 Name = 'LeftShift',
                 Control = FALSE,
                 Shift = FALSE,
                 Alt = FALSE,
                 bIgnoreCtrl = FALSE,
                 bIgnoreShift = FALSE,
                 bIgnoreAlt = FALSE
                }
               )
    bAllowRotationUpdate = TRUE
    bAllowMovement = TRUE
    bAllowCamera = TRUE
    bAllowPauseMenu = TRUE
    Priority = EGameModePriority2.ModePriority_Menus
}



