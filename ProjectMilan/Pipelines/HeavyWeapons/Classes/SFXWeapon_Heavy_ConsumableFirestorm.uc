// NEW to MILAN - 11/19/2026 - Mgamerz
// Consumable Flamethrower
Class SFXWeapon_Heavy_ConsumableFirestorm extends SFXWeapon_Heavy_Flamethrower_Player
    placeable
    config(Weapon);

// Afterburn, fire priming and heat stagger
struct FirestormHeat
{
    var BioPawn Target;
    var float Heat;
    var float LastHitTime;
    var bool bLoggedStaggerFailure;
};

var transient SFXPowerCustomActionMP_Consumable_Rocket Power;
var transient int FireSerial;
var transient array<FirestormHeat> HeatTargets;
var transient bool bConeHitting;
var config float ConeHalfAngle;
var config int MaxConeTargets;
var config float ConeDamageScale;
var Name BurnCategory;
var config float BurnDamagePerSecond;
var config float BurnDuration;
var config float PrimeDuration;
var config float PrimeRank;
var config float StaggerHeat;
var config float LargeStaggerHeat;
var config float HeatHitWindow;
var config float HeatDecayPerSecond;

private final simulated function SFXPowerCustomActionMP_Consumable_Rocket GetAmmoPower()
{
    local SFXPawn_Player Player;

    if (Power == None && (Role == ENetRole.ROLE_Authority || Instigator != None && Instigator.IsLocallyControlled()))
    {
        Player = SFXPawn_Player(Instigator);
        if (Player != None)
        {
            Power = SFXPowerCustomActionMP_Consumable_Rocket(Player.FindPower('SFXPowerCustomActionMP_Consumable_Rocket'));
        }
    }
    return Power;
}
public simulated function InitializeWeapon()
{
    GetAmmoPower();
    Super(SFXWeapon).InitializeWeapon();
}
public simulated function FireAmmunition()
{
    if (!HasAmmo(CurrentFireMode))
    {
        return;
    }
    if (Role == ENetRole.ROLE_Authority)
    {
        if (GetAmmoPower() == None || !Power.AcceptScaledShot(Self))
        {
            return;
        }
    }
    else if (GetAmmoPower() != None)
    {
        Power.PredictScaledShot(Self);
    }
    Super.FireAmmunition();
    if (Role == ENetRole.ROLE_Authority)
    {
        FireCone();
    }
    if (Role == ENetRole.ROLE_Authority && Instigator != None && !Instigator.IsLocallyControlled())
    {
        ClientConfirmScaledShots(Power.GetAcceptedScaledShots(Self), 0);
    }
}
public simulated function ConsumeAmmo(byte FireModeNum);

public simulated function bool HasAmmo(byte FireModeNum, optional int Amount)
{
    return Max(1, Amount) <= GetAmmoCountInMagazine();
}
public simulated function int GetAmmoCountInMagazine()
{
    if (GetAmmoPower() != None)
    {
        return Power.GetScaledRounds(Self);
    }
    return Role == ENetRole.ROLE_Authority || Instigator != None && Instigator.IsLocallyControlled() ? 0 : GetMagazineSize();
}
public simulated function PutDownWeapon()
{
    Super(Weapon).PutDownWeapon();
}
public function DropGun();

public simulated function StartFire(byte FireModeNum)
{
    if (CurrentFireMode == FireModeNum || Instigator == None || Instigator.bNoWeaponFiring)
    {
        return;
    }
    if (Role < ENetRole.ROLE_Authority)
    {
        if (!HasAmmo(FireModeNum))
        {
            ServerPlayNoAmmoEffects();
            BeginFire(FireModeNum);
            return;
        }
        FireSerial++;
        Power.OnHeavyAmmoGranted = SendHeavyAmmoAllowance;
        SendHeavyAmmoAllowance();
    }
    Super.StartFire(FireModeNum);
}
private final simulated function SendHeavyAmmoAllowance()
{
    if (Power != None && !bDeleteMe)
    {
        ServerUpdateHeavyAmmoAllowance(Power.GetScaledChargeAllowance(), FireSerial);
    }
}
public final reliable server function ServerUpdateHeavyAmmoAllowance(int Allowance, int NewFireSerial)
{
    if (GetAmmoPower() != None)
    {
        Power.SetRemoteScaledChargeAllowance(Self, Allowance);
        FireSerial = NewFireSerial;
    }
}
public reliable server function ServerStopFire(byte FireModeNum)
{
    Super.ServerStopFire(FireModeNum);
    if (GetAmmoPower() != None)
    {
        ClientConfirmScaledShots(Power.GetAcceptedScaledShots(Self), FireSerial);
    }
}
public final reliable client function ClientConfirmScaledShots(int AcceptedShots, int StoppedFireSerial)
{
    if (Role == ENetRole.ROLE_Authority || GetAmmoPower() == None)
    {
        return;
    }
    Power.ConfirmScaledShots(Self, AcceptedShots, StoppedFireSerial != 0 && StoppedFireSerial == FireSerial);
    if (StoppedFireSerial == 0 && Instigator != None && Instigator.Weapon != Self)
    {
        ServerCurrentWeapon(Instigator.Weapon);
    }
}
public reliable server function ServerCurrentWeapon(Weapon ClientCurrentWeapon)
{
    local SFXPlayerInventoryManager PlayerInv;

    if (ClientCurrentWeapon != None && Instigator != None && Instigator.Weapon != ClientCurrentWeapon)
    {
        PlayerInv = SFXPlayerInventoryManager(InvManager);
        if (PlayerInv != None)
        {
            PlayerInv.SetWeaponIfAvailable(SFXWeapon(ClientCurrentWeapon));
        }
    }
}
public unreliable server function ServerPlayNoAmmoEffects()
{
    IncrementFizzleCount();
    PlayNoAmmoEffects();
}
// Override super cause it throws weapon. No idea why firestorm is the only one that did this.
public simulated function PlayNoAmmoEffects()
{
    Super(SFXWeapon).PlayNoAmmoEffects();
    SteamMuzzle.SetActive(TRUE);
    SkeletalMeshComponent(Mesh).AttachComponentToSocket(SteamMuzzle, 'Flash_1');
}
public simulated function ProcessInstantHit_Internal(byte FiringMode, Actor.ImpactInfo Impact, optional int NumHits)
{
    local BioPawn Target;

    if (Role == ENetRole.ROLE_Authority)
    {
        Target = GetBurnTarget(Impact.HitActor);
        if (Target != None)
        {
            AddHeat(Target, Impact.RayDir);
        }
    }
    Super.ProcessInstantHit_Internal(FiringMode, Impact, NumHits);
    if (Target != None && !Target.IsDead())
    {
        Burn(Target);
    }
}
public simulated function float GetFireModeBaseDamage()
{
    if (bConeHitting)
    {
        return Super.GetFireModeBaseDamage() * ConeDamageScale;
    }
    return Super.GetFireModeBaseDamage();
}
// Damage cone (from vorcha). We purposely have it also cover the beam weapon trace so middle gets 2x
private final function FireCone()
{
    local Pawn Candidate;
    local BioPawn Target;
    local array<BioPawn> Targets;
    local array<float> Distances;
    local Object.Vector Start;
    local Object.Vector Aim;
    local Object.Vector ToTarget;
    local float Along;
    local float Radius;
    local float Height;
    local float ConeWidth;
    local int Index;
    local Actor.ImpactInfo Impact;

    if (Instigator == None || MaxConeTargets <= 0 || ConeHalfAngle <= 0.0)
    {
        return;
    }
    Start = Instigator.GetWeaponStartTraceLocation();
    Aim = Vector(GetAdjustedAim(Start));
    ConeWidth = Tan(ConeHalfAngle * DegToRad);
    foreach WorldInfo.AllPawns(Class'Pawn', Candidate, Start, TraceRange + 500.0)
    {
        Target = GetBurnTarget(Candidate);
        if (Target == None)
        {
            continue;
        }
        ToTarget = Target.Location - Start;
        Along = ToTarget Dot Aim;
        Target.GetBoundingCylinder(Radius, Height);
        if (Along <= 0.0 || Along > TraceRange + Radius || VSize(ToTarget - Along * Aim) > Along * ConeWidth + FMax(Radius, Height) || !FastTrace(Target.Location, Start))
        {
            continue;
        }
        Index = 0;
        while (Index < Distances.Length && Distances[Index] <= Along)
        {
            Index++;
        }
        if (Index < MaxConeTargets)
        {
            Targets.Insert(Index, 1);
            Targets[Index] = Target;
            Distances.Insert(Index, 1);
            Distances[Index] = Along;
            if (Targets.Length > MaxConeTargets)
            {
                Targets.Remove(MaxConeTargets, 1);
                Distances.Remove(MaxConeTargets, 1);
            }
        }
    }
    bConeHitting = TRUE;
    for (Index = 0; Index < Targets.Length; Index++)
    {
        Impact.HitActor = Targets[Index];
        Impact.HitLocation = Targets[Index].Location;
        Impact.RayDir = Normal(Targets[Index].Location - Start);
        Impact.HitNormal = -Impact.RayDir;
        Impact.StartTrace = Start;
        ProcessInstantHit_Internal(CurrentFireMode, Impact);
    }
    bConeHitting = FALSE;
}
private final function BioPawn GetBurnTarget(Actor HitActor)
{
    local BioPawn Target;

    Target = BioPawn(HitActor);
    if (Target == None || Instigator == None || Target.IsDead() || !Target.IsHostile(Instigator))
    {
        return None;
    }
    return Target;
}
// Heat mechnanic is built-up hits that causes effect once it applies
private final function AddHeat(BioPawn Target, Object.Vector HitDirection)
{
    local int Index;
    local float Now;
    local float Elapsed;
    local float Threshold;

    Now = WorldInfo.TimeSeconds;
    for (Index = HeatTargets.Length - 1; Index >= 0; Index--)
    {
        Elapsed = Now - HeatTargets[Index].LastHitTime - HeatHitWindow;
        if (HeatTargets[Index].Target == None || HeatTargets[Index].Target.IsDead() || Elapsed > 0.0 && Elapsed * HeatDecayPerSecond >= HeatTargets[Index].Heat)
        {
            HeatTargets.Remove(Index, 1);
        }
    }
    Index = HeatTargets.Find('Target', Target);
    if (Index == -1)
    {
        Index = HeatTargets.Length;
        HeatTargets.Length = Index + 1;
        HeatTargets[Index].Target = Target;
        HeatTargets[Index].LastHitTime = Now;
    }
    Elapsed = Now - HeatTargets[Index].LastHitTime;
    HeatTargets[Index].Heat = FMax(0.0, HeatTargets[Index].Heat - FMax(0.0, Elapsed - HeatHitWindow) * HeatDecayPerSecond) + FMin(Elapsed, HeatHitWindow);
    HeatTargets[Index].LastHitTime = Now;
    Threshold = Target.bUseLargeReactions ? LargeStaggerHeat : StaggerHeat;
    if (HeatTargets[Index].Heat < Threshold)
    {
        return;
    }
    if (Stagger(Target, HitDirection))
    {
        // LogInternal("Firestorm staggered " $ Target.Name $ " resist=" $ Target.ResistanceType $ " large=" $ Target.bUseLargeReactions $ " CA=" $ Target.CurrentCustomAction);
        HeatTargets[Index].Heat = 0.0;
        HeatTargets[Index].bLoggedStaggerFailure = FALSE;
    }
    else if (!HeatTargets[Index].bLoggedStaggerFailure)
    {
        // LogInternal("Firestorm stagger refused " $ Target.Name $ " resist=" $ Target.ResistanceType $ " large=" $ Target.bUseLargeReactions $ " CA=" $ Target.CurrentCustomAction);
        HeatTargets[Index].bLoggedStaggerFailure = TRUE;
    }
}
private final function bool Stagger(BioPawn Target, Vector HitDirection)
{
    local SFXCustomActionTypes.EReactionTypes Reaction;

    if (Target.bUseLargeReactions)
    {
        Reaction = EReactionTypes.Reaction_Heavy;
    }
    else
    {
        Reaction = EReactionTypes.Reaction_Medium;
    }
    if (!Target.RequestReaction(Reaction, Instigator.Controller, HitDirection))
    {
        return FALSE;
    }
    Target.ReplicateAnimatedReaction(Target.CurrentCustomAction);
    return TRUE;
}
private final function Burn(BioPawn Target)
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_FireDamageOverTime BurnEffect;
    local SFXGameEffect_PowerCombo_Fire Prime;

    Manager = Target.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager == None)
    {
        return;
    }
    if (!Target.HasAnyShieldResistance())
    {
        BurnEffect = SFXGameEffect_FireDamageOverTime(Manager.GetFirstEffectOfTypeAndCategory(Class'SFXGameEffect_FireDamageOverTime', BurnCategory));
        if (BurnEffect != None)
        {
            BurnEffect.CurrentTime = 0.0;
            BurnEffect.Duration = BurnDuration;
        }
        else
        {
            BurnEffect = SFXGameEffect_FireDamageOverTime(Manager.CreateEffect(Class'SFXGameEffect_FireDamageOverTime', BurnCategory, BurnDuration, 1, BurnDamagePerSecond, Instigator.Controller));
            if (BurnEffect != None)
            {
                BurnEffect.bCanCauseCombo = FALSE;
                BurnEffect.OnApplied();
            }
        }
    }
    if (GetAmmoPower() == None)
    {
        return;
    }
    Prime = SFXGameEffect_PowerCombo_Fire(Manager.GetFirstEffectOfTypeAndCategory(Class'SFXGameEffect_PowerCombo_Fire', Power.Name));
    if (Prime != None)
    {
        Prime.CurrentTime = 0.0;
        return;
    }
    Power.Rank = PrimeRank;
    Power.AddComboEffect(Target, Class'SFXGameEffect_PowerCombo_Fire', PrimeDuration);
}

// Override state so you don't slow down when using it
state WeaponFiring
{
    public simulated function BeginState(Name PreviousStateName)
    {
        FireStartTime = WorldInfo.GameTimeSeconds;
        Super(SFXWeapon).BeginState(PreviousStateName);
        WeaponPlayWwiseEvent(PowerUpSound1);
    }
    public simulated function EndState(Name NextStateName)
    {
        SteamMuzzle.SetActive(FALSE);
        WeaponPlayWwiseEvent(PowerDownSound1);
        Super(SFXWeapon).EndState(NextStateName);
    }

    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh
    End Template
    ScaledHeavyAmmoFamily = 'Firestorm'
    HeavyAmmoRoundsPerCharge = 100
    BurnCategory = 'Firestorm'
    BurnDamagePerSecond = 100.0
    BurnDuration = 3.0
    PrimeDuration = 5.0
    // Highest primer rank
    PrimeRank = 6.0
    StaggerHeat = 2.0
    LargeStaggerHeat = 4.0
    HeatHitWindow = 0.25
    HeatDecayPerSecond = 1.0
    ConeHalfAngle = 15.0
    MaxConeTargets = 4
    ConeDamageScale = 1.0
    bWeaponCanBeReloaded = FALSE
    bQuickSwitchEligible = FALSE
    Mesh = WeaponMesh
    DroppedPickupMesh = WeaponMesh
    PickupFactoryMesh = WeaponMesh
    Components = (WeaponMesh)
}
