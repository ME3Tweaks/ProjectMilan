public function NotifyProfileReadComplete(byte LocalUserNum, bool bWasSuccessful)
{
    if (TRUE)
    {
        LogInternal("NotifyProfileReadComplete" @ LocalUserNum @ "success" @ bWasSuccessful, 'DevOnline');
    }
    UpdateProfileData();
    // MILAN CHANGE - Mgamerz - 2026-10-26
    if (ProfileSettings != None)
    {
        ProfileSettings.AddMissingDefaultSettings();
    }
    // END MILAN CHANGE
    // MILAN CHANGE - 11/26/2026 - Mgamerz
    Class'MilanGUIVisibility'.static.RefreshCache();
    // END MILAN CHANGE
    InitializeGammaCorrectionSettings();
}
