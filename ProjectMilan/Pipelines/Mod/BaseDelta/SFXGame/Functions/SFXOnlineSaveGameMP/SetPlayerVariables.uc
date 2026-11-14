// MILAN CHANGE - 11/14/2026 - Mgamerz
// Add null guards and remove useless gameconfig code
private static final function bool SetPlayerVariables(const out string PlayerVariableString, out SFXSaveManagerMP MPSaveManager)
{
    local string AmountString;
    local int idx;
    local int nAmount;
    local int VariableID;
    // local SFXGameConfig gameconfig;

    // We null guard MPSaveManager instead of gameconfig as gameconfig isn't even used
    if (MPSaveManager == None)
    {
        LogInternal("Error: No MPSaveManager available for player variable data parsing", );
        return FALSE;
    }
    // END MILAN CHANGE
    idx = 0;
    while (idx < Len(PlayerVariableString))
    {
        AmountString = Mid(PlayerVariableString, idx, 2);
        nAmount = HexDecodeNumber(AmountString);
        VariableID = idx / 2;
        MPSaveManager.SetPlayerVariableFromID(Name(string(VariableID)), nAmount);
        idx += 2;
    }
    return TRUE;
}