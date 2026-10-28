namespace BankConverter.Bnk.Hirc;

/// <summary>CAkSound / eHircType 0x02.</summary>
public sealed class Sound
{
    public uint Id;
    public BankSourceData Source = null!;
    public NodeBaseParams NodeBase = null!;

    // v56 only; folded into the v134 PropBundle as Loop(+ranged min/max).
    public short Loop, LoopModMin, LoopModMax;

    // ME3 -> LE3 specific fixes
    // Change volume values for fembot heavy melee
    // These seem to be asari stuff put in a filter so probably don't want them too loud
    // might be why bioware didn't bother either
    private static readonly Dictionary<uint, float> VolumeOverrides = new()
    {
        [13809640] = -3f, [179403519] = -3f, [206269821] = -3f, [224099339] = -3f, [227149206] = -3f,
        [248023457] = -3f, [319276070] = -3f, [375639249] = -3f, [555866137] = -3f, [850103009] = -3f,
        [937756221] = -3f, [954268620] = -3f, [962997130] = -3f, [1066837790] = -3f,
    };

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
        //
        // Assigned directly, NOT via SetInt: SetInt drops zero as "default", but here 0 is the meaningful
        // value (infinite) and the default is 1. Going through SetInt converted every infinitely-looping
        // Sound into a play-once one, which the game then re-posts after it ends - an audible gap between
        // "loops" (MPCer2's insect swarm, the shuttle idle). Native LE3 writes Loop=0 explicitly on 705 Sounds.
        if (Loop != 1)
        {
            NodeBase.ExtraProps ??= new PropBundle();
            NodeBase.ExtraProps.Props[PropIdV134.Loop] = PropBundle.FromInt(Loop);
        }
        if (LoopModMin != 0 || LoopModMax != 0)
        {
            NodeBase.ExtraRanges ??= new PropBundle();
            NodeBase.ExtraRanges.SetRangeInt(PropIdV134.Loop, LoopModMin, LoopModMax);
        }

        if (VolumeOverrides.TryGetValue(Id, out var volume)) NodeBase.Volume = volume;

        NodeBase.WriteV134(w, remapBusId, isFxSupported);
        return w.ToArray();
    }
}
