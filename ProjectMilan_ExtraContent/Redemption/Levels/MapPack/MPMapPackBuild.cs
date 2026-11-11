using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.PhysX;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using ProjectMilan;
using ProjectMilan_ExtraContent.Redemption.Levels.CrossGenV;
using ProjectMilan_ExtraContent.Shared;
using ProjectMilan_ExtraContent.Redemption;
using ProjectMilan_ExtraContent.Redemption.Levels;
using ProjectMilanCore;
using System;
using System.Collections.Generic;
using System.Numerics;
using System.Text;
using LegendaryExplorerCore.Misc;
using ProjectMilan.Utility;

namespace ProjectMilan_ExtraContent.Redemption.Levels.MapPack
{

    /// <summary>
    /// Handles the conversion from Redemption (DLC_MOD_MPMapPack) to Project Milan. This does not directly port, rather it rebuilds the content.
    /// </summary>
    internal class MPMapPackBuild
    {
        private const string LOG_CATEGORY = "MILAN-ExtraContent-MPMapPack";

        /// <summary>
        /// Where the OT source files live
        /// </summary>
        private static readonly string MPMapPackSourceFolder = Path.Combine(Utilities.GetModManagerLibraryPath(), @"ME3", "Redemption MP Map Pack", "DLC_MOD_MPMapPack", "CookedPCConsole");

        internal static void BuildLevels()
        {
            if (!Directory.Exists(MPMapPackSourceFolder))
            {
                MilanLog.Warning($"Redemption DLC Map Pack folder not found at {MPMapPackSourceFolder}, skipping build of MPMapPack levels.");
                return;
            }

            MilanLog.Information("Building Redemption DLC mod maps", customPrefix: LOG_CATEGORY);
            var manifestsFolder = Path.Combine(SharedECPipelines.ECPipelineRoot, "Redemption", "Levels", "MapPack", "ChangeManifests");
            var manifests = Directory.GetFiles(manifestsFolder, "*.json", SearchOption.TopDirectoryOnly).Select(x => File.ReadAllText(x)).Select(JsonConvert.DeserializeObject<MapManifest>);
            var copiedFiles = new CaseInsensitiveDictionary<string>(); // List of copied sublevels to prevent dupes
            foreach (var manifest in manifests)
            {
                BuildSingleLevel(manifest, copiedFiles);
            }
        }

        /// <summary>
        /// Entry point to building a single level using the differencing data from Redemption Map Pack.
        /// </summary>
        /// <param name="manifest"></param>
        internal static void BuildSingleLevel(MapManifest manifest, CaseInsensitiveDictionary<string> copiedFiles)
        {
            MilanLog.Information($"Building level {manifest.MasterPackage} from manifest {manifest.SourceFile}", customPrefix: LOG_CATEGORY);
            var outputFolder = Path.Combine(MilanPipelinesShared.OutputModPath, "CookedPCConsole", "Levels", manifest.MasterPackage);
            Directory.CreateDirectory(outputFolder);
            BuildLevelMaster(manifest, outputFolder);
            CopySublevels(manifest, outputFolder, copiedFiles);
            CopyMapImage(manifest);
            RegisterMap(manifest);
        }

        private static void CopyMapImage(MapManifest manifest)
        {
            var sourceImage = manifest.DisplayInfo?.Image;
            if (sourceImage == null)
            {
                MilanLog.Error($"  No map image set");
                return;
            }
            var sourceImageParts = sourceImage.Split('.');
            var sourcePackagePath = Path.Combine(MPMapPackSourceFolder, "SFXMPImagesMatchSettings.pcc");
            if(File.Exists(sourcePackagePath))
            {
                MilanLog.Information($"  Transfering map image {sourceImage}", customPrefix: LOG_CATEGORY);
                using var sourcePackage = MEPackageHandler.UnsafePartialLoad(sourcePackagePath, x => x.ObjectName == sourceImageParts.Last());
                var destPackage = RedemptionShared.GetMapImagesPackage();
                var sourceObj = sourcePackage.FindExport(sourceImage);

                // Precorrect to reduce extra crap coming over
                var inPackageExport = sourcePackage.CreatePackageExport(RedemptionShared.DLM_MAP_PACKAGE_EXPORT_NAME);
                sourceObj.idxLink = inPackageExport.UIndex; // Re-nest so it transfers over under this parent
                sourceObj.ObjectName = $"OptMap{RedemptionShared.GetMapBaseName(manifest.MasterPackage)}";

                EntryExporter.ExportExportToPackage(sourceObj, destPackage, out var newItem);
                var newExp = newItem as ExportEntry;
                newExp.SetForcedExportFlag(true); // This is required for dynamic load - load package, find object in it - very weird, it isn't a seek free load. Maybe required by GUI?
            }
            else
            {
                MilanLog.Warning($"  Map image {sourceImage} not found in Redemption MPMapPack source folder - skipping transfer", customPrefix: LOG_CATEGORY);
            }
        }

        /// <summary>
        /// Registers this map in the mastermaplist config using the original mod's display text
        /// (name/description/GAW subtitle), resolved per-language by RedemptionMapTool from the OT mod's own
        /// Coalesced config + TLK. New StrRef IDs are assigned via RedemptionShared's existing counter rather
        /// than reusing the OT mod's own IDs, which are far too high to be safe for this project's own content.
        /// </summary>
        private static void RegisterMap(MapManifest manifest)
        {
            var info = new ECLevelInfo
            {
                MapName = manifest.MasterPackage,
                LevelNameString = manifest.DisplayInfo?.PrettyName,
                LevelDescriptionString = manifest.DisplayInfo?.Description,
                GAWMapSubtitle = manifest.DisplayInfo?.GAWMapSubtitle,
                GAWMapPosition = new Vector2(manifest.DisplayInfo?.GAWMapPositionX ?? 0, manifest.DisplayInfo?.GAWMapPositionY ?? 0)
            };
            RedemptionShared.AddLevelToConfig(info);
        }

        /// <summary>
        /// Locates each of the manifest's sublevels in the vanilla LE3 game files and copies it into the level's
        /// output folder under its (possibly renamed) manifest package name. Some sublevels were renamed by the
        /// original Redemption mod from their original shipping LE3 package name - <see cref="SublevelManifest.SourceFile"/>
        /// (resolved by RedemptionMapTool via package guid matching) carries that original name when it's known.
        /// Sublevels that can't be found are only reported - they're likely custom assets with no vanilla original.
        /// </summary>
        private static void CopySublevels(MapManifest manifest, string outputFolder, CaseInsensitiveDictionary<string> copiedFiles)
        {
            var loadedFiles = MELoadedFiles.GetFilesLoadedInGame(MEGame.LE3);
            var sublevelDataByName = manifest.SublevelData.ToDictionary(x => x.PackageName, x => x, StringComparer.OrdinalIgnoreCase);
            var missing = new List<string>();

            foreach (var sublevel in manifest.Sublevels)
            {
                var sublevelData = sublevelDataByName.GetValueOrDefault(sublevel);
                var sourceFileName = sublevelData?.SourceFile ?? $"{sublevel}.pcc";

                if (!loadedFiles.TryGetValue(sourceFileName, out var sourcePath))
                {
                    MilanLog.Warning($"  Sublevel not found in LE3: {sourceFileName} (manifest name {sublevel}) - likely a custom asset with no vanilla original", customPrefix: LOG_CATEGORY);
                    missing.Add(sublevel);
                    continue;
                }

                // Check if file already copied to DLC - e.g. BioSnd_CitSim is used by all the levels but we only want one copy
                if (copiedFiles.TryGetValue(sourceFileName, out var existingDest))
                {
                    var dirParent = Directory.GetParent(existingDest)?.Name;
                    if (dirParent == "Shared")
                    {
                        MilanLog.Information($"  Sublevel {sourceFileName} already copied to DLC as {existingDest} - skipping duplicate copy", customPrefix: LOG_CATEGORY);
                    }
                    else
                    {
                        // Move it to shared.
                        MilanLog.Information($"  Sublevel {sourceFileName} already copied to DLC as {existingDest} - moving to Shared", customPrefix: LOG_CATEGORY);
                        var shared = Path.Combine(outputFolder, "..", "Shared");
                        Directory.CreateDirectory(shared);
                        var finalShared = Path.Combine(shared, Path.GetFileName(existingDest));
                        File.Move(existingDest, finalShared);
                        copiedFiles[sourceFileName] = finalShared; // Update target to shared for future copies
                    }

                    continue;
                }

                var destPath = Path.Combine(outputFolder, $"{sublevel}.pcc");
                MilanLog.Information($"  Copying sublevel {sourceFileName} -> {Path.GetFileName(destPath)}", customPrefix: LOG_CATEGORY);
                File.Copy(sourcePath, destPath, true);
                copiedFiles[sourceFileName] = destPath;

                ClearMainSequence(destPath);

                if (sublevelData is { EnemySpawnPoints.Count: > 0 })
                {
                    ConvertEnemySpawnPoints(destPath, sublevelData.EnemySpawnPoints);
                }

                if (sublevelData is { ObjectiveSpawnPoints.Count: > 0 })
                {
                    CreateObjectiveSpawnPoints(destPath, sublevelData.ObjectiveSpawnPoints);
                }
            }

            if (missing.Count > 0)
            {
                MilanLog.Warning($"{missing.Count} sublevel(s) for {manifest.MasterPackage} were not found and were not copied: {string.Join(", ", missing)}", customPrefix: LOG_CATEGORY);
            }
        }

        /// <summary>
        /// Converts existing pathfinding nodes in the freshly-copied vanilla sublevel back into
        /// SFXEnemySpawnPoint, mirroring what the original Redemption mod did by hand in the OT file.
        /// Since object names/indices aren't consistent between OT and LE, each manifest entry is matched to
        /// a candidate node by its recorded location - the mod only ever repositioned the class of an existing
        /// node, never its place in the level, so an exact (or near-exact) location match is a very strong signal
        /// it's the same node. Candidates are restricted to actors that themselves expose a MaxPathSize (i.e.
        /// other NavigationPoint-derived pathfinding nodes) so we don't accidentally grab an unrelated actor -
        /// like a BioBlockingVolume - that happens to sit at the same spot as a node.
        /// </summary>
        private static void ConvertEnemySpawnPoints(string packagePath, List<EnemySpawnPointEntry> entries)
        {
            using var package = MEPackageHandler.OpenMEPackage(packagePath, diskIOSyncLock: MilanShared.DiskIOSyncLock);
            var rop = new RelinkerOptionsPackage { ImportExportDependencies = true };

            var nodeClassImport = EntryImporter.EnsureClassIsInFile(package, "SFXEnemySpawnPoint", rop);
            if (nodeClassImport is null)
            {
                MilanLog.Warning($"  !! Could not resolve SFXEnemySpawnPoint class in {Path.GetFileName(packagePath)} - skipping enemy spawn point conversion", customPrefix: LOG_CATEGORY);
                return;
            }

            var cylinderArchetype = CrossGenVShared.GetImportArchetype(package, "SFXGame", "Default__SFXEnemySpawnPoint.CollisionCylinder");

            // Other pathfinding nodes (has its own MaxPathSize) that aren't already a spawn point.
            var candidates = package.Exports
                .Where(x => x.ClassName != "SFXEnemySpawnPoint" && x.GetProperty<StructProperty>("MaxPathSize") != null)
                .ToList();

            var convertedCount = 0;
            foreach (var entry in entries)
            {
                var entryLocation = new Vector3(entry.Location.X, entry.Location.Y, entry.Location.Z);

                ExportEntry match = null;
                var bestDistance = float.MaxValue;
                foreach (var candidate in candidates)
                {
                    var candidateLocation = CommonStructs.GetVector3(candidate.GetProperty<StructProperty>("location"));
                    var distance = Vector3.Distance(candidateLocation, entryLocation);
                    if (distance < 1.0f && distance < bestDistance)
                    {
                        bestDistance = distance;
                        match = candidate;
                    }
                }

                if (match is null)
                {
                    MilanLog.Warning($"  !! {Path.GetFileName(packagePath)}: no existing node found near {entry.ObjectName} at {entryLocation} - it may be new or moved in the OT source. Needs manual review.", customPrefix: LOG_CATEGORY);
                    continue;
                }

                candidates.Remove(match); // don't let a second entry claim the same node

                ConvertNodeToEnemySpawnPoint(package, match, entry, nodeClassImport, cylinderArchetype, rop);
                convertedCount++;
            }

            if (convertedCount > 0)
            {
                MilanLog.Information($"  Converted {convertedCount}/{entries.Count} enemy spawn point(s) in {Path.GetFileName(packagePath)}", customPrefix: LOG_CATEGORY);
                package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
            }
        }

        /// <summary>
        /// Converts a single matched export in place to SFXEnemySpawnPoint: reclasses it, points its collision
        /// cylinder at the SFXEnemySpawnPoint archetype, and applies the manifest's recorded MaxPathSize and
        /// SupportedReachSpecs (the only two SFXEnemySpawnPoint-specific properties actually authored on any of
        /// these instances - everything else on the manifest entry is either OT-file-specific and not
        /// transferable (PathList, Base, NavGuid, cached pathfinding weights) or reachspec work that isn't in
        /// scope yet).
        /// </summary>
        private static void ConvertNodeToEnemySpawnPoint(IMEPackage package, ExportEntry node, EnemySpawnPointEntry entry, IEntry nodeClassImport, IEntry cylinderArchetype, RelinkerOptionsPackage rop)
        {
            var originalClass = node.ClassName;

            var maxPathSize = entry.Properties.GetValueOrDefault("MaxPathSize") as JObject;
            if (maxPathSize != null)
            {
                var existing = node.GetProperty<StructProperty>("MaxPathSize");
                var newRadius = maxPathSize.Value<float>("Radius");
                var newHeight = maxPathSize.Value<float>("Height");
                if (existing != null)
                {
                    var oldRadius = existing.GetProp<FloatProperty>("Radius")?.Value ?? 0;
                    var oldHeight = existing.GetProp<FloatProperty>("Height")?.Value ?? 0;
                    if (Math.Abs(oldRadius - newRadius) > 0.01f || Math.Abs(oldHeight - newHeight) > 0.01f)
                    {
                        MilanLog.Information($"    {entry.ObjectName} -> {node.InstancedFullPath}: resized on conversion ({oldRadius}/{oldHeight} -> {newRadius}/{newHeight})", customPrefix: LOG_CATEGORY);
                    }
                }

                node.WriteProperty(CrossGenVShared.CreateCylinder(newRadius, newHeight, "MaxPathSize"));
            }

            if (entry.Properties.GetValueOrDefault("SupportedReachSpecs") is JArray supportedReachSpecs && supportedReachSpecs.Count > 0)
            {
                var reachSpecClasses = new List<ObjectProperty>();
                foreach (var reachSpecClassPath in supportedReachSpecs.Values<string>())
                {
                    var bareClassName = reachSpecClassPath.Split('.')[^1];
                    var reachSpecClassImport = EntryImporter.EnsureClassIsInFile(package, bareClassName, rop);
                    if (reachSpecClassImport != null)
                    {
                        reachSpecClasses.Add(new ObjectProperty(reachSpecClassImport.UIndex));
                    }
                }

                node.WriteProperty(new ArrayProperty<ObjectProperty>(reachSpecClasses, "SupportedReachSpecs"));
            }

            // Re-point the collision cylinder at the SFXEnemySpawnPoint archetype so it inherits that class's
            // defaults, then reclass and rename the node itself to match.
            if (node.GetProperty<ObjectProperty>("CollisionComponent")?.ResolveToEntry(package) is ExportEntry cylinderExport && cylinderArchetype != null)
            {
                cylinderExport.Archetype = cylinderArchetype;
            }

            node.Class = nodeClassImport;
            node.ObjectName = "SFXEnemySpawnPoint";
            ReindexMatchingObjects(node);

            MilanLog.Information($"    Converted {node.ObjectName.Instanced} (was {originalClass})", customPrefix: LOG_CATEGORY);
        }

        /// <summary>
        /// Reindexes every export sharing this one's full path so duplicate object names stay unique after a
        /// class-driven rename (e.g. several nodes all renamed to "SFXEnemySpawnPoint" under the same parent).
        /// </summary>
        private static void ReindexMatchingObjects(ExportEntry exportToReindex)
        {
            var fullPath = exportToReindex.FullPath;
            var index = 1;
            foreach (var export in exportToReindex.FileRef.Exports)
            {
                if (fullPath == export.FullPath && !export.IsClass)
                {
                    export.indexValue = index;
                    index++;
                }
            }
        }

        /// <summary>
        /// Creates brand-new SFXOperation_ObjectiveSpawnPoint actors in the copied sublevel from manifest data.
        /// Unlike enemy spawn points, these were never converted from existing OT nodes - the mod placed them
        /// fresh - so there's nothing to match against; we just build each one from scratch (mirroring
        /// BuildStartLocationMP's actor+CylinderComponent pattern) and let MilanLevelTools.RebuildPersistentLevelChildren
        /// pick them up into the level's Actors list afterward.
        /// </summary>
        private static void CreateObjectiveSpawnPoints(string packagePath, List<ObjectiveSpawnPointEntry> entries)
        {
            using var package = MEPackageHandler.OpenMEPackage(packagePath, diskIOSyncLock: MilanShared.DiskIOSyncLock);
            var persistentLevel = package.GetLevel();
            var cylinderArchetype = CrossGenVShared.GetImportArchetype(package, "SFXGame", "Default__SFXOperation_ObjectiveSpawnPoint.CollisionCylinder");

            foreach (var entry in entries)
            {
                var spawnPoint = ExportCreator.CreateExport(package, "SFXOperation_ObjectiveSpawnPoint", "SFXOperation_ObjectiveSpawnPoint", persistentLevel);
                spawnPoint.WriteProperty(CommonStructs.Vector3Prop(entry.Location.X, entry.Location.Y, entry.Location.Z, "location"));
                spawnPoint.WriteProperty(CommonStructs.RotatorProp(entry.Rotation.Pitch, entry.Rotation.Yaw, entry.Rotation.Roll, "Rotation"));

                if (!string.IsNullOrEmpty(entry.Tag))
                {
                    spawnPoint.WriteProperty(new NameProperty(entry.Tag, "Tag"));
                }

                if (entry.SupportedSpawnTags.Count > 0)
                {
                    spawnPoint.WriteProperty(new ArrayProperty<StrProperty>(entry.SupportedSpawnTags.Select(x => new StrProperty(x)), "SupportedSpawnTags"));
                }

                if (!string.IsNullOrEmpty(entry.SpawnLocation))
                {
                    spawnPoint.WriteProperty(new EnumProperty(entry.SpawnLocation, "EObjectiveLocation", package.Game, "SpawnLocation"));
                }

                var cylinderComp = ExportCreator.CreateExport(package, "CylinderComponent", "CylinderComponent", spawnPoint);
                cylinderComp.WritePrePropsAndProperties(new byte[4], cylinderComp.GetProperties()); // NetIndex slot
                cylinderComp.WriteProperty(new ObjectProperty(0, "ReplacementPrimitive"));
                if (cylinderArchetype != null)
                {
                    cylinderComp.Archetype = cylinderArchetype;
                }

                spawnPoint.WriteProperty(new ObjectProperty(cylinderComp, "CollisionComponent"));

                MilanLog.Information($"    Created objective spawn point {spawnPoint.ObjectName.Instanced} at {entry.Location.X}, {entry.Location.Y}, {entry.Location.Z}", customPrefix: LOG_CATEGORY);
            }

            MilanLevelTools.RebuildPersistentLevelChildren(persistentLevel);
            package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
        }

        /// <summary>
        /// Multiplayer doesn't use Kismet on these levels for now - clears out the sequence objects on the
        /// copied sublevel's Main_Sequence.
        /// </summary>
        private static void ClearMainSequence(string packagePath)
        {
            using var package = MEPackageHandler.OpenMEPackage(packagePath, diskIOSyncLock: MilanShared.DiskIOSyncLock);
            var mainSequence = package.FindExport("TheWorld.PersistentLevel.Main_Sequence");
            if (mainSequence == null)
            {
                MilanLog.Warning($"  {Path.GetFileName(packagePath)} has no TheWorld.PersistentLevel.Main_Sequence", customPrefix: LOG_CATEGORY);
                return;
            }

            mainSequence.WriteProperty(new ArrayProperty<ObjectProperty>("SequenceObjects"));
            package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
        }

        /// <summary>
        /// Builds the BioP_ for the given manifest
        /// </summary>
        /// <param name="manifest"></param>
        internal static void BuildLevelMaster(MapManifest manifest, string outputFolder)
        {
            // use MPLevel.pcc - it's already set up for MP wwise stuff, and has the correct archetypes for BioStartLocationMP
            var biopPath = Path.Combine(outputFolder, $"{manifest.MasterPackage}.pcc");
            var templateBioP = Path.Combine(SharedECPipelines.ECPipelineRoot, "Redemption", "Assets", "Templates", "MPLevel.pcc");
            File.Copy(templateBioP, biopPath, true);
            var mapPackage = MEPackageHandler.OpenMEPackage(biopPath);

            mapPackage.LECLTagData.ImportHintFiles.Add(MilanShared.MP_STARTUP_FILENAME); // Hint this file

            var persistentLevel = mapPackage.GetLevel();
            var theWorld = mapPackage.FindEntry("TheWorld");

            // Add trigger stream, start locations, level streaming kismets, streaming states.
            foreach (var startLocation in manifest.StartLocations.OrderBy(x => x.Index))
            {
                BuildStartLocationMP(mapPackage, persistentLevel, startLocation);
            }

            // LevelStreamingKismet lives under TheWorld directly (not PersistentLevel) for our level masters.
            foreach (var sublevel in manifest.Sublevels)
            {
                var kismet = ExportCreator.CreateExport(mapPackage, "LevelStreamingKismet", "LevelStreamingKismet", theWorld);
                kismet.WriteProperty(new NameProperty(sublevel, "PackageName"));
            }

            BuildTriggerStream(mapPackage, persistentLevel, manifest.Sublevels);

            // Set respawn floor
            var bwi = mapPackage.GetBioWorldInfo();
            bwi.WriteProperty(new FloatProperty(manifest.KillZ, "KillZ"));


            MilanLevelTools.SetupHordeModes(mapPackage, false); // GameTypesSupportedOnThisMap = SFXGameInfoMP, SFXGameType_Horde_Operation

            MilanLevelTools.RebuildStreamingLevels(mapPackage, LOG_CATEGORY);
            MilanLevelTools.RebuildPersistentLevelChildren(persistentLevel);

            mapPackage.Save();
        }

        /// <summary>
        /// Builds a single BioStartLocationMP actor (with its CylinderComponent) from manifest data.
        /// </summary>
        private static void BuildStartLocationMP(IMEPackage package, IEntry persistentLevel, StartLocationEntry startLocation)
        {
            var startLoc = ExportCreator.CreateExport(package, "BioStartLocationMP", "BioStartLocationMP", persistentLevel);
            startLoc.WriteProperty(new BoolProperty(true, "bPrimaryStart"));
            startLoc.WriteProperty(CommonStructs.Vector3Prop(startLocation.Location.X, startLocation.Location.Y, startLocation.Location.Z, "location"));
            startLoc.WriteProperty(CommonStructs.RotatorProp(startLocation.Rotation.Pitch, startLocation.Rotation.Yaw, startLocation.Rotation.Roll, "Rotation"));
            startLoc.WriteProperty(new NameProperty("BioStartLocationMP", "Tag"));
            startLoc.WriteProperty(new FloatProperty(2, "DrawScale"));

            var cylinderComp = ExportCreator.CreateExport(package, "CylinderComponent", "CylinderComponent", startLoc);
            cylinderComp.WritePrePropsAndProperties(new byte[4], cylinderComp.GetProperties()); // NetIndex slot
            cylinderComp.WriteProperty(new ObjectProperty(0, "ReplacementPrimitive"));

            startLoc.WriteProperty(new ObjectProperty(cylinderComp, "CollisionComponent"));
        }

        /// <summary>
        /// Builds the BioTriggerStream that controls sublevel streaming, with a single always-active TIER_Global
        /// state (no touch required) listing every sublevel in VisibleChunkNames.
        /// </summary>
        private static void BuildTriggerStream(IMEPackage package, IEntry persistentLevel, List<string> sublevels)
        {
            var triggerStream = ExportCreator.CreateExport(package, "BioTriggerStream", "BioTriggerStream", persistentLevel);

            var streamingState = new PropertyCollection
            {
                new NameProperty("None", "StateName"),
                new NameProperty("None", "InChunkName"),
                new ArrayProperty<NameProperty>(sublevels.Select(x => new NameProperty(x)), "VisibleChunkNames"),
                new ArrayProperty<NameProperty>("VisibleSoonChunkNames"),
                new ArrayProperty<NameProperty>("LoadChunkNames"),
            };
            triggerStream.WriteProperty(new ArrayProperty<StructProperty>([new StructProperty("BioStreamingState", streamingState)], "StreamingStates"));
            triggerStream.WriteProperty(new NameProperty("TIER_Global", "TierName"));
            triggerStream.WriteProperty(new NameProperty("BioTriggerStream", "Tag"));

            // Placeholder brush geometry - the standard 256x256x256 default builder-brush cube. The geometry
            // itself is functionally irrelevant here (TIER_Global + StateName "None" applies unconditionally,
            // no touch required) but a valid Model/Polys/BrushComponent triple is still expected on a placed
            // Brush-derived actor.
            var model = ExportCreator.CreateExport(package, "Model", "Model", persistentLevel);
            var polys = ExportCreator.CreateExport(package, "Polys", "Polys", persistentLevel);

            var modelBin = Model.Create();
            modelBin.Self = model.UIndex;
            modelBin.Polys = polys.UIndex;
            modelBin.RootOutside = true;
            modelBin.NumSharedSides = 4;
            modelBin.LightingGuid = Guid.NewGuid();
            model.WriteBinary(modelBin);

            var polysBin = Polys.Create();
            polysBin.Owner = model.UIndex;
            polys.WriteBinary(polysBin);

            var brushComponent = ExportCreator.CreateExport(package, "BrushComponent", "BrushComponent", triggerStream);
            brushComponent.WriteBinary(BrushComponent.Create());
            brushComponent.WriteProperty(new ObjectProperty(model, "Brush"));
            brushComponent.WriteProperty(GetDefaultBuilderBrushAggGeomProperty());
            brushComponent.WriteProperty(new ObjectProperty(0, "ReplacementPrimitive"));

            triggerStream.WriteProperty(new ObjectProperty(model, "Brush"));
            triggerStream.WriteProperty(new ObjectProperty(brushComponent, "BrushComponent"));
            triggerStream.WriteProperty(new ObjectProperty(brushComponent, "CollisionComponent"));
        }

        /// <summary>
        /// The standard 256x256x256 default builder-brush cube's BrushAggGeom, as found on every freshly placed
        /// Brush-derived actor (e.g. BioTriggerStream) built from the engine's default template.
        /// </summary>
        private static StructProperty GetDefaultBuilderBrushAggGeomProperty()
        {
            var convexElem = new KConvexElem
            {
                VertexData =
                [
                    new Vector3(128, 128, -128),
                    new Vector3(128, -128, -128),
                    new Vector3(-128, -128, -128),
                    new Vector3(128, 128, 128),
                    new Vector3(-128, -128, 128),
                    new Vector3(-128, 128, -128),
                    new Vector3(128, -128, 128),
                    new Vector3(-128, 128, 128),
                ],
                PermutedVertexData =
                [
                    new Plane(128, 128, -128, 128),
                    new Plane(128, -128, -128, 128),
                    new Plane(-128, -128, -128, 128),
                    new Plane(-128, -128, 128, -128),
                    new Plane(-128, 128, -128, 128),
                    new Plane(128, -128, 128, 128),
                ],
                FaceTriData =
                [
                    0, 2, 1, 0, 5, 2, 1, 3, 0, 1, 6, 3, 4, 1, 2, 4, 6, 1,
                    5, 4, 2, 5, 7, 4, 7, 0, 3, 7, 5, 0, 6, 7, 3, 6, 4, 7,
                ],
                EdgeDirections =
                [
                    new Vector3(-0.99999994f, 0, 0),
                    new Vector3(0, -0.99999994f, 0),
                    new Vector3(0, 0, 0.99999994f),
                ],
                FaceNormalDirections =
                [
                    new Vector3(0, 0, -0.99999994f),
                    new Vector3(0.99999994f, 0, 0),
                    new Vector3(0, -0.99999994f, 0),
                ],
                FacePlaneData =
                [
                    new Plane(0, 0, -0.99999994f, 127.99999f),
                    new Plane(0.99999994f, 0, 0, 127.99999f),
                    new Plane(0, -0.99999994f, 0, 127.99999f),
                    new Plane(-0.99999994f, 0, 0, 127.99999f),
                    new Plane(0, 0.99999994f, 0, 127.99999f),
                    new Plane(0, 0, 0.99999994f, 127.99999f),
                ],
                ElemBox = new Box(new Vector3(-128, -128, -128), new Vector3(128, 128, 128)),
            };

            var convexElemsProp = new ArrayProperty<StructProperty>([convexElem.GetStructProperty()], "ConvexElems");
            return new StructProperty("KAggregateGeom", new PropertyCollection { convexElemsProp }, "BrushAggGeom");
        }
    }
}
