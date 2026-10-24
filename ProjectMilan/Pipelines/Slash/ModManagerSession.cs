#nullable disable
using System.ComponentModel;
using System.Diagnostics;
using System.IO.Pipes;
using System.Text.Json;
using System.Text.Json.Nodes;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Misc.ME3Tweaks;
using ProjectMilan.Pipelines.Mod.BaseDelta;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Slash
{
    /// <summary>
    /// What Mod Manager sends us when the unslashed base install is ready. Matches MilanSlashRequest in Mod Manager.
    /// </summary>
    internal class SlashRequest
    {
        public string GameRoot { get; set; }
        public List<string> ModOutputs { get; set; }
        public Dictionary<string, string> FilesLeftInLE3 { get; set; }
        public Dictionary<string, string> VanillaOfPatched { get; set; }
        public List<string> ExcludedFiles { get; set; }
    }

    /// <summary>
    /// Drives Mod Manager (a debug build) over a named pipe: it builds the base install, we generate the slash manifest for
    /// it, it applies that and records the final state. Then it installs the build again the way a user's Mod Manager would,
    /// to catch anything that only works when the slash manifest is being generated. Mod Manager is started at the beginning
    /// of the build so it's up by the time we need it. See MilanBuildSession in Mod Manager for the other end.
    /// </summary>
    [Localizable(false)]
    internal static class ModManagerSession
    {
        private const string LOG_CATEGORY = "MILAN-Slash";
        private const string M3_LOG_CATEGORY = "M3";
        private const int ProtocolVersion = 1;
        private static readonly TimeSpan ConnectTimeout = TimeSpan.FromMinutes(5);
        private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

        private static NamedPipeServerStream pipe;
        private static StreamReader reader;
        private static StreamWriter writer;
        private static Task<JsonNode> hello;
        private static int launchCount;

        /// <summary>
        /// Starts Mod Manager in the background so it has booted by the time the build is done.
        /// </summary>
        public static void StartEarly()
        {
            Launch();
        }

        /// <summary>
        /// Has Mod Manager build the base install and generate the slash manifest into MilanDelta. If it fails, lets the user
        /// fix things (e.g. start a debug Mod Manager) and retry rather than rebuilding everything.
        /// </summary>
        public static void RunSlashStage()
        {
            while (true)
            {
                try
                {
                    Run();
                    return;
                }
                catch (Exception e)
                {
                    MilanLog.Exception(e, "Slash generation failed:", customPrefix: LOG_CATEGORY);
                }
                finally
                {
                    Disconnect();
                }

                Console.WriteLine("-------------------------------");
                Console.WriteLine("Slash generation failed (see above). Fix it (e.g. start a debug build of Mod Manager), then:");
                Console.WriteLine("  R = retry, S = skip (the mod stays built, just without a new slash manifest)");
                while (true)
                {
                    var input = Console.ReadLine()?.Trim();
                    if ("R".CaseInsensitiveEquals(input))
                        break;
                    if ("S".CaseInsensitiveEquals(input) || input == null)
                    {
                        MilanLog.ErrorWithSummary("Slash generation was skipped; MilanDelta has no new slash manifest", customPrefix: LOG_CATEGORY);
                        return;
                    }
                }
            }
        }

        private static void Run()
        {
            var moddesc = Path.GetFullPath(Path.Combine(Program.Settings.OutputModPath, "..", "moddesc.ini"));
            var buildBase = new JsonObject { ["type"] = "buildBase", ["moddescPath"] = moddesc };

            // Mod Manager might have been closed or restarted since we started it (or it was a release build), so if it isn't
            // there any more, start it again. If it's still booting, just wait for it.
            bool sent = hello is { IsCompletedSuccessfully: true } && IsDebug(hello.Result) && TrySend(buildBase);
            if (!sent)
            {
                if (hello == null || hello.IsCompleted)
                {
                    MilanLog.Information("Mod Manager isn't connected, starting it", customPrefix: LOG_CATEGORY);
                    Launch();
                }
                WaitForHello();
                Send(buildBase);
            }

            MilanLog.Information("Mod Manager is building the base install", customPrefix: LOG_CATEGORY);
            RunBuild(generating: true);
            MilanLog.Information("Mod Manager built the base install and recorded the slash manifest's final state", customPrefix: LOG_CATEGORY);

            // Now install it again exactly like a user would, without generating anything, to make sure what we ship actually
            // installs. Mod Manager ends its session after each build, so this is a new connection.
            Launch();
            WaitForHello();
            Send(new JsonObject { ["type"] = "buildBase", ["moddescPath"] = moddesc, ["generateSlash"] = false });
            MilanLog.Information("Mod Manager is installing the build the way a user would, to test it", customPrefix: LOG_CATEGORY);
            RunBuild(generating: false);
            MilanLog.Information("The build installs the way it will for users and matches the recorded final state", customPrefix: LOG_CATEGORY);
        }

        /// <summary>
        /// Handles Mod Manager's messages until it says the build is finished. Throws if it failed, or if it came across any dialog.
        /// </summary>
        private static void RunBuild(bool generating)
        {
            var what = generating ? "build the base install" : "install the build the way a user would";
            while (reader.ReadLine() is { } line)
            {
                var message = JsonNode.Parse(line);
                switch ((string)message?["type"])
                {
                    case "status":
                        ConsoleHelpers.SetConsoleTitle("Project Milan", $"Mod Manager: {(string)message["text"]}");
                        break;
                    case "log":
                        LogFromModManager((string)message["level"], (string)message["message"]);
                        break;
                    case "generateSlash":
                        if (generating)
                            GenerateSlash(message);
                        else
                            Send(new JsonObject { ["type"] = "slashGenerated", ["ok"] = false, ["error"] = "Not generating a slash manifest for this install" });
                        break;
                    case "finished":
                        // A user would've seen these, and whatever got picked for them may not be what they'd pick
                        var dialogs = message["dialogs"]?.AsArray().Select(x => (string)x).ToList() ?? [];
                        foreach (var dialog in dialogs)
                            MilanLog.Error($"Mod Manager showed a dialog: {dialog}", customPrefix: LOG_CATEGORY);
                        if (message["success"]?.GetValue<bool>() != true)
                            throw new Exception($"Mod Manager couldn't {what}: {(string)message["error"]}");
                        if (dialogs.Count > 0)
                            throw new Exception($"Mod Manager showed {dialogs.Count} dialog(s) while it tried to {what}. First: {dialogs[0]}");
                        return;
                }
            }
            throw new Exception($"Mod Manager disconnected before it finished trying to {what} (was it closed?)");
        }

        private static void GenerateSlash(JsonNode message)
        {
            try
            {
                var request = message.Deserialize<SlashRequest>(JsonOptions);
                MilanLog.Information($"Generating the slash manifest for {request.GameRoot}", customPrefix: LOG_CATEGORY);
                SlashGenerator.Generate(request, BaseDeltaHandler.MilanDeltaFolder, s => ConsoleHelpers.SetConsoleTitle("Project Milan", s));
                GC.Collect(); // Generation can hold several GB
                Send(new JsonObject { ["type"] = "slashGenerated", ["ok"] = true });
            }
            catch (Exception e)
            {
                // Mod Manager will clean up and tell us it failed
                MilanLog.Exception(e, "Couldn't generate the slash manifest:", customPrefix: LOG_CATEGORY);
                Send(new JsonObject { ["type"] = "slashGenerated", ["ok"] = false, ["error"] = e.Message });
            }
        }

        private static void LogFromModManager(string level, string text)
        {
            // M3Log already prefixes its lines with [M3]
            if (text != null && text.StartsWith("[M3] ", StringComparison.Ordinal))
                text = text[5..];
            switch (level)
            {
                case "Warning":
                    MilanLog.Warning(text, customPrefix: M3_LOG_CATEGORY);
                    break;
                case "Error":
                case "Fatal":
                    MilanLog.Error(text, customPrefix: M3_LOG_CATEGORY);
                    break;
                default:
                    MilanLog.Information(text, customPrefix: M3_LOG_CATEGORY);
                    break;
            }
        }

        /// <summary>
        /// Opens a new pipe and starts Mod Manager pointed at it. If Mod Manager is already open, it gets the argument passed
        /// on to it and connects from there.
        /// </summary>
        private static void Launch()
        {
            Disconnect();
            var pipeName = $"ProjectMilan.M3.{Environment.ProcessId}.{++launchCount}";
            pipe = new NamedPipeServerStream(pipeName, PipeDirection.InOut, 1, PipeTransmissionMode.Byte, PipeOptions.Asynchronous);
            var thisPipe = pipe;
            hello = Task.Run(async () =>
            {
                await thisPipe.WaitForConnectionAsync();
                reader = new StreamReader(thisPipe);
                writer = new StreamWriter(thisPipe) { AutoFlush = true };
                var line = await reader.ReadLineAsync() ?? throw new Exception("Mod Manager disconnected without saying hello");
                var message = JsonNode.Parse(line);
                MilanLog.Information($"Mod Manager {(string)message["version"]} connected ({(message["debug"]?.GetValue<bool>() == true ? "debug" : "release")} build)", customPrefix: LOG_CATEGORY);
                if (!IsDebug(message))
                {
                    // Log at the handshake, before publishing readiness, so startup and slash-only runs both warn immediately.
                    MilanLog.Warning(NonDebugInstructions(message), customPrefix: LOG_CATEGORY);
                }
                return message;
            });

            var exe = ModManagerIntegration.GetModManagerExecutableLocation();
            if (exe == null)
            {
                MilanLog.Warning("Couldn't find Mod Manager in the registry; start it once so it records where it is", customPrefix: LOG_CATEGORY);
                return;
            }

            MilanLog.Information($"Starting Mod Manager ({exe})", customPrefix: LOG_CATEGORY);
            var psi = new ProcessStartInfo(exe) { WorkingDirectory = Path.GetDirectoryName(exe), UseShellExecute = false };
            psi.ArgumentList.Add("--milanbuild");
            psi.ArgumentList.Add(pipeName);
            Process.Start(psi);
        }

        private static void WaitForHello()
        {
            if (!hello.Wait(ConnectTimeout))
                throw new Exception($"Mod Manager didn't connect within {ConnectTimeout.TotalMinutes} minutes");
            var message = hello.Result;
            if (!IsDebug(message))
                throw new Exception(NonDebugInstructions(message));
        }

        private static bool IsDebug(JsonNode helloMessage) => helloMessage["debug"]?.GetValue<bool>() == true;

        private static string NonDebugInstructions(JsonNode message) =>
            $"ACTION REQUIRED: detected non-Debug Mod Manager running ({(string)message["version"]}). " +
            "Slash WILL FAIL with this instance. Rebuild Mod Manager in Debug and restart it in Debug before the Slash stage. " +
            "If this run is being monitored, do this now while the remaining build stages continue. " +
            "If the build has already exited, run ProjectMilan --config <configuration> --slash-only after restarting Mod Manager in Debug; " +
            "the completed mod output can be reused.";

        private static void Send(JsonObject message)
        {
            message["v"] = ProtocolVersion;
            writer.WriteLine(message.ToJsonString());
        }

        private static bool TrySend(JsonObject message)
        {
            try
            {
                Send(message);
                return true;
            }
            catch (IOException)
            {
                return false;
            }
        }

        private static void Disconnect()
        {
            try
            {
                pipe?.Dispose();
            }
            catch
            {
                // Already gone
            }
            pipe = null;
            reader = null;
            writer = null;
            hello = null;
        }
    }
}
