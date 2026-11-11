// MILAN CHANGE - 10/12/2026
// By Mgamerz
// Increase pickup cooldown every time picked up in rapid succession to prevent exploits

Class SFXObjective_Retrieve_PickupObject_DLC extends SFXOperationObjective
    placeable
    config(Game);

// MILAN CHANGE - Mgamerz - Change name to DLC because the non-DLC version in BIOP_MP_COMMON has a struct with the same name.
// The decompiler looks structs up by name, so it would pick the wrong one and break recompiles of this class.
struct ReplicatedPickupObjectDLC
{
    var SFXPawn_Player PickedUpBy;
    var EPickupObjectEventDLC EPOEvent;
    var byte Trigger;
    var vector DropLocation;
};
// MILAN CHANGE - Mgamerz - Change name to DLC because the non-DLC (broken) version was promoted to BIOP_MP_COMMON causing collision here
enum EPickupObjectEventDLC
{
    EPO_PickedUp,
    EPO_Dropped,
    EPO_Retrieved,
};
struct RetrieveMoveSpeedOverride 
{
    var Name CharacterClass;
    var float MovementSpeedDecrease;
};

var config array<RetrieveMoveSpeedOverride> MovementSpeedOverrides;
var config array<Name> DropObjectCustomActions;
var Name AttachSocketName;
var transient repnotify ReplicatedPickupObjectDLC ReplicatedPickupObjectInfo;
var SFXPawn_Player PickedUpBy;
var instanced SkeletalMeshComponent PickupMeshComp;
var transient SkeletalMeshComponent CarriedPickupMesh;
var transient SFXModule_MarkerObjective CarrierMarker;
var stringref srPickedUpObject;
var config float MovementSpeedDecrease;
var const stringref SrPlayerCarryingObjectiveMarker;
var SFXEngagement_Retrieve_DLC_Base RetrieveWave;
var config float CheckForDropFrequency;
var config float MaxCarrierFloorDistance;
var transient vector LastValidDropLocation;
var float PickedUpTimestamp;
var config float IgnoreStealthFlagTime;
var WwiseEvent PickupSound;
var WwiseEvent HandedInSound;
var WwiseEvent DroppedLoopStartSound;
var WwiseEvent DroppedLoopStopSound;
var bool bLoopStarted;

// MILAN CHANGE - Mgamerz - 2026-10-08
// Penalize rapid drops per pawn while allowing teammate interceptions
struct RetrieveDropPenalty
{
    var SFXPawn_Player Player;
    var int Count;
    var float LastDropTime;
    var float LockoutUntil;
};
var transient array<RetrieveDropPenalty> DropPenalties;
var config float RapidHoldWindow;
var config float StrikeForgiveTime;
var config array<float> PickupLockoutLadder;

public function int FindDropPenalty(SFXPawn_Player Player, bool bCreate)
{
    local int i;
    local RetrieveDropPenalty Entry;
    for (i = DropPenalties.Length - 1; i >= 0; i--)
    {
        if (DropPenalties[i].Player == None || DropPenalties[i].Player.bDeleteMe)
        {
            DropPenalties.Remove(i, 1);
        }
    }
    for (i = 0; i < DropPenalties.Length; i++)
    {
        if (DropPenalties[i].Player == Player)
        {
            return i;
        }
    }
    if (!bCreate)
    {
        return -1;
    }
    Entry.Player = Player;
    DropPenalties.AddItem(Entry);
    return DropPenalties.Length - 1;
}
public function bool IsPickupLocked(SFXPawn_Player Player)
{
    local int i;
    i = FindDropPenalty(Player, FALSE);
    if (i < 0)
    {
        return FALSE;
    }
    return WorldInfo.GameTimeSeconds < DropPenalties[i].LockoutUntil;
}
public function ClearPickupLockout(SFXPawn_Player Player)
{
    local int i;
    i = FindDropPenalty(Player, FALSE);
    if (i >= 0)
    {
        DropPenalties[i].LockoutUntil = 0.0;
    }
}
public function RecordVoluntaryDrop()
{
    local int i;
    local float Now;
    if (Role != ENetRole.ROLE_Authority || PickedUpBy == None)
    {
        return;
    }
    i = FindDropPenalty(PickedUpBy, TRUE);
    Now = WorldInfo.GameTimeSeconds;
    if (Now - PickedUpTimestamp >= RapidHoldWindow)
    {
        DropPenalties[i].Count = 0;
        DropPenalties[i].LastDropTime = Now;
        DropPenalties[i].LockoutUntil = 0.0;
        return;
    }
    if (Now - DropPenalties[i].LastDropTime >= StrikeForgiveTime)
    {
        DropPenalties[i].Count = 0;
    }
    DropPenalties[i].LastDropTime = Now;
    if (PickupLockoutLadder.Length == 0)
    {
        DropPenalties[i].Count = 0;
        DropPenalties[i].LockoutUntil = 0.0;
        return;
    }
    DropPenalties[i].Count = Min(DropPenalties[i].Count + 1, PickupLockoutLadder.Length);
    DropPenalties[i].LockoutUntil = Now + FMax(0.0, PickupLockoutLadder[DropPenalties[i].Count - 1]);
}
// END MILAN CHANGE
public event simulated function Destroyed()
{
    RemovePickupObject();
    if (bLoopStarted)
    {
        bLoopStarted = FALSE;
        PlaySound(DroppedLoopStopSound, TRUE);
    }
    Super.Destroyed();
}
public simulated function PostBeginPlay()
{
    local SFXModule_MarkerObjective ObjectiveModule;
    
    Super.PostBeginPlay();
    ObjectiveModule = GetModule(Class'SFXModule_MarkerObjective');
    ObjectiveModule.MarkerType = "RetrievePickupDLC";
}
public event simulated function ReplicatedEvent(Name VarName)
{
    Super.ReplicatedEvent(VarName);
    if (VarName == 'ReplicatedPickupObjectInfo')
    {
        ClientPickupObjectEvent();
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
    // MILAN CHANGE - Mgamerz - 2026-10-08
    // Downing releases this pawn's lockout without adding or clearing strikes
    if (Role == ENetRole.ROLE_Authority && SFXPawn_Player(Pawn) != None)
    {
        ClearPickupLockout(SFXPawn_Player(Pawn));
    }
    // END MILAN CHANGE
    if (PickedUpBy == Pawn)
    {
        DropObject(TRUE);
    }
}
public function Used(Actor User)
{
    local SFXPawn_Player Player;
    
    Player = SFXPawn_Player(User);
    if (Player == None)
    {
        return;
    }
    // MILAN CHANGE - Mgamerz - 2026-10-08
    // Reject on authority before starting animation or changing carrier state
    if (Role != ENetRole.ROLE_Authority || PickedUpBy != None || IsPickupLocked(Player))
    {
        return;
    }
    // END MILAN CHANGE
    if (RetrieveWave != None)
    {
        if (!RetrieveWave.IsCarryingPickup(Player))
        {
            Player.StartCustomAction(27);
            OnPickedUp(Player);
        }
    }
}
public simulated function HideWeapons()
{
    ShowWeapons(FALSE);
}
public simulated function DropObject(bool bPlayDownedVO)
{
    local SFXObjective_Retrieve_DropOffLocation_DLC DropOff;
    local SFXPawn_Player Carrier;
    
    if (Role != ENetRole.ROLE_Authority || !IsTimerActive('CheckForDrop'))
    {
        return;
    }

    // MILAN CHANGE - 11/11/2026 - Mgamerz
    // Keep track of the last place to place the object if the player leaves
    if (PickedUpBy != None && !PickedUpBy.bDeleteMe)
    {
        UpdateLastValidDropLocation(PickedUpBy.Location);
    }
    // END MILAN CHANGE
    Carrier = PickedUpBy;
    RestoreDroppedPickup(LastValidDropLocation);
    ReplicatedPickupObjectInfo.DropLocation = Location;
    ReplicatePickupObjectEvent(1, Carrier);

    DropOff = GetDropOffActor();
    if (DropOff != None)
    {
        DropOff.ObjectDropped(bPlayDownedVO);
    }
}

// MILAN CHANGE - 11/11/2026 - Mgamerz
// Track last OK location to drop
public function UpdateLastValidDropLocation(vector CarrierLocation)
{
    local vector HitLocation;
    local vector HitNormal;
    local vector TraceEnd;

    // Floor trace in the same way as the game does when moving actor to floor, but also cap distance
    TraceEnd = CarrierLocation - vect(0.0, 0.0, 1.0) * MaxCarrierFloorDistance;
    if (Trace(HitLocation, HitNormal, TraceEnd, CarrierLocation, FALSE) != None)
    {
        LastValidDropLocation = HitLocation;
    }
}
// END MILAN CHANGE

public simulated function RestoreDroppedPickup(vector DropLocation)
{
    local SFXSimpleUseModule UseModule;
    local SFXModule_MarkerObjective ObjectiveModule;

    if (PickedUpBy != None)
    {
        UpdatePlayerDroppedObject();
    }
    RemovePickupObject();
    SetLocation(DropLocation);
    ObjectiveModule = GetModule(Class'SFXModule_MarkerObjective');
    ObjectiveModule.Activate();
    SetHidden(FALSE);
    UseModule = GetModule(Class'SFXSimpleUseModule');
    if (UseModule != None)
    {
        UseModule.m_bTargetable = TRUE;
    }
    if (!bLoopStarted)
    {
        bLoopStarted = TRUE;
        PlaySound(DroppedLoopStartSound, TRUE);
    }
}
public final simulated function ObjectDroppedOff()
{
    if (PickedUpBy != None)
    {
        PickedUpBy.PlaySound(HandedInSound, TRUE);
    }
    RemovePickupObject();
    Deactivate();
}
public simulated function OnPickedUp(SFXPawn_Player Player)
{
    local SFXObjective_Retrieve_DropOffLocation_DLC DropOff;
    
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
            CarrierMarker = new (Player) Class'SFXModule_MarkerObjective';
            CarrierMarker.PawnWithExclusiveInvisibility = Player;
            CarrierMarker.MarkerOffset.Z = 90.0;
            CarrierMarker.MarkerIconType = EObjectiveMarkerIconType.EOMIT_None;
            CarrierMarker.MarkerLabel = SrPlayerCarryingObjectiveMarker;
            CarrierMarker.MarkerType = "RetrievePickup";
            Player.AddSFXModule(CarrierMarker);
            CarrierMarker.Activate();
            if (Role == ENetRole.ROLE_Authority)
            {
                ReplicatePickupObjectEvent(0, Player);
                DropOff = GetDropOffActor();
                if (DropOff != None)
                {
                    DropOff.ObjectPickedUp(Player);
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
    local int idx;
    local float fMoveSpeedDecrease;
    
    if (Player == None)
    {
        return;
    }
    if (Role == ENetRole.ROLE_Authority)
    {
        LastValidDropLocation = Location;
        SetHidden(TRUE);
        if (RetrieveWave != None)
        {
            RetrieveWave.DeactivateObjectiveCombatZone(Self);
        }
        PickedUpBy = Player;
        UpdateLastValidDropLocation(Player.Location);
        SetTimer(CheckForDropFrequency, TRUE, 'CheckForDrop', );
    }
    PickedUpTimestamp = WorldInfo.GameTimeSeconds;
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
    // MILAN CHANGE - 11/11/2026 - Mgamerz
    // Instantiate a new mesh on pickup, cause a player who leaves carrying it seems to
    // make it so the backup doesn't appear for the next person who picks it up
    // (but only if the person who picks it up isn't freshly joined after this event... so
    // not replication related)
    CarriedPickupMesh = new (Player) Class'SkeletalMeshComponent'(PickupMeshComp);
    // END MILAN CHANGE
    Player.Mesh.AttachComponentToSocket(CarriedPickupMesh, AttachSocketName);
    Manager = Player.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        fMoveSpeedDecrease = MovementSpeedDecrease;
        if (Player.PlayerClass != None)
        {
            for (idx = 0; idx < MovementSpeedOverrides.Length; idx++)
            {
                if (Player.PlayerClass.IsA(MovementSpeedOverrides[idx].CharacterClass))
                {
                    fMoveSpeedDecrease = MovementSpeedOverrides[idx].MovementSpeedDecrease;
                    break;
                }
            }
        }
        if (fMoveSpeedDecrease < float(0))
        {
            Manager.CreateAndApplyEffect(Class'SFXGameEffect_MovementSpeedBonus', Name, 0.0, 2, fMoveSpeedDecrease, Player.Controller);
        }
    }
    if (Player.bIsStealthed)
    {
        Player.BreakStealth();
    }
    Player.PlaySound(PickupSound, TRUE);
    if (bLoopStarted)
    {
        bLoopStarted = FALSE;
        PlaySound(DroppedLoopStopSound, TRUE);
    }
    HideWeapons();
    SetTimer(0.5, TRUE, 'HideWeapons', );
}
public simulated function RemovePickupObject()
{
    local SFXModule_GameEffectManager Manager;
    local SFXModule_MarkerPlayer PlayerMarkerModule;
    
    ClearTimer('CheckForDrop');
    ClearTimer('HideWeapons');
    if (PickedUpBy == None || PickedUpBy.bDeleteMe)
    {
        CarriedPickupMesh = None;
        CarrierMarker = None;
        PickedUpBy = None;
        return;
    }
    Manager = PickedUpBy.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        Manager.RemoveEffectsByTypeAndCategory(Class'SFXGameEffect_MovementSpeedBonus', Name);
    }
    if (CarrierMarker != None)
    {
        CarrierMarker.Deactivate();
        PickedUpBy.RemoveSFXModule(CarrierMarker);
        CarrierMarker = None;
    }
    if (PickedUpBy.GetModule(Class'SFXModule_MarkerPlayer') == None)
    {
        PlayerMarkerModule = new (PickedUpBy) Class'SFXModule_MarkerPlayer';
        PickedUpBy.AddSFXModule(PlayerMarkerModule);
    }
    ShowWeapons(TRUE);
    if (PickedUpBy.Mesh != None && CarriedPickupMesh != None)
    {
        PickedUpBy.Mesh.DetachComponent(CarriedPickupMesh);
    }
    CarriedPickupMesh = None;
    PickedUpBy = None;
}
public function ReplicatePickupObjectEvent(EPickupObjectEventDLC EPOEvent, SFXPawn_Player PickupPawn)
{
    ReplicatedPickupObjectInfo.EPOEvent = EPOEvent;
    ReplicatedPickupObjectInfo.PickedUpBy = PickupPawn;
    ReplicatedPickupObjectInfo.Trigger++;
}
public simulated function CheckForDrop()
{
    local BioCustomAction oCustomAction;
    local int idx;
    local bool bDropObject;
    
    if (Role != ENetRole.ROLE_Authority)
    {
        return;
    }
    if (PickedUpBy == None || PickedUpBy.bDeleteMe)
    {
        DropObject(FALSE);
        return;
    }
    if (PickedUpBy.bStorming)
    {
        bDropObject = TRUE;
    }
    else if (PickedUpBy.bIsStealthed && WorldInfo.GameTimeSeconds - PickedUpTimestamp > IgnoreStealthFlagTime)
    {
        bDropObject = TRUE;
    }
    else if (PickedUpBy.GetCurrentCustomAction(oCustomAction) && oCustomAction != None)
    {
        for (idx = 0; idx < DropObjectCustomActions.Length; idx++)
        {
            if (oCustomAction.IsA(DropObjectCustomActions[idx]))
            {
                bDropObject = TRUE;
                break;
            }
        }
    }
    if (bDropObject)
    {
        // MILAN CHANGE - Mgamerz - 2026-10-08
        // Record only the authoritative voluntary drop, before carrier is cleared
        RecordVoluntaryDrop();
        // END MILAN CHANGE
        DropObject(FALSE);
    }
    // MILAN CHANGE - Update tracked location
    else
    {
        UpdateLastValidDropLocation(PickedUpBy.Location);
    }
    // END MILAN CHANGE
}
public simulated function SFXObjective_Retrieve_DropOffLocation_DLC GetDropOffActor()
{
    local Actor oActor;
    local SFXObjective_Retrieve_DropOffLocation_DLC DropOff;
    
    if (RetrieveWave != None)
    {
        foreach RetrieveWave.ObjectiveActors(oActor, )
        {
            DropOff = SFXObjective_Retrieve_DropOffLocation_DLC(oActor);
            if (DropOff != None)
            {
                return DropOff;
            }
        }
    }
    return None;
}
public simulated function ShowWeapons(bool bShow)
{
    local SFXInventoryManager InventoryManager;
    local SFXWeapon ChkWeapon;
    
    if (PickedUpBy != None)
    {
        InventoryManager = SFXInventoryManager(PickedUpBy.InvManager);
        foreach InventoryManager.InventoryActors(Class'SFXWeapon', ChkWeapon)
        {
            if (!ChkWeapon.IsActiveWeapon())
            {
                ChkWeapon.SetWeaponHidden(!bShow);
            }
            else
            {
                ChkWeapon.SetWeaponHidden(FALSE);
            }
        }
    }
}
public simulated function UpdatePlayerDroppedObject()
{
    if (RetrieveWave != None)
    {
        RetrieveWave.PlayerDroppedObject(PickedUpBy);
    }
    else
    {
        SetTimer(0.100000001, FALSE, 'UpdatePlayerDroppedObject', );
    }
}
public simulated function ActivateObjective()
{
    local SFXSimpleUseModule UseModule;
    local SFXObjective_Retrieve_DropOffLocation_DLC DropOff;
    local int Index;
    local SFXOperation_ObjectiveMeshInfo MeshInfo;
    
    Super.ActivateObjective();
    SetHidden(FALSE);
    UseModule = GetModule(Class'SFXSimpleUseModule');
    if (UseModule != None)
    {
        UseModule.m_bTargetable = TRUE;
    }
    if (Role == ENetRole.ROLE_Authority && ObjectiveData != None && ObjectiveData.MeshAssets.Length != 0)
    {
        DropOff = GetDropOffActor();
        if (DropOff != None && DropOff.SimpleDialogPlayer != None)
        {
            Index = ObjectiveData.MeshAssets.Find('UniqueString', ObjectiveData.ChosenMeshUniqueString);
            if (Index != -1)
            {
                MeshInfo = ObjectiveData.MeshAssets[Index];
                if (MeshInfo.MeshVOLine != -1)
                {
                    DropOff.SimpleDialogPlayer.PlayVOEventLine('CustomMissionIntro', MeshInfo.MeshVOLine);
                    DropOff.SetTimer(WaveInstructionVODelay, FALSE, 'PlayWaveInstructionsVO', );
                }
            }
        }
    }
}
public simulated function SetOwningWave(SFXWave_Operation NewOwner)
{
    Super.SetOwningWave(NewOwner);
    RetrieveWave = SFXEngagement_Retrieve_DLC_Base(NewOwner);
}
public simulated function ClientPickupObjectEvent()
{
    if (RetrieveWave != None)
    {
        // MILAN CHANGE - Mgamerz - 2026-10-12
        // Compare event ordinals to avoid ambiguous enum identities during cross-game relinking.
        // EPO_PickedUp=0, EPO_Dropped=1, EPO_Retrieved=2; keep in sync with the enum.
        // What a pain this was... bioware, why
        // END MILAN CHANGE
        switch (ReplicatedPickupObjectInfo.EPOEvent)
        {
            case EPickupObjectEventDLC.EPO_PickedUp:
                PickedUpBy = ReplicatedPickupObjectInfo.PickedUpBy;
                OnPickedUp(PickedUpBy);
                SetHidden(TRUE);
                break;
            case EPickupObjectEventDLC.EPO_Dropped:
                RestoreDroppedPickup(ReplicatedPickupObjectInfo.DropLocation);
                break;
            case EPickupObjectEventDLC.EPO_Retrieved:
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

replication
{
    if (bNetDirty && Role == ENetRole.ROLE_Authority)
        ReplicatedPickupObjectInfo;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=StaticMeshComponent Name=MeshComp0
        ReplacementPrimitive = None
        LightEnvironment = MyLightEnvironment
    End Template
    Begin Template Class=DynamicLightEnvironmentComponent Name=MyLightEnvironment
    End Template
    Begin Object Class=SFXModule_MarkerObjective Name=ObjectiveModule0
        MarkerOffset = {X = 0.0, Y = 0.0, Z = 100.0}
    End Object
    Begin Object Class=SkeletalMeshComponent Name=PickupMeshComp0
        SkeletalMesh = SkeletalMesh'BIOG_MP_BACKPACK_01_CON_MP2.Backpack01_MDL'
        ReplacementPrimitive = None
        LightEnvironment = MyLightEnvironment
    End Object
    Begin Object Class=SFXSimpleUseModule Name=SelMod01
        OnUsed = class'SFXObjective_Retrieve_PickupObject_DLC'.Used
        fUseRange = 325.0
        m_TargetOffset = {X = 0.0, Y = 0.0, Z = 25.0}
        m_bTargetable = TRUE
        bIgnoreFacing = TRUE
    End Object
    MovementSpeedOverrides = ({CharacterClass = 'SFXCharacterClassMP_Sentinel_Krogan', MovementSpeedDecrease = 0.0}, 
                              {CharacterClass = 'SFXCharacterClassMP_Soldier_Krogan', MovementSpeedDecrease = 0.0}, 
                              {CharacterClass = 'SFXCharacterClassMP_Vanguard_Krogan', MovementSpeedDecrease = 0.0}, 
                              {CharacterClass = 'SFXCharacterClassMP_Sentinel_Batarian', MovementSpeedDecrease = -0.100000001}, 
                              {CharacterClass = 'SFXCharacterClassMP_Soldier_Batarian', MovementSpeedDecrease = -0.100000001}, 
                              {CharacterClass = 'SFXCharacterClassMP_Sentinel_Turian', MovementSpeedDecrease = -0.150000006}, 
                              {CharacterClass = 'SFXCharacterClassMP_Soldier_Turian', MovementSpeedDecrease = -0.150000006}, 
                              {CharacterClass = 'SFXCharacterClassMP_Adept_Drell', MovementSpeedDecrease = -0.349999994}, 
                              {CharacterClass = 'SFXCharacterClassMP_Vanguard_Drell', MovementSpeedDecrease = -0.349999994}, 
                              {CharacterClass = 'SFXCharacterClassMP_Sentinel_Vorcha', MovementSpeedDecrease = -0.349999994}, 
                              {CharacterClass = 'SFXCharacterClassMP_Soldier_Vorcha', MovementSpeedDecrease = -0.349999994}
                             )
    DropObjectCustomActions = ('SFXPowerCustomAction_BioticCharge', 'SFXCustomAction_PlayerEvadeBase')
    // MILAN CHANGE - Mgamerz - 2026-10-08
    RapidHoldWindow = 4.0
    StrikeForgiveTime = 8.0
    PickupLockoutLadder = (0.0, 1.5, 2.5, 3.2)
    // END MILAN CHANGE
    AttachSocketName = 'Socket_07'
    PickupMeshComp = PickupMeshComp0
    srPickedUpObject = $597258
    MovementSpeedDecrease = -0.25
    SrPlayerCarryingObjectiveMarker = $641202
    CheckForDropFrequency = 0.25
    MaxCarrierFloorDistance = 256.0
    IgnoreStealthFlagTime = 1.5
    PickupSound = WwiseEvent'Wwise_GUI_DLC_MP2.Play_gui_mp_retrieve_start'
    HandedInSound = WwiseEvent'Wwise_GUI_DLC_MP2.Play_gui_mp_retrieve_success'
    DroppedLoopStartSound = WwiseEvent'Wwise_GUI_DLC_MP2.Play_gui_mp_retrieve_item_dropped'
    DroppedLoopStopSound = WwiseEvent'Wwise_GUI_DLC_MP2.Play_gui_mp_retrieve_pickup_dropped_item'
    OwnerWaveClassName = 'SFXEngagement_Retrieve_DLC_Base'
    WaveInstructionVODelay = 4.0
    Mesh = MeshComp0
    LightEnvironment = MyLightEnvironment
    bEnableCombatZone = TRUE
    Components = (None, MyLightEnvironment, MeshComp0)
    Modules = (SelMod01, ObjectiveModule0)
    bAlwaysRelevant = TRUE
    bOnlyDirtyReplication = TRUE
    RemoteRole = ENetRole.ROLE_SimulatedProxy
}
