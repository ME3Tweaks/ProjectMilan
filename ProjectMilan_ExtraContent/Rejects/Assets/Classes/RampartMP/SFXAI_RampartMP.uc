Class SFXAI_RampartMP extends SFXAI_Cover
    placeable
    config(AI);

var transient float LastAggressiveTime;
var float ChanceToHitReact;
var float ShieldDamageScalePct;
var float EvadeDamageScalePct;
var transient float LastShieldTime;
var float ShieldFrequency;
var float AggroDistanceThreshold;
var transient bool bShieldDestroyed;

public function Initialize()
{
    local SFXDifficultyHandler DH;
    local SFXModule_Damage DmgMod;
    
    DH = SFXGRI(WorldInfo.GRI).DifficultyHandler;
    if (DH != None)
    {
        MeleeAttackInterval = DH.GetFloat('MeleeAttackInterval', 'Rampart');
        CancelFirePct = DH.GetFloat('CancelFirePct', 'Rampart');
        MaxFireWaitTime = DH.GetFloat('MaxFireWaitTime', 'Rampart');
        EvadeDamagePct.X = DH.GetFloat('EvadeDamagePctLow', 'Rampart');
        EvadeDamagePct.Y = DH.GetFloat('EvadeDamagePctHigh', 'Rampart');
        EvadeFrequency = DH.GetFloat('EvadeFrequency', 'Rampart');
        EvadeResetDuration = DH.GetFloat('EvadeResetDuration', 'Rampart');
        PartialLeanPct = DH.GetFloat('PartialLeanPct', 'Rampart');
        PowerEvadeChance = DH.GetFloat('PowerEvadeChance', 'Rampart');
        FlankReactionTime = DH.GetFloat('FlankReactionTime', 'Rampart');
        ChanceToHitReact = DH.GetFloat('HitReactOnArmorDestroyChance', 'Rampart');
        ShieldFrequency = DH.GetFloat('ShieldFrequency', 'Rampart');
        EvadeDamageScalePct = DH.GetFloat('EvadeDamageScalePct', 'Rampart');
        ShieldDamageScalePct = DH.GetFloat('ShieldDamageScalePct', 'Rampart');
        DmgMod = MyBP.GetModule(Class'SFXModule_Damage');
        if (DmgMod != None)
        {
            DmgMod.NormalizedHealth = DH.GetFloatNormalized('MaxHealth', 'Rampart');
            DmgMod.LevelScaledHealth = DH.GetFloat('MaxHealth', 'Rampart');
            DmgMod.InitializeMaxHealth(DmgMod.LevelScaledHealth);
        }
        if (MyBP != None)
        {
            MyBP.PowerThreshold_Standard = DH.GetFloat('PowerThreshold_Standard', 'Rampart');
            MyBP.PowerThreshold_Stagger = DH.GetFloat('PowerThreshold_Stagger', 'Rampart');
            MyBP.PowerThreshold_Knockback = DH.GetFloat('PowerThreshold_Knockback', 'Rampart');
            MyBP.HitReactionChanceMultiplier = DH.GetFloat('HitReactionChanceMultiplier', 'Rampart');
            if (SFXPawn_RampartMP(MyBP) != None)
            {
                SFXPawn_RampartMP(MyBP).BurnTimeLeft = DH.GetFloat('BurnTimeLeft', 'Rampart');
            }
        }
    }
    Super(SFXAI_Core).Initialize();
}
public function bool CanSwitchMood(EAICombatMood NewMood)
{
    if (NewMood == EAICombatMood.AI_Berserk)
    {
        return FALSE;
    }
    return Super(SFXAI_Core).CanSwitchMood(NewMood);
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
        CategoryName = 'Rampart';
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
public function NotifyArmourDestroyed(Name ArmourPiece, Controller instigatedBy)
{
    Super(SFXAI_Core).NotifyArmourDestroyed(ArmourPiece, instigatedBy);
    if (ArmourPiece == 'Rampart Part 5' && SFXPawn_RampartMP(MyBP) != None)
    {
        bShieldDestroyed = TRUE;
        SFXPawn_RampartMP(MyBP).StopShieldGenerator();
    }
    if (SFXPawn_RampartMP(MyBP) != None && !SFXPawn_RampartMP(MyBP).bAggressive && FRand() < ChanceToHitReact)
    {
        MyBP.StartCustomAction(88);
    }
}
public function NotifyPendingPowerImpact(Name Label, float TimeBeforeImpact, SFXPowerCustomAction Power, SFXProjectile_PowerCustomAction Projectile)
{
    Super(SFXAI_Core).NotifyPendingPowerImpact(Label, TimeBeforeImpact, Power, Projectile);
    if (Label == 'BioticShield' && ShouldActivateShield())
    {
        MyBP.StartCustomAction(147);
        SetTimer(ShieldFrequency, FALSE, 'StartShieldGenerator', MyBP);
        LastShieldTime = WorldInfo.GameTimeSeconds;
    }
}
public function bool ShouldMelee(Actor MeleeTarget)
{
    if (SFXPawn_RampartMP(MyBP) != None && !SFXPawn_RampartMP(MyBP).bAggressive)
    {
        return FALSE;
    }
    return Super(SFXAI_Core).ShouldMelee(MeleeTarget);
}
public function bool CheckEvade(float Damage, Controller instigatedBy, Class<SFXDamageType> DamageType)
{
    if (instigatedBy != None && instigatedBy.Pawn != None && ClassIsChildOf(DamageType, Class'SFXDamageType_Weapon') && ClassIsChildOf(DamageType, Class'SFXDamageType_HeavyWeapon') == FALSE)
    {
        EvadeDamageTaken += Damage;
        SetTimer(EvadeResetDuration, FALSE, 'ResetEvadeDamage', );
        if (MyBP.IsInCover() == FALSE && ShouldEvade(instigatedBy, DamageType) && ShouldActivateShield())
        {
            MyBP.StartCustomAction(147);
            SetTimer(ShieldFrequency, FALSE, 'StartShieldGenerator', MyBP);
            LastShieldTime = WorldInfo.GameTimeSeconds;
            LastEvadeTime = WorldInfo.GameTimeSeconds;
            ClearTimer('ResetEvadeDamage');
            ResetEvadeDamage();
            return TRUE;
        }
    }
    return FALSE;
}
public final function bool IsRampartInRange(float Range)
{
    if (MyBP.IsValidTargetFor(Pawn(FireTarget).Controller) == FALSE)
    {
        AILog_Internal(GetFuncName() @ "target not valid", 'Rampart');
        return FALSE;
    }
    if (InRange(FireTarget.location, Range) == FALSE)
    {
        AILog_Internal(GetFuncName() @ "Distance - " @ VSize(FireTarget.location - Pawn.location), 'Rampart');
        return FALSE;
    }
    if (MyBP.FastTrace(FireTarget.location, Pawn.location, Pawn.GetCollisionExtent() * 0.25, FALSE) == FALSE)
    {
        AILog_Internal(GetFuncName() @ "no LOS to the target", 'Rampart');
        return FALSE;
    }
    return TRUE;
}
public function bool ShouldActivateShield()
{
    if (!bShieldDestroyed && MyBP.CurrentCustomAction == 0 && SFXPawn_RampartMP(MyBP) != None && !SFXPawn_RampartMP(MyBP).bAggressive && !MyBP.IsDead() && MyBP.CanDoCustomAction(147) && WorldInfo.GameTimeSeconds - LastShieldTime > ShieldFrequency)
    {
        return TRUE;
    }
    return FALSE;
}
public function bool ShouldEvade(Controller instigatedBy, Class<DamageType> DamageType)
{
    if (instigatedBy != None && instigatedBy.Pawn != None && MyBP.CurrentCustomAction == 0 && WorldInfo.GameTimeSeconds - LastEvadeTime >= EvadeFrequency && EvadeDamageTaken >= EvadeHealthThreshold)
    {
        return TRUE;
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
    AggroDistanceThreshold = 2500.0
    AtCover_WeaponRange = AtCov_EvalWeaponRange
    AtCover_Defensive = AtCov_EvalDefensive
    AtCover_Aggressive = AtCov_EvalAggressive
    AtCover_NearMoveGoal = AtCov_EvalNearGoal
    MaxFireWaitTime = 10.0
    DefaultCommand = Class'SFXAICmd_Base_RampartMP'
    AggressiveCommand = Class'SFXAICmd_RampartMP_Aggressive'
    AI_BurstsToFire = {X = 1.0, Y = 2.0}
    m_fNearbyEnemyDistance = 500.0
    MeleeMoveOffset = 115.0
    MaxNumAggressive = 1
    bNotifyFriendsOnDeath = TRUE
    bReceiveDeathNotifications = TRUE
    m_bAvoidDangerLinks = TRUE
    EnemyDistance_Short = 300.0
    EnemyDistance_Medium = 1000.0
    EnemyDistance_Long = 2500.0
    EnemyDistance_Melee = 250.0
}