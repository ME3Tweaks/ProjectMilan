using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.UnrealScript.Compiling.Errors;
using Serilog;

namespace LEDecooker
{
    /// <summary>
    /// Logger for LE Decooker.
    /// </summary>
    public static class DecookerLog
    {
        /// <summary>
        /// Logging prefix for  logs.
        /// </summary>
        private const string InternalLoggingPrefix = @"DECOOKER";

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

        /// <summary>
        /// How many run logs to keep on disk, including the one being written.
        /// </summary>
        private const int RetainedLogCount = 2;

        /// <summary>
        /// Full path of this run's log file, or null if file logging could not be set up.
        /// </summary>
        public static string LogFilePath { get; private set; }

        /// <summary>
        /// Where run logs are written: a <c>logs</c> folder beside the executable.
        /// </summary>
        public static string LogDirectory => Path.Combine(AppContext.BaseDirectory, @"logs");

        public static void CreateLogger()
        {
            // One file per run rather than Serilog's rolling interval. A decook is a discrete
            // operation that can be run several times in an afternoon, so "the last two runs" is the
            // useful unit; a daily roll would merge them into one file and lose the boundary.
            // Serilog's retainedFileCountLimit only prunes files it rolls itself, so with a unique
            // name per run the pruning has to be done here.
            string logFile = null;
            try
            {
                Directory.CreateDirectory(LogDirectory);
                PruneOldLogs();
                logFile = Path.Combine(LogDirectory, $@"LEDecooker-{DateTime.Now:yyyyMMdd-HHmmss}.log");
            }
            catch (Exception e)
            {
                // Never let logging setup stop a decook. The console sink below still works.
                Console.Error.WriteLine($@"Could not prepare the log directory, continuing without a log file: {e.Message}");
            }

            var config = new LoggerConfiguration()
                // Write to the console
                .WriteTo.Console();

            if (logFile != null)
            {
                // shared: true so the file can be read while the run is still going -- a full decook
                // takes long enough that waiting for it to finish to see what happened is no use.
                config = config.WriteTo.File(logFile, shared: true, flushToDiskInterval: TimeSpan.FromSeconds(2));
                LogFilePath = logFile;
            }

#if DEBUG
            // Write to Visual Studio debug console
            config = config.WriteTo.Debug();
#endif

            Log.Logger = config.CreateLogger();

            if (LogFilePath != null)
            {
                Information($@"Logging to {LogFilePath}");
            }
        }

        /// <summary>
        /// Deletes the oldest run logs, leaving room for the one about to be created.
        /// </summary>
        private static void PruneOldLogs()
        {
            // Ordered by name, which sorts chronologically because the stamp is yyyyMMdd-HHmmss.
            // That avoids trusting mtime, which a copy or a restore can rewrite.
            var existing = Directory.GetFiles(LogDirectory, @"LEDecooker-*.log")
                .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
                .ToList();

            for (int i = 0; i <= existing.Count - RetainedLogCount; i++)
            {
                try
                {
                    File.Delete(existing[i]);
                }
                catch (Exception e)
                {
                    // Most likely another decook still has it open. Leaving an extra log is harmless.
                    Console.Error.WriteLine($@"Could not delete old log {existing[i]}: {e.Message}");
                }
            }
        }

        public static void LogUSCErrors(MessageLog log)
        {
            foreach (var msg in log.AllErrors)
            {
                DecookerLog.Error(msg.ToString(), customPrefix: @"UnrealScriptCompiler");
            }
        }
    }
}
