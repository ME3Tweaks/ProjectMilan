using LegendaryExplorerCore;
using LegendaryExplorerCore.GameFilesystem;
using ProjectMilan.Utility;

namespace MultiInstancePatcher
{
    internal class Program
    {
        static void Main(string[] args)
        {
            LegendaryExplorerCoreLib.InitLib(TaskScheduler.Current);
            if (LE3Directory.ExecutablePath != null && File.Exists(LE3Directory.ExecutablePath))
            {
                MultiInstance.PatchForMultiInstance();
            }
        }
    }
}
