using System;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace ProjectMilan.Utility
{
    internal class Checkpoint
    {
        private const string METADATA_FILENAME = "checkpoint.metadata.json";

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
            Directory.CreateDirectory(Program.Settings.CheckpointFolder);
            Utilities.DeleteFilesAndFoldersRecursively(Program.Settings.CheckpointFolder, deleteDirectoryItself: false);
            CopyDirectoryContents(Program.Settings.OutputModPath, Program.Settings.CheckpointFolder);
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

            if (!Directory.Exists(Program.Settings.CheckpointFolder))
            {
                MilanLog.Error($"Checkpoint folder does not exist: {Program.Settings.CheckpointFolder}");
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
            CopyDirectoryContents(Program.Settings.CheckpointFolder, Program.Settings.OutputModPath);
            MilanLog.Information("Checkpoint restore finished");
            return true;
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
