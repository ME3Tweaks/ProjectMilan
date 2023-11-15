Class SFXCheatManagerNonNativeMP extends BioCheatManagerNonNative within BioPlayerController
    transient
    config(Game);

// Variables
var config array<string> DisplayPools;

// Functions
public function ProfileMPGame()
{
    local SFXWave_Horde HordeCurrentWave;
    local SFXWave_Operation Operation;
    local SFXWaveCoordinator_HordeOperation WaveCoordinator;
    local int idx;
    local SFXPawn ChkPawn;
    local string EnemyName;
    local bool B;
    local SFXEngine Engine;
    local SFXPawn_Player PlayerPawn;
    local SFXScoreManager ScoreManager;
    local SFXPRI PRI;
    local SFXGRI GRI;
    local array<EnemyWaveInfo> EnemiesToSpawn;
    local int EnemyIndex;
    
    Engine = SFXEngine(Class'Engine'.static.GetEngine());
    GRI = SFXGRI(Outer.WorldInfo.GRI);
    PlayerPawn = SFXPawn_Player(ProfileTarget);
    ScoreManager = GRI != None ? GRI.GetScoreManager() : None;
    ScoreManager = ScoreManager == None ? LastScoreManager : ScoreManager;
    LastScoreManager = ScoreManager;
    WaveCoordinator = SFXWaveCoordinator_HordeOperation(GRI.WaveCoordinator);
    if (WaveCoordinator != None)
    {
        HordeCurrentWave = SFXWave_Horde(WaveCoordinator.GetWaveOfType('SFXWave_Horde'));
        Operation = SFXWave_Operation(WaveCoordinator.GetWaveOfType('SFXWave_Operation'));
    }
    if (Engine == None || GRI == None)
    {
        return;
    }
    if (WaveCoordinator != None && Operation != None)
    {
        DrawLine("WaveCoordinator information: ", string(WaveCoordinator));
        DrawLine("    Wave #:", string(WaveCoordinator.CurrentWaveNumber));
        DrawLine("    Wave # [Friendly]:", string(WaveCoordinator.GetFriendlyCurrentWaveNumber()));
        DrawLine("");
        DrawLine("Objective type Active: ", string(WaveCoordinator.OperationWaveType));
        DrawLine("    Current Objective: ", string(Operation));
        DrawLine("Horde type Active: ", string(WaveCoordinator.HordeWaveType));
    }
    else
    {
        DrawLine("WaveCoordinator information: ", string(None));
        DrawLine("    Wave #:", string(0));
        DrawLine("    Wave # [Friendly]:", string(0));
        DrawLine("");
        DrawLine("Objective type Active: ", string(None));
        DrawLine("    Current Objective: ", string(None));
        DrawLine("Horde type Active: ", string(None));
    }
    if (HordeCurrentWave != None)
    {
        DrawLine("    Current Wave: ", string(HordeCurrentWave));
        DrawLine("    Wave Points: ", HordeCurrentWave.EndlessWave ? "Endless" : (HordeCurrentWave.WavePointsRemaining $ " / ") $ HordeCurrentWave.WavePoints);
        DrawLine("    Rush Active: ", string(HordeCurrentWave.bEndRushTriggered));
    }
    else
    {
        DrawLine("    Current Wave: ", string(None));
        DrawLine("    Wave Points: ", string(0));
        DrawLine("    Rush Active: ", string(FALSE));
    }
    DrawLine("");
    DrawLine("Num Enemies Spawned:");
    HordeCurrentWave.GetEnemyArray(EnemiesToSpawn);
    for (idx = 0; idx < EnemiesToSpawn.Length; idx++)
    {
        EnemyIndex = HordeCurrentWave.EnemyList.Find('EnemyType', EnemiesToSpawn[idx].EnemyType);
        if (EnemyIndex != -1)
        {
            DrawLine((((("    Enemy: " $ EnemiesToSpawn[idx].EnemyType) $ " Count: ") $ HordeCurrentWave.NumSpawnedEnemiesByType[EnemyIndex]) $ " Max: ") $ EnemiesToSpawn[idx].MaxPerWave);
        }
    }
    DrawLine("");
    DrawLine("Enemies");
    foreach Outer.WorldInfo.AllPawns(Class'SFXPawn', ChkPawn)
    {
        if (ChkPawn.IsHostile(Outer.Pawn) == FALSE)
        {
            continue;
        }
        EnemyName = Right(string(ChkPawn), Len(string(ChkPawn)) - 8);
        if (ChkPawn.IsDead() == TRUE)
        {
            DrawLine("    Dead: " $ EnemyName);
        }
        B = FALSE;
        for (idx = 0; idx < HordeCurrentWave.EnemiesSpawned.Length; idx++)
        {
            B = B || ChkPawn == HordeCurrentWave.EnemiesSpawned[idx].Enemy;
        }
        if (B)
        {
            DrawLine("    Enemy: " $ EnemyName);
        }
        else
        {
            DrawLine("    Orphan: " $ EnemyName);
        }
    }
    if (PlayerPawn == None)
    {
        return;
    }
    DrawLine("");
    DrawLine("Character Profile for: ", string(PlayerPawn.Tag));
    DrawLine("    Credits: ", string(Engine.MPSaveManager.GetCredits()));
    DrawLine("    Experience: ", string(Engine.MPSaveManager.GetClassRecord(Engine.MPSaveManager.GetCurrentSelectedCharacterRecord().className).GetTotalXP()));
    SetProfileColumn(++CurrentColumn);
    PRI = SFXPRI(PlayerPawn.PlayerReplicationInfo);
    DrawLine("");
    DrawLine("");
    DrawLine("");
    DrawLine("Score: ", "" $ PrettyFloat(PRI.GetTotalPoints(), 0));
    if (ScoreManager != None && PRI != None)
    {
        DrawLine("");
        DrawLine("    Total Enemy Budget (Global): ", PrettyFloat(ScoreManager.EnemyScoreBudget, 0));
        DrawLine("    Enemy Score Awarded (Global): ", PrettyFloat(ScoreManager.TotalEnemyScoreRewarded, 0));
    }
}
public final exec function ReplicationDebugCam()
{
    local SFXPlayerControllerMP PC;
    
    PC = SFXPlayerControllerMP(BioWorldInfo(Class'Engine'.static.GetCurrentWorldInfo()).GetLocalPlayerController());
    if (PC.GetStateName() != 'DebugReplicationCam')
    {
        God();
        PC.GotoState('DebugReplicationCam', , , );
        Outer.ClientMessage("DebugReplicationCam ON");
    }
    else
    {
        God();
        PC.GotoState('Auto', , , );
        SFXPawn_PlayerMP(PC.Pawn).PermaDeadChanged();
        Outer.ClientMessage("DebugReplicationCam OFF");
    }
}
public exec function RestartFromWave(int nWave)
{
    SFXWaveCoordinator_HordeOperation(SFXGRI(Outer.WorldInfo.GRI).WaveCoordinator).GoToWave(nWave);
}
public final exec function CheatCardPack(optional string PackName)
{
    local SFXLocalPlayer LP;
    local SFXGAWReinforcementManager GAWManager;
    local array<CardInfoData> Cards;
    
    LP = SFXLocalPlayer(Outer.Player);
    if (LP == None)
    {
        return;
    }
    GAWManager = SFXGAWReinforcementManager(LP.GAWReinforcementManager);
    if (GAWManager == None)
    {
        return;
    }
    if (PackName == "")
    {
        PackName = "n7";
    }
    Cards = GAWManager.GiveCardPack(PackName);
    if (Cards.Length == 0)
    {
        Outer.ClientMessage("Error: No Cards Awarded");
    }
    else
    {
        Outer.ClientMessage("Pack Awarded: " $ PackName);
    }
}
public final exec function CreditsCardPack(optional string PackName)
{
    local SFXLocalPlayer LP;
    local SFXGAWReinforcementManager GAWManager;
    local array<CardInfoData> Cards;
    local SFXEngine Engine;
    local int PackIdx;
    local array<StoreInfoEntry> StoreInfoArray;
    
    LP = SFXLocalPlayer(Outer.Player);
    if (LP == None)
    {
        return;
    }
    GAWManager = SFXGAWReinforcementManager(LP.GAWReinforcementManager);
    if (GAWManager == None)
    {
        return;
    }
    if (PackName == "")
    {
        PackName = "n7";
    }
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Engine == None)
    {
        Outer.ClientMessage("The SFXEngine is none!");
        return;
    }
    if (Engine.MPSaveManager == None)
    {
        Outer.ClientMessage("The MPSaveManager is none!");
        return;
    }
    StoreInfoArray = GAWManager.GetStoreInfo();
    PackIdx = StoreInfoArray.Find('PackName', PackName);
    if (PackIdx == -1)
    {
        Outer.ClientMessage("Error: No Cards Awarded - Invalid Pack Name: " $ PackName);
        return;
    }
    if (Engine.MPSaveManager.GetCredits() < StoreInfoArray[PackIdx].CreditCost)
    {
        Outer.ClientMessage("Error: No Cards Awarded - Not Enough Credits: " $ PackName);
        return;
    }
    Cards = GAWManager.GiveCardPack(PackName);
    if (Cards.Length == 0)
    {
        Outer.ClientMessage("Error: No Cards Awarded");
    }
    else
    {
        Engine.MPSaveManager.SubtractCredits(StoreInfoArray[PackIdx].CreditCost);
        Outer.ClientMessage("Pack Awarded: " $ PackName);
    }
}
public final exec function DebugMatchConsumables()
{
    local SFXLocalPlayer LP;
    local int idx;
    local int Idx2;
    local SFXGAWReinforcementMatchConsumable CurrConsumable;
    local SFXGAWReinforcementManager GAWManager;
    
    LP = SFXLocalPlayer(Outer.Player);
    if (LP == None)
    {
        return;
    }
    GAWManager = SFXGAWReinforcementManager(LP.GAWReinforcementManager);
    if (GAWManager == None)
    {
        return;
    }
    for (idx = 0; idx < GAWManager.MatchConsumables.Length; idx++)
    {
        CurrConsumable = GAWManager.MatchConsumables[idx];
        for (Idx2 = 0; Idx2 < CurrConsumable.CardList.Length; Idx2++)
        {
            if (Class'SFXEngine'.static.GetStrFromSFXUniqueID(CurrConsumable.GetCardUniqueID(Idx2)) == "SFXGameMPContent.SFXGameEffect_MatchConsumable_AmmoPower_Cryo" && float(CurrConsumable.CardList[Idx2].VersionIdx) == 1.0)
            {
                CurrConsumable.Activate(CurrConsumable.GetCardUniqueID(Idx2), float(CurrConsumable.CardList[Idx2].VersionIdx));
            }
        }
    }
}
public exec function EndCurrentWave()
{
    SFXGRI(Outer.WorldInfo.GRI).WaveCoordinator.FinishActiveWaves();
}
public final exec function GiveAllMatchConsumables()
{
    local SFXLocalPlayer LP;
    local int idx;
    local int Idx2;
    local int Version;
    local SFXGAWReinforcementMatchConsumable CurrConsumable;
    local string Consumable;
    local Name ConsumableVar;
    local SFXEngine Engine;
    local SFXGAWReinforcementManager GAWManager;
    
    LP = SFXLocalPlayer(Outer.Player);
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    GAWManager = SFXGAWReinforcementManager(LP.GAWReinforcementManager);
    if ((LP == None || GAWManager == None) || Engine == None)
    {
        return;
    }
    for (idx = 0; idx < GAWManager.MatchConsumables.Length; idx++)
    {
        CurrConsumable = GAWManager.MatchConsumables[idx];
        for (Idx2 = 0; Idx2 < CurrConsumable.CardList.Length; Idx2++)
        {
            Consumable = Class'SFXEngine'.static.GetStrFromSFXUniqueID(CurrConsumable.GetCardUniqueID(Idx2));
            Version = CurrConsumable.CardList[Idx2].VersionIdx;
            ConsumableVar = Name((Consumable $ "_") $ Version);
            if (Engine.MPSaveManager.GetPlayerVariable(ConsumableVar) <= 0)
            {
                Engine.MPSaveManager.SetPlayerVariable(ConsumableVar, 1);
            }
        }
    }
}
public final exec function GiveAmmoConsumable(int Quantity)
{
    local SFXEngine Engine;
    local int currentCount;
    
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Engine == None)
    {
        return;
    }
    currentCount = Engine.GetPlayerVariable(Name("SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Ammo"));
    Engine.SetPlayerVariable(Name("SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Ammo"), currentCount + Quantity);
}
public final exec function GiveMPConsumables(int Quantity)
{
    GiveAmmoConsumable(Quantity);
    GiveReviveConsumable(Quantity);
    GiveRocketConsumable(Quantity);
    GiveShieldConsumable(Quantity);
}
public final exec function GiveReviveConsumable(int Quantity)
{
    local SFXEngine Engine;
    local int currentCount;
    
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Engine == None)
    {
        return;
    }
    currentCount = Engine.GetPlayerVariable(Name("SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Revive"));
    Engine.SetPlayerVariable(Name("SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Revive"), currentCount + Quantity);
}
public final exec function GiveRocketConsumable(int Quantity)
{
    local SFXEngine Engine;
    local int currentCount;
    
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Engine == None)
    {
        return;
    }
    currentCount = Engine.GetPlayerVariable(Name("SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Rocket"));
    Engine.SetPlayerVariable(Name("SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Rocket"), currentCount + Quantity);
}
public final exec function GiveShieldConsumable(int Quantity)
{
    local SFXEngine Engine;
    local int currentCount;
    
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Engine == None)
    {
        return;
    }
    currentCount = Engine.GetPlayerVariable(Name("SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Shield"));
    Engine.SetPlayerVariable(Name("SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Shield"), currentCount + Quantity);
}
public final exec function LoadDeck()
{
    local SFXLocalPlayer LP;
    local SFXGAWReinforcementManager GAWManager;
    
    LP = SFXLocalPlayer(Outer.Player);
    if (LP == None)
    {
        return;
    }
    GAWManager = SFXGAWReinforcementManager(LP.GAWReinforcementManager);
    if (GAWManager == None)
    {
        return;
    }
    GAWManager.LoadDeck();
}
public final exec function PlayHordeLine(string EventName, int Index)
{
    local SFXGRI GRI;
    local SFXWaveCoordinator_HordeOperation Horde;
    
    GRI = SFXGRI(Outer.WorldInfo.GRI);
    if (GRI != None)
    {
        Horde = SFXWaveCoordinator_HordeOperation(GRI.WaveCoordinator);
        if (Horde != None)
        {
            PlayLine(Horde.SimpleDialogPlayer, EventName, Index);
        }
    }
}
public final exec function PlayObjectiveLine(string EventName, int ObjectiveIndex, int LineIndex)
{
    local int i;
    local SFXGRI GRI;
    local Actor oActor;
    local SFXOperationObjective ObjectiveActor;
    local SFXWave_Operation OperationWave;
    
    GRI = SFXGRI(Outer.WorldInfo.GRI);
    if (GRI != None)
    {
        i = 0;
        OperationWave = SFXWave_Operation(GRI.WaveCoordinator.GetWaveOfType('SFXWave_Operation'));
        foreach OperationWave.ObjectiveActors(oActor, )
        {
            if (i == ObjectiveIndex)
            {
                ObjectiveActor = SFXOperationObjective(oActor);
                if (ObjectiveActor != None)
                {
                    PlayLine(ObjectiveActor.SimpleDialogPlayer, EventName, LineIndex);
                    break;
                }
            }
            i++;
        }
    }
}
public final exec function ProfileDeck()
{
    local SFXGAWReinforcementBase Card;
    local SFXLocalPlayer LP;
    local SFXGAWReinforcementManager GAWManager;
    local SFXEngine Engine;
    local int idx;
    local int ProfileColumn;
    local int MaxEntries;
    local int EntryCount;
    local string LastCardType;
    
    LP = SFXLocalPlayer(Outer.Player);
    if (LP == None)
    {
        return;
    }
    GAWManager = SFXGAWReinforcementManager(LP.GAWReinforcementManager);
    if (GAWManager == None)
    {
        return;
    }
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Engine == None)
    {
        return;
    }
    MaxEntries = 60;
    ProfileColumn = 1;
    foreach GAWManager.Deck(Card, )
    {
        if (DisplayPools.Find(Card.PoolName) == -1)
        {
            continue;
        }
        if (LastCardType != Card.PoolName)
        {
            DrawBrightText("CardType=" $ Card.PoolName, 0, TRUE);
            EntryCount++;
            if (EntryCount >= MaxEntries)
            {
                ProfileColumn++;
                SetProfileColumn(ProfileColumn);
                MaxEntries += 60;
            }
            LastCardType = Card.PoolName;
        }
        for (idx = 0; idx < Card.CardList.Length; idx++)
        {
            DrawBrightText("    " $ Split(Card.CardList[idx].UniqueName, "Content.", TRUE), 2, FALSE);
            DrawBrightText(",Count=" $ Engine.GetPlayerVariable(Card.GetPlayerVariableName(idx)), 1, TRUE);
            EntryCount++;
            if (EntryCount >= MaxEntries)
            {
                ProfileColumn++;
                SetProfileColumn(ProfileColumn);
                MaxEntries += 60;
            }
        }
    }
}
public exec function RestartFromBeginning()
{
    RestartFromWave(0);
}
public exec function RestartFromCheckpoint()
{
    RestartFromWave(SFXWaveCoordinator_HordeOperation(SFXGRI(Outer.WorldInfo.GRI).WaveCoordinator).CurrentWaveNumber);
}
public exec function RestartWithFaction(string Faction)
{
    local Class<SFXWave_Horde> HordeClass;
    
    Faction = Locs(Faction);
    HordeClass = InStr(Faction, "geth", , , ) != -1 ? Class'SFXWave_Horde_Geth' : HordeClass;
    HordeClass = InStr(Faction, "cerberus", , , ) != -1 ? Class'SFXWave_Horde_Cerberus' : HordeClass;
    HordeClass = InStr(Faction, "reaper", , , ) != -1 ? Class'SFXWave_Horde_Reaper' : HordeClass;
    if (HordeClass == None)
    {
        return;
    }
    Outer.ClientMessage("Switching to " $ HordeClass);
    SFXWaveCoordinator_HordeOperation(SFXGRI(Outer.WorldInfo.GRI).WaveCoordinator).GenerateHordeWaveList(HordeClass);
    RestartFromCheckpoint();
}
public exec function SetKit(string KitName)
{
    if (SFXPRIMP(Outer.PlayerReplicationInfo) != None)
    {
        SFXPRIMP(Outer.PlayerReplicationInfo).SetCharacterKit(Name(KitName));
        SFXPRIMP(Outer.PlayerReplicationInfo).SendCharacterDataToServer();
        Respawn();
    }
}
public exec function ShowAllMPCards()
{
    local SFXLocalPlayer LP;
    local SFXEngine Engine;
    local SFXGAWReinforcementManager GAWReinforcementManager;
    local int idx;
    local int CurrentValue;
    local int nCardIndex;
    
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Engine == None)
    {
        return;
    }
    LP = SFXLocalPlayer(Outer.Player);
    if (LP == None || LP.GAWReinforcementManager == None)
    {
        return;
    }
    GAWReinforcementManager = SFXGAWReinforcementManager(LP.GAWReinforcementManager);
    if (GAWReinforcementManager == None)
    {
        return;
    }
    GAWReinforcementManager.LastAwardedCards.Length = 0;
    for (idx = 0; idx < GAWReinforcementManager.CardData.Length; ++idx)
    {
        nCardIndex = GAWReinforcementManager.LastAwardedCards.AddItem(GAWReinforcementManager.CardData[idx]);
        CurrentValue = Engine.MPSaveManager.GetPlayerVariable(Name(GAWReinforcementManager.LastAwardedCards[nCardIndex].UniqueName));
        GAWReinforcementManager.LastAwardedCards[nCardIndex].LevelAwarded = CurrentValue;
    }
    SFXPlayerControllerMP(Outer.GetALocalPlayerController()).ShowReinforcementsRevealScreeen();
}
public exec function SkipWave()
{
    SFXGRI(Outer.WorldInfo.GRI).WaveCoordinator.FinishActiveWaves();
}
public final exec function TestConsumptionError(int nCriticalLocation)
{
    local SFXLocalPlayer LP;
    local SFXGAWReinforcementManager GAWManager;
    
    LP = SFXLocalPlayer(Outer.Player);
    if (LP == None)
    {
        return;
    }
    GAWManager = SFXGAWReinforcementManager(LP.GAWReinforcementManager);
    if (GAWManager == None)
    {
        return;
    }
    GAWManager.nTestConsumptionError = nCriticalLocation;
}
public exec function TestHostile()
{
    local BioPawn EnemyPawn1;
    local BioPawn EnemyPawn2;
    local SFXPlayerSquadMP PlayerSquad;
    local SFXSquadCombatMP EnemySquad;
    local SFXWave_Horde ActiveHordeWave;
    local BioPawn BP;
    
    Outer.ClientMessage("TestHostile:");
    ActiveHordeWave = SFXWave_Horde(SFXGRI(Outer.WorldInfo.GRI).WaveCoordinator.GetWaveOfType('SFXWave_Horde'));
    PlayerSquad = SFXPlayerSquadMP(BioWorldInfo(Outer.WorldInfo).m_playerSquad);
    EnemySquad = SFXSquadCombatMP(ActiveHordeWave.EnemySquad);
    if (EnemySquad != None)
    {
        EnemyPawn1 = BioPawn(EnemySquad.Members[0]);
        EnemyPawn2 = BioPawn(EnemySquad.Members[1]);
    }
    else
    {
        foreach Outer.AllActors(Class'BioPawn', BP, )
        {
            if (BP.Squad != None && SFXSquadCombatMP(BP.Squad) != None)
            {
                if (EnemyPawn1 == None)
                {
                    EnemyPawn1 = BP;
                }
                else if (EnemyPawn2 == None)
                {
                    EnemyPawn2 = BP;
                }
                else
                {
                    break;
                }
            }
        }
    }
    Outer.ClientMessage("- Local VS Leader:" @ PlayerSquad.LocalPawn.IsHostile(PlayerSquad.LeaderPawn));
    Outer.ClientMessage("- Local VS Enemy1:" @ PlayerSquad.LocalPawn.IsHostile(EnemyPawn1));
    Outer.ClientMessage("- Leader VS Enemy1:" @ PlayerSquad.LeaderPawn.IsHostile(EnemyPawn1));
    Outer.ClientMessage("- Enemy1 VS Enemy2:" @ EnemyPawn1.IsHostile(EnemyPawn2));
}
public exec function TestPurchaseEntitlement()
{
    local SFXLocalPlayer LP;
    local SFXGAWReinforcementManager GAWReinforcementManager;
    
    LP = SFXLocalPlayer(Outer.Player);
    if (LP == None || LP.GAWReinforcementManager == None)
    {
        return;
    }
    GAWReinforcementManager = SFXGAWReinforcementManager(LP.GAWReinforcementManager);
    if (GAWReinforcementManager == None)
    {
        return;
    }
    GAWReinforcementManager.GrantPackPurchasedEntitlement();
}
public exec function TestPurchaseFromPlatform(int nID)
{
    local SFXLocalPlayer LP;
    local SFXGAWReinforcementManager GAWManager;
    
    LP = SFXLocalPlayer(Outer.Player);
    if (LP == None)
    {
        return;
    }
    GAWManager = SFXGAWReinforcementManager(LP.GAWReinforcementManager);
    if (GAWManager == None)
    {
        return;
    }
    GAWManager.PurchaseItemFromPlatform(nID, None);
}
public exec function TestSquads()
{
    local SFXPlayerSquadMP PlayerSquad;
    local SFXSquadCombatMP EnemySquad;
    local SFXWave_Horde ActiveHordeWave;
    local int i;
    
    Outer.ClientMessage("TestSquads:");
    ActiveHordeWave = SFXWave_Horde(SFXGRI(Outer.WorldInfo.GRI).WaveCoordinator.GetWaveOfType('SFXWave_Horde'));
    PlayerSquad = SFXPlayerSquadMP(BioWorldInfo(Outer.WorldInfo).m_playerSquad);
    EnemySquad = SFXSquadCombatMP(ActiveHordeWave.EnemySquad);
    Outer.ClientMessage("- Player's squad members:");
    for (i = 0; i < PlayerSquad.Members.Length; ++i)
    {
        Outer.ClientMessage("     " @ PlayerSquad.Members[i]);
    }
    Outer.ClientMessage("- Enemy's squad members:");
    for (i = 0; i < EnemySquad.Members.Length; ++i)
    {
        Outer.ClientMessage("     " @ EnemySquad.Members[i]);
    }
}
public exec function ToggleEndlessWave()
{
    local SFXWave_Horde ActiveHordeWave;
    
    ActiveHordeWave = SFXWave_Horde(SFXGRI(Outer.WorldInfo.GRI).WaveCoordinator.GetWaveOfType('SFXWave_Horde'));
    if (ActiveHordeWave.EndlessWave)
    {
        Outer.ClientMessage("OFF - Endless Wave");
    }
    else
    {
        Outer.ClientMessage("ON - Endless Wave");
    }
    ActiveHordeWave.SetEndlessWaves(!ActiveHordeWave.EndlessWave);
}
public exec function UnlockAllMPCards()
{
    local SFXLocalPlayer LP;
    local SFXEngine Engine;
    local SFXGAWReinforcementManager GAWManager;
    local int idx;
    local int Idx2;
    
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Engine == None)
    {
        return;
    }
    LP = SFXLocalPlayer(Outer.Player);
    if (LP == None)
    {
        return;
    }
    GAWManager = SFXGAWReinforcementManager(LP.GAWReinforcementManager);
    if (GAWManager == None)
    {
        return;
    }
    for (idx = 0; idx < GAWManager.Deck.Length; ++idx)
    {
        for (Idx2 = 0; Idx2 < GAWManager.Deck[idx].CardList.Length; ++Idx2)
        {
            if (Engine.MPSaveManager.GetPlayerVariable(Name(GAWManager.Deck[idx].CardList[Idx2].UniqueName)) <= 0)
            {
                Engine.MPSaveManager.SetPlayerVariable(Name(GAWManager.Deck[idx].CardList[Idx2].UniqueName), 1);
            }
        }
    }
    Engine.MPSaveManager.SaveRecords();
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    DisplayPools = ("bronzecommon", "silvercommon", "goldcommon", "silverrare", "goldrare", "goldultrarare")
    AllProfiles = ({
                    Header = "", 
                    Description = "Clears the current profile", 
                    Func = None, 
                    Utility = None, 
                    Keyword = 'None', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "", 
                    Description = "", 
                    Func = None, 
                    Utility = None, 
                    Keyword = 'None', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "Camera Profile of", 
                    Description = "Displays camera info", 
                    Func = ProfileCamera, 
                    Utility = None, 
                    Keyword = 'Camera', 
                    bNoTarget = TRUE
                   }, 
                   {
                    Header = "Combat Profile of", 
                    Description = "Displays all of the target's combat stats including equipment, damage stats, perception lists and inventory", 
                    Func = ProfileCombat, 
                    Utility = DrawAIUtility, 
                    Keyword = 'Combat', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "Multiplayer Game Profile", 
                    Description = "Displays stats on objectives and enemy waves", 
                    Func = ProfileMPGame, 
                    Utility = DrawAIUtility, 
                    Keyword = 'mpgame', 
                    bNoTarget = TRUE
                   }, 
                   {
                    Header = "Weapon Profile of", 
                    Description = "Displays all of the target's weapon stats", 
                    Func = ProfileWeapon, 
                    Utility = DrawAIUtility, 
                    Keyword = 'Weapon', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "Combat Stats Profile of", 
                    Description = "Tracks combat accuracy and effectiveness", 
                    Func = ProfileCombatStats, 
                    Utility = DrawAIUtility, 
                    Keyword = 'combatstats', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "Difficulty Profile of", 
                    Description = "Displays details of the current difficult setting", 
                    Func = ProfileDifficulty, 
                    Utility = None, 
                    Keyword = 'Difficulty', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "Angst Profile", 
                    Description = "Displays Angst Icon over creatures that do not have their target within equipped weapon range.", 
                    Func = ProfileAngst, 
                    Utility = None, 
                    Keyword = 'angst', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "Power Cooldown Profile of", 
                    Description = "Displays the cooldown bar for the player.", 
                    Func = ProfileCooldown, 
                    Utility = None, 
                    Keyword = 'Cooldown', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "", 
                    Description = "", 
                    Func = None, 
                    Utility = None, 
                    Keyword = 'None', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "Pawn Profile of", 
                    Description = "Displays all non-combat information about a pawn including movement information, faction data, LOD and Talent information", 
                    Func = ProfilePawn, 
                    Utility = DrawTargetLineUtility, 
                    Keyword = 'Pawn', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "Power Profile of", 
                    Description = "Displays all power information for a given pawn, can also display information for one power use 'profile power <self/target/camera> <powername>'", 
                    Func = ProfilePower, 
                    Utility = DrawTargetLineUtility, 
                    Keyword = 'Power', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "Technology Profile of", 
                    Description = "All player tech. Use profile treasure for treasure. Use 'setintbyname <name> <value>' to modify", 
                    Func = ProfileTech, 
                    Utility = None, 
                    Keyword = 'Tech', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "Treasure Profile of", 
                    Description = "Try 'debugtreasure local' or 'debugtreasure all' to switch modes", 
                    Func = ProfileTreasure, 
                    Utility = None, 
                    Keyword = 'TREASURE', 
                    bNoTarget = TRUE
                   }, 
                   {
                    Header = "Locomotion Profile of", 
                    Description = "Displays locomotion data for the given pawn.", 
                    Func = ProfileLocomotion, 
                    Utility = DrawTargetLineUtility, 
                    Keyword = 'Locomotion', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "AnimTree Profile of", 
                    Description = "Displays animtree for the given pawn.", 
                    Func = ProfileAnimTree, 
                    Utility = DrawTargetLineUtility, 
                    Keyword = 'AnimTree', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "Ticket Profile of", 
                    Description = "Displays the max and current target and attack tickets for the pawn's squad", 
                    Func = ProfileTicket, 
                    Utility = None, 
                    Keyword = 'ticket', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "Vehicle Profile of", 
                    Description = "Displays all vehicle information, including movement, damage, and current thrust power.", 
                    Func = ProfileVehicle, 
                    Utility = None, 
                    Keyword = 'Vehicle', 
                    bNoTarget = TRUE
                   }, 
                   {
                    Header = "Henchmen Profile of", 
                    Description = "Displays information about the henchmen", 
                    Func = ProfileHenchmen, 
                    Utility = None, 
                    Keyword = 'henchmen', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "Settings Profile of", 
                    Description = "Displays all the profile settings, including trigger configuration, y axis inversion, etc.", 
                    Func = ProfileGameSettings, 
                    Utility = None, 
                    Keyword = 'Settings', 
                    bNoTarget = TRUE
                   }, 
                   {
                    Header = "GameEffect Profile of", 
                    Description = "Displays all GameEffect information for a given actor.", 
                    Func = ProfileEffects, 
                    Utility = None, 
                    Keyword = 'Effect', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "Scaleform Profile", 
                    Description = "Displays general scaleform processor times for all active scaleform panels.", 
                    Func = ProfileScaleform, 
                    Utility = None, 
                    Keyword = 'Scaleform', 
                    bNoTarget = TRUE
                   }, 
                   {
                    Header = "Save game profile", 
                    Description = "Displays information about the current save game", 
                    Func = ProfileSaveGame, 
                    Utility = None, 
                    Keyword = 'SaveGame', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "GAWAsset Profile of", 
                    Description = "Displays the totals of each of the categories of GAWAssets", 
                    Func = ProfileGAWAssets, 
                    Utility = None, 
                    Keyword = 'GAWAssets', 
                    bNoTarget = TRUE
                   }, 
                   {
                    Header = "Military GAWAsset Profile of", 
                    Description = "Displays all of the available military GAWAssets along with their strength and unlock status", 
                    Func = ProfileMilitaryGAWAssets, 
                    Utility = None, 
                    Keyword = 'MilitaryGAWAssets', 
                    bNoTarget = TRUE
                   }, 
                   {
                    Header = "Device GAWAsset Profile of", 
                    Description = "Displays all of the available device GAWAssets along with their strength and unlock status", 
                    Func = ProfileDeviceGAWAssets, 
                    Utility = None, 
                    Keyword = 'DeviceGAWAssets', 
                    bNoTarget = TRUE
                   }, 
                   {
                    Header = "Intel GAWAsset Profile of", 
                    Description = "Displays all of the available intel GAWAssets along with their strength and unlock status", 
                    Func = ProfileIntelGAWAssets, 
                    Utility = None, 
                    Keyword = 'IntelGAWAssets', 
                    bNoTarget = TRUE
                   }, 
                   {
                    Header = "Salvage GAWAsset Profile of", 
                    Description = "Displays all of the salvage military GAWAssets along with their strength and unlock status", 
                    Func = ProfileSalvageGAWAssets, 
                    Utility = None, 
                    Keyword = 'SalvageGAWAssets', 
                    bNoTarget = TRUE
                   }, 
                   {
                    Header = "Artifact GAWAsset Profile of", 
                    Description = "Displays all of the artifact military GAWAssets along with their strength and unlock status", 
                    Func = ProfileArtifactGAWAssets, 
                    Utility = None, 
                    Keyword = 'ArtifactGAWAssets', 
                    bNoTarget = TRUE
                   }, 
                   {
                    Header = "Focus/Movement Profile of", 
                    Description = "Focus and rotation", 
                    Func = ProfileFocus, 
                    Utility = DrawAIUtility, 
                    Keyword = 'Focus', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "LoadSeekFreeAsync Profile", 
                    Description = "Display all LoadSeekFreeAsync Objects currently loaded", 
                    Func = ProfileLoadSeekFreeAsync, 
                    Utility = None, 
                    Keyword = 'loadseekfreeasync', 
                    bNoTarget = TRUE
                   }, 
                   {
                    Header = "Placeable Profile of", 
                    Description = "Displays info on the targeted SFXPlaceable", 
                    Func = ProfilePlaceable, 
                    Utility = None, 
                    Keyword = 'Placeable', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "GAWCards profile ", 
                    Description = "Prints out the players cards, cardIDs and how many they have of each.", 
                    Func = ProfileDeck, 
                    Utility = None, 
                    Keyword = 'Deck', 
                    bNoTarget = TRUE
                   }, 
                   {
                    Header = "Animation Profile of", 
                    Description = "Displays animation information", 
                    Func = ProfileAnim, 
                    Utility = DrawTargetLineUtility, 
                    Keyword = 'Anim', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "Cover Profile of", 
                    Description = "Displays cover information for the specified pawn, including information about their current movement targets and the cover they're currently using", 
                    Func = ProfileCover, 
                    Utility = DrawTargetLineUtility, 
                    Keyword = 'Cover', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "Cover Profile of", 
                    Description = "Displays details of specified door", 
                    Func = ProfileDoor, 
                    Utility = None, 
                    Keyword = 'door', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "Conversation Profile of", 
                    Description = "Simple conversation profile", 
                    Func = ProfileConversation, 
                    Utility = None, 
                    Keyword = 'Conversation', 
                    bNoTarget = TRUE
                   }, 
                   {
                    Header = "Conversation Bug Profile of", 
                    Description = "Simple conversation profile", 
                    Func = ProfileConversationBug, 
                    Utility = None, 
                    Keyword = 'conversationbug', 
                    bNoTarget = TRUE
                   }, 
                   {
                    Header = "Gestures Profile of", 
                    Description = "Displays gestures information for the specified actor", 
                    Func = ProfileGestures, 
                    Utility = DrawTargetLineUtility, 
                    Keyword = 'Gestures', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "", 
                    Description = "", 
                    Func = None, 
                    Utility = None, 
                    Keyword = 'None', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "", 
                    Description = "", 
                    Func = None, 
                    Utility = None, 
                    Keyword = 'None', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "Look-At Profile of", 
                    Description = "Displays look-at information for the specified pawn", 
                    Func = ProfileLookAt, 
                    Utility = DrawTargetLineUtility, 
                    Keyword = 'LookAt', 
                    bNoTarget = FALSE
                   }, 
                   {
                    Header = "Wwise Profile of", 
                    Description = "Wwise audio profile", 
                    Func = ProfileWwise, 
                    Utility = None, 
                    Keyword = 'Wwise', 
                    bNoTarget = TRUE
                   }, 
                   {
                    Header = "Kinect Profile of", 
                    Description = "Kinect Speech profile", 
                    Func = ProfileKinect, 
                    Utility = None, 
                    Keyword = 'Kinect', 
                    bNoTarget = TRUE
                   }, 
                   {
                    Header = "Anim Preload Profile of", 
                    Description = "Displays animation preload information currently", 
                    Func = ProfileAnimPreload, 
                    Utility = DrawTargetLineUtility, 
                    Keyword = 'animpreload', 
                    bNoTarget = TRUE
                   }, 
                   {
                    Header = "Profile Galaxy Map", 
                    Description = "Galaxymap Info", 
                    Func = ProfileGalaxy, 
                    Utility = None, 
                    Keyword = 'galaxy', 
                    bNoTarget = TRUE
                   }
                  )
}