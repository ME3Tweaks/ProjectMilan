// MILAN CHANGE - 11/04/2026
// By Mgamerz
// Fix LE3's banshee teleport projectile lasting too long and looking bad.
// It doesn't shut down quickly like in OT, which can look cool, but banshee
// teleports way more in MP and it's super obvious it's a bug
Class SFXProjectile_BansheePhase extends SFXProjectile_Explosive
    config(Weapon);

public simulated function Init(Object.Vector Direction)
{
    Super.Init(Direction);
    ProjEffectsHead.SetScale(2.0);
}

// MILAN CHANGE - Mgamerz - 2026-11-03
// On shutdown kill the particle system
public simulated function ShutDown()
{
    if (bShuttingDown)
    {
        return;
    }

    Super.ShutDown();

    if (ProjEffectsHead != None)
    {
        ProjEffectsHead.KillParticlesForced();
    }
}
// END MILAN CHANGE

defaultproperties
{
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    Begin Template Class=PointLightComponent Name=EffectLight0
    End Template
    LC_EffectLight = EffectLight0
    ExplosionSound = WwiseEvent'Wwise_Crt_Reap_Banshee_SFX.Play_crt_reap_banshee_sfx_teleport'
    AdditionalExplosionSound = WwiseEvent'Wwise_Crt_Reap_Banshee_SFX.Play_crt_reap_banshee_voc_charge_teleport'
    WwiseDuckEvent = None
    CE_ExplosionTemplate = RvrClientEffect'BioVFX_B_Warp.VCFX.Warp_Impact_VCFX'
    ExplosionDecal = None
    bRandomizeFuse = FALSE
    ProjEffectsHeadTemplate = ParticleSystem'BioVFX_B_Vanguard.Particles.Shepard_Blur'
    CylinderComponent = CollisionCylinder
    Speed = 2600.0
    MaxSpeed = 2600.0
    Components = (CollisionCylinder)
    CollisionComponent = CollisionCylinder
    bCollideActors = FALSE
    bCollideWorld = FALSE
    bCollideComplex = FALSE
    RemoteRole = ENetRole.ROLE_None
}
