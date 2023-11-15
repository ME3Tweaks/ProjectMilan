Class SFXProjectile_ConsumableRocket extends SFXProjectile_Explosive
    config(Weapon);

// Variables
var const Class<SFXRumble_Power> RumbleClass;
var const Class<SFXShake_Power> ScreenShakeClass;
var config float GibRange;

// Functions
public simulated function Explode(Vector HitLocation, Vector HitNormal)
{
    local SFXPlayerController PC;
    local float fDistance;
    local float fScale;
    local ForceFeedbackWaveform Rumble;
    local ScreenShakeStruct Shake;
    local int idx;
    
    if (IsShuttingDown() || bClientPredictionActive)
    {
        return;
    }
    Super.Explode(HitLocation, HitNormal);
    if (bArmed)
    {
        return;
    }
    PC = SFXPlayerController(WorldInfo.GetALocalPlayerController());
    if ((PC != None && PC.Pawn != None) && PC.IsLocalPlayerController())
    {
        fDistance = VSize(PC.Pawn.location - HitLocation);
        fScale = RadiusFallOff(fDistance, RumbleClass.default.MaxDetonationRumbleDistance, RumbleClass.default.MinDetonationRumbleDistance);
        if (fScale > 0.0)
        {
            Rumble = RumbleClass.default.TheWaveForm;
            if (fScale < 1.0)
            {
                for (idx = 0; idx < Rumble.Samples.Length; idx++)
                {
                    Rumble.Samples[idx].LeftAmplitude *= fScale;
                    Rumble.Samples[idx].RightAmplitude *= fScale;
                }
            }
            PC.ClientPlayForceFeedbackWaveform(Rumble);
        }
        fScale = RadiusFallOff(fDistance, ScreenShakeClass.default.MaxDetonationShakeDistance, ScreenShakeClass.default.MinDetonationShakeDistance);
        if (fScale > 0.0)
        {
            Shake = ScreenShakeClass.default.TheShake;
            if (fScale < 1.0)
            {
                Shake.RotAmplitude *= fScale;
                Shake.LocAmplitude *= fScale;
                Shake.FOVAmplitude *= fScale;
            }
            SFXPlayerCamera(PC.PlayerCamera).AddScreenShake(Shake);
        }
    }
}
public simulated function float GetDamageRadius()
{
    local SFXWeapon_Heavy_ConsumableRocketLauncher Launcher;
    
    Launcher = SFXWeapon_Heavy_ConsumableRocketLauncher(ProjectileOwner);
    if (Launcher == None)
    {
        return Super(SFXProjectile).GetDamageRadius();
    }
    else
    {
        return Launcher.DamageRadius;
    }
}
public function bool ProjectileHurtRadius(float InDamageAmount, float InDamageRadius, float Momentum, Vector HurtOrigin, Vector HitNormal)
{
    local bool bCausedDamage;
    local Actor Victim;
    local TraceHitInfo HitInfo;
    
    if (bHurtEntry)
    {
        return FALSE;
    }
    bHurtEntry = TRUE;
    bCausedDamage = FALSE;
    if (ImpactedActor != None && ImpactedActor != Self)
    {
        DoImpact(ImpactedActor, InstigatorController, InDamageAmount, InDamageRadius, Momentum, HurtOrigin, TRUE, HitInfo);
        if (ImpactedActor != None)
        {
            bCausedDamage = ImpactedActor.bProjTarget;
        }
    }
    foreach CollidingActors(Class'Actor', Victim, InDamageRadius, HurtOrigin, , , )
    {
        if ((((Victim.CollisionComponent != None && !Victim.bWorldGeometry) && Victim != Self) && Victim != ImpactedActor) && (Victim.bProjTarget || NavigationPoint(Victim) == None))
        {
            DoImpact(Victim, InstigatorController, InDamageAmount, InDamageRadius, Momentum, HurtOrigin, FALSE, HitInfo);
            bCausedDamage = bCausedDamage || Victim.bProjTarget;
        }
    }
    bHurtEntry = FALSE;
    return bCausedDamage;
}
public function DoImpact(Actor InImpactedActor, Controller InInstigatorController, float BaseDamage, float InDamageRadius, float Momentum, Vector HurtOrigin, bool bFullDamage, out TraceHitInfo HitInfo)
{
    local BioPawn oPawn;
    local Class<SFXDamageType_ConsumableRocket> DamType;
    local float fDistance;
    local float fScale;
    local float fScaledDamage;
    
    DamType = Class'SFXDamageType_ConsumableRocket';
    oPawn = BioPawn(InImpactedActor);
    if (oPawn != None && oPawn.bCanRagdoll)
    {
        if (VSize(HurtOrigin - InImpactedActor.location) < GibRange)
        {
            DamType = Class'SFXDamageType_ConsumableRocketGib';
        }
        else if (int(oPawn.GetTeamNum()) != 0)
        {
            oPawn.AddRagdollImpulse(Normal(InImpactedActor.location - HurtOrigin) * Momentum, InInstigatorController);
        }
    }
    fDistance = VSize(location - InImpactedActor.location);
    fScale = RadiusFallOff(fDistance, DamType.default.DamageRadius, GetCappedDamageRadius());
    fScaledDamage = Lerp(GetFarDamage(), BaseDamage, fScale);
    InImpactedActor.TakeDamage(fScaledDamage, InInstigatorController, HurtOrigin, vect(0.0, 0.0, 0.0), DamType, , Self);
}
public final simulated function float GetCappedDamageRadius()
{
    local SFXWeapon_Heavy_ConsumableRocketLauncher Launcher;
    
    Launcher = SFXWeapon_Heavy_ConsumableRocketLauncher(ProjectileOwner);
    if (Launcher == None)
    {
        return 0.0;
    }
    else
    {
        return Launcher.CappedDamageRadius;
    }
}
public final simulated function float GetFarDamage()
{
    local SFXWeapon_Heavy_ConsumableRocketLauncher Launcher;
    
    Launcher = SFXWeapon_Heavy_ConsumableRocketLauncher(ProjectileOwner);
    if (Launcher == None)
    {
        return 0.0;
    }
    else
    {
        return Launcher.FarDamage;
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    RumbleClass = Class'SFXRumble_ConsumableRocket'
    ScreenShakeClass = Class'SFXShake_ConsumableRocket'
    GibRange = 200.0
    ExplosionSound = WwiseEvent'Wwise_Generic_Explosions.Play_gen_exp_wep_titan_explode'
    fFuseLength = 100.0
    CE_ExplosionTemplate = RvrClientEffect'BioVFX_Crt_Atlas.VCFX.Missile_Imp_Crt_VCFX'
    AccelRate = 75.0
    ProjEffectsTrailTemplate = ParticleSystem'BioVFX_C_Wpn_Titan.Particles.Titan_RPG_Projectile_1_Trail'
    ProjEffectsHeadTemplate = ParticleSystem'BioVFX_C_Wpn_Titan.Particles.Titan_RPG_Projectile_1_Base'
    MyDamageType = Class'SFXDamageType_ConsumableRocket'
    Speed = 4500.0
    MaxSpeed = 4500.0
    MomentumTransfer = 1000.0
    CylinderComponent = CollisionCylinder
    Components = (CollisionCylinder)
    LifeSpan = 10.0
    CollisionComponent = CollisionCylinder
}