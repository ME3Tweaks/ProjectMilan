// MILAN CHANGE - 12/27/2023
// By: Mgamerz
// Purpose: Use GUN02 light effects (GUN02 assets were already used in MP5 it seems)
Class SFXProjectile_SalarianBlastShard_MP extends SFXProjectile_Proximity
    config(Weapon);

// Variables
var float GravityScale;
var config transient float ExplosionDamage;
var config transient float ExplosionRadius;
var transient float ExplosionDelay;
var float LowShardExplosionDelay;
var float HighShardExplosionDelay;
var const WwiseEvent NPCExplosionSound;

// Functions
public simulated function Explode(Vector HitLocation, Vector HitNormal)
{
    local SFXPawn P;
    local Vector AltOrigin;
    
    if (IsShuttingDown() || bClientPredictionActive)
    {
        return;
    }
    if (Role == ENetRole.ROLE_Authority)
    {
        foreach WorldInfo.AllPawns(Class'SFXPawn', P, location)
        {
            if ((P != Instigator && VSize(P.location - location) < ExplosionRadius + P.CylinderComponent.CollisionRadius) && P.IsHostile(Instigator))
            {
                if (P.FastTrace(location, P.CollisionComponent.Bounds.Origin, , TRUE) == FALSE)
                {
                    AltOrigin = location + Class'BioPawn'.default.MaxStepHeight * HitNormal;
                    if (P.FastTrace(location, AltOrigin, , TRUE) == FALSE)
                    {
                        if (IsZero(Velocity) == FALSE)
                        {
                            AltOrigin = location + Class'BioPawn'.default.MaxStepHeight * -Normal(Velocity);
                            if (P.FastTrace(location, AltOrigin, , TRUE) == FALSE)
                            {
                                continue;
                            }
                        }
                        else
                        {
                            continue;
                        }
                    }
                }
                P.TakeRadiusDamage(InstigatorController, ExplosionDamage, ExplosionRadius, MyDamageType, 20.0, location, TRUE, Self);
                if (P.RequestReaction(1, InstigatorController, Normal(P.location - location) * 10.0))
                {
                    P.ReplicateAnimatedReaction(P.CurrentCustomAction);
                }
            }
        }
    }
    Super.Explode(HitLocation, HitNormal);
}
public simulated function Init(Vector Direction)
{
    Super(SFXProjectile_Explosive).Init(Direction);
    Acceleration.X = 0.0;
    Acceleration.Y = 0.0;
    Acceleration.Z = GetGravityZ() * GravityScale;
    ExplosionDelay = RandRange(LowShardExplosionDelay, HighShardExplosionDelay);
    SetTimer(FMax(0.100000001, ExplosionDelay), FALSE, 'Detonate', );
}
public simulated function Recycle()
{
    Super.Recycle();
    GravityScale = default.GravityScale;
}
public function ProcessTouch(Actor Other, Vector HitLocation, Vector HitNormal)
{
    local BioPawn BP;
    local SFXWeapon W;
    local BioPawn P;
    
    P = BioPawn(Owner);
    W = SFXWeapon(Owner);
    if (W != None)
    {
        P = BioPawn(W.Owner);
        foreach VisibleCollidingActors(Class'BioPawn', BP, ProximityRadius, , , , , , )
        {
            if (!BP.IsDead())
            {
                if (BP.IsHostile(P))
                {
                    Explode(location, Normal(BP.location - location));
                    return;
                }
            }
        }
    }
    Super(SFXProjectile_Explosive).ProcessTouch(Other, HitLocation, HitNormal);
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
    Super.DoImpact(InImpactedActor, InInstigatorController, BaseDamage, InDamageRadius, Momentum, HurtOrigin, bFullDamage, HitInfo);
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
public function Detonate()
{
    Explode(location, -Vector(Rotation));
    if (IsShuttingDown() == FALSE)
    {
        ShutDown();
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    Begin Template Class=PointLightComponent Name=EffectLight0 // MILAN CHANGE - Add EffectLight
    End Template
    GravityScale = 0.699999988
    ExplosionDamage = 1.0
    ExplosionRadius = 150.0
    LowShardExplosionDelay = 1.5
    HighShardExplosionDelay = 2.5
    NPCExplosionSound = WwiseEvent'Wwise_Weapons_S_SalShot.Play_wep_np_salarianshotgun_shard_explode'
    ProximityRadius = 75.0
    LC_EffectLight = EffectLight0 // MILAN CHANGE - Add EffectLight
    ExplosionSound = WwiseEvent'Wwise_Weapons_S_SalShot.Play_wep_p_salarianshotgun_shard_explode'
    CE_ExplosionTemplate = RvrClientEffect'BioVFX_Wpn_BLS_M_GUN02.VCFX.Grenade_Explosion_VCFX'
    ExplosionDecal = None
    MinExplodeRumbleDistance = 50.0
    MaxExplodeRumbleDistance = 250.0
    bPlayExplodeForceFeedback = TRUE
    ProjEffectsTrailTemplate = ParticleSystem'BioVFX_Wpn_BLS_M_GUN02.Particles.Grenade_ProjTrail'
    ProjEffectsHeadTemplate = ParticleSystem'BioVFX_Wpn_BLS_M_GUN02.Particles.Grenade_Projectile_Head'
    CoefficientOfRestitution = 0.699999988
    CoefficientOfFriction = 0.400000006
    BounceSound = WwiseEvent'Wwise_Weapons_S_SalShot.Play_wep_s_salshot_bounce'
    MyDamageType = Class'SFXDamageType_SalarianShard_MP'
    Speed = 900.0
    MaxSpeed = 3000.0
    MomentumTransfer = 250.0
    CylinderComponent = CollisionCylinder
    Components = (CollisionCylinder)
    CollisionComponent = CollisionCylinder
}