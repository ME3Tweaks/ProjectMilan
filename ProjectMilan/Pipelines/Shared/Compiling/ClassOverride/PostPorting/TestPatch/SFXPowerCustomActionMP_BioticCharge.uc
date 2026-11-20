// Source: ME3, Patch_SFXPwrCustActnMPBioCharge
// Decompiled 11/17/2026 7:38:12 AM against Asari_Vanguard_MP.pcc
Class SFXPowerCustomActionMP_BioticCharge extends SFXPowerCustomAction_BioticCharge
    config(Game);

var float ChargeSpeedMultiplier;

public function StartCustomAction()
{
    if (m_oPawn.Role < ENetRole.ROLE_Authority && InternalCanDoCustomAction(None, TRUE) == FALSE)
    {
        InterruptThisCustomAction();
        return;
    }
    if (bDisablePhysics && m_oPawn.Physics == EPhysics.PHYS_RigidBody)
    {
        m_oPawn.TermRagdoll();
    }
    Super.StartCustomAction();
}
public function Teleport()
{
    if (InternalCanDoCustomAction(None, TRUE) == FALSE)
    {
        InterruptThisCustomAction();
        return;
    }
    Super.Teleport();
}
protected function bool InternalCanDoCustomAction(BioPawn SyncPawn, bool bForced)
{
    if (m_oPawn == None || m_oPawn.IsDead() || m_oPawn.Physics == EPhysics.PHYS_RigidBody)
    {
        return FALSE;
    }
    else
    {
        return Super(SFXPowerCustomAction).InternalCanDoCustomAction(SyncPawn, bForced);
    }
}
public function InterruptThisCustomAction()
{
    m_oPawn.ClearTimer('StartTeleport', Self);
    m_oPawn.ClearTimer('Teleport', Self);
    m_oPawn.ClearTimer('Impact', Self);
    if (ChargeProjectile != None)
    {
        ChargeProjectile.Destroy();
    }
    bCollectedVolumes = FALSE;
    m_oPawn.SetHidden(FALSE);
    m_oPawn.CustomTimeDilation = 1.0;
    if (m_oPawn.LastPhysicsSetter == Self && m_oPawn.Physics != EPhysics.PHYS_RigidBody)
    {
        if (OriginalRole != ENetRole.ROLE_SimulatedProxy)
        {
            m_oPawn.SetPhysics(2);
        }
        else
        {
            m_oPawn.SetPhysics(1);
        }
    }
    Super(BioCustomAction).InterruptThisCustomAction();
}
public function StartPower()
{
    fAnimPlayRate = default.fAnimPlayRate * ChargeSpeedMultiplier;
    TeleportStartDelay = default.TeleportStartDelay / ChargeSpeedMultiplier;
    TeleportDelay = default.TeleportDelay / ChargeSpeedMultiplier;
    ImpactDelay_Max = default.ImpactDelay_Max / ChargeSpeedMultiplier;
    ImpactDelay_Min = default.ImpactDelay_Min / ChargeSpeedMultiplier;
    CameraImpactDelay = default.CameraImpactDelay / ChargeSpeedMultiplier;
    Super(SFXPowerCustomAction).StartPower();
}
public function StopCustomAction()
{
    if (bDisablePhysics && m_oPawn.LastPhysicsSetter == Self && m_oPawn.Physics == EPhysics.PHYS_RigidBody)
    {
        m_oPawn.TermRagdoll();
    }
    Super.StopCustomAction();
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    ChargeSpeedMultiplier = 1.5
    ChargeCast = WwiseEvent'wwise_power_biotic_charge.Play_power_biotic_P_charge_cast_MP'
    HenchChargeCast = WwiseEvent'wwise_power_biotic_charge.Play_power_biotic_NP_charge_cast_MP'
    MaximumRagdollTargets = {BaseValue = 1.0}
}