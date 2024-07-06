using Microsoft.Win32;
using System.Diagnostics;
using System.Net.Http.Headers;
using System.Security.Cryptography;

namespace ProjectMilan.Utility
{
    public static class Utilities
    {
        /// <summary>
        /// Deletes the contents of the specified folder, as well as the directory itself unless deleteDirectoryItself = false
        /// </summary>
        /// <param name="targetDirectory"></param>
        /// <param name="throwOnFailed"></param>
        /// <returns></returns>
        public static bool DeleteFilesAndFoldersRecursively(string targetDirectory, bool throwOnFailed = false, bool deleteDirectoryItself = true)
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
                    MilanLog.Information($"Deleting file: {file}");
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
                result &= DeleteFilesAndFoldersRecursively(subDir, throwOnFailed, true);
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
