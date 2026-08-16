public function DebugDraw_Adhesion(BioHUD H)
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
    if (CurrentAimAssistTarget != None)
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