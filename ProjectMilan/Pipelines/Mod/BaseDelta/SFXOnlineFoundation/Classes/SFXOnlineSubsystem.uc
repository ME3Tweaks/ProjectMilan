Class SFXOnlineSubsystem extends OnlineSubsystem
    native
    config(Game);

struct native SFXOnlineComponentDescription 
{
    var Class<Object> className;
    var Name PlatformName;
    var SFXOnlineComponentType ComponentType;
};
enum SFXOnlineComponentType
{
    SFXONLINE_COMPONENT_TYPE_COORDINATOR,
    SFXONLINE_COMPONENT_TYPE_ONLINE_API,
    SFXONLINE_COMPONENT_TYPE_ONLINE_UI,
    SFXONLINE_COMPONENT_TYPE_PLATFORM,
    SFXONLINE_COMPONENT_TYPE_LOGIN,
    SFXONLINE_COMPONENT_TYPE_TELEMETRY,
    SFXONLINE_COMPONENT_TYPE_LEADERBOARD,
    SFXONLINE_COMPONENT_TYPE_STATS,
    SFXONLINE_COMPONENT_TYPE_ACHIEVEMENT,
    SFXONLINE_COMPONENT_TYPE_PLAYGROUP,
    SFXONLINE_COMPONENT_TYPE_MATCH_MAKER,
    SFXONLINE_COMPONENT_TYPE_GAME_MANAGER,
    SFXONLINE_COMPONENT_TYPE_VOICE,
    SFXONLINE_COMPONENT_TYPE_ANTICHEAT,
    SFXONLINE_COMPONENT_TYPE_SERVER_LIST,
    SFXONLINE_COMPONENT_TYPE_GAMEFLOW,
    SFXONLINE_COMPONENT_TYPE_ASSOCIATION,
    SFXONLINE_COMPONENT_TYPE_UNREALSYSTEM,
    SFXONLINE_COMPONENT_TYPE_UNREALPLAYER,
    SFXONLINE_COMPONENT_TYPE_UNREALPLAYEREX,
    SFXONLINE_COMPONENT_TYPE_NOTIFICATION,
    SFXONLINE_COMPONENT_TYPE_ORIGIN,
    SFXONLINE_COMPONENT_TYPE_JOBQUEUE,
    SFXONLINE_COMPONENT_TYPE_MATCH_MAKING_BOT,
    SFXONLINE_COMPONENT_TYPE_MESSAGING,
    SFXONLINE_COMPONENT_TYPE_GAME_ENTRY_FLOW,
    SFXONLINE_COMPONENT_TYPE_LIVE_PARTY,
    SFXONLINE_COMPONENT_TYPE_HTTP_MANAGER,
    SFXONLINE_COMPONENT_TYPE_XML_PARSER,
    SFXONLINE_COMPONENT_TYPE_GALAXYATWAR,
    SFXONLINE_COMPONENT_TYPE_COMMERCE,
    SFXONLINE_COMPONENT_TYPE_IMAGE_MANAGER,
    SFXONLINE_COMPONENT_TYPE_AVATAR_AWARD,
};

var string GameProtocolVersion;
var const config string m_IsolatedMatchMakingCode;
var array<SFXOnlineComponentDescription> ComponentClassList;
var config string OnlineUIClass;
var config string OnlineBotClass;
var config string OnlineGameEntryFlowClass;
var config string FontPackageName;
var ISFXOnlineComponent OnlineComponentList[33];
var SFXOnlineEvent_Tick TickEvent;
var int IniVersionId;

public event native function Exit();

public native function int GetBioDynamicBuildVersion();

public native function string GetCDKey();

public final native function ISFXOnlineComponentAchievement GetComponentAchievement();

public final native function ISFXOnlineComponentAPI GetComponentAPI();

public final native function SFXOnlineComponentAvatarAwardXenon GetComponentAvatarAwardXenon();

public final native function ISFXOnlineComponentCommerce GetComponentCommerce();

public final native function ISFXOnlineComponentGalaxyAtWar GetComponentGalaxyAtWar();

public final native function ISFXOnlineComponentGame GetComponentGame();

public final native function ISFXOnlineComponentGameEntryFlow GetComponentGameEntryFlow();

public final native function ISFXOnlineComponentGameFlow GetComponentGameFlow();

public final native function SFXOnlineComponentHTTPManager GetComponentHTTPManager();

public final native function SFXOnlineComponentImageManager GetComponentImageManager();

public final native function SFXOnlineComponentJobQueue GetComponentJobQueue();

public final native function ISFXOnlineComponentLeaderboard GetComponentLeaderboard();

public final native function ISFXOnlineComponentLogin GetComponentLogin();

public final native function ISFXOnlineComponentMatchMakingBot GetComponentMatchMakingBot();

public final native function ISFXOnlineComponentMessaging GetComponentMessaging();

public final native function ISFXOnlineComponentNotification GetComponentNotification();

public final native function SFXOnlineComponentOrigin GetComponentOrigin();

public final native function ISFXOnlineComponentPlatform GetComponentPlatform();

public final native function ISFXOnlineComponentStats GetComponentStats();

public final native function ISFXOnlineComponentTelemetry GetComponentTelemetry();

public final native function SFXOnlineComponentUnrealPlayer GetComponentUnrealPlayer();

public final native function SFXOnlineComponentUnrealPlayerEx GetComponentUnrealPlayerEx();

public final native function SFXOnlineComponentUnrealSystem GetComponentUnrealSystem();

public final native function ISFXOnlineComponentUserInterface GetComponentUserInterface();

public final native function SFXOnlineComponentVoiceInterface GetComponentVoiceInterface();

public final native function SFXOnlineComponentXenonLiveParty GetComponentXenonLiveParty();

public final native function SFXOnlineComponentXMLParser GetComponentXMLParser();

public final native function SFXOnlineComponentCoordinator GetCoordinator();

public final native function string GetGameProtocolVersion();

public native function string GetLanguage();

public static final native function SFXOnlineSubsystem GetOnlineSubsystem();

public native function Name GetPlatform();

public native function string GetProjectID();

public event simulated function string GetURL()
{
    local string sURL;
    
    sURL = "UNDEFINED - OVERRIDE ME";
    return sURL;
}
public event function bool Init()
{
    Super.Init();
    TickEvent = new Class'SFXOnlineEvent_Tick';
    TickEvent.SetEventType(1);
    TickEvent.SetStatus(2);
    TickEvent.SetOutcome(0);
    InitGameProtocolVersion();
    CreateComponents();
    SetUnrealInterfaces();
    return NativeInit();
}
public function bool IsCerberusMember()
{
    return GetComponentLogin().IsCerberusMember();
}
public native function bool NativeInit();

public native function NativeInitOnlineComponent(int componentIdx, string componentClassName);

public function bool ShowKeyboardUI(byte eLocalUserNum, string sTitleText, string sDescriptionText, optional bool bIsPassword = FALSE, optional bool bShouldValidate = TRUE, optional string sDefaultText, optional int nMaxResultLength = 256)
{
    if (GetComponentPlatform() != None)
    {
        return GetComponentPlatform().ShowKeyboardUI(eLocalUserNum, sTitleText, sDescriptionText, bIsPassword ? 1 : 0, bShouldValidate, FALSE, sDefaultText, nMaxResultLength);
    }
    return FALSE;
}
public event native function ShutDown();

public event function UpdateGameProtocolVersion(int runTimeVersioning)
{
    InitGameProtocolVersion();
    IniVersionId = runTimeVersioning;
    GameProtocolVersion $= GetBioDynamicBuildVersion();
    GetComponentGame().UpdateGameProtocolVersion();
    LogInternal("DEBUG:" @ "GameProtocolVersion updated to: " @ GameProtocolVersion, 'SFXOnlineFoundation');
}
public final native function SFXOnlineComponentBlazeHubEnvironment GetEnvironment();

private final function CreateComponents()
{
    local Name nmPlatformName;
    local int nComponentIndex;
    
    nmPlatformName = GetPlatform();
    for (nComponentIndex = 0; nComponentIndex < ComponentClassList.Length; nComponentIndex++)
    {
        if (ComponentClassList[nComponentIndex].className != None && (ComponentClassList[nComponentIndex].PlatformName == nmPlatformName || ComponentClassList[nComponentIndex].PlatformName == 'None'))
        {
            LogInternal("DEBUG:" @ "Creating component" @ ComponentClassList[nComponentIndex].className, 'SFXOnlineFoundation');
            OnlineComponentList[int(ComponentClassList[nComponentIndex].ComponentType)] = ISFXOnlineComponent(new ComponentClassList[nComponentIndex].className);
            if (OnlineComponentList[int(ComponentClassList[nComponentIndex].ComponentType)] == None)
            {
                LogInternal("WARN:" @ "Failed to create online component" @ ComponentClassList[nComponentIndex].className, 'SFXOnlineFoundation');
            }
        }
    }
}
private final function InitGameProtocolVersion()
{
    GameProtocolVersion = m_IsolatedMatchMakingCode $ GetBuildUniqueId() $ GetBioStaticBuildVersion();
    LogInternal("DEBUG:" @ "GameProtocolVersion: " @ GameProtocolVersion, 'SFXOnlineFoundation');
}
private final function SetUnrealInterfaces()
{
    LogInternal("DEBUG:" @ "Setting up interfaces...", 'SFXOnlineFoundation');
    SetGameInterface(GetComponentGame());
    SetStatsInterface(GetComponentStats());
    SetPlayerInterface(GetComponentUnrealPlayer());
    SetPlayerInterfaceEx(GetComponentUnrealPlayerEx());
    SetSystemInterface(GetComponentUnrealSystem());
    SetVoiceInterface(GetComponentVoiceInterface());
    SetPartyChatInterface(GetComponentXenonLiveParty());
}
public simulated function bool ShowConsoleRoutedKeyboardUI(byte eLocalUserNum, string sTitleText, string sDescriptionText, optional bool bIsPassword = FALSE, optional bool bShouldValidate = TRUE, optional string sDefaultText, optional int nMaxResultLength = 256)
{
    if (GetComponentPlatform() != None)
    {
        return GetComponentPlatform().ShowKeyboardUI(eLocalUserNum, sTitleText, sDescriptionText, bIsPassword ? 1 : 0, bShouldValidate, TRUE, sDefaultText, nMaxResultLength);
    }
    return FALSE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    GameProtocolVersion = "ME3"
    m_IsolatedMatchMakingCode = "ME3"
    ComponentClassList = ({className = Class'SFXOnlineComponentCoordinator', PlatformName = 'None', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_COORDINATOR},
// MILAN CHANGE
// Disable Telemetry subsystem
                          {className = Class'SFXOnlineComponentTelemetrySystem', PlatformName = 'None', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_TELEMETRY}, 
// Restore OnlineAPI component which is needed for time tracking; MilanHost patches it              
                          {className = Class'SFXOnlineComponentBlazeHub', PlatformName = 'None', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_ONLINE_API},
// END MILAN CHANGE
                          {className = Class'SFXOnlineComponentGameFlow', PlatformName = 'None', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_GAMEFLOW},
                          {className = Class'SFXOnlineComponentBlazeNotification', PlatformName = 'None', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_NOTIFICATION}, 
                          {className = Class'SFXOnlineComponentUnrealSystem', PlatformName = 'None', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_UNREALSYSTEM}, 
                          {className = Class'SFXOnlineComponentUnrealPlayer', PlatformName = 'None', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_UNREALPLAYER}, 
                          {className = Class'SFXOnlineComponentUnrealPlayerEx', PlatformName = 'None', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_UNREALPLAYEREX}, 
                          {className = Class'SFXOnlineComponentBlazeStats', PlatformName = 'None', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_STATS}, 
                          {className = Class'SFXOnlineComponentVoiceInterface', PlatformName = 'None', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_VOICE}, 
                          {className = Class'SFXOnlineComponentJobQueue', PlatformName = 'None', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_JOBQUEUE}, 
                          {className = Class'SFXOnlineComponentBlazeLeaderboard', PlatformName = 'None', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_LEADERBOARD}, 
                          {className = Class'SFXOnlineComponentBlazeMessaging', PlatformName = 'None', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_MESSAGING}, 
                          {className = Class'SFXOnlineComponentHTTPManager', PlatformName = 'None', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_HTTP_MANAGER}, 
                          {className = Class'SFXOnlineComponentXMLParser', PlatformName = 'None', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_XML_PARSER}, 
                          {className = Class'SFXOnlineComponentGalaxyAtWar', PlatformName = 'None', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_GALAXYATWAR}, 
                          {className = Class'SFXOnlineComponentCommerce', PlatformName = 'None', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_COMMERCE}, 
                          {className = Class'SFXOnlineComponentImageManager', PlatformName = 'None', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_IMAGE_MANAGER}, 
                          {className = Class'SFXOnlineComponentBlazeLoginXenon', PlatformName = 'Xenon', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_LOGIN}, 
                          {className = Class'SFXOnlineComponentBlazeGameXenon', PlatformName = 'Xenon', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_GAME_MANAGER}, 
                          {className = Class'SFXOnlineComponentPlatformXenon', PlatformName = 'Xenon', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_PLATFORM}, 
                          {className = Class'SFXOnlineComponentAchievementXenon', PlatformName = 'Xenon', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_ACHIEVEMENT}, 
                          {className = Class'SFXOnlineComponentXenonLiveParty', PlatformName = 'Xenon', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_LIVE_PARTY}, 
                          {className = Class'SFXOnlineComponentAvatarAwardXenon', PlatformName = 'Xenon', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_AVATAR_AWARD}, 
                          {className = Class'SFXOnlineComponentBlazeLoginPS3', PlatformName = 'PS3', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_LOGIN}, 
                          {className = Class'SFXOnlineComponentBlazeGame', PlatformName = 'PS3', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_GAME_MANAGER}, 
                          {className = Class'SFXOnlineComponentPlatformPS3', PlatformName = 'PS3', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_PLATFORM}, 
                          {className = Class'SFXOnlineComponentAchievementPS3', PlatformName = 'PS3', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_ACHIEVEMENT}, 
                          {className = Class'SFXOnlineComponentBlazeLoginPC', PlatformName = 'PC', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_LOGIN}, 
                          {className = Class'SFXOnlineComponentBlazeGame', PlatformName = 'PC', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_GAME_MANAGER}, 
                          {className = Class'SFXOnlineComponentPlatformPC', PlatformName = 'PC', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_PLATFORM}, 
                          {className = Class'SFXOnlineComponentOrigin', PlatformName = 'PC', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_ORIGIN}, 
                          {className = Class'SFXOnlineComponentAchievementPC', PlatformName = 'PC', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_ACHIEVEMENT}, 
                          {className = Class'SFXOnlineComponentBlazeLoginPC', PlatformName = 'Dingo', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_LOGIN}, 
                          {className = Class'SFXOnlineComponentBlazeGame', PlatformName = 'Dingo', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_GAME_MANAGER}, 
                          {className = Class'SFXOnlineComponentPlatformDingo', PlatformName = 'Dingo', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_PLATFORM}, 
                          {className = Class'SFXOnlineComponentOrigin', PlatformName = 'Dingo', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_ORIGIN}, 
                          {className = Class'SFXOnlineComponentAchievementDingo', PlatformName = 'Dingo', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_ACHIEVEMENT}, 
                          {className = Class'SFXOnlineComponentBlazeLoginPC', PlatformName = 'Orbis', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_LOGIN}, 
                          {className = Class'SFXOnlineComponentBlazeGame', PlatformName = 'Orbis', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_GAME_MANAGER}, 
                          {className = Class'SFXOnlineComponentPlatformOrbis', PlatformName = 'Orbis', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_PLATFORM}, 
                          {className = Class'SFXOnlineComponentOrigin', PlatformName = 'Orbis', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_ORIGIN}, 
                          {className = Class'SFXOnlineComponentAchievementOrbis', PlatformName = 'Orbis', ComponentType = SFXOnlineComponentType.SFXONLINE_COMPONENT_TYPE_ACHIEVEMENT}
                         )
    OnlineUIClass = "SFXGame.SFXOnlineComponentUI"
    OnlineBotClass = "SFXGame.SFXOnlineComponentMatchMakingBot"
    OnlineGameEntryFlowClass = "SFXGame.SFXOnlineGameEntryFlow"
    FontPackageName = "SFXGUI_Fonts"
}