using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Gammtek.Extensions;
using System;
using System.Collections.Generic;
using System.Text;
using System.Diagnostics;
using LegendaryExplorerCore.Pathing;
using MilanCoverHost.Classes;

namespace MilanCoverHost
{
    internal class PathfindingNode
    {
        public PathfindingNode() { }

        public float X { get; set; }
        public float Y { get; set; }
        public float Z { get; set; }

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
        /// Generated export for this node
        /// </summary>
        public ExportEntry Export;

        public ExportEntry CreateReachSpec(ExportEntry targetNodeExport, int radius, int height)
        {
            var reachSpecExport = ExportCreator.CreateExport(targetNodeExport.FileRef, $"ReachSpec", "ReachSpec", parent: targetNodeExport.FileRef.GetLevel());
            var props = new PropertyCollection();

            /*
             * properties
{
    End = {
           Guid = {A = 0, B = 0, C = 0, D = 0}, 
           Actor = CoverLink'TheWorld.PersistentLevel.CoverLink_5'
          }
    Direction = {X = 0.371273369, Y = 0.890953898, Z = -0.261452019}
    Distance = 122
    Start = PathNode'TheWorld.PersistentLevel.PathNode_275'
    CollisionRadius = 40
    CollisionHeight = 95
    reachFlags = 1
    PathColorIndex = 1
}*/
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
    }
}
