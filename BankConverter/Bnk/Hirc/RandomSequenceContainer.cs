namespace BankConverter.Bnk.Hirc;

public sealed class PlaylistEntry
{
    public uint PlayId;
    public int Weight; // v56: u8, 0-100 (a percentage). Raw v56 value, NOT yet rescaled for v134 - see WriteV134.
}

/// <summary>CAkRanSeqCntr / eHircType 0x05.</summary>
public sealed class RandomSequenceContainer
{
    public uint Id;
    public NodeBaseParams NodeBase = null!;
    public ushort LoopCount;
    // v56 (<=72) has no loop-count modifier range at all; defaults to 0 (no randomization) at v134.
    public ushort LoopModMin, LoopModMax;
    public float TransitionTime, TransitionTimeModMin, TransitionTimeModMax;
    public ushort AvoidRepeatCount;
    public byte TransitionMode, RandomMode, Mode;
    public bool IsUsingWeight, ResetPlayListAtEachPlay, IsRestartBackward, IsContinuous, IsGlobal;
    public List<uint> ChildIds = new();
    public List<PlaylistEntry> Playlist = new();

    public static RandomSequenceContainer ReadV56(BankReader r)
    {
        var c = new RandomSequenceContainer { Id = r.U32() };
        c.NodeBase = NodeBaseParams.ReadV56(r);

        c.LoopCount = r.U16();
        // v56 <=72: no LoopModMin/Max on the wire.

        c.TransitionTime = r.F32();
        c.TransitionTimeModMin = r.F32();
        c.TransitionTimeModMax = r.F32();

        c.AvoidRepeatCount = r.U16();

        c.TransitionMode = r.U8();
        c.RandomMode = r.U8();
        c.Mode = r.U8();

        c.IsUsingWeight = r.U8() != 0;
        c.ResetPlayListAtEachPlay = r.U8() != 0;
        c.IsRestartBackward = r.U8() != 0;
        c.IsContinuous = r.U8() != 0;
        c.IsGlobal = r.U8() != 0;

        var childCount = r.U32();
        for (var i = 0; i < childCount; i++) c.ChildIds.Add(r.U32());

        var playCount = r.U16();
        for (var i = 0; i < playCount; i++)
        {
            c.Playlist.Add(new PlaylistEntry { PlayId = r.U32(), Weight = r.U8() });
        }

        return c;
    }

    public byte[] WriteV134(Func<uint, uint> remapBusId, Func<uint, bool>? isFxSupported = null)
    {
        var w = new BankWriter();
        w.U32(Id);
        NodeBase.WriteV134(w, remapBusId, isFxSupported);

        w.U16(LoopCount);
        w.U16(LoopModMin);
        w.U16(LoopModMax);

        w.F32(TransitionTime);
        w.F32(TransitionTimeModMin);
        w.F32(TransitionTimeModMax);

        w.U16(AvoidRepeatCount);

        w.U8(TransitionMode);
        w.U8(RandomMode);
        w.U8(Mode);

        byte bits = 0;
        if (IsUsingWeight) bits |= 1 << 0;
        if (ResetPlayListAtEachPlay) bits |= 1 << 1;
        if (IsRestartBackward) bits |= 1 << 2;
        if (IsContinuous) bits |= 1 << 3;
        if (IsGlobal) bits |= 1 << 4;
        w.U8(bits);

        w.U32((uint)ChildIds.Count);
        foreach (var id in ChildIds) w.U32(id);

        w.U16((ushort)Playlist.Count);
        foreach (var p in Playlist)
        {
            w.U32(p.PlayId);
            // v56's weight is a 0-100 percentage; v134's wire format stores it at 0.001% granularity
            // (percentage * 1000) rather than just widening the raw byte - confirmed empirically against a
            // pristine v134 bank (every sampled playlist entry's real weight equals the v56 value * 1000).
            w.S32(p.Weight * 1000);
        }

        return w.ToArray();
    }
}
