using System.Buffers.Binary;
using BankConverter.Bnk;
using BankConverter.Bnk.Chunks;
using BankConverter.Bnk.Hirc;

int passed = 0;
void Check(bool condition, string name)
{
    if (!condition) throw new Exception(name);
    Console.WriteLine("PASS: " + name); passed++;
}
void Reject(Action action, string name)
{
    try { action(); } catch (Exception e) when (e is InvalidDataException or NotSupportedException or ArgumentException or IndexOutOfRangeException)
    { Console.WriteLine("PASS: rejects " + name); passed++; return; }
    throw new Exception("Did not reject " + name);
}

var little = new BankReader([0x34, 0x12, 0x78, 0x56, 0x34, 0x12, 0, 0, 0x80, 0x3F]);
Check(little.U16() == 0x1234 && little.U32() == 0x12345678 && little.F32() == 1f, "little-endian reader unchanged");
var big = new BankReader([0x12, 0x34, 0x12, 0x34, 0x56, 0x78, 0x3F, 0x80, 0, 0], true);
Check(big.U16() == 0x1234 && big.U32() == 0x12345678 && big.F32() == 1f, "big-endian reader primitives");
Check(new BankReader([1, 2, 3, 4, 5, 6, 7, 8], true).U64() == 0x0102030405060708ul, "big-endian U64 ordering");
Check(new BankReader([8, 7, 6, 5, 4, 3, 2, 1]).U64() == 0x0102030405060708ul, "little-endian U64 ordering");
Check(!BusRemap.TryRemap(uint.MaxValue, out _) && BusRemap.FallbackUses.Count == 0, "strict bus lookup has no fallback side effect");
Check(BusRemap.TryRemap(343668318, out var bus) && bus == 3803692087, "explicit source Master Audio Bus mapping");

var bytes = File.ReadAllBytes(args[0]);
var stats = new HircConversionStats();
var output = WiiUBankConverter.ConvertToV134(bytes, stats);
Check(stats.Total == 67 && stats.Converted.Values.Sum() == 67 && stats.Skipped.Count == 0 && stats.Errors.Count == 0, "all 67 HIRC objects retained");
Check(output.SequenceEqual(WiiUBankConverter.ConvertToV134(bytes, new())), "deterministic conversion");
var target = BankFile.ReadV56(output); // chunk headers/DIDX/STID share the target's little-endian layout.
Check(target.Bkhd.BankGeneratorVersion == 134 && target.Bkhd.SoundBankId == 873134235, "target version and bank ID");
Check(target.Didx!.Media.Count == 20 && target.Didx.Media.All(m => m.Offset % 16 == 0), "all media retained and 16-byte aligned");
var sources = new Dictionary<string, (int Offset, byte[] Body)>();
var r = new BankReader(bytes, true);
while (!r.AtEnd)
{
    var tag = r.Tag4(); var count = checked((int)r.U32()); var start = r.Position;
    sources.Add(tag, (start, r.Bytes(count)));
}
var media = DidxChunk.Read(new BankReader(sources["DIDX"].Body, true), (uint)sources["DIDX"].Body.Length);
foreach (var entry in media.Media)
{
    var wem = sources["DATA"].Body.AsSpan((int)entry.Offset, (int)entry.Size).ToArray();
    var converted = WiiUAdpcmWem.ConvertToLittleEndian(wem);
    Check(converted.Length == wem.Length && converted.AsSpan(0, 4).SequenceEqual("RIFF"u8), $"WEM {entry.Id}: size and RIFF");
    var truncated = wem[..^1];
    Reject(() => WiiUAdpcmWem.ConvertToLittleEndian(truncated), $"truncated WEM {entry.Id}");
}
void MutateAndReject(int at, byte[] value, string name)
{
    var copy = (byte[])bytes.Clone(); value.CopyTo(copy, at);
    Reject(() => WiiUBankConverter.ConvertToV134(copy, new()), name);
}
MutateAndReject(8, [0, 0, 0, 56], "wrong source version");
MutateAndReject(8, [65, 0, 0, 0], "little-endian source header");
MutateAndReject(sources["HIRC"].Offset + 4, [255], "unknown HIRC type (not dropped)");
MutateAndReject(sources["HIRC"].Offset + 15, [1], "distinct unverified attenuation gain slot");
MutateAndReject(20, [0, 0, 0, 1], "feedback/motion bank");
MutateAndReject(16, [0, 0, 0, 1], "localized bank");
Reject(() => WiiUBankConverter.ConvertToV134(bytes[..^1], new()), "truncated bank");
Check(BusRemap.FallbackUses.Count == 0, "no bus fallbacks after conversion");

// v56 continues to scale percent weights; the separate v65 flag prevents double-scaling.
var node = new NodeBaseParams { Fx = new(), Priority = 50, DistOffset = -10, Positioning = new(),
    Aux = new(), AdvSettings = new(), States = new(), Rtpc = new() };
var random = new RandomSequenceContainer { NodeBase = node, Playlist = [new PlaylistEntry { PlayId = 1, Weight = 50 }] };
var legacy = random.WriteV134(x => x);
Check(BinaryPrimitives.ReadInt32LittleEndian(legacy.AsSpan(legacy.Length - 4)) == 50000, "v56 playlist scale unchanged");
random.Playlist[0].Weight = 50000; random.WeightsAreV134Units = true;
Check(random.WriteV134(x => x).SequenceEqual(legacy), "v65 playlist not double-scaled");

if (args.Length > 1)
{
    var original = File.ReadAllBytes(args[1]);
    Check(BankFile.ReadV56(original).WriteV56ChunksRoundTrip().SequenceEqual(original), "real v56 chunk roundtrip regression");
}
Console.WriteLine($"{passed} checks passed.");
