using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using MilanShaderHost.Old;
using MilanShaderResearchTool;
using Newtonsoft.Json;
using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Text;
namespace MilanShaderHost
{
    /// <summary>
    /// Listens for UShaderCache binary from the game.
    /// </summary>
    internal class ShaderHost
    {
        private const string pipeName = @"milanshaderhost";

        // Todo: make this more dynamic
        private string shaderCacheFile = @"C:\users\public\MilanShaderCache.pcc";

        enum EReadMode
        {
            None = 0,
            // INT size
            // BYTE[size]
            /// <summary>
            /// A ShaderCache binary is about to be sent to us.
            /// </summary>
            ShaderCache = 1,
            /// <summary>
            /// ShaderHost should kill the game process as it is no longer needed.
            /// </summary>
            TerminateGame = 2,
            /// <summary>
            /// ShaderClient failed to compile a shader, the error message will follow.
            /// </summary>
            ShaderCompilationFailed = 3,
            /// <summary>
            /// A MaterialResource is about to be sent to us.
            /// </summary>
            MaterialResource = 4,
            /// <summary>
            /// The Material HLSL the game has generated for a material is about to be sent to us.
            /// </summary>
            MaterialHLSL = 5,
            /// <summary>
            /// Debug package JSON is coming in next
            /// </summary>
            DebugPackage = 6,
            /// <summary>
            /// A complete FTerrainMaterialResource is about to be sent. Unlike MaterialResource,
            /// this includes the native terrain-specific extension (owner, mask, material IDs and
            /// lighting GUID) required to persist the result into Terrain.CachedTerrainMaterials.
            /// </summary>
            TerrainMaterialResource = 7,
        }

        EReadMode CurrentReadMode = EReadMode.None;
        int IncomingShaderCacheSize = 0;

        // Debug packages are returned for every material the compiler map happens to load,
        // including imported dependency materials. Keep the currently requested source package
        // here so those dependency captures cannot overwrite the standalone capture that owns
        // the same qualified material path.
        private sealed class DebugCaptureSession(string packageName)
        {
            internal string PackageName { get; } = packageName;
            internal TaskCompletionSource PipeDrained { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
            internal int SkippedForeignPayloadCount;

            /// <summary>
            /// Foreign-package payloads kept because they are instance permutations this capture is
            /// the only source of. Reported separately so the ownership rule's effect stays visible.
            /// </summary>
            internal int RetainedForeignPermutationCount;
            internal int RetainedPayloadCount;
        }

        private static DebugCaptureSession? activeDebugCapture;

        /// <summary>Debug payloads retained by the most recently finished capture.</summary>
        internal static int LastCaptureRetainedPayloadCount;

        internal static void BeginDebugCapture(string packageName)
        {
            ArgumentException.ThrowIfNullOrWhiteSpace(packageName);
            var session = new DebugCaptureSession(packageName);
            if (Interlocked.CompareExchange(ref activeDebugCapture, session, null) != null)
            {
                throw new InvalidOperationException("Cannot start a debug capture before the previous game's pipe payloads have drained.");
            }
        }

        internal static void EndDebugCapture(string packageName)
        {
            var session = Volatile.Read(ref activeDebugCapture);
            if (session == null || !string.Equals(session.PackageName, packageName, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException($"Debug capture state was lost while waiting for {packageName}.");
            }

            // Process exit only closes the client end. The pipe can still hold JSON that the
            // listener has not read yet, so keep the ownership boundary active until that stream
            // is fully drained. Starting the next game early would otherwise misclassify its tail.
            if (!session.PipeDrained.Task.Wait(TimeSpan.FromSeconds(60)))
            {
                throw new TimeoutException($"ShaderClient's pipe did not drain within 60 seconds after {packageName} exited; refusing to start the next capture with an unsafe ownership boundary.");
            }

            if (Interlocked.CompareExchange(ref activeDebugCapture, null, session) != session)
            {
                throw new InvalidOperationException($"Debug capture state changed while finishing {packageName}.");
            }

            var retainedForeign = Volatile.Read(ref session.RetainedForeignPermutationCount);
            if (retainedForeign > 0)
            {
                Console.WriteLine($"Kept {retainedForeign:N0} foreign-package permutation payload(s) while capturing {packageName}; they are filed under their parent material's package.");
            }

            var skippedCount = Volatile.Read(ref session.SkippedForeignPayloadCount);
            if (skippedCount > 0)
            {
                Console.WriteLine($"Discarded {skippedCount:N0} foreign debug package payload(s) while capturing {packageName}.");
            }

            // The retained count is what a --captureonly run actually produces. Merged compile
            // resources are a separate product and can legitimately be zero while the capture is
            // fine, so the caller needs this number rather than that one to judge the run.
            LastCaptureRetainedPayloadCount = Volatile.Read(ref session.RetainedPayloadCount);
            Console.WriteLine($"Captured {LastCaptureRetainedPayloadCount:N0} debug package payload(s) for {packageName}.");
        }

        private static bool IsForeignDebugPackage(string packageName, string localIFP)
        {
            var session = Volatile.Read(ref activeDebugCapture);
            if (session == null || packageName == "Unqualified")
            {
                // Preserve the existing Unqualified bucket: there is no reliable package
                // ownership information to filter on, and it cannot overwrite a qualified job.
                return false;
            }

            if (string.Equals(session.PackageName, packageName, StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }

            // A MaterialInstance permutation is compiled through its *parent* UMaterial, so a level
            // package's instance of a shared master material (BioG_MasterMats, BioG_LevelDetails,
            // BioG_Volumetric...) arrives attributed to the master's package and looks foreign --
            // even though this capture is the only thing that will ever ask for that permutation.
            // The master's own standalone capture cannot produce it: the instance that needs it does
            // not live there.
            //
            // Discarding it is what the ownership rule was protecting against for *base* materials,
            // where the same material compiled under two packages would overwrite one capture with
            // another. A permutation cannot do that. It is filed under `<parent>#<set hash>`, a
            // directory the parent's base-material capture never writes, and any other package
            // asking for the same set produces the same shader map by definition -- the hash *is*
            // the static parameter set, which is the engine's own shader map identity.
            //
            // Measured on BioT_CitCasino before this changed: 38 distinct permutations predicted,
            // 13 captured, 25 discarded here -- two thirds of the permutations in a typical level
            // package, concentrated on the most reused materials in the game.
            if (StaticPermutationNaming.HasPermutationKey(localIFP))
            {
                Interlocked.Increment(ref session.RetainedForeignPermutationCount);
                return false;
            }

            Interlocked.Increment(ref session.SkippedForeignPayloadCount);
            return true;
        }

        private static void MarkDebugCapturePipeDrained()
        {
            Volatile.Read(ref activeDebugCapture)?.PipeDrained.TrySetResult();
        }

        /// <summary>
        /// Invoked when a new shader cache is generated (a material has been successfully compiled)
        /// </summary>
        public static event EventHandler<CompileResult> NewShaderCacheGenerated;

        internal void StartListening()
        {
            if (File.Exists(shaderCacheFile))
            {
                File.Delete(shaderCacheFile);
            }

            // Used to pass to the flow to compile a package
            CompileResult cr = null;

            using var server = new NamedPipeServerStream(pipeName, PipeDirection.InOut, 1, PipeTransmissionMode.Byte);
            var reader = new BinaryReader(server, Encoding.Unicode);
            var writer = new StreamWriter(server);
            Console.WriteLine($"Listening for shader data on named pipe '{pipeName}'...");

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
                        // End-of-stream is the point at which every buffered payload from this
                        // game has been read. Let the launcher advance only after this signal.
                        MarkDebugCapturePipeDrained();
                        CurrentReadMode = EReadMode.None;
                    }
                    continue;

                }
                else if (CurrentReadMode == EReadMode.ShaderCache)
                {
                    if (IncomingShaderCacheSize == 0)
                    {
                        IncomingShaderCacheSize = reader.ReadInt32();
                        Console.WriteLine($"Incoming shader cache, {IncomingShaderCacheSize} bytes ({FileSize.FormatSize(IncomingShaderCacheSize)})");
                        // continue;
                    }

                    var incomingShaderCache = reader.ReadBytes(IncomingShaderCacheSize);
                    // Console.WriteLine($"Read {IncomingShaderCacheSize} bytes from client");

                    MemoryStream incomingCacheTemp = new MemoryStream(incomingShaderCache);
                    // incomingCacheTemp.WriteToFile(@"C:\users\public\shadercache_raw.bin");
                    incomingCacheTemp.Skip(4); // Netindex
                    var inStr = incomingCacheTemp.ReadUnrealString(); // None
                    // Debug.WriteLine("Should be none: " + inStr);
                    MemoryStream incomingCache = new MemoryStream();
                    incomingCacheTemp.CopyTo(incomingCache);
                    incomingCache.Position = 0;
                    // incomingCache.WriteToFile(@"C:\users\public\shadercache.bin");
                    var packagelessSC = new PackagelessSerializingContainer(incomingCache, null, true);
                    packagelessSC.SetGame(Program.Game);
                    var cache = new ShaderCache() { Packageless = true };
                    cache.PublicSerialize(packagelessSC);

                    cr = new CompileResult() { Cache = cache };
                    // WriteCacheToFile(buildingCache);
                    IncomingShaderCacheSize = 0; // Reset
                    CurrentReadMode = EReadMode.None; // Reset
                    // Console.WriteLine();
                    continue;
                }
                else if (CurrentReadMode == EReadMode.TerminateGame)
                {
                    MilanShaderBuilderFlow.KillGame();
                    CurrentReadMode = EReadMode.None;
                }
                else if (CurrentReadMode == EReadMode.ShaderCompilationFailed)
                {
                    var errorMessage = reader.ReadSZString();
                    Console.WriteLine(errorMessage);
                    MilanShaderBuilderFlow.MarkCompileFailure(errorMessage);
                    CurrentReadMode = EReadMode.None;
                }
                else if (CurrentReadMode == EReadMode.MaterialResource)
                {
                    // String incoming.
                    var strLen = reader.ReadInt32();
                    var strData = reader.ReadBytes(strLen); // Unicode
                    var materialName = Encoding.Unicode.GetString(strData);
                    Console.WriteLine($"Incoming material data: {materialName}");

                    // Material binary incoming.
                    var incomingDataLen = reader.ReadInt32();
                    var materialResourceBin = reader.ReadBytes(incomingDataLen);
                    //var outF = Path.Combine(out, materialName + ".bin");
                    //File.WriteAllBytes(outF, materialResourceBin);
                    cr.MaterialName = materialName;
                    cr.MaterialResource = materialResourceBin;
                    NewShaderCacheGenerated?.Invoke(this, cr);
                    cr = null; // Reset

                    //Console.WriteLine($"Received material resource binary for {materialName}, {incomingDataLen} bytes");
                    CurrentReadMode = EReadMode.None;
                    Console.WriteLine();
                }
                else if (CurrentReadMode == EReadMode.TerrainMaterialResource)
                {
                    if (cr == null)
                    {
                        throw new InvalidOperationException("Received terrain resource data before its shader cache.");
                    }

                    var terrainPathLength = reader.ReadInt32();
                    var terrainPath = Encoding.Unicode.GetString(reader.ReadBytes(terrainPathLength));
                    var resourceLength = reader.ReadInt32();
                    var resource = reader.ReadBytes(resourceLength);

                    Console.WriteLine($"Incoming terrain resource data: {terrainPath}");
                    cr.IsTerrainResource = true;
                    cr.TerrainPath = terrainPath;
                    cr.MaterialName = terrainPath;
                    cr.MaterialResource = resource;
                    NewShaderCacheGenerated?.Invoke(this, cr);
                    cr = null;

                    CurrentReadMode = EReadMode.None;
                    Console.WriteLine();
                }
                else if (CurrentReadMode == EReadMode.MaterialHLSL)
                {
                    // String incoming.
                    var strLen = reader.ReadInt32();
                    var strData = reader.ReadBytes(strLen); // Unicode
                    var materialIFP = Encoding.Unicode.GetString(strData);
                    Console.WriteLine($"  Incoming HLSL for material: {materialIFP}");
                    var hlslLen = reader.ReadInt32();
                    var hlslData = reader.ReadBytes(hlslLen);
                    var hlsl = Encoding.Unicode.GetString(hlslData);

                    var outPath = Path.Combine(MilanShaderBuilderFlow.DecookedPackagesPath, "HLSL", MilanShaderBuilderFlow.Game.ToString());
                    Directory.CreateDirectory(outPath);
                    var hlslPath = Path.Combine(outPath, materialIFP + ".hlsl");
                    File.WriteAllText(hlslPath, hlsl);
                    cr = null; // Reset
                    CurrentReadMode = EReadMode.None;
                    // Console.WriteLine();
                }
                else if (CurrentReadMode == EReadMode.DebugPackage)
                {
                    var strLen = reader.ReadInt32();
                    var strData = reader.ReadBytes(strLen); // Unicode
                    var materialIFP = Encoding.Unicode.GetString(strData);
                    var separatorIndex = materialIFP.IndexOf('.');
                    // Debug payloads are normally fully qualified (Package.Export), but a
                    // malformed/unqualified name must not take down the pipe server and lose
                    // all subsequent compiler results.
                    var packageName = separatorIndex >= 0 ? materialIFP.Substring(0, separatorIndex) : "Unqualified";
                    var localIFP = separatorIndex >= 0 ? materialIFP.Substring(separatorIndex + 1) : materialIFP;

                    // Console.WriteLine($"  Incoming debug package JSON for {materialIFP}");
                    var jsonLen = reader.ReadInt32();
                    var jsonData = reader.ReadBytes(jsonLen);

                    if (IsForeignDebugPackage(packageName, localIFP))
                    {
                        // The payload still has to be consumed to leave the named-pipe stream
                        // aligned for the next compiler result. Skip JSON parsing and HLSL
                        // preprocessing, however: this material belongs to another source
                        // package and would overwrite its standalone capture.
                        CurrentReadMode = EReadMode.None;
                        continue;
                    }

                    {
                        var retainSession = Volatile.Read(ref activeDebugCapture);
                        if (retainSession != null) Interlocked.Increment(ref retainSession.RetainedPayloadCount);
                    }

                    var json = Encoding.ASCII.GetString(jsonData);

                    var materialOutPath = Path.Combine(MilanShaderBuilderFlow.DecookedPackagesPath, "DebugPackages", MilanShaderBuilderFlow.Game.ToString(), packageName);

                    var obj = JsonConvert.DeserializeObject<ShaderClientDebugPackage>(json);

                    var vertexFactory = obj.vertexFactoryType;
                    var shaderName = obj.shaderType.Replace("<", "[").Replace(">", "]");

                    // Run through our preprocessor to find all possible used conditionals
                    var possibleMacros = HlslPreprocessor.FindConditionalMacros(obj.sourceFilename, obj.functionName, Path.Combine(MEDirectories.GetDefaultGamePath(Program.Game), "Engine", "Shaders"), obj.materialHlsl, obj.vertexFactoryShaderFilename);
                    obj.possibleMacros = possibleMacros.Except(KnownIgnoredMacros).ToArray();

                    var safeLocalIFP = string.Concat(localIFP.Select(c => Path.GetInvalidFileNameChars().Contains(c) ? '_' : c));
                    var shaderOutPath = Path.Combine(materialOutPath, safeLocalIFP, vertexFactory ?? "None");
                    Directory.CreateDirectory(shaderOutPath);

                    var formattedJson = JsonConvert.SerializeObject(obj, Formatting.Indented);
                    var jsonPath = Path.Combine(shaderOutPath, shaderName + ".json");
                    File.WriteAllText(jsonPath, formattedJson);

                    CurrentReadMode = EReadMode.None;
                }
            }
        }

        private static string[] KnownIgnoredMacros = [
            "ORBIS",
            "__ORBIS__",
            "SM5_PROFILE",
            "PS3",
            "SM2_PROFILE",
            "VERTEXSHADER",
            "PIXELSHADER",
            "COMPUTESHADER",
            "XBOX",
            "XBOXINSTANCING",
            //"COMPILER_SUPPORTS_EMPTY_STRUCTS",
            "COMPILER_CG",
            "COMPILER_HLSL",
            // "COMPILER_SUPPORTS_ATTRIBUTES",
            "SM3_PROFILE",
            "USING_SM5_TESSELLATION",
            "DINGO"
        ];

        private void WriteCacheToFile(ShaderCache cache)
        {
            // Switch to package-based serialization.
            cache.Packageless = false;

            IMEPackage package = null;
            if (File.Exists(shaderCacheFile))
            {
                package = MEPackageHandler.OpenMEPackage(shaderCacheFile);
                var existingCacheExport = package.FindExport("SeekFreeShaderCache");
                if (existingCacheExport != null)
                {
                    var existingCache = ObjectBinary.From<ShaderCache>(existingCacheExport);
                    cache.MergeInto(existingCache);
                    existingCacheExport.WriteBinary(cache);
                }
                else
                {
                    Debugger.Break();
                }
            }
            else
            {
                package = MEPackageHandler.CreateAndOpenPackage(shaderCacheFile, MEGame.LE3);
                var sfsc = ExportCreator.CreateExport(package, "SeekFreeShaderCache", "ShaderCache", indexed: false, prePropBinary: [0x0, 0x0, 0x0, 0x0]);
                sfsc.WriteBinary(cache);
            }

            package.Save();
        }



        private void WriteFakeGlobalCacheHeader(MemoryStream ms, MEGame game)
        {
            ms.WriteStringASCII("BMSG");
            ms.WriteInt32(UnrealPackageFile.UnrealVersion(game));
            ms.WriteInt32(UnrealPackageFile.LicenseeVersion(game));
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
