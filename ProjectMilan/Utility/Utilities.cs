using System.Diagnostics;
using System.Net.Http.Headers;

namespace ProjectMilan.Utility
{
    internal class Utilities
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
            foreach (string file in Directory.GetFiles(targetDirectory))
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
    }
}
