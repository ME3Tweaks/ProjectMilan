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