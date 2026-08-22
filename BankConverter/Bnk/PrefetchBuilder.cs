namespace BankConverter.Bnk;

/// <summary>
/// Builds a truncated "prefetch" fragment for a PrefetchStreaming source, per the actual runtime
/// constraint found in CAkSrcFileBase::HandlePrefetch (Wwise SDK, softwarepipeline/aksrcfilebase.cpp):
///   - The embedded buffer must fully contain the WEM's header chunks (RIFF/fmt/etc, up to where the
///     "data" chunk's payload begins) - ParseHeader runs directly against it, and the code asserts
///     m_ulSizeLeft >= m_uDataOffset ("Header must be entirely contained within prefetch buffer") right
///     before unconditionally consuming m_uDataOffset bytes from it - undershooting this is a real
///     buffer over-read, not just a lint-level assert.
///   - Past that point, no packet/page alignment is required: ProcessStreamBuffer just hands whatever
///     prefetch bytes remain to the decoder as an ordinary partial stream-read, and the engine then
///     seeks the external (AFC) copy to resume at exactly the prefetch buffer's length
///     (SetStreamPosition(this, m_ulSizeLeft)). So the prefetch buffer and the AFC copy MUST be the
///     exact same re-encoded bitstream, byte-identical at the front with zero gap/overlap - this is why
///     the prefetch fragment has to be a literal prefix of the same WEM bytes written to the AFC, not a
///     separately-encoded short clip.
/// </summary>
public static class PrefetchBuilder
{
    /// <summary>
    /// Extra bytes of audio payload kept beyond the RIFF/fmt header minimum. This is NOT just a stutter
    /// buffer against async file-open/seek latency (the original justification) - CAkSrcFileVorbis::
    /// DecodeVorbisHeader/AkVorbisCodebookMgr::DecodeCodebook run synchronously against whatever buffer
    /// is handed to StartStream (confirmed via a live crash in vorbis_unpack_books/CAkVorbisAllocator::
    /// Reserve when a specific WEM's prefetch fragment was too small: the codebook unpacker read torn
    /// data past the truncation point and computed a garbage allocation size, corrupting the TLSF
    /// allocator's free-list). This means the prefetch fragment must fully contain the ENTIRE Vorbis
    /// setup/codebook packet, not just the outer RIFF/fmt framing - and that packet's real size is
    /// data-dependent (varies with channel count/encoder complexity), not a fixed constant. 8192 was
    /// large enough for most sampled content but not guaranteed for all of it. Raised well past any
    /// plausible real-world codebook size as an immediate mitigation; the fully correct fix would parse
    /// the actual setup-packet-end offset out of Wwise's own WEM "fmt " chunk extension instead of
    /// guessing a margin.
    /// </summary>
    public const uint SafetyMarginBytes = 131072;

    /// <summary>
    /// Builds the new embedded prefetch fragment for a re-encoded (v134) full WEM: the WEM's own header
    /// (RIFF/fmt/etc, through the start of its "data" chunk payload) plus <see cref="SafetyMarginBytes"/>
    /// of audio payload, clamped to the full WEM's length for very short sounds. The RIFF header's
    /// declared size is left untouched (still the full stream's size) - matching the exact "declares
    /// full size, only a byte-prefix of DATA is actually present" pattern already observed in the
    /// original v56 bank-embedded prefetch fragments.
    /// </summary>
    public static byte[] BuildFragment(byte[] fullWem)
    {
        var dataOffset = WemHeader.GetDataOffset(fullWem);
        var targetSize = Math.Min((uint)fullWem.Length, dataOffset + SafetyMarginBytes);

        var fragment = new byte[targetSize];
        Array.Copy(fullWem, fragment, targetSize);
        return fragment;
    }
}
