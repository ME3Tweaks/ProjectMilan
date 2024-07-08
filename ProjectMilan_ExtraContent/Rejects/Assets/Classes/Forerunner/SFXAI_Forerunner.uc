Class SFXAI_Forerunner extends SFXAI_Cover
    placeable
    config(AI);

var transient Vector LastAimLocation;
var float ForerunnerAimDelay;
var float AimTrackingDuration;
var float MinTimeBetweenCloaks;
var float LastCloakTime;
var transient bool bFreezeAimRot;
var bool bCloaked;

public function Vector GetAimLocation(optional Actor AimTarget)
{
    if (!bFreezeAimRot)
    {
        LastAimLocation = Super(SFXAI_Core).GetAimLocation(AimTarget);
    }
    return LastAimLocation;
}
public function Initialize()
{
    local SFXDifficultyHandler DH;
    local SFXModule_Damage DmgMod;
    local SFXShield_Base PawnShield;
    
    DH = SFXGRI(WorldInfo.GRI).DifficultyHandler;
    if (DH != None)
    {
        CancelFirePct = DH.GetFloat('CancelFirePct', 'Forerunner');
        MaxFireWaitTime = DH.GetFloat('MaxFireWaitTime', 'Forerunner');
        EvadeDamagePct.X = DH.GetFloat('EvadeDamagePctLow', 'Forerunner');
        EvadeDamagePct.Y = DH.GetFloat('EvadeDamagePctHigh', 'Forerunner');
        EvadeFrequency = DH.GetFloat('EvadeFrequency', 'Forerunner');
        EvadeResetDuration = DH.GetFloat('EvadeResetDuration', 'Forerunner');
        PartialLeanPct = DH.GetFloat('PartialLeanPct', 'Forerunner');
        PowerEvadeChance = DH.GetFloat('PowerEvadeChance', 'Forerunner');
        FlankReactionTime = DH.GetFloat('FlankReactionTime', 'Forerunner');
        ForerunnerAimDelay = DH.GetFloat('ForerunnerAimDelay', 'Forerunner');
        AimTrackingDuration = DH.GetFloat('AimTrackingDuration', 'Forerunner');
        DmgMod = MyBP.GetModule(Class'SFXModule_Damage');
        if (DmgMod != None)
        {
            DmgMod.NormalizedHealth = DH.GetFloatNormalized('MaxHealth', 'Forerunner');
            DmgMod.LevelScaledHealth = DH.GetFloat('MaxHealth', 'Forerunner');
            DmgMod.InitializeMaxHealth(DmgMod.LevelScaledHealth);
        }
        PawnShield = SFXShield_Base(MyBP.InvManager.FindInventoryType(Class'SFXShield_Base', TRUE));
        if (PawnShield != None)
        {
            PawnShield.InitializeMaxShields(DH.GetFloat('MaxShields', 'Forerunner'));
            PawnShield.MaxEnemyShieldRecharge = DH.GetFloat('MaxEnemyShieldRecharge', 'Forerunner');
            if (PawnShield.MaxEnemyShieldRecharge > 0.0)
            {
                PawnShield.bRechargeable = TRUE;
                PawnShield.ShieldRegenPct = DH.GetFloat('AIShieldRegenPct', 'Forerunner');
                PawnShield.ShieldRegenDelay.X = DH.GetMinFloat('AIShieldRegenDelay', 'Forerunner');
                PawnShield.ShieldRegenDelay.Y = DH.GetMaxFloat('AIShieldRegenDelay', 'Forerunner');
                PawnShield.ShieldRegenDelay.Value = DH.GetFloat('AIShieldRegenDelay', 'Forerunner');
            }
        }
        if (MyBP != None)
        {
            MyBP.PowerThreshold_Standard = DH.GetFloat('PowerThreshold_Standard', 'Forerunner');
            MyBP.PowerThreshold_Stagger = DH.GetFloat('PowerThreshold_Stagger', 'Forerunner');
            MyBP.PowerThreshold_Knockback = DH.GetFloat('PowerThreshold_Knockback', 'Forerunner');
            MyBP.HitReactionChanceMultiplier = DH.GetFloat('HitReactionChanceMultiplier', 'Forerunner');
        }
    }
    Super(SFXAI_Core).Initialize();
}
public function Rotator GetAdjustedAimFor(Weapon W, Vector StartFireLoc)
{
    local Vector AimLoc;
    local SFXWeapon Wpn;
    local Rotator AimRot;
    
    Wpn = SFXWeapon(W);
    if (Pawn != None && FireTarget != None && Wpn != None)
    {
        AimLoc = GetAimLocation(FireTarget);
        AimRot = Rotator(AimLoc - StartFireLoc);
        return AimRot;
    }
    return Pawn.Rotation;
}
public function NotifyChangedWeapon(Weapon PrevWeapon, Weapon NewWeapon)
{
    WeaponAimDelay = ForerunnerAimDelay;
}
public function NotifyTakeHit(Controller instigatedBy, Vector HitLocation, int Damage, Class<DamageType> DamageType, Vector Momentum)
{
    Super.NotifyTakeHit(instigatedBy, HitLocation, Damage, DamageType, Momentum);
    if (MyBP.GetCurrentShields() <= 0.0)
    {
        BeginCombatCommand(Class'SFXAICmd_Reaction_ForerunnerFlee');
    }
}
public function NotifyWeaponFired(Weapon W, byte FireMode)
{
    Super(SFXAI_Core).NotifyWeaponFired(W, FireMode);
    bFreezeAimRot = FALSE;
    Decloak();
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
        CategoryName = 'Forerunner';
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
            CM.DrawProfileText(PawnShield.ShieldRegenPct @ "(" @ DH.GetMinFloat('AIShieldRegenPct', 'Forerunner') @ ":" @ DH.GetMaxFloat('AIShieldRegenPct', 'Nemesis') @ ")");
            CM.DrawProfileHeaderText("How Long Before Shields Start To Regenerate: ");
            ParamName = 'ShieldRegenDelay';
            CM.DrawProfileText(PawnShield.ShieldRegenDelay.Value @ "(" @ DH.GetMinFloat('AIShieldRegenDelay', 'Forerunner') @ ":" @ DH.GetMaxFloat('AIShieldRegenDelay', 'Forerunner') @ ")");
            CM.DrawProfileText(" ");
        }
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
        CM.DrawProfileHeaderText("ForerunnerAimDelay: ");
        ParamName = 'ForerunnerAimDelay';
        CM.DrawProfileText(ForerunnerAimDelay @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("AimTrackingDuration: ");
        ParamName = 'AimTrackingDuration';
        CM.DrawProfileText(AimTrackingDuration @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
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
public function bool IsCombatStale()
{
    return FALSE;
}

public function bool ReactToFlank(Pawn FlankingPawn)
{
    local SFXPawn ChkPawn;
    
    ChkPawn = SFXPawn(FlankingPawn);
    if (ChkPawn != None && ChkPawn.bIsPet == FALSE)
    {
        ApplyCoverDecay(2000.0);
        SFXGRI(WorldInfo.GRI).TriggerVocalizationEvent(87, ChkPawn, MyBP);
        BeginCombatCommand(Class'SFXAICmd_Reaction_ForerunnerFlee');
        return TRUE;
    }
    return FALSE;
}
public function bool ReactToNearbyEnemy(Pawn NearbyPawn)
{
    local SFXPawn ChkPawn;
    
    ChkPawn = SFXPawn(NearbyPawn);
    if (ChkPawn != None && ChkPawn.bIsPet == FALSE)
    {
        BeginCombatCommand(Class'SFXAICmd_Reaction_ForerunnerFlee');
        return TRUE;
    }
    return FALSE;
}
public function bool ShouldFindBerserkCover()
{
    return TRUE;
}
public final function FreezeAiming()
{
    bFreezeAimRot = TRUE;
}
public function AttemptCloak()
{
    local SFXModule_GameEffectManager GEManager;
    local SFXSelectionModule SelectionModule;
    LogInternal(Self $ " - " $ GetFuncName());
    
    if (bCloaked)
    {
        return;
    }
    if (WorldInfo.GameTimeSeconds - LastCloakTime > MinTimeBetweenCloaks)
    {
        bCloaked = TRUE;
        SetTimer(8, false, 'Decloak');
        SFXPawn_Forerunner(MyBP).ForerunnerCloak();
    }
}
public function Decloak()
{
    local SFXModule_GameEffectManager GEManager;
    local SFXSelectionModule SelectionModule;

    LogInternal(Self $ " - " $ GetFuncName());

    ClearTimer('Decloak');
    if (bCloaked)
    {
        bCloaked = FALSE;
        LastCloakTime = WorldInfo.GameTimeSeconds;
        SFXPawn_Forerunner(MyBP).ForerunnerDecloak();
    }
}
public function NotifyDeathBlow(Class<DamageType> DamageType)
{
    Super.NotifyDeathBlow(DAmageType);
Decloak();
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
    MinTimeBetweenCloaks = 8.0
    AtCover_WeaponRange = AtCov_EvalWeaponRange
    AtCover_Defensive = AtCov_EvalDefensive
    AtCover_Aggressive = AtCov_EvalAggressive
    AtCover_NearMoveGoal = AtCov_EvalNearGoal
    DefaultCommand = Class'SFXAICmd_Base_Forerunner'
    m_bAvoidDangerLinks = TRUE
}