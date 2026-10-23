using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.ObjectInfo;

namespace ProjectMilan.Pipelines.Levels
{
    /// <summary>
    /// How brightly a level's lights light characters. Characters are not lightmapped: each one's DynamicLightEnvironment
    /// re-lights it at runtime from the level's light components, so a bake tuned darker (<see cref="StaticLighting.UE4LightmassSettings"/>)
    /// leaves them as bright as before. 1 leaves a value as ported.
    /// </summary>
    /// <param name="LocalLightScale">Scales every point and spot light's Brightness and Radius. Match the bake's
    /// LocalLightBrightnessScale/LocalLightRadiusScale so characters are lit like the lightmaps around them.</param>
    /// <param name="BouncedLightScale">Scales every point and spot light's LightEnv_BouncedLightBrightness, the light
    /// environment's stand-in for bounced light.</param>
    /// <param name="CharacterLightScale">Scales the Brightness of character-only lights: lighting channels with BSP, Static and
    /// Dynamic off, so they light nothing but light environments.</param>
    internal sealed record CharacterLightingTuning(float LocalLightScale = 1, float BouncedLightScale = 1, float CharacterLightScale = 1)
    {
        /// <summary>
        /// Scales the light components in <paramref name="package"/>. Values are read from <paramref name="valuesFrom"/> when
        /// given (the same package unmodified, e.g. a test backup), so a repeated run replaces the scaling instead of compounding it.
        /// The light components feed the bake too, so in a build this must run after the level's lighting is exported.
        /// </summary>
        /// <returns>The number of point/spot lights and character-only lights scaled.</returns>
        public (int LocalLights, int CharacterLights) Apply(IMEPackage package, IMEPackage valuesFrom = null)
        {
            int local = 0, character = 0;
            foreach (var light in package.Exports.Where(x => x.IsA("LightComponent") && !x.IsTrash()))
            {
                var source = valuesFrom?.FindExport(light.InstancedFullPath, light.ClassName) ?? light;
                var sourceProps = source.GetProperties();
                var props = light.GetProperties();
                var channels = sourceProps.GetProp<StructProperty>("LightingChannels")?.Properties;
                bool ChannelOff(string channel) => channels?.GetProp<BoolProperty>(channel) is { Value: false };
                var brightness = sourceProps.GetProp<FloatProperty>("Brightness")?.Value ?? 1f;

                if (ChannelOff("BSP") && ChannelOff("Static") && ChannelOff("Dynamic"))
                {
                    if (CharacterLightScale == 1)
                        continue;
                    props.AddOrReplaceProp(new FloatProperty(brightness * CharacterLightScale, "Brightness"));
                    character++;
                }
                else if (light.IsA("PointLightComponent")) // spot lights are point lights too
                {
                    if (LocalLightScale == 1 && BouncedLightScale == 1)
                        continue;
                    // Class defaults: Radius 1024, LightEnv_BouncedLightBrightness 1.
                    props.AddOrReplaceProp(new FloatProperty(brightness * LocalLightScale, "Brightness"));
                    props.AddOrReplaceProp(new FloatProperty((sourceProps.GetProp<FloatProperty>("Radius")?.Value ?? 1024f) * LocalLightScale, "Radius"));
                    props.AddOrReplaceProp(new FloatProperty((sourceProps.GetProp<FloatProperty>("LightEnv_BouncedLightBrightness")?.Value ?? 1f) * BouncedLightScale,
                        "LightEnv_BouncedLightBrightness"));
                    local++;
                }
                else
                    continue;
                light.WriteProperties(props);
            }
            return (local, character);
        }
    }
}
