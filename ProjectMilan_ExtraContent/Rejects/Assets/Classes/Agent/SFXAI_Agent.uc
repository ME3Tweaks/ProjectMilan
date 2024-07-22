Class SFXAI_Agent extends SFXAI_Cover
    placeable
    config(AI);

enum EAgentState
{
    Agent_Normal,
    Agent_Fleeing,
    Agent_Aggressive,
};

var Name KaiLengSlashPowerName;
var WwiseEvent KaiLengInjuredVoc;
var transient float LastGuardTime;
var float KnockbackFrequency;
var float RollFrequency;
var transient float DamageTaken;
var float DamageThreshold;
var transient float LastAggressiveTime;
var float AggressiveFrequency;
var float MeleeCone;
var float PowerSlashInterval;
var transient float LastPowerSlashTime;
var transient float LastShieldTime;
var float ShieldFrequency;
var bool bKaiLengCharged;
var bool bIsAttemptingSyncAttack;
var bool bBreakChargeUp;
var bool bHasUsedRecharge;
var bool bIsInRechargeState;
var EAgentState AgentState;

public function DrawDifficulty(BioCheatManager CM)
{
    local SFXDifficultyHandler DH;
    local Name ParamName;
    local Name CategoryName;
    local SFXModule_Damage DmgMod;
    local SFXShield_Base PawnShield;
    
    DH = SFXGRI(WorldInfo.GRI).DifficultyHandler;
    if (DH != None)
    {
        CategoryName = 'Agent';
        CM.DrawProfileHeaderText("Current Mood: ");
        CM.DrawProfileText(string(AgentState));
        CM.DrawProfileHeaderText("Has Used Recharge: ");
        CM.DrawProfileText(string(bHasUsedRecharge));
        CM.DrawProfileHeaderText("Attempting Sync Grapple: ");
        CM.DrawProfileText(string(bIsAttemptingSyncAttack));
    }
}

public function Initialize()
{
    local SFXDifficultyHandler DH;
    local SFXModule_Damage DmgMod;
    local SFXShield_Base PawnShield;
    
    DH = SFXGRI(WorldInfo.GRI).DifficultyHandler;
    if (DH != None)
    {
        MeleeAttackInterval = DH.GetFloat('MeleeAttackInterval', 'Agent');
        AggressiveFrequency = DH.GetFloat('AggressiveFrequency', 'Agent');
        SyncMeleeAttackInterval = DH.GetFloat('SyncMeleeAttackInterval', 'Agent');
        KnockbackFrequency = DH.GetFloat('KnockbackFrequency', 'Agent');
        RollFrequency = DH.GetFloat('RollFrequency', 'Agent');
        DamageThreshold = DH.GetFloat('DamageThreshold', 'Agent');
        PowerSlashInterval = DH.GetFloat('PowerSlashInterval', 'Agent');
        DmgMod = MyBP.GetModule(Class'SFXModule_Damage');
        if (DmgMod != None)
        {
            DmgMod.NormalizedHealth = DH.GetFloatNormalized('MaxHealth', 'Agent');
            DmgMod.LevelScaledHealth = DH.GetFloat('MaxHealth', 'Agent');
            DmgMod.InitializeMaxHealth(DmgMod.LevelScaledHealth);
        }
        PawnShield = SFXShield_Base(MyBP.InvManager.FindInventoryType(Class'SFXShield_Base', TRUE));
        if (PawnShield != None)
        {
            PawnShield.InitializeMaxShields(DH.GetFloat('MaxShields', 'Agent'));
            PawnShield.MaxEnemyShieldRecharge = DH.GetFloat('MaxEnemyShieldRecharge', 'Agent');
            if (PawnShield.MaxEnemyShieldRecharge > 0.0)
            {
                PawnShield.bRechargeable = TRUE;
            }
        }
    }
    Super(SFXAI_Core).Initialize();
}
public function NotifyTakeHit(Controller instigatedBy, Vector HitLocation, int Damage, Class<DamageType> DamageType, Vector Momentum)
{
    local BioPlayerController BPController;
    
    Super.NotifyTakeHit(instigatedBy, HitLocation, Damage, DamageType, Momentum);
    BPController = BioPlayerController(instigatedBy);
    if (!bHasUsedRecharge && MyBP.GetHealthPct() < 0.6)
    {
        bHasUsedRecharge = TRUE;
        AILog_Internal("Agent is activating recharging ability", 'Combat');
        MyBP.PlaySound(KaiLengInjuredVoc, TRUE);
        BeginCombatCommand(Class'SFXAICmd_Reaction_AgentHeal');
    }
    else if (BPController != None)
    {
        DamageTaken += float(Damage);
        if (MyBP.CurrentCustomAction == 0)
        {
            if (DamageTaken >= DamageThreshold)
            {
                if (WorldInfo.GameTimeSeconds - LastGuardTime >= KnockbackFrequency && InRange(FireTarget.location, EnemyDistance_Short))
                {
                    MyBP.StartCustomAction(92);
                    LastGuardTime = WorldInfo.GameTimeSeconds;
                    DamageTaken = 0.0;
                }
                else if (WorldInfo.GameTimeSeconds - LastGuardTime >= RollFrequency)
                {
                    MyBP.StartCustomAction(56);
                    LastGuardTime = WorldInfo.GameTimeSeconds;
                    DamageTaken = 0.0;
                }
            }
        }
    }
}
public function bool IsCombatStale()
{
    return FALSE;
}
public function NotifyPendingPowerImpact(Name Label, float TimeBeforeImpact, SFXPowerCustomAction Power, SFXProjectile_PowerCustomAction Projectile)
{
    local EAICustomAction EvadeAction;
    
    Super(SFXAI_Core).NotifyPendingPowerImpact(Label, TimeBeforeImpact, Power, Projectile);
    if (Label == 'CombatRoll' && ShouldActivateShield())
    {
        EvadeAction = GetBestEvadeDir(Projectile.location, Projectile);
        if (EvadeAction != EAICustomAction.CA_None)
        {
            MyBP.StartCustomAction(int(EvadeAction));
            LastShieldTime = WorldInfo.GameTimeSeconds;
            if (Projectile != None)
            {
                Projectile.PawnEvadedPower(MyBP, Label, TimeBeforeImpact);
            }
        }
    }
}
public function bool ReactToNearbyEnemy(Pawn NearbyPawn)
{
    return FALSE;
}
public function bool SelectTarget()
{
    local Actor OldTarget;
    local int idx;
    local Pawn EnemyPawn;
    local bool bResult;
    local Pawn ClosestPawn;
    local float closestDistance;
    local float Distance;
    
    OldTarget = FireTarget;
    if (bIsAttemptingSyncAttack)
    {
        Distance = 10000000.0;
        for (idx = 0; idx < EnemyList.Length; idx++)
        {
            EnemyPawn = EnemyList[idx].Pawn;
            if (EnemyPawn == None || EnemyPawn.IsValidTargetFor(Self) == FALSE)
            {
                AILog_Internal("Warning: Invalid pawn contained in the enemy list", 'Enemy');
                continue;
            }
            Distance = VSize(EnemyPawn.location - MyBP.location);
            if (ClosestPawn == None)
            {
                closestDistance = Distance;
                ClosestPawn = EnemyPawn;
                continue;
            }
            if (Distance < closestDistance)
            {
                ClosestPawn = EnemyPawn;
            }
        }
        if (ClosestPawn != None && ClosestPawn.IsHumanControlled())
        {
            Enemy = ClosestPawn;
        }
        bResult = HasValidEnemy();
        if (bResult)
        {
            FireTarget = Enemy;
            ValidateFireTargetLocation();
            if (OldTarget != FireTarget)
            {
                TargetAcquisitionTime = WorldInfo.GameTimeSeconds;
                ReleaseTicket(OldTarget, 2, TRUE);
                ReleaseTicket(OldTarget, 1);
                AcquireTicket(FireTarget, 1);
                TriggerAttackVocalization();
                OnTargetChanged();
            }
            ShotTarget = Pawn(FireTarget);
            return TRUE;
        }
        else
        {
            return Super(SFXAI_Core).SelectTarget();
        }
    }
    else
    {
        return Super(SFXAI_Core).SelectTarget();
    }
    return FALSE;
}
public function SetMovementSpeed()
{
    local float Speed;
    
    if (MyBP != None)
    {
        switch (AgentState)
        {
            case EAgentState.Agent_Normal:
                Speed = 1.0;
                break;
            case EAgentState.Agent_Fleeing:
                Speed = 1.75;
                break;
            case EAgentState.Agent_Aggressive:
                Speed = 1.5;
                break;
            default:
        }
        MyBP.SetDesiredSpeed(Speed);
    }
}
public function bool ShouldMelee(Actor MeleeTarget)
{
    if (NoZDot(FireTarget.location - MyBP.location, Vector(MyBP.Rotation)) > MeleeCone)
    {
        return Super(SFXAI_Core).ShouldMelee(MeleeTarget);
    }
    return FALSE;
}
public function bool ShouldActivateShield()
{
    if (WorldInfo.GameTimeSeconds - LastShieldTime > ShieldFrequency)
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
    KaiLengSlashPowerName = 'KaiLengSlash'
    KaiLengInjuredVoc = WwiseEvent'Wwise_VO_Exertions.Play_Exertion_KaiLeng_Pain'
    MeleeCone = 0.649999976
    ShieldFrequency = 5.0
    NearCoverDelayTime = {X = 7.5, Y = 12.5}
    FarCoverDelayTime = {X = 7.5, Y = 12.5}
    AtCover_WeaponRange = AtCov_EvalWeaponRange
    AtCover_Defensive = AtCov_EvalDefensive
    AtCover_Aggressive = AtCov_EvalAggressive
    AtCover_NearMoveGoal = AtCov_EvalNearGoal
    MaxFireWaitTime = 0.100000001
    FlankReactionTime = 0.150000006
    DefaultCommand = Class'SFXAICmd_Agent_Aggressive'
    EvadeDamagePct = {X = 0.100000001, Y = 0.100000001}
    AI_BurstsToFire = {X = 1.0, Y = 1.0}
    m_fNearbyEnemyDistance = 700.0
    EvadeFrequency = 0.899999976
    EvadeResetDuration = 8.0
    PowerEvadeChance = 0.6
    PartialLeanPct = 0.75
    MeleeMoveOffset = 100.0
    m_fPlayerTargetWeightBonus = 1.0
    EnemyDistance_Short = 500.0
    EnemyDistance_Medium = 1000.0
    EnemyDistance_Long = 2000.0
    EnemyDistance_Melee = 200.0
}