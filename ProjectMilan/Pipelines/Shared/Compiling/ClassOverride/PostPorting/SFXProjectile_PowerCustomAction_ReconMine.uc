// MILAN CHANGE - 11/25/2026 - Mgamerz
// Fix recon mine omni tool effect never turning off due to LE changes
Class SFXProjectile_PowerCustomAction_ReconMine extends SFXProjectile_PowerCustomAction
    config(Game);

var Object.Guid ImpactGUID;
var Object.Vector MineHitNormal;
var config float ArmingDelay;
var config float UpdateFrequency;
var float LastUpdateTime;
var float StartTime;
var float ScanRange;
var clearcrosslevel SFXPowerCustomActionMP_ReconMine MinePower;
var RvrClientEffectInterface CE_MineDeployedTemplate;
var RvrClientEffectInterface CE_MineDeployedTemplate_Local;
var RvrClientEffectInterface CE_MineExplosion;
var RvrClientEffectInterface CE_EnemyInRange;
var WwiseEvent AttachToWallSound;
var WwiseEvent HenchAttachToWallSound;
var WwiseEvent ArmingSound;
var WwiseEvent NonPlayerArmingSound;
var WwiseEvent MineExplosionSound;
var WwiseEvent NonPlayerMineExplosionSound;
var transient bool bIsMineDeployed;

public event simulated function HitWall(Object.Vector HitNormal, Actor Wall, PrimitiveComponent WallComp)
{
    if (bIsMineDeployed)
    {
        return;
    }
    SetLocation(location + HitNormal * float(1), );
    MineHitNormal = HitNormal;
    Speed = 0.0;
    Velocity = vect(0.0, 0.0, 0.0);
    PlayMineImpact(HitNormal);
}
public simulated function Init(Object.Vector Direction)
{
    local SFXPawn_Player PlayerPawn;
    local Controller PlayerController;
    
    MinePower = SFXPowerCustomActionMP_ReconMine(Power);
    if (MinePower == None)
    {
        return;
    }
    if (Role != ENetRole.ROLE_Authority && MinePower.ActiveMine != Self)
    {
        if (WorldInfo.TimeSeconds == NetInitTime)
        {
            MinePower.ActiveMine = Self;
        }
        else
        {
            DeferredLinkPowerWithProjectile();
        }
    }
    ScanRange = MinePower.ScanRadius.CurrentValue;
    PlayerPawn = SFXPawn_Player(MinePower.m_oPawn);
    if (PlayerPawn != None)
    {
        PlayerController = PlayerPawn.Controller;
        if (PlayerController != None)
        {
            Direction = Vector(PlayerController.Rotation);
        }
    }
    Super.Init(Direction);
    Speed = MaxSpeed;
    Velocity = Normal(Velocity) * MaxSpeed;
    LastUpdateTime = WorldInfo.GameTimeSeconds;
    StartTime = WorldInfo.GameTimeSeconds;
    bIsMineDeployed = FALSE;
}
public simulated function Recycle()
{
    Super.Recycle();
    MinePower = default.MinePower;
    ImpactGUID = default.ImpactGUID;
}
public simulated function ShutDown()
{
    if (bShuttingDown)
    {
        return;
    }
    if (MinePower != None)
    {
        MinePower.MineDetonated();
        if (MinePower.Projectiles.Find(Self) >= 0)
        {
            MinePower.Projectiles.RemoveItem(Self);
        }
    }
    if (ImpactGUID.A != 0 && ImpactGUID.B != 0 && ImpactGUID.C != 0 && ImpactGUID.D != 0)
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(None, ImpactGUID, TRUE);
    }
    Super.ShutDown();
}
public event simulated function Tick(float DeltaTime)
{
    local Object.Vector prevDirection;
    
    if (bIsMineDeployed)
    {
        prevDirection = ReplicatedPowerProjInitInfo.Direction;
    }
    Super.Tick(DeltaTime);
    if (!bIsMineDeployed || bClientPredictionActive)
    {
        return;
    }
    if (bIsMineDeployed)
    {
        ReplicatedPowerProjInitInfo.Direction = prevDirection;
    }
    // MILAN CHANGE - 11/25/2026 - Mgamerz
    // Add guard to not turn on glow if we're shutting down still
    if (IsShuttingDown())
    {
        return;
    }
    // END MILAN CHANGE
    if (MinePower == None)
    {
        if (!IsShuttingDown())
        {
            ShutDown();
        }
        return;
    }
    if (WorldInfo.GameTimeSeconds - StartTime >= ArmingDelay && WorldInfo.GameTimeSeconds - LastUpdateTime >= UpdateFrequency)
    {
        LastUpdateTime = WorldInfo.GameTimeSeconds;
        if (MinePower != None && MinePower.StartOmniTool())
        {
            if (MinePower.m_oPawn.IsLocallyControlled())
            {
                PlaySound(ArmingSound, TRUE);
            }
            else
            {
                PlaySound(NonPlayerArmingSound, TRUE);
            }
        }
        UpdateGlowActors();
    }
}
public event simulated function Timer();

public function ProcessTouch(Actor Other, Object.Vector HitLocation, Object.Vector HitNormal)
{
    if (Pawn(Other) != None)
    {
        return;
    }
    Super.ProcessTouch(Other, HitLocation, HitNormal);
}
public simulated function float GetDamage()
{
    if (MinePower != None)
    {
        return MinePower.Damage.CurrentValue;
    }
    return 0.0;
}
public simulated function ReplicatedInitUpdated()
{
    Super.ReplicatedInitUpdated();
    if (ReplicatedPowerProjInitInfo.TravelSpeed == 0.0 && !bIsMineDeployed)
    {
        HitWall(ReplicatedPowerProjInitInfo.Direction * 0.00100000005, None, None);
    }
}
public simulated function SpawnExplosionEffects(Object.Vector HitLocation, Object.Vector HitNormal)
{
    Super(SFXProjectile_Explosive).SpawnExplosionEffects(HitLocation, HitNormal);
    Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayAtLocation(CE_MineExplosion, HitLocation, MineHitNormal);
    if (MinePower.m_oPawn.IsLocallyControlled())
    {
        PlaySound(MineExplosionSound, TRUE);
    }
    else
    {
        PlaySound(NonPlayerMineExplosionSound, TRUE);
    }
}
public function Tick_Prediction(float DeltaTime)
{
    local SFXProjectile_PowerCustomAction_ProximityMine oTargetProjectile;
    
    oTargetProjectile = SFXProjectile_PowerCustomAction_ProximityMine(TargetProjectile);
    if (bGotAPredictionTarget && oTargetProjectile != None && oTargetProjectile.bIsMineDeployed)
    {
        ShutDown();
        return;
    }
    Super(SFXProjectile_Explosive).Tick_Prediction(DeltaTime);
}
public final function UpdateGlowActors()
{
    local int idx;
    local BioPawn NearbyPawn;
    
    if (MinePower == None)
    {
        return;
    }
    if (Role != ENetRole.ROLE_Authority)
    {
        for (idx = MinePower.TrackedPawns.Length - 1; idx >= 0; idx--)
        {
            if (MinePower.TrackedPawns[idx] == None)
            {
                MinePower.TrackedPawns.Remove(idx, 1);
            }
        }
        return;
    }
    for (idx = MinePower.TrackedPawns.Length - 1; idx >= 0; idx--)
    {
        if (MinePower.TrackedPawns[idx] == None)
        {
            MinePower.TrackedPawns.Remove(idx, 1);
            continue;
        }
        if (MinePower.TrackedPawns[idx].IsDead() || VSize(MinePower.TrackedPawns[idx].location - location) > ScanRange + 50.0)
        {
            MinePower.RemoveGlowActorAt(idx);
        }
    }
    foreach WorldInfo.AllPawns(Class'BioPawn', NearbyPawn, location, ScanRange)
    {
        MinePower.AddGlowActor(NearbyPawn);
    }
}
public simulated function bool CanDetonate()
{
    return !IsShuttingDown() && WorldInfo.GameTimeSeconds - StartTime >= ArmingDelay;
}
public simulated function DeferredLinkPowerWithProjectile()
{
    if (MinePower != None && MinePower.bDoClientLinkPowerWithProjectile)
    {
        if (MinePower.ActiveMine != Self)
        {
            MinePower.ActiveMine = Self;
        }
        MinePower.bDoClientLinkPowerWithProjectile = FALSE;
    }
    else
    {
        SetTimer(0.100000001, FALSE, 'DeferredLinkPowerWithProjectile', );
    }
}
public simulated function bool DetonateMine(bool bForce)
{
    if (bForce || WorldInfo.GameTimeSeconds - StartTime >= ArmingDelay)
    {
        if (!IsShuttingDown())
        {
            Explode(location, MineHitNormal);
            ShutDown();
            return TRUE;
        }
    }
    return FALSE;
}
public simulated function PlayMineImpact(Object.Vector HitNormal)
{
    local RvrClientEffectInterface.RvrClientEffectTarget EffectTarget;
    
    bIsMineDeployed = TRUE;
    EffectTarget.HitNormal = HitNormal;
    EffectTarget.HitLocation = location;
    EffectTarget.Instigator = Self;
    if (MinePower.m_oPawn.IsLocallyControlled())
    {
        ImpactGUID = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_MineDeployedTemplate_Local, EffectTarget, Self);
    }
    else
    {
        ImpactGUID = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_MineDeployedTemplate, EffectTarget, Self);
    }
    if (ProjEffectsHead != None)
    {
        ProjEffectsHead.SetActive(FALSE);
    }
    if (Caster != None && Caster.IsLocallyControlled())
    {
        PlaySound(AttachToWallSound, TRUE);
    }
    else
    {
        PlaySound(HenchAttachToWallSound, TRUE);
    }
    ReplicatedPowerProjInitInfo.Direction = HitNormal * 1000.0;
}
public function ReplicateMineDeployed()
{
    ReplicatedPowerProjInitInfo.Trigger++;
    InitEventEndReplicationTime = WorldInfo.TimeSeconds + 3.0;
    bForceNetUpdate = TRUE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    ArmingDelay = 3.0
    UpdateFrequency = 0.5
    CE_MineDeployedTemplate = RvrClientEffect'BioVFX_MP4_Volus_Eng.VCFX.ReconMine_Imp_VCFX'
    CE_MineDeployedTemplate_Local = RvrClientEffect'BioVFX_MP4_Volus_Eng.VCFX.ReconMine_Imp_LocalPlayer_VCFX'
    CE_MineExplosion = RvrClientEffect'BioVFX_MP4_Volus_Eng.VCFX.ReconMine_Explosion_VCFX'
    AttachToWallSound = WwiseEvent'Wwise_Power_DLC_ReconMine.Play_pwr_DLC_reconmine_impact_P'
    HenchAttachToWallSound = WwiseEvent'Wwise_Power_DLC_ReconMine.Play_pwr_DLC_reconmine_impact_NP'
    ArmingSound = WwiseEvent'Wwise_Power_DLC_ReconMine.Play_pwr_DLC_reconmine_activate_P'
    NonPlayerArmingSound = WwiseEvent'Wwise_Power_DLC_ReconMine.Play_pwr_DLC_reconmine_activate_NP'
    MineExplosionSound = WwiseEvent'Wwise_Power_DLC_ReconMine.Play_pwr_DLC_reconmine_explode_P'
    NonPlayerMineExplosionSound = WwiseEvent'Wwise_Power_DLC_ReconMine.Play_pwr_DLC_reconmine_explode_NP'
    ExplosionParticleLifetime = 5.0
    ProjEffectsHeadTemplate = ParticleSystem'BioVFX_MP4_Volus_Eng.Particles.ReconMine_Projectile'
    MaxSpeed = 6000.0
    CylinderComponent = CollisionCylinder
    Components = (CollisionCylinder)
    LifeSpan = 0.0
    CollisionComponent = CollisionCylinder
}
