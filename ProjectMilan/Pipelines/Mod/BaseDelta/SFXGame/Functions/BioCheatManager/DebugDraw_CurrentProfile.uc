public final function DebugDraw_CurrentProfile(BioHUD HUD)
{
    local delegate<ProfileHandler> ProfileFunc;
    local delegate<ProfileUtility> UtilityFunc;

    // MILAN CHANGE - Mgamerz - 2026-10-01
    // Vanilla hardcoded '< 49' (the EProfileType count), which hid any profile appended to
    // AllProfiles by CheatProfileRegistry. Bound against the array instead.
    if ((ProfileTarget != None || AllProfiles[int(CurrentProfile)].bNoTarget != FALSE) && CurrentProfile > EProfileType.Profile_None && int(CurrentProfile) < AllProfiles.Length)
    // END MILAN CHANGE
    {
        DrawProfileTitle();
        ProfileFunc = AllProfiles[int(CurrentProfile)].Func;
        if (ProfileFunc != None)
        {
            ProfileFunc();
        }
        UtilityFunc = AllProfiles[int(CurrentProfile)].Utility;
        if (UtilityFunc != None)
        {
            UtilityFunc();
        }
    }
}
