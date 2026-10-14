// MILAN CHANGE - Mgamerz - 2026-10-10
// Complete character and accomplishment saves using the local disk result. Use the Milan native settings bridge that MilanHost hooks.
public final function bool Write(byte LocalUserNum, delegate<OnlinePlayerInterface.OnWritePlayerStorageComplete> WritePlayerStorageCompleteDelegate)
{
    local bool bWasSuccessful;

    bWasSuccessful = Class'MilanProfileSaveBridge'.static.WriteProfile();
    if (WritePlayerStorageCompleteDelegate != None)
    {
        WritePlayerStorageCompleteDelegate(LocalUserNum, bWasSuccessful);
    }
    return bWasSuccessful;
}
// END MILAN CHANGE
