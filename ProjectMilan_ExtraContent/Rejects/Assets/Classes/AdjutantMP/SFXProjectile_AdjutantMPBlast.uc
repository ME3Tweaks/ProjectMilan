Class SFXProjectile_AdjutantMPBlast extends SFXProjectile_SeekingMissile
    config(Weapon);

var transient SFXPawn_AdjutantMP OwnerPawn;
var const WwiseEvent BeginFlightSound;
var const WwiseEvent EndFlightSound;
var const float WallOffset;
var bool bHitWall;

public simulated function Explode(Vector HitLocation, Vector HitNormal)
{
    Super.Explode(HitLocation, HitNormal);
    if (OwnerPawn != None)
    {
        OwnerPawn.ExplodeBlast(Self, HitNormal);
    }
}
public event function HitWall(Vector HitNormal, Actor Wall, PrimitiveComponent WallComp)
{
    bHitWall = TRUE;
    Super(SFXProjectile_Explosive).HitWall(HitNormal, Wall, WallComp);
}
public simulated function Init(Vector Direction)
{
    Super.Init(Direction);
    if (BeginFlightSound != None && EndFlightSound != None)
    {
        PlaySound(BeginFlightSound);
    }
}
public simulated function Recycle()
{
    Super.Recycle();
    bHitWall = FALSE;
}
public simulated function ShutDown()
{
    if (IsShuttingDown())
    {
        return;
    }
    if (BeginFlightSound != None && EndFlightSound != None)
    {
        PlaySound(EndFlightSound);
    }
    Super.ShutDown();
}
public simulated function float GetDamageRadius()
{
    return DamageRadius;
}
public function ProcessTouch(Actor Other, Vector HitLocation, Vector HitNormal)
{
    local BioPawn ChkPawn;
    
    ChkPawn = BioPawn(Other);
    if (ChkPawn != None && Instigator.IsHostile(ChkPawn))
    {
        bHitWall = FALSE;
        Explode(HitLocation, HitNormal);
        if (IsShuttingDown() == FALSE)
        {
            ShutDown();
        }
    }
}
public function DoImpact(Actor InImpactedActor, Controller InInstigatorController, float BaseDamage, float InDamageRadius, float Momentum, Vector HurtOrigin, bool bFullDamage, out TraceHitInfo HitInfo)
{
    local BioPawn HitPawn;
    
    HitPawn = BioPawn(InImpactedActor);
    if (HitPawn != None && !HitPawn.IsDead() && Instigator.IsHostile(HitPawn))
    {
        if (HitPawn.Role == ENetRole.ROLE_Authority)
        {
            HitPawn.RequestReaction(1, InInstigatorController, Normal(InImpactedActor.location - HurtOrigin) * Momentum);
        }
    }
    Super(SFXProjectile_Explosive).DoImpact(InImpactedActor, InInstigatorController, BaseDamage, InDamageRadius, Momentum, HurtOrigin, bFullDamage, HitInfo);
}
public simulated function Fire(Actor NewTarget)
{
    AcquiredTarget = BioPawn(NewTarget);
    Init(Vector(Rotation));
}
public simulated function float GetDamage()
{
    return Damage;
}
public function Vector GetEffectLocation(Vector HitNormal)
{
    if (bHitWall)
    {
        return location + HitNormal * WallOffset;
    }
    else
    {
        return location;
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        CollisionHeight = 30.0
        CollisionRadius = 30.0
        ReplacementPrimitive = None
        CollideActors = TRUE
    End Template
    Begin Template Class=PointLightComponent Name=EffectLight0
    End Template
    BeginFlightSound = WwiseEvent'Wwise_Crt_DLC_Omega_Adjutant.Play_crt_omega_adjutant_weap_proj'
    EndFlightSound = WwiseEvent'Wwise_Crt_DLC_Omega_Adjutant.Stop_crt_omega_adjutant_weap_proj'
    WallOffset = 50.0
    MaxAngleChange = 0.0149999997
    LC_EffectLight = EffectLight0
    ExplosionSound = WwiseEvent'Wwise_Crt_DLC_Omega_Adjutant.Play_crt_omega_adjutant_weap_impact'
    ProjExplosionTemplate = None
    ExplosionDecal = None
    fFuseLength = 13.0
    AccelRate = 200.0
    TossZ = 25.0
    ProjEffectsTrailTemplate = None
    ProjEffectsHeadTemplate = None
    CE_ProjectileTemplate = RvrClientEffect'BioVFX_Exp2_Adj.VCFX.BioticSmoke_Projectile_VCFX'
    MyDamageType = Class'SFXDamageType_AdjutantBlast'
    CylinderComponent = CollisionCylinder
    Speed = 1000.0
    MaxSpeed = 1400.0
    Damage = 150.0
    DamageRadius = 25.0
    MomentumTransfer = 25.0
    bRotationFollowsVelocity = TRUE
    Components = (CollisionCylinder)
    CollisionComponent = CollisionCylinder
    LifeSpan = 15.0
    bProjTarget = TRUE
}