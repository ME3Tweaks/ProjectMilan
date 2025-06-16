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

        enum EReadMode
        {
            None = 0,
            // INT size
            // BYTE[size]
            ShaderCache = 1
        }



        IMEPac
        MEGame game = MEGame.LE3;
        EReadMode CurrentReadMode = EReadMode.None;
        int IncomingShaderCacheSize = 0;

        public static event EventHandler ShaderCacheUpdated;

        internal void StartListening()
        {
            ShaderCache buildingCache = null;

            using var server = new NamedPipeServerStream(pipeName, PipeDirection.InOut, 1, PipeTransmissionMode.Byte);
            var reader = new BinaryReader(server, Encoding.Unicode);
            var writer = new StreamWriter(server);
            Console.WriteLine($"Listening for ShaderCache data on named pipe '{pipeName}'");
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
                    var commandByte = reader.ReadByte();
                    CurrentReadMode = (EReadMode)commandByte;
                    continue;

                }
                else if (CurrentReadMode == EReadMode.ShaderCache)
                {
                    if (IncomingShaderCacheSize == 0)
                    {
                        IncomingShaderCacheSize = reader.ReadInt32();
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
                    continue;
                }
            }
        }

        private void WriteCacheToFile(ShaderCache cache)
        {
            var shaderOutputFile = @"C:\users\public\MilanShaderCache.pcc";
            IMEPackage package = null;
            if (File.Exists(shaderOutputFile))
            {
                package = MEPackageHandler.OpenMEPackage(shaderOutputFile);
                var sfsc = ExportCreator.CreateExport(package, "SeekFreeShaderCache", "ShaderCache", indexed: false);
                sfsc.WriteProperty(new NoneProperty());
                sfsc.WriteBinary(cache);
            }
            else
            {
                package = MEPackageHandler.CreateAndOpenPackage(shaderOutputFile, MEGame.LE3);
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