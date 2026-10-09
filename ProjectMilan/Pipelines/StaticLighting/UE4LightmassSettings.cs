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
        /// Gives the bake a Lightmass importance volume around the map's gameplay sublevels (see
        /// <see cref="GameplayImportanceVolume"/>), which the bridge uses when the scene has none of its own.
        /// </summary>
        public bool AddImportanceVolume { get; set; } = true;

        /// <summary>Added on every side of the gameplay mesh actors' positions.</summary>
        public float ImportanceVolumeMargin { get; set; } = 1500f;
    }
}
