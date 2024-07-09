Class SFXPowerCustomAction_ExecutionerDrone extends SFXPowerCustomAction_ProtectorDroneBase
    config(Game);

var SFXPawn_ProtectorDrone Drone;
var RvrClientEffectInterface CE_DroneExplosionTemplate;
var WwiseEvent DroneDeathSound;
var float DroneDamage;
var float DroneZapRadius;
var float ZapCooldown;

public static function PrecacheVFX(SFXObjectPool ObjectPool, RvrClientEffectManager ClientEffects)
{
    Super(SFXPowerCustomAction).PrecacheVFX(ObjectPool, ClientEffects);
    if (default.DroneClass != None)
    {
        default.DroneClass.static.PrecacheVFX(ObjectPool, ClientEffects);
    }
}
public function StartCustomAction()
{
    DespawnDrone(Drone);
    Super(SFXPowerCustomAction).StartCustomAction();
}
public function OnPowerDetonated(Vector HitLocation, Vector HitNormal, optional SFXProjectile_PowerCustomAction oProjectile, optional Actor HitActor)
{
    local Vector SpawnLocation;
    
    DespawnDrone(Drone);
    Super(SFXPowerCustomAction).OnPowerDetonated(HitLocation, HitNormal, oProjectile, HitActor);
    if (m_oPawn == None)
    {
        return;
    }
    SpawnLocation = GetFrontLocation(m_oPawn);
    if (IsSafeSpawnLocation(SpawnLocation))
    {
        SpawnDrone(SpawnLocation, m_oPawn.Rotation);
        return;
    }
    SpawnLocation = GetBackLocation(m_oPawn);
    if (IsSafeSpawnLocation(SpawnLocation))
    {
        SpawnDrone(SpawnLocation, m_oPawn.Rotation);
        return;
    }
}
public function bool IsDroneAlive()
{
    if (Drone != None && Drone.IsDead() == FALSE)
    {
        return TRUE;
    }
    return FALSE;
}
public function OnDroneKilled(SFXPawn_ProtectorDroneBase oDrone)
{
    local SFXAI_Executioner ExecutionerAI;
    
    oDrone.PlaySound(DroneDeathSound, TRUE);
    ExecutionerAI = SFXAI_Executioner(m_oAI);
    if (ExecutionerAI != None && ExecutionerAI.WorldInfo != None)
    {
        ExecutionerAI.LastDroneTime = ExecutionerAI.WorldInfo.GameTimeSeconds;
    }
}
public function SetupSpawnedDrone(SFXPawn_ProtectorDroneBase SpawnedDrone)
{
    local SFXPowerCustomAction_CombatDroneZap Power;
    
    Super.SetupSpawnedDrone(SpawnedDrone);
    Drone = SFXPawn_ProtectorDrone(SpawnedDrone);
    if (Drone == None)
    {
        return;
    }
    if (Drone.Controller != None)
    {
        SFXAI_Core(Drone.Controller).SetTeam(1);
    }
    Power = SFXPowerCustomAction_CombatDroneZap(Drone.PowerManager.GetPowerByClass(Class'SFXPowerCustomAction_CombatDroneZap'));
    if (Power != None)
    {
        Power.CooldownTime.BaseValue = ZapCooldown;
        Power.Damage.BaseValue = DroneDamage;
        Power.DefaultDamageType = DefaultDamageType;
        Power.ImpactRadius.BaseValue = DroneZapRadius;
        Power.RecalculateAllPowerInfo(FALSE);
    }
}
public function SFXPawn_ProtectorDroneBase SpawnDrone(Vector location, Rotator Rotation)
{
    local SFXPawn_ProtectorDrone ExecutionerDrone;
    local SFXAI_Executioner ExecutionerAI;
    
    ExecutionerDrone = SFXPawn_ProtectorDrone(Super.SpawnDrone(location, Rotation));
    if (ExecutionerDrone != None)
    {
        ExecutionerAI = SFXAI_Executioner(m_oAI);
        if (ExecutionerAI != None && ExecutionerAI.WorldInfo != None)
        {
            ExecutionerAI.LastDroneTime = ExecutionerAI.WorldInfo.GameTimeSeconds;
        }
    }
    return ExecutionerDrone;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_BC_RifleTechTool
        m_nmOrigSetName = 'HMM_BC_RifleTechTool'
        Sequences = (AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechTool_BC_Start', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechTool_BC_End')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_BC_A.HMM_BC_RifleTechTool_BioAnimSetData'
    End Object
    DroneDeathSound = WwiseEvent'Wwise_Power_Tech_Drone.Play_power_tech_S_combatdrone_death'
    DroneDamage = 100.0
    DroneZapRadius = 750.0
    ZapCooldown = 1.5
    DroneClass = Class'SFXPawn_CloneDrone'
    DroneAIClass = Class'SFXAI_ProtectorDrone'
    DefaultDamageType = Class'SFXDamageType_ProtectorDrone'
    CustomCasterCrustParameters = {X = 1.0, Y = 0.0, Z = 0.0}
    CastAnimSet = MY_DYN_HMM_BC_RifleTechTool
    CE_CasterCrustTemplate = RvrClientEffectMulti'BioVFX_T_TechPowers._OmniTool.VCFX.OmniTool_LeftFull_Cbt_VCFX_M'
    CastSound = WwiseEvent'Wwise_Power_Tech_Drone.Play_power_tech_P_combatdrone_cast'
    HenchmanCastSound = WwiseEvent'Wwise_Power_Tech_Drone.Play_power_tech_NP_combatdrone_cast'
    ReleaseTime = 0.300000012
    bCustomCasterCrustParameters = TRUE
    Rank = 1.0
    PowerType = EPowerType.PowerType_Instant
}