using System.Collections.ObjectModel;
using System.Diagnostics;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Gammtek.Extensions.Collections.Generic;
using LegendaryExplorerCore.Localization;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using Newtonsoft.Json;

namespace ProjectMilan.Pipelines.Shared
{
    internal class DonorTooling
    {
        public static void BuildDonorDB()
        {
            Dictionary<string, MatInfo> materialInfos = new();

            // Scan all materials and build info for them.
            foreach (var file in MELoadedFiles.GetFilesLoadedInGame(MEGame.LE3))
            {
                MilanLog.Information($"Inventorying {file.Key}", customPrefix: LOG_CATEGORY);
                var package = MEPackageHandler.UnsafePartialLoad(file.Value,
                    x => x.IsA("MaterialInterface") || x.ObjectName.Name.StartsWith("MaterialExpression"));
                foreach (var matExp in package.Exports.Where(x => x.IsDataLoaded()))
                {
                    if (!matExp.IsDefaultObject && matExp.IsA("MaterialInterface") && !materialInfos.ContainsKey(matExp.InstancedFullPath))
                    {
                        var matInfo = new MatInfo();
                        if (matExp.ClassName == "Material")
                        {
                            matInfo.AddShaderId(matExp);
                            var expressions = matExp.GetProperty<ArrayProperty<ObjectProperty>>("Expressions");
                            if (expressions != null)
                            {
                                // This is a Material
                                InventoryExpressions(matExp, matInfo, expressions);
                                var bin = ObjectBinary.From<Material>(matExp);
                                foreach (var tex in bin.SM3MaterialResource.UniformExpressionTextures)
                                {
                                    if (package.TryGetEntry(tex, out var entr))
                                    {
                                        matInfo.Textures.Add(entr.InstancedFullPath);
                                    }
                                }
                            }
                        }
                        else
                        {
                            // Not a root material
                            matInfo.VectorExpressions.ReplaceAll(InventoryParameters(matExp, "VectorParameterValues"));
                            matInfo.ScalarExpressions.ReplaceAll(InventoryParameters(matExp, "ScalarParameterValues"));
                            matInfo.TextureExpressions.ReplaceAll(InventoryParameters(matExp, "TextureParameterValues"));
                            if (matExp.GetProperty<BoolProperty>("bHasStaticPermutationResource")?.Value == true)
                            {
                                matInfo.AddShaderId(matExp);
                            }
                        }

                        // This will need updated for receiver effects as they use Base
                        matInfo.InstancedFullPath = matExp.InstancedFullPath;
                        matInfo.ParentIFP = matExp.GetProperty<ObjectProperty>("Parent")?.ResolveToEntry(matExp.FileRef)?.InstancedFullPath;
                        matInfo.ExportClass = matExp.ClassName;
                        materialInfos[matExp.InstancedFullPath] = matInfo;
                    }
                }
            }

            // Link children to parent
            MilanLog.Information($"Building relationships between materials", customPrefix: LOG_CATEGORY);
            foreach (var matExp in materialInfos)
            {
                if (matExp.Value.ParentIFP != null && materialInfos.TryGetValue(matExp.Value.ParentIFP, out var parentInfo))
                {
                    matExp.Value.Parent = parentInfo;
                    parentInfo.Children.Add(matExp.Value);
                }
                else
                {
                    Debug.WriteLine($"Could not link material {matExp.Key}");
                }
            }

            List<MatInfo> roots = materialInfos.Where(x => x.Value.ParentIFP == null).Select(x => x.Value).ToList();

            var json = JsonConvert.SerializeObject(roots, Formatting.Indented);
            File.WriteAllText(GetMaterialDBPath(), json);
        }

        private static IEnumerable<string> InventoryParameters(ExportEntry exportEntry, string listName)
        {
            List<string> parameters = new List<string>();
            var parms = exportEntry.GetProperty<ArrayProperty<StructProperty>>(listName);
            if (parms != null)
            {
                foreach (var parm in parms)
                {
                    parameters.Add(parm.GetProp<NameProperty>("ParameterName").Value.Instanced);
                }
            }
            return parameters;
        }

        private static void InventoryExpressions(ExportEntry matExp, MatInfo matInfo, ArrayProperty<ObjectProperty> expressions)
        {
            foreach (var expr in expressions)
            {
                var exprExp = expr.ResolveToEntry(matExp.FileRef) as ExportEntry;
                if (exprExp == null)
                    continue;

                var paramName = exprExp.GetProperty<NameProperty>("ParameterName")?.Value.Instanced;
                if (paramName == null)
                    continue; // We can't do anything with this
                if (exprExp.IsA("MaterialExpressionTextureSample"))
                {
                    matInfo.TextureExpressions.Add(paramName);
                }
                else if (exprExp.IsA("MaterialExpressionScalarParameter"))
                {
                    matInfo.ScalarExpressions.Add(paramName);
                }
                else if (exprExp.IsA("MaterialExpressionVectorParameter"))
                {
                    matInfo.VectorExpressions.Add(paramName);
                }
            }
        }


        private const string LOG_CATEGORY = "MILAN-MaterialDonorSystem";
        private static List<MatInfo> _materialDB;
        public static void TryMakeDonor(ExportEntry originalMaterial, string outPath)
        {
            MilanLog.Information($"Looking for possible donor materials for {originalMaterial.InstancedFullPath}", customPrefix: LOG_CATEGORY);
            if (_materialDB == null)
            {
                MilanLog.Information("Loading material donor database", customPrefix: LOG_CATEGORY);
                _materialDB = JsonConvert.DeserializeObject<List<MatInfo>>(File.ReadAllText(GetMaterialDBPath()));
            }

            // Look at parent of incoming material.
            string parentMaterial = originalMaterial.InstancedFullPath;
            if (originalMaterial.IsA("MaterialInstanceConstant"))
            {
                var tempParentMaterial = originalMaterial.GetProperty<ObjectProperty>("Parent").ResolveToEntry(originalMaterial.FileRef)?.InstancedFullPath;
                if (tempParentMaterial != null)
                {
                    parentMaterial = tempParentMaterial;
                }
            }

            var parentInfo = FindMaterial(parentMaterial);
            if (parentInfo == null)
            {
                MilanLog.Warning("  We will have to find a manual donor for this");
                return;
            }

            MilanLog.Information($"  We have parent info. There are {parentInfo.Children.Count} children");
            var donorIdx = 0;
            bool keepAttempting = true;
            while (keepAttempting)
            {
                keepAttempting = false;
                var donorChoice = parentInfo.Children.Count > 0 ? parentInfo.Children[donorIdx] : parentInfo;

                // Load package with that donor
                var files = MilanShared.LE3ObjectDB.GetFilesContainingObject(donorChoice.InstancedFullPath);
                var le3DonorPackage = MilanShared.GetLE3Package(Path.GetFileName(files[0]));
                var exp = le3DonorPackage.FindExport(donorChoice.InstancedFullPath);

                // This is no where near finished
                // Create donor
                var donorPath = Path.Combine(outPath, $"{originalMaterial.InstancedFullPath}.pcc");
                MEPackageHandler.CreateAndSavePackage(donorPath, MEGame.LE3);
                using var destDonorPackage = MEPackageHandler.OpenMEPackage(donorPath);

                var parts = originalMaterial.InstancedFullPath.Split('.');
                ExportEntry parent = null;
                IEntry portedEntry = null;
                for (int i = 0; i < parts.Length; i++)
                {
                    if (i < parts.Length - 1)
                    {
                        parent = ExportCreator.CreatePackageExport(destDonorPackage, parts[i], parent);
                        parent.indexValue = 0;
                    }
                    else
                    {
                        exp.ObjectName = parts[i];
                        EntryExporter.ExportExportToPackage(exp, destDonorPackage, out portedEntry);
                        portedEntry.idxLink = parent?.UIndex ?? 0;
                        //EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, exp, donorPackage, parent, true, new RelinkerOptionsPackage() { ImportExportDependencies = true }, out var newDonor);
                    }
                }

                var portedExport = portedEntry as ExportEntry;
                if (originalMaterial.IsA("MaterialInstanceConstant"))
                {
                    // If this is multi-layered this won't work fully
                    // But we will try it here anyways
                    // Port expressions over from the original material

                    // Vectors
                    var paramsProp =
                        originalMaterial.GetProperty<ArrayProperty<StructProperty>>("VectorParameterValues");
                    if (paramsProp != null)
                    {
                        portedExport.WriteProperty(paramsProp);
                    }
                    else
                    {
                        // Should these match the original?
                        portedExport.RemoveProperty("VectorParameterValues");
                    }

                    // Scalars
                    paramsProp = originalMaterial.GetProperty<ArrayProperty<StructProperty>>("ScalarParameterValues");
                    if (paramsProp != null)
                    {
                        portedExport.WriteProperty(paramsProp);
                    }
                    else
                    {
                        // Should these match the original?
                        portedExport.RemoveProperty("ScalarParameterValues");
                    }

                    // Textures
                    paramsProp = originalMaterial.GetProperty<ArrayProperty<StructProperty>>("TextureParameterValues");
                    if (paramsProp != null)
                    {
                        // Update object references
                        foreach (var prop in paramsProp)
                        {
                            var paramValue = prop.GetProp<ObjectProperty>("ParameterValue");
                            if (originalMaterial.FileRef.TryGetEntry(paramValue.Value, out var originalTexture))
                            {
                                ExportEntry texture = originalTexture as ExportEntry;
                                if (originalTexture is ImportEntry imp)
                                {
                                    texture = EntryImporter.ResolveImport(imp);

                                    if (texture == null)
                                    {
                                        var containingPackageF =
                                            MilanShared.LE3ObjectDB.GetFilesContainingObject(imp.InstancedFullPath)[0];
                                        var containingPackageP =
                                            MilanShared.GetME3Package(Path.GetFileName(containingPackageF));
                                        texture = containingPackageP.FindExport(imp.InstancedFullPath);
                                    }

                                    if (texture == null)
                                        Debugger.Break();
                                }

                                if (texture == null)
                                    Debugger.Break();

                                EntryExporter.ExportExportToPackage(texture, destDonorPackage, out var _le3Texture, null, new PackageCache(), MilanShared.LE3ObjectDB);
                                paramValue.Value = _le3Texture.UIndex; // Since this is not relinked we will relink it here.
                            }
                            else
                            {
                                // Auto donor failed!!! This requires a manual relink
                            }
                        }
                        portedExport.WriteProperty(paramsProp);
                    }
                    else
                    {
                        // Should these match the original?
                        portedExport.RemoveProperty("TextureParameterValues");
                    }

                    donorIdx++;
                }

                if (!keepAttempting)
                {
                    var package = new ReferenceCheckPackage();
                    EntryChecker.CheckReferences(package, destDonorPackage, LECLocalizationShim.NonLocalizedStringConverter);
                    if (package.GetInfoWarnings().Any())
                    {
                        keepAttempting = true;
                        continue;
                    }

                    foreach (var f in destDonorPackage.Exports.Where(x => x.IsTexture()))
                    {
                        // Unsure how this fixes things.
                        var tex = ObjectBinary.From<UTexture2D>(f);
                        tex.Mips.RemoveAll(x => x.StorageType == StorageTypes.empty);
                        f.WriteBinary(tex);
                    }

                    MilanLog.Information($"  Made an autodonor", customPrefix: LOG_CATEGORY);
                    destDonorPackage.Save();
                }
            }
        }

        // This can easily be optimized with a dictionary. Just doing proof of concept right now.
        private static MatInfo FindMaterial(string parentMaterial) => _materialDB.FirstOrDefault(x => x.InstancedFullPath == parentMaterial);

        private static string GetMaterialDBPath()
        {
            return Path.Combine(SharedMaterialDonor.GetGlobalDonorPath(), "matDonorInfo.json");
        }
    }

    // SirC looking at this like 'why did you not use binpack?'
    class MatInfo
    {
        [JsonProperty("ifp")]
        public string InstancedFullPath { get; set; }

        [JsonProperty("classname")]
        public string ExportClass { get; set; }

        [JsonProperty("textureexpressions")]
        public ObservableCollection<string> TextureExpressions { get; } = new();

        [JsonProperty("scalarexpressions")]
        public ObservableCollection<string> ScalarExpressions { get; } = new();

        [JsonProperty("vectorexpressions")]
        public ObservableCollection<string> VectorExpressions { get; } = new();

        [JsonProperty("children")]
        public ObservableCollection<MatInfo> Children { get; set; } = new();

        [JsonProperty("shaderid")]
        public Guid? ShaderId { get; set; }

        [JsonIgnore]
        public MatInfo Parent { get; set; }

        [JsonProperty("textures")]
        public ObservableCollection<string> Textures { get; } = new();

        /// <summary>
        /// Used only during compile
        /// </summary>
        [JsonIgnore]
        public string ParentIFP { get; set; }

        public void AddShaderId(ExportEntry matExp)
        {
            if (matExp.ClassName == "Material")
            {
                ShaderId = ObjectBinary.From<Material>(matExp).SM3MaterialResource.ID;
            }
            else
            {
                ShaderId = ObjectBinary.From<MaterialInstance>(matExp).SM3StaticPermutationResource.ID;
            }
        }
    }
}
