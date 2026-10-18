using LegendaryExplorerCore.GameFilesystem;
using System.Diagnostics;
using System.Text.Json;
using ProjectMilanCore;
using ProjectMilanCore.Shaders.OfflineCompiler;

namespace ProjectMilan.Pipelines.Shaders
{
    /// <summary>
    /// Compiles and installs the mod's shaders with the offline compiler, after the texture pipeline. Plans over
    /// every output package first (usage flags, static normal fixes, parent variants), then compiles each unique
    /// shader map once and applies the plan to every package. Any failure throws and stops the build.
    /// </summary>
    public static class ShaderPipeline
    {
        private const string LOG_CATEGORY = @"MILAN-Shaders";

        public static void RunPipeline()
        {
            string gameRoot = LE3Directory.DefaultGamePath;
            MilanLog.Information("Preparing shader context: indexing output exports, texture donors and shader sources", customPrefix: LOG_CATEGORY);
            var preparation = Stopwatch.StartNew();
            using var context = new OfflineShaderInstallContext(Program.Settings.OutputModPath, gameRoot,
                Program.Settings.DecookedLE3Path, MilanShared.LE3ObjectDB);
            MilanLog.Information($"Shader context ready in {preparation.Elapsed.TotalSeconds:F2}s; using the existing in-memory LE3 object database", customPrefix: LOG_CATEGORY);

            MilanLog.Information($"Planning the shader install over {context.OutputPackages.Count} packages", customPrefix: LOG_CATEGORY);
            int packagesStarted = 0;
            var plan = context.Plan(file =>
            {
                int index = Interlocked.Increment(ref packagesStarted);
                MilanLog.Information($"Planning package {index}/{context.OutputPackages.Count}: {Path.GetFileName(file)}", customPrefix: LOG_CATEGORY);
            }, diagnostics: message => MilanLog.Information(message, customPrefix: LOG_CATEGORY));
            string planPath = Path.Combine(Path.GetTempPath(), "MilanShaderInstallPlan.txt");
            File.WriteAllText(planPath, plan.Describe());
            MilanLog.Information($"Shader install plan: {plan.Materials.Count} materials ({plan.Materials.Count(m => m.FlagsToSet.Count > 0)} get usage flags), " +
                $"{plan.Instances.Count} instances ({plan.Instances.Count(i => i.StaticNormalFixes.Count > 0)} normal fixes, " +
                $"{plan.Instances.Count(i => i.RetargetParentTo != null)} retargeted), {plan.Variants.Count} variants, {plan.ChainClones.Count} chain clones, " +
                $"{plan.SlotRetargets.Count} lightmapped mesh slots moved off materials the game has too, " +
                $"{plan.Errors.Count} errors, {plan.Reports.Count} notes. Full plan: {planPath}", customPrefix: LOG_CATEGORY);
            foreach (var report in plan.Reports.Take(50)) MilanLog.Warning(report, customPrefix: LOG_CATEGORY);

            new OfflineShaderInstaller(context, s => MilanLog.Information(s, customPrefix: LOG_CATEGORY))
                .Install(plan, Math.Max(1, Environment.ProcessorCount / 2));

            // Keep clone provenance in the output so Shaders checkpoints can resume at PostShaders.
            var clones = plan.ChainClones.SelectMany(c => c.Packages.Select(p => new MaterialCloneBinding(
                c.SourceIdentity, c.Identity, Path.GetRelativePath(Program.Settings.OutputModPath, context.OutputPath(p))))).ToList();
            File.WriteAllText(Path.Combine(Program.Settings.OutputModPath, PostShaderPipeline.CloneManifestName), JsonSerializer.Serialize(clones));
        }
    }
}
