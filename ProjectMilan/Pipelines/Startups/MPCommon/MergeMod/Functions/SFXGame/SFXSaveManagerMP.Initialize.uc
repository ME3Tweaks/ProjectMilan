// MILAN CHANGE - 12/11/2023
// By Mgamerz
// Purpose: Dev (maybe?) - Force initialize default kit if not set. ME3 serverside might have 
// initialized it automatically. Fixes some issues in MPLobby.
// Purpose: Dev - server defined images load from ME3Tweaks.com
public function Initialize()
{
    local BioPlayerController PC; // MILAN CHANGE
    
    if (OnlineSave == None)
    {
        OnlineSave = new Class'SFXOnlineSaveGameMP';
    }
    OnlineSave.Initialize();

    // MILAN CHANGE -------------------------------
    PC = GetPC();
    if ((PC != None && PC.ProfileSettings != None) && PC.ProfileSettings.GetLastSelectedCharacter() == "")
    {
        PC.ProfileSettings.SetLastSelectedCharacter("AdeptHumanMale");
        PC.SaveProfile();
    }
    Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentImageManager().SetBaseURL("https://me3tweaks.com/mpserver/gameimages");
    // END MILAN CHANGE---------------------------
    if (MPMatchResultsData == None)
    {
        MPMatchResultsData = new Class'SFXMatchResultsData';
    }
}