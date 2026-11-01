using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Kismet;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.EntryMenu.MenuScenes
{
    /// <summary>
    /// Builds BioD_MilanMenu, the sublevel every menu scene streams in. It is the branded EntryMenu minus the title screen
    /// backdrop, the right computer and the fixed cameras. Tagged actors from each scene's persistent level are found at
    /// runtime, as a sublevel can't import them.
    /// </summary>
    internal static class MenuSharedSublevel
    {
        private const string LogCategory = "MILAN-MenuScenes";
        private const string LevelPath = "TheWorld.PersistentLevel";
        private const string MainSequencePath = LevelPath + ".Main_Sequence";

        /// <summary>
        /// Latent action (BIOP_MP_COMMON) that moves the splash camera to the end camera: steady speed, then slows to rest.
        /// LE3's camera blends can't do this, as the ones that come to rest also start from rest.
        /// </summary>
        private const string MenuCameraDriftClass = "SFXGameContent_Milan.SFXSeqAct_MenuCameraDrift";

        /// <summary>
        /// How long the splash drift runs at a steady speed, then how long it takes to slow to rest
        /// </summary>
        private const float DriftCruiseSeconds = 38f;
        private const float DriftStopSeconds = 14f;

        /// <summary>
        /// Total drift time from the cut to rest
        /// </summary>
        private const float DriftSeconds = DriftCruiseSeconds + DriftStopSeconds;

        /// <summary>
        /// Delay after a camera cut before blocking on texture streaming, so the streamer has the new view
        /// </summary>
        private const float StreamingSettleSeconds = 0.25f;

        /// <summary>
        /// How long textures are force streamed around the new camera before blocking. Without it the block can pass before
        /// anything is requested (MPHosp passed in 0.3s and popped in).
        /// </summary>
        private const float ForceStreamSeconds = 2f;

        /// <summary>
        /// Longest the screen stays black waiting for levels and textures before the view is shown anyway
        /// </summary>
        private const float StreamingTimeoutSeconds = 10f;

        /// <summary>
        /// Latent action (BIOP_MP_COMMON) that holds the Volume_Sound_Effects RTPC at the player's setting or MaxVolume,
        /// whichever is lower. The next map's player controller resets it.
        /// </summary>
        private const string CapSoundEffectsVolumeClass = "SFXGameContent_Milan.SFXSeqAct_CapSoundEffectsVolume";

        /// <summary>
        /// Highest sound effects volume in the menu, 0-1. The RTPC is linear gain, so 0.5 is only -6 dB; 0.2 is about -14 dB.
        /// </summary>
        private const float MaxSoundEffectsVolume = 0.2f;

        /// <summary>
        /// The main menu terminal. The menu movie's screen is attached to one of its bones.
        /// </summary>
        private const string TerminalActor = "SFXSkeletalMeshActor_0";

        /// <summary>
        /// The desk the terminal stands on and the right computer (closed). Attached to the terminal so they follow it.
        /// </summary>
        private static readonly string[] TerminalDeskActors =
        [
            "InterpActor_0",
            "InterpActor_1",
            "InterpActor_2",
            "InterpActor_3",
            "InterpActor_10",
            RightComputerActor,
        ];

        /// <summary>
        /// The right computer (Terminal02), its anim set from the old open/close Matinee, and the set's closed pose
        /// </summary>
        private const string RightComputerActor = "SFXSkeletalMeshActor_2";
        private const string RightComputerAnimSet = "KIS_DYN_Gui_Terminal02_Base_AnimSet";
        private const string RightComputerClosedPose = "state_closed";

        /// <summary>
        /// Actors to keep: world info, the terminal, its screen, the material actors its prefab Matinee animates, and the desk
        /// </summary>
        private static readonly string[] KeptActors =
        [
            "BioWorldInfo_1",
            TerminalActor,
            "SFXGUIRenderTarget_InterpActor_7",
            "MaterialInstanceActor_0",
            "MaterialInstanceActor_1",
            "MaterialInstanceActor_2",
            "MaterialInstanceActor_3",
            .. TerminalDeskActors,
        ];

        /// <summary>
        /// Kismet removed: title screen cameras, the right computer, the old touch trigger, the old ship ambience and the
        /// splash music stop
        /// </summary>
        private static readonly string[] RemovedSequenceObjects =
        [
            "SeqAct_Interp_1", "InterpData_0", // Title camera, held until Press Start
            "SeqAct_Interp_0", "InterpData_3", "BioSeqAct_BlackScreen_1", // Title camera rising into a fade to black
            "SeqVar_Object_3", // Title camera actor
            "SeqVar_Object_12", // Terminal camera actor, replaced by the scene's tagged camera
            "SeqEvent_Console_1", "SeqEvent_Console_4", "SeqAct_SetFloat_0", "SeqAct_SetFloat_1", "SeqAct_SetFloat_3", "SeqVar_Float_0",
            "SeqAct_Interp_2", "InterpData_2", "SeqVar_Object_1", // Right computer open/close Matinee (anim set stays to hold it closed)
            "SeqAct_WwisePostEvent_6", "SeqAct_WwisePostEvent_7", // Right computer opening and closing
            "GFxAction_OpenMovie_2", // Right computer movie
            "SeqEvent_Touch_0",
            "SeqAct_WwisePostEvent_0", "SeqAct_WwisePostEvent_4", "SeqAct_WwisePostEvent_9", // Old backdrop's ship ambience
            "SeqAct_WwisePostEvent_1", // Stopped the splash music on Press Start; it now plays on under the menu
            "Prefabs.Gui_Terminal01_Prefab_Seq.SeqAct_WwisePostEvent_1", // Terminal opening sound; it opens behind the fade
        ];

        /// <summary>
        /// Top level packages only the removed backdrop and right computer use; unused exports in them are dropped
        /// </summary>
        private static readonly string[] BackdropPackages =
        [
            "bios_startscreen", "BioT_StartScreen", "biot_normandy_des", "BioVFX_Env_TitleScreen", "BioApl_Ind_DebrisShip01",
            "BIOA_APL_INT_ScanArm_01_L", "BioApl_GUI_Terminal02", "BioApl_GUI_Terminal", "biog_plc_gui_terminal_r", "GUI_EntryMenu",
            "GUI_SF_MainMenu_RTT_RC",
        ];

        /// <summary>
        /// Writes BioD_MilanMenu.pcc next to the built EntryMenu
        /// </summary>
        /// <param name="entryMenuPath">The branded EntryMenu in the mod output</param>
        public static void Build(string entryMenuPath)
        {
            var outputPath = Path.Combine(Path.GetDirectoryName(entryMenuPath)!, $"{MenuLevelTools.SharedSublevelName}.pcc");
            File.Copy(entryMenuPath, outputPath, true);
            using var package = MEPackageHandler.OpenMEPackage(outputPath, diskIOSyncLock: MilanShared.DiskIOSyncLock);
            MenuLevelTools.RenameSelfPackage(package, "EntryMenu");
            // Only this cache knows BaseDelta's in-memory Engine.pcc
            // without it new sequence objects get no default links
            var cache = MilanShared.GetLE3GlobalCache();

            RebuildKismet(package, cache);
            StripActors(package);
            AttachDeskToTerminal(package);
            int pruned = MenuLevelTools.PruneUnreferenced(package, BackdropPackages);
            MenuLevelTools.VerifyNoTrashReferences(package);

            package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
            MilanLog.Information($"Built {outputPath}", customPrefix: LogCategory);
        }

        private static void RebuildKismet(IMEPackage package, PackageCache cache)
        {
            var sequence = package.FindExport(MainSequencePath);
            ExportEntry Node(string name) => package.FindExport($"{MainSequencePath}.{name}");

            foreach (var name in RemovedSequenceObjects)
            {
                var node = Node(name);
                // The laptop's dynamic anim set isn't a sequence object, the sequence lists it in its shared anim sets
                if (KismetHelper.GetParentSequence(node) == null)
                {
                    var sharedAnimSets = sequence.GetProperty<ArrayProperty<ObjectProperty>>("m_aSFXSharedAnimsets");
                    if (sharedAnimSets != null && sharedAnimSets.Values.RemoveAll(x => x.Value == node.UIndex) > 0)
                    {
                        if (sharedAnimSets.Count == 0)
                        {
                            sequence.RemoveProperty("m_aSFXSharedAnimsets");
                        }
                        else
                        {
                            sequence.WriteProperty(sharedAnimSets);
                        }
                    }
                    EntryPruner.TrashEntryAndDescendants(node);
                }
                else
                {
                    KismetHelper.RemoveFromSequence(node, true);
                }
            }

            // Its depth of field and FOV are tuned to the old camera, the scene's camera sets its own
            var terminalCameraGroup = Node("InterpData_1.InterpGroup_2");
            var tracks = terminalCameraGroup.GetProperty<ArrayProperty<ObjectProperty>>("InterpTracks");
            var removedTracks = tracks.Select(x => x.ResolveToEntry(package)).OfType<ExportEntry>().ToList();
            tracks.Clear();
            terminalCameraGroup.WriteProperty(tracks);
            EntryPruner.TrashEntries(package, removedTracks);

            var anchor = SequenceObjectCreator.CreateFindObjectNameTag(sequence, MenuLevelTools.TerminalAnchorTag, cache: cache);
            var vistaCamera = SequenceObjectCreator.CreateFindObjectNameTag(sequence, MenuLevelTools.VistaCameraTag, cache: cache);
            var vistaCameraEnd = SequenceObjectCreator.CreateFindObjectNameTag(sequence, MenuLevelTools.VistaCameraEndTag, cache: cache);
            var terminalCamera = SequenceObjectCreator.CreateFindObjectNameTag(sequence, MenuLevelTools.TerminalCameraTag, cache: cache);
            var player = SequenceObjectCreator.CreatePlayerObject(sequence, false, cache);
            var terminal = SequenceObjectCreator.CreateObject(sequence, package.FindExport($"{LevelPath}.{TerminalActor}"), cache);

            // Hold the camera on the scene's terminal camera while the menu is up
            KismetHelper.CreateVariableLink(Node("SeqAct_Interp_3"), "CerberusNetwork_Cam01", terminalCamera);

            // Move the terminal to the anchor once visible
            var teleport = CreateAction(sequence, "SeqAct_Teleport", cache);
            KismetHelper.CreateVariableLink(teleport, "Target", terminal);
            KismetHelper.CreateVariableLink(teleport, "Destination", anchor);
            KismetHelper.CreateOutputLink(Node("SeqEvent_LevelLoaded_9"), "Loaded and Visible", teleport);

            // Cap sound effects from load, as some maps have loud flybys. Music is a separate volume, and Press Start
            // plays on the music bus (BaseDelta SplashStartSoundRouting), so neither is ducked.
            var capVolume = CreateMilanAction(sequence, CapSoundEffectsVolumeClass);
            capVolume.WriteProperty(new FloatProperty(MaxSoundEffectsVolume, "MaxVolume"));
            KismetHelper.CreateOutputLink(Node("SeqEvent_LevelLoaded_9"), "Loaded and Visible", capVolume);

            // Splash: cut to the vista behind black, wait for textures, then show the splash and drift
            var splashBranch = Node("BioSeqAct_ShouldShowSplashSequence_0");
            var showSplash = Node("BioSeqAct_ShowSplash_0");
            RemoveOutputLinksTo(splashBranch, showSplash);
            var blackOn = CreateAction(sequence, "BioSeqAct_BlackScreen", cache);
            blackOn.WriteProperty(new EnumProperty("BlackScreenAction_TurnBlackOn", "BlackScreenActionSet", package.Game, "m_eBlackScreenAction"));
            var vistaCut = CreateSetCameraTarget(sequence, player, vistaCamera, 0f, "VTBlend_Linear", cache);
            var vistaDrift = CreateMilanAction(sequence, MenuCameraDriftClass);
            vistaDrift.WriteProperty(new NameProperty(MenuLevelTools.VistaCameraTag, "CameraTag"));
            vistaDrift.WriteProperty(new NameProperty(MenuLevelTools.VistaCameraEndTag, "EndTag"));
            vistaDrift.WriteProperty(new FloatProperty(DriftCruiseSeconds, "CruiseSeconds"));
            vistaDrift.WriteProperty(new FloatProperty(DriftStopSeconds, "StopSeconds"));
            var vistaFadeIn = CreateAction(sequence, "BioSeqAct_BlackScreen", cache);
            vistaFadeIn.WriteProperty(new EnumProperty("BlackScreenAction_FadeFromBlack", "BlackScreenActionSet", package.Game, "m_eBlackScreenAction"));
            KismetHelper.CreateOutputLink(splashBranch, "True", blackOn);
            KismetHelper.CreateOutputLink(splashBranch, "True", vistaCut);
            var vistaStreamed = CreateWaitForStreaming(sequence, cache, vistaCamera, (vistaCut, "Out"));
            KismetHelper.CreateOutputLink(vistaStreamed, "Out", vistaFadeIn);
            KismetHelper.CreateOutputLink(vistaStreamed, "Out", showSplash);
            KismetHelper.CreateOutputLink(vistaStreamed, "Out", vistaDrift);

            // Keep streaming along the drift without blocking, as it ends somewhere the reveal never saw
            var driftTextures = CreateForceStreamInTextures(sequence, cache, DriftSeconds, false, vistaCamera, vistaCameraEnd);
            KismetHelper.CreateOutputLink(vistaStreamed, "Out", driftTextures);

            // The terminal starts folded shut and only LT_Open opens it. Doing so while black means it is open on fade in.
            var openTerminal = CreateAction(sequence, "SeqAct_ConsoleCommand", cache);
            openTerminal.WriteProperty(new ArrayProperty<StrProperty>([new StrProperty("ce LT_Open")], "Commands"));
            KismetHelper.CreateVariableLink(openTerminal, "Target", player);

            // Press Start: fade to black, cut to the terminal and open the menu. The splash music plays on.
            var pressStart = Node("SeqEvent_Console_3");
            var fadeOut = CreateAction(sequence, "BioSeqAct_BlackScreen", cache);
            fadeOut.WriteProperty(new EnumProperty("BlackScreenAction_FadeToBlack", "BlackScreenActionSet", package.Game, "m_eBlackScreenAction"));
            var splashTerminalCut = CreateSetCameraTarget(sequence, player, terminalCamera, 0f, "VTBlend_Linear", cache);
            KismetHelper.CreateOutputLink(pressStart, "Out", fadeOut);
            KismetHelper.CreateOutputLink(pressStart, "Out", openTerminal);
            KismetHelper.CreateOutputLink(fadeOut, "Finished", splashTerminalCut);

            // No splash (returning from multiplayer): start on the terminal behind black
            var terminalCut = CreateSetCameraTarget(sequence, player, terminalCamera, 0f, "VTBlend_Linear", cache);
            KismetHelper.CreateOutputLink(splashBranch, "False", terminalCut);
            KismetHelper.CreateOutputLink(splashBranch, "False", openTerminal);

            // Either way, the menu waits for the terminal view's textures
            var initMainMenu = Node("SFXSeqAct_InitMainMenu_0");
            var noSplashBlack = Node("BioSeqAct_BlackScreen_2");
            RemoveOutputLinksTo(noSplashBlack, initMainMenu);
            var terminalStreamed = CreateWaitForStreaming(sequence, cache, terminalCamera, (splashTerminalCut, "Out"), (noSplashBlack, "Finished"));
            KismetHelper.CreateOutputLink(terminalStreamed, "Out", initMainMenu);
        }

        /// <summary>
        /// Waits after a camera cut for the scene to be ready: all levels loaded (blocking), a short delay for the streamer to
        /// get the view, force streamed textures, then a texture streaming block. A timeout shows the view anyway.
        /// </summary>
        /// <returns>The gate whose Out fires once, whichever finishes first</returns>
        private static ExportEntry CreateWaitForStreaming(ExportEntry sequence, PackageCache cache, ExportEntry camera, params (ExportEntry Node, string Output)[] after)
        {
            // bWaitForVisibleOnly (default on) skips levels still loading, so it would pass early
            var levels = CreateAction(sequence, "SFXSeqAct_WaitForStreamingComplete", cache);
            levels.WriteProperty(new BoolProperty(false, "bWaitForVisibleOnly"));
            levels.WriteProperty(new BoolProperty(true, "bBlocking"));
            var settle = CreateAction(sequence, "SeqAct_Delay", cache);
            settle.WriteProperty(new FloatProperty(StreamingSettleSeconds, "Duration"));
            var textures = CreateAction(sequence, "BioSeqAct_BlockForTextureStreaming", cache);
            var timeout = CreateAction(sequence, "SeqAct_Delay", cache);
            timeout.WriteProperty(new FloatProperty(StreamingTimeoutSeconds, "Duration"));
            var gate = CreateAction(sequence, "SeqAct_Gate", cache);
            gate.WriteProperty(new IntProperty(1, "AutoCloseCount"));

            foreach (var (node, output) in after)
            {
                KismetHelper.CreateOutputLink(node, output, levels);
                KismetHelper.CreateOutputLink(node, output, timeout);
            }
            var force = CreateForceStreamInTextures(sequence, cache, ForceStreamSeconds, true, camera);
            KismetHelper.CreateOutputLink(levels, "Finished", settle);
            KismetHelper.CreateOutputLink(settle, "Finished", force);
            KismetHelper.CreateOutputLink(force, "Finished", textures);
            KismetHelper.CreateOutputLink(textures, "Finished", gate);
            KismetHelper.CreateOutputLink(timeout, "Finished", gate);
            return gate;
        }

        /// <summary>
        /// Creates a BioSeqAct_ForceStreamInTextures around the given actors. Its Finished output fires when time is up.
        /// </summary>
        private static ExportEntry CreateForceStreamInTextures(ExportEntry sequence, PackageCache cache, float seconds, bool blockOnWait, params ExportEntry[] locations)
        {
            var force = CreateAction(sequence, "BioSeqAct_ForceStreamInTextures", cache);
            force.WriteProperty(new FloatProperty(seconds, "Seconds"));
            force.WriteProperty(new BoolProperty(blockOnWait, "bBlockOnWait"));
            foreach (var location in locations)
            {
                KismetHelper.CreateVariableLink(force, "Location", location);
            }
            return force;
        }

        /// <summary>
        /// Removes every output link from a node to the given node
        /// </summary>
        private static void RemoveOutputLinksTo(ExportEntry node, ExportEntry target)
        {
            var links = KismetHelper.GetOutputLinksOfNode(node);
            foreach (var link in links)
            {
                link.RemoveAll(x => x.LinkedOp == target);
            }
            KismetHelper.WriteOutputLinksToNode(node, links);
        }

        /// <summary>
        /// Creates a sequence action and checks it got its default links, as KismetHelper silently skips links it can't find
        /// </summary>
        private static ExportEntry CreateAction(ExportEntry sequence, string className, PackageCache cache)
        {
            var action = SequenceObjectCreator.CreateSequenceObject(sequence, className, cache);
            if (action.GetProperty<ArrayProperty<StructProperty>>("OutputLinks") == null)
            {
                throw new InvalidOperationException($"New {className} in {sequence.FileRef.FileNameNoExtension} has no default links; its class's package isn't in the cache.");
            }
            return action;
        }

        /// <summary>
        /// Creates a sequence action of one of Milan's own Kismet classes. They are forced exports the class info doesn't
        /// know, so no default links are written.
        /// </summary>
        private static ExportEntry CreateMilanAction(ExportEntry sequence, string classPath)
        {
            var package = sequence.FileRef;
            var actionClass = MilanLevelTools.GetOrAddForcedExportClassImport(package, classPath);
            var action = new ExportEntry(package, sequence, package.GetNextIndexedName(actionClass.ObjectName.Name), properties: new PropertyCollection
            {
                new IntProperty(1, "ObjInstanceVersion"),
            })
            {
                Class = actionClass,
            };
            action.ObjectFlags |= UnrealFlags.EObjectFlags.Transactional;
            package.AddExport(action);
            KismetHelper.AddObjectToSequence(action, sequence);
            return action;
        }

        private static ExportEntry CreateSetCameraTarget(ExportEntry sequence, ExportEntry player, ExportEntry camera, float blendTime, string blendFunction, PackageCache cache)
        {
            var package = sequence.FileRef;
            var action = CreateAction(sequence, "SeqAct_SetCameraTarget", cache);
            var transition = GlobalUnrealObjectInfo.getDefaultStructValue(package.Game, "ViewTargetTransitionParams", true, package, cache);
            transition.AddOrReplaceProp(new FloatProperty(blendTime, "BlendTime"));
            transition.AddOrReplaceProp(new EnumProperty(blendFunction, "EViewTargetBlendFunction", package.Game, "BlendFunction"));
            action.WriteProperty(new StructProperty("ViewTargetTransitionParams", transition, "TransitionParams"));
            KismetHelper.CreateVariableLink(action, "Target", player);
            KismetHelper.CreateVariableLink(action, "Cam Target", camera);
            return action;
        }

        /// <summary>
        /// Hard-attaches the desk to the terminal so teleporting the terminal takes the desk along. The desk meshes share the
        /// terminal's light environment and shadow.
        /// </summary>
        private static void AttachDeskToTerminal(IMEPackage package)
        {
            ExportEntry Actor(string name) => package.FindExport($"{LevelPath}.{name}");
            var terminal = Actor(TerminalActor);
            var terminalMesh = terminal.GetProperty<ObjectProperty>("SkeletalMeshComponent")?.ResolveToEntry(package) as ExportEntry;
            var lightEnvironment = terminalMesh.GetProperty<ObjectProperty>("LightEnvironment");

            // The terminal is level, so it only turns in yaw
            var terminalLocation = CommonStructs.GetVector3(terminal, "location", default);
            var terminalRotation = CommonStructs.GetRotator(terminal, "Rotation", default);

            var attached = terminal.GetProperty<ArrayProperty<ObjectProperty>>("Attached") ?? new ArrayProperty<ObjectProperty>("Attached");
            foreach (var desk in TerminalDeskActors.Select(Actor))
            {
                desk.WriteProperty(new ObjectProperty(terminal, "Base"));
                desk.WriteProperty(new BoolProperty(true, "bHardAttach"));

                // A hard attachment keeps its saved offset (zero if unset, which stacked everything on the terminal)
                // in the terminal's frame, so rotate by the terminal's yaw
                var offset = CommonStructs.GetVector3(desk, "location", default) - terminalLocation;
                double yaw = -terminalRotation.Yaw * Math.PI * 2 / 65536;
                float cos = (float)Math.Cos(yaw);
                float sin = (float)Math.Sin(yaw);
                desk.WriteProperty(CommonStructs.Vector3Prop(offset.X * cos - offset.Y * sin, offset.X * sin + offset.Y * cos, offset.Z, "RelativeLocation"));
                var rotation = CommonStructs.GetRotator(desk, "Rotation", default);
                desk.WriteProperty(CommonStructs.RotatorProp(rotation.Pitch, (short)((rotation.Yaw - terminalRotation.Yaw) & 0xFFFF), rotation.Roll, "RelativeRotation"));
                desk.WriteProperty(new BoolProperty(false, "bCollideActors"));
                // The right computer lists its screens, which stay out
                desk.RemoveProperty("Attached");
                if (attached.All(x => x.Value != desk.UIndex))
                {
                    attached.Add(new ObjectProperty(desk));
                }

                if (desk.GetProperty<ObjectProperty>("StaticMeshComponent")?.ResolveToEntry(package) is ExportEntry mesh)
                {
                    mesh.WriteProperty(new ObjectProperty(lightEnvironment.Value, "LightEnvironment"));
                    mesh.WriteProperty(new ObjectProperty(terminalMesh, "ShadowParent"));
                }
            }
            terminal.WriteProperty(attached);
            CloseRightComputer(package);

            // Light only from the scene's terminal lights (MenuSceneLighting). The light environment stays off as in the
            // stock menu, so those lights hit them directly.
            var terminalLightEnvironment = (ExportEntry)lightEnvironment.ResolveToEntry(package)!;
            var litMeshes = new List<ExportEntry> { terminalMesh };
            if (Actor(RightComputerActor).GetProperty<ObjectProperty>("SkeletalMeshComponent")?.ResolveToEntry(package) is ExportEntry computerMesh)
            {
                computerMesh.WriteProperty(new ObjectProperty(terminalLightEnvironment, "LightEnvironment"));
                litMeshes.Add(computerMesh);
            }
            litMeshes.AddRange(TerminalDeskActors.Select(Actor)
                .Select(x => x.GetProperty<ObjectProperty>("StaticMeshComponent")?.ResolveToEntry(package))
                .OfType<ExportEntry>());
            foreach (var mesh in litMeshes)
            {
                mesh.WriteProperty(MenuSceneLighting.TerminalChannels(package));
            }
        }

        /// <summary>
        /// The right computer defaults to open and nothing closes it any more, so hold it on its closed pose
        /// </summary>
        private static void CloseRightComputer(IMEPackage package)
        {
            var computer = package.FindExport($"{LevelPath}.{RightComputerActor}");
            var animSet = package.FindExport($"{MainSequencePath}.{RightComputerAnimSet}");
            var mesh = computer.GetProperty<ObjectProperty>("SkeletalMeshComponent")?.ResolveToEntry(package) as ExportEntry;
            var node = mesh.GetProperty<ObjectProperty>("Animations")?.ResolveToEntry(package) as ExportEntry;

            mesh.WriteProperty(new ArrayProperty<ObjectProperty>([new ObjectProperty(animSet)], "AnimSets"));
            node.WriteProperty(new NameProperty(RightComputerClosedPose, "AnimSeqName"));
            node.WriteProperty(new FloatProperty(0f, "CurrentTime"));
            node.WriteProperty(new BoolProperty(false, "bPlaying"));
        }

        private static void StripActors(IMEPackage package)
        {
            var levelExport = package.GetLevel();
            var level = ObjectBinary.From<Level>(levelExport);
            var kept = KeptActors.Select(x => package.FindExport($"{LevelPath}.{x}")).ToHashSet();
            var removed = level.Actors.Where(x => x != 0).Select(x => package.GetUExport(x)).Where(x => !kept.Contains(x)).ToList();

            // The old room's BSP would render around the terminal in every scene
            var modelComponents = level.ModelComponents.Select(x => package.GetUExport(x)).ToList();
            level.ModelComponents = [];
            MenuLevelTools.ClearNavigation(level);
            levelExport.WriteBinary(level);

            // The game still draws the model's surfaces as a default material block at the old room's position, so empty the model too
            if (package.GetEntry(level.Model) is ExportEntry modelExport)
            {
                var model = ObjectBinary.From<Model>(modelExport);
                var emptyModel = Model.Create();
                emptyModel.Self = model.Self;
                emptyModel.Polys = model.Polys;
                emptyModel.LightingGuid = model.LightingGuid;
                emptyModel.NumSharedSides = model.NumSharedSides;
                emptyModel.RootOutside = true;
                modelExport.WriteBinary(emptyModel);
            }

            // With descendants, or the components stay live under the trash package and their names collide
            EntryPruner.TrashEntriesAndDescendants(removed.Concat(modelComponents));
            EntryPruner.TrashEntriesAndDescendants(MenuLevelTools.PrunePrefabInstances(package));
            MilanLevelTools.RebuildPersistentLevelChildren(levelExport);
        }
    }
}
