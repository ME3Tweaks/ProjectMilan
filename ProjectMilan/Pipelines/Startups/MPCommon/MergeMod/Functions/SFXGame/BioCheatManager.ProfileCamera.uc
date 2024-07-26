public function ProfileCamera()
{
    local PlayerController Controller;
    local SFXPlayerCamera Camera;
    local BioWorldInfo TheWorldInfo;
    local float NearClipPlane;
    local Vector CamLoc;
    local Vector ZeroVec;

    // Milan variables.
    local Rotator CamRot;
    local TraceHitInfo HitInfo;
    local Actor HitActor;
    local Vector HitLoc;
    local Vector HitNormal;
    
    Controller = Outer;
    Camera = SFXPlayerCamera(Controller.PlayerCamera);
    DrawProfileText("Camera:" @ Camera);
    DrawProfileText("Active:" @ Camera.CurrentCameraMode);
    DrawProfileText("Actual POV: (Rotation=" @ Camera.CameraCache.POV.Rotation @ ", Location="; @ Camera.CameraCache.POV.location @ ", FOV=" @ Camera.CameraCache.POV.FOV);
    DrawProfileText("Target POV: (Rotation=" @ Camera.ViewTarget.POV.Rotation @ ", Location=" @ Camera.ViewTarget.POV.location @ ", FOV=" @ Camera.ViewTarget.POV.FOV);
    Camera.CurrentCameraMode.DrawHUD(Self);
    TheWorldInfo = BioWorldInfo(Outer.WorldInfo);
    if (TheWorldInfo != None)
    {
        NearClipPlane = TheWorldInfo.GetRenderStateOfPlayer(0);
        DrawProfileText("Near Clip Plane:" @ NearClipPlane);
    }

    // MILAN DEBUG: Show live trace to ground to help determine collision issues.

    CamRot = Camera.ViewTarget.POV.Rotation;
    CamLoc = Camera.ViewTarget.POV.location;

    HitActor = Camera.Trace(HitLoc, HitNormal, Vector(CamRot) * float(5000) * float(20) + CamLoc, CamLoc, TRUE, ZeroVec, HitInfo, );
    if (HitActor != None)
    {
        DrawProfileText("Target hit: " $ HitActor);
        Camera.DrawDebugCylinder(Camera.CameraCache.POV.location, HitLoc, 5.0, 1, 0, 255, 0);
        Camera.DrawDebugStar(HitLoc, 15.0, 255, 0, 0);
    }
    else
    {
        DrawProfileText("No target hit");
    }
}