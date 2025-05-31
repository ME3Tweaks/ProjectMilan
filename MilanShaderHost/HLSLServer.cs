using System;
using System.Collections.Generic;
using System.IO.Pipes;
using System.Linq;
using System.Security.AccessControl;
using System.Text;
using System.Threading.Tasks;

namespace MilanShaderHost
{
    /// <summary>
    /// Handles listening for HLSL dumps from the games.
    /// </summary>
    public class HLSLServer
    {
        private const string pipeName = @"milanshaderhost";
        public HLSLServer() { }

        /// <summary>
        /// Starts listening for HLSL calls. This method is blocking.
        /// </summary>
        public void StartListening()
        {
            using var server = new NamedPipeServerStream(pipeName, PipeDirection.InOut, 1, PipeTransmissionMode.Byte);
            var reader = new StreamReader(server);
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
                    Console.WriteLine($"Received message: {line}");
                    //writer.WriteLine(String.Join("", line.Reverse()));
                }
                //writer.Flush();
            }
        }
    }
}
