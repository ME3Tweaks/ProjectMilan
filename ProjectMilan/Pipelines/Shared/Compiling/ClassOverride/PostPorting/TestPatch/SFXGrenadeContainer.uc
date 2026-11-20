// Source: ME3, Patch_SFXGrenadeContainer
// Decompiled 11/17/2026 7:37:52 AM against BioA_CitHub_ShootingRange.pcc
Class SFXGrenadeContainer extends SFXDroppedGrenade
    placeable;

var float RespawnTime;
var(SFXGrenadeContainer) bool bRespawns;
var repnotify bool bGrenadeMeshVisible;

public event simulated function ReplicatedEvent(Name VarName)
{
    Super(DroppedPickup).ReplicatedEvent(VarName);
    switch (VarName)
    {
        case 'bGrenadeMeshVisible':
            GrenadeMesh.SetHidden(!bGrenadeMeshVisible);
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
    GiveGrenade(P);
    if (BioPawn(P) != None)
    {
        BioPawn(P).PlaySoundForOwnerOnly(GrenadePickupSound);
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
        if (GrenadeMesh != None)
        {
            GrenadeMesh.SetHidden(FALSE);
            bGrenadeMeshVisible = TRUE;
        }
    }
    public event function BeginState(Name PreviousStateName)
    {
        if (GrenadeMesh != None)
        {
            GrenadeMesh.SetHidden(TRUE);
            bGrenadeMeshVisible = FALSE;
        }
    }
    public function StartSleeping();
    
    
Begin:
    Sleep(RespawnTime);
    while (SFXGRI(WorldInfo.GRI).InCombat() == FALSE)
    {
        Sleep(5.0);
    }
    GotoState('Pickup', , , );
    stop;
};

replication
{
    if (Role == ENetRole.ROLE_Authority)
        bGrenadeMeshVisible;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    Begin Template Class=DynamicLightEnvironmentComponent Name=MyLightEnvironment
    End Template
    Begin Template Class=StaticMeshComponent Name=DroppedGrenadeMesh0
        ReplacementPrimitive = None
        LightEnvironment = MyLightEnvironment
    End Template
    RespawnTime = 20.0
    bGrenadeMeshVisible = TRUE
    GrenadeMesh = DroppedGrenadeMesh0
    DecayTime = 0.0
    LightEnvironment = MyLightEnvironment
    Components = (None, CollisionCylinder, MyLightEnvironment, DroppedGrenadeMesh0)
    CollisionComponent = DroppedGrenadeMesh0
    bNoDelete = TRUE
}