using LegendaryExplorerCore.Shaders;
using static LegendaryExplorerCore.Shaders.LE3MaterialShaderCompiler;

namespace ProjectMilanCore.Shaders.OfflineCompiler;

/// <summary>
/// The only place that calls <see cref="LE3MaterialShaderCompiler"/>. Uses the resource translation path,
/// the known-subset planner and the snapshot overloads, so translation, every job and cache assembly
/// share one source snapshot. Never saves, installs or merges anything.
/// </summary>
public sealed class LE3MaterialShaderCompilerBackend : IMaterialShaderCompilerBackend
{
    public IMaterialShaderCompileSession CreateSession(MaterialShaderCompileSessionContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        return new Session(context);
    }

    private sealed class Session(MaterialShaderCompileSessionContext context) : IMaterialShaderCompileSession
    {
        // One compiler instance per request; the metadata callback is the only texture source.
        private readonly LE3MaterialShaderCompiler compiler = new(context.Compilation.Input,
            getTextureMetadata: entry => context.TextureMetadata(entry)!);
        private TranslationResult? translation;
        private ShaderCompilePlan? plan;
        private ShaderCompilationResult?[] compiled = [];
        private ShaderCacheFragmentResult? fragment;

        public LE3MaterialShaderCompilerArtifacts? Artifacts => new(translation, plan,
            compiled.Where(c => c != null).Select(c => c!).ToArray(), fragment);

        public TranslationPhaseResult Translate()
        {
            if (translation != null) throw new InvalidOperationException("Translation already ran for this session.");
            translation = Native(() => compiler.TranslateMaterialResourceHlsl(context.Sources, context.ResourceForcesFloatUsage));
            return new(translation.Success, translation.Errors);
        }

        public PlanningPhaseResult Plan()
        {
            if (translation is not { Success: true }) throw new InvalidOperationException("Planning requires a successful translation.");
            if (plan != null) throw new InvalidOperationException("Planning already ran for this session.");
            plan = Native(() => compiler.BuildKnownSubsetCompilePlan(translation, context.Compilation.Resource,
                context.EnvironmentContext, context.MaterialResourceShouldCache));
            compiled = new ShaderCompilationResult?[plan.Jobs.Count];
            return new(plan.Success, plan.Errors, plan.Jobs.Select(j => j.Target).ToArray(), plan.Decisions);
        }

        public ShaderJobOutcome Compile(int jobIndex)
        {
            if (plan is not { Success: true }) throw new InvalidOperationException("Compilation requires a successful plan.");
            if ((uint)jobIndex >= (uint)compiled.Length) throw new ArgumentOutOfRangeException(nameof(jobIndex));
            if (compiled[jobIndex] != null) throw new InvalidOperationException($"Job {jobIndex} was already compiled.");
            var job = plan.Jobs[jobIndex];
            var result = Native(() => compiler.CompileShader(job, context.Sources));
            compiled[jobIndex] = result;
            return new(result.Target, result.Success, result.Diagnostics, result.InstructionCount);
        }

        public AssemblyPhaseResult Assemble()
        {
            if (plan is not { Success: true } || translation == null) throw new InvalidOperationException("Assembly requires a successful plan.");
            if (fragment != null) throw new InvalidOperationException("Assembly already ran for this session.");
            // Every planned job exactly once, in plan order, from this session's translation and snapshot.
            if (compiled.Any(c => c is not { Success: true }))
                throw new InvalidOperationException("Every planned job must compile successfully before assembly.");
            var results = compiled.Select(c => c!).ToArray();
            fragment = Native(() => compiler.BuildShaderCacheFragment(translation, plan, results,
                context.Compilation.MaterialResourceId, context.Compilation.FriendlyName, context.Sources));
            return new(fragment.Success, fragment.Errors, fragment.Cache, fragment.UniformExpressionTextures, fragment.IsCompleteShaderSet);
        }

        private static T Native<T>(Func<T> phase)
        {
            try
            {
                return phase();
            }
            catch (Exception ex) when (IsBackendLoadFailure(ex))
            {
                throw new ShaderCompilerBackendUnavailableException("The D3D shader compiler backend could not be loaded: " + ex.Message, ex);
            }
        }

        private static bool IsBackendLoadFailure(Exception ex) => ex switch
        {
            DllNotFoundException => true,
            BadImageFormatException => true,
            // A missing .usf from the snapshot is also a FileNotFoundException; only assembly loads count here.
            FileNotFoundException f => f.FileName?.StartsWith("SharpDX", StringComparison.OrdinalIgnoreCase) == true,
            FileLoadException f => f.FileName?.StartsWith("SharpDX", StringComparison.OrdinalIgnoreCase) == true,
            TypeInitializationException t => t.InnerException != null && IsBackendLoadFailure(t.InnerException),
            _ => false
        };
    }
}
