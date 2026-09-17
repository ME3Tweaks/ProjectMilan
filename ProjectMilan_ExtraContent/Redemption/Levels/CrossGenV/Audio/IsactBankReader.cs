using System.Text;

namespace ProjectMilan_ExtraContent.Redemption.Levels.CrossGenV.Audio;

/// <summary>
/// Minimal reader for the ISACT bank pair embedded in an LE1 SoundNodeWave's binary. Only decodes the chunks the
/// Pinnacle Station audio port actually needs (see Pipelines/Audio/ISACT-Format-Notes.md for the full format).
/// <para/>
/// This deliberately does not reuse LegendaryExplorerCore's ISACTHelper: that reader computes a LIST chunk's end as
/// <c>start + length - 4</c>, which is 4 bytes short of the real payload end and can silently drop a small trailing
/// subchunk. Harmless for LEC's own use (it never seeks past what it read back out) but not something to build a
/// content port on top of. The walk below is plain RIFF.
/// </summary>
internal static class IsactBankReader
{
    /// <summary>
    /// Sentinel used throughout ISACT for "no resource" - see ISACTLib's INVALID_RESOURCE_INDEX.
    /// </summary>
    public const uint InvalidResourceIndex = 0x80000000;

    /// <summary>
    /// Sample TimeLength value BioWare uses for a wave that loops forever rather than having a real duration.
    /// </summary>
    public const int IndefinitelyLoopingDuration = unchecked((int)0xFFFFFFFF);

    /// <summary>
    /// Splits a SoundNodeWave's raw binary into its two RIFF banks. The blob is laid out as:
    /// <code>
    /// int32   offset of the ISB RIFF, relative to the start of this blob
    /// RIFF ... 'icbf'   content bank (the "what plays" graph)
    /// RIFF ... 'isbf'   sample  bank (the audio + 3D presets)
    /// </code>
    /// </summary>
    public static IsactBankPair ParseSoundNodeWaveBinary(byte[] raw)
    {
        if (raw is not { Length: > 12 }) throw new InvalidDataException("SoundNodeWave binary is empty or too short to hold an ISACT bank pair");

        var isbOffset = BitConverter.ToInt32(raw, 0);
        if (isbOffset < 4 || isbOffset >= raw.Length) throw new InvalidDataException($"SoundNodeWave binary declares an out-of-range ISB offset (0x{isbOffset:X})");

        return new IsactBankPair
        {
            Icb = ParseRiff(raw, 4, isbOffset - 4),
            Isb = ParseRiff(raw, isbOffset, raw.Length - isbOffset),
        };
    }

    /// <summary>
    /// Parses a standalone RIFF (e.g. a loose .isb file from the game's Content folder).
    /// </summary>
    public static IsactChunk ParseRiff(byte[] data) => ParseRiff(data, 0, data.Length);

    private static IsactChunk ParseRiff(byte[] data, int offset, int length)
    {
        var tag = Ascii(data, offset);
        if (tag != "RIFF") throw new InvalidDataException($"Expected RIFF at 0x{offset:X}, got '{tag}'");

        var riffLen = BitConverter.ToInt32(data, offset + 4);
        // Never trust the declared length past the end of the buffer - the ICB's is measured to the ISB offset, and a
        // truncated (cooked-away) tail is a real possibility.
        var end = Math.Min(offset + 8 + riffLen, offset + length);

        var root = new IsactChunk { Id = "RIFF", ListType = Ascii(data, offset + 8) };
        ReadChildren(data, offset + 12, end, root);
        return root;
    }

    /// <summary>
    /// Reads a flat run of chunks in [pos, end), appending them to <paramref name="parent"/>. LIST chunks recurse.
    /// </summary>
    private static void ReadChildren(byte[] data, int pos, int end, IsactChunk parent)
    {
        while (pos + 8 <= end)
        {
            var id = Ascii(data, pos);
            var len = BitConverter.ToInt32(data, pos + 4);
            if (len < 0 || pos + 8 + len > end) break; // truncated tail - take what we got

            var dataStart = pos + 8;
            var chunk = new IsactChunk { Id = id };

            if (id == "LIST")
            {
                chunk.ListType = Ascii(data, dataStart);
                ReadChildren(data, dataStart + 4, dataStart + len, chunk);
            }
            else
            {
                chunk.Data = data.AsSpan(dataStart, len).ToArray();
            }

            parent.Children.Add(chunk);

            pos = dataStart + len;
            if ((len & 1) != 0) pos++; // RIFF pads odd-length chunks to an even boundary
        }
    }

    private static string Ascii(byte[] data, int offset) => Encoding.ASCII.GetString(data, offset, 4);
}

internal sealed class IsactBankPair
{
    /// <summary>Content bank ('icbf') - holds the sdqu/snde/sdri objects describing what plays.</summary>
    public IsactChunk Icb { get; init; }

    /// <summary>Sample bank ('isbf') - holds the samp (audio) and bfob (3D preset) objects.</summary>
    public IsactChunk Isb { get; init; }
}

internal sealed class IsactChunk
{
    /// <summary>Four-character chunk id, or "RIFF"/"LIST" for containers.</summary>
    public string Id { get; init; }

    /// <summary>For RIFF/LIST containers, the form/object type ('icbf', 'isbf', 'samp', 'bfob', 'sdqu', 'snde', ...).</summary>
    public string ListType { get; set; }

    /// <summary>Raw payload for a leaf chunk. Null for containers.</summary>
    public byte[] Data { get; set; }

    public List<IsactChunk> Children { get; } = [];

    /// <summary>Direct children that are LIST objects of the given ISACT object type.</summary>
    public IEnumerable<IsactChunk> Objects(string objectType) => Children.Where(x => x.Id == "LIST" && x.ListType == objectType);

    /// <summary>All direct-child LIST objects, in bank order - the order that gives each object its resource index.</summary>
    public IEnumerable<IsactChunk> Objects() => Children.Where(x => x.Id == "LIST");

    public IsactChunk Child(string id) => Children.FirstOrDefault(x => x.Id == id);

    public int? Int32(string id)
    {
        var c = Child(id);
        return c?.Data is { Length: >= 4 } d ? BitConverter.ToInt32(d, 0) : null;
    }

    public float? Float(string id)
    {
        var c = Child(id);
        return c?.Data is { Length: >= 4 } d ? BitConverter.ToSingle(d, 0) : null;
    }

    /// <summary>The object's 'titl' chunk, which ISACT stores as a null-terminated UTF-16LE string.</summary>
    public string Title
    {
        get
        {
            var c = Child("titl");
            if (c?.Data is not { Length: >= 2 } d) return null;
            var s = Encoding.Unicode.GetString(d);
            var nul = s.IndexOf('\0');
            return nul >= 0 ? s[..nul] : s;
        }
    }

    /// <summary>The object's own index within its bank, from the 'indx' chunk.</summary>
    public int? ResourceIndex => Int32("indx");

    /// <summary>Linear gain multiplier from the 'gbst' (gain boost) chunk. 1.0 when absent.</summary>
    public float GainBoost => Float("gbst") ?? 1.0f;

    public IsactSampleInfo? SampleInfo => IsactSampleInfo.From(Child("sinf"));

    public IsactCompressionInfo? CompressionInfo => IsactCompressionInfo.From(Child("cmpi"));

    /// <summary>Channel count from 'chnk'. Mono when absent.</summary>
    public int ChannelCount => Int32("chnk") ?? 1;

    /// <summary>Raw audio payload from 'data' - for the Vegas DLC this is always a complete Ogg Vorbis stream.</summary>
    public byte[] SampleData => Child("data")?.Data;

    /// <summary>
    /// Index of the 'bfob' buffer object (the 3D/attenuation preset) this sample uses, from 's3di'. Null when the
    /// sample is not spatialized.
    /// </summary>
    public int? BufferIndex
    {
        get
        {
            var v = Int32("s3di");
            return v is null or unchecked((int)IsactBankReader.InvalidResourceIndex) ? null : v;
        }
    }

    public override string ToString() => Id == "LIST" ? $"LIST {ListType} '{Title}' ({Children.Count} chunks)" : $"{Id} ({Data?.Length ?? 0} bytes)";
}

/// <summary>ISACT 'sinf' - see SampleInfoBankChunk in LEC for the same layout.</summary>
internal readonly record struct IsactSampleInfo(int BufferOffset, int TimeLength, int SamplesPerSecond, int ByteLength, ushort BitsPerSample)
{
    public static IsactSampleInfo? From(IsactChunk c)
    {
        if (c?.Data is not { Length: >= 18 } d) return null;
        return new IsactSampleInfo(BitConverter.ToInt32(d, 0), BitConverter.ToInt32(d, 4), BitConverter.ToInt32(d, 8), BitConverter.ToInt32(d, 12), BitConverter.ToUInt16(d, 16));
    }

    /// <summary>True when this is one of the infinite loops BioWare marks with a 0xFFFFFFFF duration.</summary>
    public bool IsIndefinitelyLooping => TimeLength == IsactBankReader.IndefinitelyLoopingDuration;

    public TimeSpan Duration => IsIndefinitelyLooping ? TimeSpan.Zero : TimeSpan.FromMilliseconds(TimeLength);
}

internal enum IsactCompressionFormat
{
    PCM = 0,
    IMA4ADPCM = 1,
    OGGVORBIS = 2,
    WMA = 3,
    XMA = 4,
    MSMP3 = 5,
    MSADPCM = 6,
    MSPCMBIG = 7,
}

/// <summary>ISACT 'cmpi'.</summary>
internal readonly record struct IsactCompressionInfo(IsactCompressionFormat CurrentFormat, IsactCompressionFormat TargetFormat, int TotalSize, int PacketSize)
{
    public static IsactCompressionInfo? From(IsactChunk c)
    {
        if (c?.Data is not { Length: >= 16 } d) return null;
        return new IsactCompressionInfo((IsactCompressionFormat)BitConverter.ToInt32(d, 0), (IsactCompressionFormat)BitConverter.ToInt32(d, 4), BitConverter.ToInt32(d, 8), BitConverter.ToInt32(d, 12));
    }
}

/// <summary>
/// ISACT 'sdst' (ISACTSoundDistance) - the distance attenuation preset hanging off a 'bfob' buffer object.
/// Distances are already in metres; <see cref="MaxDistanceLevel"/> is the dB level reached at MaxDistance.
/// </summary>
internal readonly record struct IsactSoundDistance(float MinDistance, float MaxDistance, float MaxDistanceLevel, uint Flags)
{
    /// <summary>ISACTEng defaults, used when a buffer has no 'sdst' of its own (isactri.h).</summary>
    public static readonly IsactSoundDistance Default = new(64f, 2048f, -30f, 0);

    public static IsactSoundDistance? From(IsactChunk c)
    {
        if (c?.Data is not { Length: >= 16 } d) return null;
        return new IsactSoundDistance(BitConverter.ToSingle(d, 0), BitConverter.ToSingle(d, 4), BitConverter.ToSingle(d, 8), BitConverter.ToUInt32(d, 12));
    }
}

/// <summary>
/// One track of an ISACT 'snde' SoundEvent, from the BioWare-shortened 'sdtf' chunk (SOUNDTRACK in SoundEvent.h,
/// with MAX_NUM_SLOTS reduced from 32 to 4, giving a 168-byte stride).
/// </summary>
internal readonly record struct IsactSoundTrack(uint BufferIndex, uint Order, uint Chance, float MinGain, float MaxGain, float MinPitch, float MaxPitch)
{
    /// <summary>sizeof(SOUNDTRACK) with MAX_NUM_SLOTS_FOUR - verified against every sdtf chunk in the Vegas DLC.</summary>
    public const int Stride = 168;

    public static List<IsactSoundTrack> ParseAll(IsactChunk soundEvent)
    {
        var result = new List<IsactSoundTrack>();
        // 'sdtf' is the four-slot variant BioWare shipped; 'sndt' is the stock 32-slot one. Only sdtf appears in the
        // Vegas DLC, but read either rather than silently returning no variations if one turns up.
        var chunk = soundEvent.Child("sdtf");
        var stride = Stride;
        if (chunk == null)
        {
            chunk = soundEvent.Child("sndt");
            stride = 728; // same struct with MAX_NUM_SLOTS = 32
        }
        if (chunk?.Data is not { } d) return result;

        for (var o = 0; o + stride <= d.Length; o += stride)
        {
            result.Add(new IsactSoundTrack(
                BitConverter.ToUInt32(d, o + 0),   // ulBufferIndex
                                                   // + 4  ulPathIndex
                BitConverter.ToUInt32(d, o + 8),   // ulOrder
                BitConverter.ToUInt32(d, o + 12),  // ulChance
                                                   // + 16 vPosition    (3 x float)
                                                   // + 28 vOrientation (3 x int32)
                                                   // + 40 vVelocity    (3 x float)
                BitConverter.ToSingle(d, o + 52),  // flMinGain
                BitConverter.ToSingle(d, o + 56),  // flMaxGain
                BitConverter.ToSingle(d, o + 60),  // flMinPitch
                BitConverter.ToSingle(d, o + 64))); // flMaxPitch
        }

        return result;
    }
}

/// <summary>
/// One entry of an ISACT 'sdqu' SoundQueue's 'qcnt' chunk (SOUNDQUEUECONTENT). <see cref="ContentIndex"/> is a packed
/// bank/object pair: <c>((bankIndex + 1) &lt;&lt; 16) | objectIndex</c>.
/// </summary>
internal readonly record struct IsactQueueContent(uint ContentType, uint ContentIndex)
{
    public int BankIndex => (int)(ContentIndex >> 16) - 1;
    public int ObjectIndex => (int)(ContentIndex & 0xFFFF);

    public static List<IsactQueueContent> ParseAll(IsactChunk soundQueue)
    {
        var result = new List<IsactQueueContent>();
        if (soundQueue.Child("qcnt")?.Data is not { } d) return result;
        for (var o = 0; o + 8 <= d.Length; o += 8)
        {
            result.Add(new IsactQueueContent(BitConverter.ToUInt32(d, o), BitConverter.ToUInt32(d, o + 4)));
        }
        return result;
    }
}
