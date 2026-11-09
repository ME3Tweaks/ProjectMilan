using System.Globalization;
using System.Numerics;
using LegendaryExplorerCore.Coalesced;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Kismet;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using ProjectMilan.Pipelines.Levels;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.EntryMenu.MenuScenes
{
    /// <summary>
    /// Builds the main menu backdrops. Each Scenes\&lt;Map&gt;.json becomes EntryMenu_&lt;Map&gt;: the map's built BioP without its
    /// Kismet, streaming its art, BioD_MilanMenu and any design levels, plus tagged actors that place the terminal and
    /// cameras. MilanHost loads one in place of EntryMenu. Runs after the level pipeline.
    /// </summary>
    internal static class MenuScenesPipeline
    {
        private const string LogCategory = "MILAN-MenuScenes";
        private const string LevelPath = "TheWorld.PersistentLevel";
        private const string MainSequencePath = LevelPath + ".Main_Sequence";

        /// <summary>
        /// Latent action class that fires Inside or Outside as the player's view enters or leaves its volumes
        /// </summary>
        private const string CameraInVolumesClass = "SFXGameContent_Milan.SFXSeqAct_CameraInVolumes";

        private static string ScenesFolder => Path.Combine(MilanShared.PipelineRoot, "EntryMenu", "Scenes");

        /// <summary>
        /// MilanHost picks a scene from the EntryMenu_*.pcc files in here
        /// </summary>
        private static string SceneOutputFolder => Path.Combine(MenuLevelTools.OutputFolder, "Scenes");

        /// <summary>
        /// The terminal's hologram materials, each with a Color vector parameter
        /// </summary>
        private static readonly string[] HologramMaterials =
        [
            "BioApl_GUI_Terminal.Terminal01.Materials.T_01_Extras",
            "BioApl_GUI_Terminal.Terminal01.Materials.T_01_Screen_1_Mat",
            "BioApl_GUI_Terminal.Terminal01.Materials.T_01_Keys_01",
            "BioApl_GUI_Terminal.Terminal01.Materials.T_01_Keyboard_01",
        ];

        /// <summary>
        /// Design level actors that only matter to gameplay: navigation, cover, spawns, pickups and volumes
        /// </summary>
        private static readonly HashSet<string> GameplayActorClasses = new(StringComparer.OrdinalIgnoreCase)
        {
            "SFXEnemySpawnPoint", "SFXOperation_ObjectiveSpawnPoint", "SFXAmmoContainer", "SFXGrenadeContainer", "SFXCombatZone",
            "SFXKillRagdollVolume", "BioTriggerVolume", "DynamicTriggerVolume", "BlockingVolume", "SFXBlockingVolume_Ledge",
            "BioTriggerStream", "BioStartLocationMP", "CoverLink", "CoverSlotMarker", "PathNode", "BioPathPoint",
        };

        public static void RunPipeline()
        {
            var manifestPaths = Directory.Exists(ScenesFolder)
                ? Directory.GetFiles(ScenesFolder, "*.json").OrderBy(x => x, StringComparer.OrdinalIgnoreCase).ToList()
                : [];
            if (Directory.Exists(SceneOutputFolder))
            {
                Directory.Delete(SceneOutputFolder, true);
            }

            var sharedSublevelPath = Path.Combine(MenuLevelTools.OutputFolder, $"{MenuLevelTools.SharedSublevelName}.pcc");
            if (File.Exists(sharedSublevelPath))
            {
                File.Delete(sharedSublevelPath);
            }

            if (manifestPaths.Count == 0)
            {
                MilanLog.Warning($"No menu scenes in {ScenesFolder}; the main menu stays on EntryMenu", customPrefix: LogCategory);
                return;
            }

            // The shared sublevel is the branded EntryMenu without its backdrop
            MenuSharedSublevel.Build(Path.Combine(MenuLevelTools.OutputFolder, "EntryMenu.pcc"));
            var hologramBrightness = GetHologramBrightness(sharedSublevelPath);
            Directory.CreateDirectory(SceneOutputFolder);
            var built = 0;
            foreach (var manifestPath in manifestPaths)
            {
                var manifest = MenuSceneManifest.Load(manifestPath);
                var level = MPLevels.FindLevelPipeline($"BioP_{manifest.Map}");
                if (level == null || !level.ShouldBuild)
                {
                    MilanLog.ErrorWithSummary($"Menu scene {manifest.Map} skipped: BioP_{manifest.Map} is not a level this build ports", customPrefix: LogCategory);
                    continue;
                }

                BuildScene(manifest, level);
                RegisterConfig(manifest, hologramBrightness);
                built++;
            }

            MilanPipelinesShared.CommitConfigBundle();
            MilanLog.Information($"Built {built} of {manifestPaths.Count} menu scenes", customPrefix: LogCategory);
        }

        private static void BuildScene(MenuSceneManifest manifest, LevelSpecificPipeline level)
        {
            var bioPPath = Path.Combine(level.LevelOutputDir, $"{level.BioP}.pcc");
            var scenePath = Path.Combine(SceneOutputFolder, $"{MenuLevelTools.ScenePackagePrefix}{manifest.Map}.pcc");
            File.Copy(bioPPath, scenePath, true);
            using var package = MEPackageHandler.OpenMEPackage(scenePath, diskIOSyncLock: MilanShared.DiskIOSyncLock);
            var levelExport = package.GetLevel();
            MenuLevelTools.RenameSelfPackage(package, level.BioP);

            // The map's logic doesn't run in the menu. Its forced exports stay, as the art sublevels import from them.
            ClearSequence(package.FindExport(MainSequencePath));
            MakeMenuWorld(levelExport);

            var designLevels = manifest.DesignLevels.Select(x => BuildDesignLevel(manifest, x, level)).ToList();
            var artLevels = SetStreaming(package, manifest, designLevels);
            AddPlacementActors(package, levelExport, manifest);
            AddTerminalLights(package, levelExport, manifest, level, artLevels);

            MilanLevelTools.RebuildStreamingLevels(package, LogCategory);
            MilanLevelTools.RebuildPersistentLevelChildren(levelExport);
            MenuLevelTools.VerifyNoTrashReferences(package);
            package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
            MilanLog.Information($"Built {scenePath} from {level.BioP}", customPrefix: LogCategory);
        }

        private static void ClearSequence(ExportEntry? sequence)
        {
            if (sequence == null)
            {
                return;
            }

            var objects = KismetHelper.GetSequenceObjects(sequence);
            sequence.WriteProperty(new ArrayProperty<ObjectProperty>("SequenceObjects"));
            EntryPruner.TrashEntriesAndDescendants(objects);
        }

        /// <summary>
        /// Shows the scene's art, design level copies and the shared sublevel in the trigger stream's default state, and
        /// drops every other sublevel
        /// </summary>
        /// <returns>The art levels shown</returns>
        private static List<string> SetStreaming(IMEPackage package, MenuSceneManifest manifest, List<string> designLevels)
        {
            var triggerStream = package.Exports.Single(x => x.ClassName == "BioTriggerStream" && x.Parent == package.GetLevel());
            var states = triggerStream.GetProperty<ArrayProperty<StructProperty>>("StreamingStates");
            var state = states.First(x => x.GetProp<NameProperty>("StateName") is { } stateName && stateName.Value.Instanced == "None");

            // Keep names, as a chunk like BioA_X_200 has an instance number a string doesn't carry
            // InChunkName is shown too (MPCer2, MPCer3 and MPOcean keep most of their geometry in it)
            var mapChunks = new[] { "VisibleChunkNames", "LoadChunkNames", "VisibleSoonChunkNames" }
                .SelectMany(x => state.GetProp<ArrayProperty<NameProperty>>(x) ?? Enumerable.Empty<NameProperty>())
                .Append(state.GetProp<NameProperty>("InChunkName"))
                .OfType<NameProperty>()
                .Select(x => x.Value)
                .ToList();
            // A state can name a chunk with no streaming entry (MPGeth's BioA_MPGeth_200WB); the game never loads it
            var streamingLevels = package.Exports.Where(x => x.ClassName == "LevelStreamingKismet").ToList();
            bool Streams(ExportEntry streaming, NameReference name) => streaming.GetProperty<NameProperty>("PackageName") is { } packageName && packageName.Value == name;
            var artChunks = mapChunks.Where(x => x.Instanced.StartsWith("BioA_", StringComparison.OrdinalIgnoreCase))
                .Where(x => package.Exports.Any(s => s.ClassName.StartsWith("LevelStreaming", StringComparison.Ordinal) && Streams(s, x)))
                .DistinctBy(x => x.Instanced, StringComparer.OrdinalIgnoreCase)
                .ToList();
            if (manifest.Sublevels != null)
            {
                foreach (var unknown in manifest.Sublevels.Where(x => !artChunks.Any(c => c.Instanced.Equals(x, StringComparison.OrdinalIgnoreCase))))
                {
                    throw new InvalidDataException($"Menu scene {manifest.Map}: {unknown} is not a BioA_ sublevel of BioP_{manifest.Map}.");
                }
                artChunks = artChunks.Where(x => manifest.Sublevels.Contains(x.Instanced, StringComparer.OrdinalIgnoreCase)).ToList();
            }

            var visible = artChunks.Concat(designLevels.Select(x => new NameReference(x))).Append(new NameReference(MenuLevelTools.SharedSublevelName)).ToList();
            state.Properties.AddOrReplaceProp(new ArrayProperty<NameProperty>(visible.Select(x => new NameProperty(x)), "VisibleChunkNames"));
            state.Properties.AddOrReplaceProp(new ArrayProperty<NameProperty>("LoadChunkNames"));
            state.Properties.AddOrReplaceProp(new ArrayProperty<NameProperty>("VisibleSoonChunkNames"));
            states.Clear();
            states.Add(state);
            triggerStream.WriteProperty(states);

            // Streaming entries follow the same list
            var parent = streamingLevels.FirstOrDefault()?.Parent ?? package.GetLevel();
            EntryPruner.TrashEntries(package, streamingLevels.Where(x => !visible.Any(name => Streams(x, name))));
            foreach (var name in visible.Where(x => !streamingLevels.Any(s => Streams(s, x))))
            {
                var streaming = ExportCreator.CreateExport(package, "LevelStreamingKismet", "LevelStreamingKismet", parent);
                streaming.WriteProperty(new NameProperty(name, "PackageName"));
            }
            return artChunks.Select(x => x.Instanced).ToList();
        }

        /// <summary>
        /// Makes the BioP's world info a menu level's, as in EntryMenu: flagged as a menu level, without the multiplayer
        /// game types
        /// </summary>
        private static void MakeMenuWorld(ExportEntry levelExport)
        {
            var worldInfo = levelExport.FileRef.Exports.First(x => x.Parent == levelExport && x.IsA("WorldInfo"));
            worldInfo.WriteProperty(new BoolProperty(true, "bIsMenuLevel"));
            worldInfo.RemoveProperty("GameTypesSupportedOnThisMap");
        }

        private static void AddPlacementActors(IMEPackage package, ExportEntry levelExport, MenuSceneManifest manifest)
        {
            var vista = manifest.VistaCamera;
            CreateActor(package, levelExport, "TargetPoint", MenuLevelTools.TerminalAnchorTag, manifest.TerminalAnchor.Location, manifest.TerminalAnchor.Rotation);
            CreateCamera(package, levelExport, MenuLevelTools.VistaCameraTag, vista.Start);
            CreateCamera(package, levelExport, MenuLevelTools.VistaCameraEndTag, vista.End ?? vista.Start);
            CreateCamera(package, levelExport, MenuLevelTools.TerminalCameraTag, manifest.TerminalView);

            // Multiplayer start spots mean nothing to the menu's game type
            EntryPruner.TrashEntriesAndDescendants(package.Exports.Where(x => x.Parent == levelExport && x.ClassName == "BioStartLocationMP").ToList());
            // The game streams textures around the player's view while loading, and the first view is the splash's
            CreatePlayerStart(package, levelExport, vista.Start.Location, vista.Start.Rotation);
        }

        /// <summary>
        /// The default game type spawns the player at a player start in the navigation list, and makes no player controller
        /// without one. This becomes the only navigation point, as in EntryMenu.
        /// </summary>
        private static void CreatePlayerStart(IMEPackage package, ExportEntry levelExport, MenuSceneVector location, MenuSceneRotator rotation)
        {
            var actor = CreateActor(package, levelExport, "PlayerStart", "PlayerStart", location, rotation);
            actor.Archetype = package.GetEntryOrAddImport("Engine.Default__PlayerStart", "PlayerStart", "Engine");
            var cylinder = new ExportEntry(package, actor, "CollisionCylinder", new byte[8])
            {
                Class = package.GetEntryOrAddImport("Engine.CylinderComponent", "Class"),
                Archetype = package.GetEntryOrAddImport("Engine.Default__PlayerStart.CollisionCylinder", "CylinderComponent", "Engine"),
            };
            package.AddExport(cylinder);
            cylinder.WriteProperties(new PropertyCollection
            {
                new BoolProperty(true, "CollideActors"),
                new BoolProperty(true, "BlockActors"),
            });
            actor.WriteProperty(new ObjectProperty(cylinder, "CylinderComponent"));
            actor.WriteProperty(new ObjectProperty(cylinder, "CollisionComponent"));
            actor.WriteProperty(CommonStructs.GuidProp(Guid.NewGuid(), "NavGuid"));

            var level = ObjectBinary.From<Level>(levelExport);
            level.NavListStart = actor.UIndex;
            level.NavListEnd = actor.UIndex;
            levelExport.WriteBinary(level);
        }

        private static ExportEntry CreateActor(IMEPackage package, ExportEntry levelExport, string className, string tag, MenuSceneVector location, MenuSceneRotator rotation)
        {
            var actor = ExportCreator.CreateExport(package, className, className, levelExport, createWithStack: true);
            actor.WriteProperty(CommonStructs.Vector3Prop(location.X, location.Y, location.Z, "location"));
            actor.WriteProperty(CommonStructs.RotatorProp(rotation.Pitch, rotation.Yaw, rotation.Roll, "Rotation"));
            actor.WriteProperty(new NameProperty(tag, "Tag"));
            return actor;
        }

        private static void CreateCamera(IMEPackage package, ExportEntry levelExport, string tag, MenuSceneCamera camera)
        {
            var actor = CreateActor(package, levelExport, "CameraActor", tag, camera.Location, camera.Rotation);
            actor.WriteProperty(new FloatProperty(camera.FOV, "FOVAngle"));
            actor.WriteProperty(new FloatProperty(16f / 9f, "AspectRatio"));
            actor.WriteProperty(new BoolProperty(false, "bConstrainAspectRatio"));
        }

        /// <summary>
        /// Adds a key point light and an ambient sky light on the terminal's channel (see <see cref="MenuSceneLighting"/>).
        /// The manifest's TerminalLighting overrides any part.
        /// </summary>
        private static void AddTerminalLights(IMEPackage package, ExportEntry levelExport, MenuSceneManifest manifest, LevelSpecificPipeline level,
            List<string> artLevels)
        {
            var anchor = manifest.TerminalAnchor.Location;
            var center = new Vector3(anchor.X, anchor.Y, anchor.Z + MenuSceneFraming.TerminalCenterHeight);
            var levels = new List<IMEPackage>();
            try
            {
                foreach (var artLevel in artLevels)
                {
                    var path = Path.Combine(level.LevelOutputDir, $"{artLevel}.pcc");
                    if (!File.Exists(path))
                    {
                        MELoadedFiles.TryGetHighestMountedFile(MEGame.LE3, $"{artLevel}.pcc", out path);
                    }
                    levels.Add(MEPackageHandler.OpenMEPackage(path, diskIOSyncLock: MilanShared.DiskIOSyncLock));
                }

                var estimate = MenuSceneLighting.EstimateAt(levels, center);
                var key = MenuSceneLighting.GetKeyLight(estimate);
                var ambient = MenuSceneLighting.GetAmbientLight(estimate);
                var overrides = manifest.TerminalLighting;
                var keyColor = overrides?.KeyColor is { } kc ? MenuSceneLighting.ToGamma(new Vector3(kc.R, kc.G, kc.B)) : key.Color;
                var keyBrightness = overrides?.KeyBrightness ?? key.Brightness;
                var ambientColor = overrides?.AmbientColor is { } ac ? MenuSceneLighting.ToGamma(new Vector3(ac.R, ac.G, ac.B)) : ambient.Color;
                var ambientBrightness = overrides?.AmbientBrightness ?? ambient.Brightness;

                var keyLocation = center + estimate.KeyDirection * MenuSceneLighting.KeyDistance;
                var keyLight = CreateTerminalLight(package, levelExport, "PointLightMovable", "PointLightComponent", MenuLevelTools.TerminalKeyLightTag,
                    new MenuSceneVector { X = keyLocation.X, Y = keyLocation.Y, Z = keyLocation.Z }, keyColor, keyBrightness);
                keyLight.WriteProperty(new FloatProperty(MenuSceneLighting.KeyRadius, "Radius"));
                var ambientLight = CreateTerminalLight(package, levelExport, "SkyLightToggleable", "SkyLightComponent", MenuLevelTools.TerminalAmbientLightTag,
                    new MenuSceneVector { X = center.X, Y = center.Y, Z = center.Z }, ambientColor, ambientBrightness);
                // Light from below is the floor bouncing it, so dimmer
                ambientLight.WriteProperty(new FloatProperty(ambientBrightness * 0.5f, "LowerBrightness"));
                ambientLight.WriteProperty(CommonStructs.ColorProp(ambientColor, "LowerColor"));

                MilanLog.Information($"Menu scene {manifest.Map}: {estimate.LightCount} lights reach the terminal; key {keyColor.R},{keyColor.G},{keyColor.B} x{keyBrightness:0.00} "
                    + $"from ({estimate.KeyDirection.X:0.00},{estimate.KeyDirection.Y:0.00},{estimate.KeyDirection.Z:0.00}), ambient {ambientColor.R},{ambientColor.G},{ambientColor.B} x{ambientBrightness:0.00}",
                    customPrefix: LogCategory);
            }
            finally
            {
                foreach (var opened in levels)
                {
                    opened.Dispose();
                }
            }
        }

        /// <summary>
        /// Creates a movable, shadowless light on the terminal's channel only
        /// </summary>
        /// <returns>The light component</returns>
        private static ExportEntry CreateTerminalLight(IMEPackage package, ExportEntry levelExport, string actorClass, string componentClass, string tag,
            MenuSceneVector location, System.Drawing.Color color, float brightness)
        {
            var actor = CreateActor(package, levelExport, actorClass, tag, location, new MenuSceneRotator());
            actor.Archetype = package.GetEntryOrAddImport($"Engine.Default__{actorClass}", actorClass, "Engine");
            var componentName = $"{componentClass}0";
            var component = new ExportEntry(package, actor, componentName, new byte[8])
            {
                Class = package.GetEntryOrAddImport($"Engine.{componentClass}", "Class"),
                Archetype = package.GetEntryOrAddImport($"Engine.Default__{actorClass}.{componentName}", componentClass, "Engine"),
            };
            package.AddExport(component);
            component.WriteProperties(new PropertyCollection
            {
                new FloatProperty(brightness, "Brightness"),
                CommonStructs.ColorProp(color, "LightColor"),
                MenuSceneLighting.TerminalChannels(package),
                new BoolProperty(true, "bEnabled"),
                new BoolProperty(false, "CastShadows"),
                new BoolProperty(false, "CastStaticShadows"),
                new BoolProperty(false, "CastDynamicShadows"),
                CommonStructs.GuidProp(Guid.NewGuid(), "LightGuid"),
                CommonStructs.GuidProp(Guid.NewGuid(), "LightmapGuid"),
            });
            component.WriteBinary(LightComponent.Create());
            actor.WriteProperty(new ObjectProperty(component, "LightComponent"));
            return component;
        }

        /// <summary>
        /// Copies a design level as &lt;Package&gt;_Menu, keeping only the listed Kismet (and what it leads to) and dropping
        /// gameplay actors
        /// </summary>
        /// <returns>The copy's package name</returns>
        private static string BuildDesignLevel(MenuSceneManifest manifest, MenuSceneDesignLevel design, LevelSpecificPipeline level)
        {
            var sourcePath = Path.Combine(level.LevelOutputDir, $"{design.Package}.pcc");
            if (!File.Exists(sourcePath) && !MELoadedFiles.TryGetHighestMountedFile(MEGame.LE3, $"{design.Package}.pcc", out sourcePath))
            {
                throw new FileNotFoundException($"Menu scene {manifest.Map}: can't find design level {design.Package}.");
            }

            var menuName = $"{design.Package}_Menu";
            var outputPath = Path.Combine(SceneOutputFolder, $"{menuName}.pcc");
            File.Copy(sourcePath, outputPath, true);
            using var package = MEPackageHandler.OpenMEPackage(outputPath, diskIOSyncLock: MilanShared.DiskIOSyncLock);
            MenuLevelTools.RenameSelfPackage(package, design.Package);

            var kept = KeepKismet(package, manifest, design);

            // Actors the kept Kismet uses stay
            var usedByKismet = kept.SelectMany(MenuLevelTools.GetDirectReferences).ToHashSet();
            var levelExport = package.GetLevel();
            var listed = GetListedActors(package, levelExport, manifest, design);
            foreach (var actor in listed.Where(x => usedByKismet.Contains(x.UIndex)))
            {
                throw new InvalidDataException($"Menu scene {manifest.Map}: {design.Package} removes {actor.ObjectName.Instanced}, which its kept Kismet uses.");
            }

            var removed = package.Exports
                .Where(x => x.Parent == levelExport && !usedByKismet.Contains(x.UIndex) && IsGameplayActor(x))
                .Union(listed)
                .ToList();

            var levelBinary = ObjectBinary.From<Level>(levelExport);
            MenuLevelTools.ClearNavigation(levelBinary);
            levelExport.WriteBinary(levelBinary);
            EntryPruner.TrashEntriesAndDescendants(removed);
            EntryPruner.TrashEntriesAndDescendants(MenuLevelTools.PrunePrefabInstances(package));
            MilanLevelTools.RebuildPersistentLevelChildren(levelExport);

            int pruned = MenuLevelTools.PruneUnreferenced(package, package.Exports
                .Where(x => x.Parent == null && x.ObjectName.Name != "TheWorld" && !x.IsTrash())
                .Select(x => x.ObjectName.Instanced)
                .ToList());
            MenuLevelTools.VerifyNoTrashReferences(package);

            package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
            MilanLog.Information($"Built {outputPath}: kept {kept.Count} Kismet objects, removed {removed.Count} gameplay actors and {pruned} unused exports", customPrefix: LogCategory);
            return menuName;
        }

        /// <summary>
        /// The design level's listed actors and every actor based on them, however deep (a shuttle's doors and emitters ride
        /// on its base)
        /// </summary>
        private static HashSet<ExportEntry> GetListedActors(IMEPackage package, ExportEntry levelExport, MenuSceneManifest manifest, MenuSceneDesignLevel design)
        {
            var listed = design.RemoveActors.Select(x => package.FindExport($"{LevelPath}.{x}")
                    ?? throw new InvalidDataException($"Menu scene {manifest.Map}: {design.Package} has no actor {x} to remove."))
                .ToHashSet();
            var bases = package.Exports
                .Where(x => x.Parent == levelExport)
                .Select(x => (Actor: x, Base: x.GetProperty<ObjectProperty>("Base")?.ResolveToEntry(package) as ExportEntry))
                .Where(x => x.Base != null)
                .ToList();

            bool added = true;
            while (added)
            {
                added = false;
                foreach (var (actor, actorBase) in bases)
                {
                    if (listed.Contains(actorBase!) && listed.Add(actor))
                    {
                        added = true;
                    }
                }
            }
            return listed;
        }

        private static bool IsGameplayActor(ExportEntry export) =>
            GameplayActorClasses.Contains(export.ClassName)
            || export.ClassName.StartsWith("SFXNav_", StringComparison.OrdinalIgnoreCase)
            || export.IsA("ReachSpec") || export.IsA("NavigationPoint") || export.IsA("Pawn") || export.IsA("Controller");

        /// <summary>
        /// Trashes every Kismet object the listed roots don't lead to
        /// </summary>
        /// <returns>The Kismet objects kept</returns>
        private static HashSet<ExportEntry> KeepKismet(IMEPackage package, MenuSceneManifest manifest, MenuSceneDesignLevel design)
        {
            var mainSequence = package.FindExport(MainSequencePath)
                ?? throw new InvalidDataException($"Menu scene {manifest.Map}: {design.Package} has no {MainSequencePath}.");
            var kept = new HashSet<ExportEntry> { mainSequence };
            var pending = new Stack<ExportEntry>();
            if (design.PlayerTargets.Count > 0)
            {
                TargetPlayer(package, manifest, design, mainSequence);
            }
            foreach (var root in design.KeepKismet)
            {
                pending.Push(package.FindExport($"{MainSequencePath}.{root}")
                    ?? throw new InvalidDataException($"Menu scene {manifest.Map}: {design.Package} has no Kismet object {root}."));
            }
            if (design.StartOnSceneReady.Count > 0 || design.CameraTouches.Count > 0)
            {
                var sceneReady = CreateSceneReadyEvent(package, manifest, design, mainSequence);
                AddCameraWatchers(package, manifest, design, mainSequence, sceneReady);
                pending.Push(sceneReady);
            }

            while (pending.TryPop(out var node))
            {
                if (!kept.Add(node))
                {
                    continue;
                }

                // Enclosing sequences, so it stays reachable
                if (KismetHelper.GetParentSequence(node) is { } parent)
                {
                    pending.Push(parent);
                }

                // Where it leads, and the variables and events it uses
                foreach (var linked in KismetHelper.GetOutputLinksOfNode(node).SelectMany(x => x).Select(x => x.LinkedOp).OfType<ExportEntry>())
                {
                    pending.Push(linked);
                }
                foreach (var linked in KismetHelper.GetVariableLinksOfNode(node).SelectMany(x => x.LinkedNodes).OfType<ExportEntry>())
                {
                    pending.Push(linked);
                }
                foreach (var linked in KismetHelper.GetEventLinksOfNode(node).SelectMany(x => x.LinkedNodes).OfType<ExportEntry>())
                {
                    pending.Push(linked);
                }

                // A listed sequence keeps all its contents; its parents only keep the path down to it
                if (node.ClassName == "Sequence" && node != mainSequence && design.KeepKismet.Any(x => node.InstancedFullPath.EndsWith(x, StringComparison.OrdinalIgnoreCase)))
                {
                    foreach (var child in KismetHelper.GetSequenceObjects(node).OfType<ExportEntry>())
                    {
                        pending.Push(child);
                    }
                }
            }

            // Events that wait on the multiplayer game won't fire in the menu
            bool IsSceneReady(ExportEntry x) => x.GetProperty<NameProperty>("EventName") is { } eventName && eventName.Value.Instanced == MenuLevelTools.SceneReadyEvent;
            foreach (var gameplayEvent in kept.Where(x => x.ClassName.StartsWith("SFXSeqEvt_", StringComparison.OrdinalIgnoreCase) || (x.ClassName == "SeqEvent_RemoteEvent" && !IsSceneReady(x))))
            {
                MilanLog.Warning($"Menu scene {manifest.Map}: kept {gameplayEvent.InstancedFullPath} ({gameplayEvent.ClassName}) waits on gameplay and won't fire in the menu", customPrefix: LogCategory);
            }

            foreach (var sequence in package.Exports.Where(x => x.ClassName == "Sequence" && kept.Contains(x)).ToList())
            {
                var objects = sequence.GetProperty<ArrayProperty<ObjectProperty>>("SequenceObjects");
                if (objects == null)
                {
                    continue;
                }

                var removed = objects.Select(x => x.ResolveToEntry(package)).OfType<ExportEntry>().Where(x => !kept.Contains(x)).ToList();
                sequence.WriteProperty(new ArrayProperty<ObjectProperty>(objects.Where(x => removed.All(r => r.UIndex != x.Value)), "SequenceObjects"));
                EntryPruner.TrashEntriesAndDescendants(removed);
            }

            return kept;
        }

        /// <summary>
        /// Substitutes touch events with a camera touching event so flyovers can trigger events
        /// </summary>
        private static void AddCameraWatchers(IMEPackage package, MenuSceneManifest manifest, MenuSceneDesignLevel design, ExportEntry mainSequence,
            ExportEntry sceneReady)
        {
            StructProperty Output(ExportEntry touch, string desc) =>
                touch.GetProperty<ArrayProperty<StructProperty>>("OutputLinks")?.FirstOrDefault(x => x.GetProp<StrProperty>("LinkDesc")?.Value == desc)
                ?? throw new InvalidDataException($"Menu scene {manifest.Map}: {design.Package}'s {touch.ObjectName.Instanced} has no {desc} output.");
            string Targets(StructProperty output) => string.Join(",", (output.GetProp<ArrayProperty<StructProperty>>("Links") ?? new ArrayProperty<StructProperty>("Links"))
                .Select(x => $"{x.GetProp<ObjectProperty>("LinkedOp")?.Value}:{x.GetProp<IntProperty>("InputLinkIdx")?.Value}"));

            var touches = design.CameraTouches.Select(path => package.FindExport($"{MainSequencePath}.{path}")
                ?? throw new InvalidDataException($"Menu scene {manifest.Map}: {design.Package} has no touch event {path}.")).ToList();
            // One watcher per set of outputs, so moving between volumes that do the same thing doesn't switch it off and on
            foreach (var group in touches.GroupBy(x => $"{Targets(Output(x, "Touched"))}|{Targets(Output(x, "UnTouched"))}"))
            {
                var first = group.First();
                var inside = Output(first, "Touched").DeepClone();
                inside.Properties.AddOrReplaceProp(new StrProperty("Inside", "LinkDesc"));
                var outside = Output(first, "UnTouched").DeepClone();
                outside.Properties.AddOrReplaceProp(new StrProperty("Outside", "LinkDesc"));

                var watcher = MenuLevelTools.CreateMilanAction(mainSequence, CameraInVolumesClass);
                var volumes = new List<ObjectProperty>();
                foreach (var touch in group)
                {
                    var volume = touch.GetProperty<ObjectProperty>("Originator")?.ResolveToEntry(package) as ExportEntry
                        ?? throw new InvalidDataException($"Menu scene {manifest.Map}: {design.Package}'s {touch.ObjectName.Instanced} has no volume!");
                    volumes.Add(new ObjectProperty(SequenceObjectCreator.CreateObject(mainSequence, volume, MilanShared.GetLE3GlobalCache())));
                }

                // LE3 doesn't have milan's class info, write it out in full
                var volumesLink = GlobalUnrealObjectInfo.getDefaultStructValue(MEGame.LE3, "SeqVarLink", true, package);
                volumesLink.AddOrReplaceProp(new ArrayProperty<ObjectProperty>(volumes, "LinkedVariables"));
                volumesLink.AddOrReplaceProp(new StrProperty("Volumes", "LinkDesc"));
                volumesLink.AddOrReplaceProp(new ObjectProperty(package.GetEntryOrAddImport("Engine.SeqVar_Object", "Class"), "ExpectedType"));
                volumesLink.AddOrReplaceProp(new NameProperty("Targets", "PropertyName"));
                volumesLink.AddOrReplaceProp(new IntProperty(1, "MinVars"));
                volumesLink.AddOrReplaceProp(new IntProperty(255, "MaxVars"));

                // Write properties
                var properties = watcher.GetProperties();
                properties.AddOrReplaceProp(new ArrayProperty<StructProperty>([inside, outside], "OutputLinks"));
                properties.AddOrReplaceProp(new ArrayProperty<StructProperty>([new StructProperty("SeqVarLink", volumesLink)], "VariableLinks"));
                watcher.WriteProperties(properties);

                KismetHelper.CreateOutputLink(sceneReady, "Out", watcher);
            }
        }

        /// <summary>
        /// Retargets 'Player' objects in kismet
        /// </summary>
        private static void TargetPlayer(IMEPackage package, MenuSceneManifest manifest, MenuSceneDesignLevel design, ExportEntry mainSequence)
        {
            // Creates a player object, it will return a controller.
            var player = SequenceObjectCreator.CreatePlayerObject(mainSequence, false, MilanShared.GetLE3GlobalCache());
            foreach (var path in design.PlayerTargets)
            {
                var node = package.FindExport($"{MainSequencePath}.{path}")
                    ?? throw new InvalidDataException($"Menu scene {manifest.Map}: {design.Package} has no Kismet object {path} to target the player.");
                var links = KismetHelper.GetVariableLinksOfNode(node);
                var target = links.FirstOrDefault(x => x.LinkDesc == "Target")
                    ?? throw new InvalidDataException($"Menu scene {manifest.Map}: {design.Package}'s {path} has no Target variable link.");
                target.LinkedNodes = [player];
                KismetHelper.WriteVariableLinksToNode(node, links);
            }
        }

        /// <summary>
        /// Adds a remote event for BioD_MilanMenu's scene ready signal that starts remote StartOnSceneReady objects
        /// </summary>
        private static ExportEntry CreateSceneReadyEvent(IMEPackage package, MenuSceneManifest manifest, MenuSceneDesignLevel design, ExportEntry mainSequence)
        {
            // Create scene ready
            var sceneReady = SequenceObjectCreator.CreateSequenceObject(mainSequence, "SeqEvent_RemoteEvent", MilanShared.GetLE3GlobalCache());
            if (sceneReady.GetProperty<ArrayProperty<StructProperty>>("OutputLinks") == null)
            {
                throw new InvalidOperationException($"Menu scene {manifest.Map}: the new SeqEvent_RemoteEvent in {design.Package} has no default links.");
            }
            sceneReady.WriteProperty(new NameProperty(MenuLevelTools.SceneReadyEvent, "EventName"));

            // Write outlink
            foreach (var path in design.StartOnSceneReady)
            {
                var target = package.FindExport($"{MainSequencePath}.{path}")
                    ?? throw new InvalidDataException($"Menu scene {manifest.Map}: {design.Package} has no Kismet object {path} to start.");
                KismetHelper.CreateOutputLink(sceneReady, "Out", target);
            }
            return sceneReady;
        }

        /// <summary>
        /// Used for adjusting the brightness of the menu hologram
        /// </summary>
        private static Dictionary<string, float> GetHologramBrightness(string sharedSublevelPath)
        {
            using var package = MEPackageHandler.OpenMEPackage(sharedSublevelPath, diskIOSyncLock: MilanShared.DiskIOSyncLock);
            var luminance = new Dictionary<string, float>();
            foreach (var path in HologramMaterials)
            {
                // Get color property
                var color = package.FindExport(path)?.GetProperty<ArrayProperty<StructProperty>>("VectorParameterValues")
                        ?.FirstOrDefault(x => x.GetProp<NameProperty>("ParameterName")?.Value.Instanced == "Color")
                        ?.GetProp<StructProperty>("ParameterValue")
                    ?? throw new InvalidDataException($"{sharedSublevelPath}: hologram material {path} has no Color parameter.");
                // Convert to a brightness value from its RGB
                luminance[path] = 0.2126f * color.GetProp<FloatProperty>("R") + 0.7152f * color.GetProp<FloatProperty>("G") + 0.0722f * color.GetProp<FloatProperty>("B");
            }
            // Change RGB to how much each contributes to the brightness as a percent
            var brightest = luminance.Values.Max();
            return luminance.ToDictionary(x => x.Key, x => x.Value / brightest);
        }

        /// <summary>
        /// Registers the scene's tints for MilanMenuScene
        /// </summary>
        private static void RegisterConfig(MenuSceneManifest manifest, Dictionary<string, float> hologramBrightness)
        {
            var game = MilanPipelinesShared.ConfigBundle.GetAsset("BioGame");
            var scenes = game.GetOrAddSection("sfxgamecontent_milanbase.milanmenuscene");
            foreach (var material in HologramMaterials)
            {
                var materialEntry = string.Create(CultureInfo.InvariantCulture, $"(Path=\"{material}\",Brightness={hologramBrightness[material]:0.####})");
                scenes.AddEntry(new CoalesceProperty("hologrammaterials", new CoalesceValue(materialEntry, CoalesceParseAction.AddUnique)));
            }

            var entry = $"(Map=\"{MenuLevelTools.ScenePackagePrefix}{manifest.Map}\"" +
                        (manifest.HologramTint is { } hologram ? $",bTintHologram=TRUE,HologramTint={FormatColor(hologram)}" : "") +
                        (manifest.UITint is { } ui ? $",bTintUI=TRUE,UITint={FormatColor(ui)}" : "") +
                        ")";
            scenes.AddEntry(new CoalesceProperty("scenes", new CoalesceValue(entry, CoalesceParseAction.AddUnique)));
        }

        private static string FormatColor(MenuSceneColor color) =>
            string.Create(CultureInfo.InvariantCulture, $"(R={color.R},G={color.G},B={color.B},A={color.A})");
    }
}
