namespace ProjectMilan.Pipelines.StaticLighting
{
    /// <summary>
    /// Per-level settings for solving static lighting with UE4.27 Lightmass through the UdkInj
    /// Lightmass bridge (see <see cref="Settings.IMilanSettings.UE4LightmassPath"/>). UDK still runs the
    /// build and imports the result; only the solver changes. The scales are passed to the bridge on
    /// each install, so they apply to that level's build only.
    /// </summary>
    public class UE4LightmassSettings
    {
        /// <summary>
        /// Solve this level with UDK's own UE3 Lightmass even when UE4 Lightmass is available - e.g. a
        /// level with BSP or terrain, which the bridge can't convert yet (it fails the build instead).
        /// </summary>
        public bool UseUE3 { get; set; }

        /// <summary>
        /// Scales the translated WorldInfo environment color (the light rays that miss the scene pick
        /// up). UE4 gave about 1.6x UE3's environment light on UdkInj's TestLevel (0.63 would match),
        /// but that is uncalibrated on real maps, so the default leaves it as UE3 exported it.
        /// </summary>
        public float EnvironmentColorScale { get; set; } = 1f;

        /// <summary>
        /// Scales each directional light's IndirectLightingScale (the sun's bounced light). UE4 gave
        /// about 5.6x UE3's sun bounce on UdkInj's TestLevel (0.18 would match), uncalibrated on real
        /// maps, so the default leaves it as UE3 exported it.
        /// </summary>
        public float DirectionalIndirectLightingScale { get; set; } = 1f;

        /// <summary>
        /// Scales each point and spot light's IndirectLightingScale. Interiors are mostly lit by these, so this
        /// darkens them where <see cref="DirectionalIndirectLightingScale"/> does not.
        /// </summary>
        public float LocalIndirectLightingScale { get; set; } = 1f;

        /// <summary>
        /// Scales each point and spot light's brightness in the bake (its direct and bounced light). Only the lightmaps
        /// change: the light components in the game packages, which also light characters, keep their brightness.
        /// </summary>
        public float LocalLightBrightnessScale { get; set; } = 1f;

        /// <summary>
        /// Scales each point and spot light's radius in the bake, the distance its light reaches. UE3 falloff is
        /// relative to the radius, so this also dims the light inside it. Like <see cref="LocalLightBrightnessScale"/>,
        /// only the lightmaps change.
        /// </summary>
        public float LocalLightRadiusScale { get; set; } = 1f;

        /// <summary>
        /// Scales every material's DiffuseBoost, which sets how much light surfaces bounce (ME3 maps export 5).
        /// Lowering it darkens all bounced light, from every light, while direct light is unchanged.
        /// </summary>
        public float DiffuseBoostScale { get; set; } = 1f;

        /// <summary>
        /// Number of indirect bounces Lightmass computes; null keeps the map's own (UE3 exports 3). Fewer bounces
        /// leave shadowed areas darker; 0 bakes direct light only (MPThes lightmaps came out about 0.36x).
        /// </summary>
        public int? IndirectLightingBounces { get; set; }

        /// <summary>
        /// Gives the bake a Lightmass importance volume around the map's gameplay sublevels (see
        /// <see cref="GameplayImportanceVolume"/>), which the bridge uses when the scene has none of its own.
        /// </summary>
        public bool AddImportanceVolume { get; set; } = true;

        /// <summary>Added on every side of the gameplay mesh actors' positions.</summary>
        public float ImportanceVolumeMargin { get; set; } = 1500f;

        /// <summary>
        /// An importance volume (min X, Y, Z, max X, Y, Z) to use instead of the computed gameplay one. Null computes it.
        /// </summary>
        public float[] ImportanceBox { get; set; }

        public UE4LightmassSettings Clone() => (UE4LightmassSettings)MemberwiseClone();
    }

    /// <summary>
    /// Look tuning from the command line (--ue4-*), applied on top of every level's <see cref="UE4LightmassSettings"/>
    /// for one run, so a value can be tried on a --bake-lighting run without editing the level. Null leaves the
    /// level's value.
    /// </summary>
    public sealed record UE4LightmassOverrides(float? EnvironmentColorScale = null, float? DirectionalIndirectLightingScale = null,
        float? LocalIndirectLightingScale = null, float? DiffuseBoostScale = null, int? IndirectLightingBounces = null,
        float? LocalLightBrightnessScale = null, float? LocalLightRadiusScale = null, float[] ImportanceBox = null)
    {
        public UE4LightmassSettings ApplyTo(UE4LightmassSettings settings)
        {
            var result = settings.Clone();
            result.EnvironmentColorScale = EnvironmentColorScale ?? result.EnvironmentColorScale;
            result.DirectionalIndirectLightingScale = DirectionalIndirectLightingScale ?? result.DirectionalIndirectLightingScale;
            result.LocalIndirectLightingScale = LocalIndirectLightingScale ?? result.LocalIndirectLightingScale;
            result.DiffuseBoostScale = DiffuseBoostScale ?? result.DiffuseBoostScale;
            result.IndirectLightingBounces = IndirectLightingBounces ?? result.IndirectLightingBounces;
            result.LocalLightBrightnessScale = LocalLightBrightnessScale ?? result.LocalLightBrightnessScale;
            result.LocalLightRadiusScale = LocalLightRadiusScale ?? result.LocalLightRadiusScale;
            result.ImportanceBox = ImportanceBox ?? result.ImportanceBox;
            return result;
        }
    }
}
