using ProjectMilanCore;

namespace ProjectMilan.Pipelines.StaticLighting
{
    /// <summary>
    /// Where baked lighting is kept: StaticLighting\Levels\&lt;UE3|UE4&gt;\&lt;BioP&gt;\*.udk, one folder per Lightmass, so a build
    /// can import either without baking again (--lightmass picks which, --cached-lighting skips the bake).
    /// The folder is the Lightmass the build asked for; a level that build solves with the other one
    /// (<see cref="UE4LightmassSettings.UseUE3"/>, or UE4 missing on this machine) is still stored there.
    /// </summary>
    internal static class StaticLightingCache
    {
        private const string LOG_CATEGORY = "MILAN-StaticLightingCache";

        public static string Root => Path.Combine(MilanShared.PipelineRoot, "StaticLighting", "Levels");

        /// <summary>The folder holding a level's maps baked with <paramref name="lightmass"/> (default: this build's).</summary>
        public static string GetLevelFolder(string bioP, LightmassSolver? lightmass = null) =>
            Path.Combine(Root, (lightmass ?? Program.Lightmass).ToString(), bioP);

        /// <summary>A baked map of a level (the BioP itself or one of its sublevels) from this build's Lightmass.</summary>
        public static string GetMapPath(string bioP, string mapName) => Path.Combine(GetLevelFolder(bioP), $"{mapName}.udk");

        public static bool HasLevel(string bioP, LightmassSolver? lightmass = null) =>
            File.Exists(Path.Combine(GetLevelFolder(bioP, lightmass), $"{bioP}.udk"));

        /// <summary>
        /// Moves bakes from the old layout (StaticLighting\Levels\&lt;BioP&gt;) into the UE4 folder, which is what
        /// every bake was when the UE3 one was added.
        /// </summary>
        public static void MigrateLegacyLayout()
        {
            if (!Directory.Exists(Root))
                return;

            foreach (var legacy in Directory.GetDirectories(Root))
            {
                var name = Path.GetFileName(legacy);
                if (Enum.TryParse<LightmassSolver>(name, ignoreCase: true, out _) || !File.Exists(Path.Combine(legacy, $"{name}.udk")))
                    continue;

                var destination = GetLevelFolder(name, LightmassSolver.UE4);
                if (Directory.Exists(destination))
                {
                    MilanLog.Warning($"Not moving {legacy} into the UE4 bakes: {destination} already exists", customPrefix: LOG_CATEGORY);
                    continue;
                }

                Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
                Directory.Move(legacy, destination);
                MilanLog.Information($"Moved {name}'s baked lighting into the UE4 bakes ({destination})", customPrefix: LOG_CATEGORY);
            }
        }
    }
}
