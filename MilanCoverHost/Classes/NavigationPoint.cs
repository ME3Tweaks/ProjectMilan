using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Pathing;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Text;

namespace MilanCoverHost.Classes
{
    public class NavigationPoint
    {
        public NavigationPoint() { }

        public float X { get; set; }
        public float Y { get; set; }
        public float Z { get; set; }


        public virtual string ClassName => "NavigationPoint";

        /// <summary>
        /// Bitpacked struct of 10 sectors with 7 bits describing the distance at which it can fire
        /// </summary>
        public int ApproximateLineOfFire { get; set; }

        /// <summary>
        /// These convert to reachspec. 
        /// They are the index of other nodes that are reachable from this node
        /// </summary>
        public List<ReachSpecInfo> ReachableNearbyNodes { get; } = new();
        /// <summary>
        /// Navigation Guid to uniquely fingerprint this node
        /// </summary>
        public Guid NavGuid { get; private set; }

        /// <summary>
        /// Generated export for this node
        /// </summary>
        public ExportEntry Export;

        /// <summary>
        /// Creates a reachspec from the current node to the target node with the given radius and height.
        /// </summary>
        /// <param name="targetNodeExport">The export entry of the target node.</param>
        /// <param name="radius">The collision radius for the reachspec.</param>
        /// <param name="height">The collision height for the reachspec.</param>
        /// <returns>The created reachspec export entry.</returns>
        public ExportEntry CreateReachSpec(ExportEntry targetNodeExport, int radius, int height, string specClass = "ReachSpec")
        {
            var reachSpecExport = ExportCreator.CreateExport(targetNodeExport.FileRef, specClass, specClass, parent: targetNodeExport.FileRef.GetLevel());
            var props = new PropertyCollection();

            props.Add(new StructProperty("ActorReference", new PropertyCollection
            {
                CommonStructs.GuidProp(Guid.Empty),
                new ObjectProperty(targetNodeExport)
            }, "End" , true));

            // Direction, Distance
            var myLoc = LevelTools.GetLocation(Export);
            var targetLoc = LevelTools.GetLocation(targetNodeExport);
            var distance = myLoc.GetDistanceToOtherPoint(targetLoc);
            props.Add(new IntProperty((int)distance, "Distance"));
            props.Add(CommonStructs.Vector3Prop(myLoc.GetDirectionToOtherPoint(targetLoc, distance), "Direction"));

                props.Add(new ObjectProperty(Export, "Start"));

            props.Add(new IntProperty(radius, "CollisionRadius"));
            props.Add(new IntProperty(height, "CollisionHeight"));
            
            // props.Add(new IntProperty(1, "reachFlags")); // Unknown purpose.

            reachSpecExport.WriteProperties(props);
            return reachSpecExport;
        }

        /// <summary>
        /// Creates a new cylinder component for collision detection and adds it to the export file.
        /// </summary>
        /// <remarks>The method ensures that the required class is present in the export file.
        /// The archetype is set to ensure correct one for this object's export.</remarks>
        /// <returns>An instance of <see cref="ExportEntry"/> representing the created cylinder component.</returns>
        public ExportEntry CreateCylinderComponent()
        {
            // We need default archetype: "Engine.Default__PathNode.CollisionCylinder"
            var cClass = EntryImporter.EnsureClassIsInFile(Export.FileRef, "CylinderComponent", new RelinkerOptionsPackage());
            var cylinderComp = ExportCreator.CreateExport(Export.FileRef, "CollisionCylinder", "CylinderComponent", parent: Export);
            cylinderComp.ObjectFlags |= UnrealFlags.EObjectFlags.Transactional;

            cylinderComp.WriteProperties(new PropertyCollection
            {
                new ObjectProperty(0, "ReplacementPrimitive"),
                new StructProperty("LightingChannelContainer", new PropertyCollection()
                {
                    new BoolProperty(true, "bInitialized"),
                    new BoolProperty(true, "Dynamic"),
                }, "LightingChannels")
            });
            cylinderComp.WriteBinary([]);

            // Need to set archetype
            var archetype = PackageUtilities.GetComponentArchetype(Export.Class, "CollisionCylinder", "CollisionCylinder");
            cylinderComp.Archetype = archetype;
            return cylinderComp;
        }

        public virtual void Serialize(BinaryReader reader, LevelSerializer levelSerializer)
        {
            // Read Coordinate of the node.
            X = reader.ReadSingle();
            Y = reader.ReadSingle();
            Z = reader.ReadSingle();

            // Generate the pathnode in the package.
            // Technically we also need the collision cylinder but for now we will not care
            var nodeExport = ExportCreator.CreateExport(levelSerializer.package, ClassName, ClassName, parent: levelSerializer.package.GetLevel(), indexed: true, createWithStack: true);
            nodeExport.ObjectFlags |= UnrealFlags.EObjectFlags.Transactional;
            Export = nodeExport;

            var rotation = CommonStructs.RotatorProp(reader.ReadInt32(), reader.ReadInt32(), reader.ReadInt32(), "Rotation");

            var approximateLineOfFire = reader.ReadInt32();

            var cylinderComponent = CreateCylinderComponent();
            var pathNodeRadius = reader.ReadSingle();
            var pathNodeHeight = reader.ReadSingle();
            if (pathNodeRadius == 0 || pathNodeHeight == 0)
            {
                Debug.WriteLine("Wrong size.");
            }

            NavGuid = Guid.NewGuid();

            var props = new PropertyCollection();
            props.Add(CommonStructs.GuidProp(NavGuid, "NavGuid"));
            props.Add(CommonStructs.CylinderProp(pathNodeRadius, pathNodeHeight, "MaxPathSize"));
            props.Add(new IntProperty(10000000, "VisitedWeight"));
            props.Add(new IntProperty(levelSerializer.networkId, "NetworkID"));
            props.Add(CommonStructs.Vector3Prop(X, Y, Z, "Location"));
            props.Add(rotation);
            props.Add(new NameProperty(ClassName, "Tag"));
            props.Add(new ObjectProperty(cylinderComponent, "CollisionComponent"));
            props.Add(new ObjectProperty(cylinderComponent, "CylinderComponent"));
            props.Add(new IntProperty(approximateLineOfFire, "ApproximateLineOfFire"));
            nodeExport.WriteProperties(props);

            // Read connecting nodes count.
            var numReachableNodes = reader.ReadInt32();
            for (int j = 0; j < numReachableNodes; j++)
            {
                var reachSpecInfo = new ReachSpecInfo()
                {
                    TargetNodeIndex = reader.ReadInt32(),
                    Radius = (int)reader.ReadSingle(),
                    Height = (int)reader.ReadSingle(),
                };
                ReachableNearbyNodes.Add(reachSpecInfo);
            }
        }
    }
}
