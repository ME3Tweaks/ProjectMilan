using LegendaryExplorerCore.GameFilesystem;

namespace ProjectMilan.Utility
{
    internal class MultiInstance
    {
        /// <summary>
        /// Patches out the 'Another instance of this game is already running' from the executable.
        /// This occurs too early for ASIs to reliably handle.
        /// </summary>
        public static void PatchForMultiInstance()
        {
            try
            {
                if (LE3Directory.ExecutablePath != null && File.Exists(LE3Directory.ExecutablePath))
                {
                    var fSize = new FileInfo(LE3Directory.ExecutablePath).Length;
                    if (fSize == 26887680L)
                    {
                        // DRM Free
                        MilanLog.Information("Patching executable for multi-instance");
                        using var fStream = File.Open(LE3Directory.ExecutablePath, FileMode.Open, FileAccess.ReadWrite);
                        fStream.Seek(0x9BAA6E, SeekOrigin.Begin);
                        for (int i = 0; i < 0x21; i++)
                        {
                            // ♫ Nop, Nop, Nop it all out
                            // These are the bytes I don't care about ♫
                            fStream.WriteByte(0x90);
                        }
                    }
                }
            }
            catch
            {
                MilanLog.Warning("Multipatching was skipped due an error.");
            }
        }
    }
}
