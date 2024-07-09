Class SFXAICmd_MoveToMeleeRange_Executioner extends SFXAICmd_MoveToMeleeRange within SFXAI_Executioner;

var float ExecutionRange;
var float ExecutionerHealthMinPercent;
var float StopFiringRange;

public function NotifyTakeHit(Controller instigatedBy, Vector HitLocation, int Damage, Class<DamageType> DamageType, Vector Momentum)
{
    Super(SFXAICommand).NotifyTakeHit(instigatedBy, HitLocation, Damage, DamageType, Momentum);
    if (Outer.MyBP.GetCurrentShields() <= 0.0 && Outer.MyBP.GetCurrentHealth() / Outer.MyBP.GetMaxHealth() <= ExecutionerHealthMinPercent)
    {
        Outer.FindNewCover();
        Outer.bPlayerSynced = TRUE;
        Outer.PopCommand(Self);
    }
}
public function PeriodicMoveCheck()
{
    local SFXPawn EnemyPawn;
    local float DistanceToPlayer;
    
    Super(SFXAICommand).PeriodicMoveCheck();
    EnemyPawn = SFXPawn(Outer.FireTarget);
    if (Outer.MyBP.GetCurrentShields() <= float(0))
    {
        // Go for broke if the target's shields are down!!
        if (EnemyPawn == None || !Outer.bRushChargingActive || EnemyPawn.GetCurrentShields() > 0.0)
        {
            Outer.PopCommand(Self);
        }
    }
    DistanceToPlayer = VSize(Outer.MyBP.location - Outer.FireTarget.location);
    if (DistanceToPlayer < ExecutionRange && Outer.ShouldMelee(Outer.FireTarget) == TRUE)
    {
        if (EnemyPawn != None)
        {
            EnemyPawn.SetAbilityTimeStamp(Outer.SyncMeleeAbilityName);
        }
        Outer.MyBP.StartCustomAction(135, Outer.Enemy);
    }
    if (DistanceToPlayer < StopFiringRange)
    {
        m_bAllowedToFire = FALSE;
    }
    else
    {
        m_bAllowedToFire = TRUE;
    }
}
public function Popped()
{
    local SFXModule_GameEffectManager GEManager;
    
    GEManager = Outer.MyBP.GetModule(Class'SFXModule_GameEffectManager');
    if (GEManager != None)
    {
        GEManager.RemoveEffectsByType(Class'SFXGameEffect_MovementSpeedBonus');
    }
    Outer.bPlayerLockedOn = FALSE;
    Super(GameAICommand).Popped();
}
public function Pushed()
{
    Super(GameAICommand).Pushed();
    Outer.bPlayerLockedOn = TRUE;
}
public static function bool MoveToMeleeRangeExecutioner(SFXAI_Core AI, Actor Target, float NewMoveOffset, float InExecutionRange, float InExecutionerHealthMinPercent, float InStopFiringRange, optional bool bInAllowedToFire = TRUE, optional bool bInAllowPartialPath = TRUE)
{
    local SFXAICmd_MoveToMeleeRange_Executioner Cmd;
    
    if (AI != None && Target != None)
    {
        Cmd = new (SFXAI_Executioner(AI)) Class'SFXAICmd_MoveToMeleeRange_Executioner';
        if (Cmd != None)
        {
            if (Controller(Target) != None)
            {
                Target = Controller(Target).Pawn;
            }
            Cmd.MeleeTarget = Target;
            Cmd.m_fMoveOffset = NewMoveOffset;
            Cmd.m_bAllowedToFire = bInAllowedToFire;
            Cmd.m_bUsePartialPaths = bInAllowPartialPath;
            Cmd.ExecutionRange = InExecutionRange;
            Cmd.ExecutionerHealthMinPercent = InExecutionerHealthMinPercent;
            Cmd.StopFiringRange = InStopFiringRange;
            if (AI != None)
            {
                AI.AILog_Internal("Starting move to goal to " $ Target $ ". Offset: " $ NewMoveOffset $ ", Can Fire: " $ bInAllowedToFire $ ", Partial: " $ bInAllowPartialPath, 'Move');
            }
            AI.PushCommand(Cmd);
            return TRUE;
        }
    }
    return FALSE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}