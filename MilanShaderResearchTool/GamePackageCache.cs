using LegendaryExplorerCore.Packages;
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace MilanShaderResearchTool
{
    class GamePackageCache : PackageCache
    {
        private string gamePath;
        public GamePackageCache(string gamePath)
        {
            this.gamePath = gamePath;
        }

        public override IMEPackage GetCachedPackage(string packagePath, bool openIfNotInCache = true, Func<string, IMEPackage> openPackageMethod = null)
        {
            var path = Path.Combine(gamePath, packagePath);
            return base.GetCachedPackage(path, openIfNotInCache, openPackageMethod);
        }
    }
}
