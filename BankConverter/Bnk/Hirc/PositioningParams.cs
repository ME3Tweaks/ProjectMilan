namespace BankConverter.Bnk.Hirc;

public sealed class PathVertex
{
    public float X, Y, Z;
    public int Duration;
}

public sealed class PlaylistItem
{
    public uint VerticesOffset;
    public uint NumVertices;
    public float XRange, YRange, ZRange;
}

/// <summary>
/// CAkParameterNodeBase::SetPositioningParams. Shapes differ significantly between v56 and v134:
/// v56 stores CenterPct/PanLr/PanFr and uAttenuationID directly in this structure; v134 moves those
/// into the NodeInitialParams PropBundle (see PropIdV134.CenterPct/PanLr/PanFr/AttenuationId) and derives
/// has3D purely from bits already in the leading flags byte.
/// </summary>
public sealed class PositioningParams
{
    public bool OverrideParent;
    public bool HasListenerRelativeRouting;
    public bool Has3D;
    public bool IsSpatialized; // v56 only concept

    // BaseGenParams (v56 only on the wire; becomes PropBundle entries on v134)
    public int CenterPct;
    public float PanLr;
    public float PanFr;

    // Gen3DParams
    public uint AttenuationId;
    public bool EnableAttenuation = true;
    public bool HoldEmitterPosAndOrient;
    public bool HoldListenerOrient;
    public byte SpatializationMode; // Ak3DSpatializationMode
    public bool IsDynamic;
    public bool HasAutomation;
    public byte PathMode;
    public bool IsLooping;
    public int TransitionTime;
    public bool FollowOrientation = true;
    public List<PathVertex> Vertices = new();
    public List<PlaylistItem> PlaylistItems = new();

    public static PositioningParams ReadV56(BankReader r)
    {
        var p = new PositioningParams();
        var flags = r.U8();
        p.OverrideParent = (flags & 1) != 0;
        p.HasListenerRelativeRouting = ((flags >> 1) & 1) != 0;

        if (!p.OverrideParent) return p;

        p.CenterPct = r.S32();
        p.PanLr = r.F32();
        p.PanFr = r.F32();

        var cbIs3DAvailable = r.U8();
        p.Has3D = cbIs3DAvailable != 0;
        if (!p.Has3D)
        {
            r.U8(); // bIsPannerEnabled
            return p;
        }

        var eType = r.U32();
        p.AttenuationId = r.U32();
        p.IsSpatialized = r.U8() != 0;

        var hasAutomation = eType == 2;
        var hasDynamic = eType == 3;
        p.HasAutomation = hasAutomation;
        p.IsDynamic = hasDynamic;

        if (hasDynamic) p.IsDynamic = r.U8() != 0;

        if (hasAutomation)
        {
            p.PathMode = (byte)r.U32();
            p.IsLooping = r.U8() != 0;
            p.TransitionTime = r.S32();
            p.FollowOrientation = r.U8() != 0;

            var numVertices = r.U32();
            for (var i = 0; i < numVertices; i++)
            {
                p.Vertices.Add(new PathVertex { X = r.F32(), Y = r.F32(), Z = r.F32(), Duration = r.S32() });
            }

            var numItems = r.U32();
            var items = new PlaylistItem[numItems];
            for (var i = 0; i < numItems; i++)
            {
                items[i] = new PlaylistItem { VerticesOffset = r.U32(), NumVertices = r.U32() };
            }
            // Ak3DAutomationParams, one per playlist item. v56 (<=89) has no fZRange on the wire; v134 does.
            for (var i = 0; i < numItems; i++)
            {
                items[i].XRange = r.F32();
                items[i].YRange = r.F32();
                items[i].ZRange = 0f;
            }
            p.PlaylistItems.AddRange(items);
        }

        return p;
    }

    public void WriteV134(BankWriter w)
    {
        byte flags = 0;
        if (OverrideParent) flags |= 1 << 0;
        // On v134, bit1 does double duty as both "listener relative routing" (bit name) and, per the
        // real grammar's positioning-params reader, "has 3D params follow" (has_3d = bit1). Since a v56
        // object either has Gen3DParams or doesn't, drive this bit from Has3D so the v134 reader finds
        // (or correctly skips) the Gen3DParams block that follows.
        if (OverrideParent && Has3D) flags |= 1 << 1;
        if (OverrideParent)
        {
            // e3DPositionType packed at bit5 (mask 3) on v134: 0 = no automation, nonzero = has automation.
            byte e3DPositionType = (byte)(Has3D && HasAutomation ? 1 : 0);
            flags |= (byte)(e3DPositionType << 5);
        }
        w.U8(flags);

        if (!OverrideParent) return;

        if (Has3D)
        {
            byte bits3d = 0;
            if (EnableAttenuation) bits3d |= 1 << 3;
            if (HoldEmitterPosAndOrient) bits3d |= 1 << 4;
            if (HoldListenerOrient) bits3d |= 1 << 5;
            bits3d |= (byte)(SpatializationMode & 0x3);
            w.U8(bits3d);

            if (HasAutomation)
            {
                w.U8(PathMode);
                w.S32(TransitionTime);

                w.U32((uint)Vertices.Count);
                foreach (var v in Vertices)
                {
                    w.F32(v.X);
                    w.F32(v.Y);
                    w.F32(v.Z);
                    w.S32(v.Duration);
                }

                w.U32((uint)PlaylistItems.Count);
                foreach (var it in PlaylistItems)
                {
                    w.U32(it.VerticesOffset);
                    w.U32(it.NumVertices);
                }
                foreach (var it in PlaylistItems)
                {
                    w.F32(it.XRange);
                    w.F32(it.YRange);
                    w.F32(it.ZRange);
                }
            }
        }
    }
}
