// Adds 4 methods that are blank. I know this is native,
// But I don't think it gets inherited.
// Eventally if we have MP menu functionality we will need to setup the functions for use.
Class SFXTelemetryGameSession
    native
    transient
    config(Game);

// Types
enum EGameEndReason
{
    GameEndReason_Leave,
    GameEndReason_GameEnd,
    GameEndReason_Restart,
    GameEndReason_Error,
    GameEndReason_OptOutTelemetry,
    GameEndReason_Unknown,
};

// Variables
var const native noexport Pointer VfTable_FTickableObject;
var const native noexport Pointer VfTable_FCallbackEventDevice;
var Double CareerTime;
var Double GameTime;
var Double SessionTime;
var Double IdleTime;
var init string Career;
var init string Base64_CharacterID;
var config array<string> SessionStartMapExclusion;
var SFXTelemetry TelemetryInstance;
var Name MapName;
var Name ChunkName;
var int Difficulty;
var int PlayerXPGained;
var int PlayerScore;
var int CombatScore;
var int PlayerKills;
var int PlayerDeaths;
var int TeamKills;
var int TeamDeaths;
var bool bStarted;
var bool bSentBootHooks;
var bool bSentBugSentryHook;

// Functions
public event function SendClientMPSessionStart()
{
}
public event function SendServerMPSessionEnd()
{
}
public event function SendServerMPSessionStart()
{
}
public final function SetMPMatchSettings(bool RandomMap, bool RandomEnemy, bool PrivateGame, int NewDifficulty, int NewEnemyType)
{
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    SessionStartMapExclusion = ("BioP_Char")
}