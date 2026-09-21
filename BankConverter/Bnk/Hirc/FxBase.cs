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

    /// <summary>
    /// Three Audiokinetic plugins changed their parameter struct between Wwise 2011 (v56) and 2019 (v134), so
    /// their v56 block cannot be passed through verbatim. Every other plugin's block is unchanged and IS passed
    /// through.
    ///
    /// Derived by matching Fx objects by fxId across the 1703 banks that exist in both shipping games and diffing
    /// the param blocks - 1040 shared objects, of which 106 differ. The three below are mechanical: one uniform
    /// transform explains 100% of that plugin's objects, and each grows by a fixed amount. The transforms here are
    /// verified exact against every one of those objects (13/13, 11/11, 22/22).
    ///
    /// Four other plugins also differ - 105 (6/123), 106 (4/8), 118 (34/58), 125 (16/56) - and are deliberately
    /// NOT replicated. They are authored edits, not a version migration: the same v56 input maps to DIFFERENT
    /// v134 outputs across objects (plugin 118 at offset 68 goes 0.0 -> -96.0 in 32 objects but 0.0 -> 0.0 in 24
    /// others), and a struct migration cannot be non-deterministic on its own input. Someone edited the Wwise
    /// project; porting ME3 content should keep ME3's values.
    /// </summary>
    internal static byte[] ConvertParamBlockToV134(uint pluginId, byte[] v56)
    {
        switch (PluginSupport.GetPluginNumber(pluginId))
        {
            // Source plugin, 65 -> 69: one new trailing uint32 whose value is always 4. 13/13 exact.
            case 102 when v56.Length == 65:
            {
                var outBytes = new byte[69];
                v56.CopyTo(outBytes, 0);
                BitConverter.GetBytes(4u).CopyTo(outBytes, 65);
                return outBytes;
            }

            // Effect, 48 -> 52: a new zero uint32 is inserted at offset 32, pushing the rest down one slot. The
            // field that lands at offset 40 is a dB level which v56 left at 0.0 when unset and v134 writes as the
            // -96.0 silence floor; where v56 already had a real value (one object carries -96.3) it is preserved.
            // 11/11 exact - a plain insert alone matches only 1 of the 11.
            case 127 when v56.Length == 48:
            {
                var outBytes = new byte[52];
                Array.Copy(v56, 0, outBytes, 0, 32);
                // outBytes[32..36] stays zero - the inserted field
                Array.Copy(v56, 32, outBytes, 36, 4);
                var level = BitConverter.ToSingle(v56, 36);
                BitConverter.GetBytes(level == 0f ? -96f : level).CopyTo(outBytes, 40);
                Array.Copy(v56, 40, outBytes, 44, 8);
                return outBytes;
            }

            // Effect, 25 -> 27: two zero bytes inserted at offset 21. 22/22 exact - appending them instead
            // matches only 20 of the 22, so the position matters.
            case 129 when v56.Length == 25:
            {
                var outBytes = new byte[27];
                Array.Copy(v56, 0, outBytes, 0, 21);
                Array.Copy(v56, 21, outBytes, 23, 4);
                return outBytes;
            }

            default:
                return v56;
        }
    }

    public byte[] WriteV134()
    {
        var w = new BankWriter();
        w.U32(Id);
        w.U32(PluginId);

        if (PluginId != 0 && PluginId != 0xFFFFFFFF)
        {
            var bytes = ConvertParamBlockToV134(PluginId, ParamBlock ?? Array.Empty<byte>());
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
