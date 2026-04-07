using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Gammtek.Extensions;
using System.Diagnostics;
using System.IO.Pipes;
using System.Text;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.GameFilesystem;
using MilanCoverHost.Classes;

namespace MilanCoverHost
{
    /// <summary>
    /// Listens for cover and pathfinding network from CoverClient ASI.
    /// </summary>
    internal class CoverHost
    {
        private const string pipeName = @"milancoverhost";

        /// <summary>
        /// List of all nodes brought in from the last pathfinding list serialization
        /// </summary>
        public static List<NavigationPoint> nodeNetwork = null;

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

        internal void StartListening()
        {
            // Used to pass to the flow to compile a package
            //CompileResult cr = null;

            using var server = new NamedPipeServerStream(pipeName, PipeDirection.InOut, 1, PipeTransmissionMode.Byte);
            var reader = new BinaryReader(server, Encoding.Unicode);
            var writer = new StreamWriter(server);
            nodeNetwork = new List<NavigationPoint>();

            // Serialization data
            LevelSerializer levelSerializer = null;

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
                    if (levelSerializer == null)
                    {
                        Console.WriteLine($"Error: Received pathfinding node list command but no level name has been set. Ignoring...");
                        CurrentReadMode = EReadMode.None; // Reset
                        continue;
                    }
                    var numNodes = reader.ReadInt32();
                    if (numNodes == 0)
                    {
                        // Nothing to do.
                        Console.WriteLine($"CoverClient sent no nodes to us, skipping command...");
                        CurrentReadMode = EReadMode.None;
                        continue;
                    }
                    nodeNetwork = new List<NavigationPoint>(numNodes);

                    var pathnodeClass = EntryImporter.EnsureClassIsInFile(levelSerializer.package, "PathNode", new RelinkerOptionsPackage());
                    var reachspecClass = EntryImporter.EnsureClassIsInFile(levelSerializer.package, "ReachSpec", new RelinkerOptionsPackage());

                    Console.WriteLine($"Expecting {numNodes} pathfinding nodes...");
                    var networkId = 441; // Change to something random I guess?
                    for (int i = 0; i < numNodes; i++)
                    {
                        NavigationPoint node = null;
                        var nodeType = reader.BaseStream.ReadUnrealString();
                        switch (nodeType)
                        {
                            case "PathNode":
                                node = new PathNode();
                                break;
                            case "CoverSlotMarker":
                                node = new CoverSlotMarker();
                                break;
                            case "CoverLink":
                                node = new CoverLink();
                                break;
                            default:
                                throw new Exception($"Unsupported pathnode type: {nodeType}");
                        }

                        Console.WriteLine($"Reading {nodeType}");

                        nodeNetwork.Add(node);
                        node.Serialize(reader, levelSerializer);
                    }

                    Console.WriteLine($"Done reading pathfinding list.");

                    // Generate reachspecs
                    Console.WriteLine($"Generating reachspecs...");
                    for (int i = 0; i < nodeNetwork.Count; i++)
                    {
                        var node = nodeNetwork[i];
                        var specs = new List<ExportEntry>();
                        foreach (var reachSpecInfo in node.ReachableNearbyNodes)
                        {
                            var reachableNode = nodeNetwork[reachSpecInfo.TargetNodeIndex];
                            var spec = node.CreateReachSpec(reachableNode.Export, reachSpecInfo.Radius, reachSpecInfo.Height);
                            specs.Add(spec);
                        }

                        if (node is CoverLink cl)
                        {
                            // Resolve FireLinks now that all nodes in the network have been loaded
                            cl.ResolveFireLinks(levelSerializer);

                            // Generate the SlotToSlotReachSpecs on the cover slot markers
                            // Note: This is NOT the current export! These are like the children
                            for(int csi = 0; csi < cl.CoverSlots.Count - 1; csi++)
                            {
                                // Generate the left to right spec
                                var left = cl.CoverSlots[csi];
                                var right = cl.CoverSlots[csi + 1];
                                var ltrSpec = left.CreateReachSpec(right.Export, 40, 95, "SlotToSlotReachSpec"); // Lets start with 40/95
                                ltrSpec.WriteProperty(new ByteProperty(2, "SpecDirection")); // 1 = Left 2 = Right

                                var pathList = left.Export.GetProperty<ArrayProperty<ObjectProperty>>("PathList") ?? new ArrayProperty<ObjectProperty>("PathList");
                                pathList.Add(ltrSpec);
                                left.Export.WriteProperty(pathList);


                                // Generate the right to left spec
                                var rtlSpec = right.CreateReachSpec(left.Export, 40, 95, "SlotToSlotReachSpec"); // Lets start with 40/95
                                rtlSpec.WriteProperty(new ByteProperty(1, "SpecDirection")); // 1 = Left 2 = Right

                                pathList = right.Export.GetProperty<ArrayProperty<ObjectProperty>>("PathList") ?? new ArrayProperty<ObjectProperty>("PathList");
                                pathList.Add(rtlSpec);
                                right.Export.WriteProperty(pathList);
                            }
                        }

                        if (specs.Count > 0)
                        {
                            node.Export.WriteProperty(new ArrayProperty<ObjectProperty>(specs.Select(x => new ObjectProperty(x)), "PathList"));
                        }
                    }

                    var allPathNodes = levelSerializer.package.Exports.Where(e => e.IsA("NavigationPoint")).ToList();
                    levelSerializer.levelBin.Actors.AddRange(allPathNodes.Select(e => e.UIndex));
                    // Build pathfinding chain
                    for (int i = 0; i < allPathNodes.Count - 1; i++)
                    {
                        var nextNode = allPathNodes[i + 1];
                        var node = allPathNodes[i];
                        node.WriteProperty(new ObjectProperty(nextNode, "nextNavigationPoint"));
                    }

                    if (allPathNodes.Count > 0)
                    {
                        levelSerializer.levelBin.NavListStart = allPathNodes.First().UIndex;
                        levelSerializer.levelBin.NavListEnd = allPathNodes.Last().UIndex;
                    }
                    else
                    { 
                        Console.WriteLine("  No NavigationPoints.");
                    }
                    // Build CoverLink chain
                    var allCoverLinks = levelSerializer.package.Exports.Where(e => e.ClassName == "CoverLink").ToList();
                    for (int i = 0; i < allCoverLinks.Count - 1; i++)
                    {
                        var nextNode = allCoverLinks[i + 1];
                        var node = allCoverLinks[i];
                        node.WriteProperty(new ObjectProperty(nextNode, "NextCoverLink"));
                    }

                    if (allCoverLinks.Count > 0)
                    {
                        levelSerializer.levelBin.CoverListStart = allCoverLinks.First().UIndex;
                        levelSerializer.levelBin.CoverListEnd = allCoverLinks.Last().UIndex;
                    } else
                    {
                        Console.WriteLine("  No CoverLinks.");
                    }

                    // NavRefs, all sorts of other things still need done...
                    levelSerializer.package.GetLevel().WriteBinary(levelSerializer.levelBin);

                    // Add test spawn tags
                    allPathNodes[new Random().Next(allPathNodes.Count)].WriteProperty(new NameProperty("BansheeSpawn", "Tag"));
                    allPathNodes[new Random().Next(allPathNodes.Count)].WriteProperty(new NameProperty("AtlasSpawn", "Tag"));
                    allPathNodes[new Random().Next(allPathNodes.Count)].WriteProperty(new NameProperty("BruteSpawn", "Tag"));
                    allPathNodes[new Random().Next(allPathNodes.Count)].WriteProperty(new NameProperty("DragoonSpawn", "Tag"));
                    allPathNodes[new Random().Next(allPathNodes.Count)].WriteProperty(new NameProperty("RavagerSpawn", "Tag"));
                    allPathNodes[new Random().Next(allPathNodes.Count)].WriteProperty(new NameProperty("ScionSpawn", "Tag"));
                    allPathNodes[new Random().Next(allPathNodes.Count)].WriteProperty(new NameProperty("CenturionSpawn", "Tag"));
                    allPathNodes[new Random().Next(allPathNodes.Count)].WriteProperty(new NameProperty("TrooperSpawn", "Tag"));
                    allPathNodes[new Random().Next(allPathNodes.Count)].WriteProperty(new NameProperty("GethPrimeSpawn", "Tag"));

                    var outPath = Path.Combine(MEDirectories.GetCookedPath(levelSerializer.package.Game), $"{levelSerializer.package.FileNameNoExtension}.pcc");
                    levelSerializer.package.Save(outPath);
                    Console.WriteLine($"Pathfinding generation complete.");
                    levelSerializer = null;
                    CurrentReadMode = EReadMode.None; // Reset
                    continue;
                }
                else if (CurrentReadMode == EReadMode.LevelName)
                {
                    // Need to double check incoming string format. It is probably unicode.x`
                    var levelName = reader.BaseStream.ReadUnrealString();
                    Console.WriteLine($"Received level name: {levelName}");

                    var pathfindingPackageName = $"{levelName}_Pathfinding.pcc";
                    levelSerializer = new LevelSerializer
                    {
                        package = MEPackageHandler.CreateMemoryEmptyLevel(pathfindingPackageName, MEGame.LE3),
                        networkId = new Random().Next(1000000), // Just generate a random network ID for now, we can change this later if needed.
                    };
                    levelSerializer.Init();
                    CurrentReadMode = EReadMode.None; // Reset
                    continue;
                }
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
    }
}