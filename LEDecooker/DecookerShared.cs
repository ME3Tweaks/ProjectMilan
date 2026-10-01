using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Misc.ME3Tweaks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.IO.Compression;
using System.Text;

namespace LEDecooker
{
    /// <summary>
    /// Shared methods and extensions for decooker and udk conversion.
    /// </summary>
    public static class DecookerShared
    {
        // Cache for ME3Tweaks backup paths so we don't repeatedly call into IO for the same game
        private static readonly ConcurrentDictionary<MEGame, string> GameBackupPathCache = new();
        public static string GetCachedGameBackupPath(MEGame game)
        {
            return GameBackupPathCache.GetOrAdd(game, g => ME3TweaksBackups.GetGameBackupPath(g));
        }


        /// <summary>
        /// Target LE Game's Object DB
        /// </summary>
        public static ObjectInstanceDB TargetObjectDB { get; set; }
        
        public static ObjectInstanceDB LoadObjectDB(MEGame game)
        {
            DecookerLog.Information($"Loading {game} object database");
            using var ms = new MemoryStream(DecookerShared.ExtractResource($@"LEDecooker.supportfiles.supportdbs.zip"));
            using var zip = new ZipArchive(ms);
            var entry = zip.Entries.FirstOrDefault(x => x.Name == $"{game}.bin");
            MemoryStream oms = new MemoryStream((int)entry.Length);
            entry.Open().CopyTo( oms );
            oms.Position = 0;
            return ObjectInstanceDB.Deserialize(game, oms);
        }

        public static string ReadSupportFileString(ZipArchive archive, string fileName)
        {
            foreach (var entry in archive.Entries)
            {
                if (entry.Name == fileName)
                {
                    var sr = new StreamReader(entry.Open(), Encoding.Default);
                    return sr.ReadToEnd();
                }
            }

            DecookerLog.Error($"Did not find support file: {fileName}");
            return null;
        }

        public static Stream ReadSupportFileBinary(ZipArchive archive, string fileName)
        {
            foreach (var entry in archive.Entries)
            {
                if (entry.Name == fileName)
                {
                    return entry.Open();
                }
            }

            DecookerLog.Error($"Did not find support file: {fileName}");
            return null;
        }

        /// <summary>
        /// Takes a forced-export package and converts it to not-self export, like source side packages are laid out
        /// </summary>
        /// <param name="package"></param>
        /// <param name="stripStaticPermutations">Passed to <see cref="PreparePackageForUDKify"/>.</param>
        public static void ConvertPackageToUncooked(this IMEPackage package, string packageName = null, bool stripStaticPermutations = true)
        {
            // Strip off extra stuff if we're entering this method out of main order. (development)
            PreparePackageForUDKify(package, packageName, stripStaticPermutations);

            var selfExp = package.FindExport(packageName ?? package.FileNameNoExtension);

            // Reference objects - we will port the referencer
            var referencedObjects = package.Exports.Where(x => x != selfExp && x.ClassName != "Package").ToList();
            var referencer = package.CreateObjectReferencer();
            referencer.WriteProperty(new ArrayProperty<ObjectProperty>(referencedObjects.Select(x => new ObjectProperty(x)), "ReferencedObjects"));

            // If object is not directly referenced, keep it in package anyways.
            // UDK doesn't use object referencer, we just use it to pull everything in.
            foreach (var obj in referencedObjects.Where(x => x.Parent == null || x.Parent.ClassName == "Package"))
            {
                if (obj.Parent == null || obj.Parent.ClassName == "Package")
                {
                    obj.ObjectFlags |= UnrealFlags.EObjectFlags.Standalone;
                }

                // Objects are transacational... whatever that means. Seems to be used by the editor.
                obj.ObjectFlags |= UnrealFlags.EObjectFlags.Transactional;
            }

            if (selfExp != null)
            {
                // Objects will be lifted out of forced export state
                SetForcedExportFlag(selfExp, false);

                foreach (var obj in package.Exports.Where(x => x.idxLink == selfExp.UIndex).ToList())
                {
                    // Move to top level
                    obj.idxLink = 0;
                }
            }
        }

        /// <summary>
        /// Sets or removes ForcedExport flag on export and its descendents
        /// </summary>
        /// <param name="exp"></param>
        /// <param name="set"></param>
        public static void SetForcedExportFlag(this ExportEntry exp, bool set)
        {

            List<IEntry> entries = exp.GetAllDescendants();
            entries.Add(exp);

            foreach (IEntry entry in entries)
            {
                if (entry is not ExportEntry export) { continue; }

                if (export.ClassName == "ObjectReferencer") { continue; }

                if (set)
                {
                    // Set
                    export.ExportFlags |= UnrealFlags.EExportFlags.ForcedExport;
                }
                else
                {
                    // Strip
                    export.ExportFlags &= ~UnrealFlags.EExportFlags.ForcedExport;
                }
            }
        }


        /// <summary>
        /// Prepares a package for UDK - moves missing textures to a single package, removes static permutations,
        /// removes properties that relink in things that we don't want for UDK
        /// </summary>
        /// <param name="package"></param>
        /// <param name="packageName"></param>
        /// <param name="stripStaticPermutations">
        /// True discards each MaterialInstance's static permutation entirely, so the instance renders
        /// its parent's static switch defaults.
        /// False keeps the StaticParameterSet and blanks only the compiled resource, so the instance
        /// still asks the engine for its own permutation and the engine has to compile it. Both the
        /// decook path (feeds ShaderHost) and UDK conversion pass false: UDK compiles the permutation
        /// itself, and without the set it renders e.g. Volumetric_MM planes fully opaque, which also
        /// makes them cast solid Lightmass shadows.
        /// </param>
        /// <summary>
        /// True when a MaterialInstance's static parameter set actually diverges from its parent's
        /// defaults. The set carries the parent's whole parameter list; only entries flagged
        /// bOverride are the instance's own, so a set with none of them describes no permutation.
        /// </summary>
        /// <remarks>
        /// Kept in step with <c>MilanShaderHost.StaticPermutationNaming.HasAnyOverride</c>, which asks
        /// the same question on the ShaderHost side. Inlined rather than shared because LEDecooker
        /// references only LegendaryExplorerCore, and this predicate is three field reads.
        /// </remarks>
        private static bool OverridesAnything(StaticParameterSet set) =>
            set != null
            && (set.StaticSwitchParameters.Any(p => p.bOverride)
                || set.StaticComponentMaskParameters.Any(p => p.bOverride)
                || set.NormalParameters.Any(p => p.bOverride));

        public static void PreparePackageForUDKify(this IMEPackage package, string packageName = null, bool stripStaticPermutations = true)
        {
            // Move all unfound textures to a single package
            var nonshippingTextures = package.Imports.Where(x => x.idxLink == 0 && x.IsTexture()).ToList();
            if (nonshippingTextures.Any())
            {
                var nonship = ExportCreator.CreatePackageImport(package, "MissingTextures");
                foreach (var tex in nonshippingTextures)
                {
                    tex.idxLink = nonship.UIndex;
                }
            }

            var pPackage = ExportCreator.CreatePackageExport(package, packageName ?? package.FileNameNoExtension);
            var rootExports = package.Exports.Where(x => x != pPackage && x.idxLink == 0);
            foreach (var rootExport in rootExports)
            {
                rootExport.idxLink = pPackage.UIndex;
            }

            pPackage.SetForcedExportFlag(true);


            // MIC - static permutations.
            //
            // Static switch / component mask / normal parameters are compile-time: they select a
            // subgraph, a channel, or a normal unpack range. Nothing at runtime can re-apply them, so
            // an instance that loses its permutation renders its parent's defaults instead. That is a
            // rendering change, not just a performance one -- see ShaderResearchTool HANDOFF Section 26,
            // which measured 8391 affected instances across 2387 distinct parameter sets.
            foreach (var mic in package.Exports.Where(x => x.IsA("MaterialInstance")))
            {
                var hasPerm = mic.GetProperty<BoolProperty>("bHasStaticPermutationResource");
                if (hasPerm?.Value != true)
                {
                    continue;
                }

                if (stripStaticPermutations)
                {
                    mic.RemoveProperty("bHasStaticPermutationResource");
                    mic.WriteBinary([]);
                    continue;
                }

                // Keep the parameter set -- it is the only record of what the instance asked for --
                // but blank the compiled resources. Retaining the ported ones would leave a shader map
                // ID pointing at shaders this package does not contain, and the engine would bind that
                // stale map instead of compiling, which is the opposite of what the capture needs.
                try
                {
                    var mi = ObjectBinary.From<MaterialInstance>(mic);

                    // An instance whose set overrides nothing resolves to its parent's shader map, so
                    // the engine never compiles a permutation for it and the blanked resource below
                    // stays blank forever. bHasStaticPermutationResource is what decides which resource
                    // UMaterialInstance::GetMaterialResource() hands back, so leaving the flag on with an
                    // empty resource gives the instance *no shaders at all* -- strictly worse than the
                    // strip this branch replaced, which at least fell back to the parent's defaults.
                    //
                    // Strip those. Only an instance that genuinely diverges has a permutation to keep.
                    if (!OverridesAnything(mi.SM3StaticParameterSet))
                    {
                        mic.RemoveProperty("bHasStaticPermutationResource");
                        mic.WriteBinary([]);
                        continue;
                    }

                    mi.SM3StaticPermutationResource = MaterialResource.Create();
                    // SM3 is the only block the games read. SM2 is blanked purely so no stale
                    // UIndex-bearing resource is carried into the rebuild; nothing ever installs to it.
                    mi.SM2StaticPermutationResource = MaterialResource.Create();
                    mic.WriteBinary(mi);
                }
                catch (Exception e)
                {
                    // A MIC whose binary will not round-trip is worse than one without a permutation:
                    // it can fail to load at all. Fall back to the old behaviour and say so.
                    DecookerLog.Warning($@"Could not preserve static permutation on {mic.InstancedFullPath}: {e.Message}. Stripping it instead.");
                    mic.RemoveProperty("bHasStaticPermutationResource");
                    mic.WriteBinary([]);
                }
            }

            foreach (var mat in package.Exports.Where(x => x.IsA("Material")))
            {
                // These won't exist in UDK.
                mat.RemoveProperty("PhysMaterial");
            }
        }

        public static byte[] ExtractResource(string filename)
        {
            System.Reflection.Assembly a = System.Reflection.Assembly.GetExecutingAssembly();
#if DEBUG
            var resources = a.GetManifestResourceNames(); // For reviewing.
#endif
            using (Stream resFilestream = a.GetManifestResourceStream(filename))
            {
                if (resFilestream == null)
                {
                    Debugger.Break();
                    return null; // Asset not found
                }
                    byte[] ba = new byte[resFilestream.Length];
                resFilestream.Read(ba, 0, ba.Length);
                return ba;
            }
        }

        public static IMEPackage OpenPackage(string path, MEGame sourceGame)
        {
            path = Path.Combine(DecookerShared.GetCachedGameBackupPath(sourceGame), path.TrimStart('\\', '/'));
            return new SFARPackageCache().GetCachedPackage(path);
        }

        /// <summary>
        /// Relinks as imports for things outside of the linker
        /// </summary>
        /// <param name="importingpcc"></param>
        /// <param name="relinkingexport"></param>
        /// <param name="uindex"></param>
        /// <param name="propertyname"></param>
        /// <param name="prefix"></param>
        /// <param name="rop"></param>
        /// <param name="result"></param>
        /// <returns></returns>
        public static bool ImportOutsideOfPackageRelink(IMEPackage importingpcc, ExportEntry relinkingexport, ref int uindex, string propertyname, string prefix, RelinkerOptionsPackage rop, out EntryStringPair result)
        {
            result = null;

            var oIndex = uindex;
            if (uindex == 0)
                return false;

            // Relink to 0, we don't want this
            if (propertyname.CaseInsensitiveEquals("PhysMaterial"))
            {
                uindex = 0;
                return true;
            }

            if (propertyname.CaseInsensitiveEquals("Parent") && relinkingexport.IsA("MaterialInstance"))
            {
                // Check if the parent is a RvrEffectsMaterialUser - UDK does not support this
                // We will relink parent up the parent material instead
                if (importingpcc.GetEntry(uindex) is IEntry parentEntry && parentEntry.ClassName.CaseInsensitiveEquals("RvrEffectsMaterialUser") && relinkingexport.IsA("MaterialInstance"))
                {
                    // Parent is a RvrMaterialUser
                    // Get property on it and relink to it instead.

                    DecookerLog.Information("\t\t\tPassing through parent of RvrEffectsMaterialUser");

                    // This export must be resolved!
                    ExportEntry rvr = parentEntry as ExportEntry;
                    if (parentEntry is ImportEntry imp)
                    {
                        var resolved = EntryImporter.ResolveImport(imp, rop.Cache);
                        if (resolved == null)
                        {
                            Debugger.Break();
                        }
                        rvr = resolved; // This is from another package! The UIndex will be for that package!
                    }

                    bool fromAnotherPackage = false;

                    var baseMatObj = rvr.GetProperty<ObjectProperty>("m_pBaseMaterial");
                    var baseMatRef = baseMatObj.ResolveToExport(rvr.FileRef, rop.Cache);
                    var originalUIndex = uindex;
                    uindex = baseMatRef.UIndex; // We're going to retrigger this method but use a different source export.

                    if (ImportOutsideOfPackageRelink(baseMatRef.FileRef, relinkingexport, ref uindex, propertyname, prefix, rop, out result))
                    {
                        return true; // We took care of this
                    }

                    // Restore the original uindex; we are going to be using the normal code path
                    uindex = originalUIndex;
                }
            }

            var sourceEntry = importingpcc.GetEntry(uindex);
            if (sourceEntry == null)
            {
                relinkingexport.FileRef.Save();
                Debugger.Break();
            }
            var linker = sourceEntry.GetLinker();
            if (!linker.CaseInsensitiveEquals(relinkingexport.FileRef.FileNameNoExtension))
            {
                // Outside of package!
                // Generate imports for this object...
                uindex = GenerateImportForObject(sourceEntry, relinkingexport.FileRef).UIndex;
                return true;
            }
            else
            {
                // Inside this package

                // Maybe the path is wrong from T3D. Do we have an export with same name and class under teh root, since we don't have path info?
                var existingDiffLevel = relinkingexport.FileRef.FindExport($"{relinkingexport.FileRef.FileNameNoExtension}.{sourceEntry.ObjectName.Instanced}", sourceEntry.ClassName);
                if (existingDiffLevel != null)
                {
                    uindex = existingDiffLevel.UIndex;

                    if (sourceEntry.HasParent)
                    {
                        // Try to move object to where it should be...
                        var parent = relinkingexport.FileRef.FindExport(sourceEntry.Parent.MemoryFullPath,
                                         sourceEntry.Parent.ClassName)
                                     ?? relinkingexport.FileRef.FindExport(
                                         sourceEntry.Parent.MemoryFullPath.Substring(sourceEntry.GetLinker().Length +
                                             1), sourceEntry.Parent.ClassName);


                        if (parent != null)
                        {
                            // Do not move a copy under if it already exists. We probably DO want the root obj.
                            // This is true for LE3 biot_rubble.Rubble_Decal_MM which has 2 same-named items in package at different levels with same classname.

                            var testIFP = $"{parent.InstancedFullPath}.{sourceEntry.ObjectName.Instanced}";
                            var testObj = relinkingexport.FileRef.FindExport(testIFP, sourceEntry.ClassName);

                            if (testObj != null)
                            {
                                // Nest under correct path.
                                existingDiffLevel.idxLink = parent.UIndex;
                            }
                        }
                    }

                    return true;
                }

                // We must check it isn't an import - we MUST use exports
                if (sourceEntry is ImportEntry ie)
                {
                    // We cannot have imports inside of ourself!
                    // Try linker.
                    if (MELoadedFiles.GetFilesLoadedInGame(ie.Game).TryGetValue($"{linker}.pcc", out var selfPackage))
                    {
                        if (ImportObject(selfPackage, ie, ref uindex, null))
                        {
                            return true;
                        }
                    }

                    // We still don't have anything!
                    var sourceObj = TargetObjectDB.GetFilesContainingObject(sourceEntry.InstancedFullPath);
                    if (sourceObj != null)
                    {
                        var firstFile = Path.Combine(ME3TweaksBackups.GetGameBackupPath(ie.Game), sourceObj[0]);
                        if (ImportObject(firstFile, ie, ref uindex, null))
                        {
                            return true;
                        }
                    }

                    // We cannot use this import
                     Debugger.Break();
                }

                // An export being ported in within our linker might be coming from a global-only package, which will trigger it to port as an import
                // We do not want that

                if (sourceEntry is ExportEntry ee)
                {
                    if (EntryImporter.IsSafeToImportFrom(ee.FileRef.FilePath, relinkingexport.FileRef, false))
                    {
                        // We must not allow imports to be generated here
                        var origName = ee.FileRef.FileNameNoExtension;
                        ee.FileRef.SetInternalFilepath($@"NOIMPORT_{origName}.pcc");

                        // This may trigger a double relink
                        EntryExporter.ExportExportToPackage(ee, relinkingexport.FileRef, out var ported, rop.Cache, rop);
                        rop?.CrossPackageMap.Clear(); // Do not persist this value, we do not want double relink
                        uindex = ported.UIndex;
                        ee.FileRef.SetInternalFilepath(origName);
                        return true;
                    }
                }
                return false;
            }

            return true;


            bool ImportObject(string sPackagePath, IEntry sIe, ref int sUIndex, IMEPackage tempPackage)
            {
                // looks like a seek free

                bool restoreName = EntryImporter.IsSafeToImportFrom(sIe.FileRef.FilePath, relinkingexport.FileRef, false);
                string origName = sIe.FileRef.FileNameNoExtension;
                if (restoreName)
                {
                    // We must not allow imports to be generated here
                    sIe.FileRef.SetInternalFilepath($@"NOIMPORT_{origName}.pcc");
                }

                if (tempPackage == null)
                {
                    var fullLoad = sIe.ClassName != "Texture2D" || Path.GetFileNameWithoutExtension(sPackagePath).StartsWith("BIOG_");
                    if (!fullLoad)
                    {
                        tempPackage = DecookerShared.OpenPackage(sPackagePath, sIe.FileRef.Game);
                        // This doesn't open SFAR
                        //MEPackageHandler.UnsafePartialLoad(sPackagePath,
                        //    x => x.MemoryFullPath == sIe.MemoryFullPath || x.ClassName is "TextureCube" or "Package"); // Or for parent porting.
                    }
                    else
                    {
                        tempPackage = DecookerShared.OpenPackage(sPackagePath, sIe.FileRef.Game);
                        //tempPackage = MEPackageHandler.OpenMEPackage(sPackagePath);
                        EntryExporter.PrepareGlobalFileForPorting(tempPackage, tempPackage.FileNameNoExtension);
                    }
                }

                var exp = tempPackage.FindExport(sIe.InstancedFullPath, sIe.ClassName) ?? tempPackage.FindExport(sIe.InstancedFullPath.Substring(tempPackage.FileNameNoExtension.Length + 1), sIe.ClassName);
                if (exp != null)
                {
                    // This may trigger a double relink
                    EntryExporter.ExportExportToPackage(exp, relinkingexport.FileRef, out var ported, rop.Cache, rop);
                    rop?.CrossPackageMap.Clear(); // Do not persist this value, we do not want double relink
                    sUIndex = ported.UIndex;

                    if (restoreName)
                    {
                        sIe.FileRef.SetInternalFilepath(origName);
                    }

                    return true;
                }

                // Object not found :(
                if (restoreName)
                {
                    sIe.FileRef.SetInternalFilepath(origName);
                }
                return false;
            }
        }


        public static ImportEntry GenerateImportForObject(IEntry sourceEntry, IMEPackage package)
        {
            // Build order to do things
            var objectChain = new List<IEntry>();
            var temp = sourceEntry;
            objectChain.Insert(0, temp);
            while (temp.HasParent)
            {
                temp = temp.Parent;
                objectChain.Insert(0, temp);
            }

            ImportEntry currentParent = null;
            foreach (var obj in objectChain)
            {
                // Check if parent already exists in package
                // These will never be exports, so we only check imports
                ImportEntry tempParent = package.FindImport(obj.InstancedFullPath, obj.ClassName);
                if (tempParent != null)
                {
                    currentParent = tempParent;
                    continue;
                }

                // Creating parent object
                ImportEntry packageImp = new ImportEntry(package)
                {
                    ClassName = obj.ClassName,
                    PackageFile = ImportEntry.GetPackageFile(package.Game, obj.ClassName),
                    ObjectName = obj.ObjectName,
                    idxLink = currentParent?.UIndex ?? 0
                };
                package.AddImport(packageImp);
                currentParent = packageImp;
            }

            return currentParent;
        }
    }
}
