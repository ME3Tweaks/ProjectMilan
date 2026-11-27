// MILAN CHANGE - 11/23/2026 - Mgamerz
// Components don't replicate, which makes phantom shield hits not register from client-> host
// We use negative numbers to track local components and re-use the armor piece replication instead
// to track which part is hit, the pawn class overrides this to provide the value
public simulated function int GetNetHitPartCode(PrimitiveComponent HitComp)
{
    if (HitComp != None && HitComp == Mesh)
    {
        // Hit the mesh
        return -2;
    }
    // Not implemented here
    return -1;
}
