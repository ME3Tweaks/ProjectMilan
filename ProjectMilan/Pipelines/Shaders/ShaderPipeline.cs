using LegendaryExplorerCore.GameFilesystem;
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
            using var context = new OfflineShaderInstallContext(Program.Settings.OutputModPath, gameRoot,
                Program.Settings.DecookedLE3Path, MilanShared.LE3ObjectDB);

            MilanLog.Information($"Planning the shader install over {context.OutputPackages.Count} packages", customPrefix: LOG_CATEGORY);
            var plan = context.Plan();
            string planPath = Path.Combine(Path.GetTempPath(), "MilanShaderInstallPlan.txt");
            File.WriteAllText(planPath, plan.Describe());
            MilanLog.Information($"Shader install plan: {plan.Materials.Count} materials ({plan.Materials.Count(m => m.FlagsToSet.Count > 0)} get usage flags), " +
                $"{plan.Instances.Count} instances ({plan.Instances.Count(i => i.StaticNormalFixes.Count > 0)} normal fixes, " +
                $"{plan.Instances.Count(i => i.RetargetParentTo != null)} retargeted), {plan.Variants.Count} variants, {plan.ChainClones.Count} chain clones, " +
                $"{plan.Errors.Count} errors, {plan.Reports.Count} notes. Full plan: {planPath}", customPrefix: LOG_CATEGORY);
            foreach (var report in plan.Reports.Take(50)) MilanLog.Warning(report, customPrefix: LOG_CATEGORY);

            new OfflineShaderInstaller(context, s => MilanLog.Information(s, customPrefix: LOG_CATEGORY))
                .Install(plan, Math.Max(1, Environment.ProcessorCount / 2));
        }
    }
}
