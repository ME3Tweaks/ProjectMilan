// Source: LE3, Collector_Adept_MP
// Initial decompilation: 9/7/2024 5:13:18 PM
// MILAN CHANGE - UP3
// Preserve Dark Channel damage type across jumps and use green dark channel like Javik does
Class SFXGameEffectMP_ProtheanDarkChannel extends SFXGameEffect_DarkChannel
    config(Game);

var float SlowPercent;
var bool bBeamActive;

public function OnRemoved()
{
    Super(SFXGameEffect_DamageOverTime).OnRemoved();
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_TargetCrustTemplate, CrustGuid, TRUE, Owner);
    if (OwnerPawn != None)
    {
        OwnerPawn.StopSound(StartLoopSound);
        OwnerPawn.PlaySound(StopLoopSound, TRUE);
    }
    if (PSC_Beam != None)
    {
        bBeamActive = FALSE;
        PSC_Beam.SetActive(FALSE);
        PSC_Beam.SetHidden(TRUE);
        if (LastHitPawn != None && LastHitPawn.Mesh != None)
        {
            LastHitPawn.Mesh.DetachComponent(PSC_Beam);
        }
    }
}
public function OnUpdate(float DeltaSeconds)
{
    Super.OnUpdate(DeltaSeconds);
    if (bBeamActive && PSC_Beam != None)
    {
        PSC_Beam.SetVectorParameter('Impact', Owner.location);
    }
}
public function DoDamage()
{
    local BioPawn oPawn;
    
    Super(SFXGameEffect_DamageOverTime).DoDamage();
    if (OwnerPawn != None && OwnerPawn.IsDead() && !DelayedRemove)
    {
        DelayedRemove = TRUE;
        if (OwnerPawn.Role == ENetRole.ROLE_Authority)
        {
            foreach OwnerPawn.CollidingActors(Class'BioPawn', oPawn, JumpRadius, OwnerPawn.location, , , )
            {
                if (!oPawn.IsDead() && int(oPawn.GetTeamNum()) == 1)
                {
                    if (ImpactAdditionalTarget(oPawn))
                    {
                        break;
                    }
                }
            }
        }
    }
}
public function OnApplied()
{
    local EPowerResistance Resistance;
    local Vector HitNormal;
    local float fDamage;
    local Vector vForce;
    local Actor oTargetOverride;
    local Actor Target;
    local RvrClientEffectTarget CETarget;
    
    Super(SFXGameEffect_DamageOverTime).OnApplied();
    OwnerPawn = BioPawn(Owner);
    if (CE_TargetCrustTemplate != None)
    {
        CETarget.Instigator = Owner;
        CETarget.SpawnValue.X = Duration - CurrentTime;
        CrustGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_TargetCrustTemplate, CETarget);
    }
    if (OwnerPawn != None)
    {
        OwnerPawn.PlaySound(StartLoopSound, TRUE);
        if (LastHitPawn != None)
        {
            LastHitPawn.Mesh.AttachComponent(PSC_Beam, BeamAttachBoneName);
            PSC_Beam.SetDepthPriorityGroup(LastHitPawn.Mesh.DepthPriorityGroup);
            PSC_Beam.SetTickGroup(3);
            PSC_Beam.SetHidden(FALSE);
            PSC_Beam.ActivateSystem();
            PSC_Beam.SetVectorParameter('Impact', Owner.location);
            bBeamActive = TRUE;
        }
    }
    if (Power != None)
    {
        Power.AddComboEffect(Owner, Class'SFXGameEffect_PowerCombo_Biotic', Duration);
        if (LastHitPawn == None)
        {
            vForce = -Vector(Owner.Rotation) * 300.0;
        }
        else
        {
            vForce = Normal(Owner.location - LastHitPawn.location) * 300.0;
        }
        Target = Owner;
        Resistance = Target.GetPowerResistance(Power.m_oPawn, Target.location, HitNormal, fDamage, vForce, DamageType, oTargetOverride);
        if (oTargetOverride != None)
        {
            Target = oTargetOverride;
        }
        if (Target.ImpactWithPower(Resistance, Power.m_oPawn, Target.location, HitNormal, fDamage, vForce, DamageType))
        {
            if (BioPawn(Target) != None)
            {
                BioPawn(Target).ReplicateAnimatedReaction(BioPawn(Target).CurrentCustomAction);
            }
        }
    }
}
public function bool ImpactAdditionalTarget(BioPawn oPawn)
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffectMP_ProtheanDarkChannel NewEffect;
    
    Manager = oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        Manager.RemoveEffectsByType(Class'SFXGameEffectMP_ProtheanDarkChannel');
        NewEffect = SFXGameEffectMP_ProtheanDarkChannel(Manager.CreateEffect(Class'SFXGameEffectMP_ProtheanDarkChannel', Power.Name, Duration - CurrentTime, 1, EffectValue, Instigator));
        if (NewEffect != None)
        {
            // MILAN CHANGE - UP3 - Preserve Dark Channel damage type when jumping targets
            NewEffect.DamageType = DamageType;
            // END MILAN CHANGE
            NewEffect.Power = Power;
            NewEffect.LastHitPawn = OwnerPawn;
            if (SlowPercent != 0.0)
            {
                NewEffect.SlowPercent = SlowPercent;
                Manager.CreateAndApplyEffect(Class'SFXGameEffect_MovementSpeedBonus', Power.Name, Duration - CurrentTime, 1, -SlowPercent, Instigator);
            }
            NewEffect.OnApplied();
        }
        OwnerPawn.PlaySound(JumpSound, TRUE);
        Power.CurrentTarget = oPawn;
        if (Power.ShouldReplicate())
        {
            Power.ReplicatePowerSubsequentImpact(oPawn, , CurrentTime);
        }
        return TRUE;
    }
    return FALSE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=ParticleSystemComponent Name=BeamPSC0
        // MILAN CHANGE - UP3 - Use the Prothean Dark Channel beam
        Template = ParticleSystem'BioVFX_Hch_Prothean.Particles.DarkChannel_Beam'
        // END MILAN CHANGE
        ReplacementPrimitive = None
    End Template
    // MILAN CHANGE - UP3 - Use the Prothean Dark Channel target effect
    CE_TargetCrustTemplate = RvrClientEffect'BioVFX_Hch_Prothean.VCFX.DarkChannel_TargetCrust_VCFX'
    // END MILAN CHANGE
    PSC_Beam = BeamPSC0
}
