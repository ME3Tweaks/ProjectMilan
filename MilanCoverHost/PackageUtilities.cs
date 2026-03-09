using LegendaryExplorerCore.Packages;
using System;
using System.Collections.Generic;
using System.Text;

namespace MilanCoverHost
{
    internal static class PackageUtilities
    {
        /// <summary>
        /// Generates the Default__ object for a class
        /// </summary>
        /// <param name="classEntry"></param>
        /// <returns></returns>
        public static IEntry GetDefaults(IEntry classEntry)
        {
            if (classEntry.Parent == null)
                return classEntry.FileRef.GetEntryOrAddImport($"Default__{classEntry.ObjectName.Instanced}", classEntry.ObjectName.Instanced, classEntry.FileRef.FileNameNoExtension);
            string parentPath = classEntry.ParentInstancedFullPath;
            return classEntry.FileRef.GetEntryOrAddImport($"{parentPath}.Default__{classEntry.ObjectName.Instanced}", classEntry.ObjectName.Instanced, classEntry.ParentName);
        }

        public static IEntry GetComponentArchetype(IEntry classEntry, string archetypeObjectName, string componentClass)
        {
            var parent = GetDefaults(classEntry); // Ensures parent is made
            var subPath = parent.InstancedFullPath + "." + archetypeObjectName;
            return classEntry.FileRef.FindImport(subPath) ?? classEntry.FileRef.GetEntryOrAddImport(subPath, componentClass);
        }
    }
}
