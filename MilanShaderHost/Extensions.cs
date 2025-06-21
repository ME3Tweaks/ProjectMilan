using LegendaryExplorerCore.Gammtek.Extensions.IO;
using LegendaryExplorerCore.Helpers;
using System.Text;

namespace MilanShaderHost
{
    public static class Extensions
    {
        /// <summary>
        /// Writes a string to the stream, in the format used by UE3ShaderCompileWorker.
        /// </summary>
        /// <param name="fs"></param>
        /// <param name="str"></param>
        public static void WriteShaderString(this Stream fs, string str)
        {
            fs.WriteInt32(str.Length);
            if (str.Length > 0)
            {
                fs.WriteStringASCII(str);
            }
        }

        /// <summary>
        /// Reads a C style null terminated ASCII string
        /// </summary>
        /// <param name="reader">The binary reader</param>
        /// <returns>A string as read from the stream</returns>
        public static string ReadSZString(this BinaryReader reader)
        {
            var result = new StringBuilder();
            while (true)
            {
                byte b = reader.ReadByte();
                if (0 == b)
                    break;
                result.Append((char)b);
            }
            return result.ToString();
        }
    }
}
