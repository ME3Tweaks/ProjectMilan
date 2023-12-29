// MILAN CHANGE - 12/25/2025
// By Mgamerz
// Purpose: Based on TestPatch's version of the file.
// Uses GUN02's version of the particle system so it uses GUN02 materials.
Class SFXProjectile_BatarianSniperRound extends SFXProjectile_Explosive
    config(Weapon);

// Variables
var const ParticleSystem KishockImpactTemplate;
var const ParticleSystem KishockBloodyImpactTemplate;
var config float DirectDamageProportion;
var config float BleedDuration;

// Functions
public simulated function Tick(float DeltaTime)
{
    local float UpForce;
    local float ChargeAmount;
    
    ChargeAmount = SFXWeapon(ProjectileOwner).ChargeAmount;
    Super(SFXProjectile).Tick(DeltaTime);
    if (!bStopAiming && bArcing)
    {
        UpForce += WorldInfo.GetGravityZ() * DeltaTime;
        UpForce *= float(-1);
        UpForce *= float(2) * (ChargeAmount - 0.5);
        Velocity.Z += UpForce;
    }
}
public function EReactionTypes GetStickReaction()
{
    local float ChargeAmount;
    
    ChargeAmount = SFXWeapon(ProjectileOwner).ChargeAmount;
    if (ChargeAmount >= 0.5)
    {
        return 1;
    }
    else
    {
        return 0;
    }
}
public simulated function bool Stick(Actor Other, Vector HitLocation, Vector HitNormal, int BoneIdx, optional int Reaction)
{
    local bool bStuckToPawn;
    local BioPawn oPawn;
    local SFXModule_GameEffectManager Manager;
    local float DirectDamage;
    local float BleedDamage;
    local TraceHitInfo HitInfo;
    
    bStuckToPawn = Super.Stick(Other, HitLocation, HitNormal, BoneIdx, Reaction);
    oPawn = BioPawn(Other);
    if (bStuckToPawn)
    {
        SFXGRI(WorldInfo.GRI).DuringAsyncWorker.SpawnImpactEffectAtLocation(Instigator, KishockBloodyImpactTemplate, Other, HitLocation, HitNormal, oPawn.Mesh, 'None');
    }
    else
    {
        SFXGRI(WorldInfo.GRI).DuringAsyncWorker.SpawnEffectAtLocation(Instigator, KishockImpactTemplate, HitLocation, Rotator(HitNormal));
    }
    if (ProjEffectsTrail != None)
    {
        ProjEffectsTrail.SetActive(FALSE);
    }
    DirectDamage = GetDirectDamage();
    BleedDamage = GetBleedDamage();
    if (oPawn != None)
    {
        HitInfo.BoneName = oPawn.Mesh.GetBoneName(BoneIdx);
    }
    Other.TakeDamage(DirectDamage, Instigator.Controller, HitLocation, -HitNormal * GetMomentum(), GetDamageType(), HitInfo, Self);
    Manager = Other.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        Manager.CreateAndApplyEffect(Class'SFXGameEffect_DamageOverTime', 'BatarianBleed', BleedDuration, 1, BleedDamage, Instigator.Controller);
    }
    return bStuckToPawn;
}
public function StickTrace(Actor Other, Vector HitNormal, PrimitiveComponent OtherComp)
{
    local Vector HitLocation;
    local TraceHitInfo HitInfo;
    local Attachment Attachment;
    local BioPawn oPawn;
    local int BoneIdx;
    local Vector MovementDir;
    local float MovementMag;
    
    MovementDir = Normal(Velocity);
    MovementMag = VSize(Velocity) + float(100);
    if (Self.TraceComponent(HitLocation, HitNormal, OtherComp, location + MovementDir * float(100), location - MovementDir * MovementMag, vect(0.0, 0.0, 0.0), HitInfo, TRUE) == FALSE)
    {
        return;
    }
    oPawn = BioPawn(Other);
    if (oPawn != None)
    {
        if (HitInfo.BoneName == 'None')
        {
            foreach oPawn.Mesh.Attachments(Attachment, )
            {
                if (Attachment.Component == HitInfo.HitComponent)
                {
                    HitInfo.BoneName = Attachment.BoneName;
                    break;
                }
            }
        }
        BoneIdx = oPawn.Mesh.MatchRefBone(HitInfo.BoneName);
    }
    if (Role == ENetRole.ROLE_Authority)
    {
        if (oPawn != None)
        {
            oPawn.RequestReaction(GetStickReaction(), InstigatorController, MovementDir * GetMomentum());
        }
        ReplicateStick(Other, HitLocation, HitNormal, BoneIdx);
    }
    Stick(Other, HitLocation, HitNormal, BoneIdx);
    if (Role == ENetRole.ROLE_Authority)
    {
        DoStickImpact(Other, HitLocation, HitNormal, HitInfo);
    }
    SetTimer(StickExplodeDelay, FALSE, 'DelayedExplosion', );
}
public simulated function float GetDirectDamage()
{
    local float TotalDirectDamage;
    local float MaxBonusDamage;
    local SFXWeapon_SniperRifle_Batarian Kishock;
    
    Kishock = SFXWeapon_SniperRifle_Batarian(ProjectileOwner);
    if (Kishock != None)
    {
        TotalDirectDamage = Kishock.GetFireModeBaseDamage() * DirectDamageProportion;
        MaxBonusDamage = (TotalDirectDamage * (Kishock.KishockDamageMultiplier - float(1))) * Kishock.ChargeAmount;
        TotalDirectDamage += MaxBonusDamage;
        return TotalDirectDamage;
    }
    return 0.0;
}
public simulated function float GetBleedDamage()
{
    local float TotalBleedDamage;
    local float MaxBonusDamage;
    local SFXWeapon_SniperRifle_Batarian Kishock;
    
    Kishock = SFXWeapon_SniperRifle_Batarian(ProjectileOwner);
    if (Kishock != None)
    {
        TotalBleedDamage = Kishock.GetFireModeBaseDamage() * (float(1) - DirectDamageProportion);
        MaxBonusDamage = (TotalBleedDamage * (Kishock.KishockDamageMultiplier - float(1))) * Kishock.ChargeAmount;
        TotalBleedDamage += MaxBonusDamage;
        return TotalBleedDamage / BleedDuration;
    }
    return 0.0;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    // MILAN CHANGE - Change to GUN02 version to use GUN02 materials
    KishockImpactTemplate = ParticleSystem'BioVFX_DLC_GUN02_Kishock.Particles.Batarian_Impact'
    KishockBloodyImpactTemplate = ParticleSystem'BioVFX_C_Impacts.Blood.Particles.Blood_Red_CriticalHit_Misty_nSound'
    StickPawnImpactSound = WwiseEvent'Wwise_Weapons_S_Batarian.Play_wep_s_batarian_impact_flesh'
    NPStickPawnImpactSound = WwiseEvent'Wwise_Weapons_S_Batarian.Play_wep_np_batarian_impact_flesh'
    StickShieldImpactSound = WwiseEvent'Wwise_Weapons_S_Batarian.Play_wep_s_batarian_impact_shield'
    NPStickShieldImpactSound = WwiseEvent'Wwise_Weapons_S_Batarian.Play_wep_np_batarian_impact_shield'
    StickEnvironmentImpactSound = WwiseEvent'Wwise_Weapons_S_Batarian.Play_wep_s_batarian_impact_env'
    NPStickEnvironmentImpactSound = WwiseEvent'Wwise_Weapons_S_Batarian.Play_wep_np_batarian_impact_env'
    fFuseLength = 10.0
    StickExplodeDelay = 0.0
    AccelRate = 15000.0
    bStickPawns = TRUE
    bStickWalls = TRUE
    // MILAN CHANGE - Change following two to GUN02 versions to use GUN02 materials
    ProjEffectsTrailTemplate = ParticleSystem'BioVFX_DLC_GUN02_Kishock.Particles.Batarian_Proj_Trail'
    ProjEffectsHeadTemplate = ParticleSystem'BioVFX_DLC_GUN02_Kishock.Particles.Batarian_Proj_Head'
    // END MILAN CHANGE
    bArcing = TRUE
    MyDamageType = Class'SFXDamageType_Kishock'
    Speed = 15000.0
    MaxSpeed = 15000.0
    MomentumTransfer = 80.0
    CylinderComponent = CollisionCylinder
    Components = (CollisionCylinder)
    LifeSpan = 10.0
    CollisionComponent = CollisionCylinder
}