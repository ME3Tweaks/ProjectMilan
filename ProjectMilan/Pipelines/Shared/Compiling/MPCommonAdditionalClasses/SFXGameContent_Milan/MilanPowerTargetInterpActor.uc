// MILAN CHANGE - Mgamerz - 2026-10-23
// An InterpActor that powers can damage
Class MilanPowerTargetInterpActor extends InterpActor
    placeable;

public simulated function bool ImpactWithPower(EPowerResistance Resistance, Pawn Caster, Vector HitLocation, Vector HitNormal, float Damage, Vector Force, Class<DamageType> DamageType)
{
    local Controller InstigatedBy;

    if (Role < ENetRole.ROLE_Authority || Damage <= 0.0)
    {
        return FALSE;
    }
    if (Caster != None)
    {
        InstigatedBy = Caster.Controller;
    }
    TakeDamage(Damage, InstigatedBy, HitLocation, Force, DamageType, , Caster);
    return TRUE;
}

defaultproperties
{
    Begin Template Class=DynamicLightEnvironmentComponent Name=MyLightEnvironment
        bEnabled = FALSE
    End Template
    Begin Template Class=StaticMeshComponent Name=StaticMeshComponent0
        LightEnvironment = MyLightEnvironment
    End Template
    StaticMeshComponent = StaticMeshComponent0
    LightEnvironment = MyLightEnvironment
    CollisionComponent = StaticMeshComponent0
    Components = (MyLightEnvironment, StaticMeshComponent0)
}
// END MILAN CHANGE
