using Microsoft.Win32;
using System.Diagnostics;
using System.Net.Http.Headers;
using System.Runtime.InteropServices;
using System.Security.Cryptography;

namespace ProjectMilan.Utility
{
    /// <summary>
    /// A process found to be holding a lock on a file, as reported by the Windows Restart Manager.
    /// </summary>
    public record FileLockOwner(int ProcessId, string ProcessName);

    /// <summary>
    /// Identifies which running process(es) are holding a lock on a given file, using the same
    /// Restart Manager API Windows itself uses to populate the "close these programs" dialog
    /// (e.g. when you try to delete a file that's open in another app). This is far more reliable
    /// than trying to enumerate system handles by hand.
    /// </summary>
    public static class FileLockUtils
    {
        private const int ERROR_MORE_DATA = 234;

        [StructLayout(LayoutKind.Sequential)]
        private struct RM_UNIQUE_PROCESS
        {
            public int dwProcessId;
            public System.Runtime.InteropServices.ComTypes.FILETIME ProcessStartTime;
        }

        private enum RM_APP_TYPE
        {
            RmUnknownApp = 0,
            RmMainWindow = 1,
            RmOtherWindow = 2,
            RmService = 3,
            RmExplorer = 4,
            RmConsole = 5,
            RmCritical = 1000
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct RM_PROCESS_INFO
        {
            public RM_UNIQUE_PROCESS Process;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)]
            public string strAppName;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
            public string strServiceShortName;
            public RM_APP_TYPE ApplicationType;
            public uint AppStatus;
            public uint TSSessionId;
            [MarshalAs(UnmanagedType.Bool)]
            public bool bRestartable;
        }

        [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
        private static extern int RmStartSession(out uint pSessionHandle, int dwSessionFlags, string strSessionKey);

        [DllImport("rstrtmgr.dll")]
        private static extern int RmEndSession(uint pSessionHandle);

        [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
        private static extern int RmRegisterResources(uint pSessionHandle, uint nFiles, string[] rgsFilenames,
            uint nApplications, RM_UNIQUE_PROCESS[] rgApplications, uint nServices, string[] rgsServiceNames);

        [DllImport("rstrtmgr.dll")]
        private static extern int RmGetList(uint dwSessionHandle, out uint pnProcInfoNeeded, ref uint pnProcInfo,
            [In, Out] RM_PROCESS_INFO[] rgAffectedApps, ref uint lpdwRebootReasons);

        /// <summary>
        /// Returns the process(es) currently holding a lock on <paramref name="filePath"/>. Returns
        /// an empty list if the file isn't locked by anything Restart Manager can see (it may still
        /// be locked at the kernel level, e.g. by a driver).
        /// </summary>
        public static List<FileLockOwner> GetLockingProcesses(string filePath)
        {
            var owners = new List<FileLockOwner>();

            int res = RmStartSession(out uint session, 0, Guid.NewGuid().ToString("N"));
            if (res != 0)
            {
                MilanLog.Warning($"RmStartSession failed with error {res}");
                return owners;
            }

            try
            {
                string[] resources = { filePath };
                res = RmRegisterResources(session, (uint)resources.Length, resources, 0, null, 0, null);
                if (res != 0)
                {
                    MilanLog.Warning($"RmRegisterResources failed with error {res} for {filePath}");
                    return owners;
                }

                uint pnProcInfoNeeded = 0;
                uint pnProcInfo = 0;
                uint lpdwRebootReasons = 0;

                // First call with a null buffer just tells us how many entries to allocate.
                res = RmGetList(session, out pnProcInfoNeeded, ref pnProcInfo, null, ref lpdwRebootReasons);
                if (res != ERROR_MORE_DATA)
                {
                    if (res != 0) MilanLog.Warning($"RmGetList (sizing) failed with error {res} for {filePath}");
                    return owners;
                }

                var processInfo = new RM_PROCESS_INFO[pnProcInfoNeeded];
                pnProcInfo = pnProcInfoNeeded;
                res = RmGetList(session, out pnProcInfoNeeded, ref pnProcInfo, processInfo, ref lpdwRebootReasons);
                if (res != 0)
                {
                    MilanLog.Warning($"RmGetList failed with error {res} for {filePath}");
                    return owners;
                }

                for (int i = 0; i < pnProcInfo; i++)
                {
                    owners.Add(new FileLockOwner(processInfo[i].Process.dwProcessId, processInfo[i].strAppName));
                }
            }
            finally
            {
                RmEndSession(session);
            }

            return owners;
        }

        /// <summary>
        /// Convenience wrapper for logging: "UDK.exe (PID 1234), UDK.exe (PID 5678)", or
        /// "an unknown process" if nothing could be attributed to the lock.
        /// </summary>
        public static string DescribeLockingProcesses(string filePath)
        {
            try
            {
                var owners = GetLockingProcesses(filePath);
                return owners.Count == 0
                    ? "an unknown process"
                    : string.Join(", ", owners.Select(o => $"{o.ProcessName} (PID {o.ProcessId})"));
            }
            catch (Exception e)
            {
                MilanLog.Warning($"Could not determine what's locking {filePath}: {e.Message}");
                return "an unknown process";
            }
        }
    }

    public static class Utilities
    {
        /// <summary>
        /// Deletes the contents of the specified folder, as well as the directory itself unless deleteDirectoryItself = false
        /// </summary>
        /// <param name="targetDirectory"></param>
        /// <param name="throwOnFailed"></param>
        /// <returns></returns>
        public static bool DeleteFilesAndFoldersRecursively(string targetDirectory, bool throwOnFailed = false, bool deleteDirectoryItself = true, bool quiet = false)
        {
            if (!Directory.Exists(targetDirectory))
            {
                Debug.WriteLine(@"Directory to delete doesn't exist: " + targetDirectory);
                return true;
            }

            bool result = true;
            foreach (string file in Directory.EnumerateFiles(targetDirectory))
            {
                File.SetAttributes(file, FileAttributes.Normal); //remove read only
                try
                {
                    if(!quiet)
                    {
                        MilanLog.Information($"Deleting file: {file}");
                    }
                    File.Delete(file);
                }
                catch (Exception e)
                {
                    MilanLog.Error($@"Unable to delete file: {file}. It may be open still: {e.Message}");
                    if (throwOnFailed)
                    {
                        throw;
                    }

                    return false;
                }
            }

            foreach (string subDir in Directory.GetDirectories(targetDirectory))
            {
                result &= DeleteFilesAndFoldersRecursively(subDir, throwOnFailed, true, quiet);
            }

            if (deleteDirectoryItself)
            {
                Thread.Sleep(10); // This makes the difference between whether it works or not. Sleep(0) is not enough.
                try
                {
                    Directory.Delete(targetDirectory);
                }
                catch (Exception e)
                {
                    MilanLog.Error($@"Unable to delete directory: {targetDirectory}. It may be open still or may not be actually empty: {e.Message}");
                    if (throwOnFailed)
                    {
                        throw;
                    }

                    return false;
                }
            }

            return result;
        }

        public static void WriteRegistryKey(string subpath, string value, string data)
        {
            int i = 0;
            List<string> subkeys = subpath.Split('\\').ToList();
            RegistryKey subkey;
            if (subkeys[0] == "HKEY_CURRENT_USER")
            {
                subkeys.RemoveAt(0);
                subkey = Registry.CurrentUser;
            }
            else
            {
                throw new Exception("Currently only HKEY_CURRENT_USER keys are supported for writing.");
            }

            while (i < subkeys.Count)
            {
                subkey = subkey.CreateSubKey(subkeys[i]);
                i++;
            }

            subkey.SetValue(value, data);
        }

        public static string GetJsonStringFromEndpoint(string url)
        {
            using var client = new HttpClient();
            client.BaseAddress = new Uri(url);
            // Add an Accept header for JSON format.
            client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
            // Get data response
            try
            {
                return client.GetStringAsync(url).Result;
            }
            catch (Exception e)
            {
                MilanLog.Error($@"Error fetching data {url}: {e.Message}");
                return null;
            }
        }


        /// <summary>
        /// Calculates the MD5 of the specified file on disk
        /// </summary>
        /// <param name="filename"></param>
        /// <param name="algorithm">Algorithm to use. Use null for MD5.</param>
        /// <returns></returns>
        public static string CalculateHash(string filename, string algorithm = null)
        {
            try
            {
                using var stream = File.OpenRead(filename);
                return CalculateHash(stream, algorithm);
            }
            catch (IOException e)
            {
                MilanLog.Error($@"I/O ERROR CALCULATING {(algorithm == null ? @"md5" : algorithm.GetType())} OF FILE: " + filename); // do not localize
                MilanLog.Error(e);
                return "";
            }
        }

        /// <summary>
        /// Calculates the hash of the stream from the beginning. Resets the stream to the beginning at the end.
        /// </summary>
        /// <param name="stream">Stream to hash</param>
        /// <param name="algorithm">Algorithm to use. Use null for MD5.</param>
        /// <returns></returns>
        public static string CalculateHash(Stream stream, string algorithm = null)
        {
            HashAlgorithm algo = null;

            try
            {
                switch (algorithm)
                {
                    case @"sha":
                    case @"sha1":
                        algo = SHA1.Create();
                        break;
                    case @"sha256":
                        algo = SHA256.Create();
                        break;
                    default:
                        algo = MD5.Create();
                        break;
                }

                stream.Position = 0;
                var hash = algo.ComputeHash(stream);
                stream.Position = 0; // reset stream
                return BitConverter.ToString(hash).Replace(@"-", "").ToLowerInvariant();
            }
            catch (Exception e)
            {
                MilanLog.Error($@"I/O ERROR CALCULATING {algo.GetType()} OF STREAM");
                MilanLog.Error(e);
                return "";
            }
            finally
            {
                algo.Dispose();
            }
        }
    }
}
