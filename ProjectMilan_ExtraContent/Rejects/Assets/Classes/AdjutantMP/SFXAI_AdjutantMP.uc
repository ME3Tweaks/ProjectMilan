Class SFXAI_AdjutantMP extends SFXAI_Core
    placeable
    config(AI);

var Vector2D FireDelayTime;
var Name ChargeAbilityName;
var Name BlastAbilityName;
var float ShortRangeSpeedMultiplier;
var float GlobalChargeInterval;
var float ChargeInterval;
var transient float LastChargeTime;
var float ChargeSeekTime;
var float GlobalBlastInterval;
var float BlastDamage;
var const float PoisonRadius;
var float PoisonDPS;
var const float ShortChargeDistance;
var const float MediumChargeDistance;
var const float ForwardEvadeDistance;
var const float SidewaysEvadeDistance;

public function Initialize()
{
    local SFXDifficultyHandler DH;
    local SFXModule_Damage DmgMod;
    local SFXShield_Base PawnShield;
    
    DH = SFXGRI(WorldInfo.GRI).DifficultyHandler;
    if (DH != None)
    {
        MeleeAttackInterval = DH.GetFloat('MeleeAttackInterval', 'AdjutantMP');
        FireDelayTime.X = DH.GetFloat('FireDelayTimeLow', 'AdjutantMP');
        FireDelayTime.Y = DH.GetFloat('FireDelayTimeHigh', 'AdjutantMP');
        MoveFireDelayTime.X = DH.GetFloat('MoveFireDelayTimeLow', 'AdjutantMP');
        MoveFireDelayTime.Y = DH.GetFloat('MoveFireDelayTimeHigh', 'AdjutantMP');
        EvadeDamagePct.X = DH.GetFloat('EvadeDamagePctLow', 'AdjutantMP');
        EvadeDamagePct.Y = DH.GetFloat('EvadeDamagePctHigh', 'AdjutantMP');
        EvadeFrequency = DH.GetFloat('EvadeFrequency', 'AdjutantMP');
        EvadeResetDuration = DH.GetFloat('EvadeResetDuration', 'AdjutantMP');
        PowerEvadeChance = DH.GetFloat('PowerEvadeChance', 'AdjutantMP');
        GlobalChargeInterval = DH.GetFloat('GlobalChargeInterval', 'AdjutantMP');
        ChargeInterval = DH.GetFloat('ChargeInterval', 'AdjutantMP');
        GlobalBlastInterval = DH.GetFloat('GlobalBlastInterval', 'AdjutantMP');
        BlastDamage = DH.GetFloat('BlastDamage', 'AdjutantMP');
        PoisonDPS = DH.GetFloat('PoisonDPS', 'AdjutantMP');
        DmgMod = MyBP.GetModule(Class'SFXModule_Damage');
        if (DmgMod != None)
        {
            DmgMod.NormalizedHealth = DH.GetFloatNormalized('MaxHealth', 'AdjutantMP');
            DmgMod.LevelScaledHealth = DH.GetFloat('MaxHealth', 'AdjutantMP');
            DmgMod.InitializeMaxHealth(DmgMod.LevelScaledHealth);
        }
        PawnShield = SFXShield_Base(MyBP.InvManager.FindInventoryType(Class'SFXShield_Base', TRUE));
        if (PawnShield != None)
        {
            PawnShield.InitializeMaxShields(DH.GetFloat('MaxShields', 'AdjutantMP'));
            PawnShield.MaxEnemyShieldRecharge = DH.GetFloat('MaxEnemyShieldRecharge', 'AdjutantMP');
            if (PawnShield.MaxEnemyShieldRecharge > 0.0)
            {
                PawnShield.bRechargeable = TRUE;
                PawnShield.ShieldRegenPct = DH.GetFloat('AIShieldRegenPct', 'AdjutantMP');
                PawnShield.ShieldRegenDelay.X = DH.GetMinFloat('AIShieldRegenDelay', 'AdjutantMP');
                PawnShield.ShieldRegenDelay.Y = DH.GetMaxFloat('AIShieldRegenDelay', 'AdjutantMP');
                PawnShield.ShieldRegenDelay.Value = DH.GetFloat('AIShieldRegenDelay', 'AdjutantMP');
            }
        }
        if (MyBP != None)
        {
            MyBP.PowerThreshold_Standard = DH.GetFloat('PowerThreshold_Standard', 'AdjutantMP');
            MyBP.PowerThreshold_Stagger = DH.GetFloat('PowerThreshold_Stagger', 'AdjutantMP');
            MyBP.PowerThreshold_Knockback = DH.GetFloat('PowerThreshold_Knockback', 'AdjutantMP');
            MyBP.HitReactionChanceMultiplier = DH.GetFloat('HitReactionChanceMultiplier', 'AdjutantMP');
            MyBP.LargeReactionInterval = DH.GetFloat('LargeReactionInterval', 'AdjutantMP');
        }
    }
    LastFireTime = WorldInfo.GameTimeSeconds;
    Super.Initialize();
}
public function DoMeleeAttack()
{
    LastCombatActionTime = WorldInfo.GameTimeSeconds;
    MyBP.StartCustomAction(FRand() > 0.5 ? 133 : 134);
}
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
        CategoryName = 'AdjutantMP';
        DmgMod = MyBP.GetModule(Class'SFXModule_Damage');
        if (DmgMod != None)
        {
            CM.DrawProfileHeaderText("Health: ");
            ParamName = 'MaxHealth';
            CM.DrawProfileText(DmgMod.GetMaxHealth() @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
            CM.DrawProfileText(" ");
        }
        PawnShield = SFXShield_Base(MyBP.InvManager.FindInventoryType(Class'SFXShield_Base', TRUE));
        if (PawnShield != None)
        {
            CM.DrawProfileHeaderText("Shields: ");
            ParamName = 'MaxShields';
            CM.DrawProfileText(PawnShield.GetMaxShields() @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
            CM.DrawProfileHeaderText("Max Shield Recharge: ");
            ParamName = 'MaxEnemyShieldRecharge';
            CM.DrawProfileText(PawnShield.MaxEnemyShieldRecharge @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
            CM.DrawProfileHeaderText("Damage Reduction On Shield Break: ");
            ParamName = 'AIEnergyShieldGatePct';
            CM.DrawProfileText(PawnShield.AIEnergyShieldGatePct @ "(" @ DH.GetMinFloat('AIEnergyShieldGatePct', 'Global') @ ":" @ DH.GetMaxFloat('AIEnergyShieldGatePct', 'Global') @ ")");
            CM.DrawProfileHeaderText("What Percent of Shields Regen Per Second: ");
            ParamName = 'ShieldRegenPct';
            CM.DrawProfileText(PawnShield.ShieldRegenPct @ "(" @ DH.GetMinFloat('AIShieldRegenPct', 'AdjutantMP') @ ":" @ DH.GetMaxFloat('AIShieldRegenPct', 'AdjutantMP') @ ")");
            CM.DrawProfileHeaderText("How Long Before Shields Start To Regenerate: ");
            ParamName = 'ShieldRegenDelay';
            CM.DrawProfileText(PawnShield.ShieldRegenDelay.Value @ "(" @ DH.GetMinFloat('AIShieldRegenDelay', 'AdjutantMP') @ ":" @ DH.GetMaxFloat('AIShieldRegenDelay', 'AdjutantMP') @ ")");
            CM.DrawProfileText(" ");
        }
        CM.DrawProfileHeaderText("MeleeAttackInterval: ");
        ParamName = 'MeleeAttackInterval';
        CM.DrawProfileText(MeleeAttackInterval @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("FireDelayTimeLow: ");
        ParamName = 'FireDelayTimeLow';
        CM.DrawProfileText("(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("FireDelayTimeHigh: ");
        ParamName = 'FireDelayTimeHigh';
        CM.DrawProfileText("(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("MoveFireDelayTimeLow: ");
        ParamName = 'MoveFireDelayTimeLow';
        CM.DrawProfileText("(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("MoveFireDelayTimeHigh: ");
        ParamName = 'MoveFireDelayTimeHigh';
        CM.DrawProfileText("(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
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
    Super.NotifyArmourDestroyed(ArmourPiece, instigatedBy);
    MyBP.StartCustomAction(110);
}
public function bool ReactToNearbyEnemy(Pawn NearbyPawn)
{
    if (NearbyPawn == Enemy && ShouldMelee(NearbyPawn))
    {
        BeginCombatCommand(Class'SFXAICmd_Base_Melee');
        return TRUE;
    }
    return FALSE;
}
public function SetMovementSpeed()
{
    if (FireTarget != None && !InRange(FireTarget.location, EnemyDistance_Medium))
    {
        MyBP.SetDesiredSpeed(1.0);
    }
    else
    {
        MyBP.SetDesiredSpeed(ShortRangeSpeedMultiplier);
    }
}
public final function bool CanAttackTarget(float Range)
{
    if (MyBP.IsValidTargetFor(Pawn(FireTarget).Controller) == FALSE)
    {
        AILog_Internal(GetFuncName() @ "target not valid", 'AdjutantMP');
        return FALSE;
    }
    if (InRange(FireTarget.location, Range) == FALSE)
    {
        AILog_Internal(GetFuncName() @ "Distance - " @ VSize(FireTarget.location - Pawn.location), 'AdjutantMP');
        return FALSE;
    }
    return TRUE;
}
private final function EAICustomAction ChooseEvade(const out array<EAICustomAction> EvadeActions, const out Vector X, const out Vector Y)
{
    local int NumActions;
    local Actor EvadeToward;
    local EAICustomAction Action;
    local EAICustomAction BestAction;
    local float ActionScore;
    local float BestActionScore;
    local Vector DirToMove;
    local float DotX;
    local float DotY;
    
    NumActions = EvadeActions.Length;
    if (NumActions == 0)
    {
        return 0;
    }
    if (RouteCache.Length > 0 && RouteCache[0] != None)
    {
        EvadeToward = RouteCache[0];
    }
    else
    {
        EvadeToward = MoveTarget;
    }
    if (EvadeToward != None)
    {
        DirToMove = Normal(EvadeToward.location - Pawn.location);
        DotX = X Dot DirToMove;
        DotY = Y Dot DirToMove;
        BestAction = EAICustomAction.CA_None;
        foreach EvadeActions(Action, )
        {
            switch (Action)
            {
                case EAICustomAction.CA_RollForward:
                    ActionScore = DotX;
                    break;
                case EAICustomAction.CA_RollBackward:
                    ActionScore = -DotX;
                    break;
                case EAICustomAction.CA_RollRight:
                    ActionScore = DotY;
                    break;
                case EAICustomAction.CA_RollLeft:
                    ActionScore = -DotY;
                    break;
                default:
            }
            if (ActionScore > BestActionScore)
            {
                BestActionScore = ActionScore;
                BestAction = Action;
            }
        }
        if (BestAction != EAICustomAction.CA_None)
        {
            return BestAction;
        }
    }
    return EvadeActions[Rand(NumActions)];
}
public final function EAICustomAction GetBestEvadeDir2(Vector DangerPoint, optional Projectile Prj, optional Pawn Shooter)
{
    local Vector X;
    local Vector Y;
    local Vector Z;
    local Vector VectToDanger;
    local Vector VectToProj;
    local bool bLeftOpen;
    local bool bRightOpen;
    local bool bFrontOpen;
    local bool bBackOpen;
    local array<EAICustomAction> Actions;
    local float DotX;
    local float DotY;
    local float DistLeftSq;
    local float DistRightSq;
    local float CheckHeight;
    local Vector ProjectedLoc;
    local Vector Offset;
    local Actor EvadeToward;
    
    GetAxes(Pawn.Rotation, X, Y, Z);
    CheckHeight = Pawn.GetCollisionHeight() * 0.5 + Pawn.MaxStepHeight;
    Offset = Y * SidewaysEvadeDistance;
    bRightOpen = MyBP.CanDoCustomAction(55) && FastTrace(Pawn.location + Offset, Pawn.location, , ) && !FastTrace(Pawn.location + Offset + vect(0.0, 0.0, -1.0) * CheckHeight, Pawn.location + Offset, Pawn.GetCollisionExtent() * 0.5, );
    bLeftOpen = MyBP.CanDoCustomAction(54) && FastTrace(Pawn.location - Offset, Pawn.location, , ) && !FastTrace(Pawn.location - Offset + vect(0.0, 0.0, -1.0) * CheckHeight, Pawn.location - Offset, Pawn.GetCollisionExtent() * 0.5, );
    if (Prj != None)
    {
        Offset = X * ForwardEvadeDistance;
        bFrontOpen = MyBP.CanDoCustomAction(56) && !MyBP.IsInCover() && FastTrace(Pawn.location + Offset, Pawn.location, , ) && !FastTrace(Pawn.location + Offset + vect(0.0, 0.0, -1.0) * CheckHeight, Pawn.location + Offset, Pawn.GetCollisionExtent() * 0.5, );
        bBackOpen = MyBP.CanDoCustomAction(57) && FastTrace(Pawn.location - Offset, Pawn.location, , ) && !FastTrace(Pawn.location - Offset + vect(0.0, 0.0, -1.0) * CheckHeight, Pawn.location - Offset, Pawn.GetCollisionExtent() * 0.5, );
        VectToProj = Normal(Prj.location - Pawn.location);
        if (Prj.Velocity.Z > Prj.Velocity.X && Prj.Velocity.Z > Prj.Velocity.Y)
        {
            if (bFrontOpen)
            {
                Actions.AddItem(56);
            }
            if (bRightOpen)
            {
                Actions.AddItem(55);
            }
            if (bLeftOpen)
            {
                Actions.AddItem(54);
            }
            if (bBackOpen)
            {
                Actions.AddItem(57);
            }
            if (Actions.Length > 0)
            {
                return ChooseEvade(Actions, X, Y);
            }
            return 0;
        }
        if (bFrontOpen && VectToProj Dot X < 0.707000017)
        {
            Actions.AddItem(56);
        }
        if (bBackOpen && VectToProj Dot X > -0.707000017)
        {
            Actions.AddItem(57);
        }
        if (bRightOpen && VectToProj Dot Y < 0.707000017)
        {
            Actions.AddItem(55);
        }
        if (bLeftOpen && VectToProj Dot Y > -0.707000017)
        {
            Actions.AddItem(54);
        }
        if (Actions.Length > 0)
        {
            return ChooseEvade(Actions, X, Y);
        }
        return 0;
    }
    else if (Shooter != None)
    {
        if (bRightOpen && !bLeftOpen)
        {
            return 55;
        }
        else if (!bRightOpen && bLeftOpen)
        {
            return 54;
        }
        else if (bRightOpen && bLeftOpen)
        {
            EvadeToward = MoveGoal;
            if (RouteCache.Length > 0 && RouteCache[0] != None)
            {
                EvadeToward = RouteCache[0];
            }
            if (EvadeToward != None)
            {
                ProjectedLoc = Pawn.location + Offset;
                DistRightSq = VSizeSq2D(ProjectedLoc - EvadeToward.location);
                ProjectedLoc = Pawn.location - Offset;
                DistLeftSq = VSizeSq2D(ProjectedLoc - EvadeToward.location);
                if (DistRightSq < DistLeftSq)
                {
                    return 55;
                }
                else
                {
                    return 54;
                }
            }
            else if (Vector(Shooter.Rotation) Dot Y > 0.0)
            {
                return 54;
            }
            else
            {
                return 54;
            }
        }
    }
    else
    {
        Offset = X * ForwardEvadeDistance;
        bFrontOpen = MyBP.CanDoCustomAction(56) && !MyBP.IsInCover() && FastTrace(Pawn.location + Offset, Pawn.location, , ) && !FastTrace(Pawn.location + Offset + vect(0.0, 0.0, -1.0) * CheckHeight, Pawn.location + Offset, Pawn.GetCollisionExtent() * 0.5, );
        bBackOpen = MyBP.CanDoCustomAction(57) && FastTrace(Pawn.location - Offset, Pawn.location, , ) && !FastTrace(Pawn.location - Offset + vect(0.0, 0.0, -1.0) * CheckHeight, Pawn.location - Offset, Pawn.GetCollisionExtent() * 0.5, );
        VectToDanger = Normal(DangerPoint - Pawn.location);
        DotX = X Dot VectToDanger;
        DotY = Y Dot VectToDanger;
        if (DotX >= 0.707099974 || DotX <= -0.707099974)
        {
            if (bBackOpen && DotX >= 0.707099974)
            {
                return 57;
            }
            else if (bFrontOpen && DotX <= -0.707099974)
            {
                return 56;
            }
            else if (bRightOpen && (DotY < 0.0 || DotY >= 0.0 && !bLeftOpen))
            {
                return 55;
            }
            else if (bLeftOpen && (DotY >= 0.0 || DotY < 0.0 && !bRightOpen))
            {
                return 54;
            }
        }
        else if (bLeftOpen && DotY >= 0.707099974)
        {
            return 54;
        }
        else if (bRightOpen && DotY <= -0.707099974)
        {
            return 55;
        }
        else if (bFrontOpen && (DotX < 0.0 || DotX >= 0.0 && !bBackOpen))
        {
            return 56;
        }
        else if (bBackOpen && (DotX >= 0.0 || DotX < 0.0 && !bFrontOpen))
        {
            return 57;
        }
    }
    return 0;
}
public function float GetFireDelayTime()
{
    return RandRange(FireDelayTime.X, FireDelayTime.Y);
}
public function OnChargeComplete()
{
    LastMeleeTime = WorldInfo.GameTimeSeconds;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    ChargeAbilityName = 'Adjutant_Charge'
    BlastAbilityName = 'Adjutant_Blast'
    ShortRangeSpeedMultiplier = 0.899999976
    PoisonRadius = 250.0
    ShortChargeDistance = 560.0
    MediumChargeDistance = 760.0
    ForwardEvadeDistance = 450.0
    SidewaysEvadeDistance = 450.0
    DefaultCommand = Class'SFXAICmd_Base_AdjutantMP'
    m_fNearbyEnemyDistance = 400.0
    MeleeMoveOffset = 100.0
    EnemyDistance_Short = 960.0
    EnemyDistance_Medium = 1600.0
    EnemyDistance_Long = 4500.0
    EnemyDistance_Melee = 275.0
}