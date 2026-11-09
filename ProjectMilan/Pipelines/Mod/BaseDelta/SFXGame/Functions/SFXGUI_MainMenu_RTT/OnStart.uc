// MILAN CHANGE - 10/30/2026 - Mgamerz
// Tints the terminal and this movie for the live main menu scene, if one is loaded
// MILAN CHANGE - 10/31/2026 - Mgamerz
// Plays the main menu music as well, so returning to the main menu plays the music too
public event function OnStart()
{
    local SFXOnlineSubsystem oOnlineSubsystem;
    local ISFXOnlineComponentGame oOnlineGame;
    local SFXGUIInteraction oMgr;
    local BioSFHandler_MainMenu oMainMenu;

    Super.OnStart();
    DLCBeginMountingAttempts = 0;
    oMgr = GetSFXUIController();
    if (oMgr != None)
    {
        oMainMenu = oMgr.CastGetMovie(Class'BioSFHandler_MainMenu', GetPC(), oMgr.MovieTag_MainMenu);
        oMainMenu.MenuComputer = Self;
    }
    AS_Initialize();
    Class'MilanMenuScene'.static.ApplyTints(Self);
    PlayGuiMusic('MainMenu');
    BeginInitDownloadableContent();
    oOnlineSubsystem = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem();
    if (oOnlineSubsystem != None)
    {
        oOnlineGame = oOnlineSubsystem.GetComponentGame();
        if (oOnlineGame != None && oOnlineGame.IsPlaying())
        {
            oOnlineGame.LeaveGame();
        }
    }
}
