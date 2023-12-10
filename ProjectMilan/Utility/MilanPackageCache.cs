using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;

namespace ProjectMilan.Utility
{
    /// <summary>
    /// Subclass of PackageCache that supports fetching files based on filename alone
    /// </summary>
    internal class MilanPackageCache : PackageCache
    {
        /// <summary>
        /// Thread-safe package cache fetch for Milan. Accesses files based on filename and then on full filename.
        /// </summary>
        /// <param name="packagePath">Path of file - full or filename only</param>
        /// <param name="openIfNotInCache">Open the specified package if it is not in the cache, and add it to the cache</param>
        /// <param name="openPackageMethod">Optional delegate that is used to open a package file</param>
        /// <returns></returns>
        public override IMEPackage GetCachedPackage(string packagePath, bool openIfNotInCache = true, Func<string, IMEPackage> openPackageMethod = null)
        {
            // Cannot look up null paths
            if (packagePath == null)
                return null;

            // May need way to set maximum size of dictionary so we don't hold onto too much memory.
            lock (syncObj)
            {
                if (Cache.TryGetValue(packagePath, out IMEPackage package))
                {
                    //Debug.WriteLine($@"PackageCache hit: {packagePath}");
                    LastAccessMap[packagePath] = DateTime.Now; // Update access time
                    return package;
                }

                var relativePath = Path.GetFileName(packagePath);
                var matching = Cache.Keys.FirstOrDefault(x => Path.GetFileName(x).CaseInsensitiveEquals(relativePath));
                if (matching != null && Cache.TryGetValue(matching, out IMEPackage package2))
                {
                    //Debug.WriteLine($@"PackageCache hit: {packagePath}");
                    LastAccessMap[relativePath] = DateTime.Now; // Update access time
                    return package2;
                }

                if (openIfNotInCache)
                {
                    if (File.Exists(packagePath))
                    {
                        Debug.WriteLine($@"MilanPackageCache {guid} load: {packagePath}");
                        package = openPackageMethod?.Invoke(packagePath) ?? MEPackageHandler.OpenMEPackage(packagePath, forceLoadFromDisk: AlwaysOpenFromDisk);
                        InsertIntoCache(package);
                        return package;
                    }

                    Debug.WriteLine($@"MilanPackageCache {guid} miss: File not found: {packagePath}");
                }
            }

            return null; //Package could not be found
        }
    }
}
