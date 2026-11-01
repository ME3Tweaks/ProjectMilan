// MILAN CHANGE - Mgamerz - 2026-10-26
// Helper method to add missing profile settings on profile read so old profiles are automatically upgraded with values that will return on read
public final function AddMissingDefaultSettings()
{
    local int i;

    for (i = 0; i < DefaultSettings.Length; i++)
    {
        if (FindProfileSettingIndex(DefaultSettings[i].ProfileSetting.PropertyId) == -1)
        {
            ProfileSettings.AddItem(DefaultSettings[i]);
        }
    }
}
// END MILAN CHANGE
