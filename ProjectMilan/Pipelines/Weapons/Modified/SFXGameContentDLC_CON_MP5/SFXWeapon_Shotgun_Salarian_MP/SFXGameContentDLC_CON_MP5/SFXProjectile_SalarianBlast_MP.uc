// MILAN CHANGE - 12/27/2023
// By: Mgamerz
// Purpose: Use GUN02 light effect component (GUN02 assets were already used in MP5 it seems)
Class SFXProjectile_SalarianBlast_MP extends SFXProjectile_Explosive
    config(Weapon);

// Variables
var const float GravityScale;
var const WwiseEvent NPCExplosionSound;

// Functions
public simulated function Init(Vector Direction)
{
    Super.Init(Direction);
    Acceleration.X = 0.0;
    Acceleration.Y = 0.0;
    Acceleration.Z = GetGravityZ() * GravityScale;
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

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    Begin Template Class=PointLightComponent Name=EffectLight0 // MILAN CHANGE - Add EffectLight
    End Template
    GravityScale = 0.5
    LC_EffectLight = EffectLight0 // MILAN CHANGE - Add EffectLight
    NPCExplosionSound = WwiseEvent'Wwise_Weapons_S_SalShot.Play_wep_np_salarianshotgun_shard_explode'
    ExplosionSound = WwiseEvent'Wwise_Weapons_S_SalShot.Play_wep_p_salarianshotgun_shard_explode'
    fFuseLength = 2.0
    CE_ExplosionTemplate = RvrClientEffect'BioVFX_Wpn_BLS_M_GUN02.VCFX.BLSM_Pulse_VCFX'
    ExplosionDecal = None
    MinExplodeRumbleDistance = 50.0
    MaxExplodeRumbleDistance = 250.0
    bPlayExplodeForceFeedback = TRUE
    ProjEffectsTrailTemplate = ParticleSystem'BioVFX_Wpn_BLS_M_GUN02.Particles.BLSPulse_Proj_Trail'
    ProjEffectsHeadTemplate = ParticleSystem'BioVFX_Wpn_BLS_M_GUN02.Particles.BLSMPulse_ProjectileHead'
    MyDamageType = Class'SFXDamageType_SalarianBlast_MP'
    Speed = 5000.0
    MaxSpeed = 5000.0
    DamageRadius = 150.0
    CylinderComponent = CollisionCylinder
    bRotationFollowsVelocity = TRUE
    Components = (CollisionCylinder)
    CollisionComponent = CollisionCylinder
}