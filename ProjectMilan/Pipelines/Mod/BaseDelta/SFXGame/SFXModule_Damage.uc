// 08/27/2026 - Mgamerz
// Add headshot damage scaling to support tactial scan rank 5A headshot debuff
Class SFXModule_Damage extends SFXModule_DamageNativeBase
    editinlinenew
    config(Game);

struct native DamagePart 
{
    var(DamagePart) Name PartName;
    var(DamagePart) float DamageScale;
};
enum EHealthType
{
    HealthType_Default,
    HealthType_Shields,
    HealthType_Barrier,
    HealthType_Armour,
};

var(SFXModule_Damage) ScaledFloat DamageMultiplier;
var(SFXModule_Damage) ScaledFloat PowerDamageTakenMultiplier;
var(SFXModule_Damage) ScaledFloat BioticPowerDamageTakenMultiplier;
var(SFXModule_Damage) ScaledFloat TechPowerDamageTakenMultiplier;
var(SFXModule_Damage) ScaledFloat CombatPowerDamageTakenMultiplier;
var(SFXModule_Damage) ScaledFloat WeaponDamageTakenMultiplier;
var(SFXModule_Damage) ScaledFloat PartBasedDamageMultiplier;
var(SFXModule_Damage) ScaledFloat HeadshotDamageTakenMultiplier;
var ScaledFloat AIArmorDamageReduction;
var array<DamagePart> DamageParts;
var(SFXModule_Damage) config float HeadShotVODistance;
var float DeathMomentumMultiplier;
var float AIArmorDamageReductionMinDamage;
var float AntiArmorDamageThreshold;
var config bool bGoreActorEnabled;
var bool bPartBasedDamageEnabled;
var bool bOwnerIsDead;
var(SFXModule_Damage) EHealthType HealthType;

public event simulated function HandlePostBeginPlay()
{
    local ScaledFloat sfMaxHealth;
    
    Super.HandlePostBeginPlay();
    sfMaxHealth = GetMaxHealthStats();
    sfMaxHealth.StaticBonus = 1.0;
    Class'SFXGame'.static.ReCalculate(sfMaxHealth);
    sfMaxHealth.Value = FMax(sfMaxHealth.Value, 1.0);
    SetMaxHealth(sfMaxHealth);
    SetCurrentHealth(GetMaxHealth());
    Class'SFXGame'.static.ReCalculate(DamageMultiplier);
    Class'SFXGame'.static.ReCalculate(PowerDamageTakenMultiplier);
    Class'SFXGame'.static.ReCalculate(BioticPowerDamageTakenMultiplier);
    Class'SFXGame'.static.ReCalculate(TechPowerDamageTakenMultiplier);
    Class'SFXGame'.static.ReCalculate(CombatPowerDamageTakenMultiplier);
    Class'SFXGame'.static.ReCalculate(WeaponDamageTakenMultiplier);
    Class'SFXGame'.static.ReCalculate(PartBasedDamageMultiplier);
    DeferedHandlePostBeginPlay();
}
public simulated function SFXTakeDamage(float Damage, out TraceHitInfo HitInfo, out Vector HitLocation, Vector Momentum, Class<DamageType> DamageType, Controller instigatedBy, optional Actor DamageCauser)
{
    local SFXGRI GRI;
    local Class<SFXDamageType> damageClass;
    local float ActualShieldDamage;
    local float ActualHealthDamage;
    local float TotalShieldDamage;
    local SFXDifficultyHandler DiffHandler;
    local Pawn ParentDamageCauser;
    local BioPawn BPDamageCauser;
    local bool bGenHeadShotVoc;
    local SFXModule_Armour Armour;
    local Pawn DamageCauserPawn;
    local SFXWeapon Weapon;
    local Pawn PawnOwner;
    local SFXInventoryManager PawnOwnerInv;
    local EBioCapMode PowerDamageDiscipline;
    local SFXModule_GameEffectManager InstigatorGameEffectManager;
    local float DamageScoreMP;
    local DamageCalculationAlgorithm DamageCalc;
    local stringref DamageSourceName;
    local Name HitPart;
    local int PartIdx;
    local float fArmorReduction;
    local float HeadshotMultiplier;
    local SFXPRI InstigatorPRI;
    
    GRI = SFXGRI(ModuleOwner.WorldInfo.GRI);
    damageClass = Class<SFXDamageType>(DamageType);
    if (damageClass == None)
    {
        damageClass = Class'SFXDamageType_Default';
    }
    PawnOwner = Pawn(ModuleOwner);
    if (PawnOwner != None)
    {
        PawnOwnerInv = SFXInventoryManager(PawnOwner.InvManager);
    }
    DamageCauserPawn = Class'BioPawn'.static.FindAttackingPawn(instigatedBy, DamageCauser);
    DiffHandler = GRI.DifficultyHandler;
    if (damageClass.default.bCausesNormalizedDamage && LevelScaledHealth != 0.0 && NormalizedHealth != 0.0)
    {
        Damage *= LevelScaledHealth / NormalizedHealth;
    }
    else if (DamageCauserPawn != None)
    {
        if (damageClass.default.bUsesDamageScaling)
        {
            ParentDamageCauser = DamageCauserPawn;
            while (ParentDamageCauser.Instigator != None && ParentDamageCauser.Instigator != ParentDamageCauser)
            {
                ParentDamageCauser = ParentDamageCauser.Instigator;
            }
            BPDamageCauser = BioPawn(ParentDamageCauser);
            if (SFXPawn_Henchman(ParentDamageCauser) != None)
            {
                DamageCalc.Global_DifficultyMultiplier = DiffHandler.OutHenchDamageScale;
            }
            else if (BPDamageCauser != None && BPDamageCauser.IsPlayerPawn() == FALSE)
            {
                DamageCalc.Global_DifficultyMultiplier = DiffHandler.OutAIDamageScale;
            }
            else if (Vehicle(ParentDamageCauser) != None && SFXPawn_Player(Vehicle(ParentDamageCauser).Driver) == None)
            {
                DamageCalc.Global_DifficultyMultiplier = DiffHandler.OutAIDamageScale;
            }
        }
    }
    DamageCalc.Global_DamageTakenMultiplier = DamageMultiplier.Value - float(1);
    Weapon = SFXWeapon(DamageCauser);
    if (Weapon == None && SFXProjectile(DamageCauser) != None)
    {
        Weapon = SFXWeapon(SFXProjectile(DamageCauser).ProjectileOwner);
    }
    if (Weapon != None)
    {
        DamageCalc.Source = EDamageCalculationSource.DamageCalcWeapon;
        DamageCalc.Weapon_DamageTakenMultiplier = WeaponDamageTakenMultiplier.Value - 1.0;
        Weapon.CalculateBonus(HitLocation, DamageCalc, ModuleOwner);
        DamageSourceName = Weapon.ShortPrettyName;
    }
    else if (ClassIsChildOf(damageClass, Class'SFXDamageType_Power'))
    {
        DamageCalc.Source = EDamageCalculationSource.DamageCalcPower;
        DamageCalc.BaseDamage = Damage;
        DamageCalc.Power_DamageTakenMultiplier = PowerDamageTakenMultiplier.Value - 1.0;
        PowerDamageDiscipline = Class<SFXDamageType_Power>(damageClass).default.Discipline;
        if (PowerDamageDiscipline == EBioCapMode.BIO_CAPMODE_BIOTICS)
        {
            DamageCalc.Power_DamageTakenMultiplier += BioticPowerDamageTakenMultiplier.Value - 1.0;
        }
        else if (PowerDamageDiscipline == EBioCapMode.BIO_CAPMODE_TECH)
        {
            DamageCalc.Power_DamageTakenMultiplier += TechPowerDamageTakenMultiplier.Value - 1.0;
        }
        else if (PowerDamageDiscipline == EBioCapMode.BIO_CAPMODE_COMBAT)
        {
            DamageCalc.Power_DamageTakenMultiplier += CombatPowerDamageTakenMultiplier.Value - 1.0;
        }
        if (damageClass.default.bIsMelee && DamageCauserPawn != None)
        {
            Weapon = SFXWeapon(DamageCauserPawn.Weapon);
            if (Weapon != None)
            {
                DamageCalc.Power_WeaponMeleeDamageMultiplier = Weapon.MeleeDamageModifier.Value - 1.0;
            }
        }
        DamageSourceName = damageClass.default.SourceDisplayName;
    }
    else if (damageClass.default.bIsMelee)
    {
        DamageCalc.Source = EDamageCalculationSource.DamageCalcPower;
        DamageCalc.BaseDamage = Damage;
        if (DamageCauserPawn != None)
        {
            Weapon = SFXWeapon(DamageCauserPawn.Weapon);
            if (Weapon != None)
            {
                DamageCalc.Power_WeaponMeleeDamageMultiplier = Weapon.MeleeDamageModifier.Value - 1.0;
            }
        }
        DamageSourceName = damageClass.default.SourceDisplayName;
    }
    if (bPartBasedDamageEnabled && damageClass.default.bPartBasedDamageDisabled == FALSE)
    {
        HitPart = GetPartFromHit(HitInfo);
        if (HitPart != 'None')
        {
            if (DamageParts.Length > 0)
            {
                PartIdx = DamageParts.Find('PartName', HitPart);
                if (PartIdx != -1)
                {
                    DamageCalc.Global_DamageTakenMultiplier += DamageParts[PartIdx].DamageScale - 1.0;
                }
            }
            if (HitPart == 'Head')
            {
                bGenHeadShotVoc = TRUE;
                DamageCalc.Global_HeadshotTakenMultiplier = PartBasedDamageMultiplier.Value - 1.0;
                // MILAN CHANGE - Add support for headshot multiplier (for Tactical Scan)
                DamageCalc.Global_HeadshotTakenMultiplier += HeadshotDamageTakenMultiplier.Value - 1.0;
                // END MILAN CHANGE
                if (DamageCauserPawn != None && SFXWeapon(DamageCauserPawn.Weapon) != None)
                {
                    if (SFXPawn(PawnOwner) != None)
                    {
                        HeadshotMultiplier = SFXPawn(PawnOwner).HeadshotMultiplier;
                    }
                    if (HeadshotMultiplier != 0.0)
                    {
                        DamageCalc.Weapon_HeadshotDamageMultiplier = HeadshotMultiplier;
                    }
                    else
                    {
                        DamageCalc.Weapon_HeadshotDamageMultiplier = SFXWeapon(DamageCauserPawn.Weapon).HeadshotDamageMultiplier.Value - 1.0;
                    }
                    InstigatorGameEffectManager = DamageCauserPawn.GetModule(Class'SFXModule_GameEffectManager');
                    if (InstigatorGameEffectManager != None)
                    {
                        DamageCalc.Weapon_PawnEffectsHeadshotDamageMultiplier = InstigatorGameEffectManager.WeaponPassiveConstraintDamageBonus.Value - 1.0;
                    }
                }
            }
        }
    }
    if (GRI != None)
    {
        if (GRI.ModifyDamage(Damage, HitInfo, HitLocation, Momentum, damageClass, ModuleOwner, instigatedBy, DamageCalc, DamageCauser) == FALSE)
        {
            Damage = 0.0;
        }
    }
    if (BioPawn(ModuleOwner) != None)
    {
        if (BioPawn(ModuleOwner).ModifyDamage(Damage, Momentum, DamageCalc, HitInfo, HitLocation, damageClass, instigatedBy, DamageCauser) == FALSE)
        {
            Damage = 0.0;
        }
    }
    Damage = Damage * Class'SFXDamageType'.static.CalculateDamageMultiplier(DamageCalc);
    DamageCalc.TargetName = ModuleOwner.Name;
    DamageCalc.DamageClassName = DamageType.Name;
    DamageCalc.ActualDamageDealt = Damage;
    if (Damage > float(0))
    {
        ActualShieldDamage = Damage;
        if (PawnOwnerInv != None)
        {
            PawnOwnerInv.ProcessDamage(Damage, HitInfo, HitLocation, Momentum, damageClass, instigatedBy, DamageCauser, TotalShieldDamage);
        }
        ActualShieldDamage = FMax(0.0, ActualShieldDamage - Damage);
    }
    if (Damage > float(0))
    {
        Armour = ModuleOwner.GetModule(Class'SFXModule_Armour');
        if (Armour != None)
        {
            Armour.ApplyDamage(Damage, HitInfo, HitLocation, Momentum, damageClass, instigatedBy, DamageCauser);
        }
    }
    if (Damage > 0.0 && (HealthType != EHealthType.HealthType_Default || damageClass.default.bHealthDamage))
    {
        if (SFXWeapon(DamageCauser) != None && HealthType == EHealthType.HealthType_Armour)
        {
            fArmorReduction = AIArmorDamageReduction.Value - AIArmorDamageReduction.Value * FClamp(SFXWeapon(DamageCauser).ArmorPiercing.Value - 1.0, 0.0, 1.0);
            if (Damage > AIArmorDamageReductionMinDamage && fArmorReduction > float(0))
            {
                Damage -= fArmorReduction;
                if (Damage < AIArmorDamageReductionMinDamage)
                {
                    Damage = AIArmorDamageReductionMinDamage;
                }
            }
        }
        ApplyDamageToHealth(Damage, instigatedBy, damageClass, HitLocation, ActualHealthDamage);
        if (damageClass.default.bSpawnWeaponImpacts)
        {
            PlayHitEffects(HitInfo, HitLocation, DamageCauser);
        }
        if (GRI != None && GRI.bMultiplayer && GRI.NumLivingPlayers() > 1 && DamageCauserPawn != None && SFXPawn_Player(DamageCauserPawn) != None)
        {
            if (damageClass.default.bIsMelee)
            {
                GRI.TriggerVocalizationEvent(119, SFXPawn(ModuleOwner));
            }
            else
            {
                GRI.TriggerVocalizationEvent(120, SFXPawn(ModuleOwner));
            }
            SFXPawn_Player(DamageCauserPawn).SetThreat(SFXPawn(ModuleOwner), damageClass.default.bIsMelee);
        }
    }
    if (PawnOwner != None && !PawnOwner.IsDead())
    {
        DamageCalc.ActualDamageApplied = ActualHealthDamage + ActualShieldDamage;
        if (SFXPawn_Player(DamageCauserPawn) == None || SFXPawn_Player(PawnOwner) == None)
        {
            PawnOwner.NotifyTakeHit(instigatedBy, HitLocation, int(ActualHealthDamage + ActualShieldDamage), damageClass, Momentum);
        }
    }
    if (instigatedBy != None)
    {
        InstigatorPRI = SFXPRI(instigatedBy.PlayerReplicationInfo);
        if (InstigatorPRI != None)
        {
            InstigatorPRI.StoreDamageCalculation(DamageCalc);
        }
    }
    DamageScoreMP = TotalShieldDamage + ActualHealthDamage;
    if (DamageScoreMP > float(0) && GRI != None && GRI.bMultiplayer)
    {
        SFXPawn(PawnOwner).AddDamageEvent(SFXPawn(DamageCauserPawn), instigatedBy, DamageScoreMP, DamageSourceName);
    }
    ProcessHit(Damage, HitInfo, HitLocation, Momentum, damageClass, instigatedBy, DamageCauser, bGenHeadShotVoc);
}
public simulated function SFXTakeRadiusDamage(float Damage, float DamageRadius, bool bFullDamage, Vector HurtOrigin, float Momentum, Class<DamageType> DamageType, Controller instigatedBy, Actor DamageCauser, optional TraceHitInfo HitInfo)
{
    local float ColRadius;
    local float ColHeight;
    local float Dist;
    local float Scale;
    local Vector Dir;
    local bool bConstantFalloff;
    
    ModuleOwner.GetBoundingCylinder(ColRadius, ColHeight);
    Dir = ModuleOwner.location - HurtOrigin;
    Dist = VSize(Dir);
    Dir = Normal(Dir);
    if (Class<SFXDamageType>(DamageType) != None && Class<SFXDamageType>(DamageType).default.FalloffType == ESFXDamageFalloffType.DamageFalloffType_Linear)
    {
        bConstantFalloff = TRUE;
    }
    if (bFullDamage || bConstantFalloff)
    {
        Scale = 1.0;
    }
    else
    {
        Dist = FClamp(Dist - ColRadius, 0.0, DamageRadius);
        Scale = 1.0 - Dist / DamageRadius;
    }
    ModuleOwner.TakeDamage(Damage * Scale, instigatedBy, ModuleOwner.location - Dir * ColRadius, Dir * Momentum * Scale, DamageType, HitInfo, DamageCauser);
    if (int(GetActorRole()) == 3)
    {
        if (BioPawn(ModuleOwner) != None && SFXWeapon(DamageCauser) == None)
        {
            BioPawn(ModuleOwner).ReplicateRadiusDamage(Damage * Scale, ModuleOwner.location - Dir * ColRadius, Dir * Momentum * Scale, DamageType, DamageCauser);
        }
    }
}
public simulated function ApplyDamageToHealth(float Damage, Controller instigatedBy, Class<SFXDamageType> DamageType, Vector HitLocation, out float AppliedDamage)
{
    local float Health;
    
    if (HealthType != EHealthType.HealthType_Default)
    {
        switch (HealthType)
        {
            case EHealthType.HealthType_Shields:
                Damage *= DamageType.default.Resistance.Shield;
                break;
            case EHealthType.HealthType_Barrier:
                Damage *= DamageType.default.Resistance.Biotic;
                break;
            case EHealthType.HealthType_Armour:
                Damage *= DamageType.default.Resistance.Armour;
                break;
            default:
        }
    }
    Health = GetCurrentHealth() - Damage;
    AppliedDamage = Damage;
    if (Health < float(1) && (ModuleOwner.Role < ENetRole.ROLE_Authority || ModuleOwner.WorldInfo.Game != None && ModuleOwner.WorldInfo.Game.PreventDeath(Pawn(ModuleOwner), instigatedBy, DamageType, HitLocation)))
    {
        SetCurrentHealth(1.0);
    }
    else
    {
        SetCurrentHealth(Health);
    }
}
public simulated function DeferedHandlePostBeginPlay()
{
    local SFXDifficultyHandler DH;
    
    if (ModuleOwner == None || ModuleOwner.WorldInfo == None)
    {
        return;
    }
    if (ModuleOwner.WorldInfo.GRI != None)
    {
        DH = SFXGRI(ModuleOwner.WorldInfo.GRI).DifficultyHandler;
        if (DH != None && SFXPawn_PlayerParty(ModuleOwner) == None)
        {
            AIArmorDamageReduction.X = DH.GetFloat('AIArmorDamageReduction', 'Global');
            AIArmorDamageReduction.Y = AIArmorDamageReduction.X;
            Class'SFXGame'.static.ReCalculate(AIArmorDamageReduction);
        }
        if (BioPawn(ModuleOwner) != None)
        {
            switch (HealthType)
            {
                case EHealthType.HealthType_Shields:
                    BioPawn(ModuleOwner).SetResistance(1, TRUE);
                    break;
                case EHealthType.HealthType_Barrier:
                    BioPawn(ModuleOwner).SetResistance(2, TRUE);
                    break;
                case EHealthType.HealthType_Armour:
                    BioPawn(ModuleOwner).SetResistance(3, TRUE);
                    break;
                default:
            }
        }
    }
    else
    {
        ModuleOwner.SetTimer(0.100000001, FALSE, 'DeferedHandlePostBeginPlay', Self);
    }
}
public final simulated function Name GetPartFromHit(out TraceHitInfo HitInfo)
{
    local BioPawn OwnerPawn;
    
    OwnerPawn = BioPawn(ModuleOwner);
    if (OwnerPawn != None)
    {
        return OwnerPawn.GetPartFromHit(HitInfo);
    }
    return 'None';
}
public simulated function bool KillForStasis(bool bImmediate, optional Controller Killer, optional Class<DamageType> DamageType)
{
    local BioPawn BP;
    
    BP = BioPawn(ModuleOwner);
    if (BP != None)
    {
        if (Killer == None)
        {
            Killer = BP.LastHitBy;
        }
        if (DamageType == None)
        {
            DamageType = Class'SFXDamageType_Suicide';
        }
        if (BP.bCanBeDamaged && BP.m_bPlotProtected == FALSE && BP.InGodMode() == FALSE)
        {
            if (BP.WorldInfo == None || BP.WorldInfo.Game == None || BP.WorldInfo.Game.PreventDeath(BP, Killer, DamageType, vect(0.0, 0.0, 0.0)) == FALSE)
            {
                BP.Died(Killer, DamageType, vect(0.0, 0.0, 0.0));
                if (BP.IsDead() == FALSE || bImmediate && BP.bDeleteMe == FALSE)
                {
                    BP.Destroy();
                }
                return TRUE;
            }
        }
    }
    return FALSE;
}
public final simulated function PlayHitEffects(const out TraceHitInfo HitInfo, Vector HitLocation, Actor DamageCauser)
{
    local SFXWeapon Weapon;
    local ImpactInfo Impact;
    
    Weapon = SFXWeapon(DamageCauser);
    if (Weapon != None)
    {
        Impact.HitInfo = HitInfo;
        Impact.HitActor = ModuleOwner;
        Impact.HitLocation = HitLocation;
        if (Weapon.Instigator != None)
        {
            Impact.HitNormal = Normal(Weapon.Instigator.location - HitLocation);
            Impact.RayDir = Impact.HitNormal * -1.0;
        }
        Weapon.SpawnImpactEffects(Impact);
        Weapon.SpawnImpactSounds(Impact);
    }
}
public simulated function ProcessHit(float Damage, out TraceHitInfo HitInfo, Vector HitLocation, Vector Momentum, Class<SFXDamageType> DamageType, Controller instigatedBy, Actor DamageCauser, bool HeadShot)
{
    local Pawn PawnOwner;
    local Controller Killer;
    local Pawn InstigatorPawn;
    local SFXPawn_Player OtherPlayer;
    local SFXPawn SFXPawnOwner;
    
    PawnOwner = Pawn(ModuleOwner);
    if (PawnOwner != None)
    {
        InstigatorPawn = Class'BioPawn'.static.FindAttackingPawn(instigatedBy, DamageCauser);
        PawnOwner.PlayHit(Damage, instigatedBy, HitLocation, DamageType, Momentum, HitInfo, InstigatorPawn);
        PawnOwner.MakeNoise(1.0, );
        if (GetCurrentHealth() > float(0))
        {
            if (instigatedBy != None && instigatedBy != PawnOwner.Controller)
            {
                PawnOwner.LastHitBy = instigatedBy;
            }
            if (ClassIsChildOf(DamageType, Class'SFXDamageType_Weapon'))
            {
                PawnOwner.HandleMomentum(Momentum, HitLocation, DamageType, HitInfo);
            }
        }
        else if (!bOwnerIsDead)
        {
            bOwnerIsDead = TRUE;
            Killer = PawnOwner.SetKillInstigator(instigatedBy, DamageType);
            if (SFXWeapon(DamageCauser) != None)
            {
                Momentum *= SFXWeapon(DamageCauser).ImpactForceModifier.Value;
            }
            PawnOwner.TearOffMomentum = Momentum * DeathMomentumMultiplier;
            if (BioPawn(PawnOwner) != None)
            {
                BioPawn(PawnOwner).DeathHitBoneName = HitInfo.BoneName;
            }
            PawnOwner.PlayDyingSound();
            SFXPawnOwner = SFXPawn(PawnOwner);
            if (SFXPawnOwner != None)
            {
                SFXPawnOwner.PlayDeathEffect(DamageType, Killer);
                SFXPawnOwner.ReplicatedDeathInfo.bHeadShot = HeadShot;
                if (SFXPawnOwner.Mesh.IsBoneHidden(SFXPawnOwner.Mesh.MatchRefBone('Head')))
                {
                    SFXPawnOwner.ReplicatedDeathInfo.bHeadGib = TRUE;
                }
            }
            PawnOwner.Died(Killer, DamageType, HitLocation);
            if (Killer != None && (Killer.Pawn.IsHumanControlled() || Killer.Instigator != None && Killer.Instigator.IsHumanControlled()) && SFXGRI(ModuleOwner.WorldInfo.GRI).GetScoreManager() != None)
            {
                SFXGRI(ModuleOwner.WorldInfo.GRI).GetScoreManager().ProcessKill(PawnOwner, Damage, DamageType, instigatedBy, DamageCauser, HeadShot);
            }
            if (ModuleOwner.Role == ENetRole.ROLE_Authority && ModuleOwner.WorldInfo != None && ModuleOwner.WorldInfo.GRI.IsMultiplayerGame() && HeadShot && Killer != None && SFXPawn_Player(Killer.Pawn) != None)
            {
                foreach ModuleOwner.WorldInfo.AllPawns(Class'SFXPawn_Player', OtherPlayer)
                {
                    if (OtherPlayer != SFXPawn_Player(Killer.Pawn) && VSizeSq(OtherPlayer.location - Killer.Pawn.location) <= HeadShotVODistance * HeadShotVODistance)
                    {
                        SFXGRI(ModuleOwner.WorldInfo.GRI).TriggerVocalizationEvent(126, OtherPlayer, , , , TRUE);
                        break;
                    }
                }
            }
            if (Killer != None)
            {
                if (Killer.Pawn != None && Killer.Pawn.IsHumanControlled() && BioPlayerController(Killer) != None)
                {
                    BioPlayerController(Killer).UpdateTrilogyGrinderStatProgression(0);
                }
                else if (Killer.Instigator != None && Killer.Instigator.IsHumanControlled() && BioPlayerController(Killer.Instigator.Controller) != None)
                {
                    BioPlayerController(Killer.Instigator.Controller).UpdateTrilogyGrinderStatProgression(0);
                }
            }
            if (Killer != None && Killer.Pawn.IsHumanControlled() && DamageType.default.bIsMelee && BioPlayerController(Killer) != None)
            {
                BioPlayerController(Killer).UpdateAccomplishmentProgression('MELEEKILLCOUNT');
                BioPlayerController(Killer).UpdateTrilogyGrinderStatProgression(1);
            }
            if (Killer != None)
            {
                if (Killer.Pawn.IsHumanControlled())
                {
                    Class'SFXTelemetry'.static.IncSessionPlayerKills(1);
                    Class'SFXTelemetry'.static.IncSessionTeamKills(1);
                }
                else if (Killer.Pawn.InPlayerParty())
                {
                    Class'SFXTelemetry'.static.IncSessionTeamKills(1);
                }
            }
            if (PawnOwner.IsHumanControlled())
            {
                Class'SFXTelemetry'.static.IncSessionPlayerDeaths(1);
                Class'SFXTelemetry'.static.IncSessionTeamDeaths(1);
            }
            else if (PawnOwner.InPlayerParty())
            {
                Class'SFXTelemetry'.static.IncSessionTeamDeaths(1);
            }
        }
    }
    else if (GetCurrentHealth() < 0.0)
    {
        ModuleOwner.Destroy();
    }
}
public simulated function SetPlayerHealthFromSave(float Health);


//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    DamageMultiplier = {
                        Bonuses = (), 
                        X = 1.0, 
                        Y = 1.0, 
                        MaxLevel = 100, 
                        Level = 0, 
                        Value = 0.0, 
                        StaticBonus = 1.0
                       }
    PowerDamageTakenMultiplier = {
                                  Bonuses = (), 
                                  X = 1.0, 
                                  Y = 1.0, 
                                  MaxLevel = 100, 
                                  Level = 0, 
                                  Value = 0.0, 
                                  StaticBonus = 1.0
                                 }
    BioticPowerDamageTakenMultiplier = {
                                        Bonuses = (), 
                                        X = 1.0, 
                                        Y = 1.0, 
                                        MaxLevel = 100, 
                                        Level = 0, 
                                        Value = 0.0, 
                                        StaticBonus = 1.0
                                       }
    TechPowerDamageTakenMultiplier = {
                                      Bonuses = (), 
                                      X = 1.0, 
                                      Y = 1.0, 
                                      MaxLevel = 100, 
                                      Level = 0, 
                                      Value = 0.0, 
                                      StaticBonus = 1.0
                                     }
    CombatPowerDamageTakenMultiplier = {
                                        Bonuses = (), 
                                        X = 1.0, 
                                        Y = 1.0, 
                                        MaxLevel = 100, 
                                        Level = 0, 
                                        Value = 0.0, 
                                        StaticBonus = 1.0
                                       }
    WeaponDamageTakenMultiplier = {
                                   Bonuses = (), 
                                   X = 1.0, 
                                   Y = 1.0, 
                                   MaxLevel = 100, 
                                   Level = 0, 
                                   Value = 0.0, 
                                   StaticBonus = 1.0
                                  }
    PartBasedDamageMultiplier = {
                                 Bonuses = (), 
                                 X = 1.0, 
                                 Y = 1.0, 
                                 MaxLevel = 100, 
                                 Level = 0, 
                                 Value = 0.0, 
                                 StaticBonus = 1.0
                                }
    AIArmorDamageReduction = {
                              Bonuses = (), 
                              X = 0.0, 
                              Y = 0.0, 
                              MaxLevel = 100, 
                              Level = 0, 
                              Value = 0.0, 
                              StaticBonus = 1.0
                             }
    HeadShotVODistance = 500.0
    DeathMomentumMultiplier = 10.0
    AIArmorDamageReductionMinDamage = 5.0
    AntiArmorDamageThreshold = 0.200000003
    bPartBasedDamageEnabled = TRUE
    HeadshotDamageTakenMultiplier = {
                                     Bonuses = (), 
                                     X = 1.0, 
                                     Y = 1.0, 
                                     MaxLevel = 100, 
                                     Level = 0, 
                                     Value = 0.0, 
                                     StaticBonus = 1.0
                                    }
}