// Source: LE3, Krogan_Soldier_MP
// Initial decompilation: 9/7/2024 3:57:35 PM
// MILAN CHANGE - UP3
// Repair fragments not splitting apart from the explosion point
Class SFXPowerCustomActionMP_InfernoGrenade extends SFXPowerCustomAction_InfernoGrenade
    config(Game);

// MILAN CHANGE - UP3 - Launch fragments at configured speed
// We deviate from UP3 here with extra None checks
public function SpawnChildProjectiles(Object.Vector HitLocation, Object.Vector HitNormal, optional SFXProjectile_PowerCustomAction oProjectile)
{
    local int Index;
    local SFXProjectile_PowerCustomAction_InfernoChild Projectile;
    local Object.Vector Direction;
    local Object.Rotator SpawnRotation;
    local float YawRotation;

    if (m_oPawn == None)
    {
        return;
    }
    if (m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        if (ProjectileSplitSound != None)
        {
            SFXGRI(m_oPawn.WorldInfo.GRI).PlayTransientSound(ProjectileSplitSound, HitLocation);
        }
        Direction.X = 1.0;
        Direction.Y = 0.0;
        YawRotation = FRand() * float(65536);
        for (Index = 0; float(Index) < NumChildProjectiles.CurrentValue; Index++)
        {
            Direction.Z = 0.5 + FRand();
            SpawnRotation = Rotator(Direction);
            SpawnRotation.Yaw = int(YawRotation);
            Projectile = SFXGRI(m_oPawn.WorldInfo.GRI).ObjectPool.GetProjectile(Class'SFXProjectile_PowerCustomAction_InfernoChild', m_oPawn, m_oPawn.Instigator, HitLocation + HitNormal * 50.0, SpawnRotation);
            if (Projectile != None)
            {
                Projectile.SetRotation(SpawnRotation);
                if (oProjectile != None)
                {
                    Projectile.InitializePowerProjectile(m_oPawn, ChildProjMaxSpeed, 0.0, oProjectile.Power);
                }
                else
                {
                    Projectile.InitializePowerProjectile(m_oPawn, ChildProjMaxSpeed, 0.0, Self);
                }
                if (oProjectile != None)
                {
                    Projectile.ReplicatedPowerProjInitInfo.Power = oProjectile.ReplicatedPowerProjInitInfo.Power;
                    Projectile.ReplicatedPowerProjInitInfo.Caster = oProjectile.Caster;
                }
            }
            YawRotation += float(65536) / NumChildProjectiles.CurrentValue;
        }
    }
}
// END MILAN CHANGE

// MILAN CHANGE - UP3 - Display fragment count and its rank-six evolution
public function PopulatePowerStatBarEvolves()
{
    Super.PopulatePowerStatBarEvolves();
    PowerStatBars.Length = 4;
    PowerStatBars[3].Data = NumChildProjectiles;
    PowerStatBars[3].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[3].srStatBarDisplayTitle = $702080;
    PowerStatBars[3].EvolvedBonuses[5] = Evolve_NumFragmentsIncrease;
}
// END MILAN CHANGE

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_CB_Grenade
        m_nmOrigSetName = 'HMM_CB_Grenade'
        Sequences = (AnimSequence'BIOG_HMM_CB_A.HMM_CB_Grenade_CB_Grenade2')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_CB_A.HMM_CB_Grenade_BioAnimSetData'
    End Object
    NumChildProjectiles = {BaseValue = 2.0}
    Evolve_GrenadeCountBonus = 1.0
    CastAnimSet = MY_DYN_HMM_CB_Grenade
}
