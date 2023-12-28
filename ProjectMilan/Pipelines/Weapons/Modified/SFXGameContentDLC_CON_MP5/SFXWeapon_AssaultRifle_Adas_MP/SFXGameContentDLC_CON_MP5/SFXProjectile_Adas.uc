Class SFXProjectile_Adas_MP extends SFXProjectile_SeekingMissile
    config(Weapon);

// Variables
var WwiseEvent TravelStart;
var WwiseEvent TravelStop;

// Functions
public simulated function Init(Vector Direction)
{
    Super.Init(Direction);
    PlaySound(TravelStart, TRUE);
}
public simulated function ShutDown()
{
    Super.ShutDown();
    PlaySound(TravelStop, TRUE);
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
public function AcquireTarget();


//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    Begin Template Class=PointLightComponent Name=EffectLight0 // MILAN CHANGE - Use weapon light component from GUN01
    End Template
    TravelStart = WwiseEvent'Wwise_Weapons_S_Quarian_AR.Play_wep_s_quarian_proj_lp'
    TravelStop = WwiseEvent'Wwise_Weapons_S_Quarian_AR.Stop_wep_s_quarian_proj_lp'
    ScreenShakeClass = None
    LockedEvent = None
    MaxAngleChange = 0.00524999993
    MaxRetargettingAngle = 0.0258819051
    LC_EffectLight = EffectLight0 // MILAN CHANGE - Add effect light component
    ImpactSound0 = None
    ExplosionSound = WwiseEvent'Wwise_Weapons_S_Quarian_AR.Play_wep_s_quarian_proj_exp'
    fFuseLength = 4.0
    ProjExplosionTemplate = None
    CE_ExplosionTemplate = RvrClientEffect'BioVFX_DLC_Wpn_Quarian_GUN01.VCFX.Quarian_Explosion_VCFX' // MILAN CHANGE - Use GUN01 asset
    ExplosionDecal = None
    AccelRate = 750.0
    TossZ = 0.0
    ExplosionEffectRadius = 50.0
    MinExplodeRumbleDistance = 50.0
    MaxExplodeRumbleDistance = 350.0
    bPlayExplodeForceFeedback = TRUE
    ProjEffectsTrailTemplate = ParticleSystem'BioVFX_DLC_Wpn_Quarian_GUN01.Particles.Quarian_Proj_Trail' // MILAN CHANGE - Use GUN01 asset
    ProjEffectsHeadTemplate = ParticleSystem'BioVFX_DLC_Wpn_Quarian_GUN01.Particles.Quarian_Proj_Head' // MILAN CHANGE - Use GUN01 asset
    MyDamageType = Class'SFXDamageType_Adas'
    Speed = 5000.0
    MaxSpeed = 7500.0
    MomentumTransfer = 100.0
    CylinderComponent = CollisionCylinder
    Components = (CollisionCylinder)
    LifeSpan = 5.0
    CollisionComponent = CollisionCylinder
}