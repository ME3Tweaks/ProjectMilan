using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using ProjectMilan.Utility;

namespace ProjectMilan_ExtraContent.Shared
{
    // Will probably move to LEC after stabilizing and figuring out API
    internal class SharedLoc
    {
        /// <summary>
        /// Finds localized imports for the given source export, and places them into the destination package.
        /// </summary>
        /// <param name="sourceExport"></param>
        /// <param name="localizedDestPackage"></param>
        public static void GenerateLocalizedContent(ExportEntry sourceExport, IMEPackage localizedDestPackage, MELocalization lang, PackageCache cache, string objectReferencerName = null, List<ImportEntry> references = null)
        {
            if (sourceExport.FileRef.Localization != MELocalization.None)
                throw new Exception("Package is already localized version.");

            // Base names that is safe to import from and we should not port
            var safeToImportFrom = EntryImporter.FilesSafeToImportFrom(sourceExport.FileRef.Game).Select(x => Path.GetFileNameWithoutExtension(x).StripUnrealLocalization()).ToList();
            references ??= EntryImporter.GetAllReferencesOfExport(sourceExport).OfType<ImportEntry>().ToList();

            // We need to resolve all imports and see if they resolve in a localized package.
            // Ones that do not will not be moved, but ones that do, will need their resolved version moved to the localized dest package.
            List<ExportEntry> portedItems = new List<ExportEntry>();

            foreach (var iref in references)
            {
                // TODO: Lang ToString needs to be adjusted for ME1/LE1's different suffixes.
                var resolved = EntryImporter.ResolveImport(iref, cache, lang.ToString());
                if (resolved == null)
                    continue; // Could not resolve.
                if (resolved.FileRef.Localization == lang && !safeToImportFrom.Contains(resolved.FileRef.FileNameNoExtension.StripUnrealLocalization(), StringComparer.OrdinalIgnoreCase))
                {
                    // Port localized content over.
                    EntryExporter.ExportExportToPackage(resolved, localizedDestPackage, out var ported, cache);
                    if (ported is ExportEntry exp)
                    {
                        portedItems.Add(exp);
                    }
                }
            }

            // Create object referencer, with optional name that makes it easy to migrate this to another package later.
            var referencer = PackageTools.CreateObjectReferencer(localizedDestPackage, false, objectReferencerName);
            PackageTools.AddObjectsToReferencer(referencer, portedItems);
        }
    }
}
