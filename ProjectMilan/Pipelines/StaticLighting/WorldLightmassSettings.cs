using System.Drawing;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.StaticLighting
{
    /// <summary>
    /// Per-level overrides for the UDK persistent map's WorldInfo.LightmassSettings, written when the level is
    /// exported for its bake. Anything left null keeps UDK's default.
    /// </summary>
    /// <remarks>
    /// ME3's cooked WorldInfo has no LightmassSettings at all, so the values the original maps were baked
    /// with can't be read back and our bakes run on UDK's defaults (black environment, 3 bounces). Measured
    /// against ME3's own lightmaps, that leaves interiors that are lit mainly by bounced light far darker than
    /// the original (see LIGHTING_CALIBRATION_HANDOFF.md); these settings exist to calibrate that.
    ///
    /// The UE4 Lightmass bridge carries NumIndirectLightingBounces, StaticLightingLevelScale, EnvironmentColor
    /// (already multiplied by EnvironmentIntensity) and the ambient occlusion settings from the scene header;
    /// every other header setting comes from its UE4 reference header. DiffuseBoost is not in either header or
    /// in the per-element boost (UDK writes 1 there), so UDK applies it while exporting the material samples,
    /// which reach UE4 unchanged.
    /// </remarks>
    public class WorldLightmassSettings
    {
        /// <summary>
        /// Light picked up by rays that leave the scene. Stored as UE3 does, an sRGB byte color; Lightmass
        /// linearizes it. UDK's default is black.
        /// </summary>
        public Color? EnvironmentColor { get; set; }

        /// <summary>Scales <see cref="EnvironmentColor"/>. UDK's default is 1.</summary>
        public float? EnvironmentIntensity { get; set; }

        /// <summary>UDK's default is 3.</summary>
        public int? NumIndirectLightingBounces { get; set; }

        /// <summary>Scales material diffuse for bounced light, applied by UDK to the exported materials. UDK's default is 5.</summary>
        public float? DiffuseBoost { get; set; }

        /// <summary>
        /// Writes the overrides into <paramref name="worldInfo"/>'s LightmassSettings, keeping any field already
        /// set there that this doesn't override.
        /// </summary>
        public void ApplyTo(ExportEntry worldInfo, string logCategory)
        {
            var settings = worldInfo.GetProperty<StructProperty>("LightmassSettings")
                           ?? new StructProperty("LightmassWorldInfoSettings", [], "LightmassSettings", isImmutable: false);
            var applied = new List<string>();
            if (EnvironmentColor is { } color)
            {
                settings.Properties.AddOrReplaceProp(CommonStructs.ColorProp(Color.FromArgb(0, color.R, color.G, color.B), "EnvironmentColor"));
                applied.Add($"EnvironmentColor=({color.R},{color.G},{color.B})");
            }
            if (EnvironmentIntensity is { } intensity)
            {
                settings.Properties.AddOrReplaceProp(new FloatProperty(intensity, "EnvironmentIntensity"));
                applied.Add($"EnvironmentIntensity={intensity}");
            }
            if (NumIndirectLightingBounces is { } bounces)
            {
                settings.Properties.AddOrReplaceProp(new IntProperty(bounces, "NumIndirectLightingBounces"));
                applied.Add($"NumIndirectLightingBounces={bounces}");
            }
            if (DiffuseBoost is { } diffuseBoost)
            {
                settings.Properties.AddOrReplaceProp(new FloatProperty(diffuseBoost, "DiffuseBoost"));
                applied.Add($"DiffuseBoost={diffuseBoost}");
            }
            if (applied.Count == 0)
                return;

            worldInfo.WriteProperty(settings);
            MilanLog.Information($"WorldInfo Lightmass overrides for {worldInfo.FileRef.FileNameNoExtension}: {string.Join(", ", applied)}", customPrefix: logCategory);
        }
    }
}
