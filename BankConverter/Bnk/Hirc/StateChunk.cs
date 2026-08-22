namespace BankConverter.Bnk.Hirc;

public sealed class StateGroupEntry
{
    public uint StateGroupId;
    public byte SyncType;
    public List<(uint StateId, uint StateInstanceId)> States = new();
}

public sealed class StatePropertyInfo
{
    public uint PropertyId;
    public byte AccumType;
    public bool InDb;
}

/// <summary>
/// v56 uses CAkParameterNodeBase::ReadStateChunk (no state-properties list, fixed-width counts).
/// v134 uses CAkStateAware::ReadStateChunk (adds a state-properties list, var-encoded counts).
/// In practice both are empty for nearly all objects in this game's content.
/// </summary>
public sealed class StateChunk
{
    public List<StatePropertyInfo> StateProps = new(); // v134 only; always empty when converting from v56
    public List<StateGroupEntry> Groups = new();

    public static StateChunk ReadV56(BankReader r)
    {
        var c = new StateChunk();
        var count = r.U32();
        for (var i = 0; i < count; i++)
        {
            var g = new StateGroupEntry { StateGroupId = r.U32(), SyncType = r.U8() };
            var stateCount = r.U16();
            for (var s = 0; s < stateCount; s++)
            {
                g.States.Add((r.U32(), r.U32()));
            }
            c.Groups.Add(g);
        }
        return c;
    }

    public void WriteV134(BankWriter w)
    {
        w.Var((uint)StateProps.Count);
        foreach (var p in StateProps)
        {
            w.Var(p.PropertyId);
            w.U8(p.AccumType);
            w.U8((byte)(p.InDb ? 1 : 0));
        }

        w.Var((uint)Groups.Count);
        foreach (var g in Groups)
        {
            w.U32(g.StateGroupId);
            w.U8(g.SyncType);
            w.Var((uint)g.States.Count);
            foreach (var (stateId, instanceId) in g.States)
            {
                w.U32(stateId);
                w.U32(instanceId);
            }
        }
    }
}
