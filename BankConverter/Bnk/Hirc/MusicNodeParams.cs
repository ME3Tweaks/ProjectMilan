namespace BankConverter.Bnk.Hirc;

public sealed class Stinger
{
    public uint TriggerId, SegmentId;
    public uint SyncPlayAt;
    public uint CueFilterHash;
    public int DontRepeatTime;
    public uint NumSegmentLookAhead;
}

/// <summary>CAkMusicNode::SetMusicNodeParams - shared by MusicSegment/MusicTrack/MusicSwitchContainer/MusicRanSeqContainer.</summary>
public sealed class MusicNodeParams
{
    public NodeBaseParams NodeBase = null!;
    public List<uint> ChildIds = new();

    public double GridPeriod, GridOffset;
    public float Tempo;
    public byte TimeSigNumBeatsBar, TimeSigBeatValue;
    public bool MeterInfoFlag;

    public List<Stinger> Stingers = new();

    public static MusicNodeParams ReadV56(BankReader r)
    {
        var p = new MusicNodeParams();
        // uFlags: v56 (<=89) doesn't have this field at all.
        p.NodeBase = NodeBaseParams.ReadV56(r);

        var childCount = r.U32();
        for (var i = 0; i < childCount; i++) p.ChildIds.Add(r.U32());

        p.GridPeriod = r.D64();
        p.GridOffset = r.D64();
        p.Tempo = r.F32();
        p.TimeSigNumBeatsBar = r.U8();
        p.TimeSigBeatValue = r.U8();
        p.MeterInfoFlag = r.U8() != 0;

        var stingerCount = r.U32();
        for (var i = 0; i < stingerCount; i++)
        {
            var s = new Stinger
            {
                TriggerId = r.U32(),
                SegmentId = r.U32(),
                SyncPlayAt = r.U32(),
                CueFilterHash = r.U32(),
                DontRepeatTime = r.S32(),
                NumSegmentLookAhead = r.U32(),
            };
            p.Stingers.Add(s);
        }

        return p;
    }

    public void WriteV134(BankWriter w, Func<uint, uint> remapBusId)
    {
        w.U8(0); // uFlags: no v56 source, default (no midi overrides)
        NodeBase.WriteV134(w, remapBusId);

        w.U32((uint)ChildIds.Count);
        foreach (var id in ChildIds) w.U32(id);

        w.D64(GridPeriod);
        w.D64(GridOffset);
        w.F32(Tempo);
        w.U8(TimeSigNumBeatsBar);
        w.U8(TimeSigBeatValue);
        w.U8((byte)(MeterInfoFlag ? 1 : 0));

        w.U32((uint)Stingers.Count);
        foreach (var s in Stingers)
        {
            w.U32(s.TriggerId);
            w.U32(s.SegmentId);
            w.U32(s.SyncPlayAt);
            w.U32(s.CueFilterHash);
            w.S32(s.DontRepeatTime);
            w.U32(s.NumSegmentLookAhead);
        }
    }
}
