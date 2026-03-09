using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Gammtek.Extensions;
using MilanCoverHost;
using System.Diagnostics;
using System.IO.Pipes;
using System.Text;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.GameFilesystem;
using MilanCoverHost.Classes;

namespace MilanShaderHost
{
    /// <summary>
    /// Listens for cover and pathfinding network from CoverClient ASI.
    /// </summary>
    internal class CoverHost
    {
        private const string pipeName = @"milancoverhost";

        enum EReadMode
        {
            None = 0,
            /// <summary>
            /// CoverClient is sending us a pathfinding node list which includes reachspecs.
            /// </summary>
            PathfindingNodeList = 1,
            /// <summary>
            /// Name of the current persistent level
            /// </summary>
            LevelName = 2,
        }

        EReadMode CurrentReadMode = EReadMode.None;

        IMEPackage pathfindingPackage = null;

        internal void StartListening()
        {
            // Used to pass to the flow to compile a package
            //CompileResult cr = null;

            using var server = new NamedPipeServerStream(pipeName, PipeDirection.InOut, 1, PipeTransmissionMode.Byte);
            var reader = new BinaryReader(server, Encoding.Unicode);
            var writer = new StreamWriter(server);
            Console.WriteLine($"Listening for cover and pathfinding data on named pipe '{pipeName}'...");

            while (true)
            {
                if (!server.IsConnected)
                {
                    try
                    {
                        server.WaitForConnection();
                    }
                    catch (IOException)
                    {
                        server.Disconnect();
                        continue;
                    }
                }
                if (!server.IsConnected)
                {
                    continue;
                }


                if (CurrentReadMode == EReadMode.None)
                {
                    // Read a command
                    try
                    {
                        var commandByte = reader.ReadByte();
                        CurrentReadMode = (EReadMode)commandByte;
                        // Console.WriteLine($"Received command: {CurrentReadMode}");
                    }
                    catch (IOException)
                    {
                        // We just exit, it may be pipe disconnected
                    }
                    continue;

                }
                else if (CurrentReadMode == EReadMode.PathfindingNodeList)
                {
                    if (pathfindingPackage == null)
                    {
                        Console.WriteLine($"Error: Received pathfinding node list command but no level name has been set. Ignoring...");
                        CurrentReadMode = EReadMode.None; // Reset
                        continue;
                    }
                    var numNodes = reader.ReadInt32();

                    var pathnodeClass = EntryImporter.EnsureClassIsInFile(pathfindingPackage, "PathNode", new RelinkerOptionsPackage());
                    var reachspecClass = EntryImporter.EnsureClassIsInFile(pathfindingPackage, "ReachSpec", new RelinkerOptionsPackage());

                    var level = pathfindingPackage.GetLevel();
                    Console.WriteLine($"Expecting {numNodes} pathfinding nodes...");
                    List<PathfindingNode> generatedNodes = new List<PathfindingNode>();
                    var networkId = 441; // Change to something random I guess?
                    for (int i = 0; i < numNodes; i++)
                    {
                        var node = new PathfindingNode();
                        generatedNodes.Add(node);
                        // Read Coordinate of the node.
                        node.X = reader.ReadSingle();
                        node.Y = reader.ReadSingle();
                        node.Z = reader.ReadSingle();

                        // Generate the pathnode in the package.
                        // Technically we also need the collision cylinder but for now we will not care
                        var nodeExport = ExportCreator.CreateExport(pathfindingPackage, $"PathNode", "PathNode", parent: level, indexed: true, createWithStack: true);
                        nodeExport.ObjectFlags |= UnrealFlags.EObjectFlags.Transactional;
                        node.Export = nodeExport;

                        var approximateLineOfFire = reader.ReadInt32();

                        var cylinderComponent = node.CreateCylinderComponent();
                        var pathNodeRadius = reader.ReadSingle();
                        var pathNodeHeight = reader.ReadSingle();
                        if (pathNodeRadius == 0 || pathNodeHeight == 0)
                        {
                            Debug.WriteLine("Wrong size.");
                        }
                        var props = new PropertyCollection();
                        props.Add(CommonStructs.GuidProp(Guid.NewGuid(), "NavGuid"));
                        props.Add(CommonStructs.CylinderProp(pathNodeRadius, pathNodeHeight, "MaxPathSize"));
                        props.Add(new IntProperty(10000000, "VisitedWeight"));
                        props.Add(new IntProperty(networkId, "NetworkID"));
                        props.Add(CommonStructs.Vector3Prop(node.X, node.Y, node.Z, "Location"));
                        props.Add(new NameProperty("PathNode", "Tag"));
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
                                Radius = (int) reader.ReadSingle(),
                                Height = (int) reader.ReadSingle(),
                            };
                            node.ReachableNearbyNodes.Add(reachSpecInfo);
                        }
                        // Console.WriteLine($"Received pathfinding node: ({node.X}, {node.Y}, {node.Z}), Reachable nodes: {string.Join(", ", node.ReachableNearbyNodes)}");
                    }

                    Console.WriteLine($"Done reading pathfinding list.");

                    // Generate reachspecs
                    Console.WriteLine($"Generating reachspecs...");
                    for (int i = 0; i < generatedNodes.Count; i++)
                    {
                        var node = generatedNodes[i];
                        var specs = new List<ExportEntry>();
                        foreach (var reachSpecInfo in node.ReachableNearbyNodes)
                        {
                            var reachableNode = generatedNodes[reachSpecInfo.TargetNodeIndex];
                            var spec = node.CreateReachSpec(reachableNode.Export, reachSpecInfo.Radius, reachSpecInfo.Height);
                            specs.Add(spec);
                        }

                        if (specs.Count > 0)
                        {
                            node.Export.WriteProperty(new ArrayProperty<ObjectProperty>(specs.Select(x => new ObjectProperty(x)), "PathList"));
                        }
                    }

                    var levelBin = pathfindingPackage.GetLevelBinary();
                    var allPathNodes = pathfindingPackage.Exports.Where(e => e.ClassName == "PathNode").ToList();
                    levelBin.Actors.AddRange(allPathNodes.Select(e => e.UIndex));
                    // Build pathfinding chain
                    for (int i = 0; i < allPathNodes.Count - 1; i++)
                    {
                        var nextNode = allPathNodes[i + 1];
                        var node = allPathNodes[i];
                        node.WriteProperty(new ObjectProperty(nextNode, "nextNavigationPoint"));
                    }

                    levelBin.NavListStart = allPathNodes.First().UIndex;
                    levelBin.NavListEnd = allPathNodes.Last().UIndex;
                    level.WriteBinary(levelBin);

                    // Add test spawn tags
                    allPathNodes[new Random().Next(allPathNodes.Count)].WriteProperty(new NameProperty("BansheeSpawn", "Tag"));
                    allPathNodes[new Random().Next(allPathNodes.Count)].WriteProperty(new NameProperty("AtlasSpawn", "Tag"));
                    allPathNodes[new Random().Next(allPathNodes.Count)].WriteProperty(new NameProperty("BruteSpawn", "Tag"));
                    allPathNodes[new Random().Next(allPathNodes.Count)].WriteProperty(new NameProperty("DragoonSpawn", "Tag"));

                    var outPath = Path.Combine(MEDirectories.GetCookedPath(MEGame.LE3), $"{pathfindingPackage.FileNameNoExtension}.pcc");
                    pathfindingPackage.Save(outPath);
                    Console.WriteLine($"Pathfinding generation complete.");
                    pathfindingPackage = null;
                    CurrentReadMode = EReadMode.None; // Reset
                    continue;
                }
                else if (CurrentReadMode == EReadMode.LevelName)
                {
                    // Need to double check incoming string format. It is probably unicode.x`
                    var levelName = reader.BaseStream.ReadUnrealString();
                    Console.WriteLine($"Received level name: {levelName}");

                    var pathfindingPackageName = $"{levelName}_Pathfinding.pcc";
                    pathfindingPackage = MEPackageHandler.CreateMemoryEmptyLevel(pathfindingPackageName, MEGame.LE3);
                    CurrentReadMode = EReadMode.None; // Reset
                    continue;
                }
            }
        }

        private void WriteCacheToFile(ShaderCache cache)
        {
            //// Switch to package-based serialization.
            //cache.Packageless = false;

            //IMEPackage package = null;
            //if (File.Exists(shaderCacheFile))
            //{
            //    package = MEPackageHandler.OpenMEPackage(shaderCacheFile);
            //    var existingCacheExport = package.FindExport("SeekFreeShaderCache");
            //    if (existingCacheExport != null)
            //    {
            //        var existingCache = ObjectBinary.From<ShaderCache>(existingCacheExport);
            //        cache.MergeInto(existingCache);
            //        existingCacheExport.WriteBinary(cache);
            //    }
            //    else
            //    {
            //        Debugger.Break();
            //    }
            //}
            //else
            //{
            //    package = MEPackageHandler.CreateAndOpenPackage(shaderCacheFile, MEGame.LE3);
            //    var sfsc = ExportCreator.CreateExport(package, "SeekFreeShaderCache", "ShaderCache", indexed: false, prePropBinary: [0x0, 0x0, 0x0, 0x0]);
            //    sfsc.WriteBinary(cache);
            //}

            //package.Save();
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
    }
}