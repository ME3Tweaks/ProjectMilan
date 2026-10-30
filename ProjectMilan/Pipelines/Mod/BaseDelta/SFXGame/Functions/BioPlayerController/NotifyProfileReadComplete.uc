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
    InitializeGammaCorrectionSettings();
}
