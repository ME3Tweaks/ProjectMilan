// MILAN CHANGE - 12/27/2023
// By: Mgamerz
// Purpose: Use GUN02 light effects (GUN02 assets were already used in MP5 it seems)
Class SFXProjectile_SalarianBlastSplitter_MP extends SFXProjectile_SeekingMissile
    config(Weapon);

// Variables
var float GravityScale;
var float HitGravityScale;
var config int NumShardsToSpawn;
var float ProximityRadius;
var float ProximityRadiusTightAim;
var float PercentVelocityInherited;
var float ConeAngle;
var config float ExplosionDamage;
var const WwiseEvent NPCExplosionSound;
var bool bHitTarget;

// Functions
public simulated function Explode(Vector HitLocation, Vector HitNormal)
{
    local Vector SpawnLoc;
    local float VelDotN;
    local Vector Reflect;
    local Vector ProjDir;
    local int idx;
    local SFXObjectPool Pool;
    local SFXProjectile_SalarianBlastShard_MP Shard;
    local BioPawn HitPawn;
    
    if (IsShuttingDown() || bClientPredictionActive)
    {
        return;
    }
    if (Role == ENetRole.ROLE_Authority)
    {
        if (ImpactedActor == None)
        {
            SpawnLoc = location;
            Reflect = Normal(Velocity);
        }
        else
        {
            SpawnLoc = HitLocation + HitNormal * 15.0;
            VelDotN = Velocity Dot HitNormal;
            Reflect = Normal(Velocity - (float(2) * VelDotN) * HitNormal);
            HitPawn = BioPawn(ImpactedActor);
            if (HitPawn != None)
            {
                bHitTarget = TRUE;
            }
            else
            {
                bHitTarget = FALSE;
            }
        }
        Pool = SFXGRI(WorldInfo.GRI).ObjectPool;
        if (Pool != None)
        {
            for (idx = 0; idx < NumShardsToSpawn; idx++)
            {
                Shard = Pool.GetProjectile(Class'SFXProjectile_SalarianBlastShard_MP', Owner, Instigator, SpawnLoc, Rotation);
                if (Shard != None)
                {
                    Shard.Instigator = Instigator;
                    Shard.bSuppressAudio = bSuppressAudio;
                    ProjDir = VRandCone(Reflect, ConeAngle);
                    if (bHitTarget)
                    {
                        Shard.GravityScale = HitGravityScale;
                    }
                    Shard.Init(ProjDir);
                    Shard.Velocity += (ProjDir * PercentVelocityInherited) * Speed;
                }
            }
        }
    }
    Super.Explode(HitLocation, HitNormal);
}
public simulated function Init(Vector Direction)
{
    Super.Init(Direction);
    Acceleration.X = 0.0;
    Acceleration.Y = 0.0;
    Acceleration.Z = GetGravityZ() * GravityScale;
}
public simulated function Tick(float DeltaTime)
{
    Super(SFXProjectile).Tick(DeltaTime);
    if (bExplodeNextFrame)
    {
        if (!IsShuttingDown())
        {
            SetTimer(0.00100000005, FALSE, , );
        }
        return;
    }
    if (!bStopAiming)
    {
        TickNPC(DeltaTime);
    }
}
public function ProcessTouch(Actor Other, Vector HitLocation, Vector HitNormal)
{
    local BioPawn ChkPawn;
    
    ChkPawn = BioPawn(Other);
    if (ChkPawn != None && Instigator.IsHostile(ChkPawn))
    {
        Explode(HitLocation, HitNormal);
        if (IsShuttingDown() == FALSE)
        {
            ShutDown();
        }
    }
}
public function DoImpact(Actor InImpactedActor, Controller InInstigatorController, float BaseDamage, float InDamageRadius, float Momentum, Vector HurtOrigin, bool bFullDamage, out TraceHitInfo HitInfo)
{
    local ImpactInfo Info;
    local SFXWeapon Weapon;
    
    Weapon = SFXWeapon(Owner);
    if (Weapon != None && InImpactedActor != None)
    {
        Info.HitActor = InImpactedActor;
        Info.HitLocation = HurtOrigin;
        Info.HitNormal = Normal(HurtOrigin - InImpactedActor.location);
        Info.RayDir = -Info.HitNormal;
        Weapon.__OnWeaponImpact__Delegate(Weapon, Info);
    }
    Super(SFXProjectile_Explosive).DoImpact(InImpactedActor, InInstigatorController, BaseDamage, InDamageRadius, Momentum, HurtOrigin, bFullDamage, HitInfo);
}
public simulated function float GetDamage()
{
    return ExplosionDamage;
}
public simulated function SpawnExplosionEffects(Vector HitLocation, Vector HitNormal)
{
    local Rotator EffectRotation;
    local Vector ListenerPosition;
    
    if (ProjExplosionTemplate != None)
    {
        EffectRotation = Rotator(HitNormal) + rot(-16384, 0, 0);
        SFXGRI(WorldInfo.GRI).DuringAsyncWorker.SpawnEffectAtLocation(Instigator, ProjExplosionTemplate, location, EffectRotation, ExplosionParticleLifetime);
    }
    if (ExplosionDecal != None && Pawn(ImpactedActor) == None)
    {
        SFXGRI(WorldInfo.GRI).DuringAsyncWorker.SpawnImpactDecalAtLocation(Instigator, ExplosionDecal, HitLocation, HitNormal, DecalWidth, DecalHeight, 5.0, TRUE, DurationOfDecal);
    }
    if (CE_ExplosionTemplate != None)
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayAtLocation(CE_ExplosionTemplate, HitLocation);
    }
    if (((ExplosionSound != None && !bSuppressAudio) && Instigator != None) && Instigator.IsLocallyControlled())
    {
        SFXGRI(WorldInfo.GRI).PlayTransientSound(ExplosionSound, HitLocation);
    }
    else if (NPCExplosionSound != None && !bSuppressAudio)
    {
        SFXGRI(WorldInfo.GRI).PlayTransientSound(NPCExplosionSound, HitLocation);
    }
    if (AdditionalExplosionSound != None && !bSuppressAudio)
    {
        SFXGRI(WorldInfo.GRI).PlayTransientSound(AdditionalExplosionSound, HitLocation);
    }
    if (bDuckAudio)
    {
        ListenerPosition = Class'WwiseAudioComponent'.static.GetMicPosition();
        if (VSize(ListenerPosition - HitLocation) < DuckDistanceThreshold)
        {
            PlaySound(WwiseDuckEvent, TRUE);
        }
    }
    bSuppressExplosionFX = TRUE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    Begin Template Class=PointLightComponent Name=EffectLight0 // MILAN CHANGE - Add effect light
    End Template
    GravityScale = 0.5
    HitGravityScale = 5.0
    NumShardsToSpawn = 3
    ProximityRadius = 150.0
    ProximityRadiusTightAim = 150.0
    ConeAngle = 0.449999988
    ExplosionDamage = 1.0
    NPCExplosionSound = WwiseEvent'Wwise_Weapons_S_SalShot.Play_wep_np_salarianshotgun_impact_high' // MILAN NOTE: Need to check if this is in GUN02 soundbank events
    MaxAngleChange = 0.000524999981
    MaxRetargettingAngle = 0.00258819037
    ExplosionSound = WwiseEvent'Wwise_Weapons_S_SalShot.Play_wep_p_salarianshotgun_impact_high'
    fFuseLength = 2.0
    ProjExplosionTemplate = None
    CE_ExplosionTemplate = RvrClientEffect'BioVFX_Wpn_BLS_M_GUN02.VCFX.BLSM_Pulse_VCFX'
    ExplosionDecal = None
    MinExplodeRumbleDistance = 50.0
    MaxExplodeRumbleDistance = 250.0
    bPlayExplodeForceFeedback = TRUE
    ProjEffectsTrailTemplate = ParticleSystem'BioVFX_Wpn_BLS_M_GUN02.Particles.Mirv_Projectile_Trail'
    ProjEffectsHeadTemplate = ParticleSystem'BioVFX_Wpn_BLS_M_GUN02.Particles.Mirv_ProjectileHead'
    MyDamageType = Class'SFXDamageType_SalarianBlast_MP'
    Speed = 5000.0
    MaxSpeed = 5000.0
    DamageRadius = 150.0
    MomentumTransfer = 100.0
    CylinderComponent = CollisionCylinder
    bRotationFollowsVelocity = TRUE
    Components = (CollisionCylinder)
    CollisionComponent = CollisionCylinder
}