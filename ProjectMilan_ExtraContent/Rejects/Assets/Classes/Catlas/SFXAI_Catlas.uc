Class SFXAI_Catlas extends SFXAI_Core
    placeable
    config(AI);

var const Name RocketAttack;
var transient float LastSmokeTime;
var float SmokeInterval;
var transient float LastRocketTime;
var float RocketInterval;
var transient float LastBlockTime;
var float BlockInterval;
var transient float CockpitDamageTaken;
var transient float CockpitBlockThreshold;
var transient float CockpitDamageResetDuration;
var float SyncKillChance;
var float AtlasMeleeCone;
var float AtlasSyncMeleeCone;
var float AtlasSyncMeleeRange;
var float RocketConeAngle;

public function Initialize()
{
    local SFXDifficultyHandler DH;
    local SFXModule_Damage DmgMod;
    local SFXShield_Base PawnShield;
    
    DH = SFXGRI(WorldInfo.GRI).DifficultyHandler;
    if (DH != None)
    {
        MeleeAttackInterval = DH.GetFloat('MeleeAttackInterval', 'Catlas');
        SyncMeleeAttackInterval = DH.GetFloat('SyncMeleeAttackInterval', 'Catlas');
        SmokeInterval = DH.GetFloat('SmokeInterval', 'Catlas');
        RocketInterval = DH.GetFloat('RocketInterval', 'Catlas');
        BlockInterval = DH.GetFloat('BlockInterval', 'Catlas');
        CockpitDamageResetDuration = DH.GetFloat('CockpitDamageResetDuration', 'Catlas');
        CockpitBlockThreshold = DH.GetFloat('CockpitBlockThreshold', 'Catlas');
        SyncKillChance = DH.GetFloat('SyncKillChance', 'Catlas');
        DmgMod = MyBP.GetModule(Class'SFXModule_Damage');
        if (DmgMod != None)
        {
            DmgMod.NormalizedHealth = DH.GetFloatNormalized('MaxHealth', 'Catlas');
            DmgMod.LevelScaledHealth = DH.GetFloat('MaxHealth', 'Catlas');
            DmgMod.InitializeMaxHealth(DmgMod.LevelScaledHealth);
        }
        PawnShield = SFXShield_Base(MyBP.InvManager.FindInventoryType(Class'SFXShield_Base', TRUE));
        if (PawnShield != None)
        {
            PawnShield.InitializeMaxShields(DH.GetFloat('MaxShields', 'Catlas'));
            PawnShield.MaxEnemyShieldRecharge = DH.GetFloat('MaxEnemyShieldRecharge', 'Catlas');
            if (PawnShield.MaxEnemyShieldRecharge > 0.0)
            {
                PawnShield.bRechargeable = TRUE;
                PawnShield.ShieldRegenPct = DH.GetFloat('AIShieldRegenPct', 'Catlas');
                PawnShield.ShieldRegenDelay.X = DH.GetMinFloat('AIShieldRegenDelay', 'Catlas');
                PawnShield.ShieldRegenDelay.Y = DH.GetMaxFloat('AIShieldRegenDelay', 'Catlas');
                PawnShield.ShieldRegenDelay.Value = DH.GetFloat('AIShieldRegenDelay', 'Catlas');
            }
        }
        if (MyBP != None)
        {
            MyBP.PowerThreshold_Standard = DH.GetFloat('PowerThreshold_Standard', 'Catlas');
            MyBP.PowerThreshold_Stagger = DH.GetFloat('PowerThreshold_Stagger', 'Catlas');
            MyBP.PowerThreshold_Knockback = DH.GetFloat('PowerThreshold_Knockback', 'Catlas');
            MyBP.HitReactionChanceMultiplier = DH.GetFloat('HitReactionChanceMultiplier', 'Catlas');
        }
    }
    Super.Initialize();
}
public function DrawDifficulty(BioCheatManager CM)
{
    local SFXDifficultyHandler DH;
    local Name ParamName;
    local Name CategoryName;
    local SFXShield_Base PawnShield;
    local SFXModule_Damage DmgMod;
    local SFXModule_Armour ArmMod;
    local int idx;
    
    DH = SFXGRI(WorldInfo.GRI).DifficultyHandler;
    if (DH != None)
    {
        CategoryName = 'Catlas';
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
            CM.DrawProfileText(PawnShield.ShieldRegenPct @ "(" @ DH.GetMinFloat('AIShieldRegenPct', 'Catlas') @ ":" @ DH.GetMaxFloat('AIShieldRegenPct', 'Catlas') @ ")");
            CM.DrawProfileHeaderText("How Long Before Shields Start To Regenerate: ");
            ParamName = 'ShieldRegenDelay';
            CM.DrawProfileText(PawnShield.ShieldRegenDelay.Value @ "(" @ DH.GetMinFloat('AIShieldRegenDelay', 'Catlas') @ ":" @ DH.GetMaxFloat('AIShieldRegenDelay', 'Catlas') @ ")");
            CM.DrawProfileText(" ");
        }
        CM.DrawProfileHeaderText("Armour Health: ");
        ArmMod = MyBP.GetModule(Class'SFXModule_Armour');
        if (ArmMod != None)
        {
            for (idx = 0; idx < 12; idx++)
            {
                if (ArmMod.ActiveArmour[idx] != None && ArmMod.ActiveArmour[idx].bCanBeDamaged)
                {
                    if (ArmMod.ActiveArmour[idx].ArmourName != 'CanopyGlass')
                    {
                        ParamName = 'ArmourPieceHealth';
                    }
                    else
                    {
                        ParamName = 'GlassCockpitHealth';
                    }
                    CM.DrawProfileText(ArmMod.ActiveArmour[idx].ArmourName @ ArmMod.ActiveArmour[idx].MaxHealth @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
                }
            }
        }
        CM.DrawProfileHeaderText("MeleeAttackInterval: ");
        ParamName = 'MeleeAttackInterval';
        CM.DrawProfileText(MeleeAttackInterval @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("SyncMeleeAttackInterval: ");
        ParamName = 'SyncMeleeAttackInterval';
        CM.DrawProfileText(SyncMeleeAttackInterval @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("SmokeInterval: ");
        ParamName = 'SmokeInterval';
        CM.DrawProfileText(SmokeInterval @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("RocketInterval: ");
        ParamName = 'RocketInterval';
        CM.DrawProfileText(RocketInterval @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("BlockInterval: ");
        ParamName = 'BlockInterval';
        CM.DrawProfileText(BlockInterval @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("CockpitDamageResetDuration: ");
        ParamName = 'CockpitDamageResetDuration';
        CM.DrawProfileText(CockpitDamageResetDuration @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("CockpitBlockThreshold: ");
        ParamName = 'CockpitBlockThreshold';
        CM.DrawProfileText(CockpitBlockThreshold @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("SyncKillChance: ");
        ParamName = 'SyncKillChance';
        CM.DrawProfileText(SyncKillChance @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
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
    local SFXPawn_Catlas Atlas;
    local BioPawn Driver;
    
    Super.NotifyArmourDestroyed(ArmourPiece, instigatedBy);
    if (ArmourPiece == 'CanopyGlass')
    {
        if (MyBP.StartCustomAction(110) == TRUE)
        {
            MyBP.ReplicateAnimatedReaction(MyBP.CurrentCustomAction);
        }
    }
    else
    {
        MyBP.TakeDamage(MyBP.GetMaxHealth() * 0.0700000003, instigatedBy, MyBP.location, vect(0.0, 0.0, 0.0), Class'SFXDamageType_Explosion');
    }
}
public function NotifyArmourHit(float Damage, Name ArmourPiece, Controller instigatedBy, Vector HitLocation, Vector Momentum, optional Class<DamageType> DamageType, optional Actor DamageCauser)
{
    if (ArmourPiece == 'CanopyGlass' && MyBP.CurrentCustomAction == 0)
    {
        CockpitDamageTaken += Damage;
        SetTimer(CockpitDamageResetDuration, FALSE, 'ResetCockpitDamage', );
        if (ShouldBlock())
        {
            MyBP.StartCustomAction(162);
            LastBlockTime = WorldInfo.GameTimeSeconds;
        }
    }
}
public function bool ReactToNearbyEnemy(Pawn NearbyPawn)
{
    if (ShouldMelee(NearbyPawn))
    {
        BeginCombatCommand(Class'SFXAICmd_Catlas_Melee');
        return TRUE;
    }
    return FALSE;
}
public function bool ShouldMelee(Actor MeleeTarget)
{
    if (Normal(MeleeTarget.location - MyBP.location) Dot Vector(MyBP.Rotation) > AtlasMeleeCone)
    {
        return Super.ShouldMelee(MeleeTarget);
    }
    return FALSE;
}
public function bool ShouldSyncMelee(Actor MeleeTarget)
{
    if (Normal(MeleeTarget.location - MyBP.location) Dot Vector(MyBP.Rotation) > AtlasSyncMeleeCone)
    {
        return Super.ShouldSyncMelee(MeleeTarget);
    }
    return FALSE;
}
public final function bool IsAtlasInRange(float Range)
{
    if (MyBP.IsValidTargetFor(Pawn(FireTarget).Controller) == FALSE)
    {
        AILog_Internal(GetFuncName() @ "target not valid", 'Catlas');
        return FALSE;
    }
    if (InRange(FireTarget.location, Range) == FALSE)
    {
        AILog_Internal(GetFuncName() @ "Distance - " @ VSize(FireTarget.location - Pawn.location), 'Catlas');
        return FALSE;
    }
    return TRUE;
}
public final function ResetCockpitDamage()
{
    CockpitDamageTaken = 0.0;
}
public final function bool ShouldBlock()
{
    local int EnemyIdx;
    
    if (MyBP.CanDoCustomAction(162) && WorldInfo.GameTimeSeconds - LastBlockTime > BlockInterval && CockpitDamageTaken >= CockpitBlockThreshold && InRange(FireTarget.location, EnemyDistance_Short) == FALSE)
    {
        EnemyIdx = GetEnemyIndex(Pawn(FireTarget));
        if (EnemyIdx != -1 && TimeSinceEnemyVisible(EnemyIdx) < 3.0)
        {
            return TRUE;
        }
    }
    return FALSE;
}
public final function bool ShouldFireRocket()
{
    local SFXPowerCustomAction Power;
    local int FireTargetIndex;
    local Vector AttackOrigin;
    
    FireTargetIndex = GetEnemyIndex(Pawn(FireTarget));
    if (TimeSinceEnemyLocationUpdate(FireTargetIndex) < 2.0 || TimeSinceHurtByEnemy(FireTargetIndex) < 4.0)
    {
        Power = SFXPowerCustomAction(MyBP.PowerManager.GetPower(RocketAttack));
        if (Power != None && WorldInfo.GameTimeSeconds - LastRocketTime > RocketInterval && Power.CanUsePower(FireTarget))
        {
            if (Normal(FireTarget.location - MyBP.location) Dot Vector(MyBP.Rotation) > RocketConeAngle)
            {
                if (GetAttackOrigin(FireTarget, AttackOrigin) && CanFireAt(FireTarget, AttackOrigin, TRUE))
                {
                    return TRUE;
                }
            }
        }
    }
    return FALSE;
}
public final function bool ShouldSmokeTarget(optional bool bIgnoreRange)
{
    local int EnemyIdx;
    local SFXGame Game;
    
    Game = SFXGame(WorldInfo.Game);
    if (MyBP.CanDoCustomAction(161) && WorldInfo.GameTimeSeconds - LastSmokeTime > SmokeInterval && float(Game.CurrentSmokeCount) < Game.MaxSmokeCount && (bIgnoreRange || InRange(FireTarget.location, EnemyDistance_Medium) == FALSE))
    {
        EnemyIdx = GetEnemyIndex(Pawn(FireTarget));
        if (EnemyIdx != -1 && TimeSinceEnemyVisible(EnemyIdx) < 3.0)
        {
            return TRUE;
        }
    }
    return FALSE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    RocketAttack = 'MIRVBomb'
    AtlasMeleeCone = 0.649999976
    AtlasSyncMeleeCone = 0.5
    AtlasSyncMeleeRange = 400.0
    RocketConeAngle = 0.699999988
    DefaultCommand = Class'SFXAICmd_Base_Catlas'
    MoveFireDelayTime = {X = 2.0, Y = 2.0}
    AI_BurstsToFire = {X = 1.0, Y = 1.0}
    m_fNearbyEnemyDistance = 650.0
    MeleeMoveOffset = 200.0
    EnemyDistance_Melee = 400.0
}