// Source: ME3, SFXEngagement_Annex_Hack
// Decompiled 9/7/2024 3:45:38 PM
// MILAN CHANGE 10-19-2026 - Mgamerz
// Prevent annex progress while outside the annex
Class SFXObjective_Annex_DefendZone extends SFXOperationObjective
    placeable
    abstract
    config(Game);

struct PlayerUpdateInfo
{
    var SFXPawn_Player Player;
    var float PlayerUpdateTime;
    var bool bIsEnteringZone;
};
struct PlayerAnnexState
{
    var Guid OmniToolGuid;
    var SFXPawn_Player Player;
    var float NextRemindTime;
    var bool bInAnnexZone;
    var bool bLeftAnnexZone;
};
const NumPlayers = 4;

var array<PlayerAnnexState> PlayerAnnexStates;
var transient array<PlayerUpdateInfo> PlayersToUpdate;
var SFXPawn_Player InAnnexZoneArray[4];
var Name ZoneStartGuiSound;
var Name ZoneFailGuiSound;
var Name ZoneSuccessGuiSound;
var Name ZoneEnterExitGuiSound;
var repnotify float CompletionCount;
var float CompletionCountTimer;
var float CompletionCountFrequency;
var config float CompletionRatePerPlayer;
var RvrClientEffectInterface CE_OmniTool;
var config float ScoreRewardFrequency;
var float ScoreRewardTimer;
var float CompletionAtLastScoreReward;
var float LeaveZoneVOChance;
var float NotInZoneVOMinTime;
var float NotInZoneVOMaxTime;
var WwiseEvent HackStartSound;
var WwiseEvent HackStopSound;
var WwiseEvent AnnexStartedSound;
var WwiseEvent AnnexSucceededSound;
var WwiseEvent AnnexFailedSound;
var SFXEngagement_Annex AnnexWave;
var repnotify SFXAnnexZone AnnexZone;
var int PlayersInZone;
var config float PlayerUpdateDelayTime;
var repnotify bool bIsComplete;
var bool bHalfWayMessageSent;

public event simulated function Destroyed()
{
    local int idx;

    for (idx = PlayerAnnexStates.Length - 1; idx >= 0; idx--)
    {
        PlayerExitedAnnex(PlayerAnnexStates[idx].Player);
    }
    PlayerAnnexStates.Length = 0;
    for (idx = 0; idx < 4; idx++)
    {
        InAnnexZoneArray[idx] = None;
    }
    AnnexWave.PlayersInAnnexZone.Length = 0;
    ClearTimer('UpdateAnnexZone');
    if (AnnexZone != None)
    {
        AnnexZone.Destroy();
    }
    Super.Destroyed();
}
public simulated function PostBeginPlay()
{
    local SFXModule_MarkerObjective ObjectiveModule;

    ObjectiveModule = GetModule(Class'SFXModule_MarkerObjective');
    ObjectiveModule.MarkerType = "Annex_DefendZone";
    CompletionCount = 0.0;
    CompletionCountTimer = 0.0;
    SetTimer(1.5, FALSE, 'UpdateObjectiveStatus', );
    Super.PostBeginPlay();
}
public simulated function ReplicatedEvent(Name VarName)
{
    if (VarName == 'CompletionCount')
    {
        if (CompletionCount >= 1.0)
        {
            AnnexWave.DelayedFinishWave();
        }
    }
    else if (VarName == 'AnnexZone' && AnnexZone != None)
    {
        StartAnnex();
    }
    else if (VarName == 'bIsComplete' && bIsComplete)
    {
        OnComplete();
    }
    Super.ReplicatedEvent(VarName);
}
public function Used(Actor User)
{
    local SFXPawn_Player Player;
    local SFXPlayerControllerMP PC;

    if (AnnexZone != None)
    {
        return;
    }
    Player = SFXPawn_Player(User);
    if (Player == None)
    {
        return;
    }
    if (AnnexWave != None)
    {
        Player.StartCustomAction(27);
        PC = SFXPlayerControllerMP(Player.Controller);
        if (PC != None)
        {
            SimpleDialogPlayer.PlayVOEventRandomLine('HackStarted', PC);
        }
    }
    StartAnnex();
}
public function CountdownTimerFailedMessage()
{
    Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound(ZoneFailGuiSound);
    PlaySound(AnnexFailedSound, TRUE);
}
public function CountdownTimerFirstWarning()
{
    ClearTimer('RepeatWaveInstructions');
    SimpleDialogPlayer.PlayVOEventRandomLine('FirstWarning');
    PlayPlayerAcknowledgment(SimpleDialogPlayer.LastEventDuration + 0.5);
}
public function CountdownTimerSecondWarning()
{
    SimpleDialogPlayer.PlayVOEventRandomLine('SecondWarning');
    PlayPlayerAcknowledgment(SimpleDialogPlayer.LastEventDuration + 0.5);
}
public simulated function DelayedPlayerStatusUpdate()
{
    local int Index;

    if (PlayersToUpdate.Length == 0 || bIsComplete)
    {
        ClearTimer('DelayedPlayerStatusUpdate');
        return;
    }
    for (Index = 0; Index < PlayersToUpdate.Length && !bIsComplete; Index++)
    {
        if (WorldInfo.GameTimeSeconds - PlayersToUpdate[Index].PlayerUpdateTime > PlayerUpdateDelayTime)
        {
            if (PlayersToUpdate[Index].bIsEnteringZone)
            {
                PlayerEnteredAnnex(PlayersToUpdate[Index].Player);
            }
            else
            {
                PlayerExitedAnnex(PlayersToUpdate[Index].Player);
            }
            PlayersToUpdate.Remove(Index, 1);
            Index--;
        }
    }
}
public final simulated function int GetPlayerStateIndex(SFXPawn_Player Player)
{
    local int idx;

    if (Player != None)
    {
        for (idx = 0; idx < PlayerAnnexStates.Length; idx++)
        {
            if (PlayerAnnexStates[idx].Player == Player)
            {
                return idx;
            }
        }
    }
    return -1;
}
public final simulated function bool IsInStaticArray(SFXPawn_Player Player)
{
    local int idx;

    if (Player != None)
    {
        for (idx = 0; idx < 4; idx++)
        {
            if (InAnnexZoneArray[idx] == Player)
            {
                return TRUE;
            }
        }
    }
    return FALSE;
}
public final simulated function bool IsPlayerInAnnex(SFXPawn_Player Player)
{
    local int idx;

    if (Player != None)
    {
        for (idx = 0; idx < PlayerAnnexStates.Length; idx++)
        {
            if (PlayerAnnexStates[idx].Player == Player && PlayerAnnexStates[idx].bInAnnexZone)
            {
                return TRUE;
            }
        }
    }
    return FALSE;
}
public simulated function OnComplete()
{
    Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound(ZoneSuccessGuiSound);
    PlaySound(AnnexSucceededSound, TRUE);
}
public simulated function OnTouch(Actor Other)
{
    local SFXPawn_Player Player;

    Player = SFXPawn_Player(Other);
    if (Player == None || bIsComplete)
    {
        return;
    }
    AddDelayedPlayerUpdateEntry(Player, TRUE);
}
public simulated function OnUnTouch(Actor Other)
{
    local SFXPawn_Player Player;

    Player = SFXPawn_Player(Other);
    if (Player == None || bIsComplete)
    {
        return;
    }
    AddDelayedPlayerUpdateEntry(Player, FALSE);
}
// MILAN CHANGE - Mgamerz - 2026-10-20
// Use the actual zone cylinder and pawn collision size for actual annex contribution
public final simulated function bool IsPlayerWithinAnnexCylinder(SFXPawn_Player Player)
{
    local CylinderComponent ZoneCylinder;
    local Vector Offset;
    local Vector ZoneScale;
    local float Radius;
    local float Height;

    if (Player == None || Player.CylinderComponent == None || AnnexZone == None)
    {
        return FALSE;
    }
    ZoneCylinder = CylinderComponent(AnnexZone.CollisionComponent);
    if (ZoneCylinder == None)
    {
        return FALSE;
    }

    ZoneScale = ZoneCylinder.Scale3D * AnnexZone.DrawScale3D;
    ZoneScale *= Abs(ZoneCylinder.Scale * AnnexZone.DrawScale);
    Radius = ZoneCylinder.CollisionRadius * FMax(Abs(ZoneScale.X), Abs(ZoneScale.Y));
    Height = ZoneCylinder.CollisionHeight * Abs(ZoneScale.Z);
    if (Radius <= 0.0 || Height <= 0.0)
    {
        return FALSE;
    }

    Offset = Player.CylinderComponent.GetPosition() - ZoneCylinder.GetPosition();
    Radius += Player.GetCollisionRadius();
    Height += Player.GetCollisionHeight();
    return Offset.X * Offset.X + Offset.Y * Offset.Y < Radius * Radius
        && Abs(Offset.Z) < Height;
}
// END MILAN CHANGE

public final simulated function PlayerEnteredAnnex(SFXPawn_Player Player)
{
    local PlayerAnnexState AnnexState;
    local int idx;

    // MILAN CHANGE - Mgamerz - 2026-10-20
    // Reject player not actually being in annex - this method is called on activation which
    // is why we check this
    if (!IsPlayerWithinAnnexCylinder(Player))
    {
        return;
    }
    // END MILAN CHANGE
    AddToStaticArray(Player);
    if (AnnexWave.PlayersInAnnexZone.Find(Player) == -1)
    {
        AnnexWave.PlayersInAnnexZone.AddItem(Player);
    }
    if (!IsTimerActive('UpdateAnnexZone'))
    {
        SetTimer(CompletionCountFrequency, TRUE, 'UpdateAnnexZone', );
    }
    idx = GetPlayerStateIndex(Player);
    if (idx == -1)
    {
        AnnexState.Player = Player;
        PlayerAnnexStates.AddItem(AnnexState);
        idx = PlayerAnnexStates.Length - 1;
    }
    else if (PlayerAnnexStates[idx].bInAnnexZone)
    {
        return;
    }
    PlayerAnnexStates[idx].OmniToolGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().Start(CE_OmniTool, Player);
    PlayerAnnexStates[idx].bInAnnexZone = TRUE;
    if (PlayerAnnexStates[idx].Player.IsLocallyControlled())
    {
        PlayerAnnexStates[idx].Player.PlaySound(HackStartSound);
        Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound(ZoneEnterExitGuiSound);
    }
    if (Player.Controller == GetALocalPlayerController())
    {
        ClearTimer('RepeatWaveInstructions');
    }
}
public final simulated function PlayerExitedAnnex(SFXPawn_Player Player)
{
    local int idx;
    local SFXPlayerControllerMP PC;
    local bool bPlayVO;
    local SFXGRI GRI;

    if (Player == None)
    {
        return;
    }
    GRI = SFXGRI(WorldInfo.GRI);
    bPlayVO = !(bIsComplete || GRI != None && GRI.IsGameOver());
    AnnexWave.PlayersInAnnexZone.RemoveItem(Player);
    RemoveFromStaticArray(Player);
    idx = GetPlayerStateIndex(Player);
    if (idx != -1 && PlayerAnnexStates[idx].bInAnnexZone)
    {
        PlayerAnnexStates[idx].bInAnnexZone = FALSE;
        PlayerAnnexStates[idx].bLeftAnnexZone = TRUE;
        SetRemindTime(Player);
        Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_OmniTool, PlayerAnnexStates[idx].OmniToolGuid, TRUE);
        if (PlayerAnnexStates[idx].Player.IsLocallyControlled() && bPlayVO)
        {
            PlayerAnnexStates[idx].Player.PlaySound(HackStopSound);
            Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound(ZoneEnterExitGuiSound);
        }
    }
    if (Player.Controller.IsLocalPlayerController() && FRand() < LeaveZoneVOChance && bPlayVO)
    {
        if (AnnexWave != None)
        {
            PC = SFXPlayerControllerMP(Player.Controller);
            if (PC != None)
            {
                SimpleDialogPlayer.PlayVOEventRandomLine('PlayerLeftZone', PC);
            }
        }
    }
}
public final simulated function RemoveFromStaticArray(SFXPawn_Player Player)
{
    local int idx;

    if (Player != None)
    {
        for (idx = 0; idx < 4; idx++)
        {
            if (InAnnexZoneArray[idx] == Player)
            {
                InAnnexZoneArray[idx] = None;
                return;
            }
        }
    }
}
public simulated function SetOwningWave(SFXWave_Operation NewOwner)
{
    Super.SetOwningWave(NewOwner);
    AnnexWave = SFXEngagement_Annex(NewOwner);
}
public final simulated function SetRemindTime(SFXPawn_Player Player)
{
    local int idx;

    if (Player != None)
    {
        idx = GetPlayerStateIndex(Player);
        if (idx != -1)
        {
            PlayerAnnexStates[idx].NextRemindTime = FRand() * (NotInZoneVOMaxTime - NotInZoneVOMinTime) + NotInZoneVOMinTime;
        }
    }
}
public final simulated function StartAnnex()
{
    local SFXSimpleUseModule UseModule;
    local SFXPawn_Player Player;

    ActivateObjective();
    if (Role == ENetRole.ROLE_Authority)
    {
        AnnexZone = Spawn(Class'SFXAnnexZone', Self, 'AnnexZone', AnnexWave.GetAnnexZoneLocation(Self), Rotation, , TRUE, FALSE);
    }
    if (AnnexZone != None)
    {
        AnnexZone.StartAnnex(Self);
    }
    PlaySound(AnnexStartedSound, TRUE);
    UseModule = GetModule(Class'SFXSimpleUseModule');
    if (UseModule != None)
    {
        UseModule.m_bTargetable = FALSE;
    }
    foreach WorldInfo.AllPawns(Class'SFXPawn_Player', Player)
    {
        if (GetPlayerStateIndex(Player) == -1)
        {
            // MILAN CHANGE - Mgamerz - 2026-10-20
            // Check player is within annex before we accept them
            if (IsPlayerWithinAnnexCylinder(Player))
            {
                PlayerEnteredAnnex(Player);
            }
            // END MILAN CHANGE
        }
    }
    Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound(ZoneStartGuiSound);
    BioPlayerController(WorldInfo.GetALocalPlayerController()).HintSystem.HintEvent('ObjectiveStarted');
}
public simulated function UpdateAnnexZone()
{
    local SFXPlayerControllerMP PC;
    local SFXModule_MarkerObjective Module;
    local float AnnexRateBonus;
    local array<SFXPawn_Player> LivePlayersInZone;
    local SFXPawn_Player Player;
    local SFXScoreManager ScoreManager;
    local float fScore;
    local SFXGRI GRI;
    local SFXMPEventTicker EventTicker;
    local int idx;

    Module = GetModule(Class'SFXModule_MarkerObjective');
    if (Module == None || !Module.bActive || AnnexWave == None)
    {
        return;
    }
    if (AnnexZone == None)
    {
        return;
    }
    for (idx = 0; idx < PlayerAnnexStates.Length; idx++)
    {
        // MILAN CHANGE - Mgamerz - 2026-10-20
        // Detect player exits
        if (PlayerAnnexStates[idx].bInAnnexZone && PlayerAnnexStates[idx].Player != None
            && !IsPlayerWithinAnnexCylinder(PlayerAnnexStates[idx].Player))
        {
            PlayerExitedAnnex(PlayerAnnexStates[idx].Player);
        }
        // END MILAN CHANGE
        if (PlayerAnnexStates[idx].bInAnnexZone && PlayerAnnexStates[idx].Player != None && !PlayerAnnexStates[idx].Player.IsDead())
        {
            LivePlayersInZone.AddItem(PlayerAnnexStates[idx].Player);
        }
    }
    AnnexRateBonus = SFXGRI(WorldInfo.GRI).NumPlayersInGame() == 0 ? 1.0 : 1.0 / float(SFXGRI(WorldInfo.GRI).NumPlayersInGame()) * float(SFXGRIMP(WorldInfo.GRI).MaxPlayersAllowedMP);
    PlayersInZone = LivePlayersInZone.Length;
    CompletionCount += float(PlayersInZone) * CompletionRatePerPlayer * AnnexRateBonus * CompletionCountFrequency;
    if (CompletionCount > 1.0)
    {
        CompletionCount = 1.0;
    }
    ScoreRewardTimer += CompletionCountFrequency;
    if (ScoreRewardTimer >= ScoreRewardFrequency)
    {
        ScoreRewardTimer = 0.0;
        if (CompletionCount > CompletionAtLastScoreReward)
        {
            GRI = SFXGRI(WorldInfo.GRI);
            if (GRI != None)
            {
                ScoreManager = GRI.GetScoreManager();
                if (ScoreManager != None)
                {
                    foreach LivePlayersInZone(Player, )
                    {
                        fScore += ScoreManager.AddScore(Player, (CompletionCount - CompletionAtLastScoreReward) * AnnexWave.OperationScoreReward / float(LivePlayersInZone.Length), 2);
                    }
                    EventTicker = GRI.GetEventTicker();
                    if (EventTicker != None && fScore > float(0))
                    {
                        ClearCustomTokens();
                        SetCustomToken(0, string(PlayersInZone));
                        SetCustomToken(1, string(int(fScore)));
                        if (PlayersInZone > 1)
                        {
                            EventTicker.AddTickerEntry(Class'SFXGame'.static.GetSimpleString(AnnexWave.srAnnexProgressTickerPlural, TRUE));
                        }
                        else
                        {
                            EventTicker.AddTickerEntry(Class'SFXGame'.static.GetSimpleString(AnnexWave.srAnnexProgressTicker, TRUE));
                        }
                        ClearCustomTokens();
                    }
                    CompletionAtLastScoreReward = CompletionCount;
                }
            }
        }
    }
    UpdateObjectiveStatus();
    if (Role == ENetRole.ROLE_Authority)
    {
        if (CompletionCount >= 1.0)
        {
            bIsComplete = TRUE;
            OnComplete();
            AnnexWave.DelayedFinishWave();
            SimpleDialogPlayer.PlayVOEventRandomLine('WaveCompleted');
            Module.Deactivate();
            return;
        }
        if (CompletionCount >= 0.5 && !bHalfWayMessageSent)
        {
            bHalfWayMessageSent = TRUE;
            SimpleDialogPlayer.PlayVOEventRandomLine('WaveHalfCompleted');
        }
        for (idx = 0; idx < PlayerAnnexStates.Length; idx++)
        {
            if (!PlayerAnnexStates[idx].bInAnnexZone && PlayerAnnexStates[idx].bLeftAnnexZone)
            {
                PlayerAnnexStates[idx].NextRemindTime -= CompletionCountFrequency;
                if (PlayerAnnexStates[idx].NextRemindTime <= float(0))
                {
                    PlayerAnnexStates[idx].NextRemindTime = FRand() * (NotInZoneVOMaxTime - NotInZoneVOMinTime) + NotInZoneVOMinTime;
                    PC = SFXPlayerControllerMP(PlayerAnnexStates[idx].Player.Controller);
                    if (PC != None)
                    {
                        SimpleDialogPlayer.PlayVOEventRandomLine('OutOfZoneTooLong', PC);
                    }
                }
            }
        }
    }
}
public simulated function UpdateObjectiveStatus()
{
    SFXPlayerController(GetALocalPlayerController()).SetScoreHudObjectiveProgress(CompletionCount, PlayersInZone > 1);
}
public simulated function AddDelayedPlayerUpdateEntry(SFXPawn_Player Player, bool bIsEnteringZone)
{
    local PlayerUpdateInfo UpdateInfo;
    local int Index;

    // MILAN CHANGE - Mgamerz - 2026-10-18
    // StartAnnex can register a player immediately while a delayed enter is
    // queued. If they leave, it can still cause an entry
    // this lets people cheat the objective, so abort
    if (Player == None || bIsComplete)
    {
        return;
    }

    Index = PlayersToUpdate.Find('Player', Player);
    if (Index != -1 && PlayersToUpdate[Index].bIsEnteringZone == bIsEnteringZone)
    {
        return;
    }

    if (Index != -1)
    {
        PlayersToUpdate.Remove(Index, 1);
    }

    if (IsPlayerInAnnex(Player) == bIsEnteringZone)
    {
        return;
    }

    UpdateInfo.Player = Player;
    UpdateInfo.PlayerUpdateTime = WorldInfo.GameTimeSeconds;
    UpdateInfo.bIsEnteringZone = bIsEnteringZone;
    PlayersToUpdate.AddItem(UpdateInfo);
    if (!IsTimerActive('DelayedPlayerStatusUpdate'))
    {
        SetTimer(0.1, TRUE, 'DelayedPlayerStatusUpdate');
    }
    // END MILAN CHANGE
}
public final simulated function AddToStaticArray(SFXPawn_Player Player)
{
    local int idx;

    if (Player != None && !IsInStaticArray(Player))
    {
        for (idx = 0; idx < 4; idx++)
        {
            if (InAnnexZoneArray[idx] == None)
            {
                InAnnexZoneArray[idx] = Player;
                return;
            }
        }
    }
}

replication
{
    if ((bNetInitial || CompletionCount >= 1.0) && bNetDirty && Role == ENetRole.ROLE_Authority)
        CompletionCount, bIsComplete;
    if (bNetDirty && Role == ENetRole.ROLE_Authority)
        AnnexZone;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=DynamicLightEnvironmentComponent Name=MyLightEnvironment
    End Template
    Begin Template Class=StaticMeshComponent Name=MeshComp0
        ReplacementPrimitive = None
        LightEnvironment = MyLightEnvironment
    End Template
    Begin Object Class=SFXSimpleUseModule Name=SelMod01
        __OnUsed__Delegate = class'SFXObjective_Annex_DefendZone'.Used
        fUseRange = 325.0
        m_TargetOffset = {X = 0.0, Y = 0.0, Z = 25.0}
        m_bTargetable = TRUE
        bIgnoreFacing = TRUE
    End Object
    Begin Object Class=SFXModule_MarkerObjective Name=ObjectiveModule0
        MarkerOffset = {X = 0.0, Y = 0.0, Z = 100.0}
    End Object
    ZoneEnterExitGuiSound = 'MPEnterExitZone'
    CompletionCountFrequency = 1.0
    CompletionRatePerPlayer = 0.00400000019
    CE_OmniTool = RvrClientEffectMulti'BioVFX_T_TechPowers._OmniTool.VCFX.OmniTool_RightFull_VCFX_M'
    ScoreRewardFrequency = 5.0
    LeaveZoneVOChance = 1.0
    NotInZoneVOMinTime = 8.0
    NotInZoneVOMaxTime = 20.0
    HackStartSound = None
    HackStopSound = None
    PlayerUpdateDelayTime = 0.5
    OwnerWaveClassName = 'SFXEngagement_Annex'
    WaveInstructionVODelay = 4.0
    Mesh = MeshComp0
    LightEnvironment = MyLightEnvironment
    ActivateObjectiveOnSpawn = TRUE
    bEnableCombatZone = TRUE
    Components = (None, MyLightEnvironment, MeshComp0)
    Modules = (SelMod01, ObjectiveModule0)
    bAlwaysRelevant = TRUE
    bOnlyDirtyReplication = TRUE
    RemoteRole = ENetRole.ROLE_SimulatedProxy
}
