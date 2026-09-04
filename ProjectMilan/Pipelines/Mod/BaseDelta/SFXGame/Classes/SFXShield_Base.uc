// 08/27/2026 - Mgamerz
// AIEnergyShieldGatePct converted to ScaledFloat to allow game effects to apply to it
// 08/31/2026 - Mgamerz
// Fix shields not recharging at high FPS
Class SFXShield_Base extends Inventory
    abstract
    config(Weapon);

struct ShieldBreachReplication 
{
    var Class<SFXDamageType> DamageType;
    var byte Trigger;
};

var(SFXShield_Base) config protectedwrite repnotify ScaledFloat MaxShields;
var(SFXShield_Base) ScaledFloat ShieldRegenDelay;
var ScaledFloat ShieldDamageMultiplier;
var transient repnotify ShieldBreachReplication ShieldBreachReplicationInfo;
var(SFXShield_Base) Vector ShieldOffset;
var(SFXShield_Base) ParticleSystem PS_Impact;
var(SFXShield_Base) ParticleSystem PS_Recharged;
var(SFXShield_Base) ParticleSystem PS_Breach;
var(SFXShield_Base) PhysicalMaterial PhysMat;
var(SFXShield_Base) WwiseEvent ShieldsBreakSound;
var(SFXShield_Base) WwiseEvent ShieldsUpSound;
var(SFXShield_Base) WwiseEvent PCShieldsUpStopSound;
var stringref ShieldDisplayName;
var(SFXShield_Base) float ShieldScale;
var(SFXShield_Base) privatewrite float CurrentShields;
var transient float OldCurrentShields;
var float MaxEnemyShieldRecharge;
var transient float ShieldRegenTimer;
var(SFXShield_Base) float ShieldRegenPct;
var ScaledFloat AIEnergyShieldGatePct; // MILAN CHANGE - Convert to ScaledFloat
var config int TOTAL_SHIELD_STEPS;
var(SFXShield_Base) bool bRechargeable;
var bool bRecentShieldDamage;
var const EResistanceType Resistance;
var transient repnotify byte ReplicatedShield;

public simulated function float GetCurrentShields()
{
    return CurrentShields;
}
public simulated function float GetMaxShields()
{
    return MaxShields.Value;
}
public simulated function Initialize()
{
    local BioPawn Pawn;
    local ShieldLoadout ShieldEntry;
    
    Pawn = BioPawn(Instigator);
    if (Pawn != None)
    {
        foreach Pawn.Loadout.ShieldLoadouts(ShieldEntry, )
        {
            if (ShieldEntry.Shields == Self.@Class)
            {
                ShieldScale = Pawn.Loadout.ShieldScale;
                ShieldOffset = Pawn.Loadout.ShieldOffset;
                MaxShields.Level = int(Lerp(ShieldEntry.ShieldLevelRange.X, ShieldEntry.ShieldLevelRange.Y, 0.0));
                MaxShields.X = ShieldEntry.MaxShields.X;
                MaxShields.Y = ShieldEntry.MaxShields.Y;
                SetMaxShields(MaxShields);
                ScaleShields();
                CurrentShields = GetMaxShields();
                OldCurrentShields = CurrentShields;
                break;
            }
        }
    }
    else
    {
        SetTimer(0.100000001, FALSE, 'Initialize', );
    }
}
public simulated function PostBeginPlay()
{
    Super(Actor).PostBeginPlay();
    Initialize();
}
public static function PrecacheVFX(SFXObjectPool ObjectPool, RvrClientEffectManager ClientEffects)
{
    ObjectPool.PrecacheImpactParticleSystemComponent(default.PS_Impact);
    ObjectPool.PrecacheGenericParticleSystemComponent(default.PS_Recharged);
    ObjectPool.PrecacheGenericParticleSystemComponent(default.PS_Breach);
    ClientEffects.PrimeClass(default.@Class);
}
public event simulated function ReplicatedEvent(Name VarName)
{
    Super(Actor).ReplicatedEvent(VarName);
    switch (VarName)
    {
        case 'ShieldBreachReplicationInfo':
            ClientDeferredBreachShields();
            break;
        case 'ReplicatedShield':
        case 'MaxShields':
            CurrentShields = float(ReplicatedShield) / float(TOTAL_SHIELD_STEPS) * GetMaxShields();
            if (CurrentShields > 0.0)
            {
                ClientDeferredSetResistance();
            }
            break;
        default:
            Super(Actor).ReplicatedEvent(VarName);
            break;
    }
}
public simulated function Tick(float DeltaSeconds)
{
    local BioPawn PawnOwner;
    local float MaxVal;
    
    if (!bRechargeable)
    {
        return;
    }
    PawnOwner = BioPawn(Instigator);
    if (PawnOwner != None && PawnOwner.IsDead() == FALSE)
    {
        if (ShieldRegenTimer > float(0))
        {
            ShieldRegenTimer -= DeltaSeconds;
        }
        else
        {
            if (bRecentShieldDamage)
            {
                bRecentShieldDamage = FALSE;
                BeginRecharge();
            }
            MaxVal = MaxEnemyShieldRecharge > 0.0 ? MaxEnemyShieldRecharge * MaxShields.Value : MaxShields.Value;
            if (OldCurrentShields < MaxVal)
            {
                PawnOwner.SetResistance(Resistance, TRUE);
                SetCurrentShields(FMin(MaxVal, CurrentShields + GetShieldRegenRate() * MaxVal * DeltaSeconds));
                if (CurrentShields >= MaxVal)
                {
                    PlayRecharge();
                    if (Instigator != None && Instigator.IsHumanControlled())
                    {
                        Instigator.PlaySound(PCShieldsUpStopSound, TRUE);
                    }
                }
            }
        }
        if (CurrentShields > 0.0 && OldCurrentShields <= 0.0)
        {
            PawnOwner.ShieldsUp();
        }
        OldCurrentShields = CurrentShields;
    }
}
public function GivenTo(Pawn thisPawn, optional bool bDoNotActivate)
{
    local BioPawn BP;
    local SFXDifficultyHandler DH;
    
    BP = BioPawn(Instigator);
    if (BP != None)
    {
        BP.SetResistance(Resistance, TRUE);
    }
    DH = SFXGRI(WorldInfo.GRI).DifficultyHandler;
    if (DH != None)
    {
        if (SFXPawn_PlayerParty(Instigator) == None)
        {
            // MILAN CHANGE 08/27/2026 - Mgamerz
            // Change to ScaledFloat for game effects
            AIEnergyShieldGatePct.StaticBonus = DH.GetFloat('AIEnergyShieldGatePct', 'Global');
            Class'SFXGame'.static.ReCalculate(AIEnergyShieldGatePct);
            // END MILAN CHANGE
        }
    }
    Super.GivenTo(thisPawn, bDoNotActivate);
}
public function ItemRemovedFromInvManager()
{
    local BioPawn BP;
    
    BP = BioPawn(Instigator);
    if (BP != None)
    {
        BP.SetResistance(Resistance, FALSE);
    }
    Super.ItemRemovedFromInvManager();
}
protected final simulated function ActivatePSC(ParticleSystem Template, optional float ImpactScale = 1.0, optional Vector Offset)
{
    local SFXObjectPool Pool;
    local ParticleSystemComponent PSC;
    
    if (Instigator != None && Template != None && Instigator.WorldInfo.GRI != None)
    {
        Pool = SFXGRI(Instigator.WorldInfo.GRI).ObjectPool;
        if (Pool != None)
        {
            PSC = Pool.GetGenericParticleSystemComponent(Template);
            if (PSC != None)
            {
                Instigator.AttachComponent(PSC);
                PSC.SetScale(ImpactScale);
                PSC.SetTranslation(Offset);
                Pool.ApplyLODLevel(PSC, Instigator.location);
                PSC.SetActive(TRUE);
            }
        }
    }
}
private final simulated function ActivateWeaponImpact(SFXWeapon Weapon, out TraceHitInfo HitInfo, out Vector HitLocation, ParticleSystem Template, PrimitiveComponent PrimComp)
{
    local Vector HitNormal;
    local Vector DmgParameter;
    
    if (Weapon != None && PrimComp != None && Template != None)
    {
        HitNormal = Normal(Weapon.Instigator.location - HitLocation);
        if (Instigator != None)
        {
            HitLocation += HitNormal * Instigator.CylinderComponent.CollisionRadius;
        }
        DmgParameter = vect(1.0, 1.0, 1.0) * (1.0 - GetCurrentShields() / GetMaxShields());
        SFXGRI(WorldInfo.GRI).DuringAsyncWorker.SpawnImpactEffectAtLocation(Weapon.Instigator, Template, PrimComp.Owner, HitLocation, HitNormal, PrimComp, HitInfo.BoneName, GetImpactScale(Weapon, HitLocation), 'Shield_Damage', DmgParameter);
    }
}
public simulated function ApplyDamage(out float Damage, out TraceHitInfo HitInfo, out Vector HitLocation, Vector Momentum, Class<SFXDamageType> DamageType, Controller instigatedBy, Actor DamageCauser, out float TotalDamageDone)
{
    local SFXWeapon Weapon;
    
    if (Damage <= float(0))
    {
        return;
    }
    ResetShieldRegenTimer();
    if (CurrentShields <= float(0))
    {
        return;
    }
    ApplyDamageToShields(Damage, DamageType, Momentum, HitLocation, HitInfo, instigatedBy, TotalDamageDone);
    // MILAN CHANGE 08/27/2026 - Mgamerz
    // Convert AIEnergyShieldGatePct to a ScaledFloat so it can be modified by game effects (var type also changed)
    if (CurrentShields <= float(0) && AIEnergyShieldGatePct.Value > float(0) && !DamageType.default.bCausesNormalizedDamage && (SFXWeapon(DamageCauser) != None || DamageCauser.IsA('SFXProjectile_Turian')))
    {
        Damage -= Damage * FMax(AIEnergyShieldGatePct.Value, 0.0);
    }
    // END MILAN CHANGE
    if (DamageType.default.bSpawnWeaponImpacts)
    {
        Weapon = SFXWeapon(DamageCauser);
        if (Weapon != None)
        {
            if (Weapon.bSuppressImpactFX == FALSE)
            {
                ActivateWeaponImpact(Weapon, HitInfo, HitLocation, Weapon.PS_DefaultImpactEffect, HitInfo.HitComponent);
                ActivateWeaponImpact(Weapon, HitInfo, HitLocation, PS_Impact, HitInfo.HitComponent);
            }
            if (Weapon.bSuppressAudio == FALSE)
            {
                PlayShieldSound(Weapon, HitInfo, HitLocation);
            }
        }
    }
}
protected simulated function ApplyDamageToShields(out float Damage, Class<SFXDamageType> DamageType, Vector Momentum, Vector HitLocation, TraceHitInfo HitInfo, Controller instigatedBy, out float TotalDamageDone)
{
    local float ShieldDamage;
    local float DamageResistance;
    local BioPawn Pawn;
    local float CurrentShieldValue;
    local SFXCustomAction_DamageReaction Action;
    local int BoneIndex;
    
    DamageResistance = GetDamageResistance(DamageType);
    ShieldDamage = Damage * DamageResistance;
    CurrentShieldValue = GetCurrentShields();
    Pawn = BioPawn(Instigator);
    if (CurrentShieldValue > ShieldDamage)
    {
        if (DamageType.default.bAlwaysPlayHitReact)
        {
            if (Pawn != None && Role == ENetRole.ROLE_Authority)
            {
                if (Pawn.RequestWeaponReaction(instigatedBy, HitLocation, DamageType, Momentum, HitInfo))
                {
                    Action = SFXCustomAction_DamageReaction(Pawn.CustomActions[Pawn.CurrentCustomAction]);
                    if (Action != None)
                    {
                        BoneIndex = Pawn.Mesh.MatchRefBone(HitInfo.BoneName);
                        Action.Init(HitLocation, -Normal(Momentum), BoneIndex, TRUE, DamageType);
                    }
                    Pawn.ReplicateAnimatedReaction(Pawn.CurrentCustomAction, HitLocation, -Normal(Momentum), BoneIndex, DamageType);
                }
            }
        }
        TotalDamageDone += ShieldDamage;
        SetCurrentShields(CurrentShieldValue - ShieldDamage);
        Damage = 0.0;
    }
    else
    {
        if (Pawn != None && Role == ENetRole.ROLE_Authority)
        {
            BreachShields(DamageType);
            if (Vector(Pawn.Rotation) Dot Momentum < 0.0 && Pawn.RequestReaction(5, instigatedBy, Momentum, HitInfo))
            {
                Pawn.ReplicateAnimatedReaction(Pawn.CurrentCustomAction);
            }
        }
        TotalDamageDone += CurrentShieldValue;
        ShieldDamage -= CurrentShieldValue;
        Damage = ShieldDamage / DamageResistance;
    }
}
public simulated function BeginRecharge();

public simulated function BreachShields(Class<SFXDamageType> DamageType)
{
    local BioPawn Pawn;
    
    if (Role == ENetRole.ROLE_Authority)
    {
        ReplicateShieldBreach(DamageType);
    }
    if (Instigator != None && (Instigator.IsHumanControlled() == FALSE || Instigator.IsLocallyControlled() == FALSE))
    {
        Instigator.PlaySound(ShieldsBreakSound, TRUE);
    }
    ActivatePSC(PS_Breach, ShieldScale, ShieldOffset);
    SetCurrentShields(0.0);
    ResetShieldRegenTimer();
    Pawn = BioPawn(Instigator);
    if (Pawn != None)
    {
        Pawn.ShieldsDown();
        Pawn.SetResistance(Resistance, FALSE);
        if (SFXGRI(WorldInfo.GRI) != None)
        {
            SFXGRI(WorldInfo.GRI).TriggerVocalizationEvent(28, Pawn, , 1.0);
        }
    }
    ShieldDestroyedPowerCallback(Instigator, Self);
}
public simulated function ClientDeferredBreachShields()
{
    if (Instigator == None)
    {
        SetTimer(0.100000001, FALSE, 'ClientDeferredBreachShields', );
    }
    else
    {
        BreachShields(ShieldBreachReplicationInfo.DamageType);
    }
}
public simulated function ClientDeferredSetResistance()
{
    if (Instigator == None)
    {
        SetTimer(0.100000001, FALSE, 'ClientDeferredSetResistance', );
    }
    else
    {
        BioPawn(Instigator).SetResistance(Resistance, TRUE);
    }
}
public simulated function float GetDamageResistance(Class<SFXDamageType> DamageType)
{
    local float fResistance;
    
    if (DamageType == None)
    {
        return ShieldDamageMultiplier.Value;
    }
    fResistance = 1.0;
    switch (Resistance)
    {
        case EResistanceType.ResistanceType_Biotic:
            fResistance = DamageType.default.Resistance.Biotic;
            break;
        case EResistanceType.ResistanceType_Shield:
            fResistance = DamageType.default.Resistance.Shield;
            break;
        default:
    }
    return ShieldDamageMultiplier.Value * FClamp(fResistance, 0.0, 10.0);
}
public simulated function float GetImpactScale(SFXWeapon Weapon, Vector HitLocation)
{
    local float Range;
    local float Scale;
    
    Scale = 1.0;
    if (Weapon.DefaultFireMode != FireModes.FireMode_FullAuto)
    {
        Scale = 1.5;
    }
    if (SFXPawn_Player(Instigator) == None && SFXPawn_Henchman(Instigator) == None && Weapon.IsZoomed() == FALSE)
    {
        Range = VSize(HitLocation - Weapon.Instigator.location);
        Scale = FClamp(Scale * (Range + float(3000)) / float(4000), Scale, Scale * 1.5);
    }
    return Scale;
}
public simulated function ScaledFloat GetMaxShieldStruct()
{
    return MaxShields;
}
public simulated function float GetShieldRegenDelay()
{
    return ShieldRegenDelay.Value;
}
public simulated function float GetShieldRegenRate()
{
    return ShieldRegenPct;
}
public function InitializeMaxShields(float NewMaxShields)
{
    MaxShields.X = NewMaxShields;
    MaxShields.Y = NewMaxShields;
    MaxShields.Value = NewMaxShields;
    OldCurrentShields = MaxShields.Value;
    SetCurrentShields(MaxShields.Value);
}
public simulated function PlayRecharge()
{
    local SFXPlayerController PC;
    
    PC = SFXPlayerController(GetALocalPlayerController());
    if (PC == None || !PC.GameModeManager2.IsActive(8) && !PC.GameModeManager2.IsActive(7))
    {
        if (Instigator != None && (Instigator.IsHumanControlled() == FALSE || Instigator.IsLocallyControlled() == FALSE))
        {
            Instigator.PlaySound(ShieldsUpSound, TRUE);
        }
        ActivatePSC(PS_Recharged, ShieldScale, ShieldOffset);
    }
}
public simulated function PlayShieldSound(SFXWeapon Weapon, TraceHitInfo HitInfo, Vector HitLocation)
{
    local WwiseEvent ShieldSound;
    
    ShieldSound = Weapon.GetImpactSound(PhysMat);
    if (ShieldSound != None)
    {
        Instigator.PlaySound(ShieldSound, TRUE, , , HitLocation);
    }
}
public function ReplicateCurrentShields()
{
    local float NewShields;
    
    // MILAN CHANGE - 08/31/2026 - Mgamerz
    // Use FMax instead of Max to do float comparison, not integer
    // (Original find by Tajfun)
    NewShields = FMax(CurrentShields, 0);
    ReplicatedShield = byte(FCeil(NewShields / GetMaxShields() * float(TOTAL_SHIELD_STEPS)));
}
public function ReplicateShieldBreach(Class<SFXDamageType> DamageType)
{
    ShieldBreachReplicationInfo.Trigger++;
    ShieldBreachReplicationInfo.DamageType = DamageType;
}
public simulated function ResetShieldRegenTimer()
{
    bRecentShieldDamage = TRUE;
    ShieldRegenTimer = GetShieldRegenDelay();
}
public simulated function ScaleShields()
{
    local ScaledFloat MaxShieldsLoc;
    
    MaxShieldsLoc = GetMaxShieldStruct();
    MaxShieldsLoc.StaticBonus = 1.0;
    Class'SFXGame'.static.ReCalculate(ShieldRegenDelay);
    Class'SFXGame'.static.ReCalculate(MaxShieldsLoc);
    SetMaxShields(MaxShieldsLoc);
}
public final function SetCurrentShields(float NewCurrentShields)
{
    if (Role == ENetRole.ROLE_Authority)
    {
        // MILAN CHANGE - 08/31/2026 - Mgamerz
        // Use FMax instead of Max to do float comparison, not integer
        // (Original find by Tajfun)
        CurrentShields = FMax(NewCurrentShields, 0);
        ReplicateCurrentShields();
    }
}

public function SetMaxShields(ScaledFloat NewMaxShields)
{
    MaxShields = NewMaxShields;
}
public delegate function ShieldDestroyedPowerCallback(Actor ShieldActor, SFXShield_Base Shield);


replication
{
    if (Role == ENetRole.ROLE_Authority && bNetDirty)
        MaxShields, ShieldBreachReplicationInfo, ReplicatedShield;
}

defaultproperties
{
    MaxShields = {
                  Bonuses = (), 
                  X = 0.0, 
                  Y = 0.0, 
                  MaxLevel = 100, 
                  Level = 0, 
                  Value = 0.0, 
                  StaticBonus = 1.0
                 }
    ShieldRegenDelay = {
                        Bonuses = (), 
                        X = 0.0, 
                        Y = 0.0, 
                        MaxLevel = 100, 
                        Level = 0, 
                        Value = 0.0, 
                        StaticBonus = 1.0
                       }
    ShieldDamageMultiplier = {
                              Bonuses = (), 
                              X = 1.0, 
                              Y = 1.0, 
                              MaxLevel = 100, 
                              Level = 0, 
                              Value = 1.0, 
                              StaticBonus = 1.0
                             }
    ShieldScale = 1.0
    TOTAL_SHIELD_STEPS = 10
    bReplicateInstigator = TRUE
}