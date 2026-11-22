// MILAN CHANGE - Mgamerz - 11/19/2026
// Shared action also unregisters PC_Cover and optionally PC_Sprint if split
public function UnregisterInputOverride(string Alias, optional bool bPress = TRUE)
{
    local int i;

    for (i = 0; i < InputOverrides.Length; i++)
    {
        if (InputOverrides[i].Alias == Alias && InputOverrides[i].bPress == bPress)
        {
            InputOverrides.RemoveItem(InputOverrides[i]);
            break;
        }
    }
    // MILAN CHANGE - Unregister same things we override in RegisterInputOverride()
    if (Alias == "Shared_Action")
    {
        UnregisterInputOverride("PC_Cover", bPress);
        UnregisterInputOverride("PC_Sprint", bPress);
    }
    // END MILAN CHANGE
}
