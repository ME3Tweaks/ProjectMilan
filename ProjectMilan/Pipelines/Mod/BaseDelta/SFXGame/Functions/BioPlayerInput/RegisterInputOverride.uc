// MILAN CHANGE - Mgamerz - 11/19/2026
// Shared action also registers PC_Cover and optionally PC_Sprint if split
public function RegisterInputOverride(string Alias, delegate<BioPlayerInput.InputDelegate> InputDelegate, bool bExclusive, optional bool bPress = TRUE)
{
    local bool bFoundAlias;
    local int i;
    local BioPlayerInput.InputOverride NewOverride;

    bFoundAlias = FALSE;
    for (i = 0; i < InputOverrides.Length && !bFoundAlias; i++)
    {
        if (InputOverrides[i].Alias == Alias && InputOverrides[i].bPress == bPress)
        {
            bFoundAlias = TRUE;
        }
    }
    if (!bFoundAlias)
    {
        NewOverride.Alias = Alias;
        NewOverride.bPress = bPress;
        NewOverride.bExclusive = bExclusive;
        NewOverride.InputDelegate = InputDelegate;
        InputOverrides.AddItem(NewOverride);
    }
    // MILAN CHANGE - Register split overrides
    if (Alias == "Shared_Action")
    {
        RegisterInputOverride("PC_Cover", InputDelegate, bExclusive, bPress);
        if (!SprintSharesCover())
        {
            RegisterInputOverride("PC_Sprint", InputDelegate, bExclusive, bPress);
        }
    }
    // END MILAN CHANGE
}
