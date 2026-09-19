using LegendaryExplorerCore.Packages;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Shaders
{

    public static class ShaderPipeline
    {
        private const string LOG_CATEGORY = @"MILAN-Shaders";

        public static void RunPipeline()
        {
            InternalRunPipeline();
        }

        private static void InternalRunPipeline()
        {
            var files = Directory.GetFiles(Program.Settings.OutputModPath, "*.pcc", SearchOption.AllDirectories);
            foreach (var file in files)
            {
                var package = MEPackageHandler.OpenMEPackage(file, diskIOSyncLock: MilanShared.DiskIOSyncLock);
                MilanShaders.InstallCompiledShadersToPackage(package, LOG_CATEGORY);
                if (package.IsModified)
                {
                    package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
                }
            }
        }
    }
}
