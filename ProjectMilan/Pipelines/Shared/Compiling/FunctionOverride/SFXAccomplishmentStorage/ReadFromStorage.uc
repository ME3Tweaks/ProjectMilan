// MILAN CHANGE - Mgamerz - 2026-09-24
// The native timestamp loader replaces the array with only the three legacy
// strings. Preserve the MP_Profile extension slots through later reloads.
public final function ReadFromStorage(SFXAccomplishmentManager AccomplishmentManager)
{
    local string WarnString;
    local array<int> ExtendedCompletionTimes;
    local int i;
    local int RequiredLength;

    if (AccomplishmentManager.AccomplishmentCompletionTimes.Length > 750)
    {
        ExtendedCompletionTimes.Length =
            AccomplishmentManager.AccomplishmentCompletionTimes.Length - 750;
        for (i = 0; i < ExtendedCompletionTimes.Length; ++i)
        {
            ExtendedCompletionTimes[i] = AccomplishmentManager.AccomplishmentCompletionTimes[750 + i];
        }
    }

    if (!SetCompletion(AccomplishmentManager.AccomplishmentData,
                       AccomplishmentManager.AccomplishmentIsComplete) ||
        !SetProgress(AccomplishmentManager.AccomplishmentProgressData) ||
        !SetRewardLevels() ||
        !SetCompletionTimes(AccomplishmentManager.AccomplishmentCompletionTimes))
    {
        WarnString = "SFXAccomplishmentStorage:ReadFromStorage encountered an error.";
        if (IsInvalid)
        {
            WarnString = WarnString @ "The version on the server was inconsistent with the local version; the server data will be overwritten and this message should disappear.";
        }
        WarnInternal(WarnString);
    }

    if (ExtendedCompletionTimes.Length > 0)
    {
        AccomplishmentManager.AccomplishmentCompletionTimes.Length =
            750 + ExtendedCompletionTimes.Length;
        for (i = 0; i < ExtendedCompletionTimes.Length; ++i)
        {
            AccomplishmentManager.AccomplishmentCompletionTimes[750 + i] = ExtendedCompletionTimes[i];
        }
    }
    RequiredLength = AccomplishmentManager.AccomplishmentIsComplete.Length;
    for (i = 0; i < AccomplishmentManager.AccomplishmentData.Length; ++i)
    {
        if (AccomplishmentManager.AccomplishmentData[i].Index + 1 > RequiredLength)
        {
            RequiredLength = AccomplishmentManager.AccomplishmentData[i].Index + 1;
        }
    }
    if (AccomplishmentManager.AccomplishmentIsComplete.Length < RequiredLength)
    {
        AccomplishmentManager.AccomplishmentIsComplete.Length = RequiredLength;
    }
    if (AccomplishmentManager.AccomplishmentCompletionTimes.Length < RequiredLength)
    {
        AccomplishmentManager.AccomplishmentCompletionTimes.Length =
            RequiredLength;
    }
}
// END MILAN CHANGE
