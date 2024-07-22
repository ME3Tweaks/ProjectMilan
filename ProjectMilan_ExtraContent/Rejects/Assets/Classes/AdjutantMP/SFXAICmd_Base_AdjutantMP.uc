Class SFXAICmd_Base_AdjutantMP extends SFXAICommand_Base_Combat within SFXAI_AdjutantMP;

public function NotifyTakeHit(Controller instigatedBy, Vector HitLocation, int Damage, Class<DamageType> DamageType, Vector Momentum)
{
    local EAICustomAction EvadeAction;
    
    Super(SFXAICommand).NotifyTakeHit(instigatedBy, HitLocation, Damage, DamageType, Momentum);
    if (ClassIsChildOf(DamageType, Class'SFXDamageType_Weapon'))
    {
        Outer.EvadeDamageTaken += float(Damage);
        Outer.SetTimer(Outer.EvadeResetDuration, FALSE, 'ResetEvadeDamage', );
        if (instigatedBy != None && instigatedBy.Pawn != None && Outer.MyBP.CurrentCustomAction == 0)
        {
            if (Outer.WorldInfo.GameTimeSeconds - Outer.LastEvadeTime >= Outer.EvadeFrequency && Outer.EvadeDamageTaken >= Outer.EvadeHealthThreshold)
            {
                Outer.AILog_Internal(GetFuncName() @ "Decided to evade...");
                EvadeAction = Outer.GetBestEvadeDir2(instigatedBy.Pawn.location, None, instigatedBy.Pawn);
                if (EvadeAction != EAICustomAction.CA_None)
                {
                    Outer.MyBP.StartCustomAction(int(EvadeAction));
                    Outer.LastEvadeTime = Outer.WorldInfo.GameTimeSeconds;
                    Outer.ClearTimer('ResetEvadeDamage');
                    Outer.ResetEvadeDamage();
                }
                Outer.AILog_Internal(GetFuncName() @ "Evading..." @ EvadeAction);
            }
        }
    }
}
public function NotifyPendingPowerImpact(Name Label, float TimeBeforeImpact, SFXPowerCustomAction Power, SFXProjectile_PowerCustomAction Projectile)
{
    local EAICustomAction EvadeAction;
    
    Super(SFXAICommand).NotifyPendingPowerImpact(Label, TimeBeforeImpact, Power, Projectile);
    if (Outer.MyBP.CurrentCustomAction == 0)
    {
        if (Label == 'Evade')
        {
            if (Outer.WorldInfo.GameTimeSeconds - Outer.LastEvadeTime >= Outer.EvadeFrequency && Outer.ShouldPowerEvade())
            {
                EvadeAction = Outer.GetBestEvadeDir2(Projectile.location, Projectile);
                if (EvadeAction != EAICustomAction.CA_None)
                {
                    Outer.MyBP.StartCustomAction(int(EvadeAction));
                    Outer.LastEvadeTime = Outer.WorldInfo.GameTimeSeconds;
                    if (Projectile != None)
                    {
                        Projectile.PawnEvadedPower(Outer.MyBP, Label, TimeBeforeImpact);
                    }
                }
            }
        }
    }
}
public function PeriodicMoveCheck()
{
    Super(SFXAICommand).PeriodicMoveCheck();
    if (ShouldCharge(Outer.FireTarget) || ShouldBlast(Outer.FireTarget))
    {
        Outer.MoveGoal = None;
        Outer.bReachedMoveGoal = TRUE;
    }
}
public function EAICustomAction GetChargeCA(Actor Target)
{
    local float TargetDistanceSq;
    
    TargetDistanceSq = VSizeSq(Outer.FireTarget.location - Outer.Pawn.location);
    if (TargetDistanceSq < Outer.ShortChargeDistance * Outer.ShortChargeDistance)
    {
        return 205;
    }
    else if (TargetDistanceSq < Outer.MediumChargeDistance * Outer.MediumChargeDistance)
    {
        return 206;
    }
    else
    {
        return 207;
    }
}
public function bool ShouldBlast(Actor Target)
{
    local int EnemyIdx;
    local BioPawn PawnTarget;
    
    PawnTarget = BioPawn(Target);
    if (PawnTarget == None)
    {
        Outer.AILog_Internal("Non-pawn enemy can't be blasted", 'Combat');
        return FALSE;
    }
    if (Outer.WorldInfo.GameTimeSeconds - Outer.LastFireTime < Outer.GetFireDelayTime() || Outer.WorldInfo.GameTimeSeconds - PawnTarget.GetAbilityTimeStamp(Outer.BlastAbilityName) <= Outer.GlobalBlastInterval)
    {
        Outer.AILog_Internal("Enemy can't be blasted again so soon", 'Combat');
        return FALSE;
    }
    if (Outer.InRange(Target.location, Outer.EnemyDistance_Short))
    {
        return FALSE;
    }
    EnemyIdx = Outer.GetEnemyIndex(PawnTarget);
    if (EnemyIdx < 0 || !Outer.IsEnemyVisibleByIndex(EnemyIdx))
    {
        Outer.AILog_Internal("Target not visible", 'Combat');
        return FALSE;
    }
    return TRUE;
}
public final function bool ShouldCharge(Actor Target)
{
    local BioPawn PawnTarget;
    local Vector EndTrace;
    
    PawnTarget = BioPawn(Target);
    if (PawnTarget == None)
    {
        Outer.AILog_Internal("Non-pawn enemy can't be charged", 'Combat');
        return FALSE;
    }
    if (Outer.WorldInfo.GameTimeSeconds - Outer.LastChargeTime <= Outer.ChargeInterval)
    {
        Outer.AILog_Internal("Adjutant can't charge again so soon", 'Combat');
        return FALSE;
    }
    if (Outer.WorldInfo.GameTimeSeconds - PawnTarget.GetAbilityTimeStamp(Outer.ChargeAbilityName) <= Outer.GlobalChargeInterval)
    {
        Outer.AILog_Internal("Enemy can't be charged again so soon", 'Combat');
        return FALSE;
    }
    if (!Outer.MyBP.IsValidTargetFor(Pawn(Outer.FireTarget).Controller))
    {
        Outer.AILog_Internal("Enemy is not a valid target", 'Combat');
        return FALSE;
    }
    if (!Outer.InRange(PawnTarget.location, Outer.EnemyDistance_Short) || Outer.InRange(PawnTarget.location, Outer.EnemyDistance_Melee))
    {
        Outer.AILog_Internal("Enemy is out of range - " @ Outer.EnemyDistance_Short, 'Combat');
        return FALSE;
    }
    EndTrace = Outer.FireTarget.location;
    EndTrace.Z += Outer.Pawn.CylinderComponent.CollisionHeight - PawnTarget.CylinderComponent.CollisionHeight;
    if (!Outer.MyBP.FastTrace(EndTrace, Outer.MyBP.location, Outer.MyBP.GetCollisionExtent() * 0.5, FALSE))
    {
        Outer.AILog_Internal("No LOS to the target", 'Combat');
        return FALSE;
    }
    return TRUE;
}

auto state Combat extends InCombat 
{
    
Begin:
    if (Outer.FireTarget == None)
    {
        while (Outer.SelectTarget() == FALSE)
        {
            Outer.Sleep(1.0);
        }
    }
    Outer.m_bClearVelocityAfterMove = FALSE;
    Class'SFXAICmd_MoveToMeleeRange2'.static.MoveToMeleeRange(Outer, Outer.FireTarget, Outer.MeleeMoveOffset, FALSE);
    if (ShouldCharge(Outer.FireTarget))
    {
        Outer.LastChargeTime = Outer.WorldInfo.GameTimeSeconds;
        BioPawn(Outer.FireTarget).SetAbilityTimeStamp(Outer.ChargeAbilityName);
        Outer.Pawn.Acceleration *= float(0);
        Outer.Pawn.Velocity *= float(0);
        Outer.MyBP.StartCustomAction(int(GetChargeCA(Outer.FireTarget)));
    }
    else if (ShouldBlast(Outer.FireTarget))
    {
        Outer.LastFireTime = Outer.WorldInfo.GameTimeSeconds;
        BioPawn(Outer.FireTarget).SetAbilityTimeStamp(Outer.BlastAbilityName);
        Outer.SetDesiredRotation(Rotator(Outer.FireTarget.location - Outer.Pawn.location));
        Outer.FinishRotation();
        Outer.MyBP.StartCustomAction(169);
    }
    Outer.Sleep(0.200000003);
    goto 'Begin';
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}