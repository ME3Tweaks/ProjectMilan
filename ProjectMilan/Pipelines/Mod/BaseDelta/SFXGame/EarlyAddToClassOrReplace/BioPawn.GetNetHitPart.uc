// MILAN CHANGE - 11/23/2026 - Mgamerz
// Host side of GetNetHitPartCode
public simulated function PrimitiveComponent GetNetHitPart(int Code)
{
    if (Code == -2)
    {
        return Mesh;
    }
    return None;
}
