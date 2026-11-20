// Source: ME3, Patch_SFXDroppedGrenade
// Decompiled 11/17/2026 7:37:46 AM against BioA_CitHub_ShootingRange.pcc
Class SFXDroppedGrenade extends DroppedPickup
    config(Weapon);

var(SFXDroppedGrenade) instanced StaticMeshComponent GrenadeMesh;
var(SFXDroppedGrenade) WwiseEvent GrenadePickupSound;
var float DecayTime;
var(SFXDroppedGrenade) instanced LightEnvironmentComponent LightEnvironment;
var transient bool bPooled;

public event function EncroachedBy(Actor Other)
{
    if (bPooled)
    {
        Recycle();
    }
    else
    {
        Destroy();
    }
}
public event function Landed(Object.Vector HitNormal, Actor FloorActor)
{
    Super.Landed(HitNormal, FloorActor);
    SetCollisionCylinderSize(120.0, 10.0);
}
public function Recycle()
{
    DecayTime = default.DecayTime;
    Inventory = default.Inventory;
    InventoryClass = default.InventoryClass;
    PickupCache = default.PickupCache;
    bFadeOut = default.bFadeOut;
    SetHidden(TRUE);
    SetTickIsDisabled(TRUE);
    SetCollision(FALSE, FALSE, FALSE);
}
public function Reset()
{
    if (bPooled)
    {
        Recycle();
    }
    else
    {
        Super.Reset();
    }
}
public function Reuse()
{
    SetHidden(FALSE);
    SetTickIsDisabled(FALSE);
    SetCollision(TRUE, FALSE, FALSE);
    if (DecayTime != float(0))
    {
        SetTimer(DecayTime, FALSE, 'Recycle', );
    }
}
public function PickedUpBy(Pawn P)
{
    if (bPooled)
    {
        Recycle();
    }
    else
    {
        Destroy();
    }
}
public function GiveTo(Pawn P)
{
    Inventory = None;
    GiveGrenade(P);
    if (BioPawn(P) != None)
    {
        BioPawn(P).PlaySoundForOwnerOnly(GrenadePickupSound);
    }
    PickedUpBy(P);
    ClearTimer('RecheckValidTouch');
}
public function SetCollisionCylinderSize(float CollisionRadius, float CollisionHeight)
{
    local CylinderComponent Comp;
    
    foreach AllOwnedComponents(Class'CylinderComponent', Comp)
    {
        Comp.SetCylinderSize(CollisionRadius, CollisionHeight);
    }
}
public function ShowAmmoFullMessage(Pawn Other)
{
    local PlayerController PC;
    local SFXGUIInteraction GUI;
    local SFXSFHandler_HUD HUD;
    
    if (Other != None && Other.IsLocallyControlled())
    {
        PC = PlayerController(Other.Controller);
        if (PC != None)
        {
            GUI = Class'SFXGUIInteraction'.static.GetInstance();
            if (GUI != None)
            {
                HUD = GUI.CastGetMovie(Class'SFXSFHandler_HUD', PC, GUI.MovieTag_HUD);
                if (HUD != None)
                {
                    HUD.PulseFullAmmoMessage(TRUE);
                }
            }
        }
    }
}
public function bool CanPickUpGrenade(Pawn ChkPawn)
{
    local SFXGRI GRI;
    local SFXInventoryManager InvMan;
    local BioBaseSquad Squad;
    local int idx;
    
    if (ChkPawn != None && ChkPawn.InvManager != None)
    {
        GRI = SFXGRI(WorldInfo.GRI);
        if (GRI != None && GRI.bMultiplayer)
        {
            InvMan = SFXInventoryManager(ChkPawn.InvManager);
            if (InvMan != None && InvMan.bCanPickUpGrenades && InvMan.GetResource(3) < InvMan.GetMaxGrenades())
            {
                return TRUE;
            }
        }
        else if (BioPawn(ChkPawn) != None && BioPawn(ChkPawn).Squad != None)
        {
            Squad = BioPawn(ChkPawn).Squad;
            for (idx = 0; idx < Squad.Members.Length; idx++)
            {
                if (Squad.Members[idx] != None && Squad.Members[idx].InvManager != None)
                {
                    InvMan = SFXInventoryManager(Squad.Members[idx].InvManager);
                    if (InvMan != None && InvMan.bCanPickUpGrenades && InvMan.GetResource(3) < InvMan.GetMaxGrenades())
                    {
                        return TRUE;
                    }
                }
            }
        }
    }
    return FALSE;
}
public function GiveGrenade(Pawn P)
{
    local SFXGRI GRI;
    local SFXInventoryManager InvMan;
    local BioBaseSquad Squad;
    local int idx;
    
    if (P != None && P.InvManager != None)
    {
        GRI = SFXGRI(WorldInfo.GRI);
        if (GRI != None && GRI.DifficultyHandler != None)
        {
            if (GRI.bMultiplayer)
            {
                InvMan = SFXInventoryManager(P.InvManager);
                if (InvMan != None && InvMan.bCanPickUpGrenades)
                {
                    InvMan.AdjustResource(3, GRI.DifficultyHandler.GrenadesPerDrop, TRUE, FALSE);
                }
            }
            else if (BioPawn(P) != None && BioPawn(P).Squad != None)
            {
                Squad = BioPawn(P).Squad;
                for (idx = 0; idx < Squad.Members.Length; idx++)
                {
                    if (Squad.Members[idx] != None && Squad.Members[idx].InvManager != None)
                    {
                        InvMan = SFXInventoryManager(Squad.Members[idx].InvManager);
                        if (InvMan != None && InvMan.bCanPickUpGrenades)
                        {
                            InvMan.AdjustResource(3, GRI.DifficultyHandler.GrenadesPerDrop, TRUE, FALSE);
                        }
                    }
                }
            }
        }
    }
}

auto state Pickup 
{
    public function CheckTouching()
    {
        local Pawn P;
        
        foreach TouchingActors(Class'Pawn', P, )
        {
            Touch(P, None, location, Normal(location - P.location));
        }
    }
    public function RecheckValidTouch()
    {
        CheckTouching();
    }
    public simulated function bool ValidTouch(Pawn Other)
    {
        local SFXInventoryManager InvMan;
        
        if (bTickIsDisabled)
        {
            return FALSE;
        }
        if (Other == None || !Other.bCanPickupInventory || Other.DrivenVehicle == None && Other.Controller == None)
        {
            return FALSE;
        }
        if (CanPickUpGrenade(Other) == FALSE)
        {
            InvMan = SFXInventoryManager(Other.InvManager);
            if (InvMan != None && InvMan.bCanPickUpGrenades)
            {
                ShowAmmoFullMessage(Other);
            }
            return FALSE;
        }
        return TRUE;
    }
    public function BeginState(Name PreviousStateName);
    
    
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        CollisionHeight = 10.0
        CollisionRadius = 120.0
        ReplacementPrimitive = None
    End Template
    Begin Object Class=DynamicLightEnvironmentComponent Name=MyLightEnvironment
    End Object
    Begin Object Class=StaticMeshComponent Name=DroppedGrenadeMesh0
        StaticMesh = StaticMesh'BioVFX_Z_MESHES.Grenades.Canister_Grenade'
        Materials = (Material'BioVFX_Z_MATERIALS.Grenades.Canister_Grenade_MAT_lit')
        ReplacementPrimitive = None
        LightEnvironment = MyLightEnvironment
        bUseAsOccluder = FALSE
        bForceDirectLightMap = TRUE
        CollideActors = FALSE
        BlockRigidBody = FALSE
        Translation = {X = 0.0, Y = 0.0, Z = 6.0}
    End Object
    GrenadeMesh = DroppedGrenadeMesh0
    GrenadePickupSound = WwiseEvent'Wwise_Generic_GUI.Play_PUGeneric'
    DecayTime = 45.0
    LightEnvironment = MyLightEnvironment
    Components = (None, CollisionCylinder, MyLightEnvironment, DroppedGrenadeMesh0)
    LifeSpan = 0.0
    CollisionComponent = DroppedGrenadeMesh0
    bAlwaysRelevant = TRUE
}