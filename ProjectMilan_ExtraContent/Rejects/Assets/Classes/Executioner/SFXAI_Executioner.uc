Class SFXAI_Executioner extends SFXAI_Cover
    placeable
    config(AI);

enum CloneClassType
{
    CloneClass_Soldier,
    CloneClass_Adept,
    CloneClass_Engineer,
    CloneClass_Infiltrator,
    CloneClass_Sentinel,
    CloneClass_Vanguard,
};

var Guid Guid_DefensiveCrust;
var RvrClientEffectInterface CE_TechArmor_Male;
var RvrClientEffectInterface CE_TechArmor_Female;
var RvrClientEffectInterface CE_Barrier;
var RvrClientEffectInterface CE_AdrenalineRush;
var RvrClientEffectInterface CE_DefensiveMatrix;
var ParticleSystem PS_FireHologramTemplate;
var ParticleSystem PS_FireIconTemplate;
var WwiseEvent WWise_FireAmmoSound;
var ParticleSystem PS_FireMuzzleVFX;
var ParticleSystem PS_FireMuzzleLoopVFX;
var Actor TeleportLocation;
var SFXPawn FemmePawn;
var transient float LastGrenadeTime;
var float GrenadeInterval;
var transient float LastPowerTime;
var float PowerInterval;
var float GrenadeConeAngle;
var float PowerToFiringRatio;
var float StageTwo_ShieldRechargeDelayMultiplier;
var float StageTwo_ShieldBonusMultiplier;
var float StageTwo_WeaponDamageMultiplier;
var float StageTwo_NewIdealRange;
var float StageTwo_SentinelDamageReduction;
var float StageTwo_VanguardChargeFrequencyBonus;
var float StageTwo_InfiltratorAgressiveFrequencyMultiplier;
var float StageTwo_AdeptPowerDamageBonus;
var float StageTwo_SoldierGrenadeFrequencyMultiplier;
var float StageTwo_SoldierWeaponDamageMultiplier;
var float MinTimeBetweenDrones;
var float LastDroneTime;
var float Shield_StartingMax;
var float Shield_StartRegenDelay;
var float CloneRetreatDistance;
var float CloneSpeedBoostDuration;
var float CLoneSpeedIncrease;
var float InfiltratorSpeedIncrease;
var float RushTimeout;
var float Rush_CloneSyncRange;
var float Rush_CloneHealthMinPercent;
var float Rush_StopFiringRange;
var float MinTimeBetweenCloaks;
var float LastCloakTime;
var float LastTeleportTime;
var float MinTeleportInterval;
var float MinTeleportInterval_Rush;
var float TeleportChance;
var int MaxChargesPerRush;
var int ChargeCountThisRush;
var float EnemyDistance_VanguardMelee;
var float SyncMeleeAttackInterval_Vanguard;
var float MaxRezDistance;
var float PlayerCampingDistance;
var stringref GameName_Soldier;
var stringref GameName_Adept;
var stringref GameName_Engineer;
var stringref GameName_Sentinel;
var stringref GameName_Vanguard;
var stringref GameName_Infiltrator;
var bool bThrowGrenade;
var bool bStageTwoActive;
var bool bPlayerLockedOn;
var bool bPlayerSynced;
var bool bCloaked;
var bool bRushChargingActive;
var bool bEndBehaviorActive;
var bool bHasRushPriority;
var bool bSimFightActive;
var CloneClassType CloneClass;

public function Destroyed()
{
    local SFXPowerCustomAction_CloneDenial DenialGrenade;
    
    DenialGrenade = SFXPowerCustomAction_CloneDenial(MyBP.PowerManager.GetPowerByClass(Class'SFXPowerCustomAction_CloneDenial'));
    if (DenialGrenade != None)
    {
        DenialGrenade.ClearDenialZones();
    }
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_AdrenalineRush, Guid_DefensiveCrust, FALSE);
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_Barrier, Guid_DefensiveCrust, FALSE);
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_DefensiveMatrix, Guid_DefensiveCrust, FALSE);
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_TechArmor_Female, Guid_DefensiveCrust, FALSE);
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_TechArmor_Male, Guid_DefensiveCrust, FALSE);
    Super(BioAiController).Destroyed();
}
public function Initialize()
{
    local SFXDifficultyHandler DH;
    local SFXModule_Damage DmgMod;
    local SFXShield_Base PawnShield;
    local SFXPowerCustomAction_CloneDenial DenialPower;
    local SFXPowerCustomAction_CloneProjectile ProjectilePower;
    local SFXPawn_Player PlayerPawn;
    local PlayerController PC;
    local int idx;
    
    if (MyBP.WorldInfo != None)
    {
        PC = MyBP.WorldInfo.GetALocalPlayerController();
        if (PC != None)
        {
            PlayerPawn = SFXPawn_Player(PC.Pawn);
        }
    }
    if (PlayerPawn.IsA('SFXPawn_PlayerSentinel') == TRUE)
    {
        CloneClass = CloneClassType.CloneClass_Sentinel;
    }
    else if (PlayerPawn.IsA('SFXPawn_PlayerVanguard') == TRUE)
    {
        CloneClass = CloneClassType.CloneClass_Vanguard;
    }
    else if (PlayerPawn.IsA('SFXPawn_PlayerInfiltrator') == TRUE)
    {
        CloneClass = CloneClassType.CloneClass_Infiltrator;
    }
    else if (PlayerPawn.IsA('SFXPawn_PlayerEngineer') == TRUE)
    {
        CloneClass = CloneClassType.CloneClass_Engineer;
    }
    else if (PlayerPawn.IsA('SFXPawn_PlayerAdept') == TRUE)
    {
        CloneClass = CloneClassType.CloneClass_Adept;
    }
    else
    {
        CloneClass = CloneClassType.CloneClass_Soldier;
    }
    DH = SFXGRI(WorldInfo.GRI).DifficultyHandler;
    if (DH != None)
    {
        MeleeAttackInterval = DH.GetFloat('MeleeAttackInterval', 'Executioner');
        CancelFirePct = DH.GetFloat('CancelFirePct', 'Executioner');
        MaxFireWaitTime = DH.GetFloat('MaxFireWaitTime', 'Executioner');
        EvadeDamagePct.X = DH.GetFloat('EvadeDamagePctLow', 'Executioner');
        EvadeDamagePct.Y = DH.GetFloat('EvadeDamagePctHigh', 'Executioner');
        EvadeFrequency = DH.GetFloat('EvadeFrequency', 'Executioner');
        EvadeResetDuration = DH.GetFloat('EvadeResetDuration', 'Executioner');
        PartialLeanPct = DH.GetFloat('PartialLeanPct', 'Executioner');
        PowerEvadeChance = DH.GetFloat('PowerEvadeChance', 'Executioner');
        FlankReactionTime = DH.GetFloat('FlankReactionTime', 'Executioner');
        GrenadeInterval = DH.GetFloat('GrenadeInterval', 'Executioner');
        DmgMod = MyBP.GetModule(Class'SFXModule_Damage');
        if (DmgMod != None)
        {
            DmgMod.NormalizedHealth = DH.GetFloatNormalized('MaxHealth', 'Executioner');
            DmgMod.LevelScaledHealth = DH.GetFloat('MaxHealth', 'Executioner');
            DmgMod.InitializeMaxHealth(DmgMod.LevelScaledHealth);
        }
        PawnShield = SFXShield_Base(MyBP.InvManager.FindInventoryType(Class'SFXShield_Base', TRUE));
        if (PawnShield != None)
        {
            PawnShield.InitializeMaxShields(DH.GetFloat('MaxShields', 'Executioner'));
            Shield_StartingMax = DH.GetFloat('MaxShields', 'Executioner');
            PawnShield.MaxEnemyShieldRecharge = DH.GetFloat('MaxEnemyShieldRecharge', 'Executioner');
            if (PawnShield.MaxEnemyShieldRecharge > 0.0)
            {
                PawnShield.bRechargeable = TRUE;
                PawnShield.ShieldRegenPct = DH.GetFloat('AIShieldRegenPct', 'Executioner');
                PawnShield.ShieldRegenDelay.X = DH.GetMinFloat('AIShieldRegenDelay', 'Executioner');
                PawnShield.ShieldRegenDelay.Y = DH.GetMaxFloat('AIShieldRegenDelay', 'Executioner');
                PawnShield.ShieldRegenDelay.Value = DH.GetFloat('AIShieldRegenDelay', 'Executioner');
                Shield_StartRegenDelay = DH.GetFloat('AIShieldRegenDelay', 'Executioner');
            }
        }
        if (MyBP != None)
        {
            MyBP.PowerThreshold_Standard = DH.GetFloat('PowerThreshold_Standard', 'Executioner');
            MyBP.PowerThreshold_Stagger = DH.GetFloat('PowerThreshold_Stagger', 'Executioner');
            MyBP.PowerThreshold_Knockback = DH.GetFloat('PowerThreshold_Knockback', 'Executioner');
            MyBP.HitReactionChanceMultiplier = DH.GetFloat('HitReactionChanceMultiplier', 'Executioner');
        }
        if (MyBP != None && MyBP.PowerManager != None)
        {
            DenialPower = SFXPowerCustomAction_CloneDenial(MyBP.PowerManager.GetPowerByClass(Class'SFXPowerCustomAction_CloneDenial'));
            if (DenialPower != None)
            {
                DenialPower.DenialDamage = DH.GetFloat('DenialDamage', 'Executioner');
            }
            for (idx = 0; idx < MyBP.PowerManager.Powers.Length; idx++)
            {
                if (ClassIsChildOf(MyBP.PowerManager.Powers[idx].Class, Class'SFXPowerCustomAction_CloneProjectile'))
                {
                    ProjectilePower = SFXPowerCustomAction_CloneProjectile(MyBP.PowerManager.Powers[idx]);
                    if (ProjectilePower != None)
                    {
                        ProjectilePower.Damage.BaseValue = DH.GetFloat('ProjectileDamage', 'Executioner');
                        ProjectilePower.RecalculateAllPowerData();
                    }
                }
            }
        }
        if (WorldInfo != None)
        {
            LastSyncMeleeTime = WorldInfo.GameTimeSeconds;
        }
    }
    InitializeClassSpecific();
    Super(SFXAI_Core).Initialize();
}
public event function NotifyPlayerFocus()
{
    if (MyBP == None)
    {
        return;
    }
    if (MyBP.GetCurrentShields() > float(0))
    {
        ShootWeaponAtFireTarget(MyBP.GetMaxHealth() * CancelFirePct);
    }
    if (MyBP.IsInCover())
    {
        FindNewCover();
    }
}
public final function bool ShouldUsePower()
{
    local SFXPowerCustomAction Power;
    
    if (CanAttack(FireTarget) == FALSE)
    {
        return FALSE;
    }
    if (WorldInfo.GameTimeSeconds - LastPowerTime > PowerInterval)
    {
        Power = SFXPowerCustomAction(MyBP.PowerManager.GetPower(GetPowerName()));
        if (Power != None && Power.CanUsePower(FireTarget))
        {
            return TRUE;
        }
    }
    return FALSE;
}
public function NotifyTakeHit(Controller instigatedBy, Vector HitLocation, int Damage, Class<DamageType> DamageType, Vector Momentum)
{
    Super.NotifyTakeHit(instigatedBy, HitLocation, Damage, DamageType, Momentum);
    if (MyBP.GetCurrentShields() <= 0.0)
    {
        FindNewCover();
    }
}
public function DoMeleeAttack()
{
    local SFXPawn EnemyPawn;
    local float SyncInterval;
    local bool bSyncSuccessful;
    
    if (CloneClass == CloneClassType.CloneClass_Vanguard)
    {
        SyncInterval = SyncMeleeAttackInterval_Vanguard;
    }
    else
    {
        SyncInterval = SyncMeleeAttackInterval;
    }
    if (SFXPawn_Player(FireTarget) != None && WorldInfo.GameTimeSeconds - LastSyncMeleeTime > SyncInterval)
    {
        EnemyPawn = SFXPawn(Enemy);
        if (EnemyPawn != None)
        {
            EnemyPawn.SetAbilityTimeStamp(SyncMeleeAbilityName);
        }
        if (MyBP.StartCustomAction(135, Enemy) == TRUE)
        {
            bSyncSuccessful = TRUE;
        }
    }
    if (!bSyncSuccessful)
    {
        LastCombatActionTime = WorldInfo.GameTimeSeconds;
        if (CloneClass == CloneClassType.CloneClass_Sentinel)
        {
            MyBP.StartCustomAction(205);
        }
        else if (CloneClass == CloneClassType.CloneClass_Vanguard)
        {
            MyBP.StartCustomAction(206);
        }
        else if (CloneClass == CloneClassType.CloneClass_Infiltrator)
        {
            MyBP.StartCustomAction(207);
        }
        else if (CloneClass == CloneClassType.CloneClass_Engineer)
        {
            MyBP.StartCustomAction(208);
        }
        else if (CloneClass == CloneClassType.CloneClass_Adept)
        {
            MyBP.StartCustomAction(209);
        }
        else
        {
            MyBP.StartCustomAction(210);
        }
    }
}
public function DrawDifficulty(BioCheatManager CM)
{
    local SFXDifficultyHandler DH;
    local Name ParamName;
    local Name CategoryName;
    local SFXModule_Damage DmgMod;
    
    DH = SFXGRI(WorldInfo.GRI).DifficultyHandler;
    if (DH != None)
    {
        CategoryName = 'Executioner';
        CM.DrawProfileHeaderText("Health: ");
        ParamName = 'MaxHealth';
        DmgMod = MyBP.GetModule(Class'SFXModule_Damage');
        if (DmgMod != None)
        {
            CM.DrawProfileText(DmgMod.GetMaxHealth() @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        }
        CM.DrawProfileText(" ");
        CM.DrawProfileHeaderText("MeleeAttackInterval: ");
        ParamName = 'MeleeAttackInterval';
        CM.DrawProfileText(MeleeAttackInterval @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("CancelFirePct: ");
        ParamName = 'CancelFirePct';
        CM.DrawProfileText(CancelFirePct @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("MaxFireWaitTime: ");
        ParamName = 'MaxFireWaitTime';
        CM.DrawProfileText(MaxFireWaitTime @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("EvadeHealthThreshold: ");
        CM.DrawProfileText(string(EvadeHealthThreshold));
        CM.DrawProfileHeaderText("EvadeDamagePctLow: ");
        ParamName = 'EvadeDamagePctLow';
        CM.DrawProfileText("(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("EvadeDamagePctHigh: ");
        ParamName = 'EvadeDamagePctHigh';
        CM.DrawProfileText("(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("EvadeFrequency: ");
        ParamName = 'EvadeFrequency';
        CM.DrawProfileText(EvadeFrequency @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("EvadeResetDuration: ");
        ParamName = 'EvadeResetDuration';
        CM.DrawProfileText(EvadeResetDuration @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("PartialLeanPct: ");
        ParamName = 'PartialLeanPct';
        CM.DrawProfileText(PartialLeanPct @ "(" @ DH.GetFloat(ParamName, CategoryName) @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("PowerEvadeChance: ");
        ParamName = 'PowerEvadeChance';
        CM.DrawProfileText(PowerEvadeChance @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("FlankReactionTime: ");
        ParamName = 'FlankReactionTime';
        CM.DrawProfileText(FlankReactionTime @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        if (MyBP != None)
        {
            CM.DrawProfileHeaderText("PowerThreshold_Standard: ");
            ParamName = 'PowerThreshold_Standard';
            CM.DrawProfileText(MyBP.PowerThreshold_Standard @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
            CM.DrawProfileHeaderText("PowerThreshold_Stagger: ");
            ParamName = 'PowerThreshold_Stagger';
            CM.DrawProfileText(MyBP.PowerThreshold_Stagger @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
            CM.DrawProfileHeaderText("PowerThreshold_Knockback: ");
            ParamName = 'PowerThreshold_Knockback';
            CM.DrawProfileText(MyBP.PowerThreshold_Knockback @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
            CM.DrawProfileHeaderText("HitReactionChanceMultiplier: ");
            ParamName = 'HitReactionChanceMultiplier';
            CM.DrawProfileText(MyBP.HitReactionChanceMultiplier @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        }
    }
}
public function float GetActionDelayTime()
{
    return 1.0;
}
public function float GetCoverDelayTime()
{
    return 1.0;
}
public function InitializeCoverConstraints(Goal_AtCover Evaluator, Actor GoalActor)
{
    Super.InitializeCoverConstraints(Evaluator, GoalActor);
    if (MyBP.GetCurrentShields() <= 0.0)
    {
        Class'SFXPath_AwayFromGoal'.static.AwayFromGoal(MyBP, GoalActor, CloneRetreatDistance);
    }
}
public function bool ReactToNearbyEnemy(Pawn NearbyPawn)
{
    if (bPlayerLockedOn)
    {
        return FALSE;
    }
    if (MyBP != None && (MyBP.GetCurrentShields() > float(0) || bSimFightActive == TRUE))
    {
        if (DirectWalkCheck(NearbyPawn.location, NearbyPawn) == FALSE)
        {
            if (MyBP.IsInCover())
            {
                if (Vector(MyBP.Rotation) Dot Normal(NearbyPawn.location - MyBP.location) >= 0.5)
                {
                    return ReactToFlank(NearbyPawn);
                }
            }
        }
        else if (ShouldMelee(NearbyPawn))
        {
            if (CloneClass == CloneClassType.CloneClass_Vanguard)
            {
                MyBP.StartCustomAction(206);
            }
            else
            {
                BeginCombatCommand(Class'SFXAICmd_Base_Melee');
                return TRUE;
            }
        }
        return FALSE;
    }
    return FALSE;
}
public function bool ShouldMelee(Actor MeleeTarget)
{
    if (bEndBehaviorActive == TRUE && m_bAllowedToLeavePlaypen == TRUE && MyBP.Squad != None && MyBP.Squad.HasPlaypen() == TRUE && MyBP.Squad.IsPositionInPlaypen(MyBP.location) == FALSE)
    {
        return FALSE;
    }
    return Super(SFXAI_Core).ShouldMelee(MeleeTarget);
}
public function OnShouldThrowGrenade(SequenceAction Seq)
{
    if (Seq != None)
    {
        if (Seq.InputLinks[0].bHasImpulse)
        {
            bThrowGrenade = TRUE;
        }
        else if (Seq.InputLinks[1].bHasImpulse)
        {
            bThrowGrenade = FALSE;
        }
    }
}
public final function bool ShouldUseGrenade()
{
    local SFXPowerCustomAction Power;
    local int FireTargetIndex;
    
    FireTargetIndex = GetEnemyIndex(Pawn(FireTarget));
    if (bThrowGrenade)
    {
        if (TimeSinceEnemyLocationUpdate(FireTargetIndex) < 2.0 || TimeSinceHurtByEnemy(FireTargetIndex) < 4.0)
        {
            if (WorldInfo.GameTimeSeconds - LastGrenadeTime > GrenadeInterval)
            {
                Power = SFXPowerCustomAction(MyBP.PowerManager.GetPower(GetGrenadeName()));
                if (Power != None && Power.CanUsePower(FireTarget))
                {
                    return TRUE;
                }
            }
        }
    }
    return FALSE;
}

public function CloneCloak(optional bool bForce = FALSE)
{
    // TODO: Must be moved to pawn to work off-host
    local SFXModule_GameEffectManager GEManager;
    local SFXSelectionModule SelectionModule;
    
    if (bCloaked)
    {
        return;
    }
    if (bForce == TRUE || WorldInfo.GameTimeSeconds - LastCloakTime > MinTimeBetweenCloaks)
    {
        LastCloakTime = MyBP.WorldInfo.GameTimeSeconds;
        bCloaked = TRUE;
        GEManager = MyBP.GetModule(Class'SFXModule_GameEffectManager');
        if (GEManager != None)
        {
            GEManager.RemoveEffectsByTypeAndCategory(Class'SFXGameEffect_Cloak', Name);
            GEManager.CreateAndApplyEffect(Class'SFXGameEffect_Cloak', Name, 0.0, 2, 0.0);
        }
        SelectionModule = MyBP.GetModule(Class'SFXSelectionModule');
        if (SelectionModule != None)
        {
            SelectionModule.SetCombatTargetable(FALSE);
        }
    }
}
public function CloneDeCloak()
{
    // TODO: Must be moved to pawn to work off-host
    local SFXModule_GameEffectManager GEManager;
    local SFXSelectionModule SelectionModule;
    
    if (bCloaked)
    {
        bCloaked = FALSE;
        GEManager = MyBP.GetModule(Class'SFXModule_GameEffectManager');
        if (GEManager != None)
        {
            GEManager.RemoveEffectsByTypeAndCategory(Class'SFXGameEffect_Cloak', Name);
        }
        SelectionModule = MyBP.GetModule(Class'SFXSelectionModule');
        if (SelectionModule != None)
        {
            SelectionModule.SetCombatTargetable(TRUE);
        }
    }
}

public final function Name GetGrenadeName()
{
    if (CloneClass == CloneClassType.CloneClass_Sentinel)
    {
        return 'DenialGrenade';
    }
    else if (CloneClass == CloneClassType.CloneClass_Vanguard)
    {
        return 'DenialGrenade_Biotic';
    }
    else if (CloneClass == CloneClassType.CloneClass_Infiltrator)
    {
        return 'DenialGrenade';
    }
    else if (CloneClass == CloneClassType.CloneClass_Engineer)
    {
        return 'DenialGrenade';
    }
    else if (CloneClass == CloneClassType.CloneClass_Adept)
    {
        return 'DenialGrenade_Biotic';
    }
    else
    {
        return 'DenialGrenade';
    }
}
public final function Name GetPowerName()
{
    if (CloneClass == CloneClassType.CloneClass_Sentinel)
    {
        if (FRand() >= 0.5)
        {
            return 'CloneWarp';
        }
        else
        {
            return 'CloneIncinerate';
        }
    }
    else if (CloneClass == CloneClassType.CloneClass_Vanguard)
    {
        return 'CloneWarp';
    }
    else if (CloneClass == CloneClassType.CloneClass_Infiltrator)
    {
        return 'CloneIncinerate';
    }
    else if (CloneClass == CloneClassType.CloneClass_Engineer)
    {
        return 'CloneIncinerate';
    }
    else if (CloneClass == CloneClassType.CloneClass_Adept)
    {
        return 'CloneWarp';
    }
    else
    {
        return 'CloneCarnage';
    }
}

public function InitializeClassSpecific()
{
    local SFXPawn_Executioner ClonePawn;
    local SFXSelectionModule SelectionModule;
    
    SetPowerUsage();
    ClonePawn = SFXPawn_Executioner(MyBP);
    if (ClonePawn != None)
    {
        if (ClonePawn.Weapon != None)
        {
            ClonePawn.Weapon.Destroy();
        }
        SelectionModule = ClonePawn.GetModule(Class'SFXSelectionModule');
        if (CloneClass == CloneClassType.CloneClass_Infiltrator)
        {
            ClonePawn.Loadout = ClonePawn.Loadout_Sniper;
            ClonePawn.CreateWeapons(ClonePawn.Loadout_Sniper, TRUE);
            if (bSimFightActive == TRUE && SelectionModule != None && GameName_Infiltrator != 0)
            {
                SelectionModule.m_srGameName = GameName_Infiltrator;
            }
        }
        else if (CloneClass == CloneClassType.CloneClass_Vanguard)
        {
            ClonePawn.Loadout = ClonePawn.Loadout_Shotgun;
            ClonePawn.CreateWeapons(ClonePawn.Loadout_Shotgun, TRUE);
            EnemyDistance_Melee = EnemyDistance_VanguardMelee;
            if (bSimFightActive == TRUE && SelectionModule != None && GameName_Vanguard != 0)
            {
                SelectionModule.m_srGameName = GameName_Vanguard;
            }
        }
        else if (CloneClass == CloneClassType.CloneClass_Sentinel)
        {
            ClonePawn.Loadout = ClonePawn.Loadout_Shotgun;
            ClonePawn.CreateWeapons(ClonePawn.Loadout_Shotgun, TRUE);
            if (bSimFightActive == TRUE && SelectionModule != None && GameName_Sentinel != 0)
            {
                SelectionModule.m_srGameName = GameName_Sentinel;
            }
        }
        else if (CloneClass == CloneClassType.CloneClass_Adept)
        {
            ClonePawn.Loadout = ClonePawn.Loadout_Pistol;
            ClonePawn.CreateWeapons(ClonePawn.Loadout_Pistol, TRUE);
            if (bSimFightActive == TRUE && SelectionModule != None && GameName_Adept != 0)
            {
                SelectionModule.m_srGameName = GameName_Adept;
            }
        }
        else if (CloneClass == CloneClassType.CloneClass_Engineer)
        {
            ClonePawn.Loadout = ClonePawn.Loadout_Pistol;
            ClonePawn.CreateWeapons(ClonePawn.Loadout_Pistol, TRUE);
            if (bSimFightActive == TRUE && SelectionModule != None && GameName_Engineer != 0)
            {
                SelectionModule.m_srGameName = GameName_Engineer;
            }
        }
        else
        {
            ClonePawn.Loadout = ClonePawn.Loadout_Assault;
            ClonePawn.CreateWeapons(ClonePawn.Loadout_Assault, TRUE);
            if (bSimFightActive == TRUE && SelectionModule != None && GameName_Soldier != 0)
            {
                SelectionModule.m_srGameName = GameName_Soldier;
            }
        }
    }
}

public function OnInitSimClone(SFXSeqAct_InitSimClone Seq)
{
    local SFXPowerCustomAction_CloneDenial SimDenialPower;
    
    if (Seq == None || Seq.SimClone == None)
    {
        return;
    }
    bSimFightActive = TRUE;
    CloneClass = Seq.CloneClass;
    InitializeClassSpecific();
    if (Seq.SimClone.PowerManager != None)
    {
        SimDenialPower = SFXPowerCustomAction_CloneDenial(Seq.SimClone.PowerManager.GetPowerByClass(Class'SFXPowerCustomAction_CloneDenial'));
        if (SimDenialPower == None)
        {
            SimDenialPower = SFXPowerCustomAction_CloneDenial(Seq.SimClone.PowerManager.GetPowerByClass(Class'SFXPowerCustomAction_CloneDenial_Biotic'));
        }
        if (SimDenialPower != None)
        {
            SimDenialPower.MaxActiveGrenades = 1;
        }
    }
    Seq.SimClone.bPreventPermanentDeath = FALSE;
    Seq.SimClone.bCanRagdoll = TRUE;
}
public function SetGrenadeTime()
{
    local SFXAI_Executioner ChkCloneAI;
    local SFXPawn_Executioner ChkExecutioner;
    
    if (MyBP == None || MyBP.WorldInfo == None)
    {
        return;
    }
    if (!bSimFightActive)
    {
        LastGrenadeTime = MyBP.WorldInfo.GameTimeSeconds;
    }
    else
    {
        foreach WorldInfo.AllPawns(Class'SFXPawn_Executioner', ChkExecutioner)
        {
            ChkCloneAI = SFXAI_Executioner(ChkExecutioner.Controller);
            if (ChkCloneAI != None)
            {
                ChkCloneAI.LastGrenadeTime = MyBP.WorldInfo.GameTimeSeconds;
            }
        }
    }
}
public function SetPowerUsage()
{
    if (CloneClass == CloneClassType.CloneClass_Sentinel)
    {
        PowerToFiringRatio = 1.5;
        PowerInterval = 1.5;
    }
    else if (CloneClass == CloneClassType.CloneClass_Vanguard)
    {
        PowerToFiringRatio = 0.5;
        PowerInterval = 4.0;
    }
    else if (CloneClass == CloneClassType.CloneClass_Infiltrator)
    {
        PowerToFiringRatio = 0.5;
        PowerInterval = 4.0;
    }
    else if (CloneClass == CloneClassType.CloneClass_Engineer)
    {
        PowerToFiringRatio = 1.0;
        PowerInterval = 1.5;
    }
    else if (CloneClass == CloneClassType.CloneClass_Adept)
    {
        PowerToFiringRatio = 1.0;
        PowerInterval = 1.5;
    }
    else
    {
        PowerToFiringRatio = 0.5;
        PowerInterval = 4.0;
    }
}
public final function bool ShouldCastDrone()
{
    local SFXPowerCustomAction_CloneDrone CloneDronePower;
    
    if (CloneClass != CloneClassType.CloneClass_Engineer)
    {
        return FALSE;
    }
    if (MyBP.PowerManager != None)
    {
        CloneDronePower = SFXPowerCustomAction_CloneDrone(MyBP.PowerManager.GetPowerByClass(Class'SFXPowerCustomAction_CloneDrone'));
        if (CloneDronePower != None)
        {
            if (CloneDronePower.IsDroneAlive() == TRUE)
            {
                return FALSE;
            }
            else if (LastDroneTime != float(0) && WorldInfo.GameTimeSeconds - LastDroneTime < MinTimeBetweenDrones)
            {
                return FALSE;
            }
        }
    }
    return TRUE;
}

public final function bool ShouldRushPlayer()
{
    if (SFXPawn_Player(FireTarget) == None || bEndBehaviorActive == TRUE || bHasRushPriority == FALSE)
    {
        return FALSE;
    }
    if (WorldInfo.GameTimeSeconds - LastSyncMeleeTime > SyncMeleeAttackInterval)
    {
        if (MyBP.GetCurrentShields() > float(0))
        {
            return TRUE;
        }
    }
    return FALSE;
}
public function StageTwoUpgrade()
{
    local SFXPawn_Player PlayerPawn;
    local PlayerController PC;
    local RvrClientEffectTarget CETarget;
    local SFXShield_Base CloneShield;
    local SFXModule_GameEffectManager GEManager;
    local SFXModule_GameEffectManager WeaponGEManager;
    local SFXWeapon CloneWeapon;
    local SFXGameEffect_WeaponVFXChange WeaponVFXEffect;
    
    bStageTwoActive = TRUE;
    GEManager = MyBP.GetModule(Class'SFXModule_GameEffectManager');
    if (GEManager == None)
    {
        return;
    }
    if (MyBP.WorldInfo != None)
    {
        PC = MyBP.WorldInfo.GetALocalPlayerController();
        if (PC != None)
        {
            PlayerPawn = SFXPawn_Player(PC.Pawn);
        }
    }
    CloneWeapon = SFXWeapon(MyBP.Weapon);
    if (CloneWeapon != None)
    {
        CloneWeapon.IdealTargetDistance = StageTwo_NewIdealRange;
    }
    if (CloneClass != CloneClassType.CloneClass_Soldier)
    {
        GEManager.CreateAndApplyEffect(Class'SFXGameEffect_WeaponDamageBonus', Name, 0.0, 2, StageTwo_WeaponDamageMultiplier);
    }
    CloneShield = MyBP.GetShields();
    if (CloneShield != None)
    {
        CloneShield.InitializeMaxShields(Shield_StartingMax * StageTwo_ShieldBonusMultiplier);
        if (CloneShield.MaxEnemyShieldRecharge > 0.0)
        {
            CloneShield.ShieldRegenDelay.X = Shield_StartRegenDelay * StageTwo_ShieldRechargeDelayMultiplier;
            CloneShield.ShieldRegenDelay.Y = Shield_StartRegenDelay * StageTwo_ShieldRechargeDelayMultiplier;
            CloneShield.ShieldRegenDelay.Value = Shield_StartRegenDelay * StageTwo_ShieldRechargeDelayMultiplier;
        }
    }
    CETarget.Instigator = MyBP;
    if (CloneClass == CloneClassType.CloneClass_Sentinel)
    {
        if (PlayerPawn.bIsFemale == FALSE)
        {
            Guid_DefensiveCrust = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_TechArmor_Male, CETarget);
        }
        else
        {
            Guid_DefensiveCrust = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_TechArmor_Female, CETarget);
        }
        GEManager.CreateAndApplyEffect(Class'SFXGameEffect_DamageTakenBonus', Name, 0.0, 2, StageTwo_SentinelDamageReduction, Self);
    }
    else if (CloneClass == CloneClassType.CloneClass_Vanguard)
    {
        Guid_DefensiveCrust = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_Barrier, CETarget);
    }
    else if (CloneClass == CloneClassType.CloneClass_Infiltrator)
    {
        SyncMeleeAttackInterval *= StageTwo_InfiltratorAgressiveFrequencyMultiplier;
    }
    else if (CloneClass == CloneClassType.CloneClass_Engineer)
    {
        Guid_DefensiveCrust = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_DefensiveMatrix, CETarget);
    }
    else if (CloneClass == CloneClassType.CloneClass_Adept)
    {
        Guid_DefensiveCrust = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_Barrier, CETarget);
        GEManager.CreateAndApplyEffect(Class'SFXGameEffect_PowerBonus_Damage', Name, 0.0, 2, StageTwo_AdeptPowerDamageBonus, Self);
    }
    else
    {
        Guid_DefensiveCrust = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_AdrenalineRush, CETarget);
        GEManager.CreateAndApplyEffect(Class'SFXGameEffect_WeaponDamageBonus', Name, 0.0, 2, StageTwo_SoldierWeaponDamageMultiplier);
        CloneWeapon.WeaponPowerFireSound = WWise_FireAmmoSound;
        CloneWeapon.SetAmmoPowerHologramTemplates(PS_FireHologramTemplate, PS_FireIconTemplate);
        WeaponGEManager = CloneWeapon.GetModule(Class'SFXModule_GameEffectManager');
        if (WeaponGEManager != None)
        {
            WeaponVFXEffect = SFXGameEffect_WeaponVFXChange(WeaponGEManager.CreateEffect(Class'SFXGameEffect_WeaponVFXChange', Name, 0.0, 2, 1.0, Self));
            if (WeaponVFXEffect != None)
            {
                WeaponVFXEffect.bModifyMuzzleFlash = TRUE;
                WeaponVFXEffect.oMuzzleVFX = PS_FireMuzzleVFX;
                WeaponVFXEffect.oMuzzleLoopVFX = PS_FireMuzzleLoopVFX;
                WeaponVFXEffect.OnApplied();
            }
        }
        GrenadeInterval *= StageTwo_SoldierGrenadeFrequencyMultiplier;
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=Goal_AtCover Name=AtCov_EvalAggressive
        Begin Template Class=CovGoal_CombatZones Name=CovGoal_CombatZones0
        End Template
        Begin Template Class=CovGoal_Enemies Name=CovGoal_Enemies0
        End Template
        Begin Template Class=CovGoal_MovementDistance Name=CovGoal_MovDistAggressive
        End Template
        Begin Template Class=CovGoal_TeammateProximity Name=CovGoal_TeamProx0
        End Template
        Begin Template Class=CovGoal_WeaponRange Name=CovGoal_WeaponRange0
        End Template
        CoverGoalConstraints = (CovGoal_WeaponRange0, CovGoal_Enemies0, CovGoal_TeamProx0, CovGoal_MovDistAggressive, CovGoal_CombatZones0)
    End Template
    Begin Template Class=Goal_AtCover Name=AtCov_EvalDefensive
        Begin Template Class=CovGoal_Enemies Name=CovGoal_Enemies0
        End Template
        Begin Template Class=CovGoal_MovementDistance Name=CovGoal_MovDistDefensive
        End Template
        Begin Template Class=CovGoal_TeammateProximity Name=CovGoal_TeamProx0
        End Template
        CoverGoalConstraints = (CovGoal_Enemies0, CovGoal_MovDistDefensive, CovGoal_TeamProx0)
    End Template
    Begin Template Class=Goal_AtCover Name=AtCov_EvalNearGoal
        Begin Template Class=CovGoal_Enemies Name=CovGoal_Enemies0
        End Template
        Begin Template Class=CovGoal_GoalProximity Name=CovGoal_NearMoveGoal
        End Template
        CoverGoalConstraints = (CovGoal_NearMoveGoal, CovGoal_Enemies0)
    End Template
    Begin Template Class=Goal_AtCover Name=AtCov_EvalWeaponRange
        Begin Template Class=CovGoal_CombatZones Name=CovGoal_CombatZones0
        End Template
        Begin Template Class=CovGoal_Enemies Name=CovGoal_Enemies0
        End Template
        Begin Template Class=CovGoal_MovementDistance Name=CovGoal_MovDistWeapon
        End Template
        Begin Template Class=CovGoal_TeammateProximity Name=CovGoal_TeamProx0
        End Template
        Begin Template Class=CovGoal_WeaponRange Name=CovGoal_WeaponRange0
        End Template
        CoverGoalConstraints = (CovGoal_WeaponRange0, CovGoal_Enemies0, CovGoal_TeamProx0, CovGoal_MovDistWeapon, CovGoal_CombatZones0)
    End Template
    CE_TechArmor_Male = RvrClientEffect'BioVFX_C_Powers.07_PowerArmor.Power_Armor_Material_VCFX'
    CE_TechArmor_Female = RvrClientEffect'BioVFX_C_Powers.07_PowerArmor.Power_Armor_HMF_VCFX'
    CE_Barrier = RvrClientEffect'BioVFX_Hch_Morinth.VCFX.Reave_Charge_2_VCFX'
    CE_AdrenalineRush = RvrClientEffect'BioVFX_C_Adrenaline.VCFX.AdrenalineRush_VCFX'
    CE_DefensiveMatrix = RvrClientEffect'BioVFX_C_Shield.VCFX.Geth_ShieldBoost_VCFX_TargetCrust'
    PS_FireHologramTemplate = ParticleSystem'BioVFX_Exp3_CitGlobal.Particles.Modal_Carnage_C'
    PS_FireIconTemplate = ParticleSystem'BioVFX_C_Modal.Particles.Modal_Holo_Icon_Incendiary'
    WWise_FireAmmoSound = WwiseEvent'Wwise_VFX_Tech.Play_ammo_inc_mzzl'
    PS_FireMuzzleVFX = ParticleSystem'BioVFX_C_Modal.Particles.Modal_Mzl1_Carnage'
    PS_FireMuzzleLoopVFX = ParticleSystem'BioVFX_C_Modal.Particles.Modal_Mzl_Carnage'
    PowerInterval = 5.0
    GrenadeConeAngle = 0.699999988
    PowerToFiringRatio = 0.5
    StageTwo_ShieldRechargeDelayMultiplier = 0.75
    StageTwo_ShieldBonusMultiplier = 1.5
    StageTwo_WeaponDamageMultiplier = 0.25
    StageTwo_NewIdealRange = 750.0
    StageTwo_SentinelDamageReduction = 0.5
    StageTwo_VanguardChargeFrequencyBonus = 0.5
    StageTwo_InfiltratorAgressiveFrequencyMultiplier = 0.5
    StageTwo_AdeptPowerDamageBonus = 0.5
    StageTwo_SoldierGrenadeFrequencyMultiplier = 0.5
    StageTwo_SoldierWeaponDamageMultiplier = 0.5
    MinTimeBetweenDrones = 10.0
    CloneRetreatDistance = 4000.0
    CloneSpeedBoostDuration = 10.0
    CLoneSpeedIncrease = 0.300000012
    InfiltratorSpeedIncrease = 0.400000006
    RushTimeout = 30.0
    Rush_CloneSyncRange = 300.0
    Rush_CloneHealthMinPercent = 0.5
    Rush_StopFiringRange = 800.0
    MinTimeBetweenCloaks = 3.0
    MinTeleportInterval = 5.0
    MinTeleportInterval_Rush = 1.5
    TeleportChance = 1.0
    MaxChargesPerRush = 2
    EnemyDistance_VanguardMelee = 250.0
    SyncMeleeAttackInterval_Vanguard = 30.0
    MaxRezDistance = 200.0
    PlayerCampingDistance = 500.0
    GameName_Soldier = $93952
    GameName_Adept = $93954
    GameName_Engineer = $93953
    GameName_Sentinel = $93957
    GameName_Vanguard = $93956
    GameName_Infiltrator = $93955
    bThrowGrenade = TRUE
    bHasRushPriority = TRUE
    AtCover_WeaponRange = AtCov_EvalWeaponRange
    AtCover_Defensive = AtCov_EvalDefensive
    AtCover_Aggressive = AtCov_EvalAggressive
    AtCover_NearMoveGoal = AtCov_EvalNearGoal
    DefaultCommand = Class'SFXAICmd_Base_Executioner'
    m_fNearbyEnemyDistance = 400.0
    SyncMeleeAttackInterval = 15.0
    m_bAllowedToLeavePlaypen = TRUE
    m_bAvoidDangerLinks = TRUE
    EnemyDistance_Melee = 150.0
}