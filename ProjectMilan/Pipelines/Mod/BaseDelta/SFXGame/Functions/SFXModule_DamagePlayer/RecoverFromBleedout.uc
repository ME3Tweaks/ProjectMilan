public simulated function RecoverFromBleedout(optional bool bResetHealth = TRUE)
{
    // MILAN CHANGE: Do not run bleedout code if the owner is not a human player
    // 09/30/2026 - Mgamerz - Also add IsLocallyControlled() so clients don't mess with us
    if (Pawn(ModuleOwner).IsHumanControlled() && Pawn(ModuleOwner).IsLocallyControlled())
    {
        Super.RecoverFromBleedout();
        if (bResetHealth)
        {
            SetCurrentHealth(GetMaxHealth());
        }
        if (CurrentBleedoutState != EBleedoutState.BleedOutState_None)
        {
            CurrentBleedoutState = EBleedoutState.BleedOutState_None;
        }
        DisableBleedOutVisualEffects();
        DisableBleedoutSoundEffects();
    }
}