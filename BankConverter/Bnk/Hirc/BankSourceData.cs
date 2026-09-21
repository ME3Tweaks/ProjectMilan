namespace BankConverter.Bnk.Hirc;

/// <summary>
/// AkBankSourceData (CAkBankMgr::LoadSource). StreamType's *numeric values* for Streaming vs
/// PrefetchStreaming are swapped between the v56 (&lt;=88-family) and v134 (&gt;112-family) enums, so the
/// value is translated, not copied verbatim. v134 also drops the separate uFileID/uFileOffset fields
/// entirely (offset lookups now go exclusively through the DIDX chunk, keyed by sourceID).
/// </summary>
public enum SourceStreamType
{
    Data = 0,
    Streaming = 1,
    PrefetchStreaming = 2,
}

public sealed class BankSourceData
{
    public uint PluginId;
    public SourceStreamType StreamType;
    public uint SourceId;
    public uint FileId; // v56 only; typically equals SourceId
    public uint FileOffset; // v56 only
    public uint InMemoryMediaSize;
    public bool IsLanguageSpecific;
    public bool HasSource;
    public bool ExternallySupplied; // v56 only, no v134 equivalent
    public byte[]? PluginParams;

    public static BankSourceData ReadV56(BankReader r)
    {
        var s = new BankSourceData { PluginId = r.U32() };
        var pluginType = s.PluginId & 0x0F;

        s.StreamType = (SourceStreamType)r.U32();

        s.SourceId = r.U32();

        s.FileId = r.U32();
        if (s.StreamType != SourceStreamType.Streaming)
        {
            s.FileOffset = r.U32();
            s.InMemoryMediaSize = r.U32();
        }

        var sourceBits = r.U8();
        s.IsLanguageSpecific = (sourceBits & 1) != 0;
        s.HasSource = (sourceBits & 2) != 0;
        s.ExternallySupplied = (sourceBits & 4) != 0;

        var hasParam = pluginType == 2 || pluginType == 5;
        if (hasParam)
        {
            var size = r.U32();
            s.PluginParams = r.Bytes((int)size);
        }

        return s;
    }

    /// <param name="overrideInMemoryMediaSize">
    /// Actual byte count embedded in the v134 bank's DIDX/DATA for this SourceId, when it differs from
    /// the original v56 value (e.g. after WEM re-encoding, which changes file sizes, or after building a
    /// new truncated prefetch fragment - see <see cref="PrefetchBuilder"/>). InMemoryMediaSize otherwise
    /// only makes sense as "how many bytes are actually resident," so passing through the stale v56
    /// value after a size-changing replacement would desync it from the real DIDX/DATA entry.
    /// </param>
    /// <param name="forceData">
    /// True when a v56-PrefetchStreaming source's re-encoded WEM turned out small enough that
    /// PrefetchBuilder embedded the ENTIRE file rather than a truncated prefix (re-encoding can shrink a
    /// short clip well below the old prefetch cutoff). Confirmed via a live crash: keeping such a source
    /// tagged PrefetchStreaming makes the real engine consume all of the (complete) embedded audio, then
    /// seek the external AFC to continue reading a "remainder" that doesn't exist for this source - the
    /// Vorbis decoder ends up reading whatever unrelated bytes happen to follow in the AFC (the next WEM,
    /// or past EOF), corrupting its codebook parse and crashing the allocator. Forces StreamType=Data
    /// (fully self-contained, no external continuation expected) instead of trusting the v56-inherited
    /// classification.
    /// </param>
    public void WriteV134(BankWriter w, uint? overrideInMemoryMediaSize = null, bool forceData = false)
    {
        // A SOURCE plugin generates its audio rather than reading a media file, so it reports no media.
        // Confirmed against shipped, working LE3 content (native SFXPawn_GethPrime.pcc, PluginId 0x00650002,
        // reached by the geth prime's self-destruct explosion event): the official conversion keeps the PluginId
        // completely unchanged and reports InMemoryMediaSize=0 with an empty zero-length PluginParams. Stock LE3
        // does this for every source plugin it ships (148/148 resident, 435/435 LMP base).
        //
        // This keys off the plugin TYPE, not off who registered it. It used to call IsThirdParty, which was
        // decoding the wrong bitfield and so happened to return true for exactly these - verified equivalent on
        // real data: across 83,604 ME3 and 78,925 LE3 Sound objects the two predicates never disagree, because
        // every source plugin in either game is Audiokinetic (company 0) and every non-source source is the
        // Vorbis codec 0x00040001. Same behaviour, correct reason - and it no longer moves when IsThirdParty is
        // fixed. See PluginSupport.
        var isSourcePlugin = PluginSupport.IsSourcePlugin(PluginId);
        w.U32(PluginId);
        var pluginType = PluginId & 0x0F;

        var effectiveStreamType = forceData ? SourceStreamType.Data : StreamType;

        // v56 Streaming(1)/PrefetchStreaming(2) swap meaning at v134.
        var v134StreamType = effectiveStreamType switch
        {
            SourceStreamType.Data => 0,
            SourceStreamType.Streaming => 2,
            SourceStreamType.PrefetchStreaming => 1,
            _ => 0,
        };
        w.U8((byte)v134StreamType);

        w.U32(SourceId);
        w.U32(isSourcePlugin ? 0 : overrideInMemoryMediaSize ?? InMemoryMediaSize);

        byte sourceBits = 0;
        if (IsLanguageSpecific) sourceBits |= 1 << 0;
        if (effectiveStreamType == SourceStreamType.PrefetchStreaming) sourceBits |= 1 << 1; // bPrefetch
        if (HasSource) sourceBits |= 1 << 7;
        w.U8(sourceBits);

        if (isSourcePlugin)
        {
            var bytes = Array.Empty<byte>(); // stock LE3 ships an empty param block for every source plugin
            w.U32((uint)bytes.Length);
            w.Bytes(bytes);
        }
    }
}
