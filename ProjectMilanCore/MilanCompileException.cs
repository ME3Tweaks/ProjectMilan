namespace ProjectMilanCore
{
    /// <summary>
    /// Thrown when a Milan UnrealScript override fails to compile
    /// </summary>
    public class MilanCompileException : Exception
    {
        public MilanCompileException(string message) : base(message)
        {
        }

        public MilanCompileException(string message, Exception innerException) : base(message, innerException)
        {
        }
    }
}
