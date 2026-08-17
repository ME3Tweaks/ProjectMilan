using System;

namespace ProjectMilan.Utility
{
    internal class Checkpoint
    {
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
