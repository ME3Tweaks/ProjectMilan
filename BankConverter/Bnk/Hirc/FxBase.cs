namespace BankConverter.Bnk.Hirc;

public sealed class MediaMapEntry
{
    public byte Index;
    public uint SourceId;
}

/// <summary>
/// CAkFxBase / eHircType 0x12(v56 FxShareSet)/0x13(v56 FxCustom), remapped to 0x10/0x11 at v134.
/// Identical shape between versions except v134 adds a wholly-new trailing StateChunk + PluginPropertyValue
/// list that has no v56 source data (written empty).
/// </summary>
public sealed class FxBase
{
    public uint Id;
    public uint PluginId;
    public byte[]? ParamBlock;
    public List<MediaMapEntry> Media = new();
    public RtpcList Rtpc = null!;

    public static FxBase ReadV56(BankReader r)
    {
        var f = new FxBase { Id = r.U32(), PluginId = r.U32() };

        if (f.PluginId != 0 && f.PluginId != 0xFFFFFFFF)
        {
            var size = r.U32();
            if (size > 0) f.ParamBlock = r.Bytes((int)size);
        }

        var mediaCount = r.U8();
        for (var i = 0; i < mediaCount; i++)
        {
            f.Media.Add(new MediaMapEntry { Index = r.U8(), SourceId = r.U32() });
        }

        f.Rtpc = RtpcList.ReadV56(r);
        // v56 (<=89): nothing further.
        return f;
    }

    public byte[] WriteV134()
    {
        var w = new BankWriter();
        w.U32(Id);
        w.U32(PluginId);

        if (PluginId != 0 && PluginId != 0xFFFFFFFF)
        {
            var bytes = ParamBlock ?? Array.Empty<byte>();
            w.U32((uint)bytes.Length);
            if (bytes.Length > 0) w.Bytes(bytes);
        }

        w.U8((byte)Media.Count);
        foreach (var m in Media)
        {
            w.U8(m.Index);
            w.U32(m.SourceId);
        }

        // false: an FX's RTPC list targets the plugin's own internal parameter indices, not the shared
        // AkRTPC_ParameterID node-property enum - must not go through RtpcList's node-param translation
        // table (see RtpcList.WriteV134's doc comment).
        Rtpc.WriteV134(w, translateParamId: false);

        // v134-only trailing StateChunk + PluginPropertyValue list: no v56 source data, write empty.
        w.Var(0); // ulNumStateProps
        w.Var(0); // ulNumStateGroups
        w.U16(0); // numValues

        return w.ToArray();
    }
}
