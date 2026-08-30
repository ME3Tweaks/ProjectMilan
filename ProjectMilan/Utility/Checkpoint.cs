using System;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using ProjectMilan.Pipelines.Mod.BaseDelta;

namespace ProjectMilan.Utility
{
    /// <summary>
    /// Owns the on-disk layout and lifecycle of the checkpoint: a Data subfolder (direct copy of
    /// mod output), a Delta subfolder (computed .jsf patch files from <see cref="BaseDeltaHandler"/>),
    /// and a metadata file in the checkpoint root. All checkpoint creation, restoration, and removal
    /// should go through this class rather than manipulating the checkpoint folder directly.
    /// </summary>
    internal class Checkpoint
    {
        private const string METADATA_FILENAME = "checkpoint.metadata.json";
        private const string DATA_SUBFOLDER = "Data";
        private const string DELTA_SUBFOLDER = "Delta";
        private const string DEBUG_DELTA_SUBFOLDER = "DebugDelta";

        /// <summary>
        /// Subfolder containing a direct copy of the mod output.
        /// </summary>
        internal static string DataFolder => Path.Combine(Program.Settings.CheckpointFolder, DATA_SUBFOLDER);

        /// <summary>
        /// Subfolder containing computed patch (.jsf) files produced by <see cref="BaseDeltaHandler"/> via JDiff.
        /// </summary>
        internal static string DeltaFolder => Path.Combine(Program.Settings.CheckpointFolder, DELTA_SUBFOLDER);

        /// <summary>
        /// DEBUG-only subfolder holding the actual transformed (patched) target files, written alongside
        /// the .jsf deltas whenever a checkpoint is being created, so they can be manually inspected
        /// (e.g. in PackageEditor). Not part of the checkpoint's real contract - nothing restores from it.
        /// </summary>
        internal static string DebugDeltaFolder => Path.Combine(Program.Settings.CheckpointFolder, DEBUG_DELTA_SUBFOLDER);

        private class CheckpointMetadata
        {
            public DateTime CreatedUtc { get; set; }
            public int MinCheckpointVersion { get; set; }
        }

        internal static void CreateCheckpoint()
        {
            if (string.IsNullOrWhiteSpace(Program.Settings.CheckpointFolder))
            {
                MilanLog.Error("Checkpoint system is enabled, but CheckpointFolder is not configured.");
                return;
            }

            if (!Directory.Exists(Program.Settings.OutputModPath))
            {
                MilanLog.Error($"Cannot create checkpoint because output folder does not exist: {Program.Settings.OutputModPath}");
                return;
            }

            MilanLog.Information($"Creating checkpoint at {Program.Settings.CheckpointFolder}");

            // Only clear/rewrite Data - Delta is maintained independently by BaseDeltaHandler
            // (PrepareForFreshBuild(), which already ran earlier this pipeline run) and must not be
            // wiped out here.
            Directory.CreateDirectory(DataFolder);
            Utilities.DeleteFilesAndFoldersRecursively(DataFolder, deleteDirectoryItself: false);
            CopyDirectoryContents(Program.Settings.OutputModPath, DataFolder);

            // Write metadata for this checkpoint
            try
            {
                var metadata = new CheckpointMetadata
                {
                    CreatedUtc = DateTime.UtcNow,
                    MinCheckpointVersion = Program.MIN_CHECKPOINT_VERSION
                };

                var json = JsonSerializer.Serialize(metadata, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(Path.Combine(Program.Settings.CheckpointFolder, METADATA_FILENAME), json);
            }
            catch (Exception ex)
            {
                MilanLog.Error($"Failed to write checkpoint metadata: {ex}");
            }
            MilanLog.Information("Checkpoint creation finished");
        }

        internal static bool RestoreCheckpoint()
        {
            if (string.IsNullOrWhiteSpace(Program.Settings.CheckpointFolder))
            {
                MilanLog.Error("Checkpoint system is enabled, but CheckpointFolder is not configured.");
                return false;
            }

            if (!Directory.Exists(DataFolder))
            {
                MilanLog.Error($"Checkpoint data folder does not exist: {DataFolder}");
                return false;
            }

            if (string.Equals(Path.GetFullPath(Program.Settings.CheckpointFolder),
                    Path.GetFullPath(Program.Settings.OutputModPath),
                    StringComparison.OrdinalIgnoreCase))
            {
                MilanLog.Error("CheckpointFolder and OutputModPath cannot be the same path.");
                return false;
            }

            MilanLog.Information($"Restoring checkpoint from {Program.Settings.CheckpointFolder}");
            Directory.CreateDirectory(Program.Settings.OutputModPath);
            Utilities.DeleteFilesAndFoldersRecursively(Program.Settings.OutputModPath, deleteDirectoryItself: false);
            CopyDirectoryContents(DataFolder, Program.Settings.OutputModPath);
            MilanLog.Information("Checkpoint restore finished");
            return true;
        }

        /// <summary>
        /// Deletes any existing checkpoint (Data, Delta, and metadata). This is the only place
        /// checkpoint removal should happen from -- callers that need to discard a checkpoint
        /// should call this rather than deleting the checkpoint folder themselves.
        /// </summary>
        internal static void DeleteCheckpoint()
        {
            if (string.IsNullOrWhiteSpace(Program.Settings.CheckpointFolder))
                return;

            Directory.CreateDirectory(Program.Settings.CheckpointFolder);
            Utilities.DeleteFilesAndFoldersRecursively(Program.Settings.CheckpointFolder, deleteDirectoryItself: false);
        }

        internal static int ReadCheckpointVersion()
        {
            try
            {
                var metaPath = Path.Combine(Program.Settings.CheckpointFolder ?? string.Empty, METADATA_FILENAME);
                if (!File.Exists(metaPath))
                    return 0; // version zero if missing

                var json = File.ReadAllText(metaPath);
                var metadata = JsonSerializer.Deserialize<CheckpointMetadata>(json);
                return metadata?.MinCheckpointVersion ?? 0;
            }
            catch (Exception ex)
            {
                MilanLog.Error($"Failed to read checkpoint metadata: {ex}");
                return 0;
            }
        }

        private static void CopyDirectoryContents(string sourceDirectory, string destinationDirectory)
        {
            Directory.CreateDirectory(destinationDirectory);

            foreach (var file in Directory.GetFiles(sourceDirectory))
            {
                var destinationFile = Path.Combine(destinationDirectory, Path.GetFileName(file));
                File.Copy(file, destinationFile, true);
            }

            foreach (var directory in Directory.GetDirectories(sourceDirectory))
            {
                var destinationSubdirectory = Path.Combine(destinationDirectory, Path.GetFileName(directory));
                CopyDirectoryContents(directory, destinationSubdirectory);
            }
        }
    }
}
