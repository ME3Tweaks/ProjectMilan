using System.Buffers.Binary;
using System.Text;

namespace ProjectMilan.Pipelines.Scaleform;

/// <summary>
/// Byte-level transplant of a glyph between Scaleform font movies (uncompressed GFX/FWS containing DefineFont3 tags).
/// Every byte of the target except the inserted glyph's shape, code, advance and bounds entry is copied verbatim with
/// its offsets rebased, so the result differs from the target only by the added glyph. Re-serializing through JPEXS
/// instead would re-encode every empty glyph and bounds RECT in the library (equivalent, but ~8KB of churn per font).
/// </summary>
public static class GfxFontGlyphSplicer
{
    private const int DefineFont3Tag = 75;
    private const int EndTag = 0;

    private readonly record struct TagSpan(int Code, int HeaderStart, int BodyStart, int BodyLength)
    {
        public int End => BodyStart + BodyLength;
    }

    /// <summary>
    /// Adds <paramref name="codePoint"/> from each DefineFont3 in <paramref name="donorMovie"/> to the same-named
    /// DefineFont3 in <paramref name="targetMovie"/>, at its sorted code table position. Every target font must
    /// have a donor of the same name and identical ascent/descent/leading, so the outline needs no rescaling.
    /// </summary>
    public static byte[] AddGlyph(byte[] donorMovie, byte[] targetMovie, int codePoint, Action<string>? log = null)
    {
        var donorFonts = ReadTags(donorMovie)
            .Where(t => t.Code == DefineFont3Tag)
            .Select(t => new Font3(donorMovie, t))
            .ToDictionary(f => f.Name);

        var tags = ReadTags(targetMovie);
        using var output = new MemoryStream(targetMovie.Length + 4096);
        output.Write(targetMovie, 0, tags[0].HeaderStart);
        int patchedFonts = 0;
        foreach (var tag in tags)
        {
            if (tag.Code != DefineFont3Tag)
            {
                output.Write(targetMovie, tag.HeaderStart, tag.End - tag.HeaderStart);
                continue;
            }

            var target = new Font3(targetMovie, tag);
            if (!donorFonts.TryGetValue(target.Name, out var donor))
                throw new InvalidDataException($"Donor movie has no font named {target.DisplayName}");
            if (!targetMovie.AsSpan(target.Layout, 6).SequenceEqual(donorMovie.AsSpan(donor.Layout, 6)))
                throw new InvalidDataException($"{target.DisplayName}: ascent/descent/leading differ between donor and target");

            var body = SpliceFont(target, donor, codePoint, log);
            WriteU16(output, (DefineFont3Tag << 6) | 0x3F); // always long-form; font tags are far over 62 bytes
            WriteU32(output, (uint)body.Length);
            output.Write(body);
            patchedFonts++;
        }

        // Anything after the End tag is carried over untouched.
        output.Write(targetMovie, tags[^1].End, targetMovie.Length - tags[^1].End);

        if (patchedFonts == 0)
            throw new InvalidDataException("Target movie has no DefineFont3 tags");

        var result = output.ToArray();
        BinaryPrimitives.WriteUInt32LittleEndian(result.AsSpan(4), (uint)result.Length);
        return result;
    }

    private static byte[] SpliceFont(Font3 target, Font3 donor, int codePoint, Action<string>? log)
    {
        int donorIndex = Array.BinarySearch(donor.Codes, codePoint);
        if (donorIndex < 0)
            throw new InvalidDataException($"Donor {donor.DisplayName} has no glyph for U+{codePoint:X4}");
        int existing = Array.BinarySearch(target.Codes, codePoint);
        if (existing >= 0)
            throw new InvalidDataException($"Target {target.DisplayName} already has a glyph for U+{codePoint:X4}");
        if (donor.KerningPairsWith(codePoint) > 0)
            throw new NotSupportedException($"Donor {donor.DisplayName} has kerning pairs for U+{codePoint:X4}, which are not carried over");

        int at = ~existing;
        int n = target.GlyphCount;
        byte[] t = target.Data, d = donor.Data;
        int glyphStart = donor.GlyphStart(donorIndex);
        int glyphLength = donor.GlyphEnd(donorIndex) - glyphStart;
        int boundsStart = donor.BoundsStarts[donorIndex];
        int boundsLength = donor.BoundsStarts[donorIndex + 1] - boundsStart;

        using var o = new MemoryStream(target.End - target.Start + glyphLength + 16);
        o.Write(t, target.Start, target.OffsetTable - 2 - target.Start); // font id, flags, language, name
        WriteU16(o, n + 1);

        // The extra offset entry moves every shape 4 bytes later; shapes after the insertion also move past the new one.
        for (int j = 0; j <= n; j++)
        {
            uint offset = j < at ? target.Offsets[j] + 4
                : j == at ? (at < n ? target.Offsets[at] : target.CodeTableOffset) + 4
                : target.Offsets[j - 1] + 4 + (uint)glyphLength;
            WriteU32(o, offset);
        }
        WriteU32(o, target.CodeTableOffset + 4 + (uint)glyphLength);

        int shapesStart = target.OffsetTable + 4 * (n + 1);
        int split = at < n ? target.GlyphStart(at) : target.CodeTable;
        o.Write(t, shapesStart, split - shapesStart);
        o.Write(d, glyphStart, glyphLength);
        o.Write(t, split, target.CodeTable - split);

        o.Write(t, target.CodeTable, 2 * at);
        WriteU16(o, codePoint);
        o.Write(t, target.CodeTable + 2 * at, 2 * (n - at));

        o.Write(t, target.Layout, 6); // ascent, descent, leading

        o.Write(t, target.AdvanceTable, 2 * at);
        o.Write(d, donor.AdvanceTable + 2 * donorIndex, 2);
        o.Write(t, target.AdvanceTable + 2 * at, 2 * (n - at));

        o.Write(t, target.BoundsTable, target.BoundsStarts[at] - target.BoundsTable);
        o.Write(d, boundsStart, boundsLength);
        o.Write(t, target.BoundsStarts[at], target.Kerning - target.BoundsStarts[at]);

        o.Write(t, target.Kerning, target.End - target.Kerning); // kerning is keyed by code, not glyph index

        log?.Invoke($"{target.DisplayName}: added U+{codePoint:X4} ({glyphLength} shape bytes, advance {(short)U16(d, donor.AdvanceTable + 2 * donorIndex)}) at glyph {at} of {n + 1}");
        return o.ToArray();
    }

    private static List<TagSpan> ReadTags(byte[] movie)
    {
        var signature = Encoding.ASCII.GetString(movie, 0, 3);
        if (signature != "GFX" && signature != "FWS")
            throw new InvalidDataException($"Expected an uncompressed GFx/SWF movie, got signature '{signature}'");
        if (U32(movie, 4) != movie.Length)
            throw new InvalidDataException($"Movie header length {U32(movie, 4)} does not match data length {movie.Length}");

        int pos = 8 + RectByteLength(movie, 8) + 4; // frame size rect, frame rate, frame count
        var tags = new List<TagSpan>();
        while (pos < movie.Length)
        {
            int headerStart = pos;
            int codeAndLength = U16(movie, pos);
            pos += 2;
            int length = codeAndLength & 0x3F;
            if (length == 0x3F)
            {
                length = (int)U32(movie, pos);
                pos += 4;
            }
            var tag = new TagSpan(codeAndLength >> 6, headerStart, pos, length);
            if (tag.End > movie.Length)
                throw new InvalidDataException($"Tag {tag.Code} at {headerStart} runs past the end of the movie");
            tags.Add(tag);
            pos = tag.End;
            if (tag.Code == EndTag)
                break;
        }
        return tags;
    }

    /// <summary>
    /// Parsed positions within a DefineFont3 tag body. Only the wide-offset, wide-code, has-layout form is supported.
    /// </summary>
    private sealed class Font3
    {
        public readonly byte[] Data;
        public readonly int Start, End;
        public readonly string Name;
        public readonly int GlyphCount;
        public readonly int OffsetTable;
        public readonly uint[] Offsets;
        public readonly uint CodeTableOffset;
        public readonly int CodeTable, Layout, AdvanceTable, BoundsTable, Kerning;
        public readonly int[] Codes;
        public readonly int[] BoundsStarts; // GlyphCount + 1 entries; bounds RECTs are variable length

        public string DisplayName => Name.TrimEnd('\0');

        public Font3(byte[] data, TagSpan tag)
        {
            Data = data;
            Start = tag.BodyStart;
            End = tag.End;

            int flags = data[Start + 2];
            const int hasLayout = 0x80, wideOffsets = 0x08, wideCodes = 0x04;
            int nameLength = data[Start + 4];
            Name = Encoding.Latin1.GetString(data, Start + 5, nameLength);
            if ((flags & (hasLayout | wideOffsets | wideCodes)) != (hasLayout | wideOffsets | wideCodes))
                throw new NotSupportedException($"{DisplayName}: only DefineFont3 with layout, wide offsets and wide codes is supported (flags 0x{flags:X2})");

            int pos = Start + 5 + nameLength;
            GlyphCount = U16(data, pos);
            OffsetTable = pos + 2;
            Offsets = new uint[GlyphCount];
            for (int i = 0; i < GlyphCount; i++)
                Offsets[i] = U32(data, OffsetTable + 4 * i);
            CodeTableOffset = U32(data, OffsetTable + 4 * GlyphCount);

            CodeTable = OffsetTable + (int)CodeTableOffset;
            Codes = new int[GlyphCount];
            for (int i = 0; i < GlyphCount; i++)
            {
                Codes[i] = U16(data, CodeTable + 2 * i);
                if (i > 0 && Codes[i] <= Codes[i - 1])
                    throw new InvalidDataException($"{DisplayName}: code table is not ascending at glyph {i}");
            }

            Layout = CodeTable + 2 * GlyphCount;
            AdvanceTable = Layout + 6;
            BoundsTable = AdvanceTable + 2 * GlyphCount;
            BoundsStarts = new int[GlyphCount + 1];
            int bounds = BoundsTable;
            for (int i = 0; i < GlyphCount; i++)
            {
                BoundsStarts[i] = bounds;
                bounds += RectByteLength(data, bounds);
            }
            BoundsStarts[GlyphCount] = bounds;
            Kerning = bounds;

            if (Kerning + 2 + 6 * U16(data, Kerning) != End)
                throw new InvalidDataException($"{DisplayName}: kerning table does not end the tag; layout parse is off");
        }

        public int GlyphStart(int i) => OffsetTable + (int)Offsets[i];

        public int GlyphEnd(int i) => OffsetTable + (int)(i + 1 < GlyphCount ? Offsets[i + 1] : CodeTableOffset);

        public int KerningPairsWith(int code)
        {
            int count = U16(Data, Kerning), hits = 0;
            for (int i = 0; i < count; i++)
            {
                int record = Kerning + 2 + 6 * i;
                if (U16(Data, record) == code || U16(Data, record + 2) == code)
                    hits++;
            }
            return hits;
        }
    }

    /// <summary>
    /// Byte length of a byte-aligned SWF RECT: 5-bit field size, then four fields of that size.
    /// </summary>
    private static int RectByteLength(byte[] data, int pos) => (5 + 4 * (data[pos] >> 3) + 7) / 8;

    private static int U16(byte[] data, int pos) => BinaryPrimitives.ReadUInt16LittleEndian(data.AsSpan(pos));

    private static uint U32(byte[] data, int pos) => BinaryPrimitives.ReadUInt32LittleEndian(data.AsSpan(pos));

    private static void WriteU16(Stream s, int value)
    {
        Span<byte> b = stackalloc byte[2];
        BinaryPrimitives.WriteUInt16LittleEndian(b, (ushort)value);
        s.Write(b);
    }

    private static void WriteU32(Stream s, uint value)
    {
        Span<byte> b = stackalloc byte[4];
        BinaryPrimitives.WriteUInt32LittleEndian(b, value);
        s.Write(b);
    }
}
