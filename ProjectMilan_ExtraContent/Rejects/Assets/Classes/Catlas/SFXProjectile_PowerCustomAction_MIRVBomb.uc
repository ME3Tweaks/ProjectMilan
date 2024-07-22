Class SFXProjectile_PowerCustomAction_MIRVBomb extends SFXProjectile_PowerCustomAction_Grenade
    config(Game);

var Class<Projectile> ShardClass;
var int NumShardsToSpawn;
var const float TargetDistanceThreshold;
var const float TargetCoverDistanceThreshold;
var transient bool bTargetInCover;

public simulated function Explode(Vector HitLocation, Vector HitNormal)
{
    local Vector SpawnLoc;
    local float VelDotN;
    local Vector Reflect;
    local Vector ProjDir;
    local int idx;
    local SFXObjectPool Pool;
    local SFXProjectile_MIRVShard Shard;
    
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
            Reflect = Normal(Velocity - float(2) * VelDotN * HitNormal);
        }
        Pool = SFXGRI(WorldInfo.GRI).ObjectPool;
        if (Pool != None)
        {
            for (idx = 0; idx < NumShardsToSpawn; idx++)
            {
                Shard = SFXProjectile_MIRVShard(Pool.GetProjectile(ShardClass, Self, Instigator, SpawnLoc, Rotation));
                if (Shard != None)
                {
                    Shard.Instigator = Instigator;
                    Shard.bSuppressAudio = bSuppressAudio;
                    ProjDir = VRandCone(Reflect, 0.707000017);
                    Shard.Init(ProjDir);
                }
            }
        }
    }
    Super.Explode(HitLocation, HitNormal);
}
public simulated function Init(Vector Direction)
{
    local SFXDifficultyHandler DH;
    
    Super(SFXProjectile_PowerCustomAction).Init(Direction);
    DH = SFXGRI(WorldInfo.GRI).DifficultyHandler;
    if (DH != None)
    {
        NumShardsToSpawn = 5;
    }
}
public simulated function Tick(float DeltaTime)
{
    local float Dist;
    
    if (bActive && (TargetLocation.X != 0.0 || TargetLocation.Y != 0.0 || TargetLocation.Z != 0.0))
    {
        Dist = VSize(location - TargetLocation);
        if (bTargetInCover == FALSE && Dist < TargetDistanceThreshold || bTargetInCover && Dist <= TargetCoverDistanceThreshold)
        {
            Explode(location, -Vector(Rotation));
            if (IsShuttingDown() == FALSE)
            {
                ShutDown();
            }
        }
    }
    Super.Tick(DeltaTime);
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

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    Begin Template Class=PointLightComponent Name=EffectLight0
    End Template
    ShardClass = Class'SFXProjectile_MIRVShard'
    TargetDistanceThreshold = 500.0
    TargetCoverDistanceThreshold = 255.0
    SpeedThresholdFuseLength = 5.0
    LC_EffectLight = EffectLight0
    ExplosionSound = WwiseEvent'Wwise_Crt_DLC_CITSpecial.Play_crt_cit_specialist_grenadesplit'
    TossZ = 0.0
    MinExplodeRumbleDistance = 50.0
    MaxExplodeRumbleDistance = 250.0
    bUseHurtRadius = FALSE
    bPlayExplodeForceFeedback = TRUE
    MyDamageType = Class'SFXDamageType_MIRVBlast'
    CylinderComponent = CollisionCylinder
    bRotationFollowsVelocity = TRUE
    Components = (CollisionCylinder)
    CollisionComponent = CollisionCylinder
    ProjEffectsTrailTemplate = ParticleSystem'BioVFX_Crt_Atlas.Particles.Atlas_RPG_ProjTrail'
    ProjEffectsHeadTemplate = ParticleSystem'BioVFX_Crt_Atlas.Particles.Atlas_RPG_ProjBase'
    RotationsPerSecond = 0.0
}