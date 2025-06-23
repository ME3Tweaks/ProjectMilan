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
        }

        MEGame game = MEGame.LE3;
        EReadMode CurrentReadMode = EReadMode.None;
        int IncomingShaderCacheSize = 0;

        public static event EventHandler ShaderCacheUpdated;

        internal void StartListening()
        {
            if (File.Exists(shaderCacheFile))
            {
                File.Delete(shaderCacheFile);
            }

            ShaderCache buildingCache = null;

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
                    MemoryStream incomingCacheTemp = new MemoryStream(incomingShaderCache);
                    incomingCacheTemp.Skip(4); // Netindex
                    incomingCacheTemp.ReadUnrealString(); // None

                    MemoryStream incomingCache = new MemoryStream();
                    WriteFakeGlobalCacheHeader(incomingCache, game);
                    incomingCacheTemp.CopyTo(incomingCache);
                    incomingCache.Position = 0;
                    // incomingCache.WriteToFile(@"C:\users\public\shadercache.bin");
                    var cache = ShaderCache.ReadGlobalShaderCache(incomingCache, game);

                    if (buildingCache == null)
                    {
                        buildingCache = cache;
                    }
                    else
                    {
                        cache.MergeInto(buildingCache, true);
                    }
                    WriteCacheToFile(buildingCache);
                    CurrentReadMode = EReadMode.None; // Reset
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
                    var outF = Path.Combine(@"C:\users\public\matbins", materialName + ".bin");
                    File.WriteAllBytes(outF, materialResourceBin);

                    Console.WriteLine($"Received material resource binary for {materialName}, {incomingDataLen} bytes");

                    CurrentReadMode = EReadMode.None;
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

            // Notify listeners that we have just updated the shader cache
            if (ShaderCacheUpdated != null)
            {
                ShaderCacheUpdated.Invoke(this, EventArgs.Empty);
            }
        }



        private void WriteFakeGlobalCacheHeader(MemoryStream ms, MEGame game)
        {
            ms.WriteStringASCII("BMSG");
            ms.WriteInt32(UnrealPackageFile.UnrealVersion(game));
            ms.WriteInt32(UnrealPackageFile.LicenseeVersion(game));
        }


    }
}