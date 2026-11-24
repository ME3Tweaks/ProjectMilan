// MILAN CHANGE - 11/22/2026 - Mgamerz
// Priority targets from objectives can be shot by more enemies at once
public event function int GetMaxAttackTickets()
{
    local int Tickets;
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect PriorityEffect;

    Tickets = m_nMaxAttackTickets;
    Manager = GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        PriorityEffect = Manager.GetFirstEffectOfCategory('MilanObjectivePriority');
        if (PriorityEffect != None && PriorityEffect.EffectValue > 1.0)
        {
            Tickets += int(PriorityEffect.EffectValue);
        }
    }
    return Tickets;
}
