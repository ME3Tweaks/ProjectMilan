namespace BankConverter.Bnk.Hirc;

public sealed class TrackPlaylistItem
{
    public uint TrackId;
    public uint SourceId;
    public uint EventId; // v134 only (version>132); no v56 source, default 0
    public double PlayAt, BeginTrimOffset, EndTrimOffset, SrcDuration;
}

public sealed class ClipAutomationItem
{
    public uint ClipIndex;
    public uint AutoType;
    public List<RtpcCurvePoint> Points = new();
}

/// <summary>
/// CAkMusicTrack / eHircType 0x0B. The rare "switch type" track (eTrackType==3, carrying its own
/// SwitchParams/TransParams sub-structure) is a v134-only concept with no v56 source data to derive it
/// from, so every track is written as the default (non-switch) type - matches the overwhelming majority
/// of real content, which uses plain sequential/random playback.
/// </summary>
public sealed class MusicTrack
{
    public uint Id;
    public List<BankSourceData> Sources = new();
    public List<TrackPlaylistItem> Playlist = new();
    public uint NumSubTrack;
    public List<ClipAutomationItem> ClipAutomation = new();
    public NodeBaseParams NodeBase = null!;
    public short Loop, LoopModMin, LoopModMax;
    public uint RanSeqType; // v56 eRSType; passed through numerically as v134's eTrackType
    public int LookAheadTime;

    public static MusicTrack ReadV56(BankReader r)
    {
        var t = new MusicTrack { Id = r.U32() };

        var sourceCount = r.U32();
        for (var i = 0; i < sourceCount; i++) t.Sources.Add(BankSourceData.ReadV56(r));

        var playlistCount = r.U32();
        if (playlistCount > 0)
        {
            for (var i = 0; i < playlistCount; i++)
            {
                t.Playlist.Add(new TrackPlaylistItem
                {
                    TrackId = r.U32(),
                    SourceId = r.U32(),
                    PlayAt = r.D64(),
                    BeginTrimOffset = r.D64(),
                    EndTrimOffset = r.D64(),
                    SrcDuration = r.D64(),
                });
            }
            t.NumSubTrack = r.U32();
        }

        // v56 (<=62): no clip automation on the wire at all (that's added at >62, which v134 has).

        t.NodeBase = NodeBaseParams.ReadV56(r);

        t.Loop = r.S16();
        t.LoopModMin = r.S16();
        t.LoopModMax = r.S16();

        t.RanSeqType = r.U32();
        t.LookAheadTime = r.S32();

        return t;
    }

    public byte[] WriteV134(Func<uint, uint> remapBusId, Func<uint, uint?>? sourceSizeOverride = null, Func<uint, bool>? isFullyEmbedded = null, Func<uint, bool>? isFxSupported = null)
    {
        var w = new BankWriter();
        w.U32(Id);

        w.U8(0); // uFlags: no v56 source, default (no midi overrides)

        w.U32((uint)Sources.Count);
        foreach (var s in Sources) s.WriteV134(w, sourceSizeOverride?.Invoke(s.SourceId), isFullyEmbedded?.Invoke(s.SourceId) ?? false);

        w.U32((uint)Playlist.Count);
        if (Playlist.Count > 0)
        {
            foreach (var p in Playlist)
            {
                w.U32(p.TrackId);
                w.U32(p.SourceId);
                w.U32(p.EventId);
                w.D64(p.PlayAt);
                w.D64(p.BeginTrimOffset);
                w.D64(p.EndTrimOffset);
                w.D64(p.SrcDuration);
            }
            w.U32(NumSubTrack);
        }

        w.U32((uint)ClipAutomation.Count);
        foreach (var c in ClipAutomation)
        {
            w.U32(c.ClipIndex);
            w.U32(c.AutoType);
            w.U32((uint)c.Points.Count);
            foreach (var p in c.Points)
            {
                w.F32(p.From);
                w.F32(p.To);
                w.U32(p.Interp);
            }
        }

        // v56's "not looping" default is 1, not 0 - see Sound.WriteV134 for the full explanation
        // (confirmed against reference v134 banks, same bug, same fix, this HIRC type too).
        if (Loop != 1)
        {
            NodeBase.ExtraProps ??= new PropBundle();
            NodeBase.ExtraProps.Props[PropIdV134.Loop] = PropBundle.FromInt(Loop); // not SetInt - 0 (infinite) must survive, see Sound.WriteV134
        }
        if (LoopModMin != 0 || LoopModMax != 0)
        {
            NodeBase.ExtraRanges ??= new PropBundle();
            NodeBase.ExtraRanges.SetRangeInt(PropIdV134.Loop, LoopModMin, LoopModMax);
        }
        NodeBase.WriteV134(w, remapBusId, isFxSupported);

        w.U8((byte)RanSeqType); // eTrackType: numeric passthrough, always non-switch (type 3 needs no extra data here)
        w.S32(LookAheadTime);

        return w.ToArray();
    }
}
