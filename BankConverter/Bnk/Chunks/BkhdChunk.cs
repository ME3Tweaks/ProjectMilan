namespace BankConverter.Bnk.Chunks;

/// <summary>
/// BKHD (bank header) chunk. Field set differs between v56 and v134 source/target versions;
/// this model carries the superset of fields needed for both.
/// </summary>
public sealed class BkhdChunk
{
    public uint BankGeneratorVersion;
    public uint SoundBankId;
    public uint LanguageId;

    /// <summary>v56 (&lt;=126): bFeedbackInBank. Always 0 for this game (no feedback/motion content observed).</summary>
    public uint FeedbackInBank;

    /// <summary>v134 (127..134): packed bUnused(low16)/bDeviceAllocated(high16). Observed as 0 in reference LE3 banks.</summary>
    public uint AltValues;

    /// <summary>v134 only (version &gt; 76). Observed as 0 in reference LE3 banks (no custom Wwise project id set).</summary>
    public uint ProjectId;

    /// <summary>Raw alignment padding bytes read after the v56 body (DATA-chunk alignment). Kept only for round-trip validation.</summary>
    public byte[] V56Padding = Array.Empty<byte>();

    public static BkhdChunk ReadV56(BankReader r, uint chunkSize)
    {
        var start = r.Position;
        var c = new BkhdChunk
        {
            BankGeneratorVersion = r.U32(),
            SoundBankId = r.U32(),
            LanguageId = r.U32(),
            FeedbackInBank = r.U32(),
        };
        var read = r.Position - start;
        var gap = (int)chunkSize - read;
        if (gap > 0) c.V56Padding = r.Bytes(gap);
        return c;
    }

    /// <summary>Writes the 16-byte v56 body plus the original alignment padding. Used only for reader validation.</summary>
    public byte[] WriteV56Body()
    {
        var w = new BankWriter();
        w.U32(BankGeneratorVersion);
        w.U32(SoundBankId);
        w.U32(LanguageId);
        w.U32(FeedbackInBank);
        w.Bytes(V56Padding);
        return w.ToArray();
    }

    /// <summary>Writes just the fixed 20-byte v134 body (no chunk tag/size, no alignment padding).</summary>
    public byte[] WriteV134Body()
    {
        var w = new BankWriter();
        w.U32(134);
        w.U32(SoundBankId);
        w.U32(LanguageId);
        w.U32(AltValues);
        w.U32(ProjectId);
        return w.ToArray();
    }

    /// <summary>
    /// The DATA chunk must start at a file offset congruent to 8 (mod 16). Computes the zero-fill
    /// padding to append after the BKHD body (and after DIDX, if present) to achieve that.
    /// </summary>
    public static byte[] ComputeAlignmentPadding(long dataChunkOffset)
    {
        var initAlignment = dataChunkOffset % 16;
        var size = initAlignment switch
        {
            < 8 => 8 - initAlignment,
            > 8 => 8 + (16 - initAlignment),
            _ => 0,
        };
        return new byte[size];
    }
}
