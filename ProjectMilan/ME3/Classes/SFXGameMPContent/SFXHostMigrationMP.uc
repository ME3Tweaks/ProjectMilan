Class SFXHostMigrationMP extends SFXHostMigration
    transient;

// Types
struct HMMatch 
{
    var WaveEventInfo Wave;
    var HMGame Game;
    var array<HMPlayer> Players;
    var bool bValidGame;
    var bool bValidPlayers;
    var bool bValidWave;
    var bool bIsMissionComplete;
};
struct HMGame 
{
    var array<int> SquadMedals;
    var int MapSetting;
    var int EnemySetting;
    var int DifficultySetting;
    var bool PrivacySetting;
    var bool bRandomMap;
    var bool bRandomEnemy;
};
struct HMPlayer 
{
    var UniqueNetId NetId;
    var string PlayerName;
    var array<int> PlayerMedals;
    var array<ActiveMatchConsumable> ActiveMatchConsumables;
    var ScoreInfo Score;
};

// Variables
var HMMatch Match;

// Functions
public function bool CanRestoreWave()
{
    return bNeedRestoration && Match.bValidWave;
}
public function bool FindPlayer(out HMPlayer OutPlayer, UniqueNetId NetId, string PlayerName)
{
    local HMPlayer Player;
    
    foreach Match.Players(Player, )
    {
        if (Class'OnlineSubsystem'.static.AreUniqueNetIdsEqual(Player.NetId, NetId) && Player.PlayerName == PlayerName)
        {
            OutPlayer = Player;
            return TRUE;
        }
    }
    return FALSE;
}
public function WaveEventInfo GetWaveToRestore()
{
    return Match.Wave;
}
public function bool HasCompleteAndValidState(SFXGRI GRI)
{
    if ((GRI != None && Match.bValidGame) && Match.bValidPlayers)
    {
        return GRI.IsA('SFXGRIMP_Lobby') || Match.bValidWave;
    }
    return FALSE;
}
public function InvalidateAll()
{
    Match.bValidPlayers = FALSE;
    Match.bValidWave = FALSE;
    Match.bValidGame = FALSE;
}
public function RestorePRI(SFXPRI PRI)
{
    local SFXPRIMP PRIMP;
    local HMPlayer Player;
    local int i;
    
    PRIMP = SFXPRIMP(PRI);
    if ((bNeedRestoration && Match.bValidPlayers) && PRIMP != None)
    {
        if (FindPlayer(Player, PRIMP.UniqueId, PRIMP.PlayerName))
        {
            PRIMP.AddPoints(Player.Score.Score);
            PRIMP.AddCredits(Player.Score.Credits);
            for (i = 0; i < Player.PlayerMedals.Length; i++)
            {
                PRIMP.AddPlayerMedal(Player.PlayerMedals[i], , FALSE);
            }
            for (i = 0; i < Player.ActiveMatchConsumables.Length; i++)
            {
                PRIMP.AddActiveMatchConsumable(Player.ActiveMatchConsumables[i].ClassNameID, Player.ActiveMatchConsumables[i].Value);
            }
        }
    }
}
public function SaveGRI(SFXGRI GRI)
{
    local PlayerReplicationInfo PRI;
    local SFXPRIMP PRIMP;
    local HMPlayer Player;
    local SFXGRIMP GRIMP;
    local SFXGRIMP_Lobby GRILobby;
    local int i;
    
    if (bNeedRestoration)
    {
        return;
    }
    Match.bValidGame = FALSE;
    GRIMP = SFXGRIMP(GRI);
    if (GRIMP != None)
    {
        Match.bValidGame = TRUE;
        Match.Game.PrivacySetting = GRIMP.PrivacySetting;
        Match.Game.MapSetting = GRIMP.MapSetting;
        Match.Game.bRandomMap = GRIMP.bRandomMap;
        Match.Game.EnemySetting = GRIMP.EnemySetting;
        Match.Game.bRandomEnemy = GRIMP.bRandomEnemy;
        Match.Game.DifficultySetting = GRIMP.DifficultySetting;
        Match.Game.SquadMedals.Length = 10;
        for (i = 0; i < Match.Game.SquadMedals.Length; i++)
        {
            Match.Game.SquadMedals[i] = GRIMP.SquadMedals[i];
        }
        Match.bIsMissionComplete = GRIMP.bIsMissionComplete;
    }
    else
    {
        GRILobby = SFXGRIMP_Lobby(GRI);
        if (GRILobby != None)
        {
            Match.bValidGame = TRUE;
            Match.Game.PrivacySetting = GRILobby.PrivacySetting;
            Match.Game.MapSetting = GRILobby.MapSetting;
            Match.Game.bRandomMap = GRILobby.bRandomMap;
            Match.Game.EnemySetting = GRILobby.EnemySetting;
            Match.Game.bRandomEnemy = GRILobby.bRandomEnemy;
            Match.Game.DifficultySetting = GRILobby.DifficultySetting;
        }
    }
    Match.Players.Length = 0;
    foreach GRI.PRIArray(PRI, )
    {
        PRIMP = SFXPRIMP(PRI);
        if (PRIMP != None && PRIMP.PlayerID != 0)
        {
            Player.NetId = PRIMP.UniqueId;
            Player.PlayerName = PRIMP.PlayerName;
            Player.Score = PRIMP.ReplicatedScoreInfo;
            Player.PlayerMedals.Length = 10;
            for (i = 0; i < Player.PlayerMedals.Length; i++)
            {
                Player.PlayerMedals[i] = PRIMP.PlayerMedals[i];
            }
            PRIMP.GetActiveMatchConsumables(Player.ActiveMatchConsumables);
            Match.Players.AddItem(Player);
        }
    }
    Match.bValidPlayers = Match.Players.Length > 0;
}
public function SetWaveToRestore(WaveEventInfo InWave)
{
    Match.bValidWave = TRUE;
    Match.Wave = InWave;
}
public function bool IsReadyToStartMatch(int ConnectedPlayerCount)
{
    local SFXOnlineSubsystem OnlineSubsystem;
    local ISFXOnlineComponentGame OnlineGame;
    
    if (bNeedRestoration)
    {
        OnlineSubsystem = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem();
        if (OnlineSubsystem != None)
        {
            OnlineGame = OnlineSubsystem.GetComponentGame();
            if (OnlineGame != None)
            {
                return ConnectedPlayerCount >= OnlineGame.GetPlayerCount();
            }
        }
    }
    return TRUE;
}
public function RestoreGRI(SFXGRI GRI)
{
    local SFXGRIMP GRIMP;
    local SFXGRIMP_Lobby GRILobby;
    local int i;
    
    if ((bNeedRestoration && Match.bValidGame) && GRI != None)
    {
        GRIMP = SFXGRIMP(GRI);
        if (GRIMP != None)
        {
            GRIMP.PrivacySetting = Match.Game.PrivacySetting;
            GRIMP.MapSetting = Match.Game.MapSetting;
            GRIMP.bRandomMap = Match.Game.bRandomMap;
            GRIMP.EnemySetting = Match.Game.EnemySetting;
            GRIMP.bRandomEnemy = Match.Game.bRandomEnemy;
            GRIMP.DifficultySetting = Match.Game.DifficultySetting;
            for (i = 0; i < Match.Game.SquadMedals.Length; i++)
            {
                GRIMP.AddSquadMedal(Match.Game.SquadMedals[i]);
            }
            GRIMP.bIsMissionComplete = Match.bIsMissionComplete;
        }
        else
        {
            GRILobby = SFXGRIMP_Lobby(GRI);
            if (GRILobby != None)
            {
                GRILobby.PrivacySetting = Match.Game.PrivacySetting;
                GRILobby.MapSetting = Match.Game.MapSetting;
                GRILobby.bRandomMap = Match.Game.bRandomMap;
                GRILobby.EnemySetting = Match.Game.EnemySetting;
                GRILobby.bRandomEnemy = Match.Game.bRandomEnemy;
                GRILobby.DifficultySetting = Match.Game.DifficultySetting;
            }
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}