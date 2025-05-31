using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal;

namespace MilanShaderHost.LEX
{
    public static class SharedMethods
    {
        /// <summary>
        /// By SirCxyrtyx.
        /// </summary>
        /// <param name="pcc"></param>
        /// <param name="name"></param>
        /// <param name="className"></param>
        /// <param name="parent"></param>
        /// <param name="properties"></param>
        /// <param name="binary"></param>
        /// <param name="prePropBinary"></param>
        /// <param name="super"></param>
        /// <param name="archetype"></param>
        /// <returns>New ExportEntry</returns>
        public static ExportEntry CreateExport(IMEPackage pcc, NameReference name, string className, IEntry parent, PropertyCollection properties = null, ObjectBinary binary = null, byte[] prePropBinary = null, IEntry super = null, IEntry archetype = null)
        {
            IEntry classEntry = className.CaseInsensitiveEquals("Class") ? null : EntryImporter.EnsureClassIsInFile(pcc, className, new RelinkerOptionsPackage());

            var exp = new ExportEntry(pcc, parent, name, prePropBinary, properties, binary, binary is UClass)
            {
                Class = classEntry,
                SuperClass = super,
                Archetype = archetype
            };
            pcc.AddExport(exp);
            return exp;
        }
    }
}
