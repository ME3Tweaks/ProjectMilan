// Source: LMP, HumanFemale_Sentinel_MP (installed LE3 port)
// Initial decompilation: 10/31/2026
// MILAN CHANGE - UP3
// Route Tech Armor blast impacts through the owning power combo check
Class SFXGameEffect_PowerArmor extends SFXGameEffect_DamageTakenBonus;

var SFXPreAsyncWorkTicker.AreaEffectParameters AoEParams;
var Object.Guid ShieldClientEffectGuid;
var RvrClientEffectInterface CE_ShieldTemplate;
var RvrClientEffectInterface CE_ShieldDeathTemplate;
var WwiseEvent PlayerExplosionSound;
var WwiseEvent ExplosionSound;
var BioPawn OwnerPawn;
var clearcrosslevel SFXPowerCustomAction_TechArmor Power;
var float ExplosionRadius;
var float ExplosionDamage;
var float ExplosionForce;
var bool bShieldVFXOn;
var bool bShieldDestroyed;

public function DoAreaExplosionForActor(Actor oActor, int ImpactCount)
{
    if (Owner != None && Power != None)
    {
        Power.DoAreaExplosionForActor(oActor, Owner.location, ImpactCount, ExplosionDamage, Class'SFXDamageType_PowerArmor', ExplosionForce, AoEParams, 0, OnImpact);
    }
}
// MILAN CHANGE - UP3 - Check the owning power detonators on valid Tech Armor blast impacts
public function bool OnImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local SFXPawn oPawn;

    oPawn = SFXPawn(oImpacted);
    if (oPawn == None || Power == None)
    {
        return FALSE;
    }
    if (Resistance == EPowerResistance.Resistance_None)
    {
        oPawn.AddPowerAssistEvent(OwnerPawn, Power.DisplayName, Power.PowerAssistFullControlValue);
    }
    if (Resistance != EPowerResistance.Resistance_Full)
    {
        Power.CheckForPowerCombo(oPawn, Resistance, HitLocation, HitNormal);
    }
    return TRUE;
}
// END MILAN CHANGE
public function OnRemoved()
{
    Super.OnRemoved();
    OnShieldDestroyed(FALSE);
}
public function OnUpdate(float DeltaSeconds)
{
    local BioWorldInfo Info;
    local BioPlayerController PC;

    Super(SFXGameEffect).OnUpdate(DeltaSeconds);
    Info = BioWorldInfo(Owner.WorldInfo);
    if (Info != None)
    {
        PC = Info.GetLocalPlayerController();
        if (PC != None && (PC.GameModeManager2.IsActive(8) || PC.GameModeManager2.IsActive(7)))
        {
            TurnVFXOff();
            return;
        }
    }
    if (!bShieldDestroyed)
    {
        TurnVFXOn();
    }
}
public function OnApplied()
{
    Super.OnApplied();
    OwnerPawn = BioPawn(Owner);
    TurnVFXOn();
}
public function OnShieldDestroyed(bool PlayDeathCrust)
{
    local Object.Vector Parms;

    if (OwnerPawn == None)
    {
        return;
    }
    if (bShieldDestroyed)
    {
        return;
    }
    TurnVFXOff();
    bShieldDestroyed = TRUE;
    if (PlayDeathCrust)
    {
        if (OwnerPawn != None && Power != None)
        {
            if (Power.IsEvolvedWithChoice(0))
            {
                Parms.Y = 1.0;
            }
            Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayAtLocation(CE_ShieldDeathTemplate, Owner.location, vect(0.0, 0.0, 1.0), Parms);
            Power.AreaExplosion(OwnerPawn.location, ExplosionRadius, ExplosionDamage, Class'SFXDamageType_PowerArmor', ExplosionForce, AoEParams, 0, OnImpact);
            if (SFXPawn_Player(OwnerPawn) != None && OwnerPawn.IsLocallyControlled())
            {
                OwnerPawn.PlaySound(PlayerExplosionSound, TRUE);
            }
            else
            {
                OwnerPawn.PlaySound(ExplosionSound, TRUE);
            }
            Power.OnShieldExplode();
        }
    }
}
public function TurnVFXOff()
{
    bShieldVFXOn = FALSE;
    Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(None, ShieldClientEffectGuid, !Owner.bHidden);
}
public function TurnVFXOn()
{
    local RvrClientEffectInterface.RvrClientEffectTarget CETarget;
    local RvrClientEffectManager Manager;

    if (!bShieldVFXOn)
    {
        Manager = Class'RvrClientEffectManager'.static.GetClientEffectManager();
        if (Manager != None)
        {
            bShieldVFXOn = TRUE;
            CETarget.Instigator = Owner;
            CETarget.SpawnValue.X = Duration;
            ShieldClientEffectGuid = Manager.StartOnTarget(CE_ShieldTemplate, CETarget, Owner);
        }
        else
        {
            Owner.SetTimer(0.100000001, FALSE, 'TurnVFXOn', Self);
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    AoEParams = {
                 ConeDirection = {X = 0.0, Y = 0.0, Z = 0.0},
                 HitDirectionOffset = {Pitch = 0, Yaw = 0, Roll = 0},
                 ConeAngle = 0.0,
                 ImpactFriends = FALSE,
                 ImpactDeadPawns = FALSE,
                 ImpactPlaceables = TRUE,
                 BlockedByObjects = FALSE,
                 DistancedSorted = FALSE
                }
    CE_ShieldDeathTemplate = RvrClientEffect'BioVFX_T_Sentinel.VCFX.PowerArmor_Burst_VCFX'
    PlayerExplosionSound = WwiseEvent'Wwise_Power_Tech_TechArmor.Play_power_tech_P_techarmor_detonate'
    ExplosionSound = WwiseEvent'Wwise_Power_Tech_TechArmor.Play_power_tech_NP_techarmor_detonate'
}
