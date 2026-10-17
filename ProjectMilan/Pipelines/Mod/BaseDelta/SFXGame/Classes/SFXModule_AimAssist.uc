// MILAN CHANGE
// 09/27/2026 - Stumpy
// Aim Assist Tweaks changes
// Uses data from aimAssistProfileSettingID to control strength of the Aim Assist 

Class SFXModule_AimAssist extends SFXModule within BioPlayerController
    config(Game);

var Vector LastCamLoc;
var Vector LastMagneticEllipse;
var transient Rotator DebugAdhesion_Smoothed;
var transient Rotator DebugAdhesion_Final;
var transient Rotator DebugAdhesion_Combined;
var transient Rotator DebugAdhesion_PerfectAim;
var transient Rotator DebugAdhesion_StrafeAssist;
var transient Vector ZoomSnapTarget;
var transient Vector AdhesionSmoothForce;
var transient Vector CurrentAimAssistBoneLocation;
var transient Pawn LastAdhesionTarget;
var transient Pawn LastFrictionTarget;
var transient Actor LastZoomSnapTarget;
var transient Actor CurrentAimAssistTarget;
var config float GlobalFrictionFactor;
var config float GlobalAimCorrectionFactor;
var config float GlobalAdhesionFactor;
var config float GlobalSweepFactor;
var config float EnemyMovementAdhesionFactor;
var float LastDistToTarget;
var float LastDistMultiplier;
var float LastDistFromAimZ;
var float LastDistFromAimY;
var float LastFrictionMultiplier;
var float LastTargetRadius;
var float LastTargetHeight;
var float AdhesionSmoothRate;
var transient float AdhesionSmoothMag;
var transient float FrictionSmoothValue;
var float FrictionSmoothRate;
var transient float CurrentAimAssistSoftMargin;

// MILAN CHANGE START
// 09/27/2026 - Stumpy
// AAT Variables
var float AAProfileAdhesionValue;
var float AAProfileFrictionValue;
var bool AAProfileZoomSnapEnabled;
var int aimAssistProfileSettingID;
var EAimNodes LastNodeTarget;
// MILAN CHANGE END

public final function Rotator GetAdjustedAimFor(Weapon W, Vector StartFireLoc)
{
    local SFXWeapon SW;
    local Rotator BaseAimRot;
    local float Angle;
    local float Threshold;
    local SFXGRI GRI;
    
    BaseAimRot = Outer.Pawn != None ? Outer.Pawn.GetBaseAimRotation() : Outer.Rotation;
    SW = SFXWeapon(W);
    if (SW == None)
    {
        return BaseAimRot;
    }
    Angle = SW.MaxMagneticCorrectionAngle;
    Threshold = SW.MagneticCorrectionThresholdAngle;
    GRI = SFXGRI(Outer.WorldInfo.GRI);
    if (GRI != None && GRI.bMultiplayer == FALSE)
    {
        if (GRI.DifficultyHandler.CurrentDifficulty == EDifficultyOptions.DO_Level1 || GRI.DifficultyHandler.CurrentDifficulty == EDifficultyOptions.DO_Level2)
        {
            Angle *= 3.5;
            Threshold *= 3.5;
        }
    }
    return GetMagneticAimCorrection(StartFireLoc, BaseAimRot, Angle, Threshold, W.GetTraceRange());
}

// MILAN CHANGE START
// 09/27/2026 - Stumpy
// Get values from the packed int and set respective variables 
public final function CacheCurrentAimAssistTarget()
{
    local SFXWeapon SW;
    local Vector CamLoc;
    local Rotator CamRot;
    local AimAssistBox AimBox;
    local SFXModule_AimAssistTarget TargetMod;
    local SFXEngine oEngine;
    local int AARawSettingValue;
    
    if (SFXPlayerCamera(Outer.PlayerCamera) != None && SFXPlayerCamera(Outer.PlayerCamera).CurrentCameraMode != None)
    {
        CamLoc = SFXPlayerCamera(Outer.PlayerCamera).CurrentCameraMode.m_pov.location;
        CamRot = SFXPlayerCamera(Outer.PlayerCamera).CurrentCameraMode.m_pov.Rotation;
    }
    SW = SFXWeapon(Outer.Pawn.Weapon);
    oEngine = SFXEngine(Class'SFXEngine'.static.GetEngine());
    oEngine.GetProfileSettings().GetProfileSettingValueInt(aimAssistProfileSettingID, AARawSettingValue);
    // As this is a signed int, grabbing the first bit before removing it
    AAProfileZoomSnapEnabled = bool(AARawSettingValue >> 31);
    AARawSettingValue = AARawSettingValue << 1 >> 1;
    AAProfileAdhesionValue = float((AARawSettingValue << 20 >> 26)) / 10.0;
    AAProfileFrictionValue = float((AARawSettingValue << 14 >> 26)) / 10.0;
    CurrentAimAssistSoftMargin = 0.0;
    CurrentAimAssistBoneLocation = vect(0.0, 0.0, 0.0);
    CurrentAimAssistTarget = Outer.GetAimAssistTarget(SW.MaxAdhesionDistance, CamLoc, CamRot, CurrentAimAssistBoneLocation, CurrentAimAssistSoftMargin);
    if (BioPawn(CurrentAimAssistTarget) != None)
    {
        TargetMod = CurrentAimAssistTarget.GetModule(Class'SFXModule_AimAssistTarget');
        foreach TargetMod.AimAssistRegions(AimBox, )
        {
            if (AimBox.NodeType == EAimNodes.AimNode_Head)
            {
                AimBox.SoftMargin = 80.0;
            }
            else
            {
                AimBox.SoftMargin = 40.0;
            }
        }
        if (BioPawn(CurrentAimAssistTarget).IsDead())
        {
            CurrentAimAssistTarget = None;
            CurrentAimAssistSoftMargin = 0.0;
            CurrentAimAssistBoneLocation = vect(0.0, 0.0, 0.0);
        }
    }
    if (SFXPlayerCamera(Outer.PlayerCamera).m_aTraceInfo.m_oCollVectorActor != CurrentAimAssistTarget && VSizeSq(SFXPlayerCamera(Outer.PlayerCamera).m_aTraceInfo.m_vCollVectorLocation - CamLoc) < VSizeSq(CurrentAimAssistBoneLocation - CamLoc))
    {
        CurrentAimAssistTarget = None;
        CurrentAimAssistSoftMargin = 0.0;
        CurrentAimAssistBoneLocation = vect(0.0, 0.0, 0.0);
    }
}
// MILAN CHANGE END

// MILAN CHANGE START
// 09/27/2026 - Stumpy
// Add debug output for Aim Assist Tweaks, values as text, and a somewhat accurate visualization of Adhesion influence zones.
public function DebugDraw_Adhesion(BioHUD H)
// 10/17/2026 - Stumpy
// Add current weapon info related to Adhesion
// Disable "influence circles" if the target doesn't cause adhesion
{
    local Vector XAxis;
    local Vector YAxis;
    local Vector ZAxis;
    local Vector Dir;
    local Vector TargLoc;
    local int X;
    local int Y;
    local Vector CamLoc;
    local Rotator CamRot;
    local SFXModule_AimAssistTarget TargetMod;
    local AimAssistBox AimBox;
    local Vector ScreenCoords;
    local float DistToTarget;
    local float CircleSize;
    local float AdhesionAngle;
    local SFXWeapon Weapon;
    local float TextXL;
    local float TextYL;
    local SFXEngine oEngine;
    local int debugAAProfileSetting;
    local bool debugZoomSnapEnabled;
    local int debugProfileSettingValue;
    
    Weapon = SFXWeapon(Outer.Pawn.Weapon);
    X = 15;
    Y = 150;
    oEngine = SFXEngine(Class'SFXEngine'.static.GetEngine());
    // Get profile settings again instead of using the AATProfile*Value because that one does not get updated while the game is paused
    oEngine.GetProfileSettings().GetProfileSettingValueInt(aimAssistProfileSettingID, debugAAProfileSetting);
    debugZoomSnapEnabled = bool(debugAAProfileSetting >> 31);
    debugProfileSettingValue = debugAAProfileSetting << 1 >> 1;
    H.Canvas.DrawColor = MakeColor(61, 240, 213, 255);
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawText("Zoom Snap enabled MCS: " $ debugZoomSnapEnabled);
    Y += 15;
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawText("Adhesion MCS value: " $ debugProfileSettingValue << 20 >> 26);
    Y += 15;
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawText("Friction MCS value: " $ debugProfileSettingValue << 14 >> 26);
    Y += 15;
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawText("Aim Assist MCS hex value: " $ ToHex(debugAAProfileSetting));
    Y += 15;
    H.Canvas.DrawColor = MakeColor(255, 255, 0, 255);
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawText("Perfect  :" $ DebugAdhesion_PerfectAim);
    Y += 15;
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawText("Strafe   :" $ DebugAdhesion_StrafeAssist);
    Y += 15;
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawText("Combined :" $ DebugAdhesion_Combined);
    Y += 15;
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawText("Smoothed :" $ DebugAdhesion_Smoothed);
    Y += 15;
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawText("Final    :" $ DebugAdhesion_Final);
    Y += 15;
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawText("Target:" $ CurrentAimAssistTarget);
    Y += 15;
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawText("Bone Location: " $ CurrentAimAssistBoneLocation);
    Y += 15;
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawText("Current Soft Margin: " $ CurrentAimAssistSoftMargin);
    Y += 15;
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawColor = MakeColor(61, 240, 213, 255);
    H.Canvas.DrawText("Weapon.AdhesionStrength: " $ Weapon.AdhesionStrengthRange.X $ "-" $ Weapon.AdhesionStrengthRange.Y);
    Y += 15;
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawText("Weapon.AdhesionDistance: " $ Weapon.MinAdhesionDistance $ "-" $ Weapon.MaxAdhesionDistance);
    Y += 15;
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawText("Weapon.MinAdhesionVelocity: " $ Weapon.MinAdhesionVelocity);
    Y += 15;
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawText("Weapon.MaxLateralAdhesionDist: " $ Weapon.MaxLateralAdhesionDist);
    Y += 15;
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawText("Weapon.CamInputAdhesionDamping: " $ Weapon.CamInputAdhesionDamping);
    Y += 15;
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawText("Weapon.MaxRange: " $ Weapon.MaxRange());
    Y += 15;
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawText("Weapon.AimCorrectionAmount: " $ Weapon.AimCorrectionAmount);
    Y += 15;
    H.Canvas.SetPos(float(X), float(Y));
    if (int(LastNodeTarget) == 255)
    {
        H.Canvas.DrawText("Last Targeted Node: None");
    }
    else
    {
        H.Canvas.DrawText("Last Targeted Node: " $ LastNodeTarget);
    }
    Y += 30;
    if (LastAdhesionTarget != None)
    {
        TargLoc = LastAdhesionTarget.location;
        Outer.DrawDebugLine(Outer.Pawn.location, TargLoc, 0, 255, 0);
        Outer.GetPlayerViewPoint(CamLoc, CamRot);
        Dir = TargLoc - CamLoc;
        Dir.Z = 0.0;
        GetAxes(Rotator(Dir), XAxis, YAxis, ZAxis);
    }
    if (CurrentAimAssistTarget != None && Weapon.MaxAdhesionDistance >= VSize(CurrentAimAssistTarget.location - Outer.Pawn.location) && VSize(CurrentAimAssistTarget.location - Outer.Pawn.location) >= Weapon.MinAdhesionDistance && CurrentAimAssistSoftMargin > float(0))
    {
        Outer.GetPlayerViewPoint(CamLoc, CamRot);
        GetAxes(Outer.PlayerCamera.CameraCache.POV.Rotation, XAxis, YAxis, ZAxis);
        TargetMod = CurrentAimAssistTarget.GetModule(Class'SFXModule_AimAssistTarget');
        foreach TargetMod.AimAssistRegions(AimBox, )
        {
            TargLoc = Pawn(CurrentAimAssistTarget).Mesh.GetBoneLocation(TargetMod.AimNodes[int(AimBox.NodeType)]);
            if (TargLoc == vect(0.0, 0.0, 0.0))
            {
                H.Canvas.SetPos(float(X), float(Y));
                H.Canvas.DrawText(AimBox.NodeType $ ": Inactive");
                Y += 15;
                continue;
            }
            if (int(TargLoc.X) == int(CurrentAimAssistBoneLocation.X) && int(TargLoc.Y) == int(CurrentAimAssistBoneLocation.Y) && int(TargLoc.Z) == int(CurrentAimAssistBoneLocation.Z))
            {
                LastNodeTarget = AimBox.NodeType;
            }
            H.Canvas.SetPos(float(X), float(Y));
            H.Canvas.DrawText(AimBox.NodeType $ ": " $ TargLoc $ " --- " $ AimBox.SoftMargin);
            ScreenCoords = H.Canvas.Project(TargLoc);
            DistToTarget = VSize(TargLoc - CamLoc);
            AdhesionAngle = Atan2(Weapon.MaxLateralAdhesionDist, DistToTarget) * 57.2957802;
            CircleSize = AdhesionAngle / Outer.PlayerCamera.CameraCache.POV.FOV * float(H.Canvas.SizeX);
            H.DrawCircle(ScreenCoords.X, ScreenCoords.Y, CircleSize);
            H.Canvas.TextSize(string(AimBox.NodeType), TextXL, TextYL);
            H.Canvas.SetPos(float(int(ScreenCoords.X + CircleSize + 5.0)), ScreenCoords.Y - TextYL / float(2));
            H.Canvas.DrawText(string(AimBox.NodeType));
            Y += 15;
        }
    }
    else
    {
        LastNodeTarget = 255;
    }
}
// MILAN CHANGE END

public function DebugDraw_Friction(BioHUD H)
{
    local Vector XAxis;
    local Vector YAxis;
    local Vector ZAxis;
    local Vector TargLoc;
    local int X;
    local int Y;
    local SFXModule_AimAssistTarget TargetMod;
    local AimAssistBox AimBox;
    
    X = 15;
    Y = 150;
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawText("Target:" @ LastFrictionTarget @ "[" $ LastDistToTarget $ "] [" $ LastDistMultiplier $ "]");
    Y += 15;
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawText("Aim distance (Y/Z): [" $ LastDistFromAimY $ "] [" $ LastDistFromAimZ $ "]");
    Y += 15;
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawText("Target collision (R/H): [" $ LastTargetRadius $ "] [" $ LastTargetHeight $ "]");
    Y += 15;
    H.Canvas.SetPos(float(X), float(Y));
    H.Canvas.DrawText("Friction multiplier: [" $ LastFrictionMultiplier $ "]");
    Y += 15;
    if (CurrentAimAssistTarget != None)
    {
        GetAxes(Outer.PlayerCamera.CameraCache.POV.Rotation, XAxis, YAxis, ZAxis);
        TargetMod = CurrentAimAssistTarget.GetModule(Class'SFXModule_AimAssistTarget');
        foreach TargetMod.AimAssistRegions(AimBox, )
        {
            TargLoc = Pawn(CurrentAimAssistTarget).Mesh.GetBoneLocation(TargetMod.AimNodes[int(AimBox.NodeType)]);
            Outer.DrawDebugLine(Outer.Pawn.location, TargLoc, 0, 255, 0);
            Outer.DrawDebugLine(TargLoc + YAxis * AimBox.Width * 0.5 + ZAxis * AimBox.Height * 0.5, TargLoc + YAxis * AimBox.Width * 0.5 - ZAxis * AimBox.Height * 0.5, 0, 0, 255);
            Outer.DrawDebugLine(TargLoc - YAxis * AimBox.Width * 0.5 + ZAxis * AimBox.Height * 0.5, TargLoc - YAxis * AimBox.Width * 0.5 - ZAxis * AimBox.Height * 0.5, 0, 0, 255);
            Outer.DrawDebugLine(TargLoc + YAxis * AimBox.Width * 0.5 + ZAxis * AimBox.Height * 0.5, TargLoc - YAxis * AimBox.Width * 0.5 + ZAxis * AimBox.Height * 0.5, 0, 0, 255);
            Outer.DrawDebugLine(TargLoc + YAxis * AimBox.Width * 0.5 - ZAxis * AimBox.Height * 0.5, TargLoc - YAxis * AimBox.Width * 0.5 - ZAxis * AimBox.Height * 0.5, 0, 0, 255);
            Outer.DrawDebugLine(TargLoc + YAxis * (AimBox.Width * 0.5 + AimBox.SoftMargin) + ZAxis * (AimBox.Height * 0.5 + AimBox.SoftMargin), TargLoc + YAxis * (AimBox.Width * 0.5 + AimBox.SoftMargin) - ZAxis * (AimBox.Height * 0.5 + AimBox.SoftMargin), 0, 0, 127);
            Outer.DrawDebugLine(TargLoc - YAxis * (AimBox.Width * 0.5 + AimBox.SoftMargin) + ZAxis * (AimBox.Height * 0.5 + AimBox.SoftMargin), TargLoc - YAxis * (AimBox.Width * 0.5 + AimBox.SoftMargin) - ZAxis * (AimBox.Height * 0.5 + AimBox.SoftMargin), 0, 0, 127);
            Outer.DrawDebugLine(TargLoc + YAxis * (AimBox.Width * 0.5 + AimBox.SoftMargin) + ZAxis * (AimBox.Height * 0.5 + AimBox.SoftMargin), TargLoc - YAxis * (AimBox.Width * 0.5 + AimBox.SoftMargin) + ZAxis * (AimBox.Height * 0.5 + AimBox.SoftMargin), 0, 0, 127);
            Outer.DrawDebugLine(TargLoc + YAxis * (AimBox.Width * 0.5 + AimBox.SoftMargin) - ZAxis * (AimBox.Height * 0.5 + AimBox.SoftMargin), TargLoc - YAxis * (AimBox.Width * 0.5 + AimBox.SoftMargin) - ZAxis * (AimBox.Height * 0.5 + AimBox.SoftMargin), 0, 0, 127);
        }
    }
}

public function DebugDraw_Magnetism(BioHUD H)
{
    local Vector v1;
    local float CosCorrection;
    local float LookStickMag;
    local SFXWeapon SW;
    local Vector StartFireLoc;
    local Rotator BaseAimRot;
    local Vector PerfectAim;
    local Vector AimOffset;
    
    SW = SFXWeapon(Outer.Pawn.Weapon);
    if (SW == None)
    {
        return;
    }
    LookStickMag = Sqrt(Outer.PlayerInput.RawJoyLookRight * Outer.PlayerInput.RawJoyLookRight + Outer.PlayerInput.RawJoyLookUp * Outer.PlayerInput.RawJoyLookUp);
    if (LookStickMag <= Outer.DeadZoneThreshold || CurrentAimAssistTarget == None)
    {
        return;
    }
    StartFireLoc = Outer.Pawn.GetWeaponStartTraceLocation();
    BaseAimRot = Outer.Pawn != None ? Outer.Pawn.GetBaseAimRotation() : Outer.Rotation;
    PerfectAim = CurrentAimAssistBoneLocation - StartFireLoc;
    AimOffset = PerfectAim << BaseAimRot;
    CosCorrection = GetStickRelativeDot(Normal(AimOffset));
    v1.Z = -Outer.PlayerInput.RawJoyLookUp;
    v1.Y = Outer.PlayerInput.RawJoyLookRight;
    v1.X = 1.0;
    if (CosCorrection > Cos(0.0174532924 * SW.MagneticCorrectionThresholdAngle))
    {
        Outer.DrawDebugLine(StartFireLoc, StartFireLoc + (v1 >> BaseAimRot) * GlobalSweepFactor, 0, 255, 0);
    }
    else
    {
        Outer.DrawDebugLine(StartFireLoc, StartFireLoc + (v1 >> BaseAimRot) * GlobalSweepFactor, 255, 0, 0);
    }
}

public function DebugDraw_ZoomSnap(BioHUD H)
{
    local SFXWeapon Weapon;
    local LocalEnemy ChkEnemy;
    local BioPawn ChkPawn;
    local ZoomSnapInfo Info;
    local float XL;
    local float YL;
    local float Angle;
    local Vector CamLoc;
    local Vector HitLoc;
    local Vector HitNorm;
    local Rotator CamRot;
    local TraceHitInfo Hit;
    local float CircleSize;
    local Vector ScreenCoords;
    local Vector BoneLoc;
    
    Weapon = SFXWeapon(Outer.Pawn.Weapon);
    if (Weapon == None)
    {
        return;
    }
    Outer.GetPlayerViewPoint(CamLoc, CamRot);
    foreach Outer.EnemyList(ChkEnemy, )
    {
        ChkPawn = BioPawn(ChkEnemy.Enemy);
        if (ChkPawn != None && ChkEnemy.bVisible && VSize(ChkPawn.location - Outer.Pawn.location) >= Weapon.MinZoomSnapDistance && VSize(ChkPawn.location - Outer.Pawn.location) <= Weapon.MaxZoomSnapDistance)
        {
            foreach Weapon.ZoomSnapList(Info, )
            {
                if (ChkPawn.IsInCover() && Info.AimNode == EAimNodes.AimNode_Cover)
                {
                    BoneLoc = ChkPawn.GetPawnViewLocation();
                }
                else
                {
                    BoneLoc = ChkPawn.Mesh.GetBoneLocation(ChkPawn.AimNodes[int(Info.AimNode)]);
                }
                if (IsZero(BoneLoc) == FALSE && SFXPlayerCamera(Outer.PlayerCamera).LineCheck(Hit, HitLoc, HitNorm, BoneLoc) == None)
                {
                    ScreenCoords = H.Canvas.Project(BoneLoc);
                    H.Canvas.TextSize(string(ChkPawn.AimNodes[int(Info.AimNode)]), XL, YL);
                    H.Canvas.SetPos(ScreenCoords.X - XL / float(2), ScreenCoords.Y);
                    H.Canvas.SetDrawColor(255, 255, 255, 255);
                    Angle = Acos(Normal(BoneLoc - CamLoc) Dot Vector(CamRot)) * 57.2957802;
                    H.Canvas.DrawText(ChkPawn.AimNodes[int(Info.AimNode)] @ Angle);
                    H.Canvas.SetDrawColor(255, 0, 0, 255);
                    CircleSize = Info.OuterSnapAngle / Outer.PlayerCamera.CameraCache.POV.FOV * float(H.Canvas.SizeX);
                    H.DrawCircle(ScreenCoords.X, ScreenCoords.Y, CircleSize - float(2));
                    H.Canvas.SetDrawColor(0, 255, 0, 255);
                    CircleSize = Info.InnerSnapAngle / Outer.PlayerCamera.CameraCache.POV.FOV * float(H.Canvas.SizeX);
                    H.DrawCircle(ScreenCoords.X, ScreenCoords.Y, CircleSize - float(2));
                }
            }
        }
    }
}

public final function Rotator GetMagneticAimCorrection(Vector StartFireLoc, Rotator BaseAimRot, float MaxAngle, float Threshold, float Range)
{
    local float CosCorrection;
    local Rotator AdjustedAimRot;
    local float CorrectionRads;
    local float InterpAmount;
    local Vector PerfectAim;
    local Vector AimOffset;
    local Vector LookStick;
    local float LookStickMag;
    
    if (SFXPlayerCamera(Outer.PlayerCamera).m_aTraceInfo.m_oCollVectorActor == Outer.m_oPlayerSelection.m_oCurrentSelectionTarget)
    {
        return BaseAimRot;
    }
    LookStick.X = Outer.PlayerInput.RawJoyLookRight;
    LookStick.Y = Outer.PlayerInput.RawJoyLookUp;
    LookStickMag = VSize2D(LookStick);
    BaseAimRot = Outer.Pawn != None ? Outer.Pawn.GetBaseAimRotation() : Outer.Rotation;
    PerfectAim = CurrentAimAssistBoneLocation - StartFireLoc;
    AimOffset = PerfectAim << BaseAimRot;
    CosCorrection = GetStickRelativeDot(AimOffset);
    CorrectionRads = Acos(CosCorrection);
    if (CurrentAimAssistSoftMargin > float(0) || CorrectionRads < 0.0174532924 * Threshold / (LookStickMag + float(1)))
    {
        MaxAngle = MaxAngle * (float(1) + LookStickMag) * 0.0174532924;
        CorrectionRads = Abs(Acos(CosCorrection));
        InterpAmount = FClamp(MaxAngle / CorrectionRads, 0.0, 1.0);
        AdjustedAimRot = RLerp(BaseAimRot, Rotator(Normal(PerfectAim)), InterpAmount, TRUE);
        return AdjustedAimRot;
    }
    return BaseAimRot;
}

public function float GetStickRelativeDot(Vector ScreenAimOffset)
{
    local Vector AimOffset;
    local Vector LookStick;
    
    LookStick.X = Outer.PlayerInput.RawJoyLookRight;
    LookStick.Y = Outer.PlayerInput.RawJoyLookUp;
    AimOffset.X = ScreenAimOffset.X * GlobalAimCorrectionFactor;
    if (VSize2D(LookStick) > 0.800000012)
    {
        AimOffset.Y = ScreenAimOffset.Y / (float(1) + Abs(LookStick.X) * GlobalSweepFactor);
        AimOffset.Z = ScreenAimOffset.Z / (float(1) + Abs(LookStick.Y) * GlobalSweepFactor);
    }
    else
    {
        AimOffset.Y = ScreenAimOffset.Y;
        AimOffset.Z = ScreenAimOffset.Z;
    }
    return Normal(AimOffset).X;
}

public function string PrintQuat(Quat Q)
{
    return "" $ Q.X $ "," $ Q.Y $ "," $ Q.Z $ "," $ Q.W;
}

public final function ProcessRotation(float DeltaTime, out Rotator DeltaRot)
{
    local SFXWeapon Weapon;
    local Rotator AdhesionRot;
    local float FrictionFactor;
    
    Weapon = Outer.Pawn != None ? SFXWeapon(Outer.Pawn.Weapon) : None;
    if (Weapon != None)
    {
        AdhesionRot = ViewAdhesion(DeltaTime, Weapon);
        FrictionFactor = ViewFriction(DeltaTime, Weapon);
        DeltaRot = (float(1) - FrictionFactor) * DeltaRot + AdhesionRot;
        if (LastAdhesionTarget != None && (LastAdhesionTarget.bDeleteMe || LastAdhesionTarget.IsDead()))
        {
            LastAdhesionTarget = None;
        }
    }
}

public function Quat StripRoll(Quat Q)
{
    local Rotator R;
    
    R = QuatToRotator(Q);
    R.Roll = 0;
    return QuatFromRotator(R);
}

// MILAN CHANGE START
// 09/27/2026 - Stumpy
// Multiply the default adhesion result with the multiplier set by the user
public function Rotator ViewAdhesion(float DeltaTime, SFXWeapon Weapon)
// 10/17/2026 - Stumpy
// Check for max adhesion distance
// Bias adhesion a bit towards head area
// Disable adhesion for pitch
{
    local Pawn AdhesionTarget;
    local float DistToTarget;
    local float AdhesionRot;
    local float LookMag;
    local float MoveMag;
    local Vector CamVec;
    local Vector CamLoc;
    local Vector TargetLoc;
    local Vector CamToTarget;
    local Vector YLoc;
    local Vector FutureCamLoc;
    local Vector Correction;
    local Rotator CamRot;
    local Rotator NewRotation;
    local Vector PerfectAim;
    local Vector StrafeAim;
    local SFXModule_AimAssistTarget TargetMod;
    local Vector NodeCover;
    local Vector NodeHead;
    local Vector NodeGroin;
    local array<float> CustomAdhesionNodeMultiplier;
    local float AdhesionMultiplierResult;
    local float AdhesionPlayerMultiplier;
    local BioWorldInfo WorldRef;
    local AimAssistBox AimBox;
    
    MoveMag = Abs(Outer.RemappedJoyRight);
    LookMag = Sqrt(Outer.PlayerInput.RawJoyLookRight * Outer.PlayerInput.RawJoyLookRight + Outer.PlayerInput.RawJoyLookUp * Outer.PlayerInput.RawJoyLookUp);
    if (Outer.Pawn == None || Weapon == None || Weapon.bAdhesionEnabled == FALSE || LookMag == float(0) && MoveMag == float(0))
    {
        AdhesionSmoothMag = 0.0;
        return rot(0, 0, 0);
    }
    AdhesionTarget = Pawn(CurrentAimAssistTarget);
    WorldRef = BioWorldInfo(Class'Engine'.static.GetCurrentWorldInfo());
    // avoid applying adhesion to targets outside of adhesion range
    if (AdhesionTarget != None && Weapon.MaxAdhesionDistance >= VSize(AdhesionTarget.location - Outer.Pawn.location) && VSize(AdhesionTarget.location - Outer.Pawn.location) >= Weapon.MinAdhesionDistance && CurrentAimAssistSoftMargin > float(0))
    {
        TargetMod = CurrentAimAssistTarget.GetModule(Class'SFXModule_AimAssistTarget');
        NodeCover = AdhesionTarget.Mesh.GetBoneLocation(TargetMod.AimNodes[0]);
        NodeHead = AdhesionTarget.Mesh.GetBoneLocation(TargetMod.AimNodes[1]);
        NodeGroin = AdhesionTarget.Mesh.GetBoneLocation(TargetMod.AimNodes[5]);
        if (int(NodeCover.X) == int(CurrentAimAssistBoneLocation.X) && int(NodeCover.Y) == int(CurrentAimAssistBoneLocation.Y) && int(NodeCover.Z) == int(CurrentAimAssistBoneLocation.Z))
        {
            AdhesionMultiplierResult = 1.0;
            //CurrentAimAssistSoftMargin = 80.0;
        }
        else if (int(NodeHead.X) == int(CurrentAimAssistBoneLocation.X) && int(NodeHead.Y) == int(CurrentAimAssistBoneLocation.Y) && int(NodeHead.Z) == int(CurrentAimAssistBoneLocation.Z))
        {
            AdhesionMultiplierResult = 1.0;
            //CurrentAimAssistSoftMargin = 80.0;
        }
        else
        {
            // set aim assist location to between the head and groin when the target node is groin
            CurrentAimAssistBoneLocation = VLerp(NodeGroin, NodeHead, 0.5);
            AdhesionMultiplierResult = 1.0;
            //CurrentAimAssistSoftMargin = 40.0;
        }
        TargetLoc = CurrentAimAssistBoneLocation;
        CamLoc = SFXPlayerCamera(Outer.PlayerCamera).CurrentCameraMode.m_pov.location;
        CamRot = SFXPlayerCamera(Outer.PlayerCamera).CurrentCameraMode.m_pov.Rotation;
        CamVec = Vector(CamRot);
        CamToTarget = TargetLoc - CamLoc;
        DistToTarget = VSize(CamToTarget);
        YLoc = CamLoc + CamVec * DistToTarget;
        if (Outer.PlayerInput.RawJoyRight < -0.00999999978)
        {
            StrafeAim.X = 0.0;
        }
        StrafeAim = YLoc + AdhesionTarget.Velocity * DeltaTime * EnemyMovementAdhesionFactor;
        PerfectAim = TargetLoc + AdhesionTarget.Velocity * DeltaTime;
        FutureCamLoc = CamLoc + Outer.Pawn.Velocity * DeltaTime;
        AdhesionRot = GetRangeValueByPct(Weapon.AdhesionStrengthRange, CurrentAimAssistSoftMargin) * AdhesionMultiplierResult * AAProfileAdhesionValue;
        if (Weapon.IsZoomed())
        {
            AdhesionRot *= Weapon.AimModes[Weapon.CurrentAimMode].AdhesionMultiplier * AdhesionMultiplierResult * AdhesionPlayerMultiplier;
        }
        Correction = VLerp(StrafeAim, PerfectAim, Weapon.AimCorrectionAmount);
        DebugAdhesion_Combined = Rotator(Normal(Correction - FutureCamLoc));
        Correction = VLerp(CamVec, Normal(Correction - FutureCamLoc), FClamp(AdhesionRot * GlobalAdhesionFactor * (LookMag + MoveMag), 0.0, 1.0));
        NewRotation = Rotator(Correction);
        // Disable pitch (vertical) adhesion TODO: make toggleable in settings
        NewRotation.Pitch = CamRot.Pitch;
        DebugAdhesion_Final = NewRotation;
        return NewRotation - CamRot;
    }
    return rot(0, 0, 0);
}
// MILAN CHANGE END

// MILAN CHANGE START
// 09/27/2026 - Stumpy
// Multiply the default friction result with the multiplier set by the user
public function float ViewFriction(float DeltaTime, SFXWeapon Weapon)
{
    local BioPawn FrictionTarget;
    local Vector CamLoc;
    local Vector X;
    local Vector Y;
    local Vector Z;
    local Rotator CamRot;
    local float FrictionMultiplier;
    local float FrictionPlayerConfig;
    
    if (Outer.Pawn == None || Weapon.bFrictionEnabled == FALSE)
    {
        return 0.0;
    }
    Outer.GetPlayerViewPoint(CamLoc, CamRot);
    GetAxes(CamRot, X, Y, Z);
    FrictionTarget = BioPawn(CurrentAimAssistTarget);
    if (FrictionTarget != None && CurrentAimAssistSoftMargin > float(0))
    {
        FrictionMultiplier = GetRangeValueByPct(Weapon.FrictionMultiplierRange, CurrentAimAssistSoftMargin) * GlobalFrictionFactor * AAProfileFrictionValue;
        if (Weapon.IsZoomed())
        {
            FrictionMultiplier *= Weapon.AimModes[Weapon.CurrentAimMode].FrictionMultiplier * AAProfileFrictionValue;
        }
    }
    else
    {
        FrictionMultiplier = 0.0;
    }
    FrictionSmoothValue = Lerp(FrictionSmoothValue, FrictionMultiplier, 1.0 - (float(1) - FrictionSmoothRate) ** DeltaTime);
    FrictionMultiplier = FrictionSmoothValue;
    if (FrictionMultiplier > 0.0)
    {
        LastFrictionTarget = FrictionTarget;
    }
    LastFrictionMultiplier = FrictionMultiplier;
    LastCamLoc = CamLoc;
    return FrictionMultiplier;
}
// MILAN CHANGE END

// MILAN CHANGE START
// Check if user has zoom snap enabled (default on)
public function ZoomSnap()
{
    local SFXWeapon Weapon;
    local float Dist;
    local float MaxHeightOffset;
    local float HeightOffset;
    local Vector Proj;
    local Vector Offset;
    local SFXPlayerCamera Cam;
    
    Weapon = SFXWeapon(Outer.Pawn.Weapon);
    if (Outer.Pawn == None || Weapon == None || AAProfileZoomSnapEnabled == FALSE || Weapon.bZoomSnapEnabled == FALSE || SFXPlayerCamera(Outer.PlayerCamera).m_aTraceInfo.m_oCollVectorActor == CurrentAimAssistTarget)
    {
        return;
    }
    LastZoomSnapTarget = Outer.GetZoomSnapTarget(Weapon.MinZoomSnapDistance, Weapon.MaxZoomSnapDistance, ZoomSnapTarget);
    if (LastZoomSnapTarget == None)
    {
        ZoomSnapTarget = vect(0.0, 0.0, 0.0);
        return;
    }
    Cam = SFXPlayerCamera(Outer.PlayerCamera);
    Dist = VSize(Cam.CameraCache.POV.location - (LastZoomSnapTarget.location + ZoomSnapTarget));
    Proj = Cam.CameraCache.POV.location + Vector(Cam.CameraCache.POV.Rotation) * Dist;
    Offset = Proj - (LastZoomSnapTarget.location + ZoomSnapTarget);
    if (BioPawn(LastZoomSnapTarget) != None)
    {
        MaxHeightOffset = BioPawn(LastZoomSnapTarget).CylinderComponent.CollisionHeight;
        HeightOffset = Proj.Z - LastZoomSnapTarget.location.Z;
        if (HeightOffset > float(0) && HeightOffset < MaxHeightOffset)
        {
            ZoomSnapTarget.Z = HeightOffset;
            Offset.Z = 0.0;
        }
    }
    ZoomSnapTarget += Offset * (FRand() * 0.25 + 0.0500000007);
}
// MILAN CHANGE END

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    GlobalFrictionFactor = 1.79999995
    GlobalAimCorrectionFactor = 0.5
    GlobalAdhesionFactor = 0.5
    GlobalSweepFactor = 2.0
    EnemyMovementAdhesionFactor = 0.75
    AdhesionSmoothRate = 0.699999988
    FrictionSmoothRate = 1.0
    bTickWhilePaused = TRUE
    // MILAN CHANGE START
    // 09/27/2026 - Stumpy
    // Profile setting ID that contains the Aim Assist settings
    aimAssistProfileSettingID = 31
    // MILAN CHANGE END
}