using System.Security.Cryptography;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilan;
using ProjectMilanCore;

namespace ProjectMilan_ExtraContent.Redemption.Levels.CrossGenV.Audio;

/// <summary>
/// One playable audio file in the port. Sourced from a single ISACT 'samp' object, which the Vegas DLC always stores
/// as a complete Ogg Vorbis stream (verified: every sample's cmpi has current == target == OGGVORBIS), so no ISACT
/// decoder is involved - the Ogg is carved out and handed straight to ffmpeg.
/// </summary>
internal sealed class VegasSample
{
    /// <summary>SHA256 of <see cref="OggData"/>. Samples are shared between cues and packages; this is the dedupe key.</summary>
    public string ContentHash { get; init; }

    /// <summary>ISACT sample title, e.g. "jug20_waves01.wav". Not unique across the DLC.</summary>
    public string IsactName { get; init; }

    /// <summary>Unique, Wwise-safe name. Used for the .wav on disk and the Wwise Sound object.</summary>
    public string WwiseName { get; set; }

    public byte[] OggData { get; init; }
    public int SampleRate { get; init; }
    public int Channels { get; init; }
    public TimeSpan Duration { get; init; }

    /// <summary>Attenuation preset ('bfob' -> 'sdst') this sample was authored against, if it is spatialized.</summary>
    public IsactSoundDistance? Distance { get; init; }

    /// <summary>
    /// Whether this sample is streamed out to the AFC rather than embedded in the bank. Anything over 5 seconds or
    /// 500 KB streams - embedded audio is duplicated into every bank that references it, so only genuinely small
    /// clips are worth embedding.
    /// </summary>
    public bool ShouldStream => Duration.TotalSeconds > 5 || OggData.Length > 500 * 1024;

    public override string ToString() => $"{WwiseName ?? IsactName} ({Duration.TotalSeconds:F1}s, {OggData.Length / 1024}KB, {Channels}ch @ {SampleRate}Hz){(ShouldStream ? " [stream]" : "")}";
}

/// <summary>
/// One variation within a cue - a <see cref="VegasSample"/> plus the weighting and gain/pitch randomisation the ISACT
/// SoundEvent ('snde') track applied to it.
/// </summary>
internal sealed class VegasVariation
{
    public VegasSample Sample { get; init; }

    /// <summary>Selection weight, from the track's ulChance. 100 for a cue with no SoundEvent.</summary>
    public float Weight { get; init; } = 100;

    public float MinGain { get; init; } = 1f;
    public float MaxGain { get; init; } = 1f;
    public float MinPitch { get; init; } = 1f;
    public float MaxPitch { get; init; } = 1f;

    public bool HasGainRange => Math.Abs(MinGain - MaxGain) > 0.001f;
    public bool HasPitchRange => Math.Abs(MinPitch - MaxPitch) > 0.001f;
}

/// <summary>
/// One LE1 SoundCue, flattened into everything needed to author it as a Wwise object.
/// </summary>
internal sealed class VegasCue
{
    /// <summary>Instanced full path of the LE1 SoundCue, e.g. "snd_jug_20_00.c_jug20_waves".</summary>
    public string SourcePath { get; init; }

    /// <summary>Source packages this cue was found in. The same cue is duplicated across several _SND files.</summary>
    public List<string> SourcePackages { get; } = [];

    /// <summary>Unique, Wwise-safe object name. Also the basis of the Play_/Stop_ event names.</summary>
    public string WwiseName { get; set; }

    /// <summary>SoundCue.VolumeMultiplier - a linear multiplier, converted to dB for Wwise.</summary>
    public float VolumeMultiplier { get; init; } = 1f;

    /// <summary>SoundCue.PitchMultiplier - a linear ratio, converted to cents for Wwise.</summary>
    public float PitchMultiplier { get; init; } = 1f;

    /// <summary>SoundCue.SoundGroup, e.g. "AMBIENCE". Informational only.</summary>
    public string SoundGroup { get; init; }

    /// <summary>
    /// SoundNodeAttenuation.MinRadius/MaxRadius, in metres (the UE3 values divided by 100). Null when the cue's graph
    /// has no attenuation node, in which case the sound is not spatialized at all.
    /// </summary>
    public float? MinRadius { get; init; }
    public float? MaxRadius { get; init; }

    /// <summary>Whether the LE1 attenuation node applies distance attenuation and 3D positioning.</summary>
    public bool IsAttenuated { get; init; }
    public bool IsSpatialized { get; init; }

    /// <summary>
    /// The lower-level ISACT buffer's signed dB level at max distance. ISACT's OpenAL backend uses this to calculate
    /// its fixed inverse-clamped rolloff; the UE3 attenuation node remains authoritative for radii.
    /// </summary>
    public float MaxDistanceLevelDb { get; set; } = IsactSoundDistance.Default.MaxDistanceLevel;

    /// <summary>True when the cue's graph contains a SoundNodeModulator, which applies a +/-10% volume and pitch jitter.</summary>
    public bool HasModulator { get; init; }

    /// <summary>True when the SoundNodeWave's Duration is BioWare's infinite-loop marker.</summary>
    public bool IsLooping { get; init; }

    /// <summary>
    /// True when the source SoundEvent set SOUNDEVENTFLAG_PREVENT_REPEATS, i.e. don't play the same variation twice
    /// in a row.
    /// </summary>
    public bool PreventRepeats { get; set; }

    public List<VegasVariation> Variations { get; } = [];

    /// <summary>
    /// Distinct effective actor gains (AmbientSound.m_fVolume * AudioComponent.VolumeMultiplier) used to play this
    /// cue. WwiseAmbientSound has no actor volume property, so non-default values get game-object-scoped Set Voice
    /// Volume actions on a neutral parent mixer in actor-specific Play events. Keeping the authored cue/ISACT gain
    /// on the child prevents Wwise's Independent action value from replacing it.
    /// </summary>
    public HashSet<float> ActorVolumeMultipliers { get; } = [];

    /// <summary>
    /// Whether this cue's audio streams. Wwise routes a container to a single output bus, and our streamed and
    /// non-streamed ambient buses are separate, so a cue whose variations disagree falls back to embedding all of
    /// them rather than splitting the container across two buses.
    /// </summary>
    public bool Streams => Variations.Count > 0 && Variations.All(x => x.Sample.ShouldStream);

    /// <summary>A container is only needed when there's more than one variation to pick between.</summary>
    public bool IsContainer => Variations.Count > 1;

    public string PlayEventName => $"Play_{WwiseName}";
    public string StopEventName => $"Stop_{WwiseName}";

    public string PlayEventNameForVolume(float volume)
    {
        if (Math.Abs(volume - 1f) <= 0.001f) return PlayEventName;
        var token = MathF.Round(volume, 4).ToString("0.####", System.Globalization.CultureInfo.InvariantCulture)
            .Replace('-', 'm').Replace('.', 'p');
        return $"{PlayEventName}_Vol_{token}";
    }

    public override string ToString() => $"{SourcePath} -> {WwiseName} ({Variations.Count} variation(s), {(Streams ? "streamed" : "embedded")})";
}

/// <summary>
/// The complete set of audio to be built into the Wwise_Vegas bank.
/// </summary>
internal sealed class VegasAudioModel
{
    public List<VegasCue> Cues { get; } = [];

    /// <summary>Every unique sample, keyed by content hash.</summary>
    public Dictionary<string, VegasSample> Samples { get; } = [];

    public IEnumerable<VegasSample> StreamedSamples => Samples.Values.Where(x => Cues.Any(c => c.Streams && c.Variations.Any(v => v.Sample == x)));
}

internal static class VegasAudioScanner
{
    private const string LOG_CATEGORY = @"MILANEC-PSAUDIO";

    /// <summary>
    /// LE1's marker for a SoundNodeWave that loops forever rather than having a real duration
    /// (0xFFFFFFFF milliseconds expressed as seconds).
    /// </summary>
    private const float IndefinitelyLoopingDuration = 4294967f;

    /// <summary>SOUNDEVENTFLAG_PREVENT_REPEATS from SoundEvent.h.</summary>
    private const uint SoundEventFlagPreventRepeats = 0x01;

    /// <summary>
    /// Unreal units per metre. LE3 hands Wwise metre-scale positions (verified by decoding shipped LE3 attenuation
    /// curves, whose max distances are 25/30/50), and ISACT's own distances are already metres, so UE3 radii divide
    /// by this and ISACT distances pass through untouched.
    /// </summary>
    private const float UnrealUnitsPerMetre = 100f;

    /// <summary>
    /// Reads every SoundCue in the given LE1 packages and flattens it into a <see cref="VegasAudioModel"/>.
    /// A cue that appears in more than one package is emitted once.
    /// </summary>
    public static VegasAudioModel Scan(string cookedFolder, IEnumerable<string> packageNames)
    {
        var model = new VegasAudioModel();
        var cuesByPath = new Dictionary<string, VegasCue>(StringComparer.OrdinalIgnoreCase);

        foreach (var packageName in packageNames)
        {
            var path = Path.Combine(cookedFolder, packageName);
            if (!File.Exists(path))
            {
                MilanLog.Warning($"Source audio package not found, skipping: {path}", customPrefix: LOG_CATEGORY);
                continue;
            }

            using var package = MEPackageHandler.OpenMEPackage(path);
            foreach (var cueExport in package.Exports.Where(x => x.ClassName == "SoundCue"))
            {
                if (cuesByPath.TryGetValue(cueExport.InstancedFullPath, out var existing))
                {
                    existing.SourcePackages.Add(packageName);
                    continue;
                }

                var cue = BuildCue(cueExport, model);
                if (cue == null) continue;

                cue.SourcePackages.Add(packageName);
                cuesByPath[cue.SourcePath] = cue;
                model.Cues.Add(cue);
            }

            // WwiseAmbientSound has no serialized per-actor gain. Capture every LE1 actor multiplier while its cue
            // references are local and easy to resolve; the writer will create one gain-adjusted Play event per
            // distinct value without duplicating the underlying audio object or media.
            foreach (var ambientSound in package.Exports.Where(x => x.ClassName == "AmbientSound"))
            {
                var componentRef = ambientSound.GetProperty<ObjectProperty>("AudioComponent");
                if (componentRef == null || !package.TryGetUExport(componentRef.Value, out var component)) continue;
                var cueRef = component.GetProperty<ObjectProperty>("SoundCue");
                if (cueRef == null || !package.TryGetUExport(cueRef.Value, out var actorCue)) continue;
                if (!cuesByPath.TryGetValue(actorCue.InstancedFullPath, out var cue)) continue;

                cue.ActorVolumeMultipliers.Add(GetAmbientVolumeMultiplier(ambientSound));
            }
        }

        AssignUniqueNames(model);
        return model;
    }

    private static VegasCue BuildCue(ExportEntry cueExport, VegasAudioModel model)
    {
        var package = cueExport.FileRef;
        var firstNode = cueExport.GetProperty<ObjectProperty>("FirstNode");
        if (firstNode == null || !package.TryGetUExport(firstNode.Value, out _))
        {
            MilanLog.Warning($"SoundCue {cueExport.InstancedFullPath} has no FirstNode, skipping", customPrefix: LOG_CATEGORY);
            return null;
        }

        // The Vegas cue graphs only ever take three shapes - Attenuation->Wave, Attenuation->Modulator->Wave, and a
        // bare Wave - so a flat walk collecting the one node of each kind we care about is sufficient. Anything more
        // exotic showing up is logged rather than silently half-ported.
        ExportEntry attenuationNode = null;
        ExportEntry waveNode = null;
        var hasModulator = false;
        var unexpectedNodes = new List<string>();

        foreach (var node in WalkGraph(package, firstNode.Value))
        {
            switch (node.ClassName)
            {
                case "SoundNodeAttenuation":
                    attenuationNode ??= node;
                    break;
                case "SoundNodeWave":
                    waveNode ??= node;
                    break;
                case "SoundNodeModulator":
                    hasModulator = true;
                    break;
                default:
                    unexpectedNodes.Add(node.ClassName);
                    break;
            }
        }

        if (unexpectedNodes.Count > 0)
        {
            MilanLog.Warning($"SoundCue {cueExport.InstancedFullPath} contains unhandled node type(s) {string.Join(", ", unexpectedNodes.Distinct())} - their behaviour will not be ported", customPrefix: LOG_CATEGORY);
        }

        if (waveNode == null)
        {
            MilanLog.Warning($"SoundCue {cueExport.InstancedFullPath} has no SoundNodeWave, skipping", customPrefix: LOG_CATEGORY);
            return null;
        }

        float? minRadius = null, maxRadius = null;
        var isAttenuated = false;
        var isSpatialized = false;
        if (attenuationNode != null)
        {
            minRadius = GetDistributionValue(attenuationNode, "MinRadius") / UnrealUnitsPerMetre;
            maxRadius = GetDistributionValue(attenuationNode, "MaxRadius") / UnrealUnitsPerMetre;
            isAttenuated = attenuationNode.GetProperty<BoolProperty>("bAttenuate")?.Value ?? true;
            isSpatialized = attenuationNode.GetProperty<BoolProperty>("bSpatialize")?.Value ?? true;
        }

        var duration = waveNode.GetProperty<FloatProperty>("Duration")?.Value ?? 0f;

        var cue = new VegasCue
        {
            SourcePath = cueExport.InstancedFullPath,
            VolumeMultiplier = cueExport.GetProperty<FloatProperty>("VolumeMultiplier")?.Value ?? 1f,
            PitchMultiplier = cueExport.GetProperty<FloatProperty>("PitchMultiplier")?.Value ?? 1f,
            SoundGroup = cueExport.GetProperty<NameProperty>("SoundGroup")?.Value.Name,
            MinRadius = minRadius,
            MaxRadius = maxRadius,
            IsAttenuated = isAttenuated,
            IsSpatialized = isSpatialized,
            HasModulator = hasModulator,
            IsLooping = duration >= IndefinitelyLoopingDuration,
        };

        PopulateVariations(cue, waveNode, model);
        if (cue.Variations.Count == 0)
        {
            MilanLog.Warning($"SoundCue {cueExport.InstancedFullPath} produced no playable samples, skipping", customPrefix: LOG_CATEGORY);
            return null;
        }

        cue.MaxDistanceLevelDb = cue.Variations.Select(x => x.Sample.Distance).FirstOrDefault(x => x != null)?.MaxDistanceLevel
                                 ?? IsactSoundDistance.Default.MaxDistanceLevel;

        return cue;
    }

    /// <summary>
    /// LE1 layers the AmbientSound's fade target over its AudioComponent's authored multiplier. Both are per actor,
    /// so both belong in the game-object-scoped Wwise gain event rather than in the shared cue object.
    /// </summary>
    internal static float GetAmbientVolumeMultiplier(ExportEntry ambientSound)
    {
        var actorVolume = ambientSound.GetProperty<FloatProperty>("m_fVolume")?.Value ?? 1f;
        var componentVolume = 1f;
        var componentRef = ambientSound.GetProperty<ObjectProperty>("AudioComponent");
        if (componentRef != null && ambientSound.FileRef.TryGetUExport(componentRef.Value, out var component))
        {
            componentVolume = component.GetProperty<FloatProperty>("VolumeMultiplier")?.Value ?? 1f;
        }

        return actorVolume * componentVolume;
    }

    /// <summary>
    /// Reads a UE3 RawDistributionFloat property (SoundNodeAttenuation stores its radii as distributions rather than
    /// plain floats). Every distribution in the Vegas cues is a constant, so the baked LookupTable's first entry is
    /// the value; MinValue is the fallback for a distribution that was never baked.
    /// </summary>
    private static float? GetDistributionValue(ExportEntry node, string propertyName)
    {
        var distribution = node.GetProperty<StructProperty>(propertyName);
        if (distribution == null) return null;

        var lookupTable = distribution.GetProp<ArrayProperty<FloatProperty>>("LookupTable");
        if (lookupTable is { Count: > 0 }) return lookupTable[0].Value;

        return distribution.GetProp<FloatProperty>("MinValue")?.Value;
    }

    /// <summary>
    /// Depth-first walk of a SoundCue's node graph from <paramref name="rootUIndex"/>, following ChildNodes.
    /// </summary>
    private static IEnumerable<ExportEntry> WalkGraph(IMEPackage package, int rootUIndex)
    {
        var seen = new HashSet<int>();
        var stack = new Stack<int>();
        stack.Push(rootUIndex);

        while (stack.Count > 0)
        {
            var uIndex = stack.Pop();
            if (!seen.Add(uIndex)) continue;
            if (!package.TryGetUExport(uIndex, out var node)) continue;

            yield return node;

            var children = node.GetProperty<ArrayProperty<ObjectProperty>>("ChildNodes");
            if (children == null) continue;
            foreach (var child in children)
            {
                if (child.Value != 0) stack.Push(child.Value);
            }
        }
    }

    /// <summary>
    /// Cracks a SoundNodeWave's embedded ISACT bank pair into the cue's variations.
    /// <para/>
    /// The ISB carried by a wave is already stripped to exactly the samples that wave uses (verified across all 45
    /// cues in the DLC: sample count always equals the SoundEvent's track count, or 1 when there is no SoundEvent),
    /// so the samples themselves are the variation list. The ICB is only consulted to recover per-variation weights
    /// and gain/pitch ranges.
    /// </summary>
    private static void PopulateVariations(VegasCue cue, ExportEntry waveNode, VegasAudioModel model)
    {
        IsactBankPair banks;
        try
        {
            // Not GetBinaryData(): a SoundNodeWave export's binary has fields ahead of the ISACT blob, and RawData is
            // the blob itself (this is what LEX's Soundpanel hands to its own ISACT reader).
            banks = IsactBankReader.ParseSoundNodeWaveBinary(ObjectBinary.From<SoundNodeWave>(waveNode).RawData);
        }
        catch (Exception e)
        {
            MilanLog.Error($"Failed to read ISACT banks from {waveNode.InstancedFullPath}: {e.Message}", customPrefix: LOG_CATEGORY);
            return;
        }

        // Buffer objects hold the 3D/attenuation presets; samples point at one by index via 's3di'.
        var buffers = new Dictionary<int, IsactSoundDistance>();
        foreach (var bfob in banks.Isb.Objects("bfob"))
        {
            var distance = IsactSoundDistance.From(bfob.Child("sdst"));
            if (distance != null && bfob.ResourceIndex is { } idx) buffers[idx] = distance.Value;
        }

        // Tracks key off the sample's own resource index, packed as ((bankIndex + 1) << 16) | objectIndex - only the
        // low half is meaningful inside a self-contained wave, which holds exactly one ICB and one ISB.
        var trackBySampleIndex = new Dictionary<int, IsactSoundTrack>();
        var soundEvent = SelectSoundEvent(banks.Icb);
        if (soundEvent != null)
        {
            foreach (var track in IsactSoundTrack.ParseAll(soundEvent))
            {
                trackBySampleIndex[(int)(track.BufferIndex & 0xFFFF)] = track;
            }

            // SOUNDEVENTINFO: lEventSelection, ulDefaultChance, lEqualChance, ulFlags, lResetParamsOnLoop, lResetSampleOnLoop
            if (soundEvent.Child("info")?.Data is { Length: >= 16 } eventInfo)
            {
                cue.PreventRepeats = (BitConverter.ToUInt32(eventInfo, 12) & SoundEventFlagPreventRepeats) != 0;
            }
        }

        foreach (var samp in banks.Isb.Objects("samp"))
        {
            var oggData = samp.SampleData;
            if (oggData is not { Length: > 0 })
            {
                MilanLog.Warning($"Sample '{samp.Title}' in {waveNode.InstancedFullPath} has no embedded audio (streamed from a loose ISB?) - skipping", customPrefix: LOG_CATEGORY);
                continue;
            }

            var compression = samp.CompressionInfo;
            if (compression is { CurrentFormat: not IsactCompressionFormat.OGGVORBIS })
            {
                MilanLog.Warning($"Sample '{samp.Title}' in {waveNode.InstancedFullPath} is {compression.Value.CurrentFormat}, not OGGVORBIS - skipping (the port assumes Ogg passthrough)", customPrefix: LOG_CATEGORY);
                continue;
            }

            var info = samp.SampleInfo;
            var hash = Convert.ToHexString(SHA256.HashData(oggData));

            if (!model.Samples.TryGetValue(hash, out var sample))
            {
                sample = new VegasSample
                {
                    ContentHash = hash,
                    IsactName = samp.Title ?? "unnamed",
                    OggData = oggData,
                    SampleRate = info?.SamplesPerSecond ?? 44100,
                    Channels = samp.ChannelCount,
                    Duration = info?.Duration ?? TimeSpan.Zero,
                    Distance = samp.BufferIndex is { } bufIdx && buffers.TryGetValue(bufIdx, out var d) ? d : null,
                };
                model.Samples[hash] = sample;
            }

            var variation = new VegasVariation { Sample = sample };
            if (samp.ResourceIndex is { } sampleIndex && trackBySampleIndex.TryGetValue(sampleIndex, out var track))
            {
                variation = new VegasVariation
                {
                    Sample = sample,
                    Weight = track.Chance,
                    MinGain = track.MinGain,
                    MaxGain = track.MaxGain,
                    MinPitch = track.MinPitch,
                    MaxPitch = track.MaxPitch,
                };
            }

            cue.Variations.Add(variation);
        }
    }

    /// <summary>
    /// Picks the SoundEvent the cue actually plays. Most waves have a single 'sdqu' SoundQueue pointing at either a
    /// sample or one 'snde' SoundEvent; a couple carry two near-identical SoundEvents and no queue at all, where
    /// either is equivalent (same tracks, same samples, only the chance split differs by a percent).
    /// </summary>
    private static IsactChunk SelectSoundEvent(IsactChunk icb)
    {
        var soundEvents = icb.Objects("snde").ToList();
        if (soundEvents.Count == 0) return null;
        if (soundEvents.Count == 1) return soundEvents[0];

        foreach (var queue in icb.Objects("sdqu"))
        {
            foreach (var content in IsactQueueContent.ParseAll(queue))
            {
                var target = soundEvents.FirstOrDefault(x => x.ResourceIndex == content.ObjectIndex);
                if (target != null) return target;
            }
        }

        return soundEvents[0];
    }

    /// <summary>
    /// Gives every cue and sample a unique, Wwise-safe name. Cue names come from the leaf of the LE1 path (e.g.
    /// "snd_jug_20_00.c_jug20_waves" -> "c_jug20_waves"), which collides across sound packages, so the owning
    /// package is prefixed on collision rather than appending a meaningless counter.
    /// </summary>
    private static void AssignUniqueNames(VegasAudioModel model)
    {
        var used = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var cue in model.Cues.OrderBy(x => x.SourcePath, StringComparer.OrdinalIgnoreCase))
        {
            var leaf = cue.SourcePath.Contains('.') ? cue.SourcePath[(cue.SourcePath.LastIndexOf('.') + 1)..] : cue.SourcePath;
            var qualified = Sanitize(cue.SourcePath.Replace('.', '_'));
            cue.WwiseName = Unique(used, Sanitize(leaf), qualified);
        }

        foreach (var sample in model.Samples.Values.OrderBy(x => x.IsactName, StringComparer.OrdinalIgnoreCase))
        {
            // ISACT sample titles keep a ".wav" suffix that would otherwise end up inside the Wwise object name.
            var baseName = sample.IsactName;
            if (baseName.EndsWith(".wav", StringComparison.OrdinalIgnoreCase)) baseName = baseName[..^4];
            sample.WwiseName = Unique(used, Sanitize(baseName), null);
        }
    }

    private static string Unique(HashSet<string> used, string preferred, string fallback)
    {
        if (used.Add(preferred)) return preferred;
        if (fallback != null && used.Add(fallback)) return fallback;

        for (var i = 2; ; i++)
        {
            var candidate = $"{preferred}_{i}";
            if (used.Add(candidate)) return candidate;
        }
    }

    /// <summary>
    /// Wwise object names may not contain the characters Wwise reserves for its own paths/queries. Everything that
    /// isn't alphanumeric or an underscore becomes an underscore.
    /// </summary>
    private static string Sanitize(string name)
    {
        var chars = name.Select(c => char.IsLetterOrDigit(c) ? c : '_').ToArray();
        var result = new string(chars).Trim('_');
        if (result.Length == 0) result = "unnamed";
        if (char.IsDigit(result[0])) result = "_" + result;
        return result;
    }
}
