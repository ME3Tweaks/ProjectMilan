using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.UnrealScript.Compiling.Errors;
using ProjectMilanCore;
using Serilog;

// Ported from ME3TweaksCore
namespace ProjectMilan
{
    /// <summary>
    /// Logger for Project Milan.
    /// </summary>
    public static class MilanLog
    {
        /// <summary>
        /// Logging prefix for Project Milan logs.
        /// </summary>
        private const string InternalLoggingPrefix = @"MILAN";

        /// <summary>
        /// Set to false to reduce text spam during content porting
        /// </summary>
        public static bool LogDonorMessages = true;

        /// <summary>
        /// Denotes a new session in the log
        /// </summary>
        /// <param name="customPrefix"></param>
        public static void LogSessionStart(string customPrefix = InternalLoggingPrefix)
        {
            Log.Information($"[{customPrefix}] ===========================================================================");
        }

        /// <summary>
        /// Logs a string to the log. You can specify a boolean for log checking (for making calls easier)
        /// </summary>
        /// <param name="message"></param>
        /// <param name="shouldLog"></param>
        /// <param name="customPrefix"></param>
        public static void Information(string message, bool shouldLog = true, string customPrefix = InternalLoggingPrefix)
        {
            if (shouldLog)
            {
                Log.Information($@"[{customPrefix}] {message}");
            }
        }

        /// <summary>
        /// Logs a string to the log. You can specify a boolean for log checking (for making calls easier)
        /// </summary>
        public static void Warning(string message, bool shouldLog = true, string customPrefix = InternalLoggingPrefix)
        {
            if (shouldLog)
            {
                Log.Warning($@"[{customPrefix}] {message}");
            }
        }

        /// <summary>
        /// Logs a string to the log. You can specify a boolean for log checking (for making calls easier)
        /// </summary>
        public static void Error(string message, bool shouldLog = true, string customPrefix = InternalLoggingPrefix)
        {
            if (shouldLog)
            {
                Log.Error($@"[{customPrefix}] {message}");
            }
        }

        /// <summary>
        /// Logs a string to the log. You can specify a boolean for log checking (for making calls easier)
        /// </summary>
        public static void Error(Exception ex, bool shouldLog = true, string customPrefix = InternalLoggingPrefix)
        {
            if (shouldLog)
            {
                Log.Error($@"[{customPrefix}] {ex.FlattenException()}");
            }
        }

        /// <summary>
        /// Logs a string to the log. You can specify a boolean for log checking (for making calls easier)
        /// </summary>
        public static void Fatal(string message, bool shouldLog = true, string customPrefix = InternalLoggingPrefix)
        {
            if (shouldLog)
            {
                Log.Fatal($@"[{customPrefix}] {message}");
            }
        }

        /// <summary>
        /// Calls Log.CloseAndFlush().
        /// </summary>
        public static void CloseAndFlush()
        {
            Log.CloseAndFlush();
        }

        /// <summary>
        /// Writes a pre-message and a stacktrace to the log.
        /// </summary>
        /// <param name="exception"></param>
        /// <param name="preMessage"></param>
        /// <param name="fatal"></param>
        /// <param name="customPrefix"></param>
        public static void Exception(Exception exception, string preMessage, bool fatal = false, string customPrefix = InternalLoggingPrefix)
        {
            Log.Error($@"[{customPrefix}] {preMessage}");

            // Log exception
            while (exception != null)
            {
                var line1 = exception.GetType().Name + @": " + exception.Message;
                foreach (var line in line1.Split("\n")) // do not localize
                {
                    if (fatal)
                        Log.Fatal(customPrefix + line);
                    else
                        Log.Error(customPrefix + line);

                }

                if (exception.StackTrace != null)
                {
                    foreach (var line in exception.StackTrace.Split("\n")) // do not localize
                    {
                        if (fatal)
                            Log.Fatal(customPrefix + line);
                        else
                            Log.Error(customPrefix + line);
                    }
                }

                exception = exception.InnerException;
            }
        }

        /// <summary>
        /// Writes a debug log statement
        /// </summary>
        public static void Debug(string message, bool shouldLog = true, string customPrefix = InternalLoggingPrefix)
        {
            if (shouldLog)
            {
                Log.Debug($@"[{customPrefix}] {message}");
            }
        }

        public static void CreateLogger()
        {
            var sessionId = DateTime.Now.ToString("yyyyMMdd_HHmmss");
            Log.Logger = new LoggerConfiguration()
                // Write to the console
                .WriteTo.Console()

                // Write to disk file (for reviewing)
                // File based logging
                .WriteTo
                .File(Path.Combine(MilanShared.PipelineRoot, "..", "Logs", $@"ProjectMilan_{sessionId}.txt"), retainedFileCountLimit: 3, shared: true)

#if DEBUG
                // Write to Visual Studio debug console
                .WriteTo.Debug()
#endif

                .CreateLogger();
        }

        public static void LogUSCErrors(MessageLog log)
        {
            foreach (var msg in log.AllErrors)
            {
                MilanLog.Error(msg.ToString(), customPrefix: @"UnrealScriptCompiler");
            }
        }
    }
}
