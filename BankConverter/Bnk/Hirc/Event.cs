namespace BankConverter.Bnk.Hirc;

/// <summary>CAkEvent / eHircType 0x04. Just a list of Action object IDs (unchanged by the version bump).</summary>
public sealed class Event
{
    public uint Id;
    public List<uint> ActionIds = new();

    public static Event ReadV56(BankReader r)
    {
        var e = new Event { Id = r.U32() };
        var count = r.U32();
        for (var i = 0; i < count; i++) e.ActionIds.Add(r.U32());
        return e;
    }

    public byte[] WriteV134()
    {
        var w = new BankWriter();
        w.U32(Id);
        w.Var((uint)ActionIds.Count);
        foreach (var id in ActionIds) w.U32(id);
        return w.ToArray();
    }
}
