// MILAN CHANGE
// By Mgamerz
// This is the broken version of the objective. Changes here are to allow the working MP2 version to compile
// when this was moved to MPCommon to reduce duplication.
Class SFXObjective_Retrieve_PickupObject extends SFXOperationObjective
    placeable
    config(Game);

struct ReplicatedPickupObject 
{
    var SFXPawn_Player PickedUpBy;
    var SFXObjective_Retrieve_PickupObject.EPickupObjectEventUnused EPOEvent;
    var byte Trigger;
};
// MILAN CHANGE - Rename this type
enum EPickupObjectEventUnused
{
    EPO_PickedUp,
    EPO_Dropped,
    EPO_Retrieved,
};

var Name AttachSocketName;
var transient repnotify SFXObjective_Retrieve_PickupObject.ReplicatedPickupObject ReplicatedPickupObjectInfo;
var SFXPawn_Player PickedUpBy;
var instanced StaticMeshComponent PickupMeshComp;
var stringref srPickedUpObject;
var config float MovementSpeedDecrease;
var const stringref SrPlayerCarryingObjectiveMarker;
var SFXEngagement_Retrieve RetrieveWave;

public event simulated function Destroyed()
{
    RemovePickupObject();
    Super.Destroyed();
}
public simulated function PostBeginPlay()
{
    local SFXModule_MarkerObjective ObjectiveModule;
    
    Super.PostBeginPlay();
    ObjectiveModule = GetModule(Class'SFXModule_MarkerObjective');
    ObjectiveModule.MarkerType = "RetrievePickup";
}
public event simulated function ReplicatedEvent(Name VarName)
{
    Super.ReplicatedEvent(VarName);
    if (VarName == 'ReplicatedPickupObjectInfo')
    {
        ClientPickupObjectEvent();
    }
    else if (VarName == 'ReplicatedMeshInfo')
    {
        SetObjectiveMesh(Class'SFXEngine'.static.GetStrFromSFXUniqueID(ReplicatedMeshInfo.MeshUniqueID), PickupMeshComp);
    }
}
public simulated function Deactivate()
{
    local SFXSimpleUseModule UseModule;
    
    Super.Deactivate();
    SetHidden(TRUE);
    UseModule = GetModule(Class'SFXSimpleUseModule');
    if (UseModule != None)
    {
        UseModule.m_bTargetable = FALSE;
    }
}
public simulated function PawnDowned(BioPawn Pawn)
{
    if (Pawn == None)
    {
        return;
    }
    if (PickedUpBy == Pawn)
    {
        ReplicatePickupObjectEvent(1, PickedUpBy);
        if (RetrieveWave != None)
        {
            RetrieveWave.PlayerDroppedObject(PickedUpBy);
        }
        DropObject();
    }
}
public function Used(Actor User)
{
    local SFXPawn_Player Player;
    local SFXCustomAction_PickupRetrieveObject PickupCustomAction;
    local BioCustomAction CustomAction;
    
    Player = SFXPawn_Player(User);
    if (Player == None)
    {
        return;
    }
    if (RetrieveWave != None)
    {
        if (!RetrieveWave.IsCarryingPickup(Player))
        {
            Player.StartCustomAction(25);
            if (Player.GetCurrentCustomAction(CustomAction))
            {
                PickupCustomAction = SFXCustomAction_PickupRetrieveObject(CustomAction);
                if (PickupCustomAction != None)
                {
                    PickupCustomAction.PickUpObject = Self;
                }
            }
        }
    }
}
public final simulated function ObjectDroppedOff()
{
    RemovePickupObject();
}
public simulated function OnPickedUp(SFXPawn_Player Player)
{
    local Actor oActor;
    local SFXObjective_Retrieve_DropOffLocation DropOff;
    local SFXModule_MarkerObjective ObjectiveModule;
    
    if (Player == None)
    {
        return;
    }
    if (RetrieveWave != None)
    {
        if (!RetrieveWave.IsCarryingPickup(Player))
        {
            RetrieveWave.PlayerPickedUpObject(Player);
            PickUpObject(Player);
            Player.RemoveSFXModule(Player.GetModule(Class'SFXModule_MarkerPlayer'));
            ObjectiveModule = new (Player) Class'SFXModule_MarkerObjective';
            ObjectiveModule.PawnWithExclusiveInvisibility = Player;
            ObjectiveModule.MarkerOffset.Z = 90.0;
            ObjectiveModule.MarkerIconType = EObjectiveMarkerIconType.EOMIT_None;
            ObjectiveModule.MarkerLabel = SrPlayerCarryingObjectiveMarker;
            ObjectiveModule.MarkerType = "RetrievePickup";
            Player.AddSFXModule(ObjectiveModule);
            ObjectiveModule.Activate();
            if (Role == ENetRole.ROLE_Authority)
            {
                ReplicatePickupObjectEvent(0, Player);
                foreach RetrieveWave.ObjectiveActors(oActor, )
                {
                    DropOff = SFXObjective_Retrieve_DropOffLocation(oActor);
                    if (DropOff != None)
                    {
                        DropOff.ObjectPickedUp(Player);
                    }
                }
            }
        }
    }
}
public simulated function PickUpObject(SFXPawn_Player Player)
{
    local SFXSimpleUseModule UseModule;
    local SFXModule_GameEffectManager Manager;
    local SFXModule_MarkerObjective ObjectiveModule;
    local BioPlayerController PC;
    
    if (Player == None)
    {
        return;
    }
    if (Role == ENetRole.ROLE_Authority)
    {
        SetHidden(TRUE);
        if (RetrieveWave != None)
        {
            RetrieveWave.DeactivateObjectiveCombatZone(Self);
        }
        PickedUpBy = Player;
    }
    if (Player.IsLocallyControlled())
    {
        SFXPlayerController(GetALocalPlayerController()).DisplayTextPopup(string(srPickedUpObject));
    }
    ObjectiveModule = GetModule(Class'SFXModule_MarkerObjective');
    ObjectiveModule.Deactivate();
    UseModule = GetModule(Class'SFXSimpleUseModule');
    if (UseModule != None)
    {
        UseModule.m_bTargetable = FALSE;
    }
    Player.AttachComponent(PickupMeshComp);
    Player.Mesh.AttachComponentToSocket(PickupMeshComp, AttachSocketName);
    Manager = Player.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        Manager.CreateAndApplyEffect(Class'SFXGameEffect_MovementSpeedBonus', Name, 0.0, 2, MovementSpeedDecrease, Player.Controller);
    }
    PC = BioPlayerController(Player.Controller);
    if (PC != None)
    {
        Player.bCanRoll = FALSE;
        PC.DisableStorm();
    }
}
public simulated function RemovePickupObject()
{
    local SFXModule_GameEffectManager Manager;
    local BioPlayerController PC;
    local SFXModule_MarkerObjective ObjectiveModule;
    local SFXModule_MarkerPlayer PlayerMarkerModule;
    
    if (PickedUpBy == None)
    {
        return;
    }
    Manager = PickedUpBy.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        Manager.RemoveEffectsByTypeAndCategory(Class'SFXGameEffect_MovementSpeedBonus', Name);
    }
    PC = BioPlayerController(PickedUpBy.Controller);
    if (PC != None)
    {
        PickedUpBy.bCanRoll = TRUE;
        PC.EnableStorm();
    }
    ObjectiveModule = PickedUpBy.GetModule(Class'SFXModule_MarkerObjective');
    if (ObjectiveModule != None)
    {
        ObjectiveModule.Deactivate();
        PickedUpBy.RemoveSFXModule(ObjectiveModule);
    }
    if (PickedUpBy.GetModule(Class'SFXModule_MarkerPlayer') == None)
    {
        PlayerMarkerModule = new (PickedUpBy) Class'SFXModule_MarkerPlayer';
        PickedUpBy.AddSFXModule(PlayerMarkerModule);
    }
    PickedUpBy.DetachComponent(PickupMeshComp);
    PickedUpBy.Mesh.DetachComponent(PickupMeshComp);
    PickedUpBy = None;
}
public function ReplicatePickupObjectEvent(SFXObjective_Retrieve_PickupObject.EPickupObjectEventUnused EPOEvent, SFXPawn_Player PickupPawn)
{
    ReplicatedPickupObjectInfo.EPOEvent = EPOEvent;
    ReplicatedPickupObjectInfo.PickedUpBy = PickupPawn;
    ReplicatedPickupObjectInfo.Trigger++;
}
public function SetObjectiveData(SFXOperation_ObjectiveData ObjData)
{
    Super.SetObjectiveData(ObjData);
    if (Role == ENetRole.ROLE_Authority && ObjData != None)
    {
        SetObjectiveMesh(ObjData.ChosenMeshUniqueString, PickupMeshComp);
    }
}
public simulated function SetOwningWave(SFXWave_Operation NewOwner)
{
    Super.SetOwningWave(NewOwner);
    RetrieveWave = SFXEngagement_Retrieve(NewOwner);
}
public simulated function ActivateObjective()
{
    local SFXSimpleUseModule UseModule;
    
    Super.ActivateObjective();
    SetHidden(FALSE);
    UseModule = GetModule(Class'SFXSimpleUseModule');
    if (UseModule != None)
    {
        UseModule.m_bTargetable = TRUE;
    }
}
public simulated function ClientPickupObjectEvent()
{
    if (RetrieveWave != None)
    {
        switch (ReplicatedPickupObjectInfo.EPOEvent)
        {
            case EPickupObjectEventUnused.EPO_PickedUp:
                PickedUpBy = ReplicatedPickupObjectInfo.PickedUpBy;
                OnPickedUp(PickedUpBy);
                SetHidden(TRUE);
                break;
            case EPickupObjectEventUnused.EPO_Dropped:
                if (PickedUpBy == None)
                {
                    PickUpObject(PickedUpBy);
                }
                PawnDowned(PickedUpBy);
                PickedUpBy = None;
                break;
            case EPickupObjectEventUnused.EPO_Retrieved:
                PickedUpBy = ReplicatedPickupObjectInfo.PickedUpBy;
                if (PickedUpBy == None)
                {
                    PickUpObject(PickedUpBy);
                }
                RetrieveWave.PickupDroppedOff(PickedUpBy, Self);
                ObjectDroppedOff();
                SetHidden(TRUE);
                break;
            default:
        }
    }
    else
    {
        SetTimer(0.00999999978, FALSE, 'ClientPickupObjectEvent', );
    }
}
public simulated function DropObject()
{
    local SFXSimpleUseModule UseModule;
    local SFXModule_MarkerObjective ObjectiveModule;
    
    if (PickedUpBy == None)
    {
        return;
    }
    ObjectiveModule = GetModule(Class'SFXModule_MarkerObjective');
    ObjectiveModule.Activate();
    if (Role == ENetRole.ROLE_Authority)
    {
        SetHidden(FALSE);
    }
    SetLocation(PickedUpBy.location, );
    UseModule = GetModule(Class'SFXSimpleUseModule');
    if (UseModule != None)
    {
        UseModule.m_bTargetable = TRUE;
    }
    RemovePickupObject();
}

replication
{
    if (bNetDirty && Role == ENetRole.ROLE_Authority)
        ReplicatedPickupObjectInfo;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=DynamicLightEnvironmentComponent Name=MyLightEnvironment
    End Template
    Begin Object Class=SFXModule_MarkerObjective Name=ObjectiveModule0
        MarkerOffset = {X = 0.0, Y = 0.0, Z = 80.0}
    End Object
    Begin Object Class=SFXSimpleUseModule Name=SelMod01
        OnUsed = class'SFXObjective_Retrieve_PickupObject'.Used
        fUseRange = 500.0
        m_fMaxSelectionRangeSqr = 235000.0
        m_bTargetable = TRUE
    End Object
    Begin Template Class=StaticMeshComponent Name=MeshComp0
        ReplacementPrimitive = None
        LightEnvironment = MyLightEnvironment
    End Template
    Begin Object Class=StaticMeshComponent Name=PickupMeshComp0
        ReplacementPrimitive = None
    End Object
    AttachSocketName = 'Socket_RetrievePickup'
    PickupMeshComp = PickupMeshComp0
    srPickedUpObject = $597258
    MovementSpeedDecrease = -0.300000012
    SrPlayerCarryingObjectiveMarker = $641202
    OwnerWaveClassName = 'SFXEngagement_Retrieve'
    Mesh = MeshComp0
    LightEnvironment = MyLightEnvironment
    bEnableCombatZone = TRUE
    Components = (None, MyLightEnvironment, MeshComp0)
    Modules = (SelMod01, ObjectiveModule0)
    bAlwaysRelevant = TRUE
    bOnlyDirtyReplication = TRUE
    RemoteRole = ENetRole.ROLE_SimulatedProxy
}