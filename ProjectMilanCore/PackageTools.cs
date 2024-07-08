using LegendaryExplorerCore.Gammtek.Extensions.Collections.Generic;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;

namespace ProjectMilan.Utility
{
    // Ported from M3/M3C/LE2R
    public static class PackageTools
    {
        /// <summary>
        /// Creates an empty ObjectReferencer if none exists - if one exists, it returns that instead
        /// </summary>
        /// <param name="package">Package to operate on</param>
        /// <returns>Export of an export referencer</returns>
        public static ExportEntry CreateObjectReferencer(IMEPackage package, bool isStartupPackage, string objectReferencerName = null)
        {
            var referencer = package.Exports.FirstOrDefault(x => x.ClassName == @"ObjectReferencer" && (objectReferencerName == null || x.ObjectName == objectReferencerName));
            if (referencer != null) return referencer;

            var rop = new RelinkerOptionsPackage() { Cache = new PackageCache() };
            var referencerName = (package.Game.IsGame2() || !isStartupPackage)
                ? @"ObjectReferencer"
                : @"CombinedStartupReferencer";
            if (objectReferencerName != null)
            {
                referencerName += "_" + objectReferencerName;
            }

            if (package.Game.IsGame2())
            {
                // 2 just uses objectreferencer
                referencer = new ExportEntry(package, 0, package.GetNextIndexedName(referencerName), properties: new PropertyCollection() { new ArrayProperty<ObjectProperty>(@"ReferencedObjects") })
                {
                    Class = EntryImporter.EnsureClassIsInFile(package, @"ObjectReferencer", rop)
                };
            }
            else
            {
                // 3 uses both ObjectReferencer for normal packages and CombinedStartupReferencer for startup files
                // Startup files do not work if they use ObjectReferencer
                referencer = new ExportEntry(package, 0, package.GetNextIndexedName(referencerName), properties: new PropertyCollection() { new ArrayProperty<ObjectProperty>(@"ReferencedObjects") })
                {
                    Class = EntryImporter.EnsureClassIsInFile(package, @"ObjectReferencer", rop)
                };
                if (isStartupPackage)
                {
                    referencer.indexValue = 0;
                }
            }

            referencer.WriteProperty(new ArrayProperty<ObjectProperty>(@"ReferencedObjects"));
            package.AddExport(referencer);
            return referencer;
        }

        /// <summary>
        /// Adds the specified entry to the object referencer in the package. If there is no object referencer already added then this does nothing.
        /// </summary>
        /// <param name="entry">The entry to add. It is not checked if it is already in the list</param>
        /// <returns>If object reference was added</returns>
        public static bool AddToObjectReferencer(IEntry entry)
        {
            var referencer = entry.FileRef.Exports.FirstOrDefault(x => x.ClassName == @"ObjectReferencer");
            if (referencer == null) return false;
            var refs = referencer.GetProperty<ArrayProperty<ObjectProperty>>(@"ReferencedObjects") ?? new ArrayProperty<ObjectProperty>(@"ReferencedObjects");
            refs.Add(new ObjectProperty(entry));
            referencer.WriteProperty(refs);
            return true;
        }

        /// <summary>
        /// Adds the specified entry to the object referencer in the package. If there is no object referencer already added then this does nothing.
        /// </summary>
        /// <param name="entry">The entry to add. It is not checked if it is already in the list</param>
        /// <returns>If object reference was added</returns>
        public static bool AddObjectsToReferencer(ExportEntry referencer, List<ExportEntry> entries)
        {
            var refs = referencer.GetProperty<ArrayProperty<ObjectProperty>>(@"ReferencedObjects") ?? new ArrayProperty<ObjectProperty>(@"ReferencedObjects");
            refs.AddRange(entries.Select(x=>new ObjectProperty(x)));
            refs.Values = refs.Values.Distinct().ToList(); // Make sure we don't add duplicates
            referencer.WriteProperty(refs);
            return true;
        }
    }
}
