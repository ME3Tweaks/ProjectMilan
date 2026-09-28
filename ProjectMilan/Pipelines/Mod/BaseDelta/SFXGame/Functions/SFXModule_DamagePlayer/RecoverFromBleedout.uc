public simulated function RecoverFromBleedout(optional bool bResetHealth = TRUE)
{
    // MILAN CHANGE: Do not run bleedout code if the owner is not a human player
    if (Pawn(ModuleOwner).IsHumanControlled())
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