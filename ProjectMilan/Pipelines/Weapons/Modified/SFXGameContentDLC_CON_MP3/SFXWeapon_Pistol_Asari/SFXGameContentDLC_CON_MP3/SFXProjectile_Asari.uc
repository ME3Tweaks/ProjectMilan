Class SFXProjectile_Asari extends SFXProjectile_Proximity
    config(Weapon);

// Variables
var const WwiseEvent NPExplosionSound;
var RvrClientEffectInterface CE_TargetCrustTemplate;
var float HitWallProximityRadius;
var float NewAccelRate;
var const float GravityScale;
var bool bHitWall;

// Functions
public simulated function Explode(Vector HitLocation, Vector HitNormal)
{
    bHitWall = FALSE;
    Super.Explode(HitLocation, HitNormal);
}
public event function HitWall(Vector HitNormal, Actor Wall, PrimitiveComponent WallComp)
{
    if (bShuttingDown || bClientPredictionActive)
    {
        return;
    }
    if (bBouncing)
    {
        bHitWall = TRUE;
        Bounce(Wall, location, HitNormal);
    }
    else
    {
        ImpactedActor = Wall;
        if (!Wall.bStatic && !Wall.bWorldGeometry)
        {
            if (DamageRadius == float(0))
            {
                Wall.TakeDamage(Damage, InstigatorController, location, GetMomentum() * Normal(Velocity), MyDamageType, , Self);
            }
        }
        Explode(location, HitNormal);
        ImpactedActor = None;
        ShutDown();
    }
}
public simulated function Init(Vector Direction)
{
    Super.Init(Direction);
    Velocity = default.Speed * Direction;
    Velocity.Z += TossZ;
    Acceleration = -AccelRate * Normal(Velocity);
    Acceleration.Z = GetGravityZ() * GravityScale;
    bArmed = TRUE;
    if (bRandomizeFuse)
    {
        SetTimer(fFuseLength + FRand() * 0.5, FALSE, , );
    }
    else
    {
        SetTimer(fFuseLength, FALSE, , );
    }
}
public simulated function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    if (bHitWall)
    {
        Acceleration = NewAccelRate * Normal(Velocity);
        Acceleration = AccelRate * Normal(Velocity);
        Acceleration.Z = GetGravityZ() * GravityScale;
    }
}
public function DoImpact(Actor InImpactedActor, Controller InInstigatorController, float BaseDamage, float InDamageRadius, float Momentum, Vector HurtOrigin, bool bFullDamage, out TraceHitInfo HitInfo)
{
    local ImpactInfo Info;
    local SFXWeapon Weapon;
    local BioPawn HitPawn;
    
    Weapon = SFXWeapon(Owner);
    if (Weapon != None && InImpactedActor != None)
    {
        Info.HitActor = InImpactedActor;
        Info.HitLocation = HurtOrigin;
        Info.HitNormal = Normal(HurtOrigin - InImpactedActor.location);
        Info.RayDir = -Info.HitNormal;
        Weapon.__OnWeaponImpact__Delegate(Weapon, Info);
    }
    InImpactedActor.TakeRadiusDamage(InInstigatorController, BaseDamage, InDamageRadius, GetDamageType(), Momentum, HurtOrigin, TRUE, Self, , HitInfo);
    HitPawn = BioPawn(InImpactedActor);
    if ((HitPawn != None && HitPawn.IsHostile(Instigator)) && (!HitPawn.IsPlayerOwned() || !HitPawn.IsInCover()))
    {
        if (HitPawn.Role == ENetRole.ROLE_Authority)
        {
            if (!HitPawn.HasResistance(3))
            {
                if (HitPawn.RequestReaction(3, InInstigatorController))
                {
                    HitPawn.ReplicateAnimatedReaction(HitPawn.CurrentCustomAction);
                    Class'RvrClientEffectManager'.static.GetClientEffectManager().Play(CE_TargetCrustTemplate, HitPawn);
                }
            }
        }
    }
}
public simulated function SpawnExplosionEffects(Vector HitLocation, Vector HitNormal)
{
    local Vector ListenerPosition;
    local Rotator EffectRotation;
    
    SpawnExplosionLightEffects(HitLocation, HitNormal); // MILAN CHANGE - support light effects
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
    if (((Instigator != None && Instigator.IsHumanControlled()) && Instigator.IsLocallyControlled()) && ExplosionSound != None)
    {
        SFXGRI(WorldInfo.GRI).PlayTransientSound(ExplosionSound, HitLocation);
    }
    else if (NPExplosionSound != None && !Instigator.IsHumanControlled())
    {
        SFXGRI(WorldInfo.GRI).PlayTransientSound(NPExplosionSound, HitLocation);
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
public function TickProximity()
{
    local BioPawn BP;
    local SFXWeapon W;
    local BioPawn P;
    
    P = BioPawn(Owner);
    W = SFXWeapon(Owner);
    if (W != None)
    {
        P = BioPawn(W.Owner);
        if (bHitWall)
        {
            foreach VisibleCollidingActors(Class'BioPawn', BP, HitWallProximityRadius, , , , , , )
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
        else
        {
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
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    Begin Template Class=PointLightComponent Name=EffectLight0 // MILAN CHANGE - Light Effect Component
    End Template
    NPExplosionSound = WwiseEvent'Wwise_Crt_Geth_Prime_SFX.Play_crt_geth_prime_wep_energyblast_impact'
    CE_TargetCrustTemplate = RvrClientEffect'BioVFX_DLC_GUN02_Disciple.VCFX.Asari_Pistol_TargetCrust_VCFX' // MILAN CHANGE - Use GUN02 asset
    HitWallProximityRadius = 100.0
    NewAccelRate = 2000.0
    GravityScale = 0.200000003
    ProximityRadius = 25.0
    // MILAN CHANGE - Use light data
    ImpactLightChangeOverLifeKeys = ({
                                      Time = 0.0, 
                                      Brightness = 10.0, 
                                      Color = {B = 255, G = 1, R = 100, A = 0}
                                     }, 
                                     {
                                      Time = 0.100000001, 
                                      Brightness = 2.0, 
                                      Color = {B = 255, G = 1, R = 100, A = 0}
                                     }, 
                                     {
                                      Time = 0.200000003, 
                                      Brightness = 0.0, 
                                      Color = {B = 255, G = 1, R = 100, A = 0}
                                     }
                                    )
    HeadLightColor = {B = 255, G = 1, R = 100, A = 0}
    HeadLightFalloffExponent = 15.0
    LC_EffectLight = EffectLight0
    // END MILAN CHANGE
    ExplosionSound = WwiseEvent'Wwise_Weapons_S_Nesu.Play_wep_s_nesu_impact'
    fFuseLength = 2.0
    CE_ExplosionTemplate = RvrClientEffect'BioVFX_DLC_GUN02_Disciple.VCFX.pistol_Impact_VCFX' // MILAN CHANGE - Use GUN02 asset
    AccelRate = 600.0
    ProjEffectsTrailTemplate = ParticleSystem'BioVFX_DLC_GUN02_Disciple.Particles.Pistol_Proj_Trail' // MILAN CHANGE - Use GUN02 asset
    ProjEffectsHeadTemplate = ParticleSystem'BioVFX_DLC_GUN02_Disciple.Particles.Pistol_Proj' // MILAN CHANGE - Use GUN02 asset
    CoefficientOfRestitution = 0.600000024
    CoefficientOfFriction = 0.699999988
	BounceSound = WwiseEvent'Wwise_Weapons_S_Nesu.Play_wep_s_nesu_wall_impact' // MILAN CHANGE - Use GUN02 asset
    bArcing = FALSE
    MyDamageType = Class'SFXDamageType_Asari'
    MaxSpeed = 4500.0
    MomentumTransfer = 250.0
    CylinderComponent = CollisionCylinder
    Components = (CollisionCylinder)
    CollisionComponent = CollisionCylinder
}