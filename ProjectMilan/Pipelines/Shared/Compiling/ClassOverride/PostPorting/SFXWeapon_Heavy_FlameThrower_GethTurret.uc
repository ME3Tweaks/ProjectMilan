// MILAN CHANGE 10/19/2026
// By Mgamerz
// Change geth turret flamethrower from sentry turret to geth turret in killfeed
Class SFXWeapon_Heavy_FlameThrower_GethTurret extends SFXWeapon_Heavy_Beam_Base
    placeable
    config(Weapon);

var Rotator MuzzleRotation;
var float DamagePerSecond;
var float DamageDuration;
var WwiseEvent WindUpSound;
var WwiseEvent WindDownSound;
var clearcrosslevel SFXPowerCustomActionMP_GethSentryTurret TurretPower;

public simulated function ProcessInstantHit(byte FiringMode, ImpactInfo Impact, optional int NumHits)
{
    local BioPawn BP;
    local SFXModule_GameEffectManager GEM;
    local SFXGameEffect Effect;
    local SFXGameEffect_FireDamageOverTime FireEffect;
    
    Super.ProcessInstantHit(FiringMode, Impact, NumHits);
    BP = BioPawn(Impact.HitActor);
    if (BP != None)
    {
        GEM = BP.GetModule(Class'SFXModule_GameEffectManager');
        if (GEM != None)
        {
            Effect = GEM.GetFirstEffectOfTypeAndCategory(Class'SFXGameEffect_FireDamageOverTime', Name);
            if (Effect != None)
            {
                Effect.CurrentTime = 0.0;
            }
            else
            {
                FireEffect = SFXGameEffect_FireDamageOverTime(GEM.CreateEffect(Class'SFXGameEffect_FireDamageOverTime', Name, DamageDuration, 1, DamagePerSecond, Instigator.Controller));
                if (FireEffect != None)
                {
                    FireEffect.ComboPower = TurretPower;
                    FireEffect.OnApplied();
                }
            }
        }
    }
}
public event simulated function WeaponStoppedFiring(byte FiringMode)
{
    Super(SFXWeapon).WeaponStoppedFiring(FiringMode);
    if (bDummyFireWeapon)
    {
        WeaponPlayWwiseEvent(WindDownSound);
    }
}
public simulated function FireModeUpdated(byte FiringMode, bool bViaReplication)
{
    if (bViaReplication)
    {
        if (int(FiringMode) == 2)
        {
            PlayWindUpEffects();
        }
        else
        {
            PlayWindDownEffects();
        }
    }
    Super(SFXWeapon).FireModeUpdated(FiringMode, bViaReplication);
}
public event simulated function AttachMuzzleEffectsComponents(SkeletalMeshComponent SkelMesh, optional Name MuzzleSocket, optional Name CasingSocket)
{
    local SkeletalMeshComponent OwnerMesh;
    
    OwnerMesh = BioPawn(Instigator).Mesh;
    if (OwnerMesh != None)
    {
        if (PSC_MuzFlashEmitter != None)
        {
            OwnerMesh.AttachComponent(PSC_MuzFlashEmitter, 'Root', vect(0.0, 0.0, 0.0), MuzzleRotation);
            PSC_MuzFlashEmitter.SetDepthPriorityGroup(OwnerMesh.DepthPriorityGroup);
            PSC_MuzFlashEmitter.SetTickGroup(3);
            HideMuzzleFlashEmitter();
        }
    }
}
public simulated function StopMuzzleFlashEffect()
{
    if (bPlayingMuzzleFlashEffect)
    {
        bPlayingMuzzleFlashEffect = FALSE;
        if (PSC_MuzFlashEmitter != None)
        {
            PSC_MuzFlashEmitter.SetActive(FALSE);
            SetTimer(2.0, FALSE, 'HideMuzzleFlashEmitter', );
        }
    }
    bFiringContinuously = FALSE;
}
public simulated function PlayWindDownEffects()
{
    WeaponPlayWwiseEvent(WindDownSound);
}
public simulated function PlayWindUpEffects()
{
    WeaponPlayWwiseEvent(WindUpSound);
}

simulated state WeaponFiring 
{
    public simulated function StopFire(byte FireModeNum)
    {
        Super(SFXWeapon).StopFire(FireModeNum);
        PlayWindDownEffects();
    }
    public simulated function EndState(Name NextStateName)
    {
        ClearFlashCount();
        ClearFlashLocation();
        ClearTimer('RefireCheckTimer');
        NotifyWeaponFinishedFiring(CurrentFireMode);
        SetCurrentFireMode(0);
    }
    public simulated function BeginState(Name PreviousStateName)
    {
        SetCurrentFireMode(2);
        PlayWindUpEffects();
        FireAmmunition();
        TimeWeaponFiring(CurrentFireMode);
    }
    
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=ParticleSystemComponent Name=AmmoPowerHologram
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ParticleSystemComponent Name=AmmoPowerIconHologram
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=ForceFeedbackWaveformBase
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_WeaponModManager Name=ModManager0
    End Template
    Begin Object Class=ParticleSystemComponent Name=MuzFlashPSC0
        Template = ParticleSystem'BioVFX_Crt_FlameThrower.Particles.Flame_Thrower_Geth'
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Template Class=ParticleSystemComponent Name=OutOfAmmoEffect0
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=OutOfAmmoRumble0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=PickupMesh
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ParticleSystemComponent Name=ReloadVent0
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh
        ReplacementPrimitive = None
    End Template
    WindUpSound = WwiseEvent'Wwise_Weapon_Flamethrower.Play_weapon_flamethrower'
    WindDownSound = WwiseEvent'Wwise_Weapon_Flamethrower.Stop_weapon_flamethrower'
    AI_AccCone_Min = {X = 1.20000005, Y = 1.20000005}
    AI_AccCone_Max = {X = 1.20000005, Y = 1.20000005}
    Damage = {X = 15.0, Y = 15.0}
    MagSize = {X = 1000.0, Y = 1000.0}
    MinAimError = {X = 1.60000002, Y = 1.60000002}
    MaxAimError = {X = 4.0, Y = 4.0}
    MinZoomAimError = {X = 0.349999994, Y = 0.349999994}
    MaxZoomAimError = {X = 1.5, Y = 1.5}
    RateOfFire = {X = 750.0, Y = 750.0}
    Recoil = {X = 3.0, Y = 3.0}
    ZoomRecoil = {X = 1.5, Y = 1.5}
    AccFirePenalty = {X = 320.0, Y = 320.0}
    AccFireInterpSpeed = {X = 420.0, Y = 420.0}
    ZoomAccFirePenalty = {X = 40.0, Y = 40.0}
    ZoomAccFireInterpSpeed = {X = 38.0, Y = 38.0}
    MinCrosshairRange = {X = 35.0, Y = 35.0}
    MaxCrosshairRange = {X = 65.0, Y = 65.0}
    MinZoomCrosshairRange = {X = 25.0, Y = 25.0}
    MaxZoomCrosshairRange = {X = 40.0, Y = 40.0}
    AI_BurstFireCount = {X = 15.0, Y = 30.0}
    AI_BurstFireDelay = {X = 0.649999976, Y = 1.0}
    AI_AimDelay = {X = 1.0, Y = 1.0}
    PSC_OutOfAmmoEffect = OutOfAmmoEffect0
    OutOfAmmoRumble = OutOfAmmoRumble0
    WeaponFireWaveForm = ForceFeedbackWaveformBase
    PS_DefaultImpactEffect = ParticleSystem'BioVFX_Crt_FlameThrower.Particles.Flamethrower_Imp'
    PS_DefaultMaterialImpactEffect = None
    DefaultDecalMaterial = MaterialInstanceTimeVarying'BioVFX_C_Blast_Decals.Decals.BlastMark_plusAsh_Decal_INST'
    PSC_ReloadVent = ReloadVent0
    TracerSpawnOffset = 2.0
    PSC_MuzFlashEmitter = MuzFlashPSC0
    RateOfFireAI = 1.0
    RecoilInterpSpeed = 15.0
    RecoilFadeSpeed = 3.0
    RecoilZoomFadeSpeed = 0.949999988
    RecoilYawScale = 0.200000003
    // MILAN CHANGE - Change string refs
    PrettyName = $727548
    ShortPrettyName = $727548
    // END MILAN CHANGE
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    bSuppressTracers = TRUE
    bScaleAnimDurationByFireRate = TRUE
    AnimType = WeaponAnimType.WeaponAnimType_ParticleBeam
    bInfiniteAmmo = TRUE
    InstantHitMomentum = (0.0, 1.0, 0.0, 1.0)
    InstantHitDamageTypes = (None, Class'SFXDamageType_Default', Class'SFXDamageType_GethTurretFlameThrower', Class'SFXDamageType_Default')
    Mesh = WeaponMesh
    PickupFactoryMesh = PickupMesh
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
}