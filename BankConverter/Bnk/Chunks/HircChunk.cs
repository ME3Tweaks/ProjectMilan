using BankConverter.Bnk.Hirc;

namespace BankConverter.Bnk.Chunks;

public sealed class HircConversionStats
{
    public int Total;
    public Dictionary<byte, int> Converted = new();
    public Dictionary<byte, int> Skipped = new();
    public List<string> Errors = new();

    /// <summary>Number of PrefetchStreaming source replacements truncated to a header+margin fragment
    /// (see PrefetchBuilder) instead of embedded in full.</summary>
    public int PrefetchFragmentsBuilt;

    /// <summary>Total bytes NOT embedded in bank DATA thanks to prefetch truncation (full replacement
    /// size minus the truncated fragment size, summed across all PrefetchFragmentsBuilt).</summary>
    public long PrefetchBytesSaved;
}

/// <summary>
/// HIRC chunk: reads every v56 object record (type + size + payload), converts the types we support,
/// and writes a v134 HIRC chunk containing only the successfully-converted objects. Unsupported types
/// are counted in <see cref="HircConversionStats"/> rather than silently dropped without a trace.
/// </summary>
public static class HircChunk
{
    /// <summary>
    /// Pre-scan: extracts SourceId -&gt; StreamType for every source-bearing HIRC object (Sound,
    /// MusicTrack) without doing a full v56-&gt;v134 conversion. Lets the DIDX/DATA splice pass (see
    /// BankFile.ConvertToV134) decide full-vs-truncated embedding for a given replacement WEM before the
    /// real HIRC conversion pass runs and needs to know the resulting sizes.
    /// </summary>
    public static Dictionary<uint, Hirc.SourceStreamType> ScanSourceStreamTypes(byte[] hircRaw)
    {
        var result = new Dictionary<uint, Hirc.SourceStreamType>();
        var r = new BankReader(hircRaw);
        var count = r.U32();

        for (var i = 0; i < count; i++)
        {
            var type = r.U8();
            var sectionSize = r.U32();
            var bodyStart = r.Position;
            var bodyEnd = bodyStart + (int)sectionSize;

            try
            {
                switch (type)
                {
                    case 0x02: // Sound
                        r.U32(); // Id
                        var src = Hirc.BankSourceData.ReadV56(r);
                        result[src.SourceId] = src.StreamType;
                        break;
                    case 0x0B: // MusicTrack
                        var track = Hirc.MusicTrack.ReadV56(r);
                        foreach (var s in track.Sources) result[s.SourceId] = s.StreamType;
                        break;
                }
            }
            catch
            {
                // Best-effort scan; the real conversion pass below surfaces parse errors properly.
            }

            r.Position = bodyEnd;
        }

        return result;
    }

    /// <summary>
    /// Pre-scan: finds every Fx (FxShareSet/FxCustom) object whose PluginId belongs to a third-party/
    /// studio-proprietary company registration (see <see cref="PluginSupport.IsThirdParty"/>) rather than
    /// a standard Audiokinetic plugin. LE3's stock Wwise runtime never linked BioWare's original plugin
    /// code, so any node referencing one of these needs that reference stripped rather than passed through -
    /// see ConvertV56ToV134's isFxSupported usage.
    /// </summary>
    private static HashSet<uint> ScanThirdPartyFxIds(byte[] hircRaw)
    {
        var result = new HashSet<uint>();
        var r = new BankReader(hircRaw);
        var count = r.U32();

        for (var i = 0; i < count; i++)
        {
            var type = r.U8();
            var sectionSize = r.U32();
            var bodyStart = r.Position;
            var bodyEnd = bodyStart + (int)sectionSize;

            try
            {
                if (type is 0x12 or 0x13) // FxShareSet / FxCustom
                {
                    var fx = Hirc.FxBase.ReadV56(r);
                    if (Hirc.PluginSupport.IsThirdParty(fx.PluginId)) result.Add(fx.Id);
                }
            }
            catch
            {
                // Best-effort scan; the real conversion pass below surfaces parse errors properly.
            }

            r.Position = bodyEnd;
        }

        return result;
    }

    public static byte[] ConvertV56ToV134(byte[] hircRaw, Func<uint, uint> remapBusId, HircConversionStats stats, Func<uint, uint?>? sourceSizeOverride = null, Func<uint, bool>? isFullyEmbedded = null)
    {
        var r = new BankReader(hircRaw);
        var count = r.U32();
        stats.Total += (int)count;

        var thirdPartyFxIds = ScanThirdPartyFxIds(hircRaw);
        bool IsFxSupported(uint fxId) => !thirdPartyFxIds.Contains(fxId);

        // Third-party Fx objects themselves are dropped too (nothing references them once IsFxSupported
        // strips every node's Fx-chain entry pointing at one, so there's no reason to carry the dead object).
        byte[]? ConvertFxOrNull(FxBase fx) => thirdPartyFxIds.Contains(fx.Id) ? null : fx.WriteV134();

        var convertedObjects = new List<byte[]>();

        for (var i = 0; i < count; i++)
        {
            var type = r.U8();
            var sectionSize = r.U32();
            var bodyStart = r.Position;
            var bodyEnd = bodyStart + (int)sectionSize;

            try
            {
                // Most eHircType values are stable across versions; FxShareSet/FxCustom are the exception.
                var v134Type = type switch
                {
                    0x12 => (byte)0x10, // FxShareSet
                    0x13 => (byte)0x11, // FxCustom
                    _ => type,
                };

                byte[]? body = type switch
                {
                    0x01 => AkState.ReadV56(r).WriteV134(),
                    0x02 => Sound.ReadV56(r).WriteV134(remapBusId, sourceSizeOverride, isFullyEmbedded, IsFxSupported),
                    0x03 => AkAction.ReadV56(r).WriteV134(remapBusId),
                    0x04 => Event.ReadV56(r).WriteV134(),
                    0x05 => RandomSequenceContainer.ReadV56(r).WriteV134(remapBusId, IsFxSupported),
                    0x06 => SwitchContainer.ReadV56(r).WriteV134(remapBusId, IsFxSupported),
                    0x07 => ActorMixer.ReadV56(r).WriteV134(remapBusId, IsFxSupported),
                    0x08 => Bus.ReadV56(r).WriteV134(remapBusId),
                    0x09 => LayerContainer.ReadV56(r).WriteV134(remapBusId, IsFxSupported),
                    0x0A => MusicSegment.ReadV56(r).WriteV134(remapBusId, IsFxSupported),
                    0x0B => MusicTrack.ReadV56(r).WriteV134(remapBusId, sourceSizeOverride, isFullyEmbedded, IsFxSupported),
                    0x0E => Attenuation.ReadV56(r).WriteV134(),
                    0x12 => ConvertFxOrNull(FxBase.ReadV56(r)),
                    0x13 => ConvertFxOrNull(FxBase.ReadV56(r)),
                    _ => null,
                };

                if (body != null)
                {
                    var obj = new BankWriter();
                    obj.U8(v134Type);
                    obj.U32((uint)body.Length);
                    obj.Bytes(body);
                    convertedObjects.Add(obj.ToArray());
                    stats.Converted[type] = stats.Converted.GetValueOrDefault(type) + 1;
                }
                else
                {
                    stats.Skipped[type] = stats.Skipped.GetValueOrDefault(type) + 1;
                }
            }
            catch (Exception ex)
            {
                stats.Errors.Add($"type=0x{type:X2}: {ex.Message}");
                stats.Skipped[type] = stats.Skipped.GetValueOrDefault(type) + 1;
            }

            r.Position = bodyEnd;
        }

        var w = new BankWriter();
        w.U32((uint)convertedObjects.Count);
        foreach (var obj in convertedObjects) w.Bytes(obj);
        return w.ToArray();
    }
}
