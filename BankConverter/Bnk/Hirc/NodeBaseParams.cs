namespace BankConverter.Bnk.Hirc;

/// <summary>
/// CAkParameterNodeBase::SetNodeBaseParams. Read as v56, converted+written as v134.
/// Several v56 fields have no direct v134 equivalent field and instead become sparse entries in the
/// v134 NodeInitialParams AkPropBundle: v56's fixed Volume/LFE/Pitch/LPF(+min/max) become PropBundle
/// entries; v56's ucPriority/iDistOffset become Priority/PriorityDistanceOffset props; v56's
/// PositioningParams CenterPct/PanLr/PanFr and uAttenuationID become CenterPCT/PAN_LR/PAN_FR/AttenuationID props.
/// </summary>
public sealed class NodeBaseParams
{
    public InitialFxParams Fx = null!;
    public uint OverrideBusId;
    public uint DirectParentId;

    // v56 priority fields (folded into the v134 PropBundle as Priority/PriorityDistanceOffset)
    public byte Priority;
    public bool PriorityOverrideParent;
    public bool PriorityApplyDistFactor;
    public sbyte DistOffset;

    // v56 fixed InitialParams (folded into the v134 PropBundle)
    public float Volume, VolumeMin, VolumeMax;
    public float Lfe, LfeMin, LfeMax;
    public float Pitch, PitchMin, PitchMax;
    public float Lpf, LpfMin, LpfMax;

    public PositioningParams Positioning = null!;
    public AuxParams Aux = null!;
    public AdvSettingsParams AdvSettings = null!;
    public StateChunk States = null!;
    public RtpcList Rtpc = null!;

    /// <summary>Extra PropBundle entries contributed by the owning HIRC type (e.g. Sound's Loop field).</summary>
    public PropBundle? ExtraProps;
    public PropBundle? ExtraRanges;

    public static NodeBaseParams ReadV56(BankReader r)
    {
        var p = new NodeBaseParams
        {
            Fx = InitialFxParams.Read(r),
        };
        // bOverrideAttachmentParams: not present <=89 (v56 doesn't have it)
        p.OverrideBusId = r.U32();
        p.DirectParentId = r.U32();

        p.Priority = r.U8();
        p.PriorityOverrideParent = r.U8() != 0;
        p.PriorityApplyDistFactor = r.U8() != 0;
        p.DistOffset = r.S8();

        // NodeInitialParams (v56 fixed RANGED_MODIFIERS<float> shape)
        p.Volume = r.F32(); p.VolumeMin = r.F32(); p.VolumeMax = r.F32();
        p.Lfe = r.F32(); p.LfeMin = r.F32(); p.LfeMax = r.F32();
        p.Pitch = r.F32(); p.PitchMin = r.F32(); p.PitchMax = r.F32();
        p.Lpf = r.F32(); p.LpfMin = r.F32(); p.LpfMax = r.F32();
        // ulStateGroupID: not present > v52 (v56 doesn't have it)

        p.Positioning = PositioningParams.ReadV56(r);
        // AuxParams: version<=65 takes the "pass" branch in the real grammar, so v56 (<=65) never has
        // this data on the wire at all. It's a v134-only addition, written with defaults below.
        p.Aux = new AuxParams();
        p.AdvSettings = AdvSettingsParams.ReadV56(r);
        p.States = StateChunk.ReadV56(r);
        p.Rtpc = RtpcList.ReadV56(r);
        // FeedbackInfo: this game never sets bFeedbackInBank, so nothing to read here.

        return p;
    }

    public void WriteV134(BankWriter w, Func<uint, uint> remapBusId, Func<uint, bool>? isFxSupported = null)
    {
        Fx.Write(w, isFxSupported);
        // bOverrideAttachmentParams (v134-only field, no v56 source data; default false)
        w.U8(0);

        w.U32(remapBusId(OverrideBusId));
        w.U32(DirectParentId);

        byte priorityBits = 0;
        if (PriorityOverrideParent) priorityBits |= 1 << 0;
        if (PriorityApplyDistFactor) priorityBits |= 1 << 1;
        w.U8(priorityBits);

        WriteInitialParamsV134(w);

        Positioning.WriteV134(w);
        Aux.WriteV134(w);
        AdvSettings.WriteV134(w);
        States.WriteV134(w);
        Rtpc.WriteV134(w);
        // FeedbackInfo: not present at v134.
    }

    private void WriteInitialParamsV134(BankWriter w)
    {
        var props = new PropBundle();
        var ranges = new PropBundle();

        props.SetFloat(PropIdV134.Volume, Volume);
        ranges.SetRangeFloat(PropIdV134.Volume, VolumeMin, VolumeMax);
        props.SetFloat(PropIdV134.Lfe, Lfe);
        ranges.SetRangeFloat(PropIdV134.Lfe, LfeMin, LfeMax);
        props.SetFloat(PropIdV134.Pitch, Pitch);
        ranges.SetRangeFloat(PropIdV134.Pitch, PitchMin, PitchMax);
        props.SetFloat(PropIdV134.Lpf, Lpf);
        ranges.SetRangeFloat(PropIdV134.Lpf, LpfMin, LpfMax);

        // Priority/PriorityDistanceOffset are stored as floats in real v134 data (confirmed against
        // reference LE3 banks), even though v56 reads/stores them as small integers on the wire.
        // Wwise defaults are 50 (Priority) and -10 (DistOffset), not 0 - only emit if they differ from
        // the v56 default (confirmed: pristine v134 omits PriorityDistanceOffset entirely for every
        // sampled Sound whose v56 DistOffset was -10 - writing it unconditionally on != 0 was injecting
        // a bogus prop into effectively every Sound in the game).
        if (Priority != 50) props.SetFloat(PropIdV134.Priority, Priority);
        if (DistOffset != -10) props.SetFloat(PropIdV134.PriorityDistanceOffset, DistOffset);

        if (Positioning.OverrideParent)
        {
            // CenterPct is also a float in v134 despite being s32 on the v56 wire (confirmed against reference data).
            props.SetFloat(PropIdV134.CenterPct, Positioning.CenterPct);
            // PanLr/PanFr are 2D direct-speaker-assignment panning - meaningless once 3D positioning takes
            // over. Confirmed against reference data: a Has3D object with a real nonzero v56 PanFr still has
            // no PAN_FR prop at all in the pristine v134 bank (CenterPct is still present, so this gate is
            // specific to Pan Lr/Fr, not the whole block) - writing them unconditionally was injecting a
            // bogus PAN_FR prop into every 3D-positioned object.
            if (!Positioning.Has3D)
            {
                props.SetFloat(PropIdV134.PanLr, Positioning.PanLr);
                props.SetFloat(PropIdV134.PanFr, Positioning.PanFr);
            }
            if (Positioning.Has3D && Positioning.AttenuationId != 0)
            {
                props.Props[PropIdV134.AttenuationId] = Positioning.AttenuationId;
            }
        }

        if (ExtraProps != null)
            foreach (var (id, val) in ExtraProps.Props) props.Props[id] = val;
        if (ExtraRanges != null)
            foreach (var (id, val) in ExtraRanges.Ranges) ranges.Ranges[id] = val;

        props.WriteProps(w);
        ranges.WriteRanges(w);
    }
}
