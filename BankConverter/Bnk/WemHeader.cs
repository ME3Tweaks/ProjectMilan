namespace BankConverter.Bnk;

/// <summary>Parses a standalone WEM file's own internal RIFF sub-chunk layout (distinct from the outer
/// AFC-level RIFF-size framing in <see cref="AfcConverter"/>, which delimits whole WEM entries).</summary>
public static class WemHeader
{
    /// <summary>
    /// Returns the byte offset (from the start of the WEM file) where the "data" chunk's payload
    /// begins - i.e. CAkSrcFileBase::m_uDataOffset, the point up to which a prefetch buffer must fully
    /// extend (see <see cref="PrefetchBuilder"/>).
    /// </summary>
    public static uint GetDataOffset(byte[] wem)
    {
        if (wem.Length < 12 || wem[0] != 'R' || wem[1] != 'I' || wem[2] != 'F' || wem[3] != 'F')
            throw new InvalidDataException("Not a RIFF/WEM file (missing 'RIFF' tag).");

        var pos = 12u; // past "RIFF" + size(4) + form type e.g. "WAVE"(4)
        while (pos + 8 <= wem.Length)
        {
            var tag = System.Text.Encoding.ASCII.GetString(wem, (int)pos, 4);
            var chunkSize = BitConverter.ToUInt32(wem, (int)pos + 4);
            var payloadStart = pos + 8;

            if (tag == "data")
                return payloadStart;

            pos = payloadStart + chunkSize + (chunkSize & 1); // RIFF sub-chunks are word-aligned/padded
        }

        throw new InvalidDataException("WEM has no 'data' chunk.");
    }
}
