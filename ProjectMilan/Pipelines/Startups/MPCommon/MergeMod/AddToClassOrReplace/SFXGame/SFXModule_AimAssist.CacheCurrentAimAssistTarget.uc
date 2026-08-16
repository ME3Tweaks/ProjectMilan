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
    // Check install bool
    if (BioWorldInfo(Class'Engine'.static.GetCurrentWorldInfo()).GetGlobalVariables().GetBool(AATInstallBool))
    {
        oEngine = SFXEngine(Class'SFXEngine'.static.GetEngine());
        oEngine.GetProfileSettings().GetProfileSettingValueInt(aimAssistProfileSettingID, AARawSettingValue);
        // As this is a signed int, grabbing the first bit before removing the highest bit
        AAProfileZoomSnapEnabled = bool(AARawSettingValue >> 31);
        AARawSettingValue = AARawSettingValue << 1 >> 1;
        AAProfileAdhesionValue = float(((AARawSettingValue >> 6) % 64)) / 10.0;
        AAProfileFrictionValue = float(((AARawSettingValue >> 12) % 64)) / 10.0;
    }
    else
    {
        AAProfileZoomSnapEnabled = TRUE;
        AAProfileAdhesionValue = 1.0;
        AAProfileFrictionValue = 1.0;
    }
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