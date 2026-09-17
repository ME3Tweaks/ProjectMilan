using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using ProjectMilan;
using ProjectMilan_ExtraContent.Classes;
using ProjectMilanCore;

namespace ProjectMilan_ExtraContent.Redemption.Levels.CrossGenV.Audio;

/// <summary>
/// Recreates Pinnacle Station's LE1 ambient audio actors and volumes as their LE3 Wwise equivalents, pointed at the
/// events in the generated Wwise_Vegas bank.
/// <para/>
/// LE1 and LE3 line up unusually well here: <c>AmbientSound</c> and <c>WwiseAmbientSound</c> are both Keypoints whose
/// only real content is a position plus "what to play", so the actors are created fresh in the destination rather
/// than cross-game ported - there is no geometry, no components and no binary to carry over, just a location and a
/// pair of event references.
/// </summary>
internal static class VegasAudioActors
{
    /// <summary>
    /// Creates a WwiseAmbientSound in <paramref name="destPackage"/> for every free-standing AmbientSound in the LE1
    /// sound level <paramref name="sourcePackage"/>, and converts each BioAudioVolume to a WwiseAudioVolume containing
    /// Play/Stop event pairs for its AmbientSoundArray.
    /// </summary>
    /// <param name="model">The scan the bank was built from - maps LE1 cue paths to generated Wwise object names.</param>
    /// <param name="logCategory">The owning level's log category, so the output reads alongside the rest of its port.</param>
    /// <returns>How many point sounds and audio volumes were created.</returns>
    public static (int AmbientSounds, int AudioVolumes) PortAmbientSounds(IMEPackage sourcePackage, IMEPackage destPackage, VegasAudioModel model, ECLevelInfo info, string logCategory)
    {
        var cuesByPath = model.Cues.ToDictionary(x => x.SourcePath, StringComparer.OrdinalIgnoreCase);

        // BioAudioVolume continuously positions its sounds relative to the listener while they are inside the brush;
        // its AmbientSound children must therefore not also be emitted as ordinary point-source actors.
        var volumeOwnedSounds = new HashSet<int>();
        var sourceVolumes = sourcePackage.Exports.Where(x => x.ClassName == "BioAudioVolume").ToList();
        foreach (var volume in sourceVolumes)
        {
            var sounds = volume.GetProperty<ArrayProperty<ObjectProperty>>("AmbientSoundArray");
            if (sounds == null) continue;
            foreach (var entry in sounds)
            {
                volumeOwnedSounds.Add(entry.Value);
            }
        }

        var created = 0;
        var createdVolumes = 0;
        var destLevel = destPackage.FindExport("TheWorld.PersistentLevel");
        if (destLevel == null)
        {
            MilanLog.Error($"{destPackage.FileNameNoExtension} has no PersistentLevel - cannot add ambient sounds", customPrefix: logCategory);
            return (0, 0);
        }

        foreach (var sourceVolume in sourceVolumes)
        {
            var sourceSounds = sourceVolume.GetProperty<ArrayProperty<ObjectProperty>>("AmbientSoundArray");
            var eventPairs = new List<(IEntry Play, IEntry Stop, string CueName)>();

            if (sourceSounds != null)
            {
                foreach (var soundRef in sourceSounds)
                {
                    if (!sourcePackage.TryGetUExport(soundRef.Value, out var ambientSound))
                    {
                        MilanLog.Warning($"  {sourceVolume.InstancedFullPath} contains an invalid AmbientSound reference {soundRef.Value}", customPrefix: logCategory);
                        continue;
                    }

                    var cue = ResolveCue(ambientSound, cuesByPath, logCategory);
                    if (cue == null) continue;
                    var actorVolume = VegasAudioScanner.GetAmbientVolumeMultiplier(ambientSound);
                    eventPairs.Add((ResolveEvent(destPackage, cue.PlayEventNameForVolume(actorVolume)), ResolveEvent(destPackage, cue.StopEventName), cue.WwiseName));
                }
            }

            if (eventPairs.Count == 0)
            {
                MilanLog.Warning($"  {sourceVolume.InstancedFullPath} has no resolvable ambient events - skipping volume", customPrefix: logCategory);
                continue;
            }

            ConvertBioAudioVolume(sourceVolume);
            var newVolume = CrossGenVShared.PortCrossgenActor(info, sourceVolume, destPackage);
            if (newVolume == null)
            {
                MilanLog.Error($"  Failed to port converted audio volume {sourceVolume.InstancedFullPath}", customPrefix: logCategory);
                continue;
            }

            var wwiseEvents = new ArrayProperty<StructProperty>(eventPairs.Select(x =>
                new StructProperty("WwiseEventPair", new PropertyCollection
                {
                    new ObjectProperty(x.Play, "Play"),
                    new ObjectProperty(x.Stop, "Stop"),
                })), "WwiseEventArray");
            newVolume.WriteProperty(wwiseEvents);
            newVolume.WriteProperty(new NameProperty(newVolume.ObjectName, "UniqueTag"));
            destPackage.AddToLevelActorsIfNotThere(newVolume);
            createdVolumes++;
            MilanLog.Information($"  Audio volume {sourceVolume.ObjectName} -> {newVolume.ObjectName} playing {string.Join(", ", eventPairs.Select(x => x.CueName))}", customPrefix: logCategory);
        }

        foreach (var ambientSound in sourcePackage.Exports.Where(x => x.ClassName == "AmbientSound").ToList())
        {
            if (volumeOwnedSounds.Contains(ambientSound.UIndex)) continue;

            var cue = ResolveCue(ambientSound, cuesByPath, logCategory);
            if (cue == null) continue;

            var actorVolume = VegasAudioScanner.GetAmbientVolumeMultiplier(ambientSound);
            var playEventName = cue.PlayEventNameForVolume(actorVolume);
            var playEvent = ResolveEvent(destPackage, playEventName);
            var stopEvent = ResolveEvent(destPackage, cue.StopEventName);

            var newActor = ExportCreator.CreateExport(destPackage, "WwiseAmbientSound", "WwiseAmbientSound", destLevel, indexed: true);

            var props = new PropertyCollection
            {
                new StructProperty("WwiseEventPair", new PropertyCollection
                {
                    new ObjectProperty(playEvent, "Play"),
                    new ObjectProperty(stopEvent, "Stop"),
                }, "AudioEvent"),
            };

            // bAutoPlay defaults to true on WwiseAmbientSound, which is what every one of these was doing in LE1 -
            // only write it when the source explicitly turned it off.
            var autoPlay = ambientSound.GetProperty<BoolProperty>("bAutoPlay");
            if (autoPlay is { Value: false }) props.Add(new BoolProperty(false, "bAutoPlay"));

            if (ambientSound.GetProperty<StructProperty>("location") is { } location) props.Add(location);
            if (ambientSound.GetProperty<NameProperty>("Tag") is { } tag) props.Add(tag);
            props.Add(new NameProperty(newActor.ObjectName, "UniqueTag"));

            newActor.WriteProperties(props);
            destPackage.AddToLevelActorsIfNotThere(newActor);
            created++;

            MilanLog.Information($"  Ambient sound {ambientSound.ObjectName} -> {newActor.ObjectName} playing {playEventName} (gain {actorVolume:0.###})", customPrefix: logCategory);
        }

        return (created, createdVolumes);
    }

    /// <summary>
    /// Changes the LE1 actor to the class LE3 expects. The event
    /// array is deliberately written after porting: it is an LE3-only array of structs and we can't deserialize it until the game ID changes.
    /// </summary>
    private static void ConvertBioAudioVolume(ExportEntry volume)
    {
        var package = volume.FileRef;
        var properties = volume.GetProperties();
        var binary = volume.GetBinaryData();

        properties.RemoveNamedProperty("AmbientSoundArray");
        properties.RemoveNamedProperty("aConvexElems");
        properties.RemoveNamedProperty("aBoxElems");
        properties.RemoveNamedProperty("m_oTrackPawn");
        properties.RemoveNamedProperty("m_oTrackTimer");
        properties.RemoveNamedProperty("bPawnIsInsideVolume");

        var wwiseVolumeClass = package.GetEntryOrAddImport("WwiseAudio.WwiseAudioVolume", "Class", "WwiseAudio");
        var wwiseVolumeDefault = package.GetEntryOrAddImport("WwiseAudio.Default__WwiseAudioVolume", "WwiseAudioVolume", "WwiseAudio");
        var wwiseBrushDefault = package.GetEntryOrAddImport("WwiseAudio.Default__WwiseAudioVolume.BrushComponent0", "BrushComponent", "WwiseAudio");

        // The instanced BrushComponent is an export dependency of the volume. Pointing its archetype at the LE3
        // class default keeps the relinker from trying to resolve Default__BioAudioVolume in the destination game.
        var brushComponent = properties.GetProp<ObjectProperty>("BrushComponent");
        if (brushComponent != null && package.TryGetUExport(brushComponent.Value, out var component))
        {
            component.Archetype = wwiseBrushDefault;
        }

        volume.Class = wwiseVolumeClass;
        volume.Archetype = wwiseVolumeDefault;
        volume.ObjectName = package.GetNextIndexedName("WwiseAudioVolume");

        if (volume.HasStack)
        {
            var stack = new PrePropStack(volume)
            {
                Node = wwiseVolumeClass,
                StateNode = wwiseVolumeClass,
            };
            volume.WritePrePropsAndPropertiesAndBinary(stack.GeneratePreProps(), properties, binary);
        }
        else
        {
            volume.WriteProperties(properties);
        }
    }

    /// <summary>
    /// Walks AmbientSound -> AudioComponent -> SoundCue and looks the cue up in the scan the bank was built from.
    /// </summary>
    internal static VegasCue ResolveCue(ExportEntry ambientSound, Dictionary<string, VegasCue> cuesByPath, string logCategory)
    {
        var componentRef = ambientSound.GetProperty<ObjectProperty>("AudioComponent");
        if (componentRef == null || !ambientSound.FileRef.TryGetUExport(componentRef.Value, out var component))
        {
            MilanLog.Warning($"  {ambientSound.InstancedFullPath} has no AudioComponent - skipping", customPrefix: logCategory);
            return null;
        }

        var cueRef = component.GetProperty<ObjectProperty>("SoundCue");
        if (cueRef == null || !ambientSound.FileRef.TryGetUExport(cueRef.Value, out var cueExport))
        {
            MilanLog.Warning($"  {ambientSound.InstancedFullPath} has an AudioComponent with no SoundCue - skipping", customPrefix: logCategory);
            return null;
        }

        if (!cuesByPath.TryGetValue(cueExport.InstancedFullPath, out var cue))
        {
            MilanLog.Warning($"  {ambientSound.InstancedFullPath} plays {cueExport.InstancedFullPath}, which is not in the {VegasAudioPipeline.BankName} bank - skipping", customPrefix: logCategory);
            return null;
        }

        return cue;
    }

    /// <summary>
    /// Resolves one of the WwiseEvent exports embedded in the destination level before actor generation begins.
    /// Runtime imports to the intermediate BioSnd_Vegas package are intentionally forbidden.
    /// </summary>
    private static IEntry ResolveEvent(IMEPackage destPackage, string eventName)
    {
        return destPackage.FindExport($"{VegasAudioPipeline.BankName}.{eventName}", "WwiseEvent")
               ?? throw new InvalidOperationException(
                   $"Embedded event {VegasAudioPipeline.BankName}.{eventName} is missing from {destPackage.FileNameNoExtension}.");
    }
}
