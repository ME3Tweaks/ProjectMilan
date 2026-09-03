namespace BankConverter.Bnk.Hirc;

/// <summary>CAkSound / eHircType 0x02.</summary>
public sealed class Sound
{
    public uint Id;
    public BankSourceData Source = null!;
    public NodeBaseParams NodeBase = null!;

    // v56 only; folded into the v134 PropBundle as Loop(+ranged min/max).
    public short Loop, LoopModMin, LoopModMax;

    public static Sound ReadV56(BankReader r)
    {
        var s = new Sound { Id = r.U32() };
        s.Source = BankSourceData.ReadV56(r);
        s.NodeBase = NodeBaseParams.ReadV56(r);
        s.Loop = r.S16();
        s.LoopModMin = r.S16();
        s.LoopModMax = r.S16();
        return s;
    }

    public byte[] WriteV134(Func<uint, uint> remapBusId, Func<uint, uint?>? sourceSizeOverride = null, Func<uint, bool>? isFullyEmbedded = null, Func<uint, bool>? isFxSupported = null)
    {
        var w = new BankWriter();
        w.U32(Id);
        Source.WriteV134(w, sourceSizeOverride?.Invoke(Source.SourceId), isFullyEmbedded?.Invoke(Source.SourceId) ?? false);

        // Loop moved from a dedicated field (v56) into the PropBundle (v134, PropIdV134.Loop). v56's
        // "not looping" default is 1 (Wwise's Loop count convention: 1 = play once, 0 = infinite), not
        // 0 - confirmed against reference v134 banks, which omit this prop entirely for non-looping
        // Sounds. Checking != 0 was injecting an explicit Loop=1 prop into nearly every Sound in the
        // game (v56's default value), which is what almost every real-world Sound actually has.
        if (Loop != 1)
        {
            NodeBase.ExtraProps ??= new PropBundle();
            NodeBase.ExtraProps.SetInt(PropIdV134.Loop, Loop);
        }
        if (LoopModMin != 0 || LoopModMax != 0)
        {
            NodeBase.ExtraRanges ??= new PropBundle();
            NodeBase.ExtraRanges.SetRangeInt(PropIdV134.Loop, LoopModMin, LoopModMax);
        }

        NodeBase.WriteV134(w, remapBusId, isFxSupported);
        return w.ToArray();
    }
}
