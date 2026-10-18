// MILAN CHANGE - d00t - 2026-10-18
// Instead of writing out accomplishment data, stores it to the server caches and completes
// the write immediately. This should avoid profile serialization each time an accomplishment progresses.
public final function bool Write(byte LocalUserNum, delegate<OnlinePlayerInterface.OnWritePlayerStorageComplete> WritePlayerStorageCompleteDelegate)
{
    if (WritePlayerStorageCompleteDelegate != None)
    {
        SaveCompleted();
        WritePlayerStorageCompleteDelegate(LocalUserNum, TRUE);
    }
    return TRUE;
}
// END MILAN CHANGE
