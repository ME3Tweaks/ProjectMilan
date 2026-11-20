// Source: ME3, Patch_SFXPawn_Atlas
// Decompiled 11/17/2026 7:37:53 AM against BioD_Cat003_580BalconyRear.pcc
Class SFXPawn_Atlas extends SFXPawn
    placeable
    config(Game);

var BioPawn.BodyStance BS_Driving;
var BioPawn.BodyStance BS_DeadDriverPose;
var BioPawn.BodyStance BS_PulledOutOfCockpit;
var RvrClientEffectInterface CE_Damaged[4];
var Object.Guid DamagedGUID;
var Name DrivingSocket;
var Actor DriverArchetype;
var AnimSet DriverAnimset;
var transient AnimNodeBlendList CachedReactionNode;
var transient SFXPawn AtlasDriver;
var transient Pawn ClaimingPawn;
var transient float LastClaimTime;
var transient SFXPawn PreviousDriver;
var transient RvrClientEffectInterface CE_Current;
var transient int DamageLevel;
var(SFXPawn_Atlas) instanced SkeletalMeshComponent PSC_BrokenCockpit;
var float CockpitOffset;
var transient Object OldSelectionMod;
var transient Controller OldController;
var transient SkelControlSingleBone SmokeLauncherCtrl;
var WwiseEvent StartPlayerDrivingSound;
var WwiseEvent StopPlayerDrivingSound;
var RvrClientEffectInterface CE_BloodEffect;
var WwiseEvent DriverShotSound;
var ParticleSystem PS_Footstep;
var transient instanced PrimitiveComponent LastHitComponent;
var(SFXPawn_Atlas) bool bSuitIsEmpty;
var(SFXPawn_Atlas) bool bOnlyPlayerPilots;
var transient bool bHadDriver;

public simulated function Destroyed()
{
    local SFXPawn OldDriver;
    
    Super(BioPawn).Destroyed();
    if (OldController != None)
    {
        OldController.Destroy();
    }
    if (AtlasDriver != None && !AtlasDriver.IsPlayerPawn())
    {
        OldDriver = AtlasDriver;
        DetachDriver();
        OldDriver.Destroy();
    }
}
public function BioPawn GetDriver()
{
    return AtlasDriver;
}
protected event function bool GetPossibleReactions(SFXCustomActionTypes.EReactionTypes ReactionType, out array<SFXCustomActionTypes.EAICustomAction> OutActions, optional Name HitPart, optional Controller instigatedBy, optional Object.Vector Momentum, optional out Actor.TraceHitInfo HitInfo)
{
    if (AtlasDriver == None || AtlasDriver.IsDead())
    {
        return FALSE;
    }
    return Super(BioPawn).GetPossibleReactions(ReactionType, OutActions, HitPart, instigatedBy, Momentum, HitInfo);
}
public simulated function PlayHit(float Damage, Controller instigatedBy, Object.Vector HitLocation, Class<DamageType> DamageType, Object.Vector Momentum, Actor.TraceHitInfo HitInfo, Pawn DamageCauser)
{
    Super.PlayHit(Damage, instigatedBy, HitLocation, DamageType, Momentum, HitInfo, DamageCauser);
    UpdateDamageLevel();
    if (CachedReactionNode != None && HitInfo.HitComponent != None && CurrentCustomAction == 0 && ClassIsChildOf(HitInfo.HitComponent.@Class, Class'StaticMeshComponent') && HasAnyShieldResistance() == FALSE)
    {
        CachedReactionNode.SetActiveChild(Rand(4) + 1, 0.100000001);
    }
}
public simulated function SetInitialState()
{
    local SFXPawn NewDriver;
    local SFXDifficultyHandler DH;
    local SFXModule_Damage DmgMod;
    local int idx;
    local SFXModule_Armour ArmMod;
    
    Super(Actor).SetInitialState();
    if (WorldInfo.GRI == None)
    {
        SetTimer(0.100000001, FALSE, 'SetInitialState', );
        return;
    }
    DH = SFXGRI(WorldInfo.GRI).DifficultyHandler;
    if (bSuitIsEmpty)
    {
        SetTimer(0.100000001, FALSE, 'InitializeSuit', );
    }
    else if (SFXGRI(WorldInfo.GRI).bMultiplayer == TRUE)
    {
        ClaimingPawn = Self;
    }
    else
    {
        NewDriver = SFXPawn(Spawn(DriverArchetype.@Class, None, 'Driver', location, Rotation, DriverArchetype, TRUE));
        if (NewDriver != None)
        {
            AttachDriver(NewDriver);
            NewDriver.InvManager.DiscardInventory();
            bHadDriver = TRUE;
            if (DH != None)
            {
                DmgMod = NewDriver.GetModule(Class'SFXModule_Damage');
                if (DmgMod != None)
                {
                    DmgMod.NormalizedHealth = DH.GetFloatNormalized('MaxHealth', 'AssaultTrooper');
                    DmgMod.LevelScaledHealth = DH.GetFloat('MaxHealth', 'AssaultTrooper');
                    DmgMod.InitializeMaxHealth(DmgMod.LevelScaledHealth);
                }
            }
        }
    }
    if (DH != None)
    {
        ArmMod = GetModule(Class'SFXModule_Armour');
        if (ArmMod != None)
        {
            for (idx = 0; idx < 12; idx++)
            {
                if (ArmMod.ActiveArmour[idx] != None)
                {
                    if (ArmMod.ActiveArmour[idx].ArmourName != 'CanopyGlass')
                    {
                        ArmMod.ActiveArmour[idx].CurrentHealth = DH.GetFloat('ArmourPieceHealth', 'Atlas');
                        ArmMod.ActiveArmour[idx].MaxHealth = DH.GetFloat('ArmourPieceHealth', 'Atlas');
                        continue;
                    }
                    ArmMod.ActiveArmour[idx].CurrentHealth = DH.GetFloat('GlassCockpitHealth', 'Atlas');
                    ArmMod.ActiveArmour[idx].MaxHealth = DH.GetFloat('GlassCockpitHealth', 'Atlas');
                }
            }
        }
    }
    SmokeLauncherCtrl = SkelControlSingleBone(Mesh.FindSkelControl('SmokeLauncher'));
    if (SmokeLauncherCtrl != None)
    {
        SmokeLauncherCtrl.SetSkelControlStrength(1.0, 0.0);
        SmokeLauncherCtrl.SetSkelControlActive(FALSE);
    }
}
public simulated function Tick(float DeltaTime)
{
    local Object.Vector NewLoc;
    local Object.Rotator NewRot;
    local Object.Rotator ViewRot;
    local SFXPlayerCamera Camera;
    
    Super(BioPawn).Tick(DeltaTime);
    if (Controller != None && Controller.bIsPlayer)
    {
        Camera = SFXPlayerCamera(PlayerController(Controller).PlayerCamera);
        if (Camera != None)
        {
            NewLoc = Camera.CameraCache.POV.location + Vector(Camera.CameraCache.POV.Rotation) * CockpitOffset;
            NewLoc = NewLoc - location;
            ViewRot.Yaw = Camera.CameraCache.POV.Rotation.Yaw;
            NewLoc = NewLoc << ViewRot;
            PSC_BrokenCockpit.SetTranslation(NewLoc);
            NewRot = PSC_BrokenCockpit.Rotation;
            NewRot.Pitch = Controller.Rotation.Pitch;
            PSC_BrokenCockpit.SetRotation(NewRot);
        }
    }
}
public function UnClaim(optional Pawn Claimer)
{
    if (Claimer == None || Claimer == ClaimingPawn)
    {
        LastClaimTime = WorldInfo.GameTimeSeconds;
        ClaimingPawn = None;
    }
}
public simulated function bool ImpactWithPower(Actor.EPowerResistance Resistance, Pawn Caster, Object.Vector HitLocation, Object.Vector HitNormal, float Damage, Object.Vector Force, Class<DamageType> DamageType)
{
    local bool bReturnVal;
    
    bReturnVal = Super.ImpactWithPower(Resistance, Caster, HitLocation, HitNormal, Damage, Force, DamageType);
    UpdateDamageLevel();
    return bReturnVal;
}
public final simulated function AttachDriver(Pawn NewDriver)
{
    local SFXAI_Atlas AI;
    local SFXPawn Driver;
    local SFXSelectionModule SelMod;
    local Controller DriverController;
    local BioPlayerController PC;
    local SFXGRI GRI;
    
    if (AtlasDriver != None)
    {
        DetachDriver();
    }
    Driver = SFXPawn(NewDriver);
    if (Driver != None)
    {
        TriggerEventClass(Class'SFXSeqEvt_AtlasEntered', NewDriver);
        AtlasDriver = Driver;
        Driver.DrivenAtlas = Self;
        bSuitIsEmpty = FALSE;
        Driver.RegisterTemporaryAnim(DriverAnimset);
        Driver.PlayBodyStance(BS_Driving, 1.0, 0.0, 0.0, TRUE);
        Driver.bCollideWorld = FALSE;
        Driver.bCanPlayReactions = FALSE;
        Driver.bCanRagdoll = FALSE;
        Driver.bCanBeDamaged = FALSE;
        Driver.bPreventPermanentDeath = TRUE;
        Driver.Mesh.CastShadow = FALSE;
        SelMod = Driver.GetModule(Class'SFXSelectionModule');
        if (SelMod != None)
        {
            SelMod.DisableSelection();
        }
        Driver.SetPhysics(0);
        Driver.SetBase(Self, , Mesh, DrivingSocket);
        DriverController = Driver.Controller;
        Driver.SetOwner(Self);
        if (PlayerController(DriverController) != None)
        {
            if (DriverController != None)
            {
                DriverController.UnPossess();
            }
            Driver.Mesh.SetTraceBlocking(FALSE, FALSE);
            SetCollisionSize(115.0, 180.0);
            CameraArmScale = 1.0;
            HideMeshes();
            AttachComponent(PSC_BrokenCockpit);
            OldController = Controller;
            Controller.SetTickIsDisabled(TRUE);
            CombatGroundSpeed = GroundSpeed;
            RotationRate.Yaw = 65536;
            DriverController.Possess(Self, FALSE);
            BioPlayerController(DriverController).GameModeManager2.EnableMode(2);
            EnableAtlasHUD(PlayerController(DriverController));
            Class'WwiseAudioComponent'.static.SetGlobalRTPCFromScript("Atlas_Mode", 0.0);
            PlaySound(StartPlayerDrivingSound, TRUE);
            GRI = SFXGRI(WorldInfo.GRI);
            if (GRI != None)
            {
                GRI.TriggerVocalizationEvent(139, Self);
            }
            if (bHadDriver)
            {
                PC = BioPlayerController(DriverController);
                if (PC != None)
                {
                    PC.UnlockAccomplishment('HIJACKATLAS');
                }
            }
        }
        else
        {
            bHadDriver = TRUE;
            Driver.InvManager.DiscardInventory();
            if (DriverController != None)
            {
                DriverController.SetTickIsDisabled(TRUE);
            }
            AI = SFXAI_Atlas(Controller);
            if (AI != None)
            {
                AI.SetTeam(1);
                AI.StartAIPilot();
            }
            if (Class'WorldInfo'.static.IsConsoleBuild())
            {
                NewDriver.Mesh.MinAutoLODLevel = 2;
            }
            Class'WwiseAudioComponent'.static.SetGlobalRTPCFromScript("Atlas_Mode", 1.0);
        }
    }
}
public simulated function CacheAnimNodes()
{
    local AnimNodeBlendList BlendNode;
    
    Super(BioPawn).CacheAnimNodes();
    if (Mesh != None && Mesh.Animations != None)
    {
        foreach Mesh.AllAnimNodes(Class'AnimNodeBlendList', BlendNode)
        {
            if (BlendNode.NodeName == 'None')
            {
                continue;
            }
            if (BlendNode.NodeName == 'LightReactions')
            {
                CachedReactionNode = BlendNode;
                break;
            }
        }
    }
}
public simulated function bool CanBeBaseForPawn(Pawn aPawn)
{
    local SFXPawn BasePawn;
    
    BasePawn = SFXPawn(aPawn);
    if (BasePawn != None && BasePawn.bCanDriveAtlas)
    {
        return TRUE;
    }
    return Super(Pawn).CanBeBaseForPawn(aPawn);
}
public simulated function ClearAnimNodes()
{
    Super(BioPawn).ClearAnimNodes();
    CachedReactionNode = None;
}
public simulated function DetachDriver(optional bool bDelayDeath = FALSE)
{
    local SFXPawn Driver;
    local SFXSelectionModule SelMod;
    local Controller DriverController;
    
    Driver = AtlasDriver;
    if (Driver != None)
    {
        AtlasDriver = None;
        Driver.DrivenAtlas = None;
        bSuitIsEmpty = TRUE;
        Driver.UnregisterTemporaryAnim(DriverAnimset, 5.0);
        Driver.StopBodyStance(BS_Driving);
        Driver.StopBodyStance(BS_DeadDriverPose);
        Driver.bCollideWorld = Driver.default.bCollideWorld;
        Driver.bCanPlayReactions = Driver.default.bCanPlayReactions;
        Driver.bCanRagdoll = Driver.default.bCanRagdoll;
        Driver.bCanBeDamaged = TRUE;
        if (!bDelayDeath)
        {
            Driver.bPreventPermanentDeath = Driver.default.bPreventPermanentDeath;
        }
        Driver.Mesh.CastShadow = Driver.Mesh.default.CastShadow;
        SelMod = Driver.GetModule(Class'SFXSelectionModule');
        if (SelMod != None)
        {
            SelMod.RestoreSelection();
        }
        Driver.SetBase(None, , , );
        DriverController = Controller;
        Driver.SetOwner(None);
        if (PlayerController(DriverController) != None)
        {
            Controller.UnPossess();
            Driver.Mesh.SetTraceBlocking(default.Mesh.BlockZeroExtent, default.Mesh.BlockNonZeroExtent);
            SetCollisionSize(default.CylinderComponent.CollisionRadius, default.CylinderComponent.CollisionHeight);
            FitCollision();
            ShowMeshes();
            DetachComponent(PSC_BrokenCockpit);
            CombatGroundSpeed = default.CombatGroundSpeed;
            RotationRate = default.RotationRate;
            DriverController.Possess(Driver, TRUE);
            DisableAtlasHUD(PlayerController(DriverController));
            BioPlayerController(Driver.Controller).GameModeManager2.DisableMode(2);
            OldController.Possess(Self, FALSE);
            OldController.SetTickIsDisabled(FALSE);
            OldController = None;
            PlaySound(StopPlayerDrivingSound, TRUE);
        }
        else
        {
            AIController(Controller).SetTeam(255);
            if (Class'WorldInfo'.static.IsConsoleBuild())
            {
                Driver.Mesh.MinAutoLODLevel = Driver.Mesh.default.MinAutoLODLevel;
            }
        }
        Class'WwiseAudioComponent'.static.SetGlobalRTPCFromScript("Atlas_Mode", 1.0);
    }
}
public function bool Died(Controller Killer, Class<DamageType> DamageType, Object.Vector HitLocation)
{
    local SFXPawn OldDriver;
    local Controller OldAIController;
    
    OldDriver = AtlasDriver;
    OldAIController = Controller;
    DetachDriver();
    if (PlayerController(OldAIController) == None && OldDriver != None)
    {
        OldDriver.SetHidden(TRUE);
        OldDriver.Suicide();
    }
    return Super.Died(Killer, DamageType, HitLocation);
}
public function DriverDied()
{
    local SFXAI_Atlas AI;
    
    if (AtlasDriver == None)
    {
        UnClaim();
    }
    else
    {
        AI = SFXAI_Atlas(Controller);
        if (AI != None)
        {
            AtlasDriver.PlayBodyStance(BS_DeadDriverPose, 1.0, 0.0, 0.0, TRUE);
            AI.NotifyDriverDied();
            AI.SetTeam(255);
            TriggerEventClass(Class'SeqEvent_Death', Self);
            Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayAtLocation(CE_BloodEffect, AtlasDriver.location);
            PlaySound(DriverShotSound, , , , AtlasDriver.location);
            StartCustomAction(163);
        }
    }
}
public simulated function bool ModifyDamage(out float Damage, Object.Vector Momentum, out SFXDamageType.DamageCalculationAlgorithm DamageCalc, const out Actor.TraceHitInfo HitInfo, Object.Vector HitLocation, Class<SFXDamageType> DamageType, Controller instigatedBy, Actor DamageCauser)
{
    local SFXAI_Core AI;
    local SFXWeapon ChkWeapon;
    
    if (Super(BioPawn).ModifyDamage(Damage, Momentum, DamageCalc, HitInfo, HitLocation, DamageType, instigatedBy, DamageCauser) == FALSE)
    {
        return FALSE;
    }
    AI = SFXAI_Core(Controller);
    if (AI != None)
    {
        ChkWeapon = SFXWeapon(DamageCauser);
        if (ChkWeapon != None && ChkWeapon.GetPenetrationDepth() > 0.0)
        {
            if (LastHitComponent != None && LastHitComponent != Mesh && HitInfo.HitComponent == Mesh && WorldInfo.GameTimeSeconds - AI.LastDamagedTime <= 0.100000001)
            {
                return FALSE;
            }
        }
    }
    LastHitComponent = HitInfo.HitComponent;
    return TRUE;
}
public simulated function PlayDying(Class<DamageType> DamageType, Object.Vector HitLoc)
{
    Super.PlayDying(DamageType, HitLoc);
    if (CE_Current != None)
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(CE_Current, DamagedGUID, FALSE, Self);
        CE_Current = None;
    }
}
public function bool CanBeDrivenBy(SFXPawn PossibleDriver)
{
    if ((AtlasDriver == None || AtlasDriver.IsDead()) && ClaimingPawn == None && WorldInfo.GameTimeSeconds - LastClaimTime >= 5.0)
    {
        if (bOnlyPlayerPilots == FALSE || PossibleDriver.IsHumanControlled())
        {
            return TRUE;
        }
    }
    return Super.CanBeDrivenBy(PossibleDriver);
}
public simulated function bool CanPlayDeathEffect()
{
    return FALSE;
}
public simulated function ParticleSystem GetSpecificFootStepEffect(SFXPhysicalMaterialFootSteps FootStepMat, int FootDown)
{
    return PS_Footstep;
}
public simulated function NotifyHealed()
{
    Super.NotifyHealed();
    UpdateDamageLevel(TRUE);
}
public function TryToDriveMe(SFXPawn NewDriver)
{
    local SFXAI_Core AI;
    
    if (ClaimingPawn == None && WorldInfo.GameTimeSeconds - LastClaimTime >= 5.0)
    {
        ClaimingPawn = NewDriver;
        LastClaimTime = WorldInfo.GameTimeSeconds;
        AI = SFXAI_Core(NewDriver.Controller);
        if (AI != None)
        {
            AI.DriveTarget = Self;
            AI.BeginCombatCommand(Class'SFXAICmd_EnterAtlas');
        }
    }
    Super.TryToDriveMe(NewDriver);
}
public function bool TryToExitMe()
{
    SyncPawn = AtlasDriver;
    StartCustomAction(168, AtlasDriver);
    return TRUE;
}
public function CloseLauncherPort()
{
    if (SmokeLauncherCtrl != None)
    {
        SmokeLauncherCtrl.SetSkelControlActive(FALSE);
    }
}
public final function DisableAtlasHUD(PlayerController oController)
{
    local SFXGUIInteraction oGUIs;
    local SFXGUI_AtlasHUD oHud;
    
    if (oController == None)
    {
        return;
    }
    oGUIs = Class'SFXGUIInteraction'.static.GetInstance();
    if (oGUIs != None)
    {
        oHud = oGUIs.CastGetMovie(Class'SFXGUI_AtlasHUD', oController, oGUIs.MovieTag_AtlasHUD);
        if (oHud != None)
        {
            oHud.PlayExit();
        }
    }
}
public final function EnableAtlasHUD(PlayerController oController)
{
    local SFXGUIInteraction oGUIs;
    local SFXGUI_AtlasHUD oHud;
    
    if (oController == None)
    {
        return;
    }
    oGUIs = Class'SFXGUIInteraction'.static.GetInstance();
    if (oGUIs != None)
    {
        oHud = oGUIs.CastOpenMovie(Class'SFXGUI_AtlasHUD', oController, oGUIs.MovieTag_AtlasHUD);
        if (oHud != None)
        {
            oHud.Initialize(Self);
        }
    }
}
public function Object.Vector GetSmokeLauncherFireLoc()
{
    local Object.Vector Loc;
    local Object.Rotator Rot;
    
    if (Mesh != None)
    {
        if (Mesh.GetSocketWorldLocationAndRotation('Socket_grenLauncher', Loc, Rot))
        {
            return Loc;
        }
    }
    return vect(0.0, 0.0, 0.0);
}
public function HideMeshes()
{
    local int idx;
    local SFXModule_Armour ArmMod;
    
    Mesh.SetHidden(TRUE);
    ArmMod = GetModule(Class'SFXModule_Armour');
    if (ArmMod != None)
    {
        for (idx = 0; idx < 12; idx++)
        {
            if (ArmMod.ActiveArmour[idx].AttachInstance != None)
            {
                ArmMod.ActiveArmour[idx].AttachInstance.SetHidden(TRUE);
            }
        }
    }
    Class'RvrClientEffectManager'.static.GetClientEffectManager().HideOn(Self, TRUE);
}
public simulated function InitializeSuit()
{
    Weapon.GotoState('Active', , , );
    StartCustomAction(165);
    AIController(Controller).SetTeam(255);
}
public function OnAtlasOpenCockpit(SFXSeqAct_AtlasOpenCockpit Seq)
{
    if (CurrentCustomAction == 0)
    {
        if (Seq.InputLinks[0].bHasImpulse)
        {
            StartCustomAction(165);
        }
        else if (Seq.InputLinks[1].bHasImpulse)
        {
            StartCustomAction(166);
        }
        Seq.ActivateOutputLink(0);
        return;
    }
    Seq.ActivateOutputLink(1);
}
public function OpenLauncherPort()
{
    if (SmokeLauncherCtrl != None)
    {
        SmokeLauncherCtrl.SetSkelControlActive(TRUE);
    }
}
public function PlayDriverEntrance(Actor User)
{
    local BioPawn BP;
    
    BP = BioPawn(User);
    if (BP != None)
    {
        SyncPawn = BP;
        StartCustomAction(167, BP);
    }
}
public function PlayDriverPullOut()
{
    if (AtlasDriver != None)
    {
        PreviousDriver = AtlasDriver;
        DetachDriver(TRUE);
        PreviousDriver.SetCollision(FALSE, FALSE, PreviousDriver.bIgnoreEncroachers);
        PreviousDriver.SetPhysics(4);
        PreviousDriver.PlayBodyStance(BS_PulledOutOfCockpit, 1.0, 0.0, 0.0);
        PreviousDriver.Mesh.RootMotionMode = ERootMotionMode.RMM_Accel;
        PreviousDriver.SetBodyStanceRootBoneAxisOption(BS_PulledOutOfCockpit, 2, 2, 2);
    }
}
public simulated function SetUseable(bool bUseable)
{
    local SFXSelectionModule SelMod;
    local SFXSimpleUseModule UseMod;
    
    if (bUseable)
    {
        if (OldSelectionMod == None)
        {
            SelMod = GetModule(Class'SFXSelectionModule');
            if (SelMod != None)
            {
                OldSelectionMod = SelMod;
                RemoveSFXModule(SelMod);
            }
            UseMod = new (Self) Class'SFXSimpleUseModule';
            AddSFXModule(UseMod);
            UseMod.m_bTargetable = TRUE;
            UseMod.m_bCombatTargetable = FALSE;
            UseMod.fUseRange = 240.0;
            UseMod.m_fSelectionRadius = 1000.0;
            UseMod.OnUsed = PlayDriverEntrance;
            UseMod.m_TargetOffset = vect(0.0, 0.0, 170.0);
            UseMod.m_TargetTipText = ETargetTipText.TargetTipText_Use;
            UseMod.m_srGameName = $538001;
        }
    }
    else if (OldSelectionMod != None)
    {
        UseMod = GetModule(Class'SFXSimpleUseModule');
        if (UseMod != None)
        {
            RemoveSFXModule(UseMod);
        }
        AddSFXModule(SFXModule_AimAssistTarget(OldSelectionMod));
        OldSelectionMod = None;
    }
}
public function ShowMeshes()
{
    local int idx;
    local SFXModule_Armour ArmMod;
    
    Mesh.SetHidden(FALSE);
    ArmMod = GetModule(Class'SFXModule_Armour');
    if (ArmMod != None)
    {
        for (idx = 0; idx < 12; idx++)
        {
            if (ArmMod.ActiveArmour[idx].AttachInstance != None)
            {
                ArmMod.ActiveArmour[idx].AttachInstance.SetHidden(FALSE);
            }
        }
    }
    Class'RvrClientEffectManager'.static.GetClientEffectManager().HideOn(Self, FALSE);
}
public function ThrowPreviousDriver()
{
    if (PreviousDriver != None)
    {
        PreviousDriver.bPreventPermanentDeath = PreviousDriver.default.bPreventPermanentDeath;
        PreviousDriver.InitRagdoll();
        PreviousDriver = None;
    }
}
public simulated function UpdateDamageLevel(optional bool bForced)
{
    local float HealthPct;
    local int NewDamageLevel;
    
    if (!IsDead() && (HasAnyShieldResistance() == FALSE || bForced))
    {
        HealthPct = GetHealthPct();
        if (HealthPct <= 1.0)
        {
            NewDamageLevel = int((float(1) - HealthPct) * 4.0);
            if (NewDamageLevel != DamageLevel)
            {
                if (CE_Current != None)
                {
                    Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(CE_Current, DamagedGUID, FALSE, Self);
                }
                CE_Current = CE_Damaged[NewDamageLevel];
                DamagedGUID = Class'RvrClientEffectManager'.static.GetClientEffectManager().Start(CE_Current, Self);
                DamageLevel = NewDamageLevel;
            }
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=BioDynamicLightEnvironmentComponent Name=BioLightEnvComponent0
    End Template
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        CollisionHeight = 190.0
        CollisionRadius = 135.0
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=FootstepShakeFF0
        Samples = ({Duration = 0.400000006, LeftAmplitude = 80, RightAmplitude = 80, LeftFunction = EWaveformFunction.WF_LinearDecreasing, RightFunction = EWaveformFunction.WF_LinearDecreasing}
                  )
    End Template
    Begin Object Class=SFXLoadoutData Name=AtlasLoadout0
        Weapons = (Class'SFXWeapon_Heavy_Atlas')
        ShieldLoadouts = ({
                           Shields = Class'SFXShield_Energy', 
                           ShieldLevelRange = {X = 0.0, Y = 0.0}, 
                           MaxShields = {X = 1500.0, Y = 1500.0}
                          }
                         )
    End Object
    Begin Template Class=SFXModule_AimAssistTarget Name=AimAssistMod
        AimAssistRegions = ({Width = 120.0, Height = 80.0, SoftMargin = 80.0, NodeType = EAimNodes.AimNode_Groin}, 
                            {Width = 80.0, Height = 50.0, SoftMargin = 80.0, NodeType = EAimNodes.AimNode_Groin}, 
                            {Width = 80.0, Height = 80.0, SoftMargin = 80.0, NodeType = EAimNodes.AimNode_Cover}
                           )
    End Template
    Begin Object Class=SFXModule_Armour Name=BattleDamage0
    End Object
    Begin Template Class=SFXModule_Audio Name=AudioModule
        bPlayFootstepSounds = FALSE
    End Template
    Begin Template Class=SFXModule_Conversation Name=ConvoMod01
        m_bDisableFacefx = TRUE
    End Template
    Begin Template Class=SFXModule_Damage Name=DmgMod0
        HealthType = EHealthType.HealthType_Armour
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_Gestures Name=GestMod01
        Begin Template Class=BioGestureAnimSetMgr Name=oAnimSetMgr_0
        End Template
        m_pAnimSetMgr = oAnimSetMgr_0
    End Template
    Begin Template Class=SFXModule_LookAt Name=LookAtMod01
    End Template
    Begin Template Class=SFXModule_Radar Name=RadarModule
    End Template
    Begin Template Class=SFXModule_Timeline Name=TimelineMod0
    End Template
    Begin Template Class=SFXPowerManager Name=PowerMgr
    End Template
    Begin Template Class=SkeletalMeshComponent Name=BioPawnSkeletalMeshComponent
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
    End Template
    Begin Object Class=SkeletalMeshComponent Name=BrokenCockpit0
        SkeletalMesh = SkeletalMesh'BioVFX_Crt_Atlas.Meshes.CRB_ATA_CanopyGlass_Broken'
        bIgnoreControllersWhenNotRendered = TRUE
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
    End Object
    Begin Template Class=SkeletalMeshComponent Name=GearMesh0
        ParentAnimComponent = BioPawnSkeletalMeshComponent
        ShadowParent = BioPawnSkeletalMeshComponent
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=HairMesh0
        ParentAnimComponent = BioPawnSkeletalMeshComponent
        ShadowParent = BioPawnSkeletalMeshComponent
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=HeadMesh0
        ParentAnimComponent = BioPawnSkeletalMeshComponent
        ShadowParent = BioPawnSkeletalMeshComponent
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
    End Template
    BS_Driving = {
                  AnimName = ('HMM_SitInCockpit_Pose')
                 }
    BS_DeadDriverPose = {
                         AnimName = ('HMM_Pilot_DeadPose')
                        }
    BS_PulledOutOfCockpit = {
                             AnimName = ('HMM_Pilot_PulledOutofCockpit')
                            }
    CE_Damaged[0] = RvrClientEffect'BioVFX_Crt_Atlas.VCFX.Atlas_Damage_lvl_1'
    CE_Damaged[1] = RvrClientEffect'BioVFX_Crt_Atlas.VCFX.Atlas_Damage_lvl_2'
    CE_Damaged[2] = RvrClientEffect'BioVFX_Crt_Atlas.VCFX.Atlas_Damage_lvl_3'
    CE_Damaged[3] = RvrClientEffect'BioVFX_Crt_Atlas.VCFX.Atlas_Damage_lvl_4'
    DrivingSocket = 'Socket_driverSeat'
    DriverArchetype = SFXPawn_Trooper'char_enemies.Archetypes.Cerberus.AssaultTrooperPilot'
    DriverAnimset = AnimSet'BIOG_HMM_2P_A.HMM_2P_ATA_Synch'
    DamageLevel = -1
    PSC_BrokenCockpit = BrokenCockpit0
    CockpitOffset = -5.0
    StartPlayerDrivingSound = WwiseEvent'Wwise_Atlas.veh_atlas_int_play'
    StopPlayerDrivingSound = WwiseEvent'Wwise_Atlas.veh_atlas_int_stop'
    CE_BloodEffect = RvrClientEffect'BioVFX_C_Wpn_Scorpion.VCFX.Scorpion_Imp_VCFX'
    DriverShotSound = WwiseEvent'Wwise_VFX_Scion.Play_vfx_scion_sac_burst'
    PS_Footstep = ParticleSystem'BioVFX_Env_Dust.Particles.Dust_Puff_wDebris_01'
    FootstepShake = {
                     RotAmplitude = {X = 60.0, Y = 60.0, Z = 60.0}, 
                     RotFrequency = {X = 120.0, Y = 160.0, Z = 200.0}, 
                     TimeDuration = 0.400000006
                    }
    MuzzleSocketName = 'Socket_cannon'
    PowerControlResistance = 0.5
    CodexPlotState = 21717
    DamageScoreBudget = 1000.0
    KillBonusScore = 100.0
    PowerControlAssistBudget = 250.0
    FootstepForceFeedback = FootstepShakeFF0
    bPlayFootstepScreenShake = TRUE
    bPlayFootstepRumble = TRUE
    bSupportsVisibleWeapons = FALSE
    bCanBeRepaired = TRUE
    bCanBeMeleed = FALSE
    bIgnoresPets = TRUE
    CustomActionClasses = (None, 
                           Class'SFXCustomAction_Ragdoll', 
                           None, 
                           Class'SFXCustomAction_SyncPawnPartner_Base', 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_Frozen', 
                           None, 
                           Class'SFXCustomAction_MountedGunReload', 
                           None, 
                           None, 
                           Class'SFXCustomAction_EnterMountedGun', 
                           Class'SFXCustomAction_ExitMountedGun', 
                           Class'SFXCustomAction_AtlasOrbitalDrop', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_AtlasMantle', 
                           None, 
                           Class'SFXCustomAction_AtlasClimbUp', 
                           Class'SFXCustomAction_AtlasClimbDown', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_AtlasStagger', 
                           Class'SFXCustomAction_AtlasStandard', 
                           Class'SFXCustomAction_AtlasStandardForward', 
                           Class'SFXCustomAction_AtlasStandardLeft', 
                           Class'SFXCustomAction_AtlasStandardRight', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_AtlasDeathExplosion', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_AtlasMelee', 
                           Class'SFXCustomAction_AtlasHeavyMelee', 
                           Class'SFXCustomAction_AtlasSyncMelee', 
                           Class'SFXCustomAction_AtlasHeavyMelee', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_AtlasPlayerSmokeShot', 
                           Class'SFXCustomAction_AtlasBlock', 
                           Class'SFXCustomAction_AtlasOpenCockpitDeath', 
                           Class'SFXCustomAction_AtlasCloseCockpitCombat', 
                           Class'SFXCustomAction_AtlasOpenCockpitIdle', 
                           Class'SFXCustomAction_AtlasCloseCockpitIdle', 
                           Class'SFXCustomAction_AtlasDriverEnter', 
                           Class'SFXCustomAction_AtlasDriverExit'
                          )
    PowerCustomActionClasses = (None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                Class'SFXPowerCustomAction_TitanRocket', 
                                Class'SFXPowerCustomAction_TitanRocket_Player'
                               )
    SupportedCustomReachSpecs = (Class'SFXLargeMantleReachSpec', Class'SFXLargeClimbReachSpec')
    CombatVocVariants = (SFXVocalizationBank'VocalizationBanks.ss_c_atlas')
    AimNodes = ('FAKE_Cover', 
                'Spine01', 
                'leftArmClav', 
                'rightArmClav', 
                'Spine01', 
                'Pelvis', 
                'LeftUpperLeg', 
                'RightUpperLeg'
               )
    ReactionBones = ({
                      BoneNames = ('LeftFoot', 'leftCalf', 'left_RearCalf', 'leftMidLeg', 'LeftUpperLeg', 'LeftHip'), 
                      BodyPart = 'LeftLeg'
                     }, 
                     {
                      BoneNames = ('RightFoot', 'rightCalf', 'right_RearCalf', 'rightMidLeg', 'RightUpperLeg', 'RightHip'), 
                      BodyPart = 'RightLeg'
                     }, 
                     {
                      BoneNames = ('LeftClaw02', 
                                   'LeftClaw01', 
                                   'RightClaw02', 
                                   'RightClaw01', 
                                   'LeftHand', 
                                   'LeftArm', 
                                   'LeftShoulder', 
                                   'leftArmClav'
                                  ), 
                      BodyPart = 'LeftArm'
                     }, 
                     {
                      BoneNames = ('RightArm', 'RightShoulder', 'rightArmClav'), 
                      BodyPart = 'RightArm'
                     }, 
                     {
                      BoneNames = ('Root', 'Pelvis', 'Spine', 'God', 'Spine01'), 
                      BodyPart = 'Chest'
                     }
                    )
    RightHandSocketName = 'Socket_cannon'
    DeathCustomAction = 120
    HeadMesh = HeadMesh0
    m_oHairMesh = HairMesh0
    m_oHeadGearMesh = GearMesh0
    LightEnvironment = BioLightEnvComponent0
    AimOffsetInterpSpeed = 6.0
    AimOriginOffset = 100.0
    Loadout = AtlasLoadout0
    CE_LifetimeCrust = RvrClientEffect'BioVFX_Crt_Atlas.VCFX.Atlas_Jet_LifetimeCrust'
    FollowDistanceModifier = 400.0
    PowerManager = PowerMgr
    bSpawnPHATInstance = FALSE
    bCanRagdoll = FALSE
    bUseLargeReactions = TRUE
    m_bHideWithCameraCollision = FALSE
    bCanPortArms = FALSE
    bAdjustMeshTranslationOnSlopes = TRUE
    RaceType = ERaceType.RaceType_Machine
    CharacterType = ECharacterType.CharacterType_Cerberus_Atlas
    AffiliationType = EAffiliationType.AffiliationType_Cerberus
    ControllerClass = Class'SFXAI_Atlas'
    SightRadius = 4000.0
    BaseEyeHeight = 130.0
    EyeHeight = 130.0
    Mesh = BioPawnSkeletalMeshComponent
    CylinderComponent = CollisionCylinder
    ViewPitchMin = -4096.0
    ViewPitchMax = 4096.0
    bCanCrouch = FALSE
    bCanStrafe = FALSE
    Components = (CollisionCylinder, None, BioLightEnvComponent0, BioPawnSkeletalMeshComponent, HeadMesh0, HairMesh0, GearMesh0)
    Modules = (GEMod0, 
               RadarModule, 
               AimAssistMod, 
               DmgMod0, 
               GestMod01, 
               ConvoMod01, 
               LookAtMod01, 
               AudioModule, 
               TimelineMod0, 
               BattleDamage0
              )
    CollisionComponent = CollisionCylinder
    bIgnoreRigidBodyPawns = TRUE
}