namespace BankConverter.Bnk;

/// <summary>
/// Lossless byte-order conversion of the v65 Wii U Wwise IMA format used by SmartMissile.
/// NOT Nintendo DSP ADPCM or standard MS ADPCM despite RIFF codec tag 0x0002.
/// Wwise IMA uses 36-byte mono blocks, interleaved per channel. Only the initial s16 predictor
/// is endian-dependent; the step index and compressed nibbles are unchanged (vgmstream's
/// src/coding/ima_decoder.c, decode_wwise_ima). No decode/re-encode or quality loss.
/// Rejects other codecs, prefetch fragments, and unknown metadata rather than guessing.
/// </summary>
public static class WiiUAdpcmWem
{
    public static byte[] ConvertToLittleEndian(byte[] wem)
    {
        var r = new BankReader(wem, bigEndian: true);
        if (r.Tag4() != "RIFX" || r.U32() != wem.Length - 8 || r.Tag4() != "WAVE")
            throw new InvalidDataException("Expected a complete big-endian RIFX WAVE.");
        var w = new BankWriter();
        w.Tag4("RIFF"); w.U32((uint)wem.Length - 8); w.Tag4("WAVE");
        ushort channels = 0;
        bool haveFormat = false, haveData = false;
        while (!r.AtEnd)
        {
            var tag = r.Tag4();
            var size = checked((int)r.U32());
            var body = r.Bytes(size);
            var f = new BankReader(body, bigEndian: true);
            switch (tag)
            {
                case "fmt ":
                    if (haveFormat || size != 24 || f.U16() != 2)
                        throw new NotSupportedException("Expected one 24-byte Wwise IMA fmt chunk.");
                    channels = f.U16();
                    var rate = f.U32();
                    var averageBytes = f.U32();
                    var blockAlign = f.U16();
                    var bits = f.U16();
                    var extraSize = f.U16();
                    var validBits = f.U16();
                    var mask = f.U32();
                    if (channels is not (1 or 2) || blockAlign != channels * 36 || bits != 4 ||
                        extraSize != 6 || validBits != 16 || mask != (channels == 1 ? 4u : 3u))
                        throw new NotSupportedException("Unsupported Wwise IMA format/channel layout.");
                    var fmt = new BankWriter();
                    fmt.U16(2); fmt.U16(channels); fmt.U32(rate); fmt.U32(averageBytes);
                    fmt.U16(blockAlign); fmt.U16(bits); fmt.U16(extraSize); fmt.U16(validBits);
                    // 2019 AkChannelConfig replaces the old raw speaker mask: mask:19/type:4/count:8.
                    fmt.U32((mask << 12) | 0x100u | channels);
                    body = fmt.ToArray();
                    haveFormat = true;
                    break;
                case "data":
                    if (!haveFormat || haveData || size % (channels * 36) != 0)
                        throw new InvalidDataException("Missing fmt, duplicate data, or incomplete IMA blocks.");
                    for (int p = 0; p < size; p += 36)
                    {
                        if (body[p + 2] > 88 || body[p + 3] != 0)
                            throw new InvalidDataException("Invalid Wwise IMA predictor header.");
                        (body[p], body[p + 1]) = (body[p + 1], body[p]);
                    }
                    haveData = true;
                    break;
                case "JUNK":
                    if (body.Any(b => b != 0)) throw new NotSupportedException("Nonzero JUNK metadata.");
                    break;
                default:
                    throw new NotSupportedException($"Unsupported RIFX chunk {tag}; metadata must be reviewed.");
            }
            w.Tag4(tag); w.U32((uint)size); w.Bytes(body);
            if ((size & 1) != 0) w.U8(r.U8());
        }
        if (!haveFormat || !haveData) throw new InvalidDataException("Missing fmt or data.");
        return w.ToArray();
    }
}
