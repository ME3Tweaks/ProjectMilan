using System.IO.Pipes;
using System.Text;

namespace MilanShaderHost
{
    enum EReadMode
    {
        None,
        MaterialName,
        MaterialHLSL
    }

    /// <summary>
    /// Handles listening for HLSL dumps from the games.
    /// </summary>
    public class HLSLServer
    {
        private const string pipeName = @"milanshaderhost";
        public HLSLServer() { }

        private EReadMode CurrentReadMode = EReadMode.None;
        private string CurrentMaterialName = null;
        private StringBuilder CurrentMaterialHLSL = null;

        /// <summary>
        /// Starts listening for HLSL calls. This method is blocking.
        /// </summary>
        public void StartListening()
        {
            using var server = new NamedPipeServerStream(pipeName, PipeDirection.InOut, 1, PipeTransmissionMode.Message);
            var reader = new StreamReader(server, Encoding.Unicode);
            var writer = new StreamWriter(server);
            Console.WriteLine($"Listening for HLSL dumps on named pipe '{pipeName}'");
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

                var line = reader.ReadLine();
                if (!server.IsConnected)
                {
                    continue;
                }

                if (!string.IsNullOrEmpty(line))
                {

                    if (line.StartsWith("[MATERIALNAME]"))
                    {
                        // Start of a new material.
                        CurrentReadMode = EReadMode.MaterialName;
                        CurrentMaterialName = null;
                        CurrentMaterialHLSL = new StringBuilder();
                        continue;
                    }

                    if (line.StartsWith("[MATERIALHLSL]"))
                    {
                        // Start of a new HLSL dump.
                        CurrentReadMode = EReadMode.MaterialHLSL;
                        continue;
                    }

                    if (line.StartsWith("[ENDMATERIALHLSL]"))
                    {
                        // End of HLSL dump.
                        var hlsl = CurrentMaterialHLSL.ToString();
                        HandleMaterialHLSL(CurrentMaterialName, hlsl);

                        CurrentReadMode = EReadMode.None;
                        continue;
                    }

                    // Not a command
                    switch (CurrentReadMode)
                    {
                        case EReadMode.MaterialName:
                            // Read material name
                            CurrentMaterialName = line.Trim();
                            Console.WriteLine($"Incoming material HLSL: {CurrentMaterialName}");
                            break;
                        case EReadMode.MaterialHLSL:
                            // Read material HLSL
                            if (CurrentMaterialHLSL != null)
                            {
                                CurrentMaterialHLSL.AppendLine(line.Trim());
                            }
                            break;
                    }

                }
                //writer.Flush();
            }
        }

        private void HandleMaterialHLSL(string materialName, string materialHLSL)
        {
            var outFile = Path.Combine(@"S:\Milan\UDK\MilanShaderComp", $"{materialName}.hlsl");
            File.WriteAllText(outFile, materialHLSL);

            // Compile shader
            ShaderCompiler.CompileShadersFor(materialHLSL);
        }
    }
}
