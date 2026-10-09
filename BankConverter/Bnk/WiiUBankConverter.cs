using BankConverter.Bnk.Chunks;
using BankConverter.Bnk.Hirc;

namespace BankConverter.Bnk;

/// <summary>
/// Narrow, fail-closed big-endian v65 -> little-endian v134 path for SmartMissile's HIRC subset.
/// Independent of the v56 parser: v65 has sparse properties, compact action types, wider playlist
/// weights, four attenuation slots, and no Sound loop triple or layer default-value float.
/// No unknown objects/chunks, effects, feedback, streaming, or properties are silently discarded.
/// </summary>
public static class WiiUBankConverter
{
    public static byte[] ConvertToV134(byte[] bytes, HircConversionStats stats)
    {
        var chunks = new Dictionary<string, byte[]>();
        var r = new BankReader(bytes, bigEndian: true);
        while (!r.AtEnd)
        {
            var tag = r.Tag4();
            if (tag is not ("BKHD" or "DIDX" or "DATA" or "HIRC" or "STID"))
                throw new NotSupportedException($"Unsupported Wii U bank chunk {tag}.");
            chunks.Add(tag, r.Bytes(checked((int)r.U32())));
        }
        var header = BkhdChunk.ReadV56(new BankReader(chunks["BKHD"], true), (uint)chunks["BKHD"].Length);
        if (header.BankGeneratorVersion != 65 || header.FeedbackInBank != 0 || header.LanguageId != 0)
            throw new NotSupportedException("Only big-endian v65 SFX banks without feedback are supported.");
        if (header.V56Padding.Any(b => b != 0)) throw new NotSupportedException("Nonzero v65 header padding needs review.");
        var index = DidxChunk.Read(new BankReader(chunks["DIDX"], true), (uint)chunks["DIDX"].Length);
        if (chunks["DIDX"].Length % 12 != 0) throw new InvalidDataException("Invalid DIDX length.");
        var newIndex = new DidxChunk();
        var media = new BankWriter();
        var sizes = new Dictionary<uint, uint>();
        foreach (var entry in index.Media)
        {
            var wem = WiiUAdpcmWem.ConvertToLittleEndian(chunks["DATA"].AsSpan(checked((int)entry.Offset), checked((int)entry.Size)).ToArray());
            // Preserve 16-byte media alignment for the target runtime, independently of source padding.
            while ((media.Position & 15) != 0) media.U8(0);
            newIndex.Media.Add(new MediaHeader { Id = entry.Id, Offset = (uint)media.Position, Size = (uint)wem.Length });
            sizes.Add(entry.Id, (uint)wem.Length);
            media.Bytes(wem);
        }
        var hirc = ConvertHirc(chunks["HIRC"], sizes, header.SoundBankId, stats);
        var w = new BankWriter();
        var bkhd = header.WriteV134Body();
        var didx = newIndex.Write();
        var padding = BkhdChunk.ComputeAlignmentPadding(8 + bkhd.Length + 8 + didx.Length);
        WriteChunk("BKHD", bkhd.Concat(padding).ToArray());
        WriteChunk("DIDX", didx);
        WriteChunk("DATA", media.ToArray());
        WriteChunk("HIRC", hirc);
        if (chunks.TryGetValue("STID", out var stid))
        {
            var strings = new BankReader(stid, true);
            var mapping = StidChunk.Read(strings);
            RequireEnd(strings, "STID");
            WriteChunk("STID", mapping.Write());
        }
        return w.ToArray();

        void WriteChunk(string tag, byte[] body) { w.Tag4(tag); w.U32((uint)body.Length); w.Bytes(body); }
    }

    private static uint RemapBusStrict(uint id)
    {
        if (id == 0) return 0;
        if (BusRemap.TryRemap(id, out var target)) return target;
        // NO FALLBACK TO MASTER AUDIO BUS: it is loud/unmixed. New Wii U buses need a real mapping.
        throw new NotSupportedException($"Unmapped Wii U bus {id}; refusing loud Master Audio Bus fallback.");
    }

    private static byte[] ConvertHirc(byte[] bytes, Dictionary<uint, uint> mediaSizes, uint bankId, HircConversionStats stats)
    {
        var r = new BankReader(bytes, true);
        var count = r.U32();
        var w = new BankWriter(); w.U32(count);
        var ids = new HashSet<uint>();
        for (uint i = 0; i < count; i++)
        {
            var type = r.U8();
            var body = r.Bytes(checked((int)r.U32()));
            var b = new BankReader(body, true);
            var id = b.U32();
            if (!ids.Add(id)) throw new InvalidDataException($"Duplicate HIRC ID {id}.");
            byte[] output = type switch
            {
                2 => ReadSound(b, id, mediaSizes, bankId).WriteV134(RemapBusStrict, sid => mediaSizes[sid]),
                3 => ConvertAction(b, id),
                4 => ReadEvent(b, id).WriteV134(),
                5 => ReadRandom(b, id).WriteV134(RemapBusStrict),
                7 => ReadActor(b, id).WriteV134(RemapBusStrict),
                9 => ReadLayer(b, id).WriteV134(RemapBusStrict),
                14 => ReadAttenuation(b, id).WriteV134(),
                _ => throw new NotSupportedException($"Unsupported Wii U HIRC type {type:X2}, ID {id}.")
            };
            RequireEnd(b, $"HIRC {type:X2}/{id}");
            w.U8(type); w.U32((uint)output.Length); w.Bytes(output);
            stats.Total++;
            stats.Converted[type] = stats.Converted.GetValueOrDefault(type) + 1;
        }
        RequireEnd(r, "HIRC");
        return w.ToArray();
    }

    private static Sound ReadSound(BankReader r, uint id, Dictionary<uint, uint> mediaSizes, uint bankId)
    {
        var source = BankSourceData.ReadV56(r); // source wire layout is unchanged through v65.
        if (source.PluginId != 0x00020001 || source.StreamType != SourceStreamType.Data ||
            !mediaSizes.TryGetValue(source.SourceId, out var size) || source.InMemoryMediaSize != size ||
            source.FileId != bankId || source.ExternallySupplied || source.IsLanguageSpecific)
            throw new NotSupportedException($"Sound {id} is not a locally embedded Wwise IMA source.");
        return new Sound { Id = id, Source = source, NodeBase = ReadNode(r), Loop = 1 };
    }

    private static NodeBaseParams ReadNode(BankReader r)
    {
        var p = new NodeBaseParams { Fx = InitialFxParams.Read(r), OverrideBusId = r.U32(), DirectParentId = r.U32(),
            Priority = 50, DistOffset = -10, PriorityOverrideParent = r.U8() != 0, PriorityApplyDistFactor = r.U8() != 0 };
        if (p.Fx.Fx.Count != 0) throw new NotSupportedException("Wii U effect chains require separate review.");
        p.ExtraProps = TranslateProps(PropBundle.ReadV56(r));
        p.ExtraRanges = TranslateProps(PropBundle.ReadRangedV56(r));
        p.Positioning = ReadPositioning(r);
        p.Aux = new AuxParams();
        p.AdvSettings = AdvSettingsParams.ReadV56(r);
        p.States = StateChunk.ReadV56(r);
        p.Rtpc = RtpcList.ReadV56(r); // same enum and curve scaling as v56.
        return p;
    }

    private static PropBundle TranslateProps(PropBundle input)
    {
        var result = new PropBundle();
        foreach (var (id, bits) in input.Props) result.Props[MapProp(id)] = bits;
        foreach (var (id, range) in input.Ranges) result.Ranges[MapProp(id)] = range;
        return result;
    }

    private static byte MapProp(byte id) => id switch
    {
        0 => PropIdV134.Volume, 1 => PropIdV134.Lfe, 2 => PropIdV134.Pitch, 3 => PropIdV134.Lpf,
        4 => PropIdV134.Priority, 5 => PropIdV134.PriorityDistanceOffset, 6 => PropIdV134.Loop,
        9 => PropIdV134.MuteRatio, 10 => PropIdV134.PanLr, 11 => PropIdV134.PanFr,
        12 => PropIdV134.CenterPct, 13 => PropIdV134.DelayTime, 14 => PropIdV134.TransitionTime,
        _ => throw new NotSupportedException($"Unverified v65 property {id:X2}.")
    };

    private static PositioningParams ReadPositioning(BankReader r)
    {
        var flags = r.U8();
        if ((flags & ~3) != 0) throw new NotSupportedException("Unknown v65 positioning flags.");
        var p = new PositioningParams { OverrideParent = (flags & 1) != 0 };
        if (!p.OverrideParent) return p;
        p.Has3D = r.U8() != 0;
        if (!p.Has3D)
        {
            if (r.U8() != 0) throw new NotSupportedException("Enabled 2D panner requires separate mapping.");
            return p;
        }
        var type = r.U32();
        p.AttenuationId = r.U32(); p.IsSpatialized = r.U8() != 0;
        if (type != 3) throw new NotSupportedException("Only game-defined 3D positioning is verified for v65.");
        p.IsDynamic = r.U8() != 0;
        p.HoldEmitterPosAndOrient = !p.IsDynamic;
        p.SpatializationMode = (byte)(p.IsSpatialized ? 1 : 0);
        return p;
    }

    private static Event ReadEvent(BankReader r, uint id)
    {
        var e = new Event { Id = id };
        ReadIds(r, e.ActionIds); return e;
    }

    private static ActorMixer ReadActor(BankReader r, uint id)
    {
        var a = new ActorMixer { Id = id, NodeBase = ReadNode(r) };
        ReadIds(r, a.ChildIds); return a;
    }

    private static RandomSequenceContainer ReadRandom(BankReader r, uint id)
    {
        var c = new RandomSequenceContainer { Id = id, NodeBase = ReadNode(r), LoopCount = r.U16(),
            TransitionTime = r.F32(), TransitionTimeModMin = r.F32(), TransitionTimeModMax = r.F32(),
            AvoidRepeatCount = r.U16(), TransitionMode = r.U8(), RandomMode = r.U8(), Mode = r.U8(),
            IsUsingWeight = r.U8() != 0, ResetPlayListAtEachPlay = r.U8() != 0, IsRestartBackward = r.U8() != 0,
            IsContinuous = r.U8() != 0, IsGlobal = r.U8() != 0, WeightsAreV134Units = true };
        ReadIds(r, c.ChildIds);
        var n = r.U16();
        for (int i = 0; i < n; i++) c.Playlist.Add(new PlaylistEntry { PlayId = r.U32(), Weight = r.S32() });
        return c;
    }

    private static LayerContainer ReadLayer(BankReader r, uint id)
    {
        var c = new LayerContainer { Id = id, NodeBase = ReadNode(r) };
        ReadIds(r, c.ChildIds);
        var n = r.U32();
        for (uint i = 0; i < n; i++)
        {
            var layer = new Layer { LayerId = r.U32(), Rtpc = RtpcList.ReadV56(r), RtpcId = r.U32() };
            var count = r.U32();
            for (uint j = 0; j < count; j++)
            {
                var assoc = new LayerAssoc { ChildId = r.U32() };
                ReadPoints(r, assoc.Curve, r.U32());
                // v65 association fades are dB (-96.3 = silent, 0 = unity). v134 feeds
                // the None-scaled table directly into AkMutedMap as a linear multiplier:
                // CAkLayer::SetChildAssoc/GetAudioParameters, Wwise 2019.1 debug SDK.
                // Copying 0dB as linear 0 muted BOTH branches of the impact event.
                foreach (var point in assoc.Curve)
                {
                    if (!float.IsFinite(point.To) || point.To > 0)
                        throw new NotSupportedException("Unverified v65 blend gain outside the attenuation range.");
                    point.To = point.To <= -96.3f ? 0f : MathF.Pow(10f, point.To / 20f);
                }
                layer.Assocs.Add(assoc);
            }
            c.Layers.Add(layer);
        }
        return c;
    }

    private static Attenuation ReadAttenuation(BankReader r, uint id)
    {
        var a = new Attenuation { Id = id, IsConeEnabled = r.U8() != 0 };
        if (a.IsConeEnabled) throw new NotSupportedException("v65 cones require separate review.");
        var dry = r.S8(); var aux = r.S8(); var lpf = r.S8(); var spread = r.S8();
        // v65's four slots: two gain curves, LPF, spread. In this bank the two gain
        // slots both select the same dB_96_3 curve. Mirror it into the modern aux slots.
        // Different selections need confirmation of the old slot-1 send semantics.
        if (aux != dry) throw new NotSupportedException("Unverified distinct v65 attenuation gain slots.");
        a.CurveToUse = [dry, aux, aux, lpf, spread]; // adapt to the shared v56 -> v134 writer's slot order.
        var n = r.U8();
        for (int i = 0; i < n; i++)
        {
            var curve = new AttenCurve { Scaling = r.U8() };
            ReadPoints(r, curve.Points, r.U16()); a.Curves.Add(curve);
        }
        a.Rtpc = RtpcList.ReadV56(r); return a;
    }

    private static byte[] ConvertAction(BankReader r, uint id)
    {
        var type = r.U16();
        if (type is not (0x0403 or 0x0102 or 0x0103))
            throw new NotSupportedException($"Unverified v65 action type {type:X4}.");
        var target = r.U32();
        var props = TranslateProps(PropBundle.ReadV56(r));
        var ranges = TranslateProps(PropBundle.ReadRangedV56(r));
        var fade = r.U8();
        var w = new BankWriter(); w.U32(id); w.U16(type); w.U32(target); w.U8(0);
        props.WriteProps(w); ranges.WriteRanges(w); w.U8(fade);
        if (type == 0x0403) w.U32(r.U32());
        else
        {
            if (r.U32() != 0) throw new NotSupportedException("Nonempty v65 action exceptions require review.");
            w.U8(0); // v134 StopActionSpecificParams, absent in v65.
            w.Var(0); // v134 exception count.
        }
        return w.ToArray();
    }

    private static void ReadIds(BankReader r, List<uint> ids)
    {
        var count = r.U32();
        for (uint i = 0; i < count; i++) ids.Add(r.U32());
    }

    private static void ReadPoints(BankReader r, List<RtpcCurvePoint> points, uint count)
    {
        for (uint i = 0; i < count; i++) points.Add(new RtpcCurvePoint { From = r.F32(), To = r.F32(), Interp = r.U32() });
    }

    private static void RequireEnd(BankReader r, string context)
    {
        if (r.Position != r.Length) throw new InvalidDataException($"{context}: consumed {r.Position}/{r.Length} bytes.");
    }
}
