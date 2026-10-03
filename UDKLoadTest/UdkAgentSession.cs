using System.ComponentModel;
using System.Diagnostics;
using System.Text.RegularExpressions;
using ProjectMilan.Pipelines.StaticLighting;
using Serilog;
using UDKInj;

namespace UDKLoadTest;

/// <summary>
/// One UDK editor process with UDKAgent injected, driven through the agent's action mailbox.
/// A trimmed copy of the dispatch plumbing in ProjectMilan's StaticLightingCompute - only what a
/// map load needs. Disposing kills UDK.
/// </summary>
internal sealed class UdkAgentSession : IDisposable
{
    private static readonly TimeSpan PollInterval = TimeSpan.FromMilliseconds(500);

    /// <summary>
    /// Title of each Win32 dialog (class #32770) in a UDKWindowProbe description. UDK's own
    /// "Please Wait..." slow-task progress dialog is one too, and is up for the whole load.
    /// </summary>
    private static readonly Regex MessageBoxTitleRegex = new(@"'([^']*)' \(#32770\)", RegexOptions.Compiled);
    private const string ProgressDialogTitle = "Please Wait...";

    /// <summary>How long a message box may stay up during an action before the action is failed.</summary>
    private static readonly TimeSpan BlockingDialogTimeout = TimeSpan.FromSeconds(30);

    /// <summary>Mirror of AgentDispatchStatus in UDKAgent/CommonHooks.hpp. Keep the two in sync.</summary>
    public readonly struct AgentStatus
    {
        public const int SizeBytes = 32;

        public bool IsIdle { get; init; }
        public int PendingActions { get; init; }
        public int CompletedActions { get; init; }
        public int SlowTaskDepth { get; init; }
        public bool IsDispatching { get; init; }
        public int TicksRemaining { get; init; }
        public int EngineTickCount { get; init; }
        public int LoadErrorEvents { get; init; }

        public override string ToString() =>
            $"idle={IsIdle} pending={PendingActions} completed={CompletedActions} " +
            $"slowTask={SlowTaskDepth} dispatching={IsDispatching} ticks={TicksRemaining} " +
            $"engineTicks={EngineTickCount}";
    }

    /// <summary>Mirrors MailboxActionType in UDKAgent/CommonHooks.hpp. Keep the two in sync.</summary>
    private enum MailboxActionType
    {
        LoadMap = 1,
    }

    private readonly FileInfo _agentModule;
    private readonly Process _udkProcess;
    private readonly int _udkPid;
    private Injector _injector;
    private ProcessHandle _processHandle;

    // Resolved once after injection and then read/written with plain Read/WriteProcessMemory - see
    // StaticLightingCompute for why the agent moved off per-call remote threads.
    private Allocation _agentStatusView;
    private Allocation _actionMailboxHeaderView; // ActionMailbox.State/ActionType
    private Allocation _actionMailboxPayloadView; // ActionMailbox.Payload, zero-based

    public int ProcessId => _udkPid;

    private UdkAgentSession(Process udkProcess, FileInfo agentModule)
    {
        _udkProcess = udkProcess;
        _udkPid = udkProcess.Id;
        _agentModule = agentModule;
    }

    /// <summary>Starts UDK, injects the agent and waits for the editor to come up.</summary>
    public static UdkAgentSession Start(string udkExePath, string arguments, FileInfo agentModule)
    {
        var udkProcess = Process.Start(new ProcessStartInfo
        {
            FileName = udkExePath,
            Arguments = arguments,
            WorkingDirectory = Path.GetDirectoryName(udkExePath),
        }) ?? throw new InvalidOperationException($"Could not start {udkExePath}");

        var session = new UdkAgentSession(udkProcess, agentModule);
        try
        {
            session.AttachWithRetry(TimeSpan.FromMinutes(3));
            session.ResolveRemoteViews();
            session.WaitForReady(TimeSpan.FromMinutes(10));
            return session;
        }
        catch
        {
            session.Dispose();
            throw;
        }
    }

    public void LoadMap(string persistentPackagePath, TimeSpan timeout) =>
        RunAction(MailboxActionType.LoadMap,
            input => input.WriteStringUTF16(0, persistentPackagePath),
            timeout,
            label: $"LoadMap({Path.GetFileName(persistentPackagePath)})");

    /// <summary>Reads g_AgentStatus, reporting a UDK that has exited as such rather than as the raw
    /// ERROR_PARTIAL_COPY a read of its unmapped memory fails with.</summary>
    public AgentStatus ReadStatus(string operation)
    {
        try
        {
            return GetStatus();
        }
        catch (Win32Exception ex) when (!IsUDKRunning())
        {
            throw new InvalidOperationException($"UDK (PID {_udkPid}) exited while {operation}. " +
                @"See UDKGame\Logs\Launch.log for how far it got.", ex);
        }
    }

    public bool IsUDKRunning()
    {
        try
        {
            using var udk = Process.GetProcessById(_udkPid);
            return !udk.HasExited;
        }
        catch (ArgumentException)
        {
            return false;
        }
    }

    /// <summary>
    /// Queues an action and blocks until it has completed: CompletedActions has advanced past its
    /// value at queue time and the agent is idle again (see StaticLightingCompute.RunAction).
    /// </summary>
    private void RunAction(MailboxActionType actionType, Action<Allocation> writeInput, TimeSpan timeout, string label)
    {
        if (!ReadStatus(label).IsIdle)
            WaitUntil(s => s.IsIdle, TimeSpan.FromMinutes(5), $"agent idle before {label}");

        var completedBefore = ReadStatus(label).CompletedActions;

        Log.Information("-> {Label}", label);
        var sw = Stopwatch.StartNew();

        // State flips last: the agent only reads ActionType/Payload once it observes State=1.
        writeInput?.Invoke(_actionMailboxPayloadView);
        _actionMailboxHeaderView.WriteInt32(4, (int)actionType);
        _actionMailboxHeaderView.WriteInt32(0, 1);

        WaitUntil(s => s.CompletedActions > completedBefore && s.IsIdle, timeout, label);

        Log.Information("<- {Label} ({Elapsed:hh\\:mm\\:ss})", label, sw.Elapsed);
    }

    /// <summary>
    /// Injects the agent, retrying until it takes - how long UDK needs before it accepts a remote
    /// thread depends on how much it loads at startup, so a fixed delay is a race.
    /// </summary>
    private void AttachWithRetry(TimeSpan timeout)
    {
        // Late enough for UDK to accept a remote thread, early enough for the agent's UIInit hook.
        Thread.Sleep(TimeSpan.FromSeconds(3));

        var deadline = DateTime.UtcNow + timeout;
        Win32Exception lastError = null;

        for (int attempt = 1; DateTime.UtcNow < deadline; attempt++)
        {
            _udkProcess.Refresh();
            if (_udkProcess.HasExited)
                throw new InvalidOperationException($"UDK exited during startup (code {_udkProcess.ExitCode})");

            // Its own Process object: disposing a ProcessHandle disposes the Process it wraps. Not
            // handed to the Injector to dispose - Injector.Dispose closes the handle before freeing its
            // own allocations through it.
            var handle = new ProcessHandle(Process.GetProcessById(_udkPid));
            Injector probe = null;
            try
            {
                probe = new Injector(handle, bDisposeProcess: false);
                probe.Inject(_agentModule);

                _injector = probe;
                _processHandle = handle;
                Log.Information("Injected agent (attempt {Attempt})", attempt);
                return;
            }
            catch (Win32Exception ex)
            {
                try { probe?.Dispose(); } catch (Win32Exception) { /* retrying anyway */ }
                handle.Dispose();
                lastError = ex;
                Log.Information("  attach attempt {Attempt} failed (win32 {Code}: {Message}); retrying", attempt, ex.NativeErrorCode, ex.Message);
                Thread.Sleep(TimeSpan.FromSeconds(2));
            }
        }

        throw new TimeoutException($"could not inject within {timeout} " +
            $"(last win32 {lastError?.NativeErrorCode}: {lastError?.Message})");
    }

    private void ResolveRemoteViews()
    {
        _agentStatusView = _injector.WrapRemoteExport(_agentModule, "g_AgentStatus", AgentStatus.SizeBytes);
        _actionMailboxHeaderView = _injector.WrapRemoteExport(_agentModule, "g_ActionMailbox", fieldOffset: 0, size: 8);
        _actionMailboxPayloadView = _injector.WrapRemoteExport(_agentModule, "g_ActionMailbox", fieldOffset: 8, size: 1024);
    }

    private void WaitForReady(TimeSpan timeout)
    {
        var deadline = DateTime.UtcNow + timeout;
        var lastReport = DateTime.UtcNow;

        while (DateTime.UtcNow < deadline)
        {
            var status = ReadStatus("waiting for UDK to become ready");
            if (status.EngineTickCount >= 5 && status.SlowTaskDepth == 0)
            {
                Log.Information("UDK is ready");
                return;
            }

            if (DateTime.UtcNow - lastReport > TimeSpan.FromSeconds(15))
            {
                lastReport = DateTime.UtcNow;
                Log.Information("  waiting for UDK... {Status}", status);
            }

            Thread.Sleep(TimeSpan.FromSeconds(1));
        }

        throw new TimeoutException($"UDK was not ready within {timeout} (last status: {ReadStatus("checking readiness")}; " +
            $"UDK windows: {UDKWindowProbe.Describe(_udkPid)})");
    }

    private void WaitUntil(Func<AgentStatus, bool> predicate, TimeSpan timeout, string label)
    {
        var deadline = DateTime.UtcNow + timeout;
        AgentStatus last = default;
        var nextDialogCheck = DateTime.UtcNow;
        DateTime? dialogSince = null;

        while (DateTime.UtcNow < deadline)
        {
            last = ReadStatus(label);
            if (predicate(last)) return;

            // A Win32 message box (appMsgf, e.g. a shader compile prompt) blocks the engine tick the
            // action runs on, so nothing will complete until someone clicks it. Fail the action
            // instead of waiting out the full timeout.
            if (DateTime.UtcNow >= nextDialogCheck)
            {
                nextDialogCheck = DateTime.UtcNow + TimeSpan.FromSeconds(5);
                var windows = UDKWindowProbe.Describe(_udkPid);
                var blocking = MessageBoxTitleRegex.Matches(windows)
                    .Any(m => !m.Groups[1].Value.Equals(ProgressDialogTitle, StringComparison.OrdinalIgnoreCase));
                if (!blocking)
                    dialogSince = null;
                else if ((dialogSince ??= DateTime.UtcNow) + BlockingDialogTimeout <= DateTime.UtcNow)
                    throw new TimeoutException($"{label} is blocked by a UDK message box: {windows}");
            }

            Thread.Sleep(PollInterval);
        }

        // The status only refreshes on an engine tick, so a UDK stuck in a modal dialog looks the
        // same as one still working. Name its windows so the cause is in the report.
        throw new TimeoutException($"{label} did not complete within {timeout} (last status: {last}; " +
            $"UDK windows: {UDKWindowProbe.Describe(_udkPid)})");
    }

    /// <summary>Reads g_AgentStatus directly - refreshed every engine tick, no remote call.</summary>
    private AgentStatus GetStatus() => new()
    {
        IsIdle = _agentStatusView.ReadInt32(0) != 0,
        PendingActions = _agentStatusView.ReadInt32(4),
        CompletedActions = _agentStatusView.ReadInt32(8),
        SlowTaskDepth = _agentStatusView.ReadInt32(12),
        IsDispatching = _agentStatusView.ReadInt32(16) != 0,
        TicksRemaining = _agentStatusView.ReadInt32(20),
        EngineTickCount = _agentStatusView.ReadInt32(24),
        LoadErrorEvents = _agentStatusView.ReadInt32(28),
    };

    public void Dispose()
    {
        // Free the injector's remote allocations while UDK is still alive to free them from; if UDK
        // already died, Windows reclaimed them anyway.
        try
        {
            _injector?.Dispose();
        }
        catch (Exception ex) when (ex is Win32Exception or InvalidOperationException)
        {
            Log.Warning("Could not clean up injector (UDK likely already exited): {Message}", ex.Message);
        }
        _injector = null;
        _processHandle?.Dispose();
        _processHandle = null;

        // Nothing is saved, so UDK is killed rather than closed - which also keeps it from rewriting
        // its ini files on exit before EditorConfigOverride restores them.
        try
        {
            using var live = Process.GetProcessById(_udkPid);
            if (!live.HasExited)
            {
                live.Kill();
                live.WaitForExit(15_000);
            }
        }
        catch (ArgumentException) { /* already gone */ }
        catch (InvalidOperationException) { /* already gone */ }
        catch (Exception ex)
        {
            Log.Warning("Could not stop UDK (PID {Pid}): {Message}", _udkPid, ex.Message);
        }

        _udkProcess.Dispose();
    }
}
