using System.Collections.Concurrent;
using System.Diagnostics;
using System.IO.Compression;
using System.Text;
using LegendaryExplorerCore.Audio;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using ProjectMilan;
using ProjectMilanCore;
using ProjectMilan_ExtraContent.Shared;
using LegendaryExplorerCore.Unreal.ObjectInfo;

namespace ProjectMilan_ExtraContent.Redemption.Levels.CrossGenV.Audio;

/// <summary>
/// Builds the Wwise_Vegas sound bank from Pinnacle Station's LE1 ISACT audio and gets it into LE3.
/// <para/>
/// LE1 uses ISACT (icb/isb banks reached through SoundCue -> SoundNodeWave); LE3 uses Wwise, so nothing ports
/// directly. What does carry over is the content: every ISACT sample in the Vegas DLC is already plain Ogg Vorbis,
/// and the cue graphs only ever express "play this (or one of these), attenuated by distance" - which is a
/// straightforward Wwise authoring problem.
/// </summary>
internal static class VegasAudioPipeline
{
    public const string LOG_CATEGORY = @"MILANEC-PSAUDIO";

    /// <summary>
    /// Name of the generated bank. This is also the name LEC's bank importer gives the WwiseBank export and the AFC
    /// it writes streamed audio into, so it wants to read like any other LE3 bank name.
    /// </summary>
    public const string BankName = "Wwise_Vegas";

    /// <summary>
    /// The LE1 sound packages the port draws from - every _SND file in the Vegas DLC. The five maps being ported
    /// use CCTHAI/CCCAVE/CCCRATE/CCLAVA/CCAHERN; the rest are the station hub, built into the same bank so hub
    /// ambience is available if those levels are ever ported too.
    /// </summary>
    public static readonly string[] SourcePackages =
    [
        "BIOA_PRC2AA_00_SND.pcc",
        "BIOA_PRC2_CCAHERN_SND.pcc",
        "BIOA_PRC2_CCCAVE_SND.pcc",
        "BIOA_PRC2_CCCRATE_SND.pcc",
        "BIOA_PRC2_CCLAVA_SND.pcc",
        "BIOA_PRC2_CCLOBBY_SND.pcc",
        "BIOA_PRC2_CCMAIN_SND.pcc",
        "BIOA_PRC2_CCMID_SND.pcc",
        "BIOA_PRC2_CCSIM_SND.pcc",
        "BIOA_PRC2_CCTHAI_SND.pcc",
    ];

    /// <summary>
    /// The template Wwise project, which defines the LE3 bus hierarchy and the "Milan Max Quality" conversion preset.
    /// Its hierarchy/attenuation/event/bank work units are empty stubs for us to fill in.
    /// </summary>
    private const string TemplateProjectFileName = "LE3TemplateProject.wproj";

    /// <summary>
    /// Builds the Wwise project from the LE1 source audio and runs WwiseCLI over it, leaving a generated bank behind.
    /// Returns the folder holding <c>{BankName}.bnk</c>, <c>SoundbanksInfo.xml</c> and the streamed .wem files -
    /// exactly the input LegendaryExplorerCore's bank importer expects.
    /// </summary>
    public static string BuildBank(string workDir, out VegasAudioModel model)
    {
        model = VegasAudioScanner.Scan(CrossGenVShared.SourceFilesFolder, SourcePackages);
        MilanLog.Information($"Scanned {model.Cues.Count} cue(s) and {model.Samples.Count} unique sample(s) from Pinnacle Station's LE1 audio", customPrefix: LOG_CATEGORY);

        var projectRoot = PrepareProject(workDir);
        ExtractSourceAudio(model, projectRoot);
        WwiseProjectWriter.Write(model, projectRoot, BankName);

        GenerateSoundBanks(Path.Combine(projectRoot, TemplateProjectFileName));

        var outputDir = Path.Combine(projectRoot, "GeneratedSoundBanks", "Windows");
        var bankPath = Path.Combine(outputDir, $"{BankName}.bnk");
        if (!File.Exists(bankPath))
        {
            throw new InvalidOperationException($"WwiseCLI reported success but produced no bank at {bankPath}");
        }

        MilanLog.Information($"Generated {BankName}.bnk ({new FileInfo(bankPath).Length / 1024} KB) in {outputDir}", customPrefix: LOG_CATEGORY);
        return outputDir;
    }

    /// <summary>
    /// Name of the intermediate LE3 package the generated bank, its events and its streamed audio are imported into.
    /// Its Wwise_Vegas export tree is subsequently embedded into each destination BioD package. The AFC remains
    /// shared even though the bank and object exports are local to every level.
    /// </summary>
    public const string SoundPackageName = "BioSnd_Vegas";

    /// <summary>
    /// Path to the intermediate package produced by the current build. Level generation uses this exact file rather
    /// than resolving BioSnd_Vegas as a runtime dependency; BioSnd_Vegas is an asset-staging package, not something
    /// the generated BioD files are allowed to import.
    /// </summary>
    public static string SharedPackagePath { get; private set; }

    /// <summary>
    /// The scan the most recent <see cref="BuildAndImport"/> built its bank from. The level builds need it to map an
    /// LE1 cue back to the Wwise event that replaced it, and it must describe the bank that actually shipped - so it
    /// is whatever the build produced, not a fresh scan.
    /// </summary>
    public static VegasAudioModel SharedModel { get; private set; }

    /// <summary>
    /// Builds the bank and imports it into <see cref="SoundPackageName"/> in the DLC's CookedPCConsole folder,
    /// writing <c>{BankName}.afc</c> alongside it. Returns the path to the package.
    /// </summary>
    public static string BuildAndImport(string workDir, string cookedPcConsolePath)
    {
        var generatedDir = BuildBank(workDir, out var model);
        SharedModel = model;

        Directory.CreateDirectory(cookedPcConsolePath);
        var packagePath = Path.Combine(cookedPcConsolePath, "Levels", "Shared", $"{SoundPackageName}.pcc");
        var afcPath = Path.Combine(cookedPcConsolePath, "Audio", $"{BankName}.afc");
        Directory.GetParent(afcPath).Create();
        Directory.GetParent(packagePath).Create();


        var importedAfcPath = Path.Combine(Directory.GetParent(packagePath).FullName, $"{BankName}.afc");

        // Clear old package and AFC path
        if (File.Exists(packagePath)) File.Delete(packagePath);
        if (File.Exists(importedAfcPath)) File.Delete(importedAfcPath);
        if (File.Exists(afcPath)) File.Delete(afcPath);

        MEPackageHandler.CreateAndSavePackage(packagePath, MEGame.LE3);
        using var package = MEPackageHandler.OpenMEPackage(packagePath);

        var error = WwiseBankImport.ImportBank(Path.Combine(generatedDir, $"{BankName}.bnk"), useWwiseObjectNames: false, package);
        if (error != null)
        {
            throw new InvalidOperationException($"Failed to import {BankName}.bnk into {SoundPackageName}: {error}");
        }

        package.Save();
        File.Move(importedAfcPath, afcPath);
        SharedPackagePath = packagePath;
        MilanLog.Information($"Imported {BankName} into {packagePath} ({package.ExportCount} exports, AFC {new FileInfo(afcPath).Length / 1024 / 1024} MB)", customPrefix: LOG_CATEGORY);
        return packagePath;
    }

    /// <summary>
    /// Embeds the complete Wwise_Vegas export tree into one destination level. The package export owns the WwiseBank,
    /// every Play/Stop WwiseEvent and every WwiseStream, so cloning it (rather than the bank child alone) gives actor
    /// properties local event exports and lets the relinker repair the events' bank/stream references in one pass.
    /// </summary>
    public static void EmbedBankIntoLevel(IMEPackage destPackage, PackageCache cache, string logCategory)
    {
        if (destPackage.FindExport(BankName, "Package") != null)
        {
            return;
        }

        if (string.IsNullOrEmpty(SharedPackagePath) || !File.Exists(SharedPackagePath))
        {
            throw new InvalidOperationException($"The intermediate {SoundPackageName} package has not been generated; cannot embed {BankName} into {destPackage.FileNameNoExtension}.");
        }

        using var sourcePackage = MEPackageHandler.OpenMEPackage(SharedPackagePath);
        var sourceRoot = sourcePackage.FindExport(BankName, "Package")
                         ?? throw new InvalidOperationException($"{SharedPackagePath} does not contain the expected {BankName} package export.");

        using var relinkerOptions = new RelinkerOptionsPackage
        {
            Cache = cache,
            ImportExportDependencies = true,
            ImportChildrenOfPackages = true,
            // This must remain false. If enabled, the root package can resolve back to BioSnd_Vegas and becomes the
            // very runtime import this embedding step is intended to eliminate.
            PortExportsAsImportsWhenPossible = false,
            PortImportsMemorySafe = true,
            DestinationCustomImportFileResolver = MilanShared.LE3PackageResolver,
            SourceCustomImportFileResolver = MilanShared.LE3PackageResolver,
        };

        var issues = EntryImporter.ImportAndRelinkEntries(
            EntryImporter.PortingOption.CloneAllDependencies,
            sourceRoot,
            destPackage,
            null,
            true,
            relinkerOptions,
            out var embeddedRoot);

        if (embeddedRoot is not ExportEntry || destPackage.FindExport($"{BankName}.{BankName}", "WwiseBank") == null)
        {
            throw new InvalidOperationException($"Failed to embed the {BankName} export tree into {destPackage.FileNameNoExtension}.");
        }

        var sourceCounts = CountAudioChildren(sourcePackage);
        var destCounts = CountAudioChildren(destPackage);
        if (sourceCounts != destCounts)
        {
            throw new InvalidOperationException(
                $"Incomplete {BankName} embed in {destPackage.FileNameNoExtension}: expected {sourceCounts}, got {destCounts}.");
        }

        foreach (var issue in issues)
        {
            MilanLog.Warning($"  {BankName} embed relinker: {issue}", customPrefix: logCategory);
        }

        MilanLog.Information($"  Embedded {BankName} ({destCounts}) into {destPackage.FileNameNoExtension}", customPrefix: logCategory);

        static (int Banks, int Events, int Streams) CountAudioChildren(IMEPackage package)
        {
            var root = package.FindExport(BankName, "Package");
            if (root == null) return (0, 0, 0);
            var children = root.GetAllDescendants().OfType<ExportEntry>().ToList();
            return (
                children.Count(x => x.ClassName == "WwiseBank"),
                children.Count(x => x.ClassName == "WwiseEvent"),
                children.Count(x => x.ClassName == "WwiseStream"));
        }
    }

    /// <summary>
    /// Audits the completed BioD packages after every CrossGenV level has been built. Any Wwise_Vegas import is a
    /// hard error because the bank/events/streams must be local exports. Other unresolved imports are reported for
    /// visibility without changing the existing CrossGenV build policy for unrelated legacy references.
    /// </summary>
    public static void ValidateBuiltLevelImports(IEnumerable<string> packagePaths, PackageCache cache)
    {
        var paths = packagePaths.Where(File.Exists).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
        if (paths.Count == 0) return;

        MilanShared.RefreshMilanFiles = true;
        var allLocalPackages = Directory.GetFiles(MilanPipelinesShared.OutputModPath, "*.pcc", SearchOption.AllDirectories);
        var unresolvedCount = 0;

        foreach (var path in paths)
        {
            using var package = MEPackageHandler.OpenMEPackage(path, forceLoadFromDisk: true);

            var illegalAudioImports = package.Imports.Where(x =>
                x.InstancedFullPath.StartsWith(BankName, StringComparison.OrdinalIgnoreCase) ||
                string.Equals(x.PackageFile, SoundPackageName, StringComparison.OrdinalIgnoreCase)).ToList();
            if (illegalAudioImports.Count > 0)
            {
                throw new InvalidOperationException(
                    $"{package.FileNameNoExtension} still contains runtime imports to the staged {BankName} audio: " +
                    string.Join(", ", illegalAudioImports.Select(x => x.InstancedFullPath)));
            }

            foreach (var import in package.Imports)
            {
                // LE3 and LMP are interchangable here, we use LE3 as we don't licensee until the end.
                if (GlobalUnrealObjectInfo.IsAKnownNativeClass(import.InstancedFullPath, MEGame.LE3)) continue;
                var resolved = EntryImporter.ResolveImport(
                    import,
                    cache,
                    unsafeLoad: true,
                    localDirFiles: allLocalPackages,
                    fileResolver: MilanShared.LE3PackageResolver);
                if (resolved != null) continue;

                unresolvedCount++;
                MilanLog.Warning(
                    $"  Unresolved import after CrossGenV build: {package.FileNameNoExtension} -> {import.InstancedFullPath} ({import.ClassName})",
                    customPrefix: LOG_CATEGORY);
            }

            var root = package.FindExport(BankName, "Package");
            var bank = package.FindExport($"{BankName}.{BankName}", "WwiseBank");
            if (root == null || bank == null)
            {
                throw new InvalidOperationException($"{package.FileNameNoExtension} does not contain its embedded {BankName} bank.");
            }
        }

        MilanLog.Information(
            $"Validated embedded {BankName} exports in {paths.Count} BioD package(s); found {unresolvedCount} unrelated unresolved import(s).",
            customPrefix: LOG_CATEGORY);
    }

    /// <summary>
    /// Lays down a clean copy of the template project. Always from scratch: a stale Actor-Mixer work unit left over
    /// from a previous run would keep contributing objects to the bank that nothing references any more.
    /// </summary>
    private static string PrepareProject(string workDir)
    {
        var projectRoot = Path.Combine(workDir, "WwiseProject");
        if (Directory.Exists(projectRoot)) Directory.Delete(projectRoot, true);
        Directory.CreateDirectory(projectRoot);

        ZipFile.ExtractToDirectory(FindTemplateProjectZip(), projectRoot);
        return projectRoot;
    }

    /// <summary>
    /// Locates the shared Wwise template project in the source tree. Deliberately walks up from the running assembly
    /// rather than using MilanShared.PipelineRoot or SharedECPipelines.ECPipelineRoot - both of those walk up from the
    /// *current directory*, which only lands on the right folder when the build is launched from inside its own
    /// project, and this needs to work however it is invoked.
    /// </summary>
    private static string FindTemplateProjectZip()
    {
        var relative = Path.Combine("ProjectMilan", "Pipelines", "Audio", "Template", "TemplateProject.zip");
        for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir != null; dir = dir.Parent)
        {
            var candidate = Path.Combine(dir.FullName, relative);
            if (File.Exists(candidate)) return candidate;
        }

        throw new FileNotFoundException($"Could not find {relative} in any parent of {AppContext.BaseDirectory}");
    }

    /// <summary>
    /// Writes every sample out as a .wav under Originals/SFX, which is where the generated work units point.
    /// <para/>
    /// The ISACT payload is already a complete Ogg Vorbis stream, so this is a straight carve-out plus an ffmpeg
    /// decode - no ISACT codec work, and no quality loss beyond the single Vorbis generation LE1 shipped. Wwise then
    /// re-encodes the .wav through the "Milan Max Quality" preset.
    /// </summary>
    private static void ExtractSourceAudio(VegasAudioModel model, string projectRoot)
    {
        var originals = Path.Combine(projectRoot, "Originals", "SFX");
        Directory.CreateDirectory(originals);
        var oggDir = Path.Combine(projectRoot, "Originals", "_isact_ogg");
        Directory.CreateDirectory(oggDir);

        var failures = new ConcurrentBag<string>();
        Parallel.ForEach(model.Samples.Values, sample =>
        {
            var oggPath = Path.Combine(oggDir, $"{sample.WwiseName}.ogg");
            var wavPath = Path.Combine(originals, $"{sample.WwiseName}.wav");
            File.WriteAllBytes(oggPath, sample.OggData);

            var result = RunProcess(FfmpegPath, $"-y -loglevel error -i \"{oggPath}\" \"{wavPath}\"");
            if (result.ExitCode != 0 || !File.Exists(wavPath))
            {
                failures.Add($"{sample.IsactName}: {result.Output.Trim()}");
            }
        });

        if (!failures.IsEmpty)
        {
            throw new InvalidOperationException($"{failures.Count} sample(s) failed to decode from Ogg Vorbis to WAV: {string.Join("; ", failures.Take(5))}");
        }

        // Only the .wav files are project sources; the carved Oggs were just an ffmpeg input.
        Directory.Delete(oggDir, true);
        MilanLog.Information($"Decoded {model.Samples.Count} ISACT sample(s) to WAV in {originals}", customPrefix: LOG_CATEGORY);
    }

    private static void GenerateSoundBanks(string projectPath)
    {
        var cli = WwiseCliPath;
        if (!File.Exists(cli))
        {
            throw new InvalidOperationException($"WwiseCLI not found at '{cli}'. The Pinnacle Station audio port needs Wwise 2019.1.6.7110 installed with WWISEROOT set.");
        }

        MilanLog.Information("Running WwiseCLI -GenerateSoundBanks (this takes a while - it re-encodes every sample)", customPrefix: LOG_CATEGORY);
        var result = RunProcess(cli, $"\"{projectPath}\" -GenerateSoundBanks -Platform Windows");

        // WwiseCLI reports project-load problems as warnings on stdout and still exits 0, and some of them silently
        // change the output (an attenuation curve that gets rescaled, for instance), so they are worth surfacing.
        foreach (var line in result.Output.Split('\n').Where(x => x.Contains("Warning", StringComparison.OrdinalIgnoreCase) || x.Contains("Error", StringComparison.OrdinalIgnoreCase)))
        {
            MilanLog.Warning($"WwiseCLI: {line.Trim()}", customPrefix: LOG_CATEGORY);
        }

        if (result.ExitCode != 0)
        {
            throw new InvalidOperationException($"WwiseCLI -GenerateSoundBanks failed (exit {result.ExitCode}): {result.Output[^Math.Min(2000, result.Output.Length)..]}");
        }
    }

    private static string WwiseCliPath
    {
        get
        {
            var root = Environment.GetEnvironmentVariable("WWISEROOT") ?? "";
            return Path.Combine(root, "Authoring", "x64", "Release", "bin", "WwiseCLI.exe");
        }
    }

    /// <summary>ffmpeg, expected on PATH - the same assumption the main audio pipeline's WEM re-encoder makes.</summary>
    private static string FfmpegPath => "ffmpeg";

    private readonly record struct ProcessResult(int ExitCode, string Output);

    private static ProcessResult RunProcess(string fileName, string arguments)
    {
        var psi = new ProcessStartInfo
        {
            FileName = fileName,
            Arguments = arguments,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
        };

        var output = new StringBuilder();
        using var process = Process.Start(psi) ?? throw new InvalidOperationException($"Failed to start '{fileName}'");
        process.OutputDataReceived += (_, e) => Append(e.Data);
        process.ErrorDataReceived += (_, e) => Append(e.Data);
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
        process.WaitForExit();

        return new ProcessResult(process.ExitCode, output.ToString());

        void Append(string line)
        {
            if (line == null) return;
            lock (output) output.AppendLine(line);
        }
    }

    /// <summary>
    /// Scans the LE1 source audio and writes a human-readable report of everything the port would produce, without
    /// touching Wwise or writing any content. Useful for eyeballing the streaming split and the attenuation values
    /// before committing to a build.
    /// </summary>
    public static void WriteScanReport(string outputPath)
    {
        var model = VegasAudioScanner.Scan(CrossGenVShared.SourceFilesFolder, SourcePackages);

        var sb = new StringBuilder();
        sb.AppendLine($"# {BankName} source audio scan");
        sb.AppendLine();

        var streamedCues = model.Cues.Count(x => x.Streams);
        var streamedSamples = model.Samples.Values.Where(x => x.ShouldStream).ToList();
        var embeddedSamples = model.Samples.Values.Where(x => !x.ShouldStream).ToList();
        sb.AppendLine($"- {model.Cues.Count} cue(s), {streamedCues} streamed / {model.Cues.Count - streamedCues} embedded");
        sb.AppendLine($"- {model.Samples.Count} unique sample(s), {Total(model.Samples.Values) / 1024} KB total");
        sb.AppendLine($"- {streamedSamples.Count} streamed ({Total(streamedSamples) / 1024} KB to the AFC), {embeddedSamples.Count} embedded ({Total(embeddedSamples) / 1024} KB in the bank)");
        sb.AppendLine();

        sb.AppendLine("## Cues");
        sb.AppendLine();
        sb.AppendLine("| Wwise name | LE1 cue | Vars | Radius (m) | ISACT max attenuation | Cue vol | Actor vols | Loop | Stream | Packages |");
        sb.AppendLine("|---|---|---|---|---|---|---|---|---|---|");
        foreach (var cue in model.Cues.OrderBy(x => x.WwiseName, StringComparer.OrdinalIgnoreCase))
        {
            var radius = cue is { MinRadius: { } min, MaxRadius: { } max } ? $"{min:0.##} - {max:0.##}" : "none";
            var actorVolumes = string.Join(", ", cue.ActorVolumeMultipliers.Order().Select(x => x.ToString("0.###")));
            sb.AppendLine($"| {cue.WwiseName} | {cue.SourcePath} | {cue.Variations.Count} | {radius} | {(cue.IsAttenuated ? $"{cue.MaxDistanceLevelDb:0.###} dB" : "none")} | {cue.VolumeMultiplier:0.###} | {actorVolumes} | {(cue.IsLooping ? "yes" : "")} | {(cue.Streams ? "yes" : "")} | {cue.SourcePackages.Count} |");
        }

        sb.AppendLine();
        sb.AppendLine("## Samples");
        sb.AppendLine();
        sb.AppendLine("| Wwise name | ISACT name | Length | Size | Ch | Rate | ISACT dist | Stream |");
        sb.AppendLine("|---|---|---|---|---|---|---|---|");
        foreach (var sample in model.Samples.Values.OrderByDescending(x => x.Duration))
        {
            var dist = sample.Distance is { } d ? $"{d.MinDistance:0.##} - {d.MaxDistance:0.##} @ {d.MaxDistanceLevel:0.#}dB" : "not 3D";
            sb.AppendLine($"| {sample.WwiseName} | {sample.IsactName} | {sample.Duration.TotalSeconds:0.00}s | {sample.OggData.Length / 1024} KB | {sample.Channels} | {sample.SampleRate} | {dist} | {(sample.ShouldStream ? "yes" : "")} |");
        }

        sb.AppendLine();
        sb.AppendLine("## Variations (cues with more than one)");
        sb.AppendLine();
        sb.AppendLine("| Cue | Sample | Weight | Gain | Pitch |");
        sb.AppendLine("|---|---|---|---|---|");
        foreach (var cue in model.Cues.Where(x => x.IsContainer).OrderBy(x => x.WwiseName, StringComparer.OrdinalIgnoreCase))
        {
            foreach (var v in cue.Variations)
            {
                sb.AppendLine($"| {cue.WwiseName} | {v.Sample.WwiseName} | {v.Weight:0.#} | {v.MinGain:0.###} - {v.MaxGain:0.###} | {v.MinPitch:0.###} - {v.MaxPitch:0.###} |");
            }
        }

        sb.AppendLine();
        sb.AppendLine("## Ambient sound actors");
        sb.AppendLine();
        sb.AppendLine("Every LE1 AmbientSound in the sound levels, and the event its ported Wwise actor or volume will play.");
        sb.AppendLine("A volume-owned sound is placed in its converted WwiseAudioVolume rather than emitted as a point source.");
        sb.AppendLine();
        sb.AppendLine("| Sound level | Actor | Plays | Volume-owned |");
        sb.AppendLine("|---|---|---|---|");
        var cuesByPath = model.Cues.ToDictionary(x => x.SourcePath, StringComparer.OrdinalIgnoreCase);
        foreach (var packageName in SourcePackages)
        {
            var path = Path.Combine(CrossGenVShared.SourceFilesFolder, packageName);
            if (!File.Exists(path)) continue;

            using var package = MEPackageHandler.OpenMEPackage(path);
            var volumeOwned = new HashSet<int>();
            foreach (var volume in package.Exports.Where(x => x.ClassName == "BioAudioVolume"))
            {
                var gatedSounds = volume.GetProperty<ArrayProperty<ObjectProperty>>("AmbientSoundArray");
                if (gatedSounds == null) continue;
                foreach (var entry in gatedSounds)
                {
                    volumeOwned.Add(entry.Value);
                }
            }

            foreach (var ambient in package.Exports.Where(x => x.ClassName == "AmbientSound"))
            {
                var cue = VegasAudioActors.ResolveCue(ambient, cuesByPath, LOG_CATEGORY);
                var actorVolume = VegasAudioScanner.GetAmbientVolumeMultiplier(ambient);
                sb.AppendLine($"| {Path.GetFileNameWithoutExtension(packageName)} | {ambient.ObjectName} | {(cue == null ? "**UNRESOLVED**" : cue.PlayEventNameForVolume(actorVolume))} | {(volumeOwned.Contains(ambient.UIndex) ? "yes" : "")} |");
            }
        }

        Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);
        File.WriteAllText(outputPath, sb.ToString());
        MilanLog.Information($"Wrote {BankName} scan report to {outputPath}", customPrefix: LOG_CATEGORY);
        return;

        static long Total(IEnumerable<VegasSample> samples) => samples.Sum(x => (long)x.OggData.Length);
    }
}
