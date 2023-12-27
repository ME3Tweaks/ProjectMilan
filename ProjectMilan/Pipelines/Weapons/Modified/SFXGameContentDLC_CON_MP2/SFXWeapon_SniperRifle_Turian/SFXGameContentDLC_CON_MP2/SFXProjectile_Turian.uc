// MILAN CHANGE
// By: Mgamerz
// Purpose: Use LE assets, add LE lighting effects
Class SFXProjectile_Turian extends SFXProjectile_Proximity
    config(Weapon);

// Variables
var const WwiseEvent NPExplosionSound;

// Functions
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
    local Vector ListenerPosition;
    local Rotator EffectRotation;
    
    SpawnExplosionLightEffects(HitLocation, HitNormal); // MILAN Change - Use GUN01 lighting effect
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

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    Begin Template Class=PointLightComponent Name=EffectLight0 // MILAN Change - Add effect light component from GUN01
    End Template
    
    NPExplosionSound = WwiseEvent'Wwise_Weapons_S_Turian_SP.Play_wep_np_turian_projectile_expl_SP' // MILAN Change - Use GUN01 asset
    ExplosionSound = WwiseEvent'Wwise_Weapons_S_Turian_SP.Play_wep_p_turian_projectile_expl_SP' // MILAN Change - Use GUN01 asset
    
    // MILAN Change - light effect properties
    ImpactLightChangeOverLifeKeys = ({
                                      Time = 0.0, 
                                      Brightness = 10.0, 
                                      Color = {B = 1, G = 120, R = 255, A = 0}
                                     }, 
                                     {
                                      Time = 0.100000001, 
                                      Brightness = 2.0, 
                                      Color = {B = 1, G = 70, R = 255, A = 0}
                                     }, 
                                     {
                                      Time = 0.200000003, 
                                      Brightness = 0.0, 
                                      Color = {B = 1, G = 70, R = 255, A = 0}
                                     }
                                    )
    LC_EffectLight = EffectLight0
    HeadLightColor = {B = 1, G = 120, R = 255, A = 0}
    HeadLightFalloffExponent = 15.0
    ImpactLightRadius = 800.0
    // END MILAN Change
    CE_ExplosionTemplate = RvrClientEffect'BioVFX_C_Carnage.VCFX.Carnage_Impact_VCFX'
    AccelRate = 1200.0
    ProjEffectsTrailTemplate = ParticleSystem'BioVFX_DLC_Wpn_SNPl_GUN01.Particles.Projectile_Trail' // MILAN CHANGE - Use Gun01 Asset
    ProjEffectsHeadTemplate = ParticleSystem'BioVFX_DLC_Wpn_SNPl_GUN01.Particles.Projectile_Head' // MILAN CHANGE - Use Gun01 Asset
    bArcing = FALSE
    bBouncing = FALSE
    MyDamageType = Class'SFXDamageType_Turian'
    Speed = 5000.0
    MaxSpeed = 7000.0
    MomentumTransfer = 250.0
    CylinderComponent = CollisionCylinder
    Components = (CollisionCylinder)
    CollisionComponent = CollisionCylinder
}