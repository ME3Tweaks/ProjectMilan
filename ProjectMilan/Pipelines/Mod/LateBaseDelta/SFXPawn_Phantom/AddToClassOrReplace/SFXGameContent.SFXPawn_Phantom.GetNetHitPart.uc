// MILAN CHANGE - 11/23/2026 - Mgamerz
// Phantom override - check if shield is active for impact
public simulated function PrimitiveComponent GetNetHitPart(int Code)
{
    if (Code == -3)
    {
        if (bShieldActive)
        {
            return InvisShieldMesh;
        }
        return None;
    }
    return Super.GetNetHitPart(Code);
}
