using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Text.Json;
using JDiffCS;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using ME3TweaksCore.Helpers;
using ProjectMilan.Utility;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Mod.BaseDelta
{
    public static class BaseDeltaHandler
    {
        /// <summary>
        /// Whether package-based targets (SFXGame, etc.) should save uncompressed before diffing/caching.
        /// Uncompressed keeps the vanilla/patched byte layout aligned so JDiff produces small, meaningful
        /// diffs; compressed keeps disk/memory smaller but the diff may be much larger. Untested tradeoff -
        /// flip this to compare once the rest of the system works.
        /// </summary>
        internal const bool UseCompressedPackages = false;

        private const double MANIFEST_VERSION = 0.1;
        private const string MANIFEST_FILENAME = "manifest.json";

        /// <summary>
        /// Subfolder (sibling of the mod's output DLC folder) that the manifest and .jsf patches ship in.
        /// Unlike Checkpoint.DeltaFolder (a dev-only cache), this is real mod content - a modder can edit
        /// the .jsf files here directly to test tweaks without touching the checkpoint.
        /// </summary>
        internal static string MilanDeltaFolder => Path.Combine(Program.Settings.OutputModPath, "..", "MilanDelta");

        /// <summary>
        /// List of patch classes we are using for transformating.
        /// </summary>
        private static readonly IBasePatchClass[] targets = [
            new SFXGame()
        ];

        private static bool restoringFromCheckpoint;
        private static bool writeDebugDelta;

        private sealed class DeltaRecord
        {
            public string GameFile;
            public string Comment;
            public byte[] JsfBytes;
            public long SourceSize;
            public string SourceHash;
            public long DestSize;
            public string DestHash;
        }

        private static readonly List<DeltaRecord> deltaRecords = new();

        /// <summary>
        /// Prepares for a fresh (non-restored) build: registers this class as the source of patched
        /// vanilla LE3 files, then forces the global package cache to build now (so a compile failure
        /// surfaces immediately, before the rest of the pipeline runs), then builds any non-package
        /// targets (which have no cache/order dependency, so they're just built directly).
        /// </summary>
        /// <param name="creatingCheckpoint">
        /// True if a checkpoint is being created this run. In DEBUG builds, each target's transformed
        /// bytes are also written to <see cref="Checkpoint.DebugDeltaFolder"/> as they're built, for
        /// manual inspection (e.g. in PackageEditor).
        /// </param>
        internal static void PrepareForFreshBuild(bool creatingCheckpoint)
        {
            restoringFromCheckpoint = false;
            writeDebugDelta = creatingCheckpoint;
            deltaRecords.Clear();
            RegisterProviderAndBuildCache();
            BuildNonPackageTargets();
        }

        /// <summary>
        /// Same as <see cref="PrepareForFreshBuild"/>, but reconstructs .pcc targets from their
        /// checkpointed .jsf patch instead of rebuilding them from source.
        /// </summary>
        internal static void PrepareForCheckpointRestore()
        {
            restoringFromCheckpoint = true;
            writeDebugDelta = false;
            deltaRecords.Clear();
            RegisterProviderAndBuildCache();
            BuildNonPackageTargets();
        }

        private static void RegisterProviderAndBuildCache()
        {
            MilanLog.Information("Preparing BaseDelta patch targets...");
            MilanShared.LE3PatchedPackageProvider = ResolvePatchedPackage;
            // Force the cache to build now (rather than lazily, whenever something first asks for an
            // LE3 package) so BaseDelta targets are ready before anything downstream might need them.
            MilanShared.GetLE3GlobalPackages();
        }

        /// <summary>
        /// Called by MilanShared while it builds the LE3 global package cache, once per vanilla "safe to
        /// import from" filename, in that enumeration's own order. This is what lets a patch target
        /// correctly resolve donors from an earlier, already-patched target as the cache builds itself,
        /// instead of every target seeing vanilla until an after-the-fact overwrite. Returns null for
        /// anything that isn't one of our .pcc targets, so the caller falls back to loading vanilla.
        /// </summary>
        private static IMEPackage ResolvePatchedPackage(string gameFile)
        {
            var target = FindTarget(gameFile);
            if (target == null || !IsPackageTarget(target))
                return null;

            var data = restoringFromCheckpoint ? RestoreFromDelta(target) : BuildAndRecordDelta(target);
            return data == null ? null : MEPackageHandler.OpenMEPackageFromStream(new MemoryStream(data), target.GameFile);
        }

        /// <summary>
        /// Targets that aren't packages (e.g. a future Coalesced.bin target) don't participate in the
        /// package cache, so they have no build-order dependency on it - just build/restore them directly
        /// once the cache above is settled.
        /// </summary>
        private static void BuildNonPackageTargets()
        {
            foreach (var target in targets)
            {
                if (IsPackageTarget(target))
                    continue; // handled via the cache-build hook in ResolvePatchedPackage

                var data = restoringFromCheckpoint ? RestoreFromDelta(target) : BuildAndRecordDelta(target);
                if (data == null)
                    continue;

                // TODO: nothing consumes non-package target output yet (e.g. writing a Coalesced.bin
                // result to its real output path) - wire this up once such a target exists.
            }
        }

        private static IBasePatchClass FindTarget(string gameFile)
        {
            var name = Path.GetFileName(gameFile);
            foreach (var target in targets)
            {
                if (target.GameFile.CaseInsensitiveEquals(name))
                    return target;
            }
            return null;
        }

        private static bool IsPackageTarget(IBasePatchClass target) => Path.GetExtension(target.GameFile).CaseInsensitiveEquals(".pcc");

        /// <summary>
        /// Builds a target fresh from source, diffs vanilla against the result, and records the delta
        /// (for the MilanDelta manifest, written at the end of the run). Also mirrors the .jsf into
        /// Checkpoint.DeltaFolder if a checkpoint folder is configured, for faster future restores.
        /// </summary>
        private static byte[] BuildAndRecordDelta(IBasePatchClass target)
        {
            MilanLog.Information($"Building patches for {target.GameFile}");
            byte[] vanilla, patched;
            try
            {
                vanilla = target.GetVanillaBytes();
                patched = target.BuildPatchTarget();
            }
            catch (Exception ex)
            {
                MilanLog.Error($"Failed to build patch target '{target.GameFile}': {ex}");
                return null;
            }

#if DEBUG
            if (writeDebugDelta && !string.IsNullOrWhiteSpace(Program.Settings.CheckpointFolder))
            {
                WriteDebugDelta(target.GameFile, patched);
            }
#endif

            var jsf = ComputeDelta(target.GameFile, vanilla, patched);
            RecordDelta(target, vanilla, patched, jsf);

            if (!string.IsNullOrWhiteSpace(Program.Settings.CheckpointFolder))
            {
                Directory.CreateDirectory(Checkpoint.DeltaFolder);
                File.WriteAllBytes(Path.Combine(Checkpoint.DeltaFolder, target.GameFile + ".jsf"), jsf);
            }

            return patched;
        }

#if DEBUG
        /// <summary>
        /// Writes the raw transformed bytes for a target to Checkpoint.DebugDeltaFolder as it's built,
        /// so it can be manually inspected (e.g. in PackageEditor). DEBUG-only; not part of the
        /// checkpoint's real contract - nothing restores from this folder.
        /// </summary>
        private static void WriteDebugDelta(string gameFile, byte[] patched)
        {
            Directory.CreateDirectory(Checkpoint.DebugDeltaFolder);
            File.WriteAllBytes(Path.Combine(Checkpoint.DebugDeltaFolder, gameFile), patched);
            MilanLog.Information($"Wrote debug copy of {gameFile} to {Checkpoint.DebugDeltaFolder}");
        }
#endif

        /// <summary>
        /// Reconstructs a target's bytes from its checkpointed .jsf patch via JPatch, instead of
        /// rebuilding it from source, and records the delta (reusing the existing .jsf as-is - the
        /// checkpoint is always the source of truth for restore; MilanDelta's copy is a modder's
        /// editable playground, never read back). Falls back to a fresh build if no checkpointed
        /// patch is found.
        /// </summary>
        private static byte[] RestoreFromDelta(IBasePatchClass target)
        {
            if (string.IsNullOrWhiteSpace(Program.Settings.CheckpointFolder) || !Directory.Exists(Checkpoint.DeltaFolder))
            {
                MilanLog.Warning($"No checkpoint delta available for '{target.GameFile}'; falling back to a fresh build.");
                return BuildAndRecordDelta(target);
            }

            var deltaFile = Path.Combine(Checkpoint.DeltaFolder, target.GameFile + ".jsf");
            if (!File.Exists(deltaFile))
            {
                MilanLog.Warning($"No checkpointed patch found for '{target.GameFile}'; falling back to a fresh build.");
                return BuildAndRecordDelta(target);
            }

            MilanLog.Information($"Restoring {target.GameFile} from checkpointed patch");

            byte[] vanilla;
            try
            {
                vanilla = target.GetVanillaBytes();
            }
            catch (Exception ex)
            {
                MilanLog.Error($"Failed to load vanilla bytes for '{target.GameFile}': {ex}");
                return null;
            }

            var jsf = File.ReadAllBytes(deltaFile);
            using var vanillaStream = new MemoryStream(vanilla);
            using var patchStream = new MemoryStream(jsf);
            using var outStream = new MemoryStream();
            JPatch.ApplyJPatch(vanillaStream, patchStream, outStream);
            var patched = outStream.ToArray();

            RecordDelta(target, vanilla, patched, jsf);
            return patched;
        }

        /// <summary>
        /// Diffs vanilla against patched with JDiff and returns the resulting .jsf bytes.
        /// </summary>
        private static byte[] ComputeDelta(string gameFile, byte[] vanilla, byte[] patched)
        {
            using var vanillaStream = new MemoryStream(vanilla);
            using var patchedStream = new MemoryStream(patched);
            using var deltaStream = new MemoryStream();

            MilanLog.Information($"Diffing {gameFile} against vanilla...");
            var progressTimer = Stopwatch.StartNew();
            var options = JDiffOptions.Default;
            options.ProgressChanged = progress =>
            {
                if (progressTimer.Elapsed.TotalSeconds < 3)
                    return;
                progressTimer.Restart();
                MilanLog.Information($"Diffing {gameFile}: {progress:P0}");
            };

            JDiffLib.Run(vanillaStream, patchedStream, deltaStream, options);
            MilanLog.Information($"Diffing {gameFile} complete");
            return deltaStream.ToArray();
        }

        private static void RecordDelta(IBasePatchClass target, byte[] vanilla, byte[] patched, byte[] jsf)
        {
            deltaRecords.Add(new DeltaRecord
            {
                GameFile = target.GameFile,
                Comment = target.Comment,
                JsfBytes = jsf,
                SourceSize = vanilla.LongLength,
                SourceHash = Utilities.CalculateHash(new MemoryStream(vanilla), "sha256"),
                DestSize = patched.LongLength,
                DestHash = Utilities.CalculateHash(new MemoryStream(patched), "sha256"),
            });
        }

        /// <summary>
        /// Writes every recorded delta's .jsf plus a manifest.json into <see cref="MilanDeltaFolder"/>.
        /// Called once the build has actually completed successfully, so a mid-build failure never
        /// leaves stale/partial patch files sitting alongside the rest of the mod output.
        /// </summary>
        internal static void WriteMilanDeltaOutput()
        {
            if (deltaRecords.Count == 0)
            {
                MilanLog.Warning("No BaseDelta patches were recorded this run; skipping MilanDelta output.");
                return;
            }

            Directory.CreateDirectory(MilanDeltaFolder);

            var manifestDeltas = new List<object>();
            foreach (var record in deltaRecords)
            {
                var deltaFileName = record.GameFile + ".jsf";
                File.WriteAllBytes(Path.Combine(MilanDeltaFolder, deltaFileName), record.JsfBytes);

                manifestDeltas.Add(new
                {
                    comment = record.Comment,
                    filename = record.GameFile,
                    delta = deltaFileName,
                    sourcesize = record.SourceSize,
                    sourcehash = record.SourceHash,
                    destsize = record.DestSize,
                    desthash = record.DestHash
                });
            }

            // Signature covers the manifest body (everything but itself), so a consumer can detect
            // tampering/corruption of the manifest independent of the individual file hashes above.
            var body = new { milan = true, version = MANIFEST_VERSION, deltas = manifestDeltas };
            var bodyJson = JsonSerializer.Serialize(body);
            var signature = Utilities.CalculateHash(new MemoryStream(Encoding.UTF8.GetBytes(bodyJson)), "sha256");

            var manifest = new { milan = true, version = MANIFEST_VERSION, deltas = manifestDeltas, signature };
            var manifestJson = JsonSerializer.Serialize(manifest, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(Path.Combine(MilanDeltaFolder, MANIFEST_FILENAME), manifestJson);

            MilanLog.Information($"Wrote MilanDelta manifest with {deltaRecords.Count} delta(s) to {MilanDeltaFolder}");
        }
    }
}
