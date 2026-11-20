// Source: LE3, SFXPawn_Abomination
// Initial decompilation: 9/7/2024 3:46:31 PM
// MILAN CHANGE - 11/19/2026 - Mgamerz
// Fix Abomination flare effect persisting past death on host if using overload
Class SFXAI_Abomination extends SFXAI_Core
    placeable
    config(AI);

var config array<string> DamageFlareClasses;
var float ChargedSpeedMod;
var const float TargetProximityInterval;
var transient float LastDamageFlareTime;
var float DamageFlareDuration;

public function Initialize()
{
    local SFXDifficultyHandler DH;
    local SFXModule_Damage DmgMod;
    local SFXPawn_Collector_Base CP;
    
    DH = SFXGRI(WorldInfo.GRI).DifficultyHandler;
    if (DH != None)
    {
        MeleeAttackInterval = DH.GetFloat('MeleeAttackInterval', 'Abomination');
        SyncMeleeAttackInterval = DH.GetFloat('SyncMeleeAttackInterval', 'Abomination');
        DamageFlareDuration = DH.GetFloat('DamageFlareDuration', 'Abomination');
        ChargedSpeedMod = DH.GetFloat('ChargedSpeedMod', 'Abomination');
        DmgMod = MyBP.GetModule(Class'SFXModule_Damage');
        if (DmgMod != None)
        {
            DmgMod.NormalizedHealth = DH.GetFloatNormalized('MaxHealth', 'Abomination');
            DmgMod.LevelScaledHealth = DH.GetFloat('MaxHealth', 'Abomination');
            DmgMod.InitializeMaxHealth(DmgMod.LevelScaledHealth);
        }
        if (MyBP != None)
        {
            MyBP.PowerThreshold_Standard = DH.GetFloat('PowerThreshold_Standard', 'Abomination');
            MyBP.PowerThreshold_Stagger = DH.GetFloat('PowerThreshold_Stagger', 'Abomination');
            MyBP.PowerThreshold_Knockback = DH.GetFloat('PowerThreshold_Knockback', 'Abomination');
            MyBP.HitReactionChanceMultiplier = DH.GetFloat('HitReactionChanceMultiplier', 'Abomination');
        }
        CP = SFXPawn_Collector_Base(Pawn);
        if (CP != None)
        {
            CP.PossessionBonusHealthPercent = FMax(0.0, DH.GetFloat('PossessionBonusHealthPercent', 'Abomination'));
            CP.PossessedBarrierBonus = FMax(0.0, DH.GetFloat('PossessedBarrierBonus', 'Abomination'));
            CP.MaxEnemyShieldRecharge = DH.GetFloat('MaxEnemyShieldRecharge', 'Abomination');
            CP.ShieldRegenPct = DH.GetFloat('AIShieldRegenPct', 'Abomination');
            CP.ShieldRegenDelay.X = DH.GetFloat('AIShieldRegenDelay', 'Abomination');
            CP.ShieldRegenDelay.Y = DH.GetFloat('AIShieldRegenDelay', 'Abomination');
        }
    }
    Super.Initialize();
}
public function NotifyTakeHit(Controller instigatedBy, Vector HitLocation, int Damage, Class<DamageType> DamageType, Vector Momentum)
{
    local SFXPawn_Abomination Abomination;
    
    Super.NotifyTakeHit(instigatedBy, HitLocation, Damage, DamageType, Momentum);
    Abomination = SFXPawn_Abomination(Pawn);
    if (Abomination != None && Abomination.bPossessed == FALSE && DamageFlareClasses.Find(string(DamageType)) != -1)
    {
        LastDamageFlareTime = WorldInfo.GameTimeSeconds;
        // MILAN CHANGE - Check if not charged so GUID doesn't get reassigned in FlareUp()
        if (!Abomination.bCharged)
        {
            Abomination.FlareUp();
        }
        // END MILAN CHANGE
        SetTimer(TargetProximityInterval + FRand() * 0.5, FALSE, 'FlareCheck', );
    }
}
public function DrawDifficulty(BioCheatManager CM)
{
    local SFXDifficultyHandler DH;
    local Name ParamName;
    local Name CategoryName;
    local SFXModule_Damage DmgMod;
    local SFXPawn_Abomination Abomination;
    
    Abomination = SFXPawn_Abomination(Pawn);
    DH = SFXGRI(WorldInfo.GRI).DifficultyHandler;
    if (DH != None && Abomination != None)
    {
        CategoryName = 'Abomination';
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
        CM.DrawProfileHeaderText("SyncMeleeAttackInterval: ");
        ParamName = 'SyncMeleeAttackInterval';
        CM.DrawProfileText(SyncMeleeAttackInterval @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("DamageFlareDuration: ");
        ParamName = 'DamageFlareDuration';
        CM.DrawProfileText(DamageFlareDuration @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("ChargedSpeedMod: ");
        ParamName = 'ChargedSpeedMod';
        CM.DrawProfileText(ChargedSpeedMod @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("ExplosionDamage: ");
        ParamName = 'ExplosionDamage';
        CM.DrawProfileText(Abomination.ExplosionDamage @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("SuperExplosionDamage: ");
        ParamName = 'SuperExplosionDamage';
        CM.DrawProfileText(Abomination.SuperExplosionDamage @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("ExplosionRadius: ");
        ParamName = 'ExplosionRadius';
        CM.DrawProfileText(Abomination.ExplosionRadius @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("SuperExplosionRadius: ");
        ParamName = 'SuperExplosionRadius';
        CM.DrawProfileText(Abomination.SuperExplosionRadius @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("DoTDuration: ");
        ParamName = 'DoTDuration';
        CM.DrawProfileText(Abomination.DoTDuration @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("SuperDoTDuration: ");
        ParamName = 'SuperDoTDuration';
        CM.DrawProfileText(Abomination.SuperDoTDuration @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("DoTDamagePerSecond: ");
        ParamName = 'DoTDamagePerSecond';
        CM.DrawProfileText(Abomination.DoTDPS @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("SuperDoTDamagePerSecond: ");
        ParamName = 'SuperDoTDamagePerSecond';
        CM.DrawProfileText(Abomination.SuperDoTDPS @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
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
        CM.DrawProfileHeaderText("PossessionBonusHealthPercent: ");
        ParamName = 'PossessionBonusHealthPercent';
        CM.DrawProfileText(Abomination.PossessionBonusHealthPercent @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("PossessedBarrierBonus: ");
        ParamName = 'PossessedBarrierBonus';
        CM.DrawProfileText(Abomination.PossessedBarrierBonus @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
    }
}
public function bool ReactToNearbyEnemy(Pawn NearbyPawn)
{
    local SFXPawn_Abomination Abomination;
    
    Abomination = SFXPawn_Abomination(Pawn);
    if (Abomination != None && Abomination.bPossessed == FALSE && Abomination.bCharged == FALSE)
    {
        Abomination.FlareUp();
        SetTimer(TargetProximityInterval + FRand() * 0.5, FALSE, 'FlareCheck', );
    }
    BeginCombatCommand(Class'SFXAICmd_Abomination_Melee');
    return TRUE;
}
public function SetMovementSpeed()
{
    local SFXPawn_Abomination Abomination;
    
    Abomination = SFXPawn_Abomination(Pawn);
    if (Abomination != None && (Abomination.bCharged || Abomination.bPossessed))
    {
        MyBP.SetDesiredSpeed(ChargedSpeedMod);
    }
    else
    {
        MyBP.SetDesiredSpeed(1.0);
    }
}
public function FlareCheck()
{
    local Pawn NearbyPawn;
    local SFXPawn_Abomination Abomination;
    
    if (HasNearbyEnemy(NearbyPawn) == FALSE && WorldInfo.GameTimeSeconds - LastDamageFlareTime > DamageFlareDuration)
    {
        Abomination = SFXPawn_Abomination(Pawn);
        if (Abomination != None && Abomination.bPossessed == FALSE && Abomination.bCharged)
        {
            Abomination.FlareDown();
        }
        return;
    }
    SetTimer(TargetProximityInterval + FRand() * 0.5, FALSE, 'FlareCheck', );
}
public function bool ShouldExplode()
{
    local SFXPawn_Abomination Abomination;
    
    Abomination = SFXPawn_Abomination(Pawn);
    if (Abomination != None && Abomination.IsHeadGibbed() == FALSE && (Abomination.bCharged || Abomination.bPossessed))
    {
        return TRUE;
    }
    return FALSE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    DamageFlareClasses = ("SFXDamageType_Overload")
    TargetProximityInterval = 0.75
    DefaultCommand = Class'SFXAICmd_Base_Abomination'
    SyncMeleeAbilityName = 'HuskSyncMelee'
    m_fNearbyEnemyDistance = 1000.0
    bNotifyFriendsOnDeath = TRUE
    EnemyDistance_Short = 400.0
    EnemyDistance_Medium = 1000.0
    EnemyDistance_Long = 2000.0
    EnemyDistance_Melee = 200.0
}
