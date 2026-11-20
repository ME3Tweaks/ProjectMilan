// Source: ME3, Patch_SFXAICmd_Banshee_Aggressive
// Decompiled 11/17/2026 7:37:37 AM against Biod_Cat002_280Banshee.pcc
Class SFXAICmd_Banshee_Aggressive extends SFXAICmd_Base_Melee within SFXAI_Banshee;

var transient int TeleportCount;
var transient float BreachDamageTaken;
var WwiseEvent StartChargeSound;
var WwiseEvent StopChargeSound;

public function NotifyTakeHit(Controller instigatedBy, Object.Vector HitLocation, int Damage, Class<DamageType> DamageType, Object.Vector Momentum)
{
    Super(SFXAICommand).NotifyTakeHit(instigatedBy, HitLocation, Damage, DamageType, Momentum);
    BreachDamageTaken += float(Damage);
    Outer.SetTimer(Outer.BreachDamageResetDuration, FALSE, 'ResetBreachDamage', Self);
    if (BreachDamageTaken >= Outer.BreachDamageThreshold)
    {
        Outer.MyBP.StartCustomAction(173);
        ResetBreachDamage();
        SFXPawn_Banshee(Outer.Pawn).StopCharge();
        Outer.ClearTimer('ResetBreachDamage', Self);
        AggressiveTimeout();
    }
}
public function PeriodicMoveCheck()
{
    Super(SFXAICommand).PeriodicMoveCheck();
    if (IsInBansheeMeleeRange())
    {
        Outer.MoveGoal = None;
        Outer.bReachedMoveGoal = TRUE;
    }
    else if (Outer.ShouldTeleport())
    {
        if (Outer.RouteCache.Length > 0)
        {
            Outer.CachedPath = Outer.RouteCache;
            if (Outer.MoveTarget != None)
            {
                Outer.CachedPath.InsertItem(0, Outer.MoveTarget);
            }
        }
        Outer.MoveGoal = None;
        Outer.bReachedMoveGoal = TRUE;
    }
}
public function Popped()
{
    Super(SFXAICommand_Base_Combat).Popped();
    Outer.LastChargedTime = Outer.WorldInfo.GameTimeSeconds;
    if (Outer.MyBP.bHidden)
    {
        Outer.MyBP.SetHidden(FALSE);
    }
    Outer.ChargedInterval = RandRange(Outer.ChargedIntervalRange.X, Outer.ChargedIntervalRange.Y);
    Outer.ClearTimer('AggressiveTimeout', Self);
    Outer.MyBP.PlaySound(StopChargeSound, FALSE);
    SFXPawn_Banshee(Outer.Pawn).StopCharge();
}
public function Pushed()
{
    Super(SFXAICommand_Base_Combat).Pushed();
    Outer.SetTimer(Outer.AggressiveDuration, FALSE, 'AggressiveTimeout', Self);
    Outer.MyBP.PlaySound(StartChargeSound, FALSE);
}
public function AggressiveTimeout()
{
    Outer.SetCombatMood(3);
}
public function bool HasTeleportFailed()
{
    local SFXPawn_Banshee Banshee;
    
    Banshee = SFXPawn_Banshee(Outer.Pawn);
    if (Banshee != None)
    {
        return Banshee.bTeleportFailed;
    }
    return FALSE;
}
public function bool IsInBansheeMeleeRange()
{
    if (Outer.MyBP.IsValidTargetFor(Pawn(Outer.FireTarget).Controller) && Outer.InRange(Outer.FireTarget.location, Outer.EnemyDistance_Melee))
    {
        return TRUE;
    }
    return FALSE;
}
public function ResetBreachDamage()
{
    BreachDamageTaken = 0.0;
}
public function ResetTeleportData()
{
    local SFXPawn_Banshee Banshee;
    
    TeleportCount = 0;
    Banshee = SFXPawn_Banshee(Outer.Pawn);
    if (Banshee != None)
    {
        Banshee.RecentTeleportNavs.Length = 0;
        Banshee.bTeleportFailed = FALSE;
    }
}

auto state Melee 
{
    
Begin:
    if (Outer.FireTarget == None)
    {
        while (Outer.SelectTarget() == FALSE)
        {
            Outer.Sleep(1.0);
        }
    }
    if (Outer.InRange(Outer.FireTarget.location, Outer.EnemyDistance_Melee) == FALSE || IsProtectedByCover(Pawn(Outer.FireTarget)))
    {
        SetupTimeout();
        Class'SFXAICmd_MoveToGoal'.static.MoveToGoal(Outer, Outer.FireTarget, Outer.MeleeMoveOffset, , FALSE);
    }
    else if (Outer.Pawn.FastTrace(Outer.FireTarget.location, Outer.Pawn.location, , ) == FALSE)
    {
        Class'SFXAICmd_MoveToGoal'.static.MoveToGoal(Outer, Outer.FireTarget, Outer.MeleeMoveOffset, , FALSE);
    }
    else
    {
        Outer.bReachedMoveGoal = TRUE;
    }
    if (Outer.ShouldTeleport())
    {
        ResetTeleportData();
        do {
            if (TeleportCount > 0)
            {
                Outer.Sleep(FRand());
            }
            Outer.Focus = Outer.FireTarget;
            Outer.MyBP.StartCustomAction(172);
            TeleportCount++;
        } until (TeleportCount >= Outer.MaxTeleports || IsInBansheeMeleeRange() || Outer.bReachedMoveGoal == FALSE || HasTeleportFailed());
        Outer.CachedPath.Length = 0;
        Outer.Sleep(0.5);
        Outer.LastTeleportTime = Outer.WorldInfo.GameTimeSeconds;
        if (Outer.MyBP.bHidden)
        {
            Outer.MyBP.SetHidden(FALSE);
        }
    }
    if (Outer.bReachedMoveGoal)
    {
        if (IsInBansheeMeleeRange())
        {
            if (FRand() <= Outer.SyncKillChance && Outer.ShouldSyncMelee(Outer.FireTarget))
            {
                Outer.SetDesiredRotation(Rotator(Outer.FireTarget.location - Outer.Pawn.location));
                Outer.FinishRotation();
                if (IsInBansheeMeleeRange() && Outer.ShouldSyncMelee(Outer.FireTarget))
                {
                    Outer.MyBP.StartCustomAction(135, Pawn(Outer.FireTarget));
                    Outer.LastSyncMeleeTime = Outer.WorldInfo.GameTimeSeconds;
                }
            }
            else if (Outer.ShouldMelee(Outer.FireTarget))
            {
                Outer.SetDesiredRotation(Rotator(Outer.FireTarget.location - Outer.Pawn.location));
                Outer.FinishRotation();
                Outer.MyBP.StartCustomAction(133);
                Outer.LastMeleeTime = Outer.WorldInfo.GameTimeSeconds;
            }
        }
    }
    Outer.Sleep(0.200000003);
    goto 'Begin';
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    StartChargeSound = WwiseEvent'Wwise_Crt_Reap_Banshee_SFX.Play_crt_reap_banshee_sfx_charged_loop'
    StopChargeSound = WwiseEvent'Wwise_Crt_Reap_Banshee_SFX.Stop_crt_reap_banshee_sfx_charged_loop'
}