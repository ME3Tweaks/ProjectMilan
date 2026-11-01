// NEW to Milan - Mgamerz - 2026-10-21
// Kismet action that reads the current match state
// so that certain wave-based kismet events don't have to
// try and guess with their own tracking (e.g. Slum2 wave counting)
class SFXSeqAct_GetMatchInfo extends SequenceAction;

// 1-based wave number, as shown in the HUD and pause screen
var int Wave;
// Number of waves in the match, extraction wave included
var int TotalWaves;
// Faction picked in the lobby (SFXOnlineGameSettings.EnemyTypes Id), as shown in the pause screen
var int FactionID;
// Class name of the faction actually used by the current wave
// Only accurate on host
var Name WaveFaction;
// 0-based difficulty level (EDifficultyOptions)
var int Difficulty;

public event function Activated()
{
    local WorldInfo WI;
    local SFXGRIMP GRI;
    local SFXWaveCoordinator_HordeOperation Coord;

    Wave = 0;
    TotalWaves = 0;
    FactionID = 0;
    WaveFaction = 'None';
    Difficulty = 0;

    WI = GetWorldInfo();
    if (WI != None)
    {
        GRI = SFXGRIMP(WI.GRI);
    }
    if (GRI != None)
    {
        Coord = SFXWaveCoordinator_HordeOperation(GRI.WaveCoordinator);
    }
    if (Coord == None)
    {
        // Failed
        ActivateOutputLink(1);
        return;
    }

    Wave = Coord.GetFriendlyCurrentWaveNumber();
    TotalWaves = Coord.NumWaves;
    FactionID = GRI.GetEnemyWaveTypeID();
    if (Coord.HordeWaveType != None)
    {
        WaveFaction = Coord.HordeWaveType.Name;
    }
    // The difficulty handler is what gameplay uses
    // DifficultySetting is the lobby value
    Difficulty = GRI.DifficultyHandler != None ? int(GRI.DifficultyHandler.CurrentDifficulty) : GRI.DifficultySetting;
    ActivateOutputLink(0);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    bCallHandler = FALSE
    bAutoActivateOutputLinks = FALSE
    OutputLinks = ({LinkDesc = "Out"}, {LinkDesc = "Failed"})
    VariableLinks = ({
                      LinkedVariables = (),
                      LinkDesc = "Wave",
                      ExpectedType = Class'SeqVar_Int',
                      PropertyName = 'Wave',
                      MinVars = 0,
                      MaxVars = 255,
                      bWriteable = TRUE
                     },
                     {
                      LinkedVariables = (),
                      LinkDesc = "Total Waves",
                      ExpectedType = Class'SeqVar_Int',
                      PropertyName = 'TotalWaves',
                      MinVars = 0,
                      MaxVars = 255,
                      bWriteable = TRUE
                     },
                     {
                      LinkedVariables = (),
                      LinkDesc = "Faction ID",
                      ExpectedType = Class'SeqVar_Int',
                      PropertyName = 'FactionID',
                      MinVars = 0,
                      MaxVars = 255,
                      bWriteable = TRUE
                     },
                     {
                      LinkedVariables = (),
                      LinkDesc = "Wave Faction",
                      ExpectedType = Class'SeqVar_Name',
                      PropertyName = 'WaveFaction',
                      MinVars = 0,
                      MaxVars = 255,
                      bWriteable = TRUE
                     },
                     {
                      LinkedVariables = (),
                      LinkDesc = "Difficulty",
                      ExpectedType = Class'SeqVar_Int',
                      PropertyName = 'Difficulty',
                      MinVars = 0,
                      MaxVars = 255,
                      bWriteable = TRUE
                     }
                    )
}
