public function Rotator ViewAdhesion(float DeltaTime, SFXWeapon Weapon)
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
    if (AdhesionTarget != None && VSize(AdhesionTarget.location - Outer.Pawn.location) >= Weapon.MinAdhesionDistance && CurrentAimAssistSoftMargin > float(0))
    {
        TargetMod = CurrentAimAssistTarget.GetModule(Class'SFXModule_AimAssistTarget');
        NodeCover = AdhesionTarget.Mesh.GetBoneLocation(TargetMod.AimNodes[0]);
        NodeHead = AdhesionTarget.Mesh.GetBoneLocation(TargetMod.AimNodes[1]);
        NodeGroin = AdhesionTarget.Mesh.GetBoneLocation(TargetMod.AimNodes[5]);
        TargetLoc = CurrentAimAssistBoneLocation;
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
            AdhesionMultiplierResult = 1.0;
            //CurrentAimAssistSoftMargin = 40.0;
        }
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
        DebugAdhesion_Final = NewRotation;
        return NewRotation - CamRot;
    }
    return rot(0, 0, 0);
}