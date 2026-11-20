// Source: ME3, Patch_PwrCustActnMPBioChargeKrogan
// Decompiled 11/17/2026 7:38:13 AM against Krogan_Vanguard_MP.pcc
Class SFXPowerCustomActionMP_BioticCharge_Krogan extends SFXPowerCustomActionMP_BioticCharge
    config(Game);

var config float Evolve_TimedMeleeDamageBonus;
var config float Evolve_TimedMeleeDamageDuration;

public function Impact()
{
    local PlayerController PC;
    local RvrClientEffectInterface.RvrClientEffectTarget CETarget;
    local SFXShield_Base Shield;
    local SFXModule_GameEffectManager Manager;
    
    if (ChargeProjectile != None)
    {
        ChargeProjectile.Destroy();
    }
    PC = PlayerController(m_oPawn.Controller);
    m_oPawn.SetHidden(FALSE);
    m_oPawn.CustomTimeDilation = 1.0;
    SFXGRI(m_oPawn.WorldInfo.GRI).DuringAsyncWorker.SpawnEffectAtLocation(m_oPawn, PS_TeleportIn, m_oPawn.location + Normal(Vector(m_oPawn.Rotation)) * 50.0, m_oPawn.Rotation);
    if (!bFailedToMoveCaster)
    {
        if (m_oPawn.Role == ENetRole.ROLE_Authority)
        {
            bCachedTargetImpacted = FALSE;
            DetonationParameters.ConeDirection = Vector(m_oPawn.Rotation);
            DetonationParameters.ConeDirection.Z += 0.5;
            DetonationParameters.ConeDirection = Normal(DetonationParameters.ConeDirection);
            AreaExplosion(m_oPawn.location, ImpactRadius.CurrentValue, Damage.CurrentValue, DefaultDamageType, Force.CurrentValue, DetonationParameters, int(MaximumImpactTargets.CurrentValue), OnChargeImpact);
            m_oPawn.SetTimer(TimeStingerDelay, FALSE, 'TimeStinger', Self);
        }
        if (SFXPawn_Player(m_oPawn) != None && m_oPawn.Controller != None && m_oPawn.Controller.IsLocalPlayerController())
        {
            SFXGRI(m_oPawn.WorldInfo.GRI).PlayTransientSound(ChargeImpact, m_oPawn.location);
        }
        else
        {
            SFXGRI(m_oPawn.WorldInfo.GRI).PlayTransientSound(HenchChargeImpact, m_oPawn.location);
        }
        Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None)
        {
            Manager.RemoveEffectsByCategory(BonusName);
            Manager.RemoveEffectsByCategory(Name);
        }
        Shield = m_oPawn.GetShields();
        Shield.SetCurrentShields(FClamp(Shield.GetCurrentShields() + Shield.GetMaxShields() * ShieldsRestored.CurrentValue, 0.0, Shield.GetMaxShields()));
        if (m_oPawn.Role == ENetRole.ROLE_Authority)
        {
            ApplyTemporaryGameEffect(m_oPawn, Class'SFXGameEffect_DamageTakenBonus', DamageReductionDuration.CurrentValue, -DamageReduction.CurrentValue, Name, m_oPawn.Controller);
            if (IsEvolvedWithChoice(2))
            {
                ApplyTemporaryGameEffect(m_oPawn, Class'SFXGameEffect_WeaponDamageBonus', Evolve_TimedWeaponDamageDuration, Evolve_TimedWeaponDamageBonus, Name, m_oPawn.Controller);
            }
            if (IsEvolvedWithChoice(3))
            {
                ApplyTemporaryGameEffect(m_oPawn, Class'SFXGameEffect_MeleeDamageBonus', Evolve_TimedMeleeDamageDuration, Evolve_TimedMeleeDamageBonus, Name, m_oPawn.Controller);
            }
        }
        CETarget.Instigator = m_oPawn;
        CETarget.SpawnValue.X = DamageReductionDuration.CurrentValue;
        Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(CE_CrustEffect, CETarget);
    }
    if (PC != None && bIsInputLocked)
    {
        PC.IgnoreLookInput(FALSE);
        PC.IgnoreMoveInput(FALSE);
        bIsInputLocked = FALSE;
    }
    bCollectedVolumes = FALSE;
    if (CustomDetonationRumbleClass != None)
    {
        PlayPowerControllerRumble(CustomDetonationRumbleClass, m_oPawn.location);
    }
    if (CustomDetonationScreenShakeClass != None)
    {
        PlayPowerScreenShake(CustomDetonationScreenShakeClass, m_oPawn.location);
    }
}
public function bool OnChargeImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local SFXModule_Damage DamageModule;
    local SFXPowerCustomActionMP_KroganMeleePassive MeleePassive;
    local bool bReturn;
    
    bReturn = Super(SFXPowerCustomAction_BioticCharge).OnChargeImpact(Resistance, oImpacted, nPreviouslyImpacted, HitLocation, HitNormal);
    if (oImpacted == None)
    {
        return bReturn;
    }
    DamageModule = oImpacted.GetModule(Class'SFXModule_Damage');
    if (DamageModule == None)
    {
        return bReturn;
    }
    if (DamageModule.GetCurrentHealth() > float(0))
    {
        return bReturn;
    }
    MeleePassive = SFXPowerCustomActionMP_KroganMeleePassive(m_oPawn.PowerManager.GetPower('MPMeleePassive'));
    if (MeleePassive != None)
    {
        MeleePassive.OnRegularMeleeKill(oImpacted);
    }
    return bReturn;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    ChargeSpeedMultiplier = 1.0
    Ranks = ({
              Icon = 65, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $634683, 
              Evolved1Description = $634684, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 65, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $645154, 
              Evolved1Description = $645155, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 65, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $645156, 
              Evolved1Description = $645157, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 65, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $645158, 
              Evolved1Description = $645159, 
              Evolved2Name = $645160, 
              Evolved2Description = $645161
             }, 
             {
              Icon = 65, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $645162, 
              Evolved1Description = $645163, 
              Evolved2Name = $502449, 
              Evolved2Description = $727800
             }, 
             {
              Icon = 65, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $645166, 
              Evolved1Description = $645167, 
              Evolved2Name = $645168, 
              Evolved2Description = $645169
             }
            )
    PowerName = 'KroganBioticCharge'
    OverrideList = (Class'SFXCustomAction_Ragdoll', 
                    Class'SFXCustomAction_AnimatedRagdoll', 
                    Class'SFXCustomAction_Frozen', 
                    Class'SFXCustomAction_SwatTurn', 
                    Class'SFXCustomAction_CoverSlipBase', 
                    Class'BioCustomAction_CoverMantle', 
                    Class'BioCustomAction_CoverClimb', 
                    Class'SFXCustomAction_PlayerEvadeBase', 
                    Class'SFXCustomAction_PlayerMeleeBase', 
                    Class'SFXCustomAction_PlayerHeavyMeleeBase', 
                    Class'SFXCustomAction_KroganRoar'
                   )
}