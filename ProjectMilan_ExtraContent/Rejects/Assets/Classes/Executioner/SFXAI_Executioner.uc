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
var float MinTimeBetweenDrones;
var float LastDroneTime;
var float Shield_StartingMax;
var float Shield_StartRegenDelay;
var float ExecutionerRetreatDistance;
var float ExecutionerSpeedBoostDuration;
var float ExecutionerSpeedIncrease;
var float InfiltratorSpeedIncrease;
var float RushTimeout;
var float Rush_ExecutionRange;
var float Rush_ExecutionerHealthMinPercent;
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
var float PlayerCampingDistance;
var bool bThrowGrenade;
var bool bStageTwoActive;
var bool bPlayerLockedOn;
var bool bPlayerSynced;
var bool bCloaked;
var bool bRushChargingActive;
var bool bHasRushPriority;
var CloneClassType ExecutionerClass;
var float MinTimeBetweenExecutionAttempts;

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
public function OnTargetChanged()
{
    Super(SFXAI_Core).OnTargetChanged();
    ChangeClass();
}
public function ChangeClass()
{
    // Choose class based on who we are attacking
    if (FireTarget == None)
    {
        return;
    }
    if (FireTarget.IsA('SFXPawn_PlayerMP_Sentinel') == TRUE)
    {
        ExecutionerClass = CloneClassType.CloneClass_Sentinel;
    }
    else if (FireTarget.IsA('SFXPawn_PlayerMP_Vanguard') == TRUE)
    {
        ExecutionerClass = CloneClassType.CloneClass_Vanguard;
    }
    else if (FireTarget.IsA('SFXPawn_PlayerMP_Infiltrator') == TRUE)
    {
        ExecutionerClass = CloneClassType.CloneClass_Infiltrator;
    }
    else if (FireTarget.IsA('SFXPawn_PlayerMP_Engineer') == TRUE)
    {
        ExecutionerClass = CloneClassType.CloneClass_Engineer;
    }
    else if (FireTarget.IsA('SFXPawn_PlayerMP_Adept') == TRUE)
    {
        ExecutionerClass = CloneClassType.CloneClass_Adept;
    }
    else
    {
        ExecutionerClass = CloneClassType.CloneClass_Soldier;
    }
    SetPowerUsage();
}
public function Initialize()
{
    local SFXDifficultyHandler DH;
    local SFXModule_Damage DmgMod;
    local SFXShield_Base PawnShield;
    local SFXPowerCustomAction_CloneDenial DenialPower;
    local SFXPowerCustomAction_CloneProjectile ProjectilePower;
    local int idx;
    
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
        MinTimeBetweenExecutionAttempts = DH.GetFloat('ExecutionAttemptInterval', 'Executioner');
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
    local bool bSyncSuccessful;
    
    if (SFXPawn_Player(FireTarget) != None && WorldInfo.GameTimeSeconds - LastSyncMeleeTime > MinTimeBetweenExecutionAttempts)
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
        if (ExecutionerClass == CloneClassType.CloneClass_Sentinel)
        {
            MyBP.StartCustomAction(205);
        }
        else if (ExecutionerClass == CloneClassType.CloneClass_Vanguard)
        {
            MyBP.StartCustomAction(206);
        }
        else if (ExecutionerClass == CloneClassType.CloneClass_Infiltrator)
        {
            MyBP.StartCustomAction(207);
        }
        else if (ExecutionerClass == CloneClassType.CloneClass_Engineer)
        {
            MyBP.StartCustomAction(208);
        }
        else if (ExecutionerClass == CloneClassType.CloneClass_Adept)
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
        Class'SFXPath_AwayFromGoal'.static.AwayFromGoal(MyBP, GoalActor, ExecutionerRetreatDistance);
    }
}
public function bool ReactToNearbyEnemy(Pawn NearbyPawn)
{
    if (bPlayerLockedOn)
    {
        return FALSE;
    }
    if (MyBP != None)
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
            if (ExecutionerClass == CloneClassType.CloneClass_Vanguard)
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
public function ExecutionerCloak(optional bool bForce = FALSE)
{
    local SFXModule_GameEffectManager GEManager;
    local SFXSelectionModule SelectionModule;
    
    // TODO: Must be moved to pawn to work off-host
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
public function ExecutionerDeCloak()
{
    local SFXModule_GameEffectManager GEManager;
    local SFXSelectionModule SelectionModule;
    
    // TODO: Must be moved to pawn to work off-host
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
    if (ExecutionerClass == CloneClassType.CloneClass_Sentinel)
    {
        return 'DenialGrenade';
    }
    else if (ExecutionerClass == CloneClassType.CloneClass_Vanguard)
    {
        return 'DenialGrenade_Biotic';
    }
    else if (ExecutionerClass == CloneClassType.CloneClass_Infiltrator)
    {
        return 'DenialGrenade';
    }
    else if (ExecutionerClass == CloneClassType.CloneClass_Engineer)
    {
        return 'DenialGrenade';
    }
    else if (ExecutionerClass == CloneClassType.CloneClass_Adept)
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
    if (ExecutionerClass == CloneClassType.CloneClass_Sentinel)
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
    else if (ExecutionerClass == CloneClassType.CloneClass_Vanguard)
    {
        return 'CloneWarp';
    }
    else if (ExecutionerClass == CloneClassType.CloneClass_Infiltrator)
    {
        return 'CloneIncinerate';
    }
    else if (ExecutionerClass == CloneClassType.CloneClass_Engineer)
    {
        return 'CloneIncinerate';
    }
    else if (ExecutionerClass == CloneClassType.CloneClass_Adept)
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
    local SFXPawn_Executioner ExecutionerPawn;
    local SFXSelectionModule SelectionModule;
    
    SetPowerUsage();
    ExecutionerPawn = SFXPawn_Executioner(MyBP);
    if (FALSE && ExecutionerPawn != None)
    {
        if (ExecutionerPawn.Weapon != None)
        {
            ExecutionerPawn.Weapon.Destroy();
        }
        // Todo: Investigate how to handle this with clients
        if (FALSE)
        {
            ExecutionerPawn.Loadout = ExecutionerPawn.Loadout_Assault;
            ExecutionerPawn.CreateWeapons(ExecutionerPawn.Loadout_Assault, TRUE);
        }
    }
}
public function SetGrenadeTime()
{
    local SFXAI_Executioner ChkExecutionerAI;
    local SFXPawn_Executioner ChkExecutioner;
    
    if (MyBP == None || MyBP.WorldInfo == None)
    {
        return;
    }
    foreach WorldInfo.AllPawns(Class'SFXPawn_Executioner', ChkExecutioner)
    {
        ChkExecutionerAI = SFXAI_Executioner(ChkExecutioner.Controller);
        if (ChkExecutionerAI != None)
        {
            ChkExecutionerAI.LastGrenadeTime = MyBP.WorldInfo.GameTimeSeconds;
        }
    }
}
public function SetPowerUsage()
{
    if (ExecutionerClass == CloneClassType.CloneClass_Sentinel)
    {
        PowerToFiringRatio = 1.5;
        PowerInterval = 1.5;
    }
    else if (ExecutionerClass == CloneClassType.CloneClass_Vanguard)
    {
        PowerToFiringRatio = 0.5;
        PowerInterval = 4.0;
    }
    else if (ExecutionerClass == CloneClassType.CloneClass_Infiltrator)
    {
        PowerToFiringRatio = 0.5;
        PowerInterval = 4.0;
    }
    else if (ExecutionerClass == CloneClassType.CloneClass_Engineer)
    {
        PowerToFiringRatio = 1.0;
        PowerInterval = 1.5;
    }
    else if (ExecutionerClass == CloneClassType.CloneClass_Adept)
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
    local SFXPowerCustomAction_ExecutionerDrone ExecutionerDronePower;
    
    if (ExecutionerClass != CloneClassType.CloneClass_Engineer)
    {
        return FALSE;
    }
    if (MyBP.PowerManager != None)
    {
        ExecutionerDronePower = SFXPowerCustomAction_ExecutionerDrone(MyBP.PowerManager.GetPowerByClass(Class'SFXPowerCustomAction_ExecutionerDrone'));
        if (ExecutionerDronePower != None)
        {
            if (ExecutionerDronePower.IsDroneAlive() == TRUE)
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
    if (SFXPawn(FireTarget) == None || bHasRushPriority == FALSE)
    {
        return FALSE;
    }
    if (WorldInfo.GameTimeSeconds - LastSyncMeleeTime > SyncMeleeAttackInterval)
    {
        // Rush players if their shields are down. Risk it!
        if (SFXPawn(FireTarget) != None && SFXPawn(FireTarget).GetCurrentShields() == 0.0)
        {
            return TRUE;
        }
        // Probably not the best plan if their shields are up but mine aren't
        if (MyBP.GetCurrentShields() > float(0))
        {
            return TRUE;
        }
    }
    return FALSE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=Goal_AtCover Name=AtCov_EvalWeaponRange
        Begin Template Class=CovGoal_WeaponRange Name=CovGoal_WeaponRange0
        End Template
        Begin Template Class=CovGoal_Enemies Name=CovGoal_Enemies0
        End Template
        Begin Template Class=CovGoal_TeammateProximity Name=CovGoal_TeamProx0
        End Template
        Begin Template Class=CovGoal_MovementDistance Name=CovGoal_MovDistWeapon
        End Template
        Begin Template Class=CovGoal_CombatZones Name=CovGoal_CombatZones0
        End Template
        CoverGoalConstraints = (CovGoal_WeaponRange0, CovGoal_Enemies0, CovGoal_TeamProx0, CovGoal_MovDistWeapon, CovGoal_CombatZones0)
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
    Begin Template Class=Goal_AtCover Name=AtCov_EvalAggressive
        Begin Template Class=CovGoal_WeaponRange Name=CovGoal_WeaponRange0
        End Template
        Begin Template Class=CovGoal_Enemies Name=CovGoal_Enemies0
        End Template
        Begin Template Class=CovGoal_TeammateProximity Name=CovGoal_TeamProx0
        End Template
        Begin Template Class=CovGoal_MovementDistance Name=CovGoal_MovDistAggressive
        End Template
        Begin Template Class=CovGoal_CombatZones Name=CovGoal_CombatZones0
        End Template
        CoverGoalConstraints = (CovGoal_WeaponRange0, CovGoal_Enemies0, CovGoal_TeamProx0, CovGoal_MovDistAggressive, CovGoal_CombatZones0)
    End Template
    Begin Template Class=Goal_AtCover Name=AtCov_EvalNearGoal
        Begin Template Class=CovGoal_GoalProximity Name=CovGoal_NearMoveGoal
        End Template
        Begin Template Class=CovGoal_Enemies Name=CovGoal_Enemies0
        End Template
        CoverGoalConstraints = (CovGoal_NearMoveGoal, CovGoal_Enemies0)
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
    MinTimeBetweenDrones = 10.0
    ExecutionerRetreatDistance = 4000.0
    ExecutionerSpeedBoostDuration = 10.0
    ExecutionerSpeedIncrease = 0.300000012
    InfiltratorSpeedIncrease = 0.400000006
    RushTimeout = 30.0
    Rush_ExecutionRange = 300.0
    Rush_ExecutionerHealthMinPercent = 0.5
    Rush_StopFiringRange = 800.0
    MinTimeBetweenCloaks = 3.0
    MinTeleportInterval = 5.0
    MinTeleportInterval_Rush = 1.5
    TeleportChance = 1.0
    MaxChargesPerRush = 2
    EnemyDistance_VanguardMelee = 250.0
    SyncMeleeAttackInterval_Vanguard = 30.0
    PlayerCampingDistance = 500.0
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