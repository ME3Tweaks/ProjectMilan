// MILAN CHANGE - Gate VFX changes to local human players only
// 10/07/2026 Mgamerz - Fixes buggy original version milan had that prevented off-host regen
public simulated function RecoverFromBleedout(optional bool bResetHealth = TRUE)
{
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
        // MILAN CHANGE - Run recovery for human players; keep bleedout presentation local
        if (Pawn(ModuleOwner).IsLocallyControlled()) {
            DisableBleedOutVisualEffects();
            DisableBleedoutSoundEffects();
        }
    }
}