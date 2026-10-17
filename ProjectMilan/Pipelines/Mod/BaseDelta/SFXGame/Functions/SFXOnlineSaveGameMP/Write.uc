// MILAN CHANGE - d00t - 2026-10-17
// Invoke the completion delegate even if CachedOnlinePlayerStorage is not initialized,
// which should prevent 'SFXSaveManagerMP.m_bSaveInProgress' from getting permanently stuck.
public final function bool Write(byte LocalUserNum, delegate<OnlinePlayerInterface.OnWritePlayerStorageComplete> WritePlayerStorageCompleteDelegate)
{
    if (CachedOnlinePlayerStorage == None)
    {
        if (WritePlayerStorageCompleteDelegate != None)
        {
            WritePlayerStorageCompleteDelegate(LocalUserNum, FALSE);
        }
        return FALSE;
    }
    return CachedOnlinePlayerStorage.Write(LocalUserNum, WritePlayerStorageCompleteDelegate);
}
// END MILAN CHANGE
