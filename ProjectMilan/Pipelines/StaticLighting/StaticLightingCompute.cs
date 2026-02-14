using System.ComponentModel;
using System.Diagnostics;
using UDKInj;
using LegendaryExplorerCore.GameFilesystem;

namespace ProjectMilan.Pipelines.StaticLighting
{
    /// <summary>
    /// Builds static lighting in UDK in an automated fashion. This process is VERY slow, should only really ever be used on final builds.
    /// </summary>
    public static class StaticLightingCompute
    {
        private const string LOG_CATEGORY = @"MILAN-StaticLightingCompute";

        private static Injector injector;
        private static FileInfo module;
        /// <summary>
        /// Runs UDK and builds lighting, importing the results afterwards.
        /// </summary>
        /// <param name="mapName">The extensionless name of the map. Should already be in the UDK maps folder</param>
        internal static void ComputeLighting(string mapName)
        {
            // Boot UDK.
            var udkInfo = new ProcessStartInfo()
            {
                FileName = UDKDirectory.GetExecutablePath(Program.Settings.MilanUDKPath),
                Arguments = $"editor {mapName}.udk -log",
            };

            MilanLog.Information("Starting UDK for lighting build");
            var udkProcess = Process.Start(udkInfo);

            Thread.Sleep(5000); // Let UDK start loading. There's a better way to do this I'm sure
            try
            {
                injector = new Injector(new ProcessHandle(udkProcess), bDisposeProcess: false);
                module ??= new FileInfo(@"B:\UserProfile\source\repos\ME3Tweaks\UdkInj\x64\Debug\UDKAgent.asi");
                InjectModule();
                var mapPath = StaticLightingExport.GetMapOutputPath(mapName);
                var masterMap = Path.Combine(mapPath, $"{mapName}.udk");

                BakeLighting(masterMap, 1);


                // Kill UDK.
                // Die mf'er
                MilanLog.Information("UDK lighting build is complete");
                udkProcess.Kill();
            }
            finally
            {
                // Reset injector and module.
                injector?.Dispose();
            }
        }
        // Example method that bakes lighting in a flow

        private static void LoadMap(string persistentPackagePath)
        {
            using var input = injector.MakeAllocation(256);
            using var output = injector.MakeAllocation(16);

            input.WriteStringUTF16(0, persistentPackagePath);

            injector.CallWithParams(module, "LoadMap", input, output);
            MilanLog.Information($"LoadMapResult: {output.ReadInt32(0)}", customPrefix: LOG_CATEGORY);
        }

        private static void RunLightmass(int qualityLevel)
        {
            using var input = injector.MakeAllocation(256);
            using var output = injector.MakeAllocation(16);

            input.WriteInt32(0, qualityLevel);

            injector.CallWithParams(module, "BuildLighting", input, output);
            MilanLog.Information($"RunLightmassResult: {output.ReadInt32(0)}", customPrefix: LOG_CATEGORY);
        }

        private static void SaveMapFiles(bool promptUser = false, bool saveMaps = true, bool saveContent = false)
        {
            using var input = injector.MakeAllocation(256);
            using var output = injector.MakeAllocation(16);

            input.WriteInt32(0, promptUser ? 1 : 0);
            input.WriteInt32(4, saveMaps ? 1 : 0);
            input.WriteInt32(8, saveContent ? 1 : 0);

            injector.CallWithParams(module, "SavePackages", input, output);
            MilanLog.Information($"SaveMapFiles: {output.ReadInt32(0)}", customPrefix: LOG_CATEGORY);
        }

        private static void CloseSubWindows()
        {
            injector.Call(module, "CloseSubWindows");
        }

        /// <summary>
        /// Invoke to build lighting
        /// </summary>
        /// <param name="masterMapPath"></param>
        /// <param name="qualityLevel"></param>
        private static void BakeLighting(string masterMapPath, int qualityLevel)
        {
            CloseSubWindows(); // Close browsers and other windows.
            LoadMap(masterMapPath);
            CloseSubWindows(); // Close not found assets
            RunLightmass(qualityLevel);
            CloseSubWindows(); // Close lighting results (e.g. not production lighting!)
            SaveMapFiles();
            WaitForTasks();
        }

        /// <summary>
        /// Causes this app to stall while UDK completes
        /// </summary>
        private static void WaitForTasks()
        {
            while (true)
            {
                Thread.Sleep(2500);
                if (!IsUDKBusy())
                {
                    break;
                }
            }
        }

        private static bool IsUDKBusy()
        {
            using var input = injector.MakeAllocation(4);
            using var output = injector.MakeAllocation(4);

            injector.CallWithParams(module, "IsSlowTaskRunning", input, output);
            var result = output.ReadInt32(0);
            return result == 0;
        }

        private static void InjectModule()
        {
            try
            {
                injector.Inject(module);
            }
            catch (Win32Exception Exception)
            {
                MilanLog.Exception(Exception, "Error injecting UDKInj: ", customPrefix: LOG_CATEGORY);
            }
        }
    }
}
