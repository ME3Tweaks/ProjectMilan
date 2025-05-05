using LegendaryExplorerCore.Gammtek.Extensions.IO;
using LegendaryExplorerCore.Helpers;

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
    }
}
