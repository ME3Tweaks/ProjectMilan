using System;
using System.Diagnostics.CodeAnalysis;
using System.Linq;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Mod.BaseDelta
{
    /// <summary>
    /// An extra entry for BioCheatManager.AllProfiles, which drives the 'profiles' and
    /// 'profile &lt;keyword&gt; &lt;self/target/camera&gt;' console commands.
    /// </summary>
    /// <param name="Keyword">The keyword typed after 'profile'. Must not collide with an existing profile.</param>
    /// <param name="Function">BioCheatManager function invoked every frame while the profile is active (delegate ProfileHandler).</param>
    /// <param name="Header">Title drawn above the profile, followed by the target when one is required.</param>
    /// <param name="Description">Shown in the 'profiles' list and under the title.</param>
    /// <param name="NoTarget">True if the profile works without a target actor.</param>
    /// <param name="Utility">Optional BioCheatManager function run after <paramref name="Function"/> (delegate ProfileUtility), e.g. DrawTargetLineUtility.</param>
    internal sealed record CheatProfile(string Keyword, string Function, string Header, string Description, bool NoTarget = false, string? Utility = null);

    /// <summary>
    /// Appends Milan's own cheat profiles to Default__BioCheatManager.AllProfiles in SFXGame. The profile
    /// functions themselves are BaseDelta UnrealScript (e.g. AddToClassOrReplace/BioCheatManager.DrawModules.uc);
    /// this only registers them so the profile commands can find them.
    /// </summary>
    internal static class CheatProfileRegistry
    {
        private const string CheatManagerClass = "BioCheatManager";
        private const string LogCategory = "Milan-SFXGame";

        /// <summary>
        /// Profiles to append, in order, after the vanilla ones.
        /// </summary>
        private static readonly CheatProfile[] AdditionalProfiles =
        [
            new("Modules", "DrawModules", "Module Profile of", "Displays the target pawn's live module list", Utility: "DrawTargetLineUtility"),
        ];

        /// <summary>
        /// Post-compile hook for the SFXGame BaseDelta target. Must run after all script compilation so
        /// the referenced functions exist and no later class recompile can drop the appended entries.
        /// </summary>
        internal static void Apply(IMEPackage sfxGame)
        {
            var defaults = sfxGame.FindExport($"Default__{CheatManagerClass}");
            if (defaults == null)
                Fail($"Default__{CheatManagerClass} not found");

            var props = defaults.GetProperties();
            var allProfiles = props.GetProp<ArrayProperty<StructProperty>>("AllProfiles");
            if (allProfiles == null || allProfiles.Count == 0)
                Fail($"Default__{CheatManagerClass} has no AllProfiles to append to");

            // Clone a vanilla entry so the new ones keep the native struct's exact property layout.
            var template = allProfiles[0];

            foreach (var profile in AdditionalProfiles)
            {
                ValidateFunction(sfxGame, profile.Function, profile.Keyword);
                if (profile.Utility != null)
                    ValidateFunction(sfxGame, profile.Utility, profile.Keyword);

                // AllProfiles.Find('Keyword', ...) returns the first match, so a duplicate would be unreachable.
                if (allProfiles.Any(p => p.GetProp<NameProperty>("Keyword")?.Value.Instanced.CaseInsensitiveEquals(profile.Keyword) == true))
                    Fail($"Cheat profile keyword '{profile.Keyword}' is already in use");

                var entry = template.DeepClone();
                entry.GetProp<StrProperty>("Header").Value = profile.Header;
                entry.GetProp<StrProperty>("Description").Value = profile.Description;
                entry.GetProp<DelegateProperty>("Func").Value = new ScriptDelegate(0, profile.Function);
                entry.GetProp<DelegateProperty>("Utility").Value = new ScriptDelegate(0, profile.Utility ?? "None");
                entry.GetProp<NameProperty>("Keyword").Value = profile.Keyword;
                entry.GetProp<BoolProperty>("bNoTarget").Value = profile.NoTarget;
                allProfiles.Add(entry);

                MilanLog.Information($"Registered cheat profile '{profile.Keyword}' -> {CheatManagerClass}.{profile.Function} (index {allProfiles.Count - 1})", customPrefix: LogCategory);
            }

            // CurrentProfile is a byte enum holding the AllProfiles index.
            if (allProfiles.Count > 256)
                Fail($"AllProfiles has {allProfiles.Count} entries; CurrentProfile is a byte and can only index 256");

            defaults.WriteProperties(props);
        }

        private static void ValidateFunction(IMEPackage sfxGame, string functionName, string keyword)
        {
            var function = sfxGame.FindExport($"{CheatManagerClass}.{functionName}");
            if (function == null || function.ClassName != "Function")
                Fail($"Cheat profile '{keyword}' references {CheatManagerClass}.{functionName}, which is not a compiled function. Add it via BaseDelta (AddToClassOrReplace/{CheatManagerClass}.{functionName}.uc).");
        }

        [DoesNotReturn]
        private static void Fail(string message)
        {
            MilanLog.Fatal($"{message} - this is a fatal error.", customPrefix: LogCategory);
            Environment.Exit(1);
        }
    }
}
