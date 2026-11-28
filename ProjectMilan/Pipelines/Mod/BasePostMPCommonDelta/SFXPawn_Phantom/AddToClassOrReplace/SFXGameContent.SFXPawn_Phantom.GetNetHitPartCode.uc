// MILAN CHANGE - 11/23/2026 - Mgamerz
// Send -3 if mesh is hit
public simulated function int GetNetHitPartCode(PrimitiveComponent HitComp)
{
    if (HitComp != None && HitComp == InvisShieldMesh)
    {
        return -3;
    }
    return Super.GetNetHitPartCode(HitComp);
}
