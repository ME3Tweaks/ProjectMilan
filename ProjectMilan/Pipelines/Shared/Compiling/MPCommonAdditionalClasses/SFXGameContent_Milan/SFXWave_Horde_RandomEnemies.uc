// NEW to Milan
// 09/21/2026 - Mgamerz
// Wavelist class that gets a randomized composition of enemies based on the score budget and compositions across the same wave in all factions
Class SFXWave_Horde_RandomEnemies extends SFXWave_Horde
    config(Game);

struct UnifiedReference
{
    var array<EnemyWaveInfo> Composition;
    var array<float> ExpectedCounts;
    var float GroupCost;
    var float SelectionWeight;
};

struct UnifiedEnemyChoice
{
    var Name EnemyType;
    var float SelectionWeight;
    var int WaveCost;
};

// Probability distribution
struct UnifiedFillState
{
    var string Key;
    var array<int> Counts;
    var float Probability;
};

var config int CompositionAttempts;
var config float GroupCostTolerance;
var config int MaxFillStates;
var transient bool bCompositionGenerated;
var transient array<EnemyWaveInfo> GeneratedComposition;

public function GetLocalEnemyArray(out array<EnemyWaveInfo> EnemyArray)
{
    EnemyArray.Length = 0;
    if (BioWorldInfo == None || BioWorldInfo.Role != ENetRole.ROLE_Authority)
    {
        return;
    }
    if (BioWorldInfo.GRI == None || SFXGRI(BioWorldInfo.GRI).DifficultyHandler == None)
    {
        return;
    }
    if (!bCompositionGenerated)
    {
        GeneratedComposition = GenerateComposition();
        bCompositionGenerated = TRUE;
    }
    EnemyArray = GeneratedComposition;
}

// Resolve real registered factions (not Random or other dynamic types)
private function CollectReferences(out array<UnifiedReference> References)
{
    local MPEnemyInfo Faction;
    local Class<SFXWave_Horde> WaveClass;
    local array<Class<SFXWave_Horde> > SeenClasses;
    local SFXWave_Horde AuthoredWave;
    local UnifiedReference Reference;

    References.Length = 0;
    foreach Class'SFXOnlineGameSettings'.default.EnemyTypes(Faction, )
    {
        if (Faction.IsRandomOption || Faction.WaveClass == "")
        {
            continue;
        }
        Reference.SelectionWeight = GetFactionWeight(Faction.WaveClass);
        if (Reference.SelectionWeight <= 0.0)
        {
            continue;
        }
        WaveClass = Class<SFXWave_Horde>(FindObject(Faction.WaveClass, Class'Class'));
        if (WaveClass == None)
        {
            WaveClass = Class<SFXWave_Horde>(Class'SFXEngine'.static.GetSeekFreeObject(Faction.WaveClass, Class'Class'));
        }
        if (WaveClass == None || ClassIsChildOf(WaveClass, Class'SFXWave_Horde_RandomEnemies') || SeenClasses.Find(WaveClass) != -1)
        {
            continue;
        }
        SeenClasses.AddItem(WaveClass);
        AuthoredWave = FindAuthoredWave(WaveClass);
        if (AuthoredWave == None)
        {
            continue;
        }
        ReadDifficultyComposition(AuthoredWave, Reference.Composition);
        if (!IsValidComposition(Reference.Composition))
        {
            continue;
        }
        if (!CalculateExpectedCounts(Reference.Composition, Reference.ExpectedCounts))
        {
            LogInternal("[Unified] Skipping reference that cannot fill cap: " $ AuthoredWave.Name);
            continue;
        }
        Reference.GroupCost = CalculateGroupCost(Reference.Composition, Reference.ExpectedCounts);
        References.AddItem(Reference);
        LogInternal("[Unified] Reference=" $ AuthoredWave.Name $ " expectedCost=" $ Reference.GroupCost $ " weight=" $ Reference.SelectionWeight);
    }
}

// Factions don't have equal weight, so bias them based on that
private function float GetFactionWeight(string WaveClassName)
{
    local int Index;

    Index = Class'SFXWaveManager_Horde'.default.WaveTypes.Find('WaveClassName', WaveClassName);
    if (Index == -1)
    {
        return 0.0;
    }
    return FMax(0.0, float(Class'SFXWaveManager_Horde'.default.WaveTypes[Index].SelectionWeight));
}

private function int PickReferenceIndex(out array<UnifiedReference> References, float TotalWeight)
{
    local float Pick;
    local int Index;

    Pick = FRand() * TotalWeight;
    for (Index = 0; Index < References.Length; Index++)
    {
        if (Pick < References[Index].SelectionWeight)
        {
            return Index;
        }
        Pick -= References[Index].SelectionWeight;
    }
    return References.Length - 1;
}

// Find the wave data for the given wave class on the current wave
private function SFXWave_Horde FindAuthoredWave(Class<SFXWave_Horde> WaveClass)
{
    local array<Object> Objects;
    local Object ConfigObject;
    local SFXWave_Horde Candidate;
    local SFXWave_Horde Found;

    GetObjectArrayFromConfigSection(WaveClass, Objects, FALSE);
    foreach Objects(ConfigObject, )
    {
        Candidate = SFXWave_Horde(ConfigObject);
        if (Candidate != None && Candidate.WaveIndex == WaveIndex)
        {
            if (Found != None)
            {
                LogInternal("[Unified] Duplicate WaveIndex=" $ WaveIndex $ " class=" $ WaveClass);
                return None;
            }
            Found = Candidate;
        }
    }
    return Found;
}

// Reads enemy composition into the given list
private function ReadDifficultyComposition(SFXWave_Horde Wave, out array<EnemyWaveInfo> Composition)
{
    local int Index;
    local int BestIndex;

    Composition.Length = 0;
    if (Wave.Enemies.Length == 0)
    {
        return;
    }
    Index = Wave.Enemies.Find('Difficulty', SFXGRI(BioWorldInfo.GRI).DifficultyHandler.CurrentDifficulty);
    if (Index == -1)
    {
        BestIndex = 0;
        for (Index = 1; Index < Wave.Enemies.Length; Index++)
        {
            if (int(Wave.Enemies[Index].Difficulty) >= int(Wave.Enemies[BestIndex].Difficulty))
            {
                BestIndex = Index;
            }
        }
        Index = BestIndex;
    }
    Composition = Wave.Enemies[Index].Enemies;
}

private function bool IsValidComposition(array<EnemyWaveInfo> Composition)
{
    local int Index;
    local int Other;
    local int RosterIndex;

    if (Composition.Length == 0)
    {
        return FALSE;
    }
    for (Index = 0; Index < Composition.Length; Index++)
    {
        RosterIndex = EnemyList.Find('EnemyType', Composition[Index].EnemyType);
        if (RosterIndex == -1)
        {
            return FALSE;
        }
        if (EnemyList[RosterIndex].WaveCost <= 0 || EnemyList[RosterIndex].EnemyArchetypeName == "")
        {
            return FALSE;
        }
        if (Composition[Index].MinCount < 0 || Composition[Index].MaxCount < 0 || Composition[Index].MaxPerWave < 0)
        {
            return FALSE;
        }
        for (Other = 0; Other < Index; Other++)
        {
            if (Composition[Other].EnemyType == Composition[Index].EnemyType)
            {
                return FALSE;
            }
        }
    }
    return TRUE;
}

// Copied from ChooseEnemy()
// Used to determine what will be chosen to spawn
private function GetFillChoices(array<EnemyWaveInfo> Composition, array<int> Counts, out array<int> Choices)
{
    local int Index;

    Choices.Length = 0;
    for (Index = 0; Index < Composition.Length; Index++)
    {
        if (Composition[Index].MaxPerWave > 0 && Counts[Index] >= Composition[Index].MaxPerWave)
        {
            continue;
        }
        if (Composition[Index].MaxCount > 0 && Counts[Index] >= Composition[Index].MaxCount)
        {
            continue;
        }
        if (Counts[Index] < Composition[Index].MinCount)
        {
            Choices.Length = 0;
            Choices.AddItem(Index);
            return;
        }
        Choices.AddItem(Index);
    }
}

// Collapse identical potential wavelists
private function AddFillState(out array<UnifiedFillState> States, array<int> Counts, float Probability)
{
    local UnifiedFillState State;
    local int Count;
    local int Index;

    foreach Counts(Count, )
    {
        State.Key $= string(Count) $ ",";
    }
    Index = States.Find('Key', State.Key);
    if (Index != -1)
    {
        States[Index].Probability += Probability;
        return;
    }
    State.Counts = Counts;
    State.Probability = Probability;
    States.AddItem(State);
}

// Basic attempt to calculate an expected count of enemies
// We don't want this to be complex because we don't want game stall
private function bool TryCalculateSimpleExpectedCounts(array<EnemyWaveInfo> Composition, out array<float> ExpectedCounts)
{
    local EnemyWaveInfo Info;
    local int UnlimitedCount;
    local int Remaining;
    local int Index;

    foreach Composition(Info, )
    {
        if (Info.MaxCount == 0)
        {
            if (Info.MinCount != 0 || Info.MaxPerWave != 0)
            {
                return FALSE;
            }
            UnlimitedCount++;
        }
        else if (Info.MinCount != Info.MaxCount || (Info.MaxPerWave > 0 && Info.MaxPerWave < Info.MaxCount))
        {
            return FALSE;
        }
    }
    if (UnlimitedCount == 0)
    {
        return FALSE;
    }
    ExpectedCounts.Length = 0;
    ExpectedCounts.Length = Composition.Length;
    Remaining = MaxEnemies;
    for (Index = 0; Index < Composition.Length; Index++)
    {
        if (Composition[Index].MaxCount > 0)
        {
            ExpectedCounts[Index] = float(Min(Remaining, Composition[Index].MaxCount));
            Remaining -= int(ExpectedCounts[Index]);
        }
    }
    for (Index = 0; Index < Composition.Length; Index++)
    {
        if (Composition[Index].MaxCount == 0)
        {
            ExpectedCounts[Index] = float(Remaining) / float(UnlimitedCount);
        }
    }
    return TRUE;
}

// More complex lookup for counts when the simple way doesn't work
private function bool CalculateExpectedCounts(array<EnemyWaveInfo> Composition, out array<float> ExpectedCounts)
{
    local array<UnifiedFillState> States;
    local array<UnifiedFillState> NextStates;
    local UnifiedFillState State;
    local array<int> Choices;
    local array<int> NextCounts;
    local int Slot;
    local int Choice;
    local int Index;

    ExpectedCounts.Length = 0;
    if (MaxEnemies <= 0)
    {
        return FALSE;
    }
    if (TryCalculateSimpleExpectedCounts(Composition, ExpectedCounts))
    {
        return TRUE;
    }
    State.Counts.Length = Composition.Length;
    State.Probability = 1.0;
    States.AddItem(State);
    for (Slot = 0; Slot < MaxEnemies; Slot++)
    {
        NextStates.Length = 0;
        foreach States(State, )
        {
            GetFillChoices(Composition, State.Counts, Choices);
            if (Choices.Length == 0)
            {
                return FALSE;
            }
            foreach Choices(Choice, )
            {
                NextCounts = State.Counts;
                NextCounts[Choice]++;
                AddFillState(NextStates, NextCounts, State.Probability / float(Choices.Length));
                if (NextStates.Length > Max(1, MaxFillStates))
                {
                    return FALSE;
                }
            }
        }
        States = NextStates;
    }
    ExpectedCounts.Length = Composition.Length;
    foreach States(State, )
    {
        for (Index = 0; Index < Composition.Length; Index++)
        {
            ExpectedCounts[Index] += float(State.Counts[Index]) * State.Probability;
        }
    }
    return TRUE;
}

private function float CalculateGroupCost(array<EnemyWaveInfo> Composition, array<float> ExpectedCounts)
{
    local float Cost;
    local int Index;
    local int RosterIndex;

    for (Index = 0; Index < Composition.Length; Index++)
    {
        RosterIndex = EnemyList.Find('EnemyType', Composition[Index].EnemyType);
        Cost += ExpectedCounts[Index] * float(EnemyList[RosterIndex].WaveCost);
    }
    return Cost;
}

// Split each faction's weight over its entries in each role
private function CollectEnemyPools(out array<UnifiedReference> References, out array<UnifiedEnemyChoice> UnlimitedTypes, out array<UnifiedEnemyChoice> LimitedTypes)
{
    local UnifiedReference Reference;
    local EnemyWaveInfo Info;
    local int UnlimitedCount;
    local int LimitedCount;

    UnlimitedTypes.Length = 0;
    LimitedTypes.Length = 0;
    foreach References(Reference, )
    {
        UnlimitedCount = 0;
        LimitedCount = 0;
        foreach Reference.Composition(Info, )
        {
            if (Info.MaxCount == 0)
            {
                UnlimitedCount++;
            }
            else
            {
                LimitedCount++;
            }
        }
        foreach Reference.Composition(Info, )
        {
            if (Info.MaxCount == 0)
            {
                AddEnemyWeight(UnlimitedTypes, Info.EnemyType, Reference.SelectionWeight / float(UnlimitedCount));
            }
            else
            {
                AddEnemyWeight(LimitedTypes, Info.EnemyType, Reference.SelectionWeight / float(LimitedCount));
            }
        }
    }
}

private function AddEnemyWeight(out array<UnifiedEnemyChoice> Pool, Name EnemyType, float Weight)
{
    local UnifiedEnemyChoice Choice;
    local int Index;
    local int RosterIndex;

    Index = Pool.Find('EnemyType', EnemyType);
    if (Index != -1)
    {
        Pool[Index].SelectionWeight += Weight;
        return;
    }
    RosterIndex = EnemyList.Find('EnemyType', EnemyType);
    Choice.EnemyType = EnemyType;
    Choice.SelectionWeight = Weight;
    Choice.WaveCost = EnemyList[RosterIndex].WaveCost;
    Pool.AddItem(Choice);
}

private function int PickEnemyIndex(out array<UnifiedEnemyChoice> Pool, out array<Name> UsedTypes)
{
    local float TotalWeight;
    local float Pick;
    local int Index;
    local int LastEligible;

    LastEligible = -1;
    for (Index = 0; Index < Pool.Length; Index++)
    {
        if (UsedTypes.Find(Pool[Index].EnemyType) == -1)
        {
            TotalWeight += Pool[Index].SelectionWeight;
            LastEligible = Index;
        }
    }
    if (TotalWeight <= 0.0)
    {
        return -1;
    }
    Pick = FRand() * TotalWeight;
    for (Index = 0; Index < Pool.Length; Index++)
    {
        if (UsedTypes.Find(Pool[Index].EnemyType) == -1)
        {
            if (Pick < Pool[Index].SelectionWeight)
            {
                return Index;
            }
            Pick -= Pool[Index].SelectionWeight;
        }
    }
    return LastEligible;
}

private function bool MakeCandidate(UnifiedReference Reference, out array<UnifiedEnemyChoice> UnlimitedTypes, out array<UnifiedEnemyChoice> LimitedTypes, out array<EnemyWaveInfo> Candidate, out float Cost)
{
    local array<Name> UsedTypes;
    local UnifiedEnemyChoice Choice;
    local int Index;
    local int Pick;

    Candidate = Reference.Composition;
    Cost = 0.0;
    for (Index = 0; Index < Candidate.Length; Index++)
    {
        if (Candidate[Index].MaxCount == 0)
        {
            Pick = PickEnemyIndex(UnlimitedTypes, UsedTypes);
            if (Pick != -1)
            {
                Choice = UnlimitedTypes[Pick];
            }
        }
        else
        {
            Pick = PickEnemyIndex(LimitedTypes, UsedTypes);
            if (Pick != -1)
            {
                Choice = LimitedTypes[Pick];
            }
        }
        if (Pick == -1)
        {
            Candidate.Length = 0;
            return FALSE;
        }
        Candidate[Index].EnemyType = Choice.EnemyType;
        UsedTypes.AddItem(Choice.EnemyType);
        Cost += Reference.ExpectedCounts[Index] * float(Choice.WaveCost);
    }
    return TRUE;
}

private function array<EnemyWaveInfo> GenerateComposition()
{
    local array<UnifiedReference> References;
    local array<UnifiedEnemyChoice> UnlimitedTypes;
    local array<UnifiedEnemyChoice> LimitedTypes;
    local array<EnemyWaveInfo> Candidate;
    local array<EnemyWaveInfo> Closest;
    local UnifiedReference Reference;
    local float TargetCost;
    local float TotalWeight;
    local float Cost;
    local float Error;
    local float BestError;
    local float AcceptedCost;
    local int Attempt;

    CollectReferences(References);
    if (References.Length == 0)
    {
        LogInternal("[Unified] No valid authored references for wave=" $ WaveIndex $ "; composition empty.");
        return Closest;
    }
    foreach References(Reference, )
    {
        TargetCost += Reference.GroupCost * Reference.SelectionWeight;
        TotalWeight += Reference.SelectionWeight;
    }
    TargetCost /= TotalWeight;
    BestError = -1.0;

    foreach References(Reference, )
    {
        Error = Abs(Reference.GroupCost - TargetCost);
        if (BestError < 0.0 || Error < BestError)
        {
            Closest = Reference.Composition;
            BestError = Error;
            AcceptedCost = Reference.GroupCost;
        }
    }
    CollectEnemyPools(References, UnlimitedTypes, LimitedTypes);
    for (Attempt = 0; Attempt < Clamp(CompositionAttempts, 1, 32); Attempt++)
    {
        Reference = References[PickReferenceIndex(References, TotalWeight)];
        if (!MakeCandidate(Reference, UnlimitedTypes, LimitedTypes, Candidate, Cost))
        {
            continue;
        }
        Error = Abs(Cost - TargetCost);
        if (Error < BestError)
        {
            Closest = Candidate;
            BestError = Error;
            AcceptedCost = Cost;
        }
        if (Error <= TargetCost * FClamp(GroupCostTolerance, 0.0, 1.0))
        {
            LogInternal("[Unified] wave=" $ WaveIndex $ " cap=" $ MaxEnemies $ " references=" $ References.Length $ " target=" $ TargetCost $ " selected=" $ Cost $ " attempts=" $ (Attempt + 1));
            return Candidate;
        }
    }
    LogInternal("[Unified] No candidate within tolerance: wave=" $ WaveIndex $ " target=" $ TargetCost $ " selected=" $ AcceptedCost $ " attempts=" $ Attempt $ " closest cost error=" $ BestError);
    return Closest;
}

defaultproperties
{
    CompositionAttempts = 32
    GroupCostTolerance = 0.10
    MaxFillStates = 4096
}