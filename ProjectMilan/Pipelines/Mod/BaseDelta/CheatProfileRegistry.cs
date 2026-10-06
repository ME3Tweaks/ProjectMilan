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
    /// Appends Milan's own cheat profiles to the AllProfiles defaults of every cheat manager that defines its
    /// own list. The profile functions themselves are BaseDelta UnrealScript on BioCheatManager
    /// (e.g. AddToClassOrReplace/BioCheatManager.DrawModules.uc); this only registers them so the profile
    /// commands can find them.
    /// </summary>
    /// <remarks>
    /// AllProfiles is not config, and a subclass assigning it in defaultproperties replaces the inherited array
    /// outright. LMP's SFXPlayerControllerMP uses SFXCheatManagerNonNativeMP (ported from ME3), which carries its
    /// own full ME3 list, so it never sees BioCheatManager's entries - the registry has to be applied to both.
    /// </remarks>
    internal static class CheatProfileRegistry
    {
        private const string CheatManagerClass = "BioCheatManager";
        private const string MPCheatManagerClass = "SFXCheatManagerNonNativeMP";
        private const string LogCategory = "Milan-CheatProfiles";

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
            foreach (var profile in AdditionalProfiles)
            {
                ValidateFunction(sfxGame, profile.Function, profile.Keyword);
                if (profile.Utility != null)
                    ValidateFunction(sfxGame, profile.Utility, profile.Keyword);
            }

            AppendTo(sfxGame, CheatManagerClass, required: true);
        }

        /// <summary>
        /// Post-compile hook for the MPCommon package, which holds SFXCheatManagerNonNativeMP (the cheat manager
        /// SFXPlayerControllerMP actually spawns). The profile functions live on BioCheatManager in SFXGame and
        /// were already validated when that was built, so they aren't checked here.
        /// </summary>
        internal static void ApplyToMPCommon(IMEPackage mpCommon) => AppendTo(mpCommon, MPCheatManagerClass, required: false);

        /// <param name="required">
        /// If false, a class that doesn't assign AllProfiles in its own defaults is skipped - it inherits
        /// BioCheatManager's list, which already has the entries.
        /// </param>
        private static void AppendTo(IMEPackage pcc, string className, bool required)
        {
            // Not FindExport: loose-compiled classes nest their defaults under a forced-export package
            // (e.g. SFXGameMPContent.Default__SFXCheatManagerNonNativeMP), so the full path varies.
            var defaultsName = $"Default__{className}";
            var defaults = pcc.Exports.FirstOrDefault(e => e.IsDefaultObject && e.ObjectName.Instanced.CaseInsensitiveEquals(defaultsName));
            if (defaults == null)
            {
                if (required)
                    Fail($"Default__{className} not found in {pcc.FileNameNoExtension}");
                MilanLog.Information($"{className} is not in {pcc.FileNameNoExtension}; no cheat profiles to append", customPrefix: LogCategory);
                return;
            }

            var props = defaults.GetProperties();
            var allProfiles = props.GetProp<ArrayProperty<StructProperty>>("AllProfiles");
            if (allProfiles == null || allProfiles.Count == 0)
            {
                if (required)
                    Fail($"Default__{className} has no AllProfiles to append to");
                MilanLog.Information($"{className} does not override AllProfiles; it inherits the registered profiles", customPrefix: LogCategory);
                return;
            }

            // Clone an existing entry so the new ones keep the native struct's exact property layout.
            var template = allProfiles[0];

            foreach (var profile in AdditionalProfiles)
            {
                // AllProfiles.Find('Keyword', ...) returns the first match, so a duplicate would be unreachable.
                if (allProfiles.Any(p => p.GetProp<NameProperty>("Keyword")?.Value.Instanced.CaseInsensitiveEquals(profile.Keyword) == true))
                    Fail($"Cheat profile keyword '{profile.Keyword}' is already in use in {className}");

                var entry = template.DeepClone();
                entry.GetProp<StrProperty>("Header").Value = profile.Header;
                entry.GetProp<StrProperty>("Description").Value = profile.Description;
                entry.GetProp<DelegateProperty>("Func").Value = new ScriptDelegate(0, profile.Function);
                entry.GetProp<DelegateProperty>("Utility").Value = new ScriptDelegate(0, profile.Utility ?? "None");
                entry.GetProp<NameProperty>("Keyword").Value = profile.Keyword;
                entry.GetProp<BoolProperty>("bNoTarget").Value = profile.NoTarget;
                allProfiles.Add(entry);

                MilanLog.Information($"Registered cheat profile '{profile.Keyword}' -> {profile.Function} in {className} (index {allProfiles.Count - 1})", customPrefix: LogCategory);
            }

            // CurrentProfile is a byte enum holding the AllProfiles index.
            if (allProfiles.Count > 256)
                Fail($"{className}.AllProfiles has {allProfiles.Count} entries; CurrentProfile is a byte and can only index 256");

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
