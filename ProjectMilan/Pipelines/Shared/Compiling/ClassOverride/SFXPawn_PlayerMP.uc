Class SFXPawn_PlayerMP extends SFXPawn_Player
    placeable
    abstract
    config(Game);

// Types
struct SyncMovementFailsafe 
{
    var transient float LastZLocation;
    var transient float ActiveStartTime;
    var transient int OscillationCount;
    var transient bool ZDeltaPositive;
    var transient bool IsActive;
};
const MAX_WEAPON_MODS = 2;
const MAX_POWERS = 6;
const MAX_MP_WEAPONS = 2;

// Variables
var LinearColor RegularNametagColor;
var LinearColor PermaDeadNametagColor;
var LinearColor DownedNametagColor;
var SyncMovementFailsafe SyncMovementFailsafeInfo;
var transient Name Kit;
var config float fPermaDeathTimer;
var config float DeathFlourishDuration;
var(SFXPawn_PlayerMP) Texture2D KitPortrait;
var config stringref srPlayerDownPopup;
var config stringref srPlayerJoined;
var config stringref srPlayerLeft;
var config stringref srPlayerKilled;
var config stringref srPlayerSuicide;
var config stringref srPlayerExecuted;
var config stringref srPlayerBledOut;
var config stringref srPlayerRevived;
var config float JoinInProgressDelay;
var WwiseEvent ReviveSound;
var SFXPawn Executioner;
var config int InvalidRagdollStateCounterThreshold;
var config int SyncMovementFailsafeOscillationCountThreshold;
var config float SyncMovementFailsafeSampleTimePeriod;
var config float SyncMovementFailsafeOscillationDistanceThreshold;
var config float HealthFailsafeCheckDelay;
var export SFXCustomizationInstance_PlayerMP CustomizationMP;
var bool bValidExecutionTarget;
var bool bDisplayedKilledMessage;
var transient bool bIsProcessingFellOutOfWorld;

// Functions
public simulated function BioBaseRemovedFromWorld();

public event simulated function bool CanDoCustomAction(int CAction, optional Pawn Sync, optional bool bForced, optional int PowerCustomAction)
{
    if (!bFullyInitializedMP)
    {
        return FALSE;
    }
    return Super(BioPawn).CanDoCustomAction(CAction, Sync, bForced, PowerCustomAction);
}
public simulated function CopyPawnAppearance(BioPawn SourcePawn)
{
    local SFXPawn_PlayerMP SourcePlayer;
    local int Tint1;
    local int Tint2;
    local int Pattern;
    local int PatternColor;
    local int Phong;
    local int Emissive;
    local int SkinTone;
    
    SourcePlayer = SFXPawn_PlayerMP(SourcePawn);
    if (SourcePlayer != None)
    {
        SourcePlayer.GetMPAppearanceVariables(Tint1, Tint2, Pattern, PatternColor, Phong, Emissive, SkinTone);
        SetMPAppearanceVariables(Tint1, Tint2, Pattern, PatternColor, Phong, Emissive, SkinTone);
    }
}
public simulated function Destroyed()
{
    local SFXPowerCustomAction_CombatDrone Power_Drone;
    local SFXPowerCustomAction_SentryTurret Power_Turret;
    local SFXPowerCustomAction_Decoy Power_Decoy;
    local string PlayerLeftMessage;
    local SFXMPEventTicker EventTicker;
    
    if (Role == ENetRole.ROLE_Authority)
    {
        Power_Drone = SFXPowerCustomAction_CombatDrone(PowerCustomActions[31]);
        if (Power_Drone != None)
        {
            Power_Drone.DespawnDrone(Power_Drone.Drone);
        }
        Power_Turret = SFXPowerCustomAction_SentryTurret(PowerCustomActions[32]);
        if (Power_Turret != None)
        {
            Power_Turret.DespawnTurret(Power_Turret.Turret);
        }
        Power_Decoy = SFXPowerCustomAction_Decoy(PowerCustomActions[52]);
        if (Power_Decoy != None)
        {
            Power_Decoy.DespawnDecoy(Power_Decoy.DecoyPawn);
        }
    }
    if (PlayerReplicationInfo != None)
    {
        ClearCustomTokens();
        SetCustomToken(0, PlayerReplicationInfo.PlayerName);
        PlayerLeftMessage = GetTokenisedString(srPlayerLeft);
        EventTicker = SFXGRI(WorldInfo.GRI).GetEventTicker();
        if (EventTicker != None)
        {
            EventTicker.AddTickerEntry(PlayerLeftMessage);
        }
    }
    SetHidden(TRUE);
    Super.Destroyed();
}
public simulated function FellOutOfWorld(Class<DamageType> dmgType)
{
    FellOutOfWorldImpl();
}
public function string GetActorGameName()
{
    return PlayerReplicationInfo.PlayerName;
}
public simulated function bool InCombat()
{
    return Super(BioPawn).InCombat() || bCombatPawn;
}
public function bool IsTestFrameworkSetupComplete()
{
    if (!Super.IsTestFrameworkSetupComplete())
    {
        return FALSE;
    }
    if (PlayerReplicationInfo == None)
    {
        return FALSE;
    }
    if (IsTimerActive('LoadWeapons'))
    {
        return FALSE;
    }
    if (Weapon == None)
    {
        return FALSE;
    }
    return TRUE;
}
public simulated function OutsideWorldBounds()
{
    FellOutOfWorldImpl();
}
public simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    LoadPowerData();
    bRecentlyResurrected = TRUE;
    DeferredPostBeginPlay();
    DeferredSetRichPresence();
    if (WorldInfo.bIsLobbyLevel)
    {
        SetHidden(TRUE);
    }
    if (Role == ENetRole.ROLE_Authority && HealthFailsafeCheckDelay >= float(0))
    {
        SetTimer(HealthFailsafeCheckDelay, TRUE, 'HealthFailsafe', );
    }
}
public simulated function PreClientTravel()
{
    local SFXModule_DamagePlayer DmgPlayer;
    local SFXModule_GameEffectManager Manager;
    
    DmgPlayer = GetModule(Class'SFXModule_DamagePlayer');
    DmgPlayer.RecoverFromBleedout();
    Manager = GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        Manager.RemoveEffectsByDuration(1);
    }
}
public event simulated function ReplicatedEvent(Name VarName)
{
    switch (VarName)
    {
        case 'PlayerReplicationInfo':
            if (PlayerReplicationInfo != None)
            {
                SFXPRIMP(PlayerReplicationInfo).SetPawn(Self);
            }
            break;
        case 'ReplicatedDeathInfo':
            if (ReplicatedDeathInfo.KillerPawn != None)
            {
                PlayerKilledMessage();
            }
            break;
        default:
    }
    Super.ReplicatedEvent(VarName);
}
public event function bool Resurrect(float PercentOfHealthRegained, bool bIsInstantaneous)
{
    if (SFXGRIMP(WorldInfo.GRI).GameStatus != EGameStatus.GS_MatchInProgress)
    {
        return FALSE;
    }
    if (!Super(SFXPawn_PlayerParty).Resurrect(PercentOfHealthRegained, bIsInstantaneous))
    {
        return FALSE;
    }
    TimeOfDeath = 0.0;
    bIsDead = FALSE;
    PermaDeadChanged();
    ClearTimer('PermaDeath');
    return TRUE;
}
public simulated function StopLoadingMovie()
{
    local SFXPlayerControllerMP PC;
    
    PC = SFXPlayerControllerMP(Controller);
    PC.GameModeManager2.DisableMode(9);
    PC.StopLoadingMovie();
    if ((Class'WorldInfo'.static.IsConsoleBuild() && PC.ProfileSettings != None) && PC.ForceFeedbackManager != None)
    {
        PC.ForceFeedbackManager.bAllowsForceFeedback = PC.ProfileSettings.GetControllerVibrationOption();
    }
    ClearTimer('StopLoadingMovie');
    if (PC != None)
    {
        PC.bIgnoreMoveInput = 0;
        PC.bIgnoreLookInput = 0;
        if (PC.IsInState('PlayerWalking', ) == FALSE && PC.IsInState('InLobby', ) == FALSE)
        {
            PC.GotoState('PlayerWalking', , , );
        }
    }
}
public simulated function Tick(float DeltaTime)
{
    Super(BioPawn).Tick(DeltaTime);
    if (Role == ENetRole.ROLE_Authority)
    {
        if (Abs(location.Z - SyncMovementFailsafeInfo.LastZLocation) > SyncMovementFailsafeOscillationDistanceThreshold)
        {
            ProcessSyncMovementFailsafe();
        }
        else if (SyncMovementFailsafeInfo.IsActive && WorldInfo.TimeSeconds - SyncMovementFailsafeInfo.ActiveStartTime > SyncMovementFailsafeSampleTimePeriod)
        {
            ResetSyncMovementFailsafeInfo();
        }
        SyncMovementFailsafeInfo.LastZLocation = location.Z;
    }
}
public event function Touch(Actor Other, PrimitiveComponent OtherComp, Vector HitLocation, Vector HitNormal)
{
    local Volume V;
    local SFXGUI_MPHUD oHud;
    
    Super(Actor).Touch(Other, OtherComp, HitLocation, HitNormal);
    V = Volume(Other);
    if (V != None && V.LocationNameStrref != 0)
    {
        if (SFXPlayerControllerMP(Controller) != None)
        {
            oHud = SFXPlayerControllerMP(Controller).GetMPHUD();
        }
        if (oHud != None)
        {
            oHud.DisplaySubareaText(V.LocationNameStrref);
        }
    }
}
public simulated function UpdateAppearance()
{
    CustomizationMP.ApplyMaterialTinting(Self);
}
public function bool Died(Controller Killer, Class<DamageType> DamageType, Vector HitLocation)
{
    local bool ToRet;
    // MILAN CHANGE - Mgamerz - 2026-09-23
    // Read the lethal sync-kill damage type so its attacker can be credited as the executioner.
    // Set execution credit only when a sync-kill damage event actually kills the player.
    local Class<SFXDamageType> MPDamageType;


    MPDamageType = Class<SFXDamageType>(DamageType);
    if (Killer != None && Killer.Pawn != None && MPDamageType != None && MPDamageType.default.bMPKillDamage)
    {
        Executioner = SFXPawn(Killer.Pawn);
    }
    // END MILAN CHANGE

    ToRet = Super.Died(Killer, DamageType, HitLocation);
    ReplicatedDeathInfo.KillerPawn = Killer.Pawn;
    PlayerKilledMessage();
    TimeOfDeath = WorldInfo.GameTimeSeconds;
    if (!IsLocallyControlled())
    {
        SetTimer(((fPermaDeathTimer + Class'SFXGameModeDying'.static.GetTotalPossibleBoost()) + fTimeToRevive) + 1.0, FALSE, 'PermaDeath', );
    }
    ClearTimer('ResurrectionTimer');
    bRecentlyResurrected = FALSE;
    return ToRet;
}
public function PossessedBy(Controller C, bool bVehicleTransition)
{
    Super.PossessedBy(C, bVehicleTransition);
    SFXPRIMP(PlayerReplicationInfo).SetPawn(Self);
}
public function ApplyCustomizationToActor(Actor InTarget, optional SFXCustomizationInstance InSettings = None, optional int UIWorldConfigFlags = 0)
{
    if (InSettings == None)
    {
        InSettings = CustomizationMP;
    }
    InSettings.ApplyMaterialTinting(InTarget);
}
public function AttemptKillingBlow(Pawn Killer)
{
    local SFXGUI_PlayerCountdown movie;
    
    if (Killer != None)
    {
        if ((Executioner == Killer && IsInState('Downed', )) && IsTimerActive('PermaDeath'))
        {
            ClearTimer('PermaDeath');
            if (Role == ENetRole.ROLE_Authority)
            {
                ServerPermaDeath();
            }
            else
            {
                movie = GetPlayerCountdownMovie(BioPlayerController(Controller));
                if (movie != None)
                {
                    movie.AbortAnimation(0);
                }
            }
        }
    }
}
public function AutoMapPC()
{
    local SFXGUIInteraction oGM;
    local SFXSFHandler_PCPowerWheel oPowerWheel;
    local SFXPowerCustomActionBase oPower;
    local BioPlayerController BPC;
    local int i;
    local int J;
    local array<Name> PowerHotkeyAssignments;
    
    BPC = BioPlayerController(Controller);
    oGM = Class'SFXGUIInteraction'.static.GetInstance();
    oPowerWheel = SFXSFHandler_PCPowerWheel(oGM.GetMovie(BPC, oGM.MovieTag_PowerWheel));
    if ((oGM == None || oPowerWheel == None) || BPC == None)
    {
        return;
    }
    oPowerWheel.SetupPlayerPowers();
    PowerHotkeyAssignments.Length = 8;
    if (PlayerClass != None)
    {
        for (i = 0; i < 3; i++)
        {
            oPower = PowerManager.GetPowerByClass(PlayerClass.SquadScreenPowerOrder[i]);
            if (oPower != None)
            {
                PowerHotkeyAssignments[i] = oPower.PowerName;
            }
        }
    }
    PowerHotkeyAssignments[4] = 'Consumable_Rocket';
    PowerHotkeyAssignments[5] = 'Consumable_Shield';
    PowerHotkeyAssignments[6] = 'Consumable_Revive';
    PowerHotkeyAssignments[7] = 'Consumable_Ammo';
    for (i = 0; i < oPowerWheel.m_aPowerIcons.Length; i++)
    {
        oPower = oPowerWheel.m_aPowerIcons[i].pPower;
        // MILAN change DropTheSquid 12/10/2023
        // added a None check to avoid a whole bunch of None Accesses that clog up the logs for no good reason.
        if (oPower == None)
        {
            continue;
        }
        // END MILAN
        for (J = 0; J < PowerHotkeyAssignments.Length; J++)
        {
            if (PowerHotkeyAssignments[J] == oPower.PowerName)
            {
                oPowerWheel.NewSetQuickSlotPower(J, i, TRUE, TRUE);
                break;
            }
        }
    }
}
public function AutoMapXbox()
{
    local BioPlayerInput BPI;
    
    BPI = BioPlayerInput(BioPlayerController(Controller).PlayerInput);
    BPI.m_nmMappedPower4 = 'SFXPowerCustomActionMP_Consumable_Rocket';
    BPI.m_nmMappedPower5 = 'SFXPowerCustomActionMP_Consumable_Shield';
    BPI.m_nmMappedPower6 = 'SFXPowerCustomActionMP_Consumable_Revive';
    BPI.m_nmMappedPower7 = 'SFXPowerCustomActionMP_Consumable_Ammo';
    Super.AutoMapXbox();
}
public simulated function bool CanPlayDeathEffect()
{
    return FALSE;
}
public function CreateWeapons(SFXLoadoutData ChkLoadout, optional bool bForceFromEngineLoadout)
{
    LoadWeapons();
}
public simulated function DeferredPostBeginPlay()
{
    local SFXSimpleUseModule UseModule;
    local string CharacterName;
    local Name CharacterKit;
    local string PlayerJoinedMessage;
    local stringref ClassPrettyName;
    local int Level;
    local int PawnTint1ID;
    local int PawnTint2ID;
    local int PawnPatternID;
    local int PawnPatternColorID;
    local int PawnPhongID;
    local int PawnEmissiveID;
    local int PawnSkinToneID;
    local int n7Rating;
    local float XP;
    local SFXModule_WeaponModManager Manager;
    local SFXModule_DamagePlayer DmgMod;
    local SFXPRIMP oPRI;
    local SFXGRIMP GRI;
    local SFXMPEventTicker EventTicker;
    local bool bInvReadyToInit;
    local SFXOnlineSubsystem OnlineSubsystem;
    local ISFXOnlineComponentGame OnlineGame;
    local bool bOnlineGameIsValid;
    local SFXPlayerControllerMP PC;
    local SFXEngine oEngine;
    local bool bLoadingMoviePlaying;
    
    OnlineSubsystem = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem();
    if (OnlineSubsystem != None)
    {
        OnlineGame = OnlineSubsystem.GetComponentGame();
        if (OnlineGame != None && OnlineGame.GetPlayerCount() > 0)
        {
            bOnlineGameIsValid = TRUE;
        }
    }
    PC = SFXPlayerControllerMP(Controller);
    oPRI = SFXPRIMP(PlayerReplicationInfo);
    bInvReadyToInit = (SFXInventoryManager(InvManager) != None && SFXInventoryManager(InvManager).IsClientReadyToInitialize()) && ((Role != ENetRole.ROLE_SimulatedProxy || oPRI != None && oPRI.bIsReplicationValid_CharacterWeapons) || bOnlineGameIsValid == FALSE);
    if ((((oPRI != None && WorldInfo != None) && WorldInfo.GRI != None) && Weapon != None) && bInvReadyToInit)
    {
        SetWeaponImmediately(SFXWeapon(Weapon));
        oPRI.GetCharacterData(CharacterName, CharacterKit, ClassPrettyName, Level, XP, n7Rating);
        oPRI.GetAppearanceData(PawnTint1ID, PawnTint2ID, PawnPatternID, PawnPatternColorID, PawnPhongID, PawnEmissiveID, PawnSkinToneID);
        oPRI.NametagColor = RegularNametagColor;
        firstName = CharacterName;
        CharacterLevel = Level;
        TotalXP = XP;
        CustomizationMP.Tint1ID = PawnTint1ID;
        CustomizationMP.Tint2ID = PawnTint2ID;
        CustomizationMP.PatternID = PawnPatternID;
        CustomizationMP.PatternColorID = PawnPatternColorID;
        CustomizationMP.PhongID = PawnPhongID;
        CustomizationMP.EmissiveID = PawnEmissiveID;
        CustomizationMP.SkinToneID = PawnSkinToneID;
        UpdateAppearance();
        UseModule = GetModule(Class'SFXSimpleUseModule');
        if (UseModule != None)
        {
            UseModule.m_GameName = GetHumanReadableName();
        }
        LoadWeaponModData();
        Manager = Weapon.GetModule(Class'SFXModule_WeaponModManager');
        Manager.SetWeaponModHidden(FALSE);
        if (!WorldInfo.bIsLobbyLevel)
        {
            oPRI.ApplyMatchConsumableGameEffects(Self);
        }
        ClearTimer('DeferredPostBeginPlay');
        SetHidden(FALSE);
        if (Role == ENetRole.ROLE_Authority)
        {
            if (PC != None && !PC.bIsJoinInProgress)
            {
                SetTimer(fPostResInvulnerability, FALSE, 'ResurrectionTimer', );
            }
            else
            {
                SetTimer(JoinInProgressDelay + fPostResInvulnerability, FALSE, 'ResurrectionTimer', );
            }
        }
        if ((IsLocallyControlled() && SFXPlayerControllerMP(Controller) != None) && !WorldInfo.bIsLobbyLevel)
        {
            oEngine = SFXEngine(Class'Engine'.static.GetEngine());
            bLoadingMoviePlaying = (oEngine != None && oEngine.LoadMovieManager != None) && oEngine.LoadMovieManager.IsLoadingMoviePlaying();
            GRI = SFXGRIMP(WorldInfo.GRI);
            if (((bOnlineGameIsValid == TRUE && GRI != None) && GRI.IsJoinInProgress()) && bLoadingMoviePlaying)
            {
                SetTimer(JoinInProgressDelay, FALSE, 'StopLoadingMovie', );
            }
            else
            {
                StopLoadingMovie();
            }
        }
        ClearCustomTokens();
        SetCustomToken(0, oPRI.PlayerName);
        PlayerJoinedMessage = GetTokenisedString(srPlayerJoined);
        EventTicker = SFXGRI(WorldInfo.GRI).GetEventTicker();
        if (EventTicker != None)
        {
            EventTicker.AddTickerEntry(PlayerJoinedMessage);
        }
        DmgMod = GetModule(Class'SFXModule_DamagePlayer');
        if (DmgMod != None)
        {
            DmgMod.RecoverFromBleedout();
        }
        if (InvalidRagdollStateCounterThreshold > 0)
        {
            SetTimer(1.0, TRUE, 'RagdollFailsafe', );
        }
        bFullyInitializedMP = TRUE;
    }
    else
    {
        SetTimer(0.100000001, FALSE, 'DeferredPostBeginPlay', );
    }
}
public simulated function string GetFullName()
{
    return firstName;
}
public function Name GetUIAppearanceTag()
{
    return Kit;
}
public simulated function IsDeadUpdated()
{
    if (WorldInfo.GRI == None)
    {
        SetTimer(0.100000001, FALSE, 'IsDeadUpdated', );
        return;
    }
    Super(BioPawn).IsDeadUpdated();
    PermaDeadChanged();
    ClearTimer('IsDeadUpdated');
}
public function bool IsReadyForExecution(SFXPawn Killer)
{
    return (bValidExecutionTarget && !bIsDead) && (Executioner == None || Executioner == Killer);
}
public function LoadWeapons()
{
    local int idx;
    local int NumWeaponCreated;
    local int WeaponLevel;
    local Class<SFXWeapon> SelectedWeaponClass;
    local SFXWeapon W;
    local SFXPRIMP oPRI;
    local Name WeaponClassPath;
    
    oPRI = SFXPRIMP(PlayerReplicationInfo);
    ClearTimer('LoadWeapons');
    if (oPRI == None)
    {
        SetTimer(0.100000001, FALSE, 'LoadWeapons', );
        return;
    }
    foreach InvManager.InventoryActors(Class'SFXWeapon', W)
    {
        InvManager.RemoveFromInventory(W);
        W.Destroy();
    }
    for (idx = 0; idx < 2; ++idx)
    {
        oPRI.GetWeapon(idx, WeaponClassPath);
        if (WeaponClassPath != 'None')
        {
            SelectedWeaponClass = Class'SFXPlayerSquadLoadoutData'.static.FindWeaponClass(WeaponClassPath);
            if (SelectedWeaponClass != None)
            {
                CreateWeapon(SelectedWeaponClass);
            }
            NumWeaponCreated++;
            continue;
        }
        break;
    }
    if (NumWeaponCreated == 0)
    {
        Super(BioPawn).CreateWeapons(Loadout);
        idx = 0;
        foreach InvManager.InventoryActors(Class'SFXWeapon', W)
        {
            WeaponClassPath = Name(PathName(W.Class));
            WeaponLevel = oPRI.GetWeaponLevel(WeaponClassPath);
            oPRI.SetWeapon(idx, WeaponClassPath, WeaponLevel);
            idx++;
            if (idx >= 2)
            {
                break;
            }
        }
    }
    SFXInventoryManager(InvManager).SetWeaponBySelected();
    UpdateWeaponEncumbrance();
    PowerManager.OnPawnLoadedWeapons();
}
public function PermaDeath()
{
    local SFXGUI_PlayerCountdown movie;
    // MILAN CHANGE - Mgamerz - 2026-09-23
    // Track damage type
    local Class<SFXDamageType> MPDamageType;
    // END MILAN CHANGE
    
    movie = GetPlayerCountdownMovie(BioPlayerController(Controller));
    if (movie != None)
    {
        movie.AbortAnimation(0);
    }

    // MILAN CHANGE - Mgamerz - 2026-09-23
    // Only clear execution intent for a real bleedout; sync kills use the short death-flourish timer instead
    MPDamageType = Class<SFXDamageType>(KilledByDamageType);
    if (MPDamageType == None || !MPDamageType.default.bMPKillDamage)
    {
        Executioner = None;
    }
    // END MILAN CHANGE

    ServerPermaDeath();
}
public simulated function PlayerRevivedMessage()
{
    local string TickerMessage;
    
    if (Reviver == None || IsInState('Downed', ))
    {
        Reviver = None;
        return;
    }
    ClearCustomTokens();
    SetCustomToken(0, Reviver.PlayerReplicationInfo.PlayerName);
    SetCustomToken(1, PlayerReplicationInfo.PlayerName);
    TickerMessage = GetTokenisedString(srPlayerRevived);
    SFXGRI(WorldInfo.GRI).GetEventTicker().AddTickerEntry(TickerMessage);
}
public function SetExecutioner(Pawn Killer)
{
    Executioner = SFXPawn(Killer);
}
public simulated function bool ShouldShowHUDGrenadeCounter()
{
    if (WorldInfo.IsConsoleBuild())
    {
        return FALSE;
    }
    else
    {
        return Super.ShouldShowHUDGrenadeCounter();
    }
}
public function bool ShouldTossWeapon(SFXWeapon ChkWeapon, SFXWeapon NewWeapon)
{
    if (Super.ShouldTossWeapon(ChkWeapon, NewWeapon) == TRUE || SFXHeavyWeapon(ChkWeapon) != None)
    {
        return TRUE;
    }
    return FALSE;
}
public simulated function StartRevive(SFXPawn_PlayerParty TargetPawn)
{
    if (SFXPawn_PlayerMP(TargetPawn) == None)
    {
        return;
    }
    Super(SFXPawn_PlayerParty).StartRevive(TargetPawn);
}
public simulated function UpdateGameEffects();

public function UpdateMappedPowerDisplay()
{
    local SFXGUI_MPHUD oHud;
    
    Super.UpdateMappedPowerDisplay();
    if (SFXPlayerControllerMP(Controller) != None)
    {
        oHud = SFXPlayerControllerMP(Controller).GetMPHUD();
    }
    if (oHud != None)
    {
        oHud.Initialize();
    }
}
public function UseReviveConsumablePower()
{
    local BioPlayerController PC;
    local SFXPowerCustomActionMP_Consumable_Revive Revive;
    
    PC = BioPlayerController(Controller);
    if (PC != None && PowerManager != None)
    {
        Revive = SFXPowerCustomActionMP_Consumable_Revive(PowerManager.GetPowerByClass(Class'SFXPowerCustomActionMP_Consumable_Revive'));
        if (Revive != None)
        {
            PC.StartPowerCustomAction(Revive);
        }
    }
}
public simulated function LoadPowerData()
{
    local array<PowerSaveInfo> Powers;
    local int idx;
    local int Idx2;
    local int CurrentRank;
    local SFXPowerCustomActionBase Power;
    local SFXPRIMP oPRI;
    local Name PowerClassPath;
    local int EvolvedChoices[6];
    
    oPRI = SFXPRIMP(PlayerReplicationInfo);
    ClearTimer('LoadPowerData');
    if ((oPRI == None || PowerManager == None) || Role == ENetRole.ROLE_SimulatedProxy && !oPRI.bIsReplicationValid_CharacterPowers)
    {
        SetTimer(0.100000001, FALSE, 'LoadPowerData', );
        return;
    }
    if (!oPRI.VerifyPawnPowers(Self))
    {
        return;
    }
    for (idx = 0; idx < 6; idx++)
    {
        oPRI.GetPower(idx, PowerClassPath, EvolvedChoices, CurrentRank);
        if (PowerClassPath != 'None')
        {
            Powers.Add(1);
            Powers[idx].CurrentRank = float(CurrentRank);
            for (Idx2 = 0; Idx2 < 6; Idx2++)
            {
                if (Idx2 >= 6)
                {
                    break;
                }
                Powers[idx].EvolvedChoices[Idx2] = EvolvedChoices[Idx2];
            }
            Powers[idx].PowerClassName = PowerClassPath;
            continue;
        }
        break;
    }
    PowerManager.LoadPowers(Powers);
    foreach PowerManager.Powers(Power, )
    {
        Power.OnPowersLoaded();
    }
    AdjustInventoryResource(3, SFXInventoryManager(InvManager).GetMaxGrenades(), FALSE);
}
public simulated function LoadWeaponModData()
{
    local int idx;
    local int Idx2;
    local int WeaponModLevel;
    local SFXWeapon CurrWeapon;
    local SFXModule_WeaponModManager Manager;
    local Class<SFXWeaponMod> ModClass;
    local SFXPRIMP oPRI;
    local Name WeaponClassPath;
    local Name WeaponModClassPath;
    
    oPRI = SFXPRIMP(PlayerReplicationInfo);
    if (InvManager == None || oPRI == None)
    {
        return;
    }
    foreach InvManager.InventoryActors(Class'SFXWeapon', CurrWeapon)
    {
        for (idx = 0; idx < 2; idx++)
        {
            oPRI.GetWeapon(idx, WeaponClassPath);
            if (PathName(CurrWeapon.Class) ~= string(WeaponClassPath))
            {
                Manager = CurrWeapon.GetModule(Class'SFXModule_WeaponModManager');
                if (Manager != None)
                {
                    Manager.RemoveAllMods();
                    for (Idx2 = 0; Idx2 < 2; ++Idx2)
                    {
                        oPRI.GetWeaponMod(idx, Idx2, WeaponModClassPath, WeaponModLevel);
                        if (WeaponModClassPath != 'None')
                        {
                            ModClass = Class'SFXWeaponMod'.static.LoadModClass(string(WeaponModClassPath));
                            if (ModClass != None)
                            {
                                Manager.AddMod(ModClass, WeaponModLevel);
                            }
                            continue;
                        }
                        break;
                    }
                }
            }
        }
    }
}
public simulated function PermaDeadChanged()
{
    local string TickerMessage;
    
    if (SFXGRIMP(WorldInfo.GRI).GameStatus != EGameStatus.GS_MatchInProgress)
    {
        return;
    }
    if (bIsDead)
    {
        if (!IsDead())
        {
            bIsDead = FALSE;
            return;
        }
        if (IsLocallyControlled())
        {
            SetTimer(3.0, FALSE, 'StartSpectatorCam', );
        }
        if (Executioner != None)
        {
            ClearCustomTokens();
            SetCustomToken(0, Executioner.GetActorGameName());
            SetCustomToken(1, PlayerReplicationInfo.PlayerName);
            TickerMessage = GetTokenisedString(srPlayerExecuted);
            SFXGRI(WorldInfo.GRI).GetEventTicker().AddTickerEntry(TickerMessage);
        }
        else
        {
            ClearCustomTokens();
            SetCustomToken(0, PlayerReplicationInfo.PlayerName);
            TickerMessage = GetTokenisedString(srPlayerBledOut);
            SFXGRI(WorldInfo.GRI).GetEventTicker().AddTickerEntry(TickerMessage);
        }
        EnableUsage(FALSE);
        if (IsLocallyControlled())
        {
             // MILAN Patched: Remove calls to SFXTelemetry
        }
    }
    else if (IsLocallyControlled())
    {
        Controller.GotoState('PlayerWalking', , , );
    }
    GetModule(Class'SFXModule_MarkerPlayer').PlayerIsDead = bIsDead;
}
public simulated function PlayerKilledMessage()
{
    local string TickerMessage;
    
    if (bDisplayedKilledMessage || ReplicatedDeathInfo.KillerPawn == None)
    {
        return;
    }
    if (ReplicatedDeathInfo.KillerPawn == Self)
    {
        ClearCustomTokens();
        SetCustomToken(0, PlayerReplicationInfo.PlayerName);
        TickerMessage = GetTokenisedString(srPlayerSuicide);
    }
    else
    {
        ClearCustomTokens();
        SetCustomToken(0, PlayerReplicationInfo.PlayerName);
        SetCustomToken(1, SFXPawn(ReplicatedDeathInfo.KillerPawn).GetActorGameName());
        TickerMessage = GetTokenisedString(srPlayerKilled);
    }
    SFXGRI(WorldInfo.GRI).GetEventTicker().AddTickerEntry(TickerMessage);
    bDisplayedKilledMessage = TRUE;
}
public final function ProcessSyncMovementFailsafe()
{
    local float DeltaZ;
    local bool CurrentZDeltaPositive;
    
    DeltaZ = location.Z - SyncMovementFailsafeInfo.LastZLocation;
    if (DeltaZ > 0.0)
    {
        CurrentZDeltaPositive = TRUE;
    }
    if (SyncMovementFailsafeInfo.IsActive)
    {
        if (CurrentZDeltaPositive != SyncMovementFailsafeInfo.ZDeltaPositive)
        {
            SyncMovementFailsafeInfo.ZDeltaPositive = CurrentZDeltaPositive;
            SyncMovementFailsafeInfo.OscillationCount++;
            if (SyncMovementFailsafeOscillationCountThreshold > -1 && SyncMovementFailsafeInfo.OscillationCount > SyncMovementFailsafeOscillationCountThreshold)
            {
                BioPlayerController(Controller).FellOutOfWorld(None);
                ResetSyncMovementFailsafeInfo();
            }
        }
    }
    else
    {
        SyncMovementFailsafeInfo.ZDeltaPositive = FALSE;
        if (DeltaZ > 0.0)
        {
            SyncMovementFailsafeInfo.ZDeltaPositive = TRUE;
        }
        SyncMovementFailsafeInfo.IsActive = TRUE;
        SyncMovementFailsafeInfo.ActiveStartTime = WorldInfo.TimeSeconds;
    }
}
public simulated function RagdollFailsafe()
{
    if ((Physics == EPhysics.PHYS_RigidBody && !IsInState('InRagdoll', )) && !IsInState('Downed', ) || Physics != EPhysics.PHYS_RigidBody && (IsInState('InRagdoll', ) || IsInState('Downed', )))
    {
        ++InvalidRagdollStateCounter;
        if (InvalidRagdollStateCounter > InvalidRagdollStateCounterThreshold)
        {
            if (Physics == EPhysics.PHYS_RigidBody)
            {
                if (!TermRagdoll())
                {
                }
            }
            else
            {
                InvalidRagdollStateCounter = 0;
            }
            EnsurePawnIsUpright(FALSE);
            m_nRemainInRagdoll = 0;
            GotoState('Auto', , , );
        }
    }
}
public final function ResetSyncMovementFailsafeInfo()
{
    SyncMovementFailsafeInfo.IsActive = FALSE;
    SyncMovementFailsafeInfo.ActiveStartTime = 0.0;
    SyncMovementFailsafeInfo.OscillationCount = 0;
}
public reliable server function ServerFellOutOfWorldImpl()
{
    if (Role == ENetRole.ROLE_Authority)
    {
        FellOutOfWorldImpl();
    }
}
public reliable server function ServerPermaDeath()
{
    local SFXModule_Damage DmgMod;
    
    if (SFXGRIMP(WorldInfo.GRI).GameStatus != EGameStatus.GS_MatchInProgress)
    {
        return;
    }
    DmgMod = GetModule(Class'SFXModule_Damage');
    DmgMod.SetCurrentHealth(DmgMod.GetMaxHealth());
    SetCollision(FALSE, FALSE, );
    bIsDead = TRUE;
    PermaDeadChanged();
    SFXPRIMP(PlayerReplicationInfo).NametagColor = PermaDeadNametagColor;
    ClearTimer('PermaDeath');
}
public simulated function SetMPAppearanceVariables(int Tint1, int Tint2, int Pattern, int PatternColor, int Phong, int Emissive, int SkinTone)
{
    CustomizationMP.Tint1ID = Tint1;
    CustomizationMP.Tint2ID = Tint2;
    CustomizationMP.PatternID = Pattern;
    CustomizationMP.PatternColorID = PatternColor;
    CustomizationMP.PhongID = Phong;
    CustomizationMP.EmissiveID = Emissive;
    CustomizationMP.SkinToneID = SkinTone;
    UpdateAppearance();
}
public function StartSpectatorCam()
{
    local SFXModule_DamagePlayer DmgPlayer;
    
    Controller.GotoState('SpectateCam', , , );
    DmgPlayer = GetModule(Class'SFXModule_DamagePlayer');
    DmgPlayer.RecoverFromBleedout();
}
public function CheckEnterCombat();

public simulated function DeferredSetRichPresence()
{
    if (PlayerReplicationInfo != None)
    {
        ClearTimer('DeferredSetRichPresence');
        if (IsLocallyControlled() && BioPlayerController(Controller) != None)
        {
            BioPlayerController(Controller).SetRichPresence();
        }
    }
    else
    {
        SetTimer(0.100000001, FALSE, 'DeferredSetRichPresence', );
    }
}
public event simulated function FellOutOfWorldImpl()
{
    local PlayerController PC;
    
    if (Role == ENetRole.ROLE_Authority)
    {
        PC = PlayerController(Controller);
        if ((PC != None && WorldInfo.Game != None) && bIsProcessingFellOutOfWorld == FALSE)
        {
            Resurrect(1.0, TRUE);
            bIsProcessingFellOutOfWorld = TRUE;
            WorldInfo.Game.RestartPlayer(PC);
        }
    }
    else if (Role == ENetRole.ROLE_AutonomousProxy)
    {
        ServerFellOutOfWorldImpl();
    }
}
public simulated function FinalizeProcessFellOutOfWorld()
{
    if (Anchor != None)
    {
        SetLocation(Anchor.location, );
        SetRotation(Anchor.Rotation);
    }
    MoveActorToFloor();
    BioPlayerController(Controller).CleanOutSavedMoves();
    BioPlayerController(Controller).ClearServerMoveExtrapolation();
    BioPlayerController(Controller).PawnLanded();
    bIsFalling = FALSE;
    bIsProcessingFellOutOfWorld = FALSE;
    bForceNetUpdate = TRUE;
}
public simulated function GetMPAppearanceVariables(out int Tint1, out int Tint2, out int Pattern, out int PatternColor, out int Phong, out int Emissive, out int SkinTone)
{
    Tint1 = CustomizationMP.Tint1ID;
    Tint2 = CustomizationMP.Tint2ID;
    Pattern = CustomizationMP.PatternID;
    PatternColor = CustomizationMP.PatternColorID;
    Phong = CustomizationMP.PhongID;
    Emissive = CustomizationMP.EmissiveID;
    SkinTone = CustomizationMP.SkinToneID;
}
public final function HealthFailsafe()
{
    local SFXModule_Damage DmgMod;
    
    DmgMod = GetModule(Class'SFXModule_Damage');
    if (DmgMod != None)
    {
        if (DmgMod.GetCurrentHealth() <= float(0) && !IsDead())
        {
            Died(Controller, None, vect(0.0, 0.0, 0.0));
        }
    }
}

// States
simulated state Downed 
{
    // State Functions
    public event simulated function FellOutOfWorld(Class<DamageType> dmgType)
    {
        FellOutOfWorldImpl();
    }
    public function ReadyForExecution()
    {
        bValidExecutionTarget = TRUE;
    }
    public event simulated function EndState(Name NextStateName)
    {
        local SFXPlayerControllerMP MPC;
        local BioPlayerController PC;
        local SFXGUI_PlayerCountdown movie;
        
        ClearTimer('PermaDeath');
        ClearTimer('StartSpectatorCam');
        MPC = SFXPlayerControllerMP(Controller);
        if (MPC != None && MPC.myHUD != None)
        {
            MPC.myHUD.bShowHUD = TRUE;
        }
        PC = BioPlayerController(Controller);
        if (PC != None)
        {
            PC.ClearPlayerOrder();
        }
        movie = GetPlayerCountdownMovie(PC);
        if (movie != None)
        {
            movie.AbortAnimation(0);
        }
        SFXPRIMP(PlayerReplicationInfo).NametagColor = RegularNametagColor;
        Super.EndState(NextStateName);
        SetCollision(TRUE, TRUE, );
        if (Controller != None)
        {
            Controller.GotoState('PlayerWalking', , , );
        }
        if (IsLocallyControlled() && SFXGRIMP(WorldInfo.GRI).GameStatus == EGameStatus.GS_MatchInProgress)
        {
            PlaySound(ReviveSound, TRUE);
        }
        GetModule(Class'SFXModule_MarkerPlayer').UpdatePlayerDownState(FALSE);
        bValidExecutionTarget = FALSE;
        ReplicatedDeathInfo.KillerPawn = None;
        bDisplayedKilledMessage = FALSE;
    }
    public event simulated function BeginState(Name PreviousStateName)
    {
        local Controller OldController;
        local SFXPlayerControllerMP MPC;
        local SFXPRIMP PRI;
        local BioPawn Speaker;
        local SFXGRIMP GRI;
        local string PlayerDownPopup;
        local SFXModule_Timeline TimelineMod;
        local Class<SFXDamageType> DamageType;
        local bool bInstantDeath;
        local SFXDifficultyHandler DH;
        
        OldController = Controller;
        MPC = SFXPlayerControllerMP(Controller);
        Super.BeginState(PreviousStateName);
        if (CurrentCustomAction != 3)
        {
            InterruptCustomAction();
        }
        SetCollision(TRUE, FALSE, );
        Controller = OldController;
        if (Controller != None)
        {
            Controller.GotoState('Dying', , , );
        }
        if (Role == ENetRole.ROLE_SimulatedProxy && Weapon != None)
        {
            Weapon.StopFireEffects(Weapon.CurrentFireMode);
        }
        TimelineMod = GetModule(Class'SFXModule_Timeline');
        if (TimelineMod != None)
        {
            TimelineMod.RemoveAllTimelines();
        }
        if (MPC != None && MPC.myHUD != None)
        {
            MPC.myHUD.bShowHUD = FALSE;
        }
        bInstantDeath = FALSE;
        DamageType = Class<SFXDamageType>(KilledByDamageType);
        if (DamageType != None && DamageType.default.bMPKillDamage)
        {
            bInstantDeath = TRUE;
        }
        if (!bInstantDeath)
        {
            SFXPRIMP(PlayerReplicationInfo).NametagColor = DownedNametagColor;
            PRI = SFXPRIMP(PlayerReplicationInfo);
            if (PRI != None)
            {
                ClearCustomTokens();
                SetCustomToken(0, PRI.PlayerName);
                PlayerDownPopup = GetTokenisedString(srPlayerDownPopup);
                if (!IsLocallyControlled())
                {
                    SFXPlayerController(WorldInfo.GetALocalPlayerController()).DisplayTextPopup(PlayerDownPopup);
                    Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound('MPFallenSquadMember');
                }
            }
        }
        GRI = SFXGRIMP(WorldInfo.GRI);
        Speaker = BioPawn(GRI.NextLivingPlayer());
        if (Speaker != None)
        {
            GRI.TriggerVocalizationEvent(15, Speaker, Self);
        }
        GRI.GetScoreManager().PlayerDown();
        TimeOfDeath = WorldInfo.GameTimeSeconds;
        if (IsLocallyControlled())
        {
            if (bInstantDeath)
            {
                SetTimer(DeathFlourishDuration, FALSE, 'PermaDeath', );
            }
            else
            {
                SetTimer(fPermaDeathTimer, FALSE, 'PermaDeath', );
            }
        }
        if (!bInstantDeath)
        {
            if (MPC != None)
            {
                MPC.GetSFXUIController().CastGetMovie(Class'SFXGUI_PlayerCountdown', MPC, MPC.GetSFXUIController().MovieTag_PlayerCountdown).PlayAnimation(0, fPermaDeathTimer);
            }
            GetModule(Class'SFXModule_MarkerPlayer').UpdatePlayerDownState(TRUE);
            DH = SFXGRI(WorldInfo.GRI).DifficultyHandler;
            if (DH != None)
            {
                SetTimer(DH.GetFloat('AllowExecutionTime', 'MPGlobal'), FALSE, 'ReadyForExecution', );
            }
        }
        if (IsLocallyControlled())
        {
             // MILAN Patched: Remove calls to SFXTelemetry
        }
    }
    
    // State code
    stop;
};

replication
{
    if (bNetDirty && Role == ENetRole.ROLE_Authority)
        Executioner;
    
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=BioDynamicLightEnvironmentComponent Name=BioLightEnvComponent0
    End Template
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=CoverEnterSound0
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=FootstepShakeFF0
    End Template
    Begin Object Class=SFXCustomizationInstance_PlayerMP Name=AppInstanceMP0
    End Object
    Begin Template Class=SFXModule_AimAssistTarget Name=AimAssistMod
        bIgnoreFacing = TRUE
        bHighPriority = TRUE
    End Template
    Begin Template Class=SFXModule_Audio Name=AudioModule
    End Template
    Begin Template Class=SFXModule_Conversation Name=ConvoMod01
        m_bDisableFacefx = TRUE
    End Template
    Begin Template Class=SFXModule_DamagePlayer Name=DmgMod1
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_Gestures Name=GestMod01
        Begin Template Class=BioGestureAnimSetMgr Name=oAnimSetMgr
        End Template
        m_pAnimSetMgr = oAnimSetMgr
    End Template
    Begin Template Class=SFXModule_Locomotion Name=Locomotion0
    End Template
    Begin Template Class=SFXModule_LookAt Name=LookAtMod01
    End Template
    Begin Object Class=SFXModule_MarkerPlayer Name=SFXModule_MarkerObjective0
    End Object
    Begin Template Class=SFXModule_Radar Name=RadarModule
    End Template
    Begin Template Class=SFXModule_Timeline Name=TimelineMod0
    End Template
    Begin Template Class=SFXPowerManager Name=PowerMgr
    End Template
    Begin Template Class=SkeletalMeshComponent Name=BioPawnSkeletalMeshComponent
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=GearMesh0
        ParentAnimComponent = BioPawnSkeletalMeshComponent
        ShadowParent = BioPawnSkeletalMeshComponent
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=HairMesh0
        ParentAnimComponent = BioPawnSkeletalMeshComponent
        ShadowParent = BioPawnSkeletalMeshComponent
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=HeadMesh0
        ParentAnimComponent = BioPawnSkeletalMeshComponent
        ShadowParent = BioPawnSkeletalMeshComponent
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
    End Template
    RegularNametagColor = {R = 1.0, G = 1.0, B = 1.0, A = 1.0}
    PermaDeadNametagColor = {R = 0.400000006, G = 0.400000006, B = 0.400000006, A = 1.0}
    DownedNametagColor = {R = 1.0, G = 0.0, B = 0.0, A = 1.0}
    fPermaDeathTimer = 12.0
    DeathFlourishDuration = 4.0
    srPlayerDownPopup = $618713
    srPlayerJoined = $708941
    srPlayerLeft = $708942
    srPlayerKilled = $718396
    srPlayerSuicide = $722513
    srPlayerExecuted = $718397
    srPlayerBledOut = $718419
    srPlayerRevived = $661135
    JoinInProgressDelay = 10.0
    ReviveSound = WwiseEvent'Wwise_GUI_MultiPlayer_Specific.Play_MPPlayerRevived'
    InvalidRagdollStateCounterThreshold = 5
    SyncMovementFailsafeOscillationCountThreshold = 3
    SyncMovementFailsafeSampleTimePeriod = 0.25
    SyncMovementFailsafeOscillationDistanceThreshold = 50.0
    HealthFailsafeCheckDelay = 3.0
    CustomizationMP = AppInstanceMP0
    CoverForceFeedback = CoverEnterSound0
    FootstepForceFeedback = FootstepShakeFF0
    bCanBeEaten = TRUE
    HeadMesh = HeadMesh0
    m_oHairMesh = HairMesh0
    m_oHeadGearMesh = GearMesh0
    LightEnvironment = BioLightEnvComponent0
    PowerManager = PowerMgr
    bSpawnPHATInstance = TRUE
    bCanBeReaped = FALSE
    bCanPortArms = FALSE
    bShouldSpawnWeapons = TRUE
    Mesh = BioPawnSkeletalMeshComponent
    CylinderComponent = CollisionCylinder
    Components = (CollisionCylinder, None, BioLightEnvComponent0, BioPawnSkeletalMeshComponent, HeadMesh0, HairMesh0, GearMesh0)
    Modules = (GEMod0, 
               RadarModule, 
               AimAssistMod, 
               GestMod01, 
               ConvoMod01, 
               LookAtMod01, 
               AudioModule, 
               TimelineMod0, 
               Locomotion0, 
               DmgMod1, 
               SFXModule_MarkerObjective0
              )
    NetPriority = 1.79999995
    CollisionComponent = CollisionCylinder
    bHidden = TRUE
}
