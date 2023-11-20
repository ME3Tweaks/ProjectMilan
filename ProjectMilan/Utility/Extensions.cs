using System;
using System.Collections.Generic;
using System.IO.Compression;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal.BinaryConverters;

namespace ProjectMilan.Utility
{
    public static class ZipExtensions
    {

        /// <summary>
        /// Fully decompresses a zip entry to memory
        /// </summary>
        /// <param name="entry"></param>
        /// <returns></returns>
        public static MemoryStream Decompress(this ZipArchiveEntry entry)
        {
            MemoryStream ms = new MemoryStream((int)entry.Length);
            using var decomp = entry.Open();
            decomp.CopyTo(ms);
            ms.Position = 0;
            return ms;
        }
    }

    public static class PackageExtensions
    {
        public static ExportEntry GetLevel(this IMEPackage package)
        {
            return package.FindExport("TheWorld.PersistentLevel");
        }

        public static Level GetLevelBinary(this IMEPackage package)
        {
            return ObjectBinary.From<Level>(package.GetLevel());
        }
    }
}
