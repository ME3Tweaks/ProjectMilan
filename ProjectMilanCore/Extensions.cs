using LegendaryExplorerCore.Packages;
using System.IO.Compression;

namespace ProjectMilanCore
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
        public static ExportEntry GetBioWorldInfo(this IMEPackage package)
        {
            return package.Exports.FirstOrDefault(x => !x.IsDefaultObject && x.ClassName == "BioWorldInfo");
        }
    }
}
