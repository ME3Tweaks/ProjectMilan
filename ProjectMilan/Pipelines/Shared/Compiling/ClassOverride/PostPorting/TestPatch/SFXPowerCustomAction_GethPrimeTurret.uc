// Source: ME3, Patch_PowCustActionGethPrimeTurret
// Decompiled 11/17/2026 7:38:36 AM against BioD_Gth001_600Core.pcc
Class SFXPowerCustomAction_GethPrimeTurret extends SFXPowerCustomAction
    config(Game);

var array<SFXPawn_GethPrimeTurret> Turrets;
var Object.Vector SpawnLocation;
var config int MaxTurretCount;

public function bool CanUsePower(Actor oTarget)
{
    if (m_oPawn != None && m_oPawn.Role == ENetRole.ROLE_Authority && Turrets.Length >= MaxTurretCount)
    {
        return FALSE;
    }
    return Super.CanUsePower(oTarget);
}
public function OnOwnerDied()
{
    local SFXPawn_GethPrimeTurret Turret;
    
    Super(SFXPowerCustomActionBase).OnOwnerDied();
    foreach Turrets(Turret, )
    {
        DespawnTurret(Turret);
    }
}
public function OnPowerDetonated(Object.Vector HitLocation, Object.Vector HitNormal, optional SFXProjectile_PowerCustomAction oProjectile, optional Actor HitActor)
{
    local SFXPawn_GethPrimeTurret Turret;
    local SFXAI_GethPrimeTurret TurretAI;
    local SFXAI_GethPrime PrimeAI;
    local BioAiController MyController;
    
    Super.OnPowerDetonated(HitLocation, HitNormal, oProjectile, HitActor);
    if (m_oPawn == None || m_oPawn.Role < ENetRole.ROLE_Authority)
    {
        return;
    }
    SpawnLocation = m_oTargetToAimAt.location;
    PrimeAI = SFXAI_GethPrime(m_oPawn.Controller);
    if (PrimeAI == None)
    {
        return;
    }
    Turret = m_oPawn.Spawn(Class'SFXPawn_GethPrimeTurret', m_oPawn, 'GethPrimeTurret', SpawnLocation, m_oPawn.Rotation, , TRUE, TRUE);
    if (Turret == None)
    {
        return;
    }
    MyController = BioAiController(m_oPawn.Controller);
    if (MyController != None && MyController.SpawnFactory != None)
    {
        MyController.SpawnFactory.SubSpawns.AddItem(Turret);
    }
    if (SFXGRI(m_oPawn.WorldInfo.GRI) != None && SFXGRI(m_oPawn.WorldInfo.GRI).WaveCoordinator != None)
    {
        SFXGRI(m_oPawn.WorldInfo.GRI).WaveCoordinator.PawnSpawned(Turret);
    }
    TurretAI = m_oPawn.Spawn(Class'SFXAI_GethPrimeTurret', , , SpawnLocation, m_oPawn.Rotation, None, TRUE);
    if (TurretAI == None)
    {
        return;
    }
    TurretAI.Possess(Turret, FALSE);
    TurretAI.SetTeam(int(m_oPawn.Controller.GetTeamNum()));
    Turret.OnTurretKilled = OnTurretKilled;
    if (m_oPawn.Squad != None)
    {
        m_oPawn.Squad.AddMember(Turret);
    }
    Turrets.AddItem(Turret);
}
public function OnTurretKilled(SFXPawn_GethPrimeTurret oTurret)
{
    TimeUntilNextUse = CooldownTime.CurrentValue;
    Turrets.RemoveItem(oTurret);
}
public function DespawnTurret(SFXPawn_GethPrimeTurret oTurret)
{
    if (oTurret != None && m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        oTurret.Died(m_oPawn.Controller, Class'SFXDamageType_Default', oTurret.location);
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_BC_RifleTechTool
        m_nmOrigSetName = 'HMM_BC_RifleTechTool'
        Sequences = (AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechTool_BC_Start', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechTool_BC_End')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_BC_A.HMM_BC_RifleTechTool_BioAnimSetData'
    End Object
    MaxTurretCount = 3
    ProjectileClass = Class'SFXProjectile_PowerCustomAction_GethPrimeTurret'
    ProjectileAttachPoint = 'Socket01'
    ReleaseEffectBoneName = 'Socket01'
    ReleaseTime = 0.166999996
    CastAnimSet = MY_DYN_HMM_BC_RifleTechTool
    CE_ReleaseEffectTemplate = RvrClientEffect'BioVFX_T_TechBall.VCFX.Tech_Attack_Muzzle_VCFX'
    CastSound = WwiseEvent'Wwise_Power_Tech_Drone.Play_power_tech_NP_combatdrone_cast'
    Discipline = EBioCapMode.BIO_CAPMODE_TECH
    MaximumRange = {BaseValue = 3000.0}
    EffectDuration = {BaseValue = 1000.0}
    PowerName = 'GethPrimeTurret'
    PowerCustomActionID = 47
    Rank = 1.0
    DelayBeforeFirstUse = 8.0
    UsesSharedCooldown = FALSE
    PowerType = EPowerType.PowerType_Projectile
    MinTimeBetweenActions = 5.0
}