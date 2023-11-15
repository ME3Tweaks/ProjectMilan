Class SFXOperationObjective extends Actor
    config(Game);

// Types
struct ReplicatedMeshInfoStruct 
{
    var int MeshUniqueID;
    var int ObjectiveTypeID;
};

// Variables
var Name OwnerWaveClassName;
var protectedwrite repnotify ReplicatedMeshInfoStruct ReplicatedMeshInfo;
var Name MeshSpecificVOEvent;
var BioSimpleDialog SimpleDialogPlayer;
var SFXWave_Operation OwnerWave;
var protectedwrite SFXOperation_ObjectiveData ObjectiveData;
var config float WaveInstructionVODelay;
var config float WaveInstructionVORepeatDelay;
var editinline export StaticMeshComponent Mesh;
var const editinline editconst export DynamicLightEnvironmentComponent LightEnvironment;
var config bool ActivateObjectiveOnSpawn;
var repnotify bool bActivated;
var config bool bEnableCombatZone;

// Functions
public event simulated function Destroyed()
{
    Deactivate();
    Super.Destroyed();
}
public simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    if (ActivateObjectiveOnSpawn)
    {
        if (Role == ENetRole.ROLE_Authority)
        {
            ActivateObjective();
        }
    }
    else
    {
        Deactivate();
    }
    if (Role != ENetRole.ROLE_Authority)
    {
        SetTimer(0.100000001, TRUE, 'FindOwningWave', );
        FindOwningWave();
    }
    if (Role == ENetRole.ROLE_Authority)
    {
        SimpleDialogPlayer.PlayVOEventRandomLine('MissionIntro');
        SetTimer(WaveInstructionVODelay, FALSE, 'PlayWaveInstructions', );
    }
    if (WaveInstructionVORepeatDelay > 0.0)
    {
        SetTimer(WaveInstructionVORepeatDelay, TRUE, 'RepeatWaveInstructions', );
    }
}
public event simulated function ReplicatedEvent(Name VarName)
{
    Super.ReplicatedEvent(VarName);
    if (VarName == 'bActivated')
    {
        if (bActivated)
        {
            ActivateObjective();
        }
        else
        {
            Deactivate();
        }
    }
    else if (VarName == 'ReplicatedMeshInfo')
    {
        ClientFindObjectiveData();
    }
}
public simulated function Deactivate()
{
    local SFXModule_MarkerObjective ObjectiveModule;
    
    bActivated = FALSE;
    ObjectiveModule = GetModule(Class'SFXModule_MarkerObjective');
    if (ObjectiveModule != None)
    {
        ObjectiveModule.Deactivate();
    }
    if (bEnableCombatZone && OwnerWave != None)
    {
        OwnerWave.DeactivateObjectiveCombatZone(Self);
    }
}
public simulated function PawnDowned(BioPawn Pawn);

public simulated function PawnRevived(BioPawn Pawn);

private final simulated function ActivateCombatZone()
{
    if (OwnerWave != None)
    {
        OwnerWave.ActivateObjectiveCombatZone(Self);
        ClearTimer('ActivateCombatZone');
    }
}
public simulated function ActivateObjective()
{
    local SFXModule_MarkerObjective ObjectiveModule;
    
    bActivated = TRUE;
    ObjectiveModule = GetModule(Class'SFXModule_MarkerObjective');
    if (ObjectiveModule != None)
    {
        ObjectiveModule.Activate();
    }
    BioPlayerController(WorldInfo.GetALocalPlayerController()).HintSystem.HintEvent('ObjectiveActivated');
    if (bEnableCombatZone)
    {
        SetTimer(0.100000001, TRUE, 'ActivateCombatZone', );
    }
}
public final simulated function ClientFindObjectiveData()
{
    local SFXWaveCoordinator_HordeOperation WaveCoordinator;
    local SFXOperation_ObjectiveData ObjDataIter;
    local string ObjectiveTypeStr;
    
    WaveCoordinator = SFXWaveCoordinator_HordeOperation(SFXGRI(WorldInfo.GRI).WaveCoordinator);
    if ((WaveCoordinator == None || WaveCoordinator.OperationManager == None) || WaveCoordinator.OperationManager.bSuccessfullyGeneratedWaveList == FALSE)
    {
        SetTimer(0.100000001, FALSE, 'ClientFindObjectiveData', );
        return;
    }
    ObjectiveTypeStr = Class'SFXEngine'.static.GetStrFromSFXUniqueID(ReplicatedMeshInfo.ObjectiveTypeID);
    foreach WaveCoordinator.OperationManager.ObjectiveData(ObjDataIter, )
    {
        if (ObjDataIter.ObjectiveType == ObjectiveTypeStr)
        {
            ObjectiveData = ObjDataIter;
            ObjectiveData.ChosenMeshUniqueString = Class'SFXEngine'.static.GetStrFromSFXUniqueID(ReplicatedMeshInfo.MeshUniqueID);
            break;
        }
    }
    SetObjectiveMesh(ObjectiveData.ChosenMeshUniqueString, Mesh);
}
public final simulated function FindOwningWave()
{
    local SFXWave_Operation Wave;
    
    Wave = SFXWave_Operation(SFXGRI(WorldInfo.GRI).WaveCoordinator.GetWaveOfType(OwnerWaveClassName));
    if (Wave != None)
    {
        SetOwningWave(Wave);
        ClearTimer('FindOwningWave');
    }
}
public final function PlayMeshSpecificVOLine()
{
    local int Index;
    local SFXOperation_ObjectiveMeshInfo MeshInfo;
    
    if ((ObjectiveData == None || ObjectiveData.MeshAssets.Length == 0) || SimpleDialogPlayer == None)
    {
        return;
    }
    Index = ObjectiveData.MeshAssets.Find('UniqueString', ObjectiveData.ChosenMeshUniqueString);
    if (Index != -1)
    {
        MeshInfo = ObjectiveData.MeshAssets[Index];
        if (MeshInfo.MeshVOLine != -1)
        {
            SimpleDialogPlayer.PlayVOEventLine(MeshSpecificVOEvent, MeshInfo.MeshVOLine);
        }
    }
}
public final function PlayPlayerAcknowledgment(optional float DelayTime = 3.0, optional bool PlayObjectiveBegin = FALSE)
{
    local SFXGRI GRI;
    local SFXWaveCoordinator_HordeOperation WaveCoordinator;
    
    if (Role == ENetRole.ROLE_Authority)
    {
        GRI = SFXGRI(WorldInfo.GRI);
        if (GRI != None)
        {
            WaveCoordinator = SFXWaveCoordinator_HordeOperation(GRI.WaveCoordinator);
            if (WaveCoordinator != None)
            {
                WaveCoordinator.PlayPlayerAcknowledgment(DelayTime, PlayObjectiveBegin);
            }
        }
    }
}
public function PlayWaveInstructions()
{
    if (SimpleDialogPlayer != None)
    {
        SimpleDialogPlayer.PlayVOEventRandomLine('WaveStartedInstructions');
        PlayPlayerAcknowledgment(SimpleDialogPlayer.LastEventDuration + 0.5, TRUE);
    }
}
public simulated function RepeatWaveInstructions()
{
    if (SimpleDialogPlayer != None)
    {
        SimpleDialogPlayer.PlayVOEventRandomLine('WaveStartedInstructions', SFXPlayerController(GetALocalPlayerController()));
        PlayPlayerAcknowledgment(SimpleDialogPlayer.LastEventDuration + 0.5, TRUE);
    }
}
public function SetObjectiveData(SFXOperation_ObjectiveData ObjData)
{
    if (ObjData != None)
    {
        ObjectiveData = ObjData;
        if (Role == ENetRole.ROLE_Authority)
        {
            ReplicatedMeshInfo.MeshUniqueID = Class'SFXEngine'.static.GetSFXUniqueIDFromStr(ObjectiveData.ChosenMeshUniqueString);
            ReplicatedMeshInfo.ObjectiveTypeID = Class'SFXEngine'.static.GetSFXUniqueIDFromStr(ObjectiveData.ObjectiveType);
            SetObjectiveMesh(ObjectiveData.ChosenMeshUniqueString, Mesh);
        }
    }
}
public final simulated function SetObjectiveMesh(string MeshIdentifier, StaticMeshComponent MeshComp)
{
    local StaticMesh oMesh;
    local SFXOperation_ObjectiveMeshInfo MeshInfo;
    local int Index;
    local SFXSimpleUseModule SelMod;
    local SFXModule_MarkerObjective ObjectiveModule;
    
    if (ObjectiveData == None || ObjectiveData.MeshAssets.Length == 0)
    {
        return;
    }
    Index = ObjectiveData.MeshAssets.Find('UniqueString', MeshIdentifier);
    if (Index != -1)
    {
        MeshInfo = ObjectiveData.MeshAssets[Index];
        oMesh = StaticMesh(FindObject(MeshInfo.MeshPath, Class'StaticMesh'));
        if (oMesh == None)
        {
            if (Role != ENetRole.ROLE_Authority)
            {
                SetTimer(0.100000001, FALSE, 'ClientFindObjectiveData', );
            }
            return;
        }
        MeshComp.SetStaticMesh(oMesh);
        MeshComp.SetTranslation(MeshInfo.Translation);
        MeshComp.SetRotation(MeshInfo.Rotation);
        if (Role != ENetRole.ROLE_Authority)
        {
            ForceUpdateComponents(FALSE, TRUE);
        }
        if (MeshInfo.Scale > float(0))
        {
            MeshComp.SetScale(MeshInfo.Scale);
        }
        if (MeshInfo.GameName != 0)
        {
            SelMod = GetModule(Class'SFXSimpleUseModule');
            if (SelMod != None)
            {
                SelMod.m_srGameName = MeshInfo.GameName;
                SelMod.m_TargetTipText = MeshInfo.TipText;
                SelMod.m_TargetOffset += MeshInfo.Translation;
            }
            ObjectiveModule = GetModule(Class'SFXModule_MarkerObjective');
            if (ObjectiveModule != None)
            {
                ObjectiveModule.MarkerLabel = MeshInfo.GameName;
                ObjectiveModule.MarkerOffset += MeshInfo.Translation;
            }
        }
    }
}
public simulated function SetOwningWave(SFXWave_Operation NewOwner)
{
    OwnerWave = NewOwner;
}

replication
{
    if (bNetDirty && Role == ENetRole.ROLE_Authority)
        ReplicatedMeshInfo, bActivated;
    
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=DynamicLightEnvironmentComponent Name=MyLightEnvironment
        bCastShadows = FALSE
    End Object
    Begin Object Class=StaticMeshComponent Name=MeshComp0
        ReplacementPrimitive = None
        LightEnvironment = MyLightEnvironment
    End Object
    OwnerWaveClassName = 'SFXWave_Operation'
    MeshSpecificVOEvent = 'MissionIntro'
    Mesh = MeshComp0
    LightEnvironment = MyLightEnvironment
    Components = (None, MyLightEnvironment, MeshComp0)
}