
using LegendaryExplorerCore.Packages;
using System.Diagnostics;

namespace ShaderCompare
{
    public enum ESerializationType
    {
        ST_Parameter,
        ST_Resource,
        ST_VertexFactory,
        ST_IndexedParameterTArray,
        ST_IndexedResourceParameterTArray
    }

    [DebuggerDisplay("{Type} {ParameterName}")]
    public class SingleSerialization
    {
        public ESerializationType Type { get; set; }
        public string ParameterName { get; set; }

        public override bool Equals(object? obj)
        {
            return obj is SingleSerialization serialization &&
                   Type == serialization.Type &&
                   ParameterName == serialization.ParameterName;
        }
    }

    public class ShaderSerialization
    {
        public string ShaderTypeName { get; set; }
        public List<SingleSerialization> Parameters = new();
        public bool IsVertexFactory { get; set; }

        internal SingleSerialization GetParameter(int index)
        {
            if (Parameters.Count > index)
            {
                return Parameters[index];
            }

            // Out of bounds
            return null;
        }
    }

    public class ShaderSerializationDifference
    {
        public int SerializationIndex { get; set; }
        public string Message { get; set; }

        public override string ToString() => Message;
    }

    [DebuggerDisplay("{Game1} vs {Game2} | {ShaderTypesOnlyInGame1.Count} Unique Types in {Game1} | {ShaderTypesOnlyInGame2.Count} Unique Types in {Game2} | {SerializationDifferences.Count} Type Serialization Differences | {SerializationIdenticals.Count} Same Type Serializations")]
    public class GameComparison
    {
        public GameComparison(MEGame game1, MEGame game2)
        {
            Game1 = game1;
            Game2 = game2;
        }

        public MEGame Game1 { get; set; }
        public MEGame Game2 { get; set; }


        public List<string> ShaderTypesOnlyInGame1 { get; set; }
        public List<string> ShaderTypesOnlyInGame2 { get; set; }
        public List<string> VertexFactoryTypesOnlyInGame1 { get; set; }
        public List<string> VertexFactoryTypesOnlyInGame2 { get; set; }

        #region VERTEX FACTORY
        /// Shader types that have different serializations
        /// </summary>
        public Dictionary<string, List<ShaderSerializationDifference>> VertexFactorySerializationDifferences = new();

        /// <summary>
        /// List of same-serialization types
        /// </summary>
        public List<string> VertexFactorySerializationIdenticals = new();

        internal void AddVertexFactorySerializationDifference(string stn, int i, string msg)
        {
            if (!VertexFactorySerializationDifferences.ContainsKey(stn))
            {
                VertexFactorySerializationDifferences[stn] = new List<ShaderSerializationDifference>();
            }
            VertexFactorySerializationDifferences[stn].Add(new ShaderSerializationDifference
            {
                SerializationIndex = i,
                Message = msg
            });
        }
        #endregion

        #region SHADER
        /// <summary>
        /// Shader types that have different serializations
        /// </summary>
        public Dictionary<string, List<ShaderSerializationDifference>> ShaderSerializationDifferences = new();

        /// <summary>
        /// List of same-serialization types
        /// </summary>
        public List<string> ShaderSerializationIdenticals = new();


        internal void AddShaderSerializationDifference(string stn, int i, string msg)
        {
            if (!ShaderSerializationDifferences.ContainsKey(stn))
            {
                ShaderSerializationDifferences[stn] = new List<ShaderSerializationDifference>();
            }
            ShaderSerializationDifferences[stn].Add(new ShaderSerializationDifference
            {
                SerializationIndex = i,
                Message = msg
            });
        }
        #endregion

        internal void PrintDifferences()
        {
            Console.WriteLine($"------------------{Game1} vs {Game2} SHADER SERIALIZATION ----------------------------");
            Console.WriteLine($"---Unique Vertex Factory Types---");
            Console.WriteLine($"{Game1} has {VertexFactoryTypesOnlyInGame1.Count} vertex shader types that are not in {Game2}");
            Console.WriteLine($"{Game2} has {VertexFactoryTypesOnlyInGame2.Count} vertex shaders types that are not in {Game1}");
            PrintUniqueShaderTypes(Game1, VertexFactoryTypesOnlyInGame1);
            PrintUniqueShaderTypes(Game2, VertexFactoryTypesOnlyInGame2);
            Console.WriteLine($"--- {VertexFactorySerializationIdenticals.Count} Identical Vertex Factory Serializations---");
            foreach (var si in VertexFactorySerializationIdenticals)
            {
                Console.WriteLine($"  {si}");
            }

            Console.WriteLine($"--- {VertexFactorySerializationDifferences.Count} Unique Vertex Factory Serializations---");
            foreach (var suKVP in VertexFactorySerializationDifferences)
            {
                PrintSerializationDifferences(suKVP.Key, suKVP.Value);
            }


            Console.WriteLine($"---Unique Shader Types---");
            Console.WriteLine($"{Game1} has {ShaderTypesOnlyInGame1.Count} shader types that are not in {Game2}");
            Console.WriteLine($"{Game2} has {ShaderTypesOnlyInGame2.Count} shader types that are not in {Game1}");
            PrintUniqueShaderTypes(Game1, ShaderTypesOnlyInGame1);
            PrintUniqueShaderTypes(Game2, ShaderTypesOnlyInGame2);
            Console.WriteLine($"--- {ShaderSerializationIdenticals.Count} Identical Shader Serializations---");
            foreach (var si in ShaderSerializationIdenticals)
            {
                Console.WriteLine($"  {si}");
            }

            Console.WriteLine($"--- {ShaderSerializationDifferences.Count} Unique Shader Serializations---");
            foreach (var suKVP in ShaderSerializationDifferences)
            {
                PrintSerializationDifferences(suKVP.Key, suKVP.Value);
            }

        }

        private void PrintSerializationDifferences(string stn, List<ShaderSerializationDifference> diffs)
        {
            Console.WriteLine($"  ---{stn}---");
            if (diffs.Count == 0)
            {
                Console.WriteLine("    No differences found.");
            }
            else
            {
                foreach (var diff in diffs)
                {
                    Console.WriteLine($"    {diff.Message}");
                }
            }
        }

        private void PrintUniqueShaderTypes(MEGame game, List<string> shaderTypesOnlyInGame)
        {
            Console.WriteLine($"  ---{game} Unique Shader Types---");
            foreach (var st in shaderTypesOnlyInGame)
            {
                Console.WriteLine($"  {st}");
            }
        }
    }

    [DebuggerDisplay("{Game} GSC | {ShaderTypes.Count} Shader Types")]
    class GameShaderCompilation
    {
        public MEGame Game { get; init; }

        public GameShaderCompilation(MEGame game) { Game = game; }

        public Dictionary<string, ShaderSerialization> ShaderTypes = new Dictionary<string, ShaderSerialization>();
        public Dictionary<string, ShaderSerialization> VertexFactoryTypes = new Dictionary<string, ShaderSerialization>();

        private static ESerializationType GetSerializationType(string typeName)
        {
            if (typeName == "Parameter")
            {
                return ESerializationType.ST_Parameter;
            }
            else if (typeName.StartsWith("ResourceParameter"))
            {
                return ESerializationType.ST_Resource;
            }
            else if (typeName.StartsWith("VertexFactory")) // double check
            {
                return ESerializationType.ST_VertexFactory;
            }
            else if (typeName.StartsWith("IndexedParameterTArray"))
            {
                return ESerializationType.ST_IndexedParameterTArray;
            }
            else if (typeName.StartsWith("IndexedResourceParameterTArray"))
            {
                return ESerializationType.ST_IndexedResourceParameterTArray;
            }
            else
            {
                throw new ArgumentException($"Unknown serialization type: {typeName}");
            }
        }

        internal void ReadOutput(string[] fileLines)
        {
            ShaderSerialization currentShader = null;
            foreach (var line in fileLines)
            {
                if (!line.StartsWith("  "))
                {
                    bool parsingVF = false;
                    string typeName = line.Trim();
                    if (typeName.StartsWith("[VF"))
                    {
                        // Vertex Factory
                        parsingVF = true;
                        typeName = typeName.Substring(4); // Remove [VF]
                    }

                    // Start of a new shader type
                    if (currentShader != null)
                    {
                        // Cache last one
                        if (currentShader.IsVertexFactory)
                        {
                            VertexFactoryTypes[currentShader.ShaderTypeName] = currentShader;
                        }
                        else
                        {
                            ShaderTypes[currentShader.ShaderTypeName] = currentShader;
                        }
                    }

                    // Start new shader obj
                    currentShader = new ShaderSerialization
                    {
                        ShaderTypeName = typeName,
                        IsVertexFactory = parsingVF
                    };
                }
                else
                {
                    // Info about existing shader type
                    var tline = line.Trim();
                    if (tline.StartsWith("@@"))
                    {
                        // Binding, we don't really care...
                        continue;
                    }
                    else if (tline.StartsWith("<<"))
                    {
                        // Parameter info
                        var parts = tline.Split();
                        currentShader.Parameters.Add(new SingleSerialization()
                        {
                            // Offset is 0, we don't really care as it's not reliable across games
                            Type = GetSerializationType(parts[2]), // Get the serialization type
                            ParameterName = parts[4] // Add the parameter name.
                        }); // Add the parameter name
                    }
                }
            }

            // Cache final
            if (currentShader.IsVertexFactory)
            {
                VertexFactoryTypes[currentShader.ShaderTypeName] = currentShader;
            }
            else
            {
                ShaderTypes[currentShader.ShaderTypeName] = currentShader;
            }
        }



        /// <summary>
        /// Compares differences between shader infos
        /// </summary>
        /// <param name="le1Info"></param>
        /// <exception cref="NotImplementedException"></exception>
        internal GameComparison Compare(GameShaderCompilation other)
        {
            GameComparison gc = new GameComparison(Game, other.Game);
            gc.VertexFactoryTypesOnlyInGame1 = CompareVertexFactoryTypeNames(other);
            gc.VertexFactoryTypesOnlyInGame2 = other.CompareVertexFactoryTypeNames(this);
            gc.ShaderTypesOnlyInGame1 = CompareShaderTypeNames(other);
            gc.ShaderTypesOnlyInGame2 = other.CompareShaderTypeNames(this);

            // Compare serializations
            var allVertexFactoryTypeNames = VertexFactoryTypes.Keys.Concat(other.VertexFactoryTypes.Keys).Distinct().OrderBy(x => x).ToList();
            foreach (var stn in allVertexFactoryTypeNames)
            {
                if (gc.VertexFactoryTypesOnlyInGame1.Contains(stn) || gc.VertexFactoryTypesOnlyInGame2.Contains(stn))
                {
                    // We know this difference
                    continue;
                }

                var game1Serialization = VertexFactoryTypes[stn];
                var game2Serialization = other.VertexFactoryTypes[stn];

                var numSerializations = Math.Max(game1Serialization.Parameters.Count, game2Serialization.Parameters.Count);
                bool typeIsDifferent = false;
                for (int i = 0; i < numSerializations; i++)
                {
                    var game1s = game1Serialization.GetParameter(i);
                    var game2s = game2Serialization.GetParameter(i);

                    if (game1s != null && game2s == null)
                    {
                        // In game 1 but not game 2
                        gc.AddVertexFactorySerializationDifference(stn, i, $"[{i}] << {gc.Game1} {game1s.ParameterName} | {gc.Game2} NULL");
                        typeIsDifferent = true;
                    }
                    else if (game1s == null && game2s != null)
                    {
                        // Not in game 1 but in game 2
                        gc.AddVertexFactorySerializationDifference(stn, i, $"[{i}] >> {gc.Game2} {game2s.ParameterName} | {gc.Game1} NULL");
                        typeIsDifferent = true;
                    }
                    else if (!game1s.Equals(game2s))
                    {
                        gc.AddVertexFactorySerializationDifference(stn, i, $"[{i}] !! {gc.Game1} {game1s.ParameterName} | {gc.Game2} {game2s.ParameterName}");
                        typeIsDifferent = true;
                    }
                    else
                    {
                        // Serialization is same
                    }
                }

                if (!typeIsDifferent)
                {
                    gc.VertexFactorySerializationIdenticals.Add(stn);
                }
            }


                var allShaderTypeNames = ShaderTypes.Keys.Concat(other.ShaderTypes.Keys).Distinct().OrderBy(x => x).ToList();
            foreach (var stn in allShaderTypeNames)
            {
                if (gc.ShaderTypesOnlyInGame1.Contains(stn) || gc.ShaderTypesOnlyInGame2.Contains(stn))
                {
                    // We know this difference
                    continue;
                }

                var game1Serialization = ShaderTypes[stn];
                var game2Serialization = other.ShaderTypes[stn];

                // SHIFTED COMPARE
                if (true)
                {
                    var sizeDiff = Math.Abs(game1Serialization.Parameters.Count - game2Serialization.Parameters.Count);
                    bool hasDifferentCounts = game1Serialization.Parameters.Count != game2Serialization.Parameters.Count;


                    var numSerializations = Math.Max(game1Serialization.Parameters.Count, game2Serialization.Parameters.Count);
                    bool typeIsDifferent = false;
                    int ig1 = -1;
                    int ig2 = -1;

                    for (int i = 0; i < numSerializations; i++)
                    {
                        ig1++;
                        ig2++;
                        var game1s = game1Serialization.GetParameter(ig1);
                        var game2s = game2Serialization.GetParameter(ig2);

                        if (gc.Game1 == MEGame.LE1 && gc.Game2 == MEGame.LE2)
                        {
                            if (game1s.ParameterName == "SceneColorTexture" && sizeDiff >= 4)
                            {
                                gc.AddShaderSerializationDifference(stn, i, $"[{i}] << {gc.Game1} [FSceneTextureShaderParameters] | {gc.Game2} NULL");
                                game2Serialization.Parameters.Insert(i, game1Serialization.GetParameter(ig1));
                                game2Serialization.Parameters.Insert(i + 1, game1Serialization.GetParameter(ig1 + 1));
                                game2Serialization.Parameters.Insert(i + 2, game1Serialization.GetParameter(ig1 + 2));
                                game2Serialization.Parameters.Insert(i + 3, game1Serialization.GetParameter(ig1 + 3));
                                typeIsDifferent = true;
                                continue;
                            }
                        }

                        if (game1s != null && game2s == null)
                        {
                            // In game 1 but not game 2
                            gc.AddShaderSerializationDifference(stn, i, $"[{i}] << {gc.Game1} {game1s.ParameterName} | {gc.Game2} NULL");
                            typeIsDifferent = true;
                        }
                        else if (game1s == null && game2s != null)
                        {
                            // Not in game 1 but in game 2
                            gc.AddShaderSerializationDifference(stn, i, $"[{i}] >> {gc.Game2} {game2s.ParameterName} | {gc.Game1} NULL");
                            typeIsDifferent = true;
                        }
                        else if (!game1s.Equals(game2s))
                        {
                            gc.AddShaderSerializationDifference(stn, i, $"[{i}] !! {gc.Game1} {game1s.ParameterName} | {gc.Game2} {game2s.ParameterName}");
                            typeIsDifferent = true;
                        }
                        else
                        {
                            // Serialization is same
                        }
                    }

                    if (!typeIsDifferent)
                    {
                        gc.ShaderSerializationIdenticals.Add(stn);
                    }

                    //if (ig1 != game1Serialization.Parameters.Count-1)
                    //    Debugger.Break();
                    //if (ig2 != game2Serialization.Parameters.Count-1)
                    //    Debugger.Break();
                }

            }

            return gc;
        }

        private List<string> CompareVertexFactoryTypeNames(GameShaderCompilation other)
        {
            List<string> onlyInMe = new List<string>();
            foreach (var stn in VertexFactoryTypes.Keys)
            {
                if (!other.VertexFactoryTypes.ContainsKey(stn))
                {
                    onlyInMe.Add(stn);
                }
            }

            return onlyInMe;
        }

        private List<string> CompareShaderTypeNames(GameShaderCompilation other)
        {
            List<string> onlyInMe = new List<string>();
            foreach (var stn in ShaderTypes.Keys)
            {
                if (!other.ShaderTypes.ContainsKey(stn))
                {
                    onlyInMe.Add(stn);
                }
            }

            return onlyInMe;
        }
    }

    internal class Program
    {

        static void Main(string[] args)
        {
            var le1File = File.ReadAllLines(@"S:\Milan\ShaderResearch\LE1ShaderSerialization.txt");
            var le2File = File.ReadAllLines(@"S:\Milan\ShaderResearch\LE2ShaderSerialization.txt");
            var le3File = File.ReadAllLines(@"S:\Milan\ShaderResearch\LE3ShaderSerialization.txt");

            var le1Info = new GameShaderCompilation(MEGame.LE1);
            le1Info.ReadOutput(le1File);

            var le2Info = new GameShaderCompilation(MEGame.LE2);
            le2Info.ReadOutput(le2File);

            var le3Info = new GameShaderCompilation(MEGame.LE3);
            le3Info.ReadOutput(le3File);

            //var le1le2Diff = le1Info.Compare(le2Info);
            //var le2le1Diff = le2Info.Compare(le1Info);

            var le1le3Diff = le1Info.Compare(le3Info);
            var le2le3Diff = le2Info.Compare(le3Info);


            le1le3Diff.PrintDifferences();
            //le2le3Diff.PrintDifferences();

            Console.WriteLine("End of report");
            Console.ReadLine();
            // le3Info.ReadOutput(le3File); // Placeholder for LE3, using LE1 as an example

        }
    }
}
