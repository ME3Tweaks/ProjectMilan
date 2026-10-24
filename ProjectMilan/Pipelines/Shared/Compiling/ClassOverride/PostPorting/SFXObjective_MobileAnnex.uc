// MILAN CHANGE 10/22/2026 - Mgamerz
// Check the SFXGameInfoMP for NavBlocks. If NavBlocks are active we should suppress failing 
// objective until they are removed. This is specifically for MPRctr2's door closures blocking
// navigation
Class SFXObjective_MobileAnnex extends SFXOperationObjective
    placeable
    config(Game);

struct InvalidMapPoint 
{
    var string MapName;
    var array<string> InvalidSpawnPoints;
};
struct MobileAnnexPlayerInfo 
{
    var SFXPawn_Player Player;
    var float LastTimeGotReminder;
    var bool bInProximity;
    var bool bGotReminder;
};
struct SpawnPointInfo 
{
    var SFXOperation_ObjectiveSpawnPoint SpawnPoint;
    var float Distance;
};

var config array<string> DestinationSpawnPoints;
var array<MobileAnnexPlayerInfo> PlayerInfos;
var config array<InvalidMapPoint> InvalidMapPoints;
var repnotify SFXPawn_MobileAnnex AnnexPawn;
var repnotify SFXMobileAnnexDestination AnnexDestination;
var config float UpdateFrequency;
var config float ProximityRadius;
var config float ArrivedDistance;
var config float OmniToolDuration;
var config float ScoreboardDelay;
var repnotify float StartingDistance;
var float ObjectiveProgress;
var SFXEngagement_MobileAnnex_Base MobileAnnexWave;
var config float InstructionReminderFrequency;
var config float LastReminderTime;
var config float AlmostTherePoint;
var config float OutOfRangeWarningDelay;
var float PawnHeight;
var config float SpawnPositionZOffset;
var config float NavPointSearchRange;
var config float ScoreUpdateInterval;
var float ObjectiveProgressAtLastScore;
var config stringref srProgressTicker;
var config stringref srProgressTickerPlural;
var bool bPawnArrived;
var bool bHalfWayVOPlayed;
var bool bAlmostThereVOPlayed;

public event simulated function Destroyed()
{
    ClearTimer('UpdateAnnex');
    ClearTimer('RewardScore');
    ClearTimer('PlayInstructionReminderVO');
    if (AnnexPawn != None)
    {
        AnnexPawn.Destroy();
    }
    if (AnnexDestination != None)
    {
        AnnexDestination.Destroy();
    }
    Super.Destroyed();
}
public simulated function PostBeginPlay()
{
    local SFXModule_MarkerObjective ObjectiveModule;
    
    Super.PostBeginPlay();
    ObjectiveModule = GetModule(Class'SFXModule_MarkerObjective');
    ObjectiveModule.MarkerType = "MobileAnnex";
    SetTimer(UpdateFrequency, TRUE, 'UpdateAnnex', );
    SetTimer(ScoreUpdateInterval, TRUE, 'RewardScore', );
    SetTimer(ScoreboardDelay, FALSE, 'ShowScoreboard', );
    if (Role == ENetRole.ROLE_Authority)
    {
        SetTimer(2.0, FALSE, 'PlayWaveInstructionsVO', );
        SetTimer(InstructionReminderFrequency, TRUE, 'PlayInstructionReminderVO', );
        SetTimer(LastReminderTime, FALSE, 'PlayAlmostOutOfTimeVO', );
    }
}
public simulated function ReplicatedEvent(Name VarName)
{
    if (VarName == 'AnnexPawn' && AnnexPawn != None)
    {
        PawnSpawned();
    }
    Super.ReplicatedEvent(VarName);
}
public simulated function PawnSpawned()
{
    local SFXSimpleUseModule UseModule;
    local SFXModule_MarkerObjective ObjectiveModule;
    
    UseModule = GetModule(Class'SFXSimpleUseModule');
    if (UseModule != None)
    {
        UseModule.m_bTargetable = FALSE;
    }
    ObjectiveModule = GetModule(Class'SFXModule_MarkerObjective');
    if (ObjectiveModule != None)
    {
        ObjectiveModule.Deactivate();
    }
    Mesh.SetHidden(TRUE);
}
public function Used(Actor User)
{
    local SFXPawn_Player Player;
    local SFXAI_MobileAnnex AnnexAI;
    local Vector vDestination;
    local NavigationPoint N;
    local NavigationPoint BestNav;
    local float Distance;
    local float BestDistance;

    if (Role != ENetRole.ROLE_Authority)
    {
        return;
    }
    if (AnnexPawn != None)
    {
        return;
    }
    Player = SFXPawn_Player(User);
    if (Player == None)
    {
        return;
    }
    vDestination = location;
    vDestination.Z += SpawnPositionZOffset;
    AnnexPawn = Spawn(Class'SFXPawn_MobileAnnex', Self, 'MobileAnnexPawn', vDestination, Rotation, , TRUE, FALSE);
    if (AnnexPawn == None)
    {
        if (MobileAnnexWave != None)
        {
            MobileAnnexWave.DelayedFinishWave();
        }
        return;
    }
    AnnexPawn.Objective = Self;
    foreach WorldInfo.RadiusNavigationPoints(Class'NavigationPoint', N, vDestination, NavPointSearchRange)
    {
        if (N != None && N.IsUsableAnchorFor(AnnexPawn))
        {
            Distance = VSize(N.location - vDestination);
            if (BestNav == None || Distance < BestDistance)
            {
                BestDistance = Distance;
                BestNav = N;
            }
        }
    }
    if (BestNav == None)
    {
        if (MobileAnnexWave != None)
        {
            MobileAnnexWave.DelayedFinishWave();
        }
        return;
    }
    vDestination = BestNav.location;
    vDestination.Z = BestNav.location.Z - BestNav.CylinderComponent.CollisionHeight + PawnHeight;
    AnnexPawn.SetLocation(vDestination, );
    AnnexAI = Spawn(Class'SFXAI_MobileAnnex', , , AnnexPawn.location, Rotation, None, TRUE);
    if (AnnexAI == None)
    {
        if (MobileAnnexWave != None)
        {
            MobileAnnexWave.DelayedFinishWave();
        }
        return;
    }
    AnnexAI.Possess(AnnexPawn, FALSE);
    AnnexAI.SetTeam(0);
    // MILAN CHANGE - Mgamerz - 10/22/2026
    // While nav points are temporarily blocked, a destination can be unreachable temporarily,
    // so stall the actual navigation start
    if (PathsTemporarilyBlocked())
    {
        ClearTimer('PlayInstructionReminderVO');
        PawnSpawned();
        SetTimer(1.0, TRUE, 'RetryChooseDestination');
        return;
    }
    if (!ChooseDestination() && MobileAnnexWave != None)
    {
        MobileAnnexWave.DelayedFinishWave();
    }
    // END MILAN CHANGE
}

// MILAN CHANGE - Mgamerz - 10/22/2026
// Add methods for handling pathing being blocked
public function bool PathsTemporarilyBlocked()
{
    local SFXGameInfoMP Game;

    Game = SFXGameInfoMP(WorldInfo.Game);
    return Game != None && Game.HasTemporaryNavBlocks();
}
public function RetryChooseDestination()
{
    if (AnnexPawn == None || AnnexDestination != None)
    {
        ClearTimer('RetryChooseDestination');
        return;
    }
    if (PathsTemporarilyBlocked())
    {
        return;
    }
    ClearTimer('RetryChooseDestination');
    if (!ChooseDestination() && MobileAnnexWave != None)
    {
        MobileAnnexWave.DelayedFinishWave();
    }
}

// Original destination code but now returns bool instead of an immediate failure
public function bool ChooseDestination()
{
    local SFXAI_MobileAnnex AnnexAI;
    local SFXOperation_ObjectiveSpawnPoint Furthest;
    local Vector vDestination;
    local Actor PathResult;
    local SFXWaveCoordinator_HordeOperation WaveCoordinator;
    local SFXOperation_ObjectiveSpawnPoint SpawnPoint;
    local int idx;
    local int Idx2;
    local array<SpawnPointInfo> sortedList;
    local bool bAdded;
    local SpawnPointInfo Info;
    local InvalidMapPoint MapInfo;
    local string CurrentMap;
    local bool bInvalidSpawnPoint;

    if (AnnexPawn == None)
    {
        return FALSE;
    }
    AnnexAI = SFXAI_MobileAnnex(AnnexPawn.Controller);
    if (AnnexAI == None)
    {
        return FALSE;
    }
    CurrentMap = WorldInfo.GetMapName();
    for (idx = 0; idx < InvalidMapPoints.Length; idx++)
    {
        if (Caps(InvalidMapPoints[idx].MapName) == Caps(CurrentMap))
        {
            MapInfo = InvalidMapPoints[idx];
            break;
        }
    }
    WaveCoordinator = SFXWaveCoordinator_HordeOperation(SFXGRI(WorldInfo.GRI).WaveCoordinator);
    foreach WaveCoordinator.OperationManager.ObjectiveSpawnPoints(SpawnPoint, )
    {
        if (SpawnPoint.SpawnLocation != EObjectiveLocation.EObjectiveLocation_Floor)
        {
            continue;
        }
        bInvalidSpawnPoint = FALSE;
        for (idx = 0; idx < MapInfo.InvalidSpawnPoints.Length; idx++)
        {
            if (Caps(MapInfo.InvalidSpawnPoints[idx]) == Caps(string(SpawnPoint.Name)))
            {
                bInvalidSpawnPoint = TRUE;
                break;
            }
        }
        if (bInvalidSpawnPoint)
        {
            continue;
        }
        for (idx = 0; idx < SpawnPoint.SupportedSpawnTags.Length; idx++)
        {
            if (DestinationSpawnPoints.Find(SpawnPoint.SupportedSpawnTags[idx]) != -1)
            {
                bAdded = FALSE;
                Info.SpawnPoint = SpawnPoint;
                Info.Distance = VSizeSq(SpawnPoint.location - AnnexPawn.location);
                for (Idx2 = 0; Idx2 < sortedList.Length; Idx2++)
                {
                    if (Info.Distance < sortedList[Idx2].Distance)
                    {
                        sortedList.InsertItem(Idx2, Info);
                        bAdded = TRUE;
                        break;
                    }
                }
                if (!bAdded)
                {
                    sortedList.AddItem(Info);
                }
                break;
            }
        }
    }
    for (idx = sortedList.Length - 1; idx >= 0; idx--)
    {
        if (Class'Goal_AtActor'.static.AtActor(AnnexPawn, sortedList[idx].SpawnPoint, 300.0, FALSE))
        {
            Class'Path_TowardGoal'.static.TowardGoal(AnnexPawn, sortedList[idx].SpawnPoint);
            PathResult = AnnexAI.FindPathToward(sortedList[idx].SpawnPoint, , , );
            if (PathResult != None)
            {
                Furthest = sortedList[idx].SpawnPoint;
                break;
            }
        }
    }
    if (Furthest == None)
    {
        return FALSE;
    }
    vDestination = Furthest.location;
    vDestination.Z += SpawnPositionZOffset;
    AnnexDestination = Spawn(Class'SFXMobileAnnexDestination', Self, 'MobileAnnexDestination', vDestination, Rotation, , TRUE, FALSE);
    StartingDistance = VSize(Furthest.location - location);
    AnnexAI.AnnexDestination = AnnexDestination;
    ClearTimer('PlayInstructionReminderVO');
    SetTimer(1.5, FALSE, 'PlayDroneActivated', );
    PawnSpawned();
    return TRUE;
}
// END MILAN CHANGE
public function PlayInstructionReminderVO()
{
    SimpleDialogPlayer.PlayVOEventRandomLine('StartMissionReminder');
}
public simulated function SetOwningWave(SFXWave_Operation NewOwner)
{
    Super.SetOwningWave(NewOwner);
    MobileAnnexWave = SFXEngagement_MobileAnnex_Base(NewOwner);
}
public function AnnexPawnFellOutOfWorld()
{
    if (MobileAnnexWave != None)
    {
        MobileAnnexWave.DelayedFinishWave();
    }
}
public function PlayAlmostOutOfTimeVO()
{
    SimpleDialogPlayer.PlayVOEventRandomLine('AlmostOutOfTime');
}
public function PlayDroneActivated()
{
    SimpleDialogPlayer.PlayVOEventRandomLine('DroneActivated');
}
public function PlayMissionAccomplishedVO()
{
    SimpleDialogPlayer.PlayVOEventRandomLine('MissionAccomplished');
}
public function PlayWaveInstructionsVO()
{
    SimpleDialogPlayer.PlayVOEventRandomLine('EscortMissionIntro');
}
public simulated function RewardScore()
{
    local int nNumPlayersEscorting;
    local SFXGRI GRI;
    local SFXScoreManager ScoreManager;
    local float fScore;
    local SFXMPEventTicker EventTicker;
    local int idx;
    
    if (AnnexPawn == None || AnnexDestination == None)
    {
        return;
    }
    if (ObjectiveProgress - ObjectiveProgressAtLastScore <= float(0))
    {
        return;
    }
    for (idx = 0; idx < PlayerInfos.Length; idx++)
    {
        if (PlayerInfos[idx].bInProximity)
        {
            nNumPlayersEscorting++;
        }
    }
    GRI = SFXGRI(WorldInfo.GRI);
    if (GRI != None)
    {
        ScoreManager = GRI.GetScoreManager();
        if (ScoreManager != None)
        {
            for (idx = 0; idx < PlayerInfos.Length; idx++)
            {
                if (PlayerInfos[idx].bInProximity)
                {
                    fScore += ScoreManager.AddScore(PlayerInfos[idx].Player, (ObjectiveProgress - ObjectiveProgressAtLastScore) * OwnerWave.OperationScoreReward / float(nNumPlayersEscorting), 2);
                }
            }
            EventTicker = GRI.GetEventTicker();
            if (EventTicker != None && fScore > float(0))
            {
                ClearCustomTokens();
                SetCustomToken(0, string(nNumPlayersEscorting));
                SetCustomToken(1, string(int(fScore)));
                if (nNumPlayersEscorting > 1)
                {
                    EventTicker.AddTickerEntry(Class'SFXGame'.static.GetSimpleString(srProgressTickerPlural, TRUE));
                }
                else
                {
                    EventTicker.AddTickerEntry(Class'SFXGame'.static.GetSimpleString(srProgressTicker, TRUE));
                }
                ClearCustomTokens();
            }
        }
    }
    ObjectiveProgressAtLastScore = ObjectiveProgress;
}
public simulated function ShowScoreboard()
{
    SFXPlayerController(GetALocalPlayerController()).SetScoreHudObjectiveProgress(ObjectiveProgress, FALSE);
}
public simulated function UpdateAnnex()
{
    local SFXPawn_Player Player;
    local int nNumPlayersEscorting;
    local float fDist;
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_OmniTool OmniToolEffect;
    local int idx;
    local MobileAnnexPlayerInfo PlayerInfo;
    
    if (AnnexPawn == None || AnnexDestination == None)
    {
        return;
    }
    for (idx = 0; idx < PlayerInfos.Length; idx++)
    {
        PlayerInfos[idx].bInProximity = FALSE;
    }
    foreach WorldInfo.AllPawns(Class'SFXPawn_Player', Player, AnnexPawn.location, ProximityRadius)
    {
        if (!Player.IsDead() && !Player.IsInvisible())
        {
            Manager = Player.GetModule(Class'SFXModule_GameEffectManager');
            if (Manager != None)
            {
                OmniToolEffect = SFXGameEffect_OmniTool(Manager.GetFirstEffectOfTypeAndCategory(Class'SFXGameEffect_OmniTool', Name));
                if (OmniToolEffect != None)
                {
                    OmniToolEffect.CurrentTime = 0.0;
                }
                else
                {
                    Manager.CreateAndApplyEffect(Class'SFXGameEffect_OmniTool', Name, OmniToolDuration, 1, 0.0, Player.Controller);
                }
            }
            nNumPlayersEscorting++;
            idx = PlayerInfos.Find('Player', Player);
            if (idx == -1)
            {
                PlayerInfo.Player = Player;
                PlayerInfos.AddItem(PlayerInfo);
                idx = PlayerInfos.Length - 1;
            }
            PlayerInfos[idx].bGotReminder = FALSE;
            PlayerInfos[idx].LastTimeGotReminder = WorldInfo.GameTimeSeconds;
            PlayerInfos[idx].bInProximity = TRUE;
        }
    }
    if (nNumPlayersEscorting == 0)
    {
        AnnexPawn.SetAnnexSpeed(0.0);
    }
    else
    {
        AnnexPawn.SetAnnexSpeed(float(nNumPlayersEscorting) / float(SFXGRI(WorldInfo.GRI).NumPlayersInGame()));
    }
    fDist = FMax(VSize(AnnexDestination.location - AnnexPawn.location) - ArrivedDistance, 0.0);
    if (StartingDistance > float(0))
    {
        if (1.0 - fDist / (StartingDistance - ArrivedDistance) > ObjectiveProgress)
        {
            ObjectiveProgress = FClamp(1.0 - fDist / (StartingDistance - ArrivedDistance), 0.0, 1.0);
        }
    }
    if (Role == ENetRole.ROLE_Authority)
    {
        for (idx = 0; idx < PlayerInfos.Length; idx++)
        {
            if (PlayerInfos[idx].bInProximity == FALSE)
            {
                if (PlayerInfos[idx].bGotReminder == FALSE && Self.WorldInfo.GameTimeSeconds - PlayerInfos[idx].LastTimeGotReminder > OutOfRangeWarningDelay)
                {
                    PlayerInfos[idx].bGotReminder = TRUE;
                    PlayerInfos[idx].LastTimeGotReminder = WorldInfo.GameTimeSeconds;
                    SimpleDialogPlayer.PlayVOEventRandomLine('PlayerOutOfRange', SFXPlayerController(PlayerInfos[idx].Player.Controller));
                    continue;
                }
                if (Self.WorldInfo.GameTimeSeconds - PlayerInfos[idx].LastTimeGotReminder > InstructionReminderFrequency)
                {
                    PlayerInfos[idx].LastTimeGotReminder = WorldInfo.GameTimeSeconds;
                    SimpleDialogPlayer.PlayVOEventRandomLine('OutOfRangeTooLong', SFXPlayerController(PlayerInfos[idx].Player.Controller));
                }
            }
        }
        if (!bHalfWayVOPlayed && ObjectiveProgress > 0.5)
        {
            bHalfWayVOPlayed = TRUE;
            SimpleDialogPlayer.PlayVOEventRandomLine('HalfWay');
        }
        if (!bAlmostThereVOPlayed && ObjectiveProgress > AlmostTherePoint)
        {
            bAlmostThereVOPlayed = TRUE;
            SimpleDialogPlayer.PlayVOEventRandomLine('AlmostThere');
        }
    }
    SFXPlayerController(GetALocalPlayerController()).SetScoreHudObjectiveProgress(ObjectiveProgress, FALSE);
    if (AnnexDestination != None && !bPawnArrived)
    {
        if (ObjectiveProgress >= 1.0)
        {
            bPawnArrived = TRUE;
            if (AnnexPawn != None)
            {
                AnnexPawn.DoneObjective();
            }
            if (MobileAnnexWave != None)
            {
                MobileAnnexWave.DelayedFinishWave();
                if (Role == ENetRole.ROLE_Authority)
                {
                    SetTimer(1.5, FALSE, 'PlayMissionAccomplishedVO', );
                }
            }
        }
    }
}

replication
{
    if (bNetDirty && Role == ENetRole.ROLE_Authority)
        AnnexPawn, AnnexDestination, StartingDistance;
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
    Begin Object Class=SFXSimpleUseModule Name=SelMod01
        OnUsed = class'SFXObjective_MobileAnnex'.Used
        fUseRange = 325.0
        m_TargetOffset = {X = 0.0, Y = 0.0, Z = 25.0}
        m_bTargetable = TRUE
        bIgnoreFacing = TRUE
    End Object
    Begin Object Class=BioSimpleDialog Name=SimpleDialog0
        DialogLinesMale = ({srText = $747338, pCue = None}, 
                           {srText = $747339, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747339_m_Play'}, 
                           {srText = $747340, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747340_m_Play'}, 
                           {srText = $747341, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747341_m_Play'}, 
                           {srText = $747342, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747342_m_Play'}, 
                           {srText = $747343, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747343_m_Play'}, 
                           {srText = $747344, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747344_m_Play'}, 
                           {srText = $747345, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747345_m_Play'}, 
                           {srText = $747346, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747346_m_Play'}, 
                           {srText = $747347, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747347_m_Play'}, 
                           {srText = $747348, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747348_m_Play'}, 
                           {srText = $747349, pCue = None}, 
                           {srText = $747350, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747350_m_Play'}, 
                           {srText = $747351, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747351_m_Play'}, 
                           {srText = $747352, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747352_m_Play'}, 
                           {srText = $747353, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747353_m_Play'}, 
                           {srText = $747354, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747354_m_Play'}, 
                           {srText = $747355, pCue = None}, 
                           {srText = $747356, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747356_m_Play'}, 
                           {srText = $747357, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747357_m_Play'}, 
                           {srText = $747358, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747358_m_Play'}, 
                           {srText = $747359, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747359_m_Play'}, 
                           {srText = $747360, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747360_m_Play'}, 
                           {srText = $747361, pCue = None}, 
                           {srText = $747362, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747362_m_Play'}, 
                           {srText = $747363, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747363_m_Play'}, 
                           {srText = $747364, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747364_m_Play'}, 
                           {srText = $747365, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747365_m_Play'}, 
                           {srText = $747366, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747366_m_Play'}, 
                           {srText = $747367, pCue = None}, 
                           {srText = $747368, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747368_m_Play'}, 
                           {srText = $747369, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747369_m_Play'}, 
                           {srText = $747370, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747370_m_Play'}, 
                           {srText = $747371, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747371_m_Play'}, 
                           {srText = $747372, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747372_m_Play'}, 
                           {srText = $747373, pCue = None}, 
                           {srText = $747374, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747374_m_Play'}, 
                           {srText = $747375, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747375_m_Play'}, 
                           {srText = $747376, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747376_m_Play'}, 
                           {srText = $747377, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747377_m_Play'}, 
                           {srText = $747378, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747378_m_Play'}, 
                           {srText = $747379, pCue = None}, 
                           {srText = $747380, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747380_m_Play'}, 
                           {srText = $747381, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747381_m_Play'}, 
                           {srText = $747382, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747382_m_Play'}, 
                           {srText = $747383, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747383_m_Play'}, 
                           {srText = $747384, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747384_m_Play'}, 
                           {srText = $747385, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747385_m_Play'}, 
                           {srText = $747386, pCue = None}, 
                           {srText = $747387, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747387_m_Play'}, 
                           {srText = $747388, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747388_m_Play'}, 
                           {srText = $747389, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747389_m_Play'}, 
                           {srText = $747390, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747390_m_Play'}, 
                           {srText = $747391, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747391_m_Play'}, 
                           {srText = $747392, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747392_m_Play'}, 
                           {srText = $747393, pCue = None}, 
                           {srText = $747394, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747394_m_Play'}, 
                           {srText = $747395, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747395_m_Play'}, 
                           {srText = $747396, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747396_m_Play'}, 
                           {srText = $747397, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747397_m_Play'}, 
                           {srText = $747398, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747398_m_Play'}, 
                           {srText = $747399, pCue = None}, 
                           {srText = $747400, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747400_m_Play'}, 
                           {srText = $747401, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747401_m_Play'}, 
                           {srText = $747402, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747402_m_Play'}, 
                           {srText = $747403, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747403_m_Play'}, 
                           {srText = $747404, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747404_m_Play'}, 
                           {srText = $747405, pCue = None}, 
                           {srText = $747406, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747406_m_Play'}, 
                           {srText = $747407, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747407_m_Play'}, 
                           {srText = $747408, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747408_m_Play'}, 
                           {srText = $747409, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747409_m_Play'}, 
                           {srText = $747410, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747410_m_Play'}, 
                           {srText = $747411, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747411_m_Play'}, 
                           {srText = $747412, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747412_m_Play'}, 
                           {srText = $747413, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747413_m_Play'}, 
                           {srText = $747414, pCue = None}, 
                           {srText = $747415, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747415_m_Play'}, 
                           {srText = $747416, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747416_m_Play'}, 
                           {srText = $747417, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747417_m_Play'}, 
                           {srText = $747418, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747418_m_Play'}, 
                           {srText = $747419, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747419_m_Play'}, 
                           {srText = $747420, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747420_m_Play'}, 
                           {srText = $747421, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747421_m_Play'}, 
                           {srText = $747422, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747422_m_Play'}, 
                           {srText = $747423, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747423_m_Play'}, 
                           {srText = $747424, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747424_m_Play'}, 
                           {srText = $747425, pCue = None}, 
                           {srText = $747426, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747426_m_Play'}, 
                           {srText = $747427, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747427_m_Play'}, 
                           {srText = $747428, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747428_m_Play'}, 
                           {srText = $747429, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747429_m_Play'}, 
                           {srText = $747430, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747430_m_Play'}, 
                           {srText = $747431, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747431_m_Play'}, 
                           {srText = $747432, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747432_m_Play'}, 
                           {srText = $747433, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747433_m_Play'}, 
                           {srText = $747434, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747434_m_Play'}, 
                           {srText = $747435, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747435_m_Play'}
                          )
        DialogLinesFemale = ({srText = $747338, pCue = None}, 
                             {srText = $747339, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747339_f_Play'}, 
                             {srText = $747340, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747340_f_Play'}, 
                             {srText = $747341, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747341_f_Play'}, 
                             {srText = $747342, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747342_f_Play'}, 
                             {srText = $747343, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747343_f_Play'}, 
                             {srText = $747344, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747344_f_Play'}, 
                             {srText = $747345, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747345_f_Play'}, 
                             {srText = $747346, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747346_f_Play'}, 
                             {srText = $747347, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747347_f_Play'}, 
                             {srText = $747348, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747348_f_Play'}, 
                             {srText = $747349, pCue = None}, 
                             {srText = $747350, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747350_f_Play'}, 
                             {srText = $747351, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747351_f_Play'}, 
                             {srText = $747352, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747352_f_Play'}, 
                             {srText = $747353, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747353_f_Play'}, 
                             {srText = $747354, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747354_f_Play'}, 
                             {srText = $747355, pCue = None}, 
                             {srText = $747356, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747356_f_Play'}, 
                             {srText = $747357, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747357_f_Play'}, 
                             {srText = $747358, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747358_f_Play'}, 
                             {srText = $747359, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747359_f_Play'}, 
                             {srText = $747360, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747360_f_Play'}, 
                             {srText = $747361, pCue = None}, 
                             {srText = $747362, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747362_f_Play'}, 
                             {srText = $747363, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747363_f_Play'}, 
                             {srText = $747364, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747364_f_Play'}, 
                             {srText = $747365, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747365_f_Play'}, 
                             {srText = $747366, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747366_f_Play'}, 
                             {srText = $747367, pCue = None}, 
                             {srText = $747368, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747368_f_Play'}, 
                             {srText = $747369, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747369_f_Play'}, 
                             {srText = $747370, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747370_f_Play'}, 
                             {srText = $747371, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747371_f_Play'}, 
                             {srText = $747372, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747372_f_Play'}, 
                             {srText = $747373, pCue = None}, 
                             {srText = $747374, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747374_f_Play'}, 
                             {srText = $747375, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747375_f_Play'}, 
                             {srText = $747376, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747376_f_Play'}, 
                             {srText = $747377, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747377_f_Play'}, 
                             {srText = $747378, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747378_f_Play'}, 
                             {srText = $747379, pCue = None}, 
                             {srText = $747380, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747380_f_Play'}, 
                             {srText = $747381, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747381_f_Play'}, 
                             {srText = $747382, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747382_f_Play'}, 
                             {srText = $747383, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747383_f_Play'}, 
                             {srText = $747384, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747384_f_Play'}, 
                             {srText = $747385, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747385_f_Play'}, 
                             {srText = $747386, pCue = None}, 
                             {srText = $747387, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747387_f_Play'}, 
                             {srText = $747388, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747388_f_Play'}, 
                             {srText = $747389, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747389_f_Play'}, 
                             {srText = $747390, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747390_f_Play'}, 
                             {srText = $747391, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747391_f_Play'}, 
                             {srText = $747392, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747392_f_Play'}, 
                             {srText = $747393, pCue = None}, 
                             {srText = $747394, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747394_f_Play'}, 
                             {srText = $747395, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747395_f_Play'}, 
                             {srText = $747396, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747396_f_Play'}, 
                             {srText = $747397, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747397_f_Play'}, 
                             {srText = $747398, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747398_f_Play'}, 
                             {srText = $747399, pCue = None}, 
                             {srText = $747400, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747400_f_Play'}, 
                             {srText = $747401, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747401_f_Play'}, 
                             {srText = $747402, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747402_f_Play'}, 
                             {srText = $747403, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747403_f_Play'}, 
                             {srText = $747404, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747404_f_Play'}, 
                             {srText = $747405, pCue = None}, 
                             {srText = $747406, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747406_f_Play'}, 
                             {srText = $747407, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747407_f_Play'}, 
                             {srText = $747408, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747408_f_Play'}, 
                             {srText = $747409, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747409_f_Play'}, 
                             {srText = $747410, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747410_f_Play'}, 
                             {srText = $747411, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747411_f_Play'}, 
                             {srText = $747412, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747412_f_Play'}, 
                             {srText = $747413, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747413_f_Play'}, 
                             {srText = $747414, pCue = None}, 
                             {srText = $747415, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747415_f_Play'}, 
                             {srText = $747416, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747416_f_Play'}, 
                             {srText = $747417, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747417_f_Play'}, 
                             {srText = $747418, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747418_f_Play'}, 
                             {srText = $747419, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747419_f_Play'}, 
                             {srText = $747420, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747420_f_Play'}, 
                             {srText = $747421, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747421_f_Play'}, 
                             {srText = $747422, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747422_f_Play'}, 
                             {srText = $747423, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747423_f_Play'}, 
                             {srText = $747424, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747424_f_Play'}, 
                             {srText = $747425, pCue = None}, 
                             {srText = $747426, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747426_f_Play'}, 
                             {srText = $747427, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747427_f_Play'}, 
                             {srText = $747428, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747428_f_Play'}, 
                             {srText = $747429, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747429_f_Play'}, 
                             {srText = $747430, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747430_f_Play'}, 
                             {srText = $747431, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747431_f_Play'}, 
                             {srText = $747432, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747432_f_Play'}, 
                             {srText = $747433, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747433_f_Play'}, 
                             {srText = $747434, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747434_f_Play'}, 
                             {srText = $747435, pCue = WwiseEvent'ss_mp_escort_narr_v1_D.Audio.VO_747435_f_Play'}
                            )
        SimpleVOEvents = ({
                           Lines = ($747339, 
                                    $747340, 
                                    $747341, 
                                    $747342, 
                                    $747343, 
                                    $747344, 
                                    $747345, 
                                    $747346, 
                                    $747347, 
                                    $747348
                                   ), 
                           EventName = 'EscortMissionIntro', 
                           ReplyLine = $747436
                          }, 
                          {
                           Lines = ($747350, $747351, $747352, $747353, $747354), 
                           EventName = 'StartMissionReminder', 
                           ReplyLine = $747437
                          }, 
                          {
                           Lines = ($747356, $747357, $747358, $747359, $747360), 
                           EventName = 'DroneActivated', 
                           ReplyLine = $747438
                          }, 
                          {
                           Lines = ($747362, $747363, $747364, $747365, $747366), 
                           EventName = 'PlayerOutOfRange', 
                           ReplyLine = $747439
                          }, 
                          {
                           Lines = ($747368, $747369, $747370, $747371, $747372), 
                           EventName = 'OutOfRangeTooLong', 
                           ReplyLine = $747440
                          }, 
                          {
                           Lines = ($747374, $747375, $747376, $747377, $747378), 
                           EventName = 'HalfWay', 
                           ReplyLine = $747441
                          }, 
                          {
                           Lines = ($747380, $747381, $747382, $747383, $747384, $747385), 
                           EventName = 'AlmostThere', 
                           ReplyLine = $747442
                          }, 
                          {
                           Lines = ($747387, $747388, $747389, $747390, $747391, $747392), 
                           EventName = 'AlmostOutOfTime', 
                           ReplyLine = $747443
                          }, 
                          {
                           Lines = ($747394, $747395, $747396, $747397, $747398), 
                           EventName = 'MissionAccomplished', 
                           ReplyLine = $747444
                          }
                         )
    End Object
    DestinationSpawnPoints = ("Disarm")
    UpdateFrequency = 0.5
    ProximityRadius = 500.0
    ArrivedDistance = 500.0
    OmniToolDuration = 1.5
    ScoreboardDelay = 1.0
    InstructionReminderFrequency = 25.0
    LastReminderTime = 270.0
    AlmostTherePoint = 0.850000024
    OutOfRangeWarningDelay = 3.0
    PawnHeight = 88.0
    SpawnPositionZOffset = 25.0
    NavPointSearchRange = 300.0
    ScoreUpdateInterval = 5.0
    srProgressTicker = $701601
    srProgressTickerPlural = $701542
    SimpleDialogPlayer = SimpleDialog0
    WaveInstructionVODelay = 4.0
    Mesh = MeshComp0
    LightEnvironment = MyLightEnvironment
    ActivateObjectiveOnSpawn = TRUE
    Components = (None, MyLightEnvironment, MeshComp0)
    Modules = (SelMod01, ObjectiveModule0)
    bAlwaysRelevant = TRUE
    bOnlyDirtyReplication = TRUE
    RemoteRole = ENetRole.ROLE_SimulatedProxy
}
