using System.Globalization;
using System.Security.Cryptography;
using System.Text;

namespace ProjectMilan_ExtraContent.Redemption.Levels.CrossGenV.Audio;

/// <summary>
/// Writes the Wwise work units (.wwu) that turn a <see cref="VegasAudioModel"/> into an authored Wwise project,
/// on top of an extracted copy of Pipelines/Audio/Template/TemplateProject.zip. The template already defines the LE3
/// bus hierarchy and the "Milan Max Quality" conversion preset; its Actor-Mixer, Attenuations, Events and SoundBanks
/// work units are empty stubs, which is where everything below gets injected.
/// <para/>
/// GUIDs and ShortIDs are derived from stable names rather than randomly generated, so re-running the build produces
/// a byte-identical project (and therefore identical .wem ids) instead of churning the bank on every run.
/// </summary>
internal static class WwiseProjectWriter
{
    // Objects the template already defines, referenced by the generated work units.
    private const string ConversionPresetName = "Milan Max Quality";
    private const string ConversionPresetId = "{1F410A13-638A-4393-AA08-5C93AE9D18AB}";
    private const string ConversionWorkUnitId = "{4619351E-05FE-45B9-AF21-A0E210CC16B4}";

    private const string MasterMixerWorkUnitId = "{124AB6D6-0A5E-4F07-B31E-EB2AD182B683}";
    private const string StreamedBusName = "Env-Snd-1-Amb-Stream";
    private const string StreamedBusId = "{2C43D15B-EEC8-48EB-A34D-9FCDEF811E51}";
    private const string NonStreamedBusName = "Env-Snd-1-Amb-NonStream";
    private const string NonStreamedBusId = "{9E38548E-5B62-41DC-B811-7E1A1A30AAE0}";

    // Work unit ids from the template's own stubs. A work unit's document ID and its root WorkUnit ID are the same.
    private const string ActorMixerWorkUnitId = "{64D3E298-01E5-4468-A817-398B71B7BCFE}";
    private const string AttenuationsWorkUnitId = "{DF989BE0-29EF-4D57-98C0-F5726141F304}";
    private const string EventsWorkUnitId = "{EAD77E84-280E-46B9-8275-80A29E2CCEC4}";
    private const string SoundBanksWorkUnitId = "{880CA6FC-77C9-4DBF-8BAE-462581AF8898}";

    /// <summary>Wwise Action.ActionType: 1 = Play, 2 = Stop. Confirmed by round-tripping both through GenerateSoundBanks.</summary>
    private const int ActionTypePlay = 1;
    private const int ActionTypeStop = 2;
    private const int ActionTypeSetVoiceVolume = 12;

    /// <summary>
    /// How many points to plot the distance curve with. ISACT's rolloff is a hyperbola and Wwise interpolates between
    /// the points we give it, so this is just "enough that the interpolation shape stops mattering".
    /// </summary>
    private const int AttenuationCurvePoints = 20;

    /// <summary>
    /// Nearby environmental beds should not collapse to a sharply localized mono point. The Wwise 2019 sample
    /// project's Ambience attenuation uses the same 50%-to-0% pattern.
    /// </summary>
    private const float NearFieldSpreadPercent = 50f;

    /// <summary>Point.Flags values observed on real curves - the last point of a curve differs from the rest.</summary>
    private const int CurvePointFlags = 5;
    private const int CurveLastPointFlags = 37;

    /// <summary>
    /// Wwise's volume/pitch properties are absolute limits, and a linear multiplier of 0 has no dB representation.
    /// Anything at or below this is treated as full silence.
    /// </summary>
    private const float MinVolumeDb = -200f;

    /// <summary>
    /// Fades applied to the generated Stop events so ambient beds don't cut off instantly when a volume is left.
    /// </summary>
    private const float StopFadeSeconds = 0.5f;

    private sealed record AttenuationShareSet(string Name, string Id, float MinRadius, float MaxRadius, float MaxDistanceLevelDb);

    /// <summary>
    /// Writes all four generated work units into <paramref name="projectRoot"/>, and returns the model's samples in
    /// the order their .wav files must exist under Originals/SFX.
    /// </summary>
    public static void Write(VegasAudioModel model, string projectRoot, string bankName)
    {
        var usedShortIds = new HashSet<uint>();

        // One shared attenuation per distinct (min, max, dB-at-max) triple - several cues resolve to the same curve,
        // and a ShareSet keeps that visible in the project instead of duplicating inline curves.
        var attenuations = new Dictionary<string, AttenuationShareSet>();
        foreach (var cue in model.Cues)
        {
            if (cue is not { IsAttenuated: true, MinRadius: { } min, MaxRadius: { } max }) continue;
            var key = $"{min:0.###}_{max:0.###}_{cue.MaxDistanceLevelDb:0.###}";
            if (attenuations.ContainsKey(key)) continue;
            var name = $"Atten_{Format(min)}_{Format(max)}_{Format(cue.MaxDistanceLevelDb)}dB";
            attenuations[key] = new AttenuationShareSet(name, Guid(name), min, max, cue.MaxDistanceLevelDb);
        }

        File.WriteAllText(Path.Combine(projectRoot, "Attenuations", "Default Work Unit.wwu"), BuildAttenuations(attenuations.Values, usedShortIds), new UTF8Encoding(false));
        File.WriteAllText(Path.Combine(projectRoot, "Actor-Mixer Hierarchy", "Default Work Unit.wwu"), BuildActorMixer(model, attenuations, usedShortIds), new UTF8Encoding(false));
        File.WriteAllText(Path.Combine(projectRoot, "Events", "Default Work Unit.wwu"), BuildEvents(model, usedShortIds), new UTF8Encoding(false));
        File.WriteAllText(Path.Combine(projectRoot, "SoundBanks", "Default Work Unit.wwu"), BuildSoundBank(bankName), new UTF8Encoding(false));
        return;

        static string Format(float value) => value.ToString("0.##", CultureInfo.InvariantCulture).Replace('.', '_');
    }

    #region Attenuations

    private static string BuildAttenuations(IEnumerable<AttenuationShareSet> shareSets, HashSet<uint> usedShortIds)
    {
        var sb = new StringBuilder();
        OpenWorkUnit(sb, "Attenuations", AttenuationsWorkUnitId);

        foreach (var set in shareSets.OrderBy(x => x.Name, StringComparer.OrdinalIgnoreCase))
        {
            sb.AppendLine($"\t\t\t\t<Attenuation Name=\"{Escape(set.Name)}\" ID=\"{set.Id}\" ShortID=\"{ShortId(set.Name, usedShortIds)}\">");
            sb.AppendLine("\t\t\t\t\t<PropertyList>");
            // Without RadiusMax, Wwise silently rescales the authored curve to fill its default 100m radius - the
            // points come back out stretched, with only a ProjectLoad warning to show for it.
            sb.AppendLine($"\t\t\t\t\t\t<Property Name=\"RadiusMax\" Type=\"Real64\" Value=\"{Num(set.MaxRadius)}\"/>");
            sb.AppendLine("\t\t\t\t\t</PropertyList>");
            sb.AppendLine("\t\t\t\t\t<CurveUsageInfoList>");
            sb.AppendLine("\t\t\t\t\t\t<VolumeDryUsage>");
            sb.AppendLine("\t\t\t\t\t\t\t<CurveUsageInfo Platform=\"Linked\" CurveToUse=\"Custom\">");
            sb.AppendLine($"\t\t\t\t\t\t\t\t<Curve Name=\"VolumeDry\" ID=\"{Guid(set.Name + ":VolumeDry")}\">");
            sb.AppendLine("\t\t\t\t\t\t\t\t\t<PropertyList>");
            sb.AppendLine("\t\t\t\t\t\t\t\t\t\t<Property Name=\"Flags\" Type=\"int32\" Value=\"3\"/>");
            sb.AppendLine("\t\t\t\t\t\t\t\t\t</PropertyList>");
            sb.AppendLine("\t\t\t\t\t\t\t\t\t<PointList>");

            var points = BuildCurve(set.MinRadius, set.MaxRadius, set.MaxDistanceLevelDb);
            for (var i = 0; i < points.Count; i++)
            {
                var flags = i == points.Count - 1 ? CurveLastPointFlags : CurvePointFlags;
                sb.AppendLine($"\t\t\t\t\t\t\t\t\t\t<Point><XPos>{Num(points[i].X)}</XPos><YPos>{Num(points[i].Y)}</YPos><Flags>{flags}</Flags></Point>");
            }

            sb.AppendLine("\t\t\t\t\t\t\t\t\t</PointList>");
            sb.AppendLine("\t\t\t\t\t\t\t\t</Curve>");
            sb.AppendLine("\t\t\t\t\t\t\t</CurveUsageInfo>");
            sb.AppendLine("\t\t\t\t\t\t</VolumeDryUsage>");
            // Every usage element has to be present even when unused, or Wwise rejects the work unit.
            AppendCurveUsage(sb, "VolumeWetGameUsage", "UseVolumeDry");
            AppendCurveUsage(sb, "VolumeWetUserUsage", "UseVolumeDry");
            AppendCurveUsage(sb, "LowPassFilterUsage", "None");
            AppendCurveUsage(sb, "HighPassFilterUsage", "None");
            sb.AppendLine("\t\t\t\t\t\t<SpreadUsage>");
            sb.AppendLine("\t\t\t\t\t\t\t<CurveUsageInfo Platform=\"Linked\" CurveToUse=\"Custom\">");
            sb.AppendLine($"\t\t\t\t\t\t\t\t<Curve Name=\"Spread\" ID=\"{Guid(set.Name + ":Spread")}\">");
            sb.AppendLine("\t\t\t\t\t\t\t\t\t<PropertyList><Property Name=\"Flags\" Type=\"int32\" Value=\"1\"/></PropertyList>");
            sb.AppendLine("\t\t\t\t\t\t\t\t\t<PointList>");
            sb.AppendLine($"\t\t\t\t\t\t\t\t\t\t<Point><XPos>0</XPos><YPos>{Num(NearFieldSpreadPercent)}</YPos><Flags>{CurvePointFlags}</Flags></Point>");
            if (set.MinRadius > 0)
            {
                sb.AppendLine($"\t\t\t\t\t\t\t\t\t\t<Point><XPos>{Num(set.MinRadius)}</XPos><YPos>{Num(NearFieldSpreadPercent)}</YPos><Flags>{CurvePointFlags}</Flags></Point>");
            }
            sb.AppendLine($"\t\t\t\t\t\t\t\t\t\t<Point><XPos>{Num(set.MaxRadius)}</XPos><YPos>0</YPos><Flags>{CurveLastPointFlags}</Flags></Point>");
            sb.AppendLine("\t\t\t\t\t\t\t\t\t</PointList>");
            sb.AppendLine("\t\t\t\t\t\t\t\t</Curve>");
            sb.AppendLine("\t\t\t\t\t\t\t</CurveUsageInfo>");
            sb.AppendLine("\t\t\t\t\t\t</SpreadUsage>");
            AppendCurveUsage(sb, "FocusUsage", "None");
            sb.AppendLine("\t\t\t\t\t</CurveUsageInfoList>");
            sb.AppendLine("\t\t\t\t</Attenuation>");
        }

        CloseWorkUnit(sb, "Attenuations");
        return sb.ToString();
    }

    private static void AppendCurveUsage(StringBuilder sb, string element, string curveToUse)
    {
        sb.AppendLine($"\t\t\t\t\t\t<{element}><CurveUsageInfo Platform=\"Linked\" CurveToUse=\"{curveToUse}\"/></{element}>");
    }

    /// <summary>
    /// Plots ISACT's fixed OpenAL AL_INVERSE_DISTANCE_CLAMPED curve, using the UE3 attenuation node's authoritative
    /// min/max radii. The ISACT max-distance level is stored as a negative dB value; Wwise work-unit Y values use the
    /// same convention. LE1's SoundNodeAttenuation DistanceModel enum does not reach this backend path.
    /// </summary>
    private static List<(float X, float Y)> BuildCurve(float minRadius, float maxRadius, float maxDistanceLevelDb)
    {
        var points = new List<(float X, float Y)>();

        // Full volume everywhere inside the min radius.
        if (minRadius > 0) points.Add((0f, 0f));
        points.Add((minRadius, 0f));

        if (maxRadius <= minRadius)
        {
            points.Add((Math.Max(maxRadius, minRadius + 0.01f), -Math.Abs(maxDistanceLevelDb)));
            return points;
        }

        // The shipped banks and ISACT default store this as negative dB. Abs also keeps malformed positive input
        // conservative instead of turning it into gain.
        var targetGain = MathF.Pow(10f, -Math.Abs(maxDistanceLevelDb) / 20f);
        var rolloff = Math.Clamp((minRadius / targetGain - minRadius) / (maxRadius - minRadius), 0f, 10f);

        // The inverse curve changes fastest immediately outside MinRadius. Geometric spacing concentrates points
        // there, while retaining an exact point at MaxRadius and Wwise's constant continuation beyond it.
        for (var i = 1; i <= AttenuationCurvePoints; i++)
        {
            var t = (float)i / AttenuationCurvePoints;
            var d = minRadius + (maxRadius - minRadius) * t * t;
            var gain = minRadius <= 0f
                ? targetGain
                : minRadius / (minRadius + rolloff * (d - minRadius));
            points.Add((d, ToDb(gain)));
        }

        return points;
    }

    #endregion

    #region Actor-Mixer Hierarchy

    private static string BuildActorMixer(VegasAudioModel model, Dictionary<string, AttenuationShareSet> attenuations, HashSet<uint> usedShortIds)
    {
        var sb = new StringBuilder();
        OpenWorkUnit(sb, "AudioObjects", ActorMixerWorkUnitId);

        foreach (var cue in model.Cues.OrderBy(x => x.WwiseName, StringComparer.OrdinalIgnoreCase))
        {
            AppendCueRootMixer(sb, cue, attenuations, usedShortIds);
        }

        CloseWorkUnit(sb, "AudioObjects");
        return sb.ToString();
    }

    /// <summary>
    /// Gives every cue a neutral parent whose only job is to receive Play/Stop and actor-volume Actions. Wwise emits
    /// Set Voice Volume actions with AkValueMeaning_Independent, so targeting the content object would replace its
    /// authored SoundCue/ISACT gain. Targeting this 0 dB parent keeps that independent actor gain on a separate
    /// hierarchy layer, where it combines with the child content's authored gain exactly as LE1 did.
    /// </summary>
    private static void AppendCueRootMixer(StringBuilder sb, VegasCue cue, Dictionary<string, AttenuationShareSet> attenuations, HashSet<uint> usedShortIds)
    {
        const string pad = "\t\t\t\t";
        var contentName = ContentObjectName(cue);

        sb.AppendLine($"{pad}<ActorMixer Name=\"{Escape(cue.WwiseName)}\" ID=\"{Guid(cue.WwiseName)}\" ShortID=\"{ShortId(cue.WwiseName, usedShortIds)}\">");
        sb.AppendLine($"{pad}\t<PropertyList>");
        AppendPositioningProperties(sb, cue, pad + "\t\t");
        sb.AppendLine($"{pad}\t</PropertyList>");
        AppendCueReferences(sb, cue, attenuations, pad + "\t");
        sb.AppendLine($"{pad}\t<ChildrenList>");
        if (cue.IsContainer)
        {
            AppendContainer(sb, cue, contentName, attenuations, usedShortIds, indent: 5);
        }
        else
        {
            AppendSound(sb, cue, cue.Variations[0], contentName, isCueRoot: true, attenuations, usedShortIds, indent: 5);
        }
        sb.AppendLine($"{pad}\t</ChildrenList>");
        sb.AppendLine($"{pad}</ActorMixer>");
    }

    private static void AppendContainer(StringBuilder sb, VegasCue cue, string name, Dictionary<string, AttenuationShareSet> attenuations, HashSet<uint> usedShortIds, int indent)
    {
        var pad = new string('\t', indent);
        sb.AppendLine($"{pad}<RandomSequenceContainer Name=\"{Escape(name)}\" ID=\"{Guid(name)}\" ShortID=\"{ShortId(name, usedShortIds)}\">");

        sb.AppendLine($"{pad}\t<PropertyList>");
        AppendVolumeAndPitch(sb, cue, variation: null, name, pad + "\t\t");
        // Ambient beds keep picking a new variation forever; Continuous chains them back to back rather than needing
        // a fresh Play per sound.
        sb.AppendLine($"{pad}\t\t<Property Name=\"PlayMechanismLoop\" Type=\"bool\" Value=\"True\"/>");
        sb.AppendLine($"{pad}\t\t<Property Name=\"PlayMechanismStepOrContinuous\" Type=\"int16\" Value=\"1\"/>");
        if (cue.PreventRepeats)
        {
            // ISACT's SOUNDEVENTFLAG_PREVENT_REPEATS is exactly Wwise's "avoid repeating the last N".
            sb.AppendLine($"{pad}\t\t<Property Name=\"RandomAvoidRepeatingCount\" Type=\"int32\" Value=\"1\"/>");
        }
        sb.AppendLine($"{pad}\t</PropertyList>");
        sb.AppendLine($"{pad}\t<ReferenceList/>");

        sb.AppendLine($"{pad}\t<ChildrenList>");
        foreach (var variation in cue.Variations)
        {
            AppendSound(sb, cue, variation, variation.Sample.WwiseName, isCueRoot: false, attenuations, usedShortIds, indent + 2);
        }
        sb.AppendLine($"{pad}\t</ChildrenList>");
        sb.AppendLine($"{pad}</RandomSequenceContainer>");
    }

    /// <summary>
    /// Writes one Sound. When <paramref name="isCueRoot"/> this is the content root of a single-variation cue and so
    /// carries the cue's volume, positioning and bus routing below the neutral action-target mixer; otherwise it's a
    /// container child and carries only its own weight and per-variation randomisation.
    /// </summary>
    private static void AppendSound(StringBuilder sb, VegasCue cue, VegasVariation variation, string name, bool isCueRoot, Dictionary<string, AttenuationShareSet> attenuations, HashSet<uint> usedShortIds, int indent)
    {
        var pad = new string('\t', indent);
        var sample = variation.Sample;

        sb.AppendLine($"{pad}<Sound Name=\"{Escape(name)}\" ID=\"{Guid(name)}\" ShortID=\"{ShortId(name, usedShortIds)}\">");

        sb.AppendLine($"{pad}\t<PropertyList>");
        if (isCueRoot)
        {
            // Routing, positioning and attenuation live on the neutral parent; this child keeps the SoundCue and
            // ISACT track gain below the parent's independent actor-volume action.
            AppendVolumeAndPitch(sb, cue, variation, name, pad + "\t\t");
            if (cue.IsLooping) sb.AppendLine($"{pad}\t\t<Property Name=\"IsLoopingEnabled\" Type=\"bool\" Value=\"True\"/>");
        }
        else
        {
            sb.AppendLine($"{pad}\t\t<Property Name=\"Weight\" Type=\"Real64\"><ValueList><Value>{Num(variation.Weight)}</Value></ValueList></Property>");
            AppendVolumeAndPitch(sb, cue: null, variation, name, pad + "\t\t");
        }

        // Streaming is decided per cue, not per sample, so that a container never straddles the streamed and
        // non-streamed ambient buses (see VegasCue.Streams).
        if (cue.Streams) sb.AppendLine($"{pad}\t\t<Property Name=\"IsStreamingEnabled\" Type=\"bool\"><ValueList><Value>True</Value></ValueList></Property>");
        sb.AppendLine($"{pad}\t</PropertyList>");
        sb.AppendLine($"{pad}\t<ReferenceList/>");

        var sourceId = Guid(sample.WwiseName + ":source");
        sb.AppendLine($"{pad}\t<ChildrenList>");
        sb.AppendLine($"{pad}\t\t<AudioFileSource Name=\"{Escape(sample.WwiseName)}\" ID=\"{sourceId}\" ShortID=\"{ShortId(sample.WwiseName + ":source", usedShortIds)}\">");
        sb.AppendLine($"{pad}\t\t\t<Language>SFX</Language>");
        sb.AppendLine($"{pad}\t\t\t<AudioFile>{Escape(sample.WwiseName)}.wav</AudioFile>");
        sb.AppendLine($"{pad}\t\t</AudioFileSource>");
        sb.AppendLine($"{pad}\t</ChildrenList>");
        sb.AppendLine($"{pad}\t<ActiveSourceList>");
        sb.AppendLine($"{pad}\t\t<ActiveSource Name=\"{Escape(sample.WwiseName)}\" ID=\"{sourceId}\" Platform=\"Linked\"/>");
        sb.AppendLine($"{pad}\t</ActiveSourceList>");
        sb.AppendLine($"{pad}</Sound>");
    }

    private static void AppendPositioningProperties(StringBuilder sb, VegasCue cue, string pad)
    {
        if (!cue.IsSpatialized) return;
        sb.AppendLine($"{pad}<Property Name=\"3DSpatialization\" Type=\"int16\" Value=\"2\"/>");
    }

    /// <summary>
    /// Writes the object's Volume and Pitch, folding together every source of level and jitter that applies at this
    /// point in the hierarchy. Wwise allows one Volume and one Pitch property per object, so a cue multiplier, a
    /// SoundNodeModulator and an ISACT track's own gain/pitch range all have to be composed into a single value plus
    /// a single Min/Max randomiser rather than written as separate properties.
    /// <para/>
    /// Pass <paramref name="cue"/> for an object that owns the cue's settings (a container, or the single Sound of a
    /// one-variation cue) and <paramref name="variation"/> for one that owns an ISACT track's; a container child
    /// passes only the variation, since it inherits the cue's half from its parent.
    /// </summary>
    private static void AppendVolumeAndPitch(StringBuilder sb, VegasCue cue, VegasVariation variation, string nameKey, string pad)
    {
        var volume = cue != null ? ToDb(cue.VolumeMultiplier) : 0f;
        var pitch = cue != null ? ToCents(cue.PitchMultiplier) : 0f;

        float volumeMin = 0, volumeMax = 0, pitchMin = 0, pitchMax = 0;
        var randomiseVolume = false;
        var randomisePitch = false;

        // SoundNodeModulator inherits Default__SoundNodeModulator's [0.9, 1.1] lookup table, so it is a live
        // +/-10% volume and pitch jitter rather than the no-op it looks like with no properties of its own.
        if (cue is { HasModulator: true })
        {
            volumeMin += ToDb(0.9f);
            volumeMax += ToDb(1.1f);
            pitchMin += ToCents(0.9f);
            pitchMax += ToCents(1.1f);
            randomiseVolume = true;
            randomisePitch = true;
        }

        if (variation is { HasGainRange: true })
        {
            // The track's gain range is a pair of linear multipliers in no guaranteed order; the louder of the two
            // becomes the object's level and the randomiser only ever takes it down from there.
            var loud = Math.Max(variation.MinGain, variation.MaxGain);
            var quiet = Math.Min(variation.MinGain, variation.MaxGain);
            volume += ToDb(loud);
            volumeMin += ToDb(quiet) - ToDb(loud);
            randomiseVolume = true;
        }

        if (variation is { HasPitchRange: true })
        {
            pitchMin += ToCents(Math.Min(variation.MinPitch, variation.MaxPitch));
            pitchMax += ToCents(Math.Max(variation.MinPitch, variation.MaxPitch));
            randomisePitch = true;
        }

        AppendRandomiser(sb, "Volume", "Real64", volume, volumeMin, volumeMax, randomiseVolume, nameKey + ":vol", pad);
        AppendRandomiser(sb, "Pitch", "int32", pitch, pitchMin, pitchMax, randomisePitch, nameKey + ":pitch", pad);
    }

    /// <summary>
    /// Writes a property, optionally with a Min/Max randomiser attached. Skipped entirely when the value is default
    /// and there's nothing to randomise, so the generated project only carries what it actually changes.
    /// </summary>
    private static void AppendRandomiser(StringBuilder sb, string property, string type, float value, float min, float max, bool randomise, string nameKey, string pad)
    {
        var hasValue = Math.Abs(value) > 0.001f;
        if (!hasValue && !randomise) return;

        sb.AppendLine($"{pad}<Property Name=\"{property}\" Type=\"{type}\">");
        sb.AppendLine($"{pad}\t<ValueList><Value>{Num(value)}</Value></ValueList>");
        if (randomise)
        {
            sb.AppendLine($"{pad}\t<ModifierList>");
            sb.AppendLine($"{pad}\t\t<ModifierInfo>");
            sb.AppendLine($"{pad}\t\t\t<Modifier Name=\"\" ID=\"{Guid(nameKey)}\">");
            sb.AppendLine($"{pad}\t\t\t\t<PropertyList>");
            sb.AppendLine($"{pad}\t\t\t\t\t<Property Name=\"Min\" Type=\"Real64\" Value=\"{Num(min)}\"/>");
            sb.AppendLine($"{pad}\t\t\t\t\t<Property Name=\"Max\" Type=\"Real64\" Value=\"{Num(max)}\"/>");
            sb.AppendLine($"{pad}\t\t\t\t</PropertyList>");
            sb.AppendLine($"{pad}\t\t\t</Modifier>");
            sb.AppendLine($"{pad}\t\t</ModifierInfo>");
            sb.AppendLine($"{pad}\t</ModifierList>");
        }
        sb.AppendLine($"{pad}</Property>");
    }

    private static void AppendCueReferences(StringBuilder sb, VegasCue cue, Dictionary<string, AttenuationShareSet> attenuations, string pad)
    {
        sb.AppendLine($"{pad}<ReferenceList>");

        if (cue is { IsAttenuated: true, MinRadius: { } min, MaxRadius: { } max })
        {
            var key = $"{min:0.###}_{max:0.###}_{cue.MaxDistanceLevelDb:0.###}";
            var set = attenuations[key];
            sb.AppendLine($"{pad}\t<Reference Name=\"Attenuation\">");
            sb.AppendLine($"{pad}\t\t<ObjectRef Name=\"{Escape(set.Name)}\" ID=\"{set.Id}\" WorkUnitID=\"{AttenuationsWorkUnitId}\"/>");
            sb.AppendLine($"{pad}\t</Reference>");
        }

        AppendConversionReference(sb, pad + "\t");

        var busName = cue.Streams ? StreamedBusName : NonStreamedBusName;
        var busId = cue.Streams ? StreamedBusId : NonStreamedBusId;
        sb.AppendLine($"{pad}\t<Reference Name=\"OutputBus\">");
        sb.AppendLine($"{pad}\t\t<ObjectRef Name=\"{busName}\" ID=\"{busId}\" WorkUnitID=\"{MasterMixerWorkUnitId}\"/>");
        sb.AppendLine($"{pad}\t</Reference>");

        sb.AppendLine($"{pad}</ReferenceList>");
    }

    private static void AppendConversionReference(StringBuilder sb, string pad)
    {
        sb.AppendLine($"{pad}<Reference Name=\"Conversion\">");
        sb.AppendLine($"{pad}\t<ObjectRef Name=\"{ConversionPresetName}\" ID=\"{ConversionPresetId}\" WorkUnitID=\"{ConversionWorkUnitId}\"/>");
        sb.AppendLine($"{pad}</Reference>");
    }

    #endregion

    #region Events and SoundBank

    private static string BuildEvents(VegasAudioModel model, HashSet<uint> usedShortIds)
    {
        var sb = new StringBuilder();
        OpenWorkUnit(sb, "Events", EventsWorkUnitId);

        foreach (var cue in model.Cues.OrderBy(x => x.WwiseName, StringComparer.OrdinalIgnoreCase))
        {
            var contentName = ContentObjectName(cue);
            AppendPlayEvent(sb, cue.PlayEventName, contentName, cue.WwiseName, actorVolume: 1f, usedShortIds);
            foreach (var volume in cue.ActorVolumeMultipliers.Where(x => Math.Abs(x - 1f) > 0.001f).Order())
            {
                AppendPlayEvent(sb, cue.PlayEventNameForVolume(volume), contentName, cue.WwiseName, volume, usedShortIds);
            }
            AppendEvent(sb, cue.StopEventName, contentName, ActionTypeStop, StopFadeSeconds, usedShortIds);
        }

        CloseWorkUnit(sb, "Events");
        return sb.ToString();
    }

    private static void AppendPlayEvent(StringBuilder sb, string eventName, string playTargetName, string volumeTargetName, float actorVolume, HashSet<uint> usedShortIds)
    {
        const string pad = "\t\t\t\t";
        sb.AppendLine($"{pad}<Event Name=\"{Escape(eventName)}\" ID=\"{Guid(eventName)}\">");
        sb.AppendLine($"{pad}\t<ChildrenList>");
        if (Math.Abs(actorVolume - 1f) > 0.001f)
        {
            AppendAction(sb, eventName + ":volume", volumeTargetName, ActionTypeSetVoiceVolume, fadeSeconds: null,
                volumeDb: ToDb(actorVolume), usedShortIds, pad + "\t\t");
        }
        AppendAction(sb, eventName + ":play", playTargetName, ActionTypePlay, fadeSeconds: null,
            volumeDb: null, usedShortIds, pad + "\t\t");
        sb.AppendLine($"{pad}\t</ChildrenList>");
        sb.AppendLine($"{pad}</Event>");
    }

    private static void AppendEvent(StringBuilder sb, string eventName, string targetName, int actionType, float? fadeSeconds, HashSet<uint> usedShortIds)
    {
        const string pad = "\t\t\t\t";
        // No ShortID on the Event itself: Wwise derives it from the name (FNV-1 over the lowercased name), which is
        // exactly what the game uses to post it, so letting Wwise assign it keeps the two in sync.
        sb.AppendLine($"{pad}<Event Name=\"{Escape(eventName)}\" ID=\"{Guid(eventName)}\">");
        sb.AppendLine($"{pad}\t<ChildrenList>");
        AppendAction(sb, eventName + ":action", targetName, actionType, fadeSeconds, volumeDb: null,
            usedShortIds, pad + "\t\t");
        sb.AppendLine($"{pad}\t</ChildrenList>");
        sb.AppendLine($"{pad}</Event>");
    }

    private static void AppendAction(StringBuilder sb, string actionKey, string targetName, int actionType,
        float? fadeSeconds, float? volumeDb, HashSet<uint> usedShortIds, string pad)
    {
        sb.AppendLine($"{pad}<Action Name=\"\" ID=\"{Guid(actionKey)}\" ShortID=\"{ShortId(actionKey, usedShortIds)}\">");
        sb.AppendLine($"{pad}\t<PropertyList>");
        sb.AppendLine($"{pad}\t\t<Property Name=\"ActionType\" Type=\"int16\" Value=\"{actionType}\"/>");
        if (fadeSeconds is { } fade)
        {
            sb.AppendLine($"{pad}\t\t<Property Name=\"FadeTime\" Type=\"Real64\" Value=\"{Num(fade)}\"/>");
        }
        if (volumeDb is { } volume)
        {
            sb.AppendLine($"{pad}\t\t<Property Name=\"Volume\" Type=\"Real64\"><ValueList><Value>{Num(volume)}</Value></ValueList></Property>");
        }
        sb.AppendLine($"{pad}\t</PropertyList>");
        sb.AppendLine($"{pad}\t<ReferenceList>");
        sb.AppendLine($"{pad}\t\t<Reference Name=\"Target\">");
        sb.AppendLine($"{pad}\t\t\t<ObjectRef Name=\"{Escape(targetName)}\" ID=\"{Guid(targetName)}\" WorkUnitID=\"{ActorMixerWorkUnitId}\"/>");
        sb.AppendLine($"{pad}\t\t</Reference>");
        sb.AppendLine($"{pad}\t</ReferenceList>");
        sb.AppendLine($"{pad}</Action>");
    }

    private static string BuildSoundBank(string bankName)
    {
        var sb = new StringBuilder();
        OpenWorkUnit(sb, "SoundBanks", SoundBanksWorkUnitId);

        // The project builds exactly one bank, so including both generated work units wholesale (Filter="7" is
        // Wwise's "everything") is both the simplest and the most complete option.
        sb.AppendLine($"\t\t\t\t<SoundBank Name=\"{Escape(bankName)}\" ID=\"{Guid(bankName)}\">");
        sb.AppendLine("\t\t\t\t\t<ObjectInclusionList>");
        sb.AppendLine($"\t\t\t\t\t\t<ObjectRef Name=\"Default Work Unit\" ID=\"{ActorMixerWorkUnitId}\" WorkUnitID=\"{ActorMixerWorkUnitId}\" Filter=\"7\" Origin=\"Manual\"/>");
        sb.AppendLine($"\t\t\t\t\t\t<ObjectRef Name=\"Default Work Unit\" ID=\"{EventsWorkUnitId}\" WorkUnitID=\"{EventsWorkUnitId}\" Filter=\"7\" Origin=\"Manual\"/>");
        sb.AppendLine("\t\t\t\t\t</ObjectInclusionList>");
        sb.AppendLine("\t\t\t\t\t<ObjectExclusionList/>");
        sb.AppendLine("\t\t\t\t\t<GameSyncExclusionList/>");
        sb.AppendLine("\t\t\t\t</SoundBank>");

        CloseWorkUnit(sb, "SoundBanks");
        return sb.ToString();
    }

    #endregion

    #region Plumbing

    private static void OpenWorkUnit(StringBuilder sb, string rootElement, string workUnitId)
    {
        sb.AppendLine("<?xml version=\"1.0\" encoding=\"utf-8\"?>");
        sb.AppendLine($"<WwiseDocument Type=\"WorkUnit\" ID=\"{workUnitId}\" SchemaVersion=\"94\">");
        sb.AppendLine($"\t<{rootElement}>");
        sb.AppendLine($"\t\t<WorkUnit Name=\"Default Work Unit\" ID=\"{workUnitId}\" PersistMode=\"Standalone\">");
        sb.AppendLine("\t\t\t<ChildrenList>");
    }

    private static void CloseWorkUnit(StringBuilder sb, string rootElement)
    {
        sb.AppendLine("\t\t\t</ChildrenList>");
        sb.AppendLine("\t\t</WorkUnit>");
        sb.AppendLine($"\t</{rootElement}>");
        sb.AppendLine("</WwiseDocument>");
    }

    /// <summary>Linear gain to dB, with 0 (and anything below) mapping to full silence rather than -infinity.</summary>
    private static float ToDb(float linear) => linear <= 0.0001f ? MinVolumeDb : Math.Clamp(20f * MathF.Log10(linear), MinVolumeDb, 200f);

    /// <summary>Linear pitch ratio to Wwise's cents.</summary>
    private static float ToCents(float ratio) => ratio <= 0.0001f ? 0f : Math.Clamp(1200f * MathF.Log2(ratio), -2400f, 2400f);

    private static string Num(float value) => MathF.Round(value, 4).ToString("0.####", CultureInfo.InvariantCulture);

    private static string ContentObjectName(VegasCue cue) => cue.WwiseName + "_Content";

    private static string Escape(string s) => s.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace("\"", "&quot;");

    /// <summary>
    /// A stable GUID for a name, so that regenerating the project doesn't renumber every object (which would change
    /// every generated .wem id and make the output impossible to diff).
    /// </summary>
    private static string Guid(string key)
    {
        var hash = MD5.HashData(Encoding.UTF8.GetBytes("ProjectMilan.Vegas:" + key));
        return new Guid(hash).ToString("B").ToUpperInvariant();
    }

    /// <summary>
    /// A stable 32-bit ShortID for a name. Wwise assigns these itself in the authoring tool, but hand-written work
    /// units have to supply them; the value only has to be unique within the project.
    /// </summary>
    private static uint ShortId(string key, HashSet<uint> used)
    {
        var candidate = Fnv1(key);
        while (candidate == 0 || !used.Add(candidate))
        {
            candidate = Fnv1(key + "#" + candidate);
        }
        return candidate;
    }

    /// <summary>FNV-1 32-bit over the lowercased name - the same hash Wwise uses for its own IDs.</summary>
    private static uint Fnv1(string value)
    {
        const uint prime = 16777619;
        var hash = 2166136261;
        foreach (var c in value.ToLowerInvariant())
        {
            hash *= prime;
            hash ^= c;
        }
        return hash;
    }

    #endregion
}
