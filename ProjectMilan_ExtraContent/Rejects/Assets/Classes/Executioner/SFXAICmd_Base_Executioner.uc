Class SFXAICmd_Base_Executioner extends SFXAICmd_Base_Cover within SFXAI_Executioner;

var SFXModule_GameEffectManager GEManager;

public function PeriodicMoveCheck()
{
    local SFXPawn_Player pPawn;
    
    Super(SFXAICommand).PeriodicMoveCheck();
    if (Outer.ExecutionerClass == CloneClassType.CloneClass_Infiltrator)
    {
        pPawn = SFXPawn_Player(Outer.FireTarget);
        if (pPawn == None)
        {
            return;
        }
    }
    if (Outer.ExecutionerClass == CloneClassType.CloneClass_Vanguard && Outer.InMeleeRange(Outer.FireTarget.location) == TRUE && Outer.ShouldMelee(Outer.FireTarget) == TRUE)
    {
        Outer.MyBP.StartCustomAction(206);
    }
}
public function Pushed()
{
    Super.Pushed();
    Outer.SetTimer(Outer.GetPeriodicMoveInterval(), TRUE, 'PeriodicMoveCheck', );
}
public function ClearRushTimer()
{
    if (Outer.bPlayerSynced != TRUE)
    {
        Outer.bPlayerSynced = TRUE;
    }
}

auto state Combat 
{
    
Begin:
    Outer.m_bAvoidDangerLinks = TRUE;
    if (Outer.ExecutionerClass == CloneClassType.CloneClass_Infiltrator)
    {
        Outer.ExecutionerDeCloak();
    }
    if (Outer.FireTarget == None)
    {
        Outer.AILog_Internal("Lost enemy.  Re-acquiring target", 'Combat');
        Outer.SelectTarget();
    }
    if (Outer.bAcquireNewCover == FALSE || Outer.bReachedCover)
    {
        Outer.bAcquireNewCover = FALSE;
        Outer.bReachedCover = FALSE;
        if (Outer.ShouldRushPlayer())
        {
            SFXPawn_Executioner(Outer.MyBP).SetMoodColor(2);
            GEManager = Outer.MyBP.GetModule(Class'SFXModule_GameEffectManager');
            if (GEManager != None)
            {
                GEManager.RemoveEffectsByType(Class'SFXGameEffect_MovementSpeedBonus');
                if (Outer.ExecutionerClass != CloneClassType.CloneClass_Infiltrator)
                {
                    GEManager.CreateAndApplyEffect(Class'SFXGameEffect_MovementSpeedBonus', Name, Outer.ExecutionerSpeedBoostDuration, 1, Outer.ExecutionerSpeedIncrease, Outer);
                }
                else
                {
                    GEManager.CreateAndApplyEffect(Class'SFXGameEffect_MovementSpeedBonus', Name, Outer.ExecutionerSpeedBoostDuration, 1, Outer.InfiltratorSpeedIncrease, Outer);
                }
            }
            Outer.m_bAvoidDangerLinks = FALSE;
            Outer.bPlayerSynced = FALSE;
            if (Outer.ExecutionerClass == CloneClassType.CloneClass_Infiltrator)
            {
                Outer.ExecutionerCloak(TRUE);
            }
            Outer.ChargeCountThisRush = 0;
            Outer.bRushChargingActive = TRUE;
            while (Outer.bPlayerSynced == FALSE && Outer.MyBP.GetCurrentShields() > float(0))
            {
                Outer.MyBP.SetTimer(Outer.RushTimeout, FALSE, 'ClearRushTimer', Self);
                if (Outer.ExecutionerClass == CloneClassType.CloneClass_Infiltrator)
                {
                    Class'SFXAICmd_MoveToMeleeRange_Executioner'.static.MoveToMeleeRangeExecutioner(Outer, Outer.FireTarget, 50.0, Outer.Rush_ExecutionRange, Outer.Rush_ExecutionerHealthMinPercent, Outer.Rush_StopFiringRange, FALSE, TRUE);
                }
                else if (Outer.ExecutionerClass == CloneClassType.CloneClass_Vanguard)
                {
                    if (Outer.ChargeCountThisRush <= Outer.MaxChargesPerRush)
                    {
                        Outer.TeleportLocation = Outer.FireTarget;
                        Outer.MyBP.StartCustomAction(213, , TRUE);
                    }
                    else
                    {
                        break;
                    }
                }
                else
                {
                    Class'SFXAICmd_MoveToMeleeRange_Executioner'.static.MoveToMeleeRangeExecutioner(Outer, Outer.FireTarget, 100.0, Outer.Rush_ExecutionRange, Outer.Rush_ExecutionerHealthMinPercent, Outer.Rush_StopFiringRange, TRUE, TRUE);
                }
                if (Outer.bPlayerSynced == TRUE)
                {
                    Outer.MyBP.ClearTimer('ClearRushTimer', Self);
                }
                if (Outer.ExecutionerClass == CloneClassType.CloneClass_Vanguard)
                {
                    Outer.Sleep(Outer.MinTeleportInterval_Rush);
                    continue;
                }
                Outer.Sleep(0.5);
            }
            Outer.bRushChargingActive = FALSE;
            SFXPawn_Executioner(Outer.MyBP).SetMoodColor(1);
            if (Outer.ExecutionerClass == CloneClassType.CloneClass_Infiltrator)
            {
                Outer.ExecutionerDeCloak();
            }
        }
        else if (Outer.ShouldCastDrone())
        {
            Class'SFXAICmd_UsePower'.static.UsePower(Outer, 'ProtectorDrone');
        }
        else if (Outer.ShouldUseGrenade())
        {
            Outer.Focus = Outer.FireTarget;
            if (Normal(Outer.FireTarget.location - Outer.MyBP.location) Dot Vector(Outer.MyBP.Rotation) > Outer.GrenadeConeAngle)
            {
                Class'SFXAICmd_UsePower'.static.UsePower(Outer, Outer.GetGrenadeName(), Outer.FireTarget, , TRUE);
                Outer.SetGrenadeTime();
                Outer.Sleep(1.0);
            }
        }
        else if (Outer.ShouldUsePower())
        {
            Outer.Focus = Outer.FireTarget;
            if (Normal(Outer.FireTarget.location - Outer.MyBP.location) Dot Vector(Outer.MyBP.Rotation) > Outer.GrenadeConeAngle)
            {
                Outer.LastPowerTime = Outer.WorldInfo.GameTimeSeconds;
                Class'SFXAICmd_UsePower'.static.UsePower(Outer, Outer.GetPowerName(), Outer.FireTarget, , TRUE);
                Outer.Sleep(1.0);
            }
        }
        else if (ShouldAttack())
        {
            SFXPawn_Executioner(Outer.MyBP).SetMoodColor(1);
            Outer.ShootWeaponAtFireTarget(Outer.MyBP.GetMaxHealth() * Outer.CancelFirePct);
            if (!Outer.bAcquireNewCover)
            {
                Outer.Sleep(Outer.GetActionDelayTime());
            }
        }
        else
        {
            SFXPawn_Executioner(Outer.MyBP).SetMoodColor(0);
        }
    }
    if (Outer.bAcquireNewCover && Outer.bPlayerLockedOn == FALSE)
    {
        if (SFXPawn(Outer.Pawn) != None)
        {
            SFXPawn(Outer.Pawn).PlayMoveToCoverSound();
        }
        if (Outer.ExecutionerClass == CloneClassType.CloneClass_Infiltrator && Outer.MyBP.GetCurrentShields() <= float(0))
        {
            Outer.ExecutionerCloak();
        }
        Class'SFXAICmd_AcquireCover_Executioner'.static.AcquireNewCover(Outer, Outer.AtCover_WeaponRange, Outer.FireTarget, , !Outer.bCloaked);
        Outer.SetTimer(Outer.GetCoverDelayTime(), FALSE, 'FindNewCover', );
    }
    Outer.Sleep(0.100000001);
    goto 'Begin';
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}