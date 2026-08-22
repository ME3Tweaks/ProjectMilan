namespace BankConverter.Bnk.Hirc;

/// <summary>CAkActorMixer / eHircType 0x07. Identical shape (NodeBaseParams + children) across versions.</summary>
public sealed class ActorMixer
{
    public uint Id;
    public NodeBaseParams NodeBase = null!;
    public List<uint> ChildIds = new();

    public static ActorMixer ReadV56(BankReader r)
    {
        var a = new ActorMixer { Id = r.U32() };
        a.NodeBase = NodeBaseParams.ReadV56(r);
        var count = r.U32();
        for (var i = 0; i < count; i++) a.ChildIds.Add(r.U32());
        return a;
    }

    public byte[] WriteV134(Func<uint, uint> remapBusId)
    {
        var w = new BankWriter();
        w.U32(Id);
        NodeBase.WriteV134(w, remapBusId);
        w.U32((uint)ChildIds.Count);
        foreach (var id in ChildIds) w.U32(id);
        return w.ToArray();
    }
}
