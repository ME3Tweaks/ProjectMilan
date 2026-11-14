// MILAN CHANGE - 11/14/2026 - Mgamerz
// Add null guards
public simulated function bool ImpactWithPower(Actor.EPowerResistance Resistance, Pawn Caster, Object.Vector HitLocation, Object.Vector HitNormal, float Damage, Object.Vector Force, Class<DamageType> DamageType)
{
    local float ForceMag;
    local SFXCustomActionTypes.EAICustomAction Action;
    local Object.Vector X;
    local Object.Vector Y;
    local Object.Vector Z;
    local float Angle;
    local float SideAngle;
    local Class<SFXDamageType> dmgType;
    local array<SFXCustomActionTypes.EAICustomAction> Actions;
    local Class<SFXDamageType_Power_Fire> FireDmgType;
    local BioPlayerController PC;
    
    if (Resistance == EPowerResistance.Resistance_Full)
    {
        return FALSE;
    }
    if (Damage > 0.0)
    {
        TakeDamage(Damage, Caster != None ? Caster.Controller : None, HitLocation, vect(0.0, 0.0, 0.0), DamageType, , Caster);
    }
    dmgType = Class<SFXDamageType>(DamageType);
    // MILAN CHANGE - Add null guard to damage type before access
    if (dmgType != None && bCanRagdoll && Resistance == EPowerResistance.Resistance_None && (dmgType.default.bCausesRagdoll || dmgType.default.bCausesRagdollOnDeath && IsDead()))
    {
        if (DrivenVehicle != None)
        {
            DrivenVehicle.DriverLeave(TRUE);
        }
        AddRagdollImpulse(Force, Caster != None ? Caster.Controller : None, HitLocation);
        PC = BioPlayerController(Caster.Instigator.Controller);
        if (PC != None && bAchievementFlyingGranted == FALSE && VSize(Force) >= AchievementForceThreshold && dmgType.default.bIsMelee == FALSE)
        {
            PC.UpdateAccomplishmentProgression('FLYINGCOUNT');
            bAchievementFlyingGranted = TRUE;
        }
        return FALSE;
    }
    if (Role == ENetRole.ROLE_Authority)
    {
        if (Resistance == EPowerResistance.Resistance_None && bUseLargeReactions == FALSE)
        {
            if (DrivenVehicle != None)
            {
                DrivenVehicle.DriverLeave(TRUE);
            }
            FireDmgType = Class<SFXDamageType_Power_Fire>(DamageType);
            if (FireDmgType != None)
            {
                Action = FireDmgType.static.PickFireReaction(Self);
            }
            if (ClassIsChildOf(DamageType, Class'SFXDamageType_Power_Freeze'))
            {
                Action = Class'SFXDamageType_Power_Freeze'.static.PickFreezeReaction(Self);
            }
            if (ClassIsChildOf(DamageType, Class'SFXDamageType_Power_Electrocute'))
            {
                Action = Class'SFXDamageType_Power_Electrocute'.static.PickElectrocuteReaction(Self);
            }
            if (Action != EAICustomAction.CA_None)
            {
                return StartCustomAction(int(Action));
            }
        }
        ForceMag = VSize(Force);
        if (ForceMag > 0.0)
        {
            GetAxes(Rotation, X, Y, Z);
            Angle = Vector(Rotation) Dot Normal(Force);
            SideAngle = Y Dot Normal(Force);
            if (ClassIsChildOf(DamageType, Class'SFXDamageType_Melee'))
            {
                GetMeleeReactions(Angle, SideAngle, Actions);
            }
            if (ClassIsChildOf(DamageType, Class'SFXDamageType_SecondMelee'))
            {
                GetMeleeReactions(Angle, SideAngle, Actions);
            }
            if (bUseLargeReactions == FALSE && ClassIsChildOf(DamageType, Class'SFXDamageType_ThirdMelee'))
            {
                GetKnockbackReactions(Angle, SideAngle, Actions);
            }
            if (IsPlayerOwned() && IsInCover())
            {
                return FALSE;
            }
            if (HasAnyShieldResistance() == FALSE || !IsInCover() || IsInCoverLeaning())
            {
                if (Actions.Length == 0 && ForceMag >= PowerThreshold_Knockback)
                {
                    GetKnockbackReactions(Angle, SideAngle, Actions);
                }
                if (Actions.Length == 0 && ForceMag >= PowerThreshold_Stagger)
                {
                    GetStaggerReactions(Angle, SideAngle, Actions);
                }
                if (Actions.Length == 0 && ForceMag >= PowerThreshold_Standard)
                {
                    GetStandardReactions(Angle, SideAngle, Actions);
                }
            }
            if (Actions.Length > 0)
            {
                return StartCustomAction(int(Actions[Rand(Actions.Length)]));
            }
        }
    }
    return FALSE;
}