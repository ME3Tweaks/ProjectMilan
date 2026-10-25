using System.Numerics;
using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Kismet;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilan.Pipelines.Levels.BioP_MPDish2;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Levels.BioP_MPRctr2;

/// <summary>
/// Rctr2's doors need fixed when exporting to UDK for light baking because they by default are in the up position which can't get light in the wall.
/// Also makes the reactor's vent buttons shootable once the reactor is charged, and blocks the reactor doorways in the path
/// network while the doors are shut.
/// </summary>
internal class MPRctr2Specific : LevelSpecificFixesBase
{
    private const string KismetPackageName = "BioD_MPRctr2";

    #region Door nav

    /// <summary>
    /// Navs to turn off when the doors close so things don't pathfind through the bulkheads
    /// </summary>
    private static readonly string[] DoorwayNavPoints =
    [
        "CoverLink_20", "CoverLink_94",   // E1 (north)
        "CoverLink_163", "CoverLink_164", // C1 (west)
        "CoverLink_165", "CoverLink_166", // A1 (south)
        "PathNode_628"                    // E1, outside end of CoverLink_203's spec
    ];
    // Milan Kismet action that blocks/unblocks the nav points, re-paths AIs routed through them and raises
    // SFXGameInfoMP.HasTemporaryNavBlocks() (which the escort drone waits on). Lives in BIOP_MP_COMMON.
    private const string NavBlockPackageName = "SFXGameContent_Milan";
    private const string NavBlockClassName = "SFXSeqAct_TemporaryNavBlock";
    
    // Fires when the doors start dropping
    private const string DoorsClosingDelayPath = "TheWorld.PersistentLevel.Main_Sequence.SeqAct_Delay_2";
    
    // Played forward to close the doors, in reverse to open them
    private const string BulkheadsInterpPath = "TheWorld.PersistentLevel.Main_Sequence.SeqAct_Interp_6";

    /// <summary>
    /// Adds vent door button colors and navigation blocks when the doors closes
    /// </summary>
    /// <param name="pipeline"></param>
    public override void PostCorrect(LevelSpecificPipeline pipeline)
    {
        var package = pipeline.LE3Packages.Values.FirstOrDefault(x => x.FileNameNoExtension.Equals(KismetPackageName, StringComparison.OrdinalIgnoreCase));
        AddDoorwayNavBlock(package, pipeline.LogCategory);
        AddVentButtonColors(package, pipeline.LogCategory);
    }

    /// <summary>
    /// Blocks the reactor doorways in the path network from when the doors start closing until they finish reopening
    /// </summary>
    internal static bool AddDoorwayNavBlock(IMEPackage package, string logCategory)
    {
        var doorsClosing = package.FindExport(DoorsClosingDelayPath, "SeqAct_Delay");
        var bulkheads = package.FindExport(BulkheadsInterpPath, "SeqAct_Interp");
        var sequence = KismetHelper.GetParentSequence(bulkheads);
        var navPoints = DoorwayNavPoints.Select(name => package.FindExport($"TheWorld.PersistentLevel.{name}"));

        // Nav block class is added to biop_mp_common
        var navBlockClass = MilanLevelTools.GetOrAddForcedExportClassImport(package, $"{NavBlockPackageName}.{NavBlockClassName}");

        // Copy SeqAct_Toggle links
        var targetLink = KismetHelper.GetSequenceObjects(sequence).OfType<ExportEntry>()
            .Where(x => x.ClassName == "SeqAct_Toggle")
            .Select(x => x.GetProperty<ArrayProperty<StructProperty>>("VariableLinks")?.FirstOrDefault(l => l.GetProp<StrProperty>("LinkDesc") == "Target"))
            .FirstOrDefault(x => x != null);

        targetLink = targetLink.DeepClone();
        targetLink.GetProp<ArrayProperty<ObjectProperty>>("LinkedVariables").Clear();

        var navBlock = new ExportEntry(package, 0, package.GetNextIndexedName(NavBlockClassName), properties: new PropertyCollection
        {
            new ArrayProperty<StructProperty>(new List<StructProperty> { targetLink }, "VariableLinks"),
            new IntProperty(1, "ObjInstanceVersion")
        })
        {
            Class = navBlockClass
        };
        navBlock.ObjectFlags |= UnrealFlags.EObjectFlags.Transactional;
        package.AddExport(navBlock);
        KismetHelper.AddObjectToSequence(navBlock, sequence);
        foreach (var nav in navPoints)
        {
            KismetHelper.CreateVariableLink(navBlock, "Target", SequenceObjectCreator.CreateObject(sequence, nav));
        }
        KismetHelper.CreateOutputLink(doorsClosing, "Finished", navBlock, 0); // Block
        KismetHelper.CreateOutputLink(bulkheads, "Reversed", navBlock, 1); // Unblock
        KismetHelper.SetComment(navBlock, "Block reactor doorway paths while the doors are shut");

        MilanLog.Information($"Reactor: blocked {navPoints.Count()} doorway nav points in {KismetPackageName} while the doors are shut", customPrefix: logCategory);
        return true;
    }

    #endregion

    #region Vent button colors

    // Milan Kismet action that blinks a material parameter on MaterialInstanceActors on the host and on every client. Lives in BIOP_MP_COMMON.
    private const string BlinkMaterialParamClassName = "SFXSeqAct_BlinkMaterialParam";
    // The button material's emissive color. The charge timeline keeps it black, then turns it green (0.28, 0.82, 0.01) when
    // the buttons become usable.
    private const string ButtonColorParam = "Emissive_color";
    // While venting the buttons blink between red and black
    private static readonly Vector3 VentingButtonColor = new(0.9f, 0.02f, 0.01f);
    private const float VentingButtonBlinkInterval = 0.75f;
    // "Venting": Completed output opens the doors
    private const string VentInterpPath = "TheWorld.PersistentLevel.Main_Sequence.SeqAct_Interp_3";

    /// <summary>
    /// Blinks the vent buttons red and black from when the reactor is vented (pressed or shot) until just before the doors
    /// reopen, when they go back to black
    /// </summary>
    internal static bool AddVentButtonColors(IMEPackage package, string logCategory)
    {
        if (package.Exports.Any(x => x.ClassName == BlinkMaterialParamClassName))
        {
            MilanLog.Information($"{KismetPackageName} already colors the vent buttons", customPrefix: logCategory);
            return false;
        }

        // The button Used events all go through the vent gate. The shootable buttons' damage events are added to it later.
        var ventGate = package.Exports.Where(x => x.ClassName == "SeqEvent_Used" && x.GetProperty<ObjectProperty>("Originator")?.ResolveToEntry(package)?.ClassName == "SFXPointOfInterestMP")
            .Select(x => KismetHelper.GetOutputLinksOfNode(x)[0].Single().LinkedOp).Distinct().SingleOrDefault() as ExportEntry;
        var sequence = KismetHelper.GetParentSequence(ventGate);
        var venting = package.FindExport(VentInterpPath, "SeqAct_Interp");

        // Color the same MaterialInstanceActors the charge timeline turns green
        var chargeTimeline = KismetHelper.GetSequenceObjects(sequence).OfType<ExportEntry>()
            .Single(x => x.ClassName == "SeqAct_Interp" && KismetHelper.GetOutputLinkNames(x).Contains("EnableManualTrigger"));
        var buttonVars = KismetHelper.GetVariableLinksOfNode(chargeTimeline).Single(x => x.LinkDesc == "Button").LinkedNodes.OfType<ExportEntry>().ToList();

        var blink = SequenceObjectCreator.CreateSequenceObject(sequence, BlinkMaterialParamClassName, MilanShared.GetLE3GlobalCache());
        blink.WriteProperty(new NameProperty(ButtonColorParam, "ParamName"));
        blink.WriteProperty(CommonStructs.LinearColorProp(VentingButtonColor.X, VentingButtonColor.Y, VentingButtonColor.Z, 1, "VectorValue"));
        blink.WriteProperty(CommonStructs.LinearColorProp(0, 0, 0, 1, "OffVectorValue"));
        blink.WriteProperty(new FloatProperty(VentingButtonBlinkInterval, "BlinkInterval"));
        foreach (var buttonVar in buttonVars)
        {
            KismetHelper.CreateVariableLink(blink, "Target", buttonVar);
        }
        KismetHelper.CreateOutputLink(ventGate, "Out", blink, 0); // Start Vector
        KismetHelper.CreateOutputLink(venting, "Completed", blink, 2); // Stop, which leaves them black
        KismetHelper.SetComment(blink, "Blink vent buttons red while venting");

        MilanLog.Information($"Reactor: vent buttons in {KismetPackageName} blink red while venting", customPrefix: logCategory);
        return true;
    }

    #endregion

    #region Door button trigger

    // Assets
    private const string ButtonPackageName = "BioA_MPRctr2";
    private const string ButtonMeshIFP = "BioApl_Ind_Button01.Button01";
    private const string HitboxMeshIFP = "BioG_Ladders.PrefabBox_01";
    private const string HitboxName = "MilanRctr2ButtonHitbox";



    // How far the hitbox extends past the button on every side, so it is hit before the button mesh is
    private const float HitboxPadding = 1f;

    // Each button's use point (SFXPointOfInterestMP) sits on the button
    private const float MaxButtonToUsePointDistance = 48f;
    
    // Damage a hitbox has to take to vent the reactor
    private const float VentDamageThreshold = 500f;
    
    // Trigger type for damage
    private const string VentDamageWhoTriggers = "WT_Everyone";


    /// <summary>
    /// Adds a hidden hitbox over each vent button that triggers the reactor when taking enough damage
    /// </summary>
    internal static bool AddShootableVentButtons(IMEPackage buttonPackage, IMEPackage package, string logCategory)
    {
        // Find the originators of the Used events
        var usedEvents = package.Exports.Where(x => x.ClassName == "SeqEvent_Used" && x.GetProperty<ObjectProperty>("Originator")?.ResolveToEntry(package)?.ClassName == "SFXPointOfInterestMP").ToList();
        var ventGate = usedEvents.Select(x => KismetHelper.GetOutputLinksOfNode(x)[0].Single().LinkedOp).Distinct().Single() as ExportEntry;
        var instigatorVar = usedEvents.Select(x => KismetHelper.GetVariableLinksOfNode(x).First(l => l.LinkDesc == "Instigator").LinkedNodes.Single()).Distinct().Single() as ExportEntry;
        var sequence = KismetHelper.GetParentSequence(ventGate)!;

        // The buttons only become usable at EnableManualTrigger, so that arms the hitboxes
        var chargeTimeline = KismetHelper.GetSequenceObjects(sequence).OfType<ExportEntry>()
            .Single(x => x.ClassName == "SeqAct_Interp" && KismetHelper.GetOutputLinkNames(x).Contains("EnableManualTrigger"));

        // Each hitbox is fitted over a button mesh, padded on every side
        var buttonMesh = buttonPackage.FindExport(ButtonMeshIFP, "StaticMesh");
        var hitboxMesh = package.FindExport(HitboxMeshIFP, "StaticMesh");
        var buttonBounds = buttonMesh.GetBinaryData<StaticMesh>().Bounds;
        var hitboxBounds = hitboxMesh.GetBinaryData<StaticMesh>().Bounds;

        var buttons = buttonPackage.Exports.Where(x => x.ClassName == "StaticMeshComponent"
            && x.InstancedFullPath.StartsWith("TheWorld.PersistentLevel.", StringComparison.Ordinal)
            && x.GetProperty<ObjectProperty>("StaticMesh")?.Value == buttonMesh.UIndex).ToList();

        // Pair each button with its use point so the hitboxes are named and ordered after them
        var usePoints = usedEvents.Select(x => (ExportEntry)x.GetProperty<ObjectProperty>("Originator")!.ResolveToEntry(package)!).ToList();
        var placements = new List<(ExportEntry UsePoint, Matrix4x4 HitboxWorld)>();
        foreach (var button in buttons)
        {
            var buttonWorld = MPDish2Specific.GetMeshWorldTransform(button);
            var buttonCenter = Vector3.Transform(buttonBounds.Origin, buttonWorld);
            var usePoint = usePoints.MinBy(x => Vector3.Distance(CommonStructs.GetVector3(x, "Location", Vector3.Zero), buttonCenter))!;
            if (Vector3.Distance(CommonStructs.GetVector3(usePoint, "Location", Vector3.Zero), buttonCenter) > MaxButtonToUsePointDistance
                || placements.Any(x => x.UsePoint == usePoint))
                throw new InvalidOperationException($"Reactor vent buttons: cannot uniquely match {button.InstancedFullPath} to a button use point.");

            // The button components are scaled (2, 0.75, 2), so the padding is divided by the button's scale to stay in world units
            var paddedExtent = buttonBounds.BoxExtent + new Vector3(HitboxPadding) / Vector3.Abs(buttonWorld.UnrealDecompose().scale);
            var hitboxScale = paddedExtent / hitboxBounds.BoxExtent;
            var hitboxToButton = Matrix4x4.CreateScale(hitboxScale) * Matrix4x4.CreateTranslation(buttonBounds.Origin - hitboxBounds.Origin * hitboxScale);
            placements.Add((usePoint, hitboxToButton * buttonWorld));
        }

        // Clone an existing InterpActor so the component keeps its template data, then replace what it is
        var template = package.Exports.First(x => x.ClassName == "InterpActor" && x.InstancedFullPath.StartsWith("TheWorld.PersistentLevel.", StringComparison.Ordinal)
            && x.GetChildren().Count() == 1
            && x.GetProperty<ObjectProperty>("StaticMeshComponent")?.ResolveToEntry(package) is ExportEntry { Archetype.InstancedFullPath: "Engine.Default__InterpActor.StaticMeshComponent0" });
        var level = package.GetLevel();
        var levelBinary = package.GetLevelBinary();
        var damageEvents = new List<ExportEntry>();

        // The Kismet classes' info points at BaseDelta's in-memory Engine.pcc, which only this cache has
        var kismetClassCache = MilanShared.GetLE3GlobalCache();
        int index = 0;
        foreach (var (usePoint, hitboxWorld) in placements.OrderBy(x => x.UsePoint.ObjectName.Instanced, StringComparer.Ordinal))
        {
            index++;
            var (location, drawScale, rotation) = hitboxWorld.UnrealDecompose();
            if (!TransformsMatch(ActorUtils.ComposeLocalToWorld(location, rotation, drawScale), hitboxWorld, hitboxBounds))
                throw new InvalidOperationException($"Reactor vent buttons: the button at {usePoint.ObjectName.Instanced} has a transform an actor can't reproduce.");

            var hitbox = EntryCloner.CloneTree(template);
            hitbox.ObjectName = new NameReference(HitboxName, index);
            var component = (ExportEntry)hitbox.GetProperty<ObjectProperty>("StaticMeshComponent")!.ResolveToEntry(package)!;
            component.WriteProperties(new PropertyCollection
            {
                new ObjectProperty(hitboxMesh, "StaticMesh"),
                new BoolProperty(false, "BlockNonZeroExtent"),
                new BoolProperty(false, "BlockRigidBody"),
                new BoolProperty(false, "CastShadow"),
                new BoolProperty(false, "bAcceptsLights")
            });

            component.WriteBinary(StaticMeshComponent.Create());
            hitbox.WriteProperties(new PropertyCollection
            {
                new ObjectProperty(component, "StaticMeshComponent"),
                new ObjectProperty(component, "CollisionComponent"),
                CommonStructs.Vector3Prop(location, "Location"),
                CommonStructs.RotatorProp(rotation, "Rotation"),
                CommonStructs.Vector3Prop(drawScale, "DrawScale3D"),
                new NameProperty(HitboxName, "Tag"),
                new BoolProperty(true, "bHidden")
            });
            levelBinary.Actors.Add(hitbox.UIndex);

            var damageEvent = SequenceObjectCreator.CreateSequenceObject(sequence, "SeqEvent_TakeDamage", kismetClassCache);
            KismetHelper.WriteOriginator(damageEvent, hitbox);
            damageEvent.WriteProperty(new FloatProperty(VentDamageThreshold, "DamageThreshold"));
            damageEvent.WriteProperty(new EnumProperty(VentDamageWhoTriggers, "EWhoTriggers", package.Game, "WhoTriggers"));
            damageEvent.WriteProperty(new IntProperty(0, "MaxTriggerCount"));

            // Armed when the reactor is charged
            damageEvent.WriteProperty(new BoolProperty(false, "bEnabled"));
            
            // Same as pressing the button, including who gets the credit for the kills
            KismetHelper.CreateOutputLink(damageEvent, "Out", ventGate);
            KismetHelper.CreateVariableLink(damageEvent, "Instigator", instigatorVar);
            KismetHelper.SetComment(damageEvent, $"Shot button {usePoint.ObjectName.Instanced}");
            damageEvents.Add(damageEvent);
        }
        level.WriteBinary(levelBinary);

        // Arm when the reactor is charged, disarm when it vents
        var arm = SequenceObjectCreator.CreateSequenceObject(sequence, "SeqAct_Toggle", kismetClassCache);
        KismetHelper.CreateOutputLink(chargeTimeline, "EnableManualTrigger", arm, 0); // Turn On
        KismetHelper.SetComment(arm, "Arm shootable buttons");
        var disarm = SequenceObjectCreator.CreateSequenceObject(sequence, "SeqAct_Toggle", kismetClassCache);
        KismetHelper.CreateOutputLink(ventGate, "Out", disarm, 1); // Turn Off
        KismetHelper.SetComment(disarm, "Disarm shootable buttons");
        foreach (var damageEvent in damageEvents)
        {
            KismetHelper.CreateEventLink(arm, "Event", damageEvent);
            KismetHelper.CreateEventLink(disarm, "Event", damageEvent);
        }

        disarm.FileRef.Save();
        MilanLog.Information($"Reactor: made {damageEvents.Count} vent buttons shootable in {KismetPackageName} ({VentDamageThreshold} damage, {VentDamageWhoTriggers})", customPrefix: logCategory);
        return true;
    }

    /// <summary>
    /// Checks that two transforms place the corners of a mesh's bounds within a tenth of a unit of each other
    /// </summary>
    private static bool TransformsMatch(Matrix4x4 a, Matrix4x4 b, BoxSphereBounds bounds)
    {
        for (int corner = 0; corner < 8; corner++)
        {
            var point = bounds.Origin + bounds.BoxExtent * new Vector3((corner & 1) == 0 ? -1 : 1, (corner & 2) == 0 ? -1 : 1, (corner & 4) == 0 ? -1 : 1);
            if (Vector3.Distance(Vector3.Transform(point, a), Vector3.Transform(point, b)) > 0.1f)
                return false;
        }
        return true;
    }

    #endregion

    #region Lighting

    // After the bake: the hitboxes are invisible gameplay actors that shouldn't take part in it
    public override void PostLightingCorrect(LevelSpecificPipeline pipeline)
    {
        using var buttonPackage = MEPackageHandler.OpenMEPackage(Path.Combine(pipeline.LevelOutputDir, $"{ButtonPackageName}.pcc"), diskIOSyncLock: MilanShared.DiskIOSyncLock);
        using var package = MEPackageHandler.OpenMEPackage(Path.Combine(pipeline.LevelOutputDir, $"{KismetPackageName}.pcc"), diskIOSyncLock: MilanShared.DiskIOSyncLock);
        if (AddShootableVentButtons(buttonPackage, package, pipeline.LogCategory))
        {
            package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
            MilanShared.RefreshMilanFiles = true;
        }
    }

    // Position to place SMC's for the doors so they get light. These are the end positions of them if the interp was in the door closed position.
    private static readonly (string ComponentPath, float ClosedZ)[] DoorBakePositions =
    [
        ("TheWorld.PersistentLevel.InterpActor_12.StaticMeshComponent_6", -33f),
        ("TheWorld.PersistentLevel.InterpActor_13.StaticMeshComponent_6", -295f),
        ("TheWorld.PersistentLevel.InterpActor_14.StaticMeshComponent_6", -295f)
    ];

    public override void CorrectUDKExport(LevelSpecificPipeline pipeline, IMEPackage udk)
    {
        // Only apply to BioD_MPRctr2
        if (!udk.FileNameNoExtension.Equals("BioD_MPRctr2", StringComparison.OrdinalIgnoreCase))
            return;


        var placedActors = udk.GetLevelBinary().Actors.ToHashSet();
        var doorSMCs = udk.Exports.Where(actor => actor.ClassName == "StaticMeshActor" && placedActors.Contains(actor.UIndex)).ToArray();
        var corrections = new List<(ExportEntry Actor, Vector3 Position)>();

        foreach (var (path, closedZ) in DoorBakePositions)
        {
            // Tag.Name is the original component path
            var door = doorSMCs.FirstOrDefault(actor => actor.GetProperty<NameProperty>("Tag")?.Value.Name == path);
            if (door == null)
                throw new InvalidOperationException($"Reactor door bake: couldn't resolve the door!");
            var location = door.GetProperty<StructProperty>("Location");
            var position = CommonStructs.GetVector3(location);
            // Correct the Z position to the closed position so it gets light baked onto the visible parts
            position.Z = closedZ;
            corrections.Add((door, position));
        }

        foreach (var (actor, position) in corrections)
        {
            actor.WriteProperty(CommonStructs.Vector3Prop(position, "Location"));
            MilanLog.Information($"Corrected Reactor blast door for UDK export", customPrefix: pipeline.LogCategory);
        }
    }

    #endregion
}