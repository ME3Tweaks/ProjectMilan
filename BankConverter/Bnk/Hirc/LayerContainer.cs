namespace BankConverter.Bnk.Hirc;

public sealed class LayerAssoc
{
    public uint ChildId;
    public List<RtpcCurvePoint> Curve = new();
}

public sealed class Layer
{
    public uint LayerId;
    public RtpcList Rtpc = null!;
    public uint RtpcId;
    public float CrossfadingRtpcDefaultValue; // v56 only; no v134 equivalent
    public List<LayerAssoc> Assocs = new();
}

/// <summary>CAkLayerCntr / eHircType 0x09 (BlendContainer).</summary>
public sealed class LayerContainer
{
    public uint Id;
    public NodeBaseParams NodeBase = null!;
    public List<uint> ChildIds = new();
    public List<Layer> Layers = new();
    public bool IsContinuousValidation; // v134 only; no v56 source, default false

    public static LayerContainer ReadV56(BankReader r)
    {
        var c = new LayerContainer { Id = r.U32() };
        c.NodeBase = NodeBaseParams.ReadV56(r);

        var childCount = r.U32();
        for (var i = 0; i < childCount; i++) c.ChildIds.Add(r.U32());

        var layerCount = r.U32();
        for (var i = 0; i < layerCount; i++)
        {
            var layer = new Layer { LayerId = r.U32() };
            layer.Rtpc = RtpcList.ReadV56(r);
            layer.RtpcId = r.U32();
            layer.CrossfadingRtpcDefaultValue = r.F32();

            var assocCount = r.U32();
            for (var j = 0; j < assocCount; j++)
            {
                var assoc = new LayerAssoc { ChildId = r.U32() };
                var curveSize = r.U32();
                for (var k = 0; k < curveSize; k++)
                {
                    assoc.Curve.Add(new RtpcCurvePoint { From = r.F32(), To = r.F32(), Interp = r.U32() });
                }
                layer.Assocs.Add(assoc);
            }

            c.Layers.Add(layer);
        }

        return c;
    }

    public byte[] WriteV134(Func<uint, uint> remapBusId, Func<uint, bool>? isFxSupported = null)
    {
        var w = new BankWriter();
        w.U32(Id);
        NodeBase.WriteV134(w, remapBusId, isFxSupported);

        w.U32((uint)ChildIds.Count);
        foreach (var id in ChildIds) w.U32(id);

        w.U32((uint)Layers.Count);
        foreach (var layer in Layers)
        {
            w.U32(layer.LayerId);
            layer.Rtpc.WriteV134(w);
            w.U32(layer.RtpcId);
            w.U8(0); // rtpcType: no v56 source, default 0 (GameParameter)

            w.U32((uint)layer.Assocs.Count);
            foreach (var assoc in layer.Assocs)
            {
                w.U32(assoc.ChildId);
                w.U32((uint)assoc.Curve.Count);
                foreach (var p in assoc.Curve)
                {
                    w.F32(p.From);
                    w.F32(p.To);
                    w.U32(p.Interp);
                }
            }
        }

        w.U8((byte)(IsContinuousValidation ? 1 : 0));
        return w.ToArray();
    }
}
