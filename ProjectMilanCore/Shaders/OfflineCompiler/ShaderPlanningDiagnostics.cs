using System.Diagnostics;

namespace ProjectMilanCore.Shaders.OfflineCompiler;

/// <summary>Optional timing/counter logging for the sequential, read-only planner. Timings may be nested.</summary>
public sealed class ShaderPlanningDiagnostics(Action<string> log)
{
    private sealed class Metric
    {
        public long Calls, Ticks, MaxTicks;
        public string? Slowest;
    }

    private readonly Dictionary<string, Metric> packageMetrics = new(StringComparer.Ordinal);
    private readonly Dictionary<string, Metric> totalMetrics = new(StringComparer.Ordinal);
    private readonly Dictionary<string, HashSet<string>> packageDistinct = new(StringComparer.Ordinal);
    private readonly Dictionary<string, HashSet<string>> totalDistinct = new(StringComparer.Ordinal);
    private readonly long started = Stopwatch.GetTimestamp();
    private long packageStarted, lastProgress;
    private string package = "initialization", phase = "opening package";

    public void BeginPackage(string file)
    {
        package = Path.GetFileName(file);
        phase = "opening package";
        packageMetrics.Clear();
        packageDistinct.Clear();
        packageStarted = lastProgress = Stopwatch.GetTimestamp();
    }

    public void CompletePackage() => log($"Planning package finished: {package}, {Seconds(Stopwatch.GetTimestamp() - packageStarted):F2}s; " +
        $"nested timings/counters: {Describe(packageMetrics)}");

    public void CompletePlan() => log($"Planning diagnostics total: {Seconds(Stopwatch.GetTimestamp() - started):F2}s; " +
        $"nested timings/counters: {Describe(totalMetrics)}");

    public IDisposable Phase(string name)
    {
        string previous = phase;
        phase = name;
        log($"Planning phase started: {package} / {name}");
        return new Measurement(this, name, null, () => phase = previous);
    }

    public IDisposable Measure(string name, string? detail = null) => new Measurement(this, name, detail, null);

    public void Count(string name)
    {
        Add(packageMetrics, name, 0, null);
        Add(totalMetrics, name, 0, null);
    }

    public void CountDistinct(string name, string value)
    {
        if (Remember(packageDistinct, name, value)) Add(packageMetrics, name, 0, null);
        if (Remember(totalDistinct, name, value)) Add(totalMetrics, name, 0, null);
    }

    private static bool Remember(Dictionary<string, HashSet<string>> sets, string name, string value)
    {
        if (!sets.TryGetValue(name, out var set)) sets[name] = set = new(StringComparer.OrdinalIgnoreCase);
        return set.Add(value);
    }

    private void Finished(string name, string? detail, long ticks)
    {
        Add(packageMetrics, name, ticks, detail);
        Add(totalMetrics, name, ticks, detail);
        if (detail != null && Seconds(ticks) >= 2)
            log($"Planning slow operation: {package} / {name}, {Seconds(ticks):F2}s: {detail}");
        long now = Stopwatch.GetTimestamp();
        if (Seconds(now - lastProgress) < 10) return;
        lastProgress = now;
        log($"Planning progress: {package} / {phase}, {Seconds(now - packageStarted):F1}s elapsed; " +
            $"last operation: {name} {detail}; nested timings/counters: {Describe(packageMetrics)}");
    }

    private static void Add(Dictionary<string, Metric> metrics, string name, long ticks, string? detail)
    {
        if (!metrics.TryGetValue(name, out var metric)) metrics[name] = metric = new();
        metric.Calls++;
        metric.Ticks += ticks;
        if (ticks > metric.MaxTicks) (metric.MaxTicks, metric.Slowest) = (ticks, detail);
    }

    private static double Seconds(long ticks) => (double)ticks / Stopwatch.Frequency;

    private static string Describe(Dictionary<string, Metric> metrics) => string.Join("; ", metrics.OrderByDescending(m => m.Value.Ticks)
        .ThenBy(m => m.Key, StringComparer.Ordinal).Select(m => m.Value.Ticks == 0
            ? $"{m.Key}={m.Value.Calls}"
            : $"{m.Key}={Seconds(m.Value.Ticks):F2}s/{m.Value.Calls} calls (max {Seconds(m.Value.MaxTicks):F2}s" +
              (m.Value.Slowest == null ? ")" : $": {m.Value.Slowest})")));

    private sealed class Measurement(ShaderPlanningDiagnostics owner, string name, string? detail, Action? completed) : IDisposable
    {
        private readonly long started = Stopwatch.GetTimestamp();
        private bool disposed;

        public void Dispose()
        {
            if (disposed) return;
            disposed = true;
            owner.Finished(name, detail, Stopwatch.GetTimestamp() - started);
            completed?.Invoke();
        }
    }
}
