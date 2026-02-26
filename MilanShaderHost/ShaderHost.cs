using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
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
        }

        EReadMode CurrentReadMode = EReadMode.None;
        int IncomingShaderCacheSize = 0;

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
                        // We just exit, it may be pipe disconnected
                    }
                    continue;

                }
                else if (CurrentReadMode == EReadMode.ShaderCache)
                {
                    if (IncomingShaderCacheSize == 0)
                    {
                        IncomingShaderCacheSize = reader.ReadInt32();
                        Console.WriteLine($"Incoming shader cache, {IncomingShaderCacheSize} bytes");
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
            }
        }

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