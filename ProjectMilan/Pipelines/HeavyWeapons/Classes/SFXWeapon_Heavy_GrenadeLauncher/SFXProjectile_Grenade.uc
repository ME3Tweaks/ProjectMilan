Class SFXProjectile_Grenade extends SFXProjectile_Explosive
    config(Weapon);

var(Sounds) WwiseEvent FuseSound;
var float ProjectileSpeedMin;
var float ProjectileSpeedMax;
var float RotationsPerSecond;

// MILAN CHANGE - 11/25/2026 - Mgamerz
// Proximity fuse, combo vars
var config float ProximityRadius;
var config float ProximityArmTime;
var config float AmmoBulletsPerSecond;
var config array<name> DetonatedCombos;
var config float ComboDetonationRank;
var transient float TimeAlive;
// END MILAN CHANGE

public simulated function Recycle()
{
    Super.Recycle();
    bReplicateMovement = default.bReplicateMovement;
    bUpdateSimulatedPosition = default.bUpdateSimulatedPosition;
    // MILAN CHANGE - 11/25/2026 - Mgamerz
    TimeAlive = default.TimeAlive;
    // END MILAN CHANGE
}
public simulated function Tick(float DeltaTime)
{
    local Object.Rotator NewRotator;

    Super(SFXProjectile).Tick(DeltaTime);
    if (!bStopAiming)
    {
        if (ProjEffectsHead != None)
        {
            NewRotator = ProjEffectsHead.Rotation;
            NewRotator.Pitch += int(65000.0 * DeltaTime * RotationsPerSecond * FClamp(VSize(Velocity) / 2000.0, 0.0, 1.0));
            ProjEffectsHead.SetRotation(NewRotator);
        }
    }
    // MILAN CHANGE - 11/25/2026 - Mgamerz
    TimeAlive += DeltaTime;
    if (Role == ENetRole.ROLE_Authority && bArmed && TimeAlive >= ProximityArmTime)
    {
        TickProximity();
    }
    // END MILAN CHANGE
}
public event singular simulated function Touch(Actor Other, PrimitiveComponent OtherComp, Object.Vector HitLocation, Object.Vector HitNormal)
{
    DelayedExplosion();
}
public function DelayedExplosion()
{
    Explode(location, vect(0.0, 0.0, 0.0));
}
public function FuseDone()
{
    if (IsShuttingDown() == FALSE)
    {
        Explode(location, vect(0.0, 0.0, 1.0));
        ShutDown();
    }
}

// MILAN CHANGE - 11/25/2026 - Mgamerz
// Explode next to living enemies, like the Falcon
public function TickProximity()
{
    local BioPawn Target;

    if (ProximityRadius <= 0.0 || Instigator == None || IsShuttingDown() || bClientPredictionActive)
    {
        return;
    }
    foreach VisibleCollidingActors(Class'BioPawn', Target, ProximityRadius)
    {
        if (!Target.IsDead() && Target.IsHostile(Instigator))
        {
            Explode(location, Normal(Target.location - location));
            ShutDown();
            return;
        }
    }
}
public function DoImpact(Actor InImpactedActor, Controller InInstigatorController, float BaseDamage, float InDamageRadius, float Momentum, Object.Vector HurtOrigin, bool bFullDamage, out Actor.TraceHitInfo HitInfo)
{
    local BioPawn HitPawn;

    HitPawn = BioPawn(InImpactedActor);
    if (HitPawn == None || HitPawn.IsDead() || !HitPawn.IsHostile(Instigator))
    {
        Super.DoImpact(InImpactedActor, InInstigatorController, BaseDamage, InDamageRadius, Momentum, HurtOrigin, bFullDamage, HitInfo);
        return;
    }
    ApplyAmmoPower(HitPawn, HurtOrigin);
    Super.DoImpact(InImpactedActor, InInstigatorController, BaseDamage, InDamageRadius, Momentum, HurtOrigin, bFullDamage, HitInfo);
    // After the damage, like powers, so death-only combos see the kill
    DetonateCombo(HitPawn, HurtOrigin);
}

// Tech combos only
private final function DetonateCombo(BioPawn HitPawn, Object.Vector HurtOrigin)
{
    local SFXPawn_Player Player;
    local SFXPowerCustomAction Detonator;
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect Effect;
    local SFXGameEffect_PowerCombo ComboEffect;
    local SFXGameEffect_PowerCombo LatestComboEffect;
    local float DetonatorRank;
    local name ComboClassName;
    local name ComboCategory;
    local int Index;

    Player = SFXPawn_Player(Instigator);
    if (Role != ENetRole.ROLE_Authority || Player == None || DetonatedCombos.Length == 0)
    {
        return;
    }
    Detonator = SFXPowerCustomAction(Player.FindPower('SFXPowerCustomActionMP_Consumable_Rocket'));
    Manager = HitPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Detonator == None || Manager == None)
    {
        return;
    }
    foreach Manager.GameEffects(Effect)
    {
        ComboEffect = SFXGameEffect_PowerCombo(Effect);
        if (ComboEffect != None && ComboEffect.SourcePower != None && DetonatedCombos.Find(ComboEffect.Class.Name) != -1
            && ComboEffect.SourcePower.PowerName != Detonator.PowerName && (!ComboEffect.bOnlyOnDeath || HitPawn.IsDead()))
        {
            if (LatestComboEffect == None || ComboEffect.CurrentTime < LatestComboEffect.CurrentTime)
            {
                LatestComboEffect = ComboEffect;
            }
        }
    }
    if (LatestComboEffect == None)
    {
        return;
    }
    ComboClassName = LatestComboEffect.Class.Name;
    ComboCategory = LatestComboEffect.Name;
    DetonatorRank = Detonator.Rank;
    Detonator.Rank = ComboDetonationRank;
    Detonator.DoPowerCombo(LatestComboEffect, HitPawn, HurtOrigin, Normal(HitPawn.location - HurtOrigin), TRUE);
    Detonator.Rank = DetonatorRank;

    // Explosion kills DoT so two more shots trigger another explosion
    if (ComboClassName == 'SFXGameEffect_PowerCombo_Fire')
    {
        for (Index = Manager.GameEffects.Length - 1; Index >= 0; Index--)
        {
            Effect = Manager.GameEffects[Index];
            if (Effect != None && Effect.Class.Name == 'SFXGameEffect_FireDamageOverTime' && Effect.Category != ComboCategory)
            {
                Manager.RemoveEffectAt(Index);
            }
        }
    }
}

// Apply ammo power from kit
private final function ApplyAmmoPower(BioPawn HitPawn, Object.Vector HurtOrigin)
{
    local SFXWeapon Launcher;
    local SFXWeapon Source;
    local Actor.ImpactInfo Impact;
    local SFXGameEffect_MatchConsumable_AmmoPower Consumable;
    local float ConsumableRate;
    local SFXGameEffect_MatchConsumable_AmmoPower_Disruptor Disruptor;
    local float LastStunTime;

    Launcher = SFXWeapon(Owner);
    Source = GetAmmoSourceWeapon();
    if (Launcher == None || Source == None)
    {
        return;
    }
    Impact.HitActor = HitPawn;
    Impact.HitLocation = HurtOrigin;
    Impact.HitNormal = Normal(HurtOrigin - HitPawn.location);
    Impact.RayDir = -Impact.HitNormal;

    // Proc chances are per second of fire, so roll at our rate rather than the gun's
    Consumable = GetConsumableAmmoPower();
    if (Consumable != None)
    {
        ConsumableRate = Consumable.BulletsPerSecond;
        Consumable.BulletsPerSecond = AmmoBulletsPerSecond;
    }
    // Disruptor stuns share a 1s cooldown across all targets
    // We purposely ignore it here
    Disruptor = SFXGameEffect_MatchConsumable_AmmoPower_Disruptor(Consumable);
    if (Disruptor != None)
    {
        LastStunTime = Disruptor.LastStunTime;
        Disruptor.LastStunTime = WorldInfo.GameTimeSeconds - 2.0;
    }
    Source.OnWeaponImpact(Launcher, Impact);
    if (Consumable != None)
    {
        Consumable.BulletsPerSecond = ConsumableRate;
    }
    if (Disruptor != None)
    {
        Disruptor.LastStunTime = LastStunTime;
    }
}
private final function SFXWeapon GetAmmoSourceWeapon()
{
    local SFXPawn_Player Player;
    local SFXWeapon Weapon;

    Player = SFXPawn_Player(Instigator);
    if (Player == None || Player.InvManager == None)
    {
        return None;
    }
    Weapon = SFXWeapon(Player.WeaponOnDeck);
    if (HasAmmoPower(Weapon))
    {
        return Weapon;
    }
    foreach Player.InvManager.InventoryActors(Class'SFXWeapon', Weapon)
    {
        if (HasAmmoPower(Weapon))
        {
            return Weapon;
        }
    }
    return None;
}
private final function bool HasAmmoPower(SFXWeapon Weapon)
{
    return Weapon != None && SFXHeavyWeapon(Weapon) == None && Weapon.OnWeaponImpact != None;
}
private final function SFXGameEffect_MatchConsumable_AmmoPower GetConsumableAmmoPower()
{
    local BioPawn Player;
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect Effect;

    Player = BioPawn(Instigator);
    if (Player == None)
    {
        return None;
    }
    Manager = Player.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager == None)
    {
        return None;
    }
    foreach Manager.GameEffects(Effect)
    {
        if (SFXGameEffect_MatchConsumable_AmmoPower(Effect) != None)
        {
            return SFXGameEffect_MatchConsumable_AmmoPower(Effect);
        }
    }
    return None;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    Begin Template Class=PointLightComponent Name=EffectLight0
    End Template
    ProjectileSpeedMin = 750.0
    ProjectileSpeedMax = 2000.0
    RotationsPerSecond = 4.0
    // MILAN CHANGE - 11/25/2026 - Mgamerz
    ProximityRadius = 250.0
    ProximityArmTime = 0.150000006
    AmmoBulletsPerSecond = 1.0
    DetonatedCombos = ('SFXGameEffect_PowerCombo_Electric', 'SFXGameEffect_PowerCombo_Fire', 'SFXGameEffect_PowerCombo_Cryo')
    ComboDetonationRank = 4.0
    // END MILAN CHANGE
    LC_EffectLight = EffectLight0
    ExplosionSound = WwiseEvent'Wwise_Generic_Explosions.Play_gen_exp_wep_grenadelauncher_explode'
    CE_ExplosionTemplate = RvrClientEffect'BioVFX_C_Grenades.Generic.VCFX.GrenadeLauncher_Imp_VCFX'
    fFuseLength = 1.5
    TossZ = 100.0
    ExplosionParticleLifetime = 4.0
    bDuckAudio = TRUE
    ProjEffectsTrailTemplate = ParticleSystem'biovfx_c_grenade_flashbang.Particles.FlashBangGrenade_Projectile_Trail'
    ProjEffectsHeadTemplate = ParticleSystem'biovfx_c_grenade_flashbang.Particles.FlashBangGrenade_Projectile_Head'
    BounceSound = WwiseEvent'Wwise_Weapons_S_GrenLauncher.Play_wep_s_grenadelauncher_bounce'
    CoefficientOfRestitution = 0.75
    bArcing = TRUE
    bBouncing = TRUE
    CylinderComponent = CollisionCylinder
    // MILAN CHANGE - 11/27/2026 - Mgamerz
    // Make 2x as fast as it is in the original for long range attacks
    Speed = 6000.0
    MaxSpeed = 6000.0
    // END MILAN CHANGE
    MomentumTransfer = 0.0
    Components = (CollisionCylinder)
    CollisionComponent = CollisionCylinder
    LifeSpan = 4.0
}
