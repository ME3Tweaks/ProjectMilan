// Source: ME3, Patch_SFXAmmoContainer
// Decompiled 11/17/2026 7:37:40 AM against BioA_CitHub_ShootingRange.pcc
Class SFXAmmoContainer extends SFXDroppedAmmo
    placeable;

var(SFXAmmoContainer) float RespawnTime;
var(SFXAmmoContainer) bool bRespawns;
var repnotify bool bAmmoMeshVisible;

public event simulated function ReplicatedEvent(Name VarName)
{
    Super(DroppedPickup).ReplicatedEvent(VarName);
    switch (VarName)
    {
        case 'bAmmoMeshVisible':
            AmmoMesh.SetHidden(!bAmmoMeshVisible);
            break;
        default:
    }
}
public event simulated function SetInitialState()
{
    bScriptInitialized = TRUE;
    GotoState('Auto', , , );
}
public function GiveTo(Pawn P)
{
    local BioPlayerController PC;
    
    GiveAmmo(P);
    if (BioPawn(P) != None)
    {
        BioPawn(P).PlaySoundForOwnerOnly(AmmoPickupSound);
    }
    PC = BioPlayerController(P.Controller);
    if (PC != None)
    {
        PC.GenerateTutorialEvent(5);
    }
    SetRespawn();
}
public function SetRespawn()
{
    if (bRespawns)
    {
        StartSleeping();
    }
    else
    {
        GotoState('Disabled', , , );
    }
}
public function StartSleeping()
{
    GotoState('Sleeping', , , );
}

state Disabled 
{
    public event simulated function BeginState(Name PreviousStateName)
    {
        SetHidden(TRUE);
        SetCollision(FALSE, FALSE, );
        LifeSpan = 5.0;
    }
    public function StartSleeping();
    
    public function Reset();
    
    
    stop;
};
state Sleeping 
{
    ignores Touch
    ;
    public event function EndState(Name NextStateName)
    {
        if (AmmoMesh != None)
        {
            AmmoMesh.SetHidden(FALSE);
            bAmmoMeshVisible = TRUE;
        }
    }
    public event function BeginState(Name PreviousStateName)
    {
        if (AmmoMesh != None)
        {
            AmmoMesh.SetHidden(TRUE);
            bAmmoMeshVisible = FALSE;
        }
    }
    public function StartSleeping();
    
    
Begin:
    Sleep(RespawnTime);
    GotoState('Pickup', , , );
    stop;
};

replication
{
    if (Role == ENetRole.ROLE_Authority)
        bAmmoMeshVisible;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    Begin Template Class=DynamicLightEnvironmentComponent Name=MyLightEnvironment
    End Template
    Begin Template Class=StaticMeshComponent Name=DroppedAmmoMesh0
        ReplacementPrimitive = None
        LightEnvironment = MyLightEnvironment
    End Template
    RespawnTime = 20.0
    bAmmoMeshVisible = TRUE
    AmmoMesh = DroppedAmmoMesh0
    DecayTime = 0.0
    LightEnvironment = MyLightEnvironment
    Components = (None, CollisionCylinder, MyLightEnvironment, DroppedAmmoMesh0)
    CollisionComponent = DroppedAmmoMesh0
    bNoDelete = TRUE
}