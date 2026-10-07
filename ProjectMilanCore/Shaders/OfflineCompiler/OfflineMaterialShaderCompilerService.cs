using LegendaryExplorerCore.Shaders;
using static LegendaryExplorerCore.Shaders.LE3MaterialShaderCompiler;

namespace ProjectMilanCore.Shaders.OfflineCompiler;

/// <summary>
/// Entry point for compiling one LE3 material with the offline shader compiler. Stops at the activation
/// gate unless <see cref="OfflineShaderCompilerOptions.CompilationEnabled"/> is set. Runs resolution,
/// source capture, translation, planning, one job at a time, then cache assembly. Every outcome keeps
/// what was gathered before it stopped. Produces a detached fragment only: no package is saved and no
/// shader is installed. Safe to share; each request gets its own compiler session.
/// </summary>
public sealed class OfflineMaterialShaderCompilerService
{
    private readonly OfflineShaderCompilerOptions options;
    private readonly IMaterialCompilationResolver resolver;
    private readonly IMaterialShaderCompilerBackend backend;

    public OfflineMaterialShaderCompilerService(OfflineShaderCompilerOptions options,
        IMaterialCompilationResolver? resolver = null, IMaterialShaderCompilerBackend? backend = null)
    {
        this.options = options ?? throw new ArgumentNullException(nameof(options));
        this.resolver = resolver ?? new MaterialCompilationResolver();
        this.backend = backend ?? new LE3MaterialShaderCompilerBackend();
    }

    /// <summary>Check before loading packages or building requests for the compiler.</summary>
    public bool IsCompilationEnabled => options.CompilationEnabled;

    /// <summary>
    /// Runs the request on one background task. Jobs are compiled sequentially; cancellation is checked
    /// between phases and jobs, never inside a native D3DCompile call.
    /// </summary>
    public Task<MaterialShaderCompileOutcome> CompileMaterialAsync(MaterialShaderCompileRequest request,
        IProgress<MaterialShaderCompileProgress>? progress = null, CancellationToken cancellationToken = default)
    {
        if (!options.CompilationEnabled) return Task.FromResult(DisabledOutcome());
        return Task.Run(() => CompileMaterial(request, progress, cancellationToken));
    }

    public MaterialShaderCompileOutcome CompileMaterial(MaterialShaderCompileRequest request,
        IProgress<MaterialShaderCompileProgress>? progress = null, CancellationToken cancellationToken = default)
    {
        // The gate comes before anything that reads the request.
        if (!options.CompilationEnabled) return DisabledOutcome();
        ArgumentNullException.ThrowIfNull(request);

        var state = new RequestState(request);

        state.Phase = MaterialShaderCompilePhase.Resolution;
        if (cancellationToken.IsCancellationRequested) return state.Finish(MaterialShaderCompileStatus.Cancelled);
        MaterialResolutionOutcome resolution;
        try
        {
            resolution = resolver.Resolve(request);
        }
        catch (Exception ex)
        {
            return state.Threw(ex);
        }
        state.Resolution = resolution;
        if (resolution.Status != MaterialResolutionStatus.Resolved || resolution.Compilation == null)
        {
            state.Errors.AddRange(resolution.Reasons);
            return state.Finish(resolution.Status == MaterialResolutionStatus.Unsupported
                ? MaterialShaderCompileStatus.Unsupported : MaterialShaderCompileStatus.Failed);
        }
        state.Compilation = resolution.Compilation;

        state.Phase = MaterialShaderCompilePhase.SourceCapture;
        if (cancellationToken.IsCancellationRequested) return state.Finish(MaterialShaderCompileStatus.Cancelled);
        LE3ShaderSourceSnapshot sources;
        try
        {
            sources = request.Sources.GetSnapshot();
        }
        catch (Exception ex)
        {
            return state.Threw(ex);
        }

        state.Phase = MaterialShaderCompilePhase.BackendCreation;
        try
        {
            state.Session = backend.CreateSession(new MaterialShaderCompileSessionContext(resolution.Compilation, sources,
                request.TextureMetadata.GetMetadata, request.ResourceForcesFloatUsage, request.EnvironmentContext,
                request.MaterialResourceShouldCache));
        }
        catch (Exception ex)
        {
            return state.Threw(ex);
        }
        var session = state.Session;

        state.Phase = MaterialShaderCompilePhase.Translation;
        if (cancellationToken.IsCancellationRequested) return state.Finish(MaterialShaderCompileStatus.Cancelled);
        try
        {
            var translation = session.Translate();
            if (!translation.Success) return state.Reported(translation.Errors, "Translation failed without reporting an error.");
        }
        catch (Exception ex)
        {
            return state.Threw(ex);
        }

        state.Phase = MaterialShaderCompilePhase.Planning;
        if (cancellationToken.IsCancellationRequested) return state.Finish(MaterialShaderCompileStatus.Cancelled);
        try
        {
            var plan = session.Plan();
            state.Decisions = plan.Decisions;
            // An unresolved candidate withholds every job; never recover a partial plan from decisions.
            if (!plan.Success) return state.Reported(plan.Errors, "Planning failed without reporting an error.");
            state.PlannedJobs = plan.Jobs;
        }
        catch (Exception ex)
        {
            return state.Threw(ex);
        }
        if (state.PlannedJobs.Count == 0)
        {
            state.Errors.Add("The plan selected no jobs. This is not a complete, empty shader set.");
            return state.Finish(MaterialShaderCompileStatus.EmptyPlan);
        }

        state.Phase = MaterialShaderCompilePhase.Compilation;
        int total = state.PlannedJobs.Count;
        for (int i = 0; i < total; i++)
        {
            var target = state.PlannedJobs[i];
            if (cancellationToken.IsCancellationRequested)
            {
                state.FailedTarget = target;
                return state.Finish(MaterialShaderCompileStatus.Cancelled);
            }
            progress?.Report(new(MaterialShaderCompilePhase.Compilation, i, total, target));
            ShaderJobOutcome job;
            try
            {
                job = session.Compile(i);
            }
            catch (Exception ex)
            {
                state.FailedTarget = target;
                return state.Threw(ex);
            }
            state.Jobs.Add(job);
            if (!job.Success)
            {
                state.FailedTarget = job.Target;
                return state.Reported([string.IsNullOrWhiteSpace(job.Diagnostics) ? "Shader compile produced no bytecode." : job.Diagnostics],
                    "Shader compile failed.");
            }
        }
        progress?.Report(new(MaterialShaderCompilePhase.Compilation, total, total, null));

        state.Phase = MaterialShaderCompilePhase.Assembly;
        if (cancellationToken.IsCancellationRequested) return state.Finish(MaterialShaderCompileStatus.Cancelled);
        try
        {
            var assembly = session.Assemble();
            if (!assembly.Success || assembly.Cache == null)
                return state.Reported(assembly.Errors, "Cache assembly failed without reporting an error.");
            state.Fragment = assembly.Cache;
            state.UniformExpressionTextures = assembly.UniformExpressionTextures;
            state.IsCompleteShaderSet = assembly.IsCompleteShaderSet;
        }
        catch (Exception ex)
        {
            return state.Threw(ex);
        }

        state.Phase = MaterialShaderCompilePhase.Completed;
        return state.Finish(MaterialShaderCompileStatus.SucceededFragment);
    }

    private static MaterialShaderCompileOutcome DisabledOutcome() => new()
    {
        Status = MaterialShaderCompileStatus.Disabled,
        Phase = MaterialShaderCompilePhase.ActivationGate,
        Errors = ["The offline material shader compiler is disabled."]
    };

    /// <summary>Accumulates what a request has gathered so any exit point can report all of it.</summary>
    private sealed class RequestState(MaterialShaderCompileRequest request)
    {
        public MaterialShaderCompilePhase Phase;
        public MaterialResolutionOutcome? Resolution;
        public ResolvedMaterialShaderCompilation? Compilation;
        public IMaterialShaderCompileSession? Session;
        public IReadOnlyList<ShaderCompileDecision> Decisions = [];
        public IReadOnlyList<ShaderCompileTarget> PlannedJobs = [];
        public readonly List<ShaderJobOutcome> Jobs = [];
        public readonly List<string> Errors = [];
        public ShaderCompileTarget? FailedTarget;
        public LegendaryExplorerCore.Unreal.BinaryConverters.ShaderCache? Fragment;
        public IReadOnlyList<int> UniformExpressionTextures = [];
        public bool IsCompleteShaderSet;
        private Exception? exception;

        public MaterialShaderCompileOutcome Reported(IReadOnlyList<string> errors, string fallback)
        {
            Errors.AddRange(errors.Count > 0 ? errors : [fallback]);
            return Finish(MaterialShaderCompileStatus.Failed);
        }

        public MaterialShaderCompileOutcome Threw(Exception ex)
        {
            exception = ex;
            Errors.Add($"{ex.GetType().Name} during {Phase}: {ex.Message}");
            return Finish(ex is ShaderCompilerBackendUnavailableException
                ? MaterialShaderCompileStatus.BackendUnavailable : MaterialShaderCompileStatus.Failed);
        }

        public MaterialShaderCompileOutcome Finish(MaterialShaderCompileStatus status)
        {
            if (status == MaterialShaderCompileStatus.Cancelled) Errors.Add($"Cancelled before {Phase}.");
            IReadOnlyList<TextureMetadataResolution> metadata;
            try { metadata = request.TextureMetadata.Resolutions.ToArray(); }
            catch (ObjectDisposedException) { metadata = []; }
            return new MaterialShaderCompileOutcome
            {
                Status = status,
                Phase = Phase,
                FailedTarget = FailedTarget,
                Errors = Errors.ToArray(),
                Exception = exception,
                Resolution = Resolution,
                Compilation = Compilation,
                Decisions = Decisions,
                PlannedJobs = PlannedJobs,
                Jobs = Jobs.ToArray(),
                TextureMetadata = metadata,
                Fragment = Fragment,
                UniformExpressionTextures = UniformExpressionTextures,
                IsCompleteShaderSet = IsCompleteShaderSet,
                Artifacts = Session?.Artifacts
            };
        }
    }
}
