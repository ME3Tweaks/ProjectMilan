using BankConverter.Bnk.Chunks;

namespace BankConverter.Bnk;

/// <summary>
/// A parsed v56 SoundBank: known chunks decoded into models, HIRC kept as raw bytes until
/// the HIRC converter is wired in (see BankFile.ReadHirc / WriteHirc, added incrementally).
/// </summary>
public sealed class BankFile
{
    public BkhdChunk Bkhd = null!;
    public DidxChunk? Didx;
    public DataChunk? Data;
    public StidChunk? Stid;
    public byte[]? HircRaw;

    /// <summary>Chunk tags in the exact order they appeared in the source file (for round-trip validation).</summary>
    public List<string> ChunkOrder = new();

    public static BankFile ReadV56(byte[] fileBytes)
    {
        var r = new BankReader(fileBytes);
        var bank = new BankFile();

        while (!r.AtEnd)
        {
            var tag = r.Tag4();
            var chunkSize = r.U32();
            var chunkStart = r.Position;
            bank.ChunkOrder.Add(tag);

            switch (tag)
            {
                case "BKHD":
                    bank.Bkhd = BkhdChunk.ReadV56(r, chunkSize);
                    break;
                case "DIDX":
                    bank.Didx = DidxChunk.Read(r, chunkSize);
                    break;
                case "DATA":
                    bank.Data = DataChunk.Read(r, chunkSize);
                    break;
                case "STID":
                    bank.Stid = StidChunk.Read(r);
                    break;
                case "HIRC":
                    bank.HircRaw = r.Bytes((int)chunkSize);
                    break;
                default:
                    r.Skip((int)chunkSize);
                    break;
            }

            // Defensive: if a chunk reader didn't consume exactly chunkSize bytes, resync.
            var consumed = r.Position - chunkStart;
            if (consumed != chunkSize)
            {
                r.Position = chunkStart + (int)chunkSize;
            }
        }

        return bank;
    }

    /// <summary>
    /// Round-trips this bank back to v56 bytes using the raw HIRC bytes as-is (HIRC is version-stable
    /// when read and written at the same version). Used only to validate the chunk-level reader/writer
    /// against real files before the v56-&gt;v134 HIRC converter exists.
    /// </summary>
    public byte[] WriteV56ChunksRoundTrip()
    {
        var w = new BankWriter();

        foreach (var tag in ChunkOrder)
        {
            byte[] body = tag switch
            {
                "BKHD" => Bkhd.WriteV56Body(),
                "DIDX" => Didx!.Write(),
                "DATA" => Data!.Write(),
                "STID" => Stid!.Write(),
                "HIRC" => HircRaw!,
                _ => throw new NotSupportedException($"Unexpected chunk tag '{tag}'"),
            };
            w.Tag4(tag);
            w.U32((uint)body.Length);
            w.Bytes(body);
        }

        return w.ToArray();
    }

    /// <summary>
    /// Converts this v56 bank to v134 bytes. STID is format-stable and passes through unchanged.
    /// DIDX/DATA pass through unchanged UNLESS <paramref name="wemReplacements"/> or <paramref name="prefetchFragments"/>
    /// supplies re-encoded media for a given source ID (embedded v56 WEM audio is not decodable by the v134 Vorbis
    /// codec - it references a disjoint codebook library - so passthrough alone produces a bank that loads but
    /// crashes on playback; see BusRemap-style fallback tracking via <paramref name="missingWems"/>).
    /// </summary>
    /// <param name="stats"></param>
    /// <param name="wemReplacements">Full re-encoded WEM bytes, keyed by source ID. Used as-is for Data-type (fully
    /// embedded) sources; for PrefetchStreaming sources, truncated internally via <see cref="PrefetchBuilder"/>
    /// unless <paramref name="prefetchFragments"/> already supplies a pre-built fragment for that ID.</param>
    /// <param name="missingWems"></param>
    /// <param name="prefetchFragments">Pre-truncated header+margin fragments, keyed by source ID, for
    /// PrefetchStreaming sources. Lets a caller that only has the full stream elsewhere (e.g. already written to an
    /// external AFC, never held in memory as a whole) supply just the small fragment actually needed here, instead
    /// of the full - potentially very large - replacement via <paramref name="wemReplacements"/>. Checked before
    /// <paramref name="wemReplacements"/> for PrefetchStreaming IDs.</param>
    /// <param name="fullyEmbeddedPrefetchIds">Source IDs from <paramref name="prefetchFragments"/> whose re-encoded
    /// WEM was small enough that the caller's <see cref="PrefetchBuilder"/> call embedded the entire file rather
    /// than a truncated prefix - i.e. there is no genuine external continuation for these. Only needed for the
    /// prefetchFragments path; the wemReplacements path detects this itself (it has the full replacement to compare
    /// against). See BankSourceData.WriteV134's forceData param for why this must be reclassified as StreamType=Data.</param>
    /// <param name="externallyProvidedMedia">Source IDs the target game already ships in its own always-loaded banks,
    /// mapped to the byte length those banks embed. Wwise resolves embedded media globally across every loaded bank
    /// rather than per-bank, so re-embedding our own re-encode of one of these registers a SECOND, different blob
    /// under an ID the stock game already owns - the resulting size/content disagreement is fed to the Vorbis decoder
    /// as garbage. Confirmed in the wild: source 2269036, owned by LE3's resident Wwise_Generic_Explosions at 58855
    /// bytes, re-embedded by ported MP banks at 300288 - which corrupted every explosion that referenced it. IDs
    /// listed here are left out of DIDX/DATA entirely and their Sounds declare the stock size instead, exactly how
    /// LE3's own banks reference them.</param>
    public byte[] ConvertToV134(HircConversionStats stats, Dictionary<uint, byte[]>? wemReplacements = null, List<uint>? missingWems = null, Dictionary<uint, byte[]>? prefetchFragments = null, HashSet<uint>? fullyEmbeddedPrefetchIds = null, IReadOnlyDictionary<uint, uint>? externallyProvidedMedia = null)
    {
        var w = new BankWriter();

        var bkhdBody = Bkhd.WriteV134Body();
        w.Tag4("BKHD");

        byte[]? didxBody;
        byte[]? dataBytes;
        Dictionary<uint, uint>? newEmbeddedSizes = null;
        HashSet<uint>? newlyFullyEmbedded = null;
        if (Didx != null && Data != null && (wemReplacements != null || prefetchFragments != null))
        {
            // Needed to decide, per replaced SourceId, whether to embed the replacement in full (Data-type
            // sources) or truncate it to a header+margin prefetch fragment (PrefetchStreaming sources) -
            // see PrefetchBuilder. Falls back to full embedding if HIRC is missing/unparseable for some ID.
            var streamTypes = HircRaw != null
                ? HircChunk.ScanSourceStreamTypes(HircRaw)
                : new Dictionary<uint, Hirc.SourceStreamType>();

            newEmbeddedSizes = new Dictionary<uint, uint>();
            // Sources whose v56-inherited PrefetchStreaming classification no longer applies: the
            // re-encoded WEM was small enough that its whole file fit within what was meant to be just a
            // truncated header+margin fragment (see PrefetchBuilder), so there's no genuine external
            // continuation for the engine to seek into. Leaving these tagged PrefetchStreaming makes the
            // real engine consume the (complete) embedded audio, then seek the AFC to read a "remainder"
            // that doesn't exist - reading unrelated bytes (the next AFC entry, or past EOF) into the
            // Vorbis decoder and corrupting its codebook parse. Confirmed via a live crash
            // (vorbis_unpack_books/CAkVorbisAllocator::Reserve garbage allocation size) traced back to
            // exactly this case. Threaded down to BankSourceData.WriteV134's forceData param, which
            // reclassifies these as StreamType=Data instead.
            // Only ever reclassify IDs that are genuinely PrefetchStreaming per this bank's own v56 HIRC.
            // A caller may (naively) flag a plain Streaming-type ID here too - e.g. because its re-encoded
            // WEM happened to be small - but Streaming-type sources have NO v56 DIDX entry at all (100%
            // external by definition), so the DIDX-rebuild loop below never visits their ID and can't
            // create the DIDX/DATA entry that StreamType=Data requires. Forcing that reclassification
            // anyway leaves a StreamType=Data entry with no matching DIDX/DATA, which manifests as total
            // audio silence at runtime (confirmed via a live repro - Banshee/Ravenger vocalization).
            newlyFullyEmbedded = fullyEmbeddedPrefetchIds != null
                ? new HashSet<uint>(fullyEmbeddedPrefetchIds.Where(id => streamTypes.TryGetValue(id, out var st) && st == Hirc.SourceStreamType.PrefetchStreaming))
                : new HashSet<uint>();
            var newDidx = new DidxChunk();
            var newData = new List<byte>();
            foreach (var m in Didx.Media)
            {
                byte[] mediaBytes;
                var isPrefetch = streamTypes.TryGetValue(m.Id, out var streamType) && streamType == Hirc.SourceStreamType.PrefetchStreaming;

                // The stock game already owns this ID in an always-loaded bank - defer to it rather than
                // registering a competing blob under the same ID (see externallyProvidedMedia). Only plain
                // embedded sources are deferred: a PrefetchStreaming source's in-bank bytes are a header
                // fragment that the engine continues reading from OUR AFC, so it can't be served by whatever
                // the stock bank happens to hold under that ID.
                if (!isPrefetch && externallyProvidedMedia != null && externallyProvidedMedia.TryGetValue(m.Id, out var stockSize))
                {
                    newEmbeddedSizes[m.Id] = stockSize;
                    stats.ExternallyProvidedMedia++;
                    stats.ExternallyProvidedBytesSaved += m.Size;
                    continue;
                }

                if (isPrefetch && prefetchFragments != null && prefetchFragments.TryGetValue(m.Id, out var fragment))
                {
                    // Already truncated by the caller - use as-is, no need for (or access to) the full replacement.
                    // The caller (which built this fragment against the full replacement, e.g. the streamed
                    // AFC write path) is responsible for its own fully-embedded detection; nothing to do here.
                    mediaBytes = fragment;
                    newEmbeddedSizes[m.Id] = (uint)mediaBytes.Length;
                }
                else if (wemReplacements != null && wemReplacements.TryGetValue(m.Id, out var replacement))
                {
                    if (isPrefetch)
                    {
                        mediaBytes = PrefetchBuilder.BuildFragment(replacement);
                        stats.PrefetchFragmentsBuilt++;
                        stats.PrefetchBytesSaved += replacement.Length - mediaBytes.Length;
                        if (mediaBytes.Length >= replacement.Length) newlyFullyEmbedded.Add(m.Id);
                    }
                    else
                    {
                        mediaBytes = replacement;
                    }
                    newEmbeddedSizes[m.Id] = (uint)mediaBytes.Length;
                }
                else
                {
                    // No re-encoded replacement exists for this source (no ME3-side match found, or
                    // re-encoding failed). Previously this copied the ORIGINAL v56 bytes through
                    // unconverted, on the theory that a wrong-but-present file beats an absent one -
                    // but v56 and v134 Vorbis streams reference disjoint codebook libraries (see
                    // WemReencoder's doc comment), so passing v56-codec bytes into the v134 decoder isn't
                    // "wrong audio," it's a malformed bitstream: the codebook unpacker reads it as
                    // garbage, computes a nonsensical allocation size, and corrupts the engine's own
                    // allocator - confirmed via a live crash (vorbis_unpack_books/CAkVorbisAllocator::
                    // Reserve). A zero-length entry instead makes this source cleanly report "no media" at
                    // load/decode time (an ordinary, well-handled runtime condition - the game already has
                    // to tolerate missing/DLC-gated content) rather than feeding a codec-incompatible
                    // bitstream to a debug-build engine that doesn't validate its input defensively.
                    mediaBytes = Array.Empty<byte>();
                    newEmbeddedSizes[m.Id] = 0;
                    missingWems?.Add(m.Id);
                }
                newDidx.Media.Add(new MediaHeader { Id = m.Id, Offset = (uint)newData.Count, Size = (uint)mediaBytes.Length });
                newData.AddRange(mediaBytes);
            }

            // NOTE: a Sound source declared Data/PrefetchStreaming in HIRC with no matching entry in
            // THIS bank's own DIDX is not a defect - confirmed by directly cross-referencing shipped,
            // working LE3 content (native SFXPawn_GethPrime.pcc and SFXWeapon_Heavy_Blackstar.pcc both
            // carry SourceId 2269036 this exact way: nonzero InMemoryMediaSize, zero local DIDX
            // entries). Wwise resolves embedded media globally across every currently-loaded bank, not
            // just the declaring bank's own DIDX, so such a source plays fine as long as some other
            // loaded bank supplies the real DIDX/DATA entry. Do not zero these out here - that would
            // silence legitimately cross-bank-shared audio instead of fixing anything. (Third-party/
            // unsupported-plugin sources are a real, separate case - see BankSourceData.WriteV134.)

            didxBody = newDidx.Write();
            dataBytes = newData.ToArray();
        }
        else
        {
            didxBody = Didx?.Write();
            dataBytes = Data?.Data;
        }

        // DATA must start at a file offset congruent to 8 (mod 16). Compute where it would land
        // (after BKHD-with-padding and DIDX) and pad BKHD's tail to hit that alignment.
        byte[] bkhdPadding = Array.Empty<byte>();
        if (dataBytes != null)
        {
            var dataChunkOffset = w.Position + 8 + bkhdBody.Length + (didxBody != null ? 8 + didxBody.Length : 0);
            bkhdPadding = BkhdChunk.ComputeAlignmentPadding(dataChunkOffset);
        }
        w.U32((uint)(bkhdBody.Length + bkhdPadding.Length));
        w.Bytes(bkhdBody);
        w.Bytes(bkhdPadding);

        if (didxBody != null)
        {
            w.Tag4("DIDX");
            w.U32((uint)didxBody.Length);
            w.Bytes(didxBody);
        }

        if (dataBytes != null)
        {
            w.Tag4("DATA");
            w.U32((uint)dataBytes.Length);
            w.Bytes(dataBytes);
        }

        if (HircRaw != null)
        {
            Func<uint, uint?>? sourceSizeOverride = newEmbeddedSizes != null
                ? id => newEmbeddedSizes.TryGetValue(id, out var size) ? size : null
                : null;
            Func<uint, bool>? isFullyEmbedded = newlyFullyEmbedded != null
                ? id => newlyFullyEmbedded.Contains(id)
                : null;
            var hircBody = HircChunk.ConvertV56ToV134(HircRaw, BusRemap.Remap, stats, sourceSizeOverride, isFullyEmbedded);
            w.Tag4("HIRC");
            w.U32((uint)hircBody.Length);
            w.Bytes(hircBody);
        }

        if (Stid != null)
        {
            var stidBody = Stid.Write();
            w.Tag4("STID");
            w.U32((uint)stidBody.Length);
            w.Bytes(stidBody);
        }

        return w.ToArray();
    }
}
