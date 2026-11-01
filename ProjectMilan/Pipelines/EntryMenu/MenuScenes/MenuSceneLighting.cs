using System.Numerics;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;

namespace ProjectMilan.Pipelines.EntryMenu.MenuScenes
{
    /// <summary>
    /// Lights the menu terminal, its desk and the right computer to match the scene. They only take light on
    /// <see cref="TerminalChannel"/>, as a scene's sky and sun reach everything on their channels unblocked (a terminal in a
    /// tunnel came out lit like it was in the open). At build time this adds up what the map's lights give at the terminal and
    /// places a key light and an ambient sky light on that channel.
    /// </summary>
    /// <remarks>
    /// The estimate has no geometry so it can't see walls. Local lights count in full, the sun and sky only in part.
    /// </remarks>
    internal static class MenuSceneLighting
    {
        /// <summary>
        /// The channel only the terminal, desk and their lights use. No light or primitive in any MP art or menu level sets
        /// it (checked 2026-10-31).
        /// </summary>
        public const string TerminalChannel = "Cinematic_6";

        /// <summary>
        /// How much of the sun (directional lights) and sky counts, as the terminal is rarely in the open
        /// </summary>
        private const float SunWeight = 0.25f;
        private const float SkyWeight = 0.2f;

        /// <summary>
        /// How much of a local light also counts as ambient
        /// </summary>
        private const float LocalAmbientWeight = 0.15f;

        /// <summary>
        /// How far the key light stands from the terminal, and its radius
        /// </summary>
        public const float KeyDistance = 250f;
        public const float KeyRadius = 600f;

        /// <summary>
        /// Brightness limits, so a dark or blown out estimate stays usable
        /// </summary>
        private const float MinKeyBrightness = 0.15f;
        private const float MaxKeyBrightness = 3f;
        private const float MinAmbientBrightness = 0.03f;
        private const float MaxAmbientBrightness = 0.8f;

        /// <summary>
        /// Channels that mean a light lights the world. Lights only on skybox, cinematic, gameplay or crowd channels are ignored.
        /// </summary>
        private static readonly HashSet<string> WorldChannels = new(StringComparer.OrdinalIgnoreCase)
        {
            "BSP", "Static", "Dynamic", "CompositeDynamic", "Unnamed_1", "Unnamed_2", "Unnamed_3", "Unnamed_4", "Unnamed_5", "Unnamed_6",
        };

        /// <summary>
        /// LightingChannels with only <see cref="TerminalChannel"/> set. Every member is written, as one left out keeps the
        /// object's default (BSP, Static, Dynamic and CompositeDynamic are on).
        /// </summary>
        public static StructProperty TerminalChannels(IMEPackage package)
        {
            var channels = GlobalUnrealObjectInfo.getDefaultStructValue(MEGame.LE3, "LightingChannelContainer", true, package);
            foreach (var channel in channels.OfType<BoolProperty>())
            {
                channel.Value = channel.Name.Instanced is "bInitialized" or TerminalChannel;
            }
            return new StructProperty("LightingChannelContainer", channels, "LightingChannels");
        }

        /// <summary>
        /// The light at a point: the directional key part, the direction it comes from, and the ambient part. Linear RGB.
        /// </summary>
        public sealed record Estimate(Vector3 Key, Vector3 KeyDirection, Vector3 Ambient, int LightCount);

        /// <summary>
        /// A light to place: sRGB color and brightness, as LightComponent takes them
        /// </summary>
        public sealed record LightSetting(System.Drawing.Color Color, float Brightness);

        /// <summary>
        /// Adds up the world lights in the given levels at a point
        /// </summary>
        public static Estimate EstimateAt(IEnumerable<IMEPackage> levels, Vector3 point)
        {
            var key = Vector3.Zero;
            var direction = Vector3.Zero;
            var ambient = Vector3.Zero;
            int count = 0;
            foreach (var level in levels)
            {
                foreach (var light in GetLights(level))
                {
                    if (!light.Enabled || !light.LightsTheWorld)
                    {
                        continue;
                    }

                    var color = light.Color * light.Brightness;
                    if (light.Kind == LightKind.Sky)
                    {
                        ambient += color * SkyWeight;
                        count++;
                        continue;
                    }
                    if (light.Kind == LightKind.Directional)
                    {
                        // Shines along forward, so it comes from the opposite way
                        var sun = color * SunWeight;
                        key += sun;
                        direction += -light.Forward * Luminance(sun);
                        count++;
                        continue;
                    }

                    var toLight = light.Location - point;
                    float distance = toLight.Length();
                    if (distance >= light.Radius || distance < 1f)
                    {
                        continue;
                    }
                    float ratio = distance / light.Radius;
                    float attenuation = MathF.Pow(1f - ratio * ratio, light.FalloffExponent);
                    if (light.Kind == LightKind.Spot)
                    {
                        float cosAngle = Vector3.Dot(light.Forward, -toLight / distance);
                        float cosOuter = MathF.Cos(light.OuterConeAngle * MathF.PI / 180f);
                        float cosInner = MathF.Cos(MathF.Min(light.InnerConeAngle, light.OuterConeAngle - 0.01f) * MathF.PI / 180f);
                        float cone = Math.Clamp((cosAngle - cosOuter) / (cosInner - cosOuter), 0f, 1f);
                        attenuation *= cone * cone;
                    }
                    if (attenuation <= 0f)
                    {
                        continue;
                    }

                    var contribution = color * attenuation;
                    key += contribution;
                    ambient += contribution * LocalAmbientWeight;
                    direction += toLight / distance * Luminance(contribution);
                    count++;
                }
            }

            // Straight down from above when nothing gives a direction
            direction = direction.LengthSquared() > 1e-6f ? Vector3.Normalize(direction) : Vector3.UnitZ;
            return new Estimate(key, direction, ambient, count);
        }

        /// <summary>
        /// The key light for an estimate, standing <see cref="KeyDistance"/> from the terminal inside <see cref="KeyRadius"/>
        /// </summary>
        public static LightSetting GetKeyLight(Estimate estimate)
        {
            // What a light of brightness 1 gives at KeyDistance with the default falloff
            float ratio = KeyDistance / KeyRadius;
            float attenuation = (1f - ratio * ratio) * (1f - ratio * ratio);
            return ToLight(estimate.Key / attenuation, MinKeyBrightness, MaxKeyBrightness);
        }

        public static LightSetting GetAmbientLight(Estimate estimate)
        {
            return ToLight(estimate.Ambient, MinAmbientBrightness, MaxAmbientBrightness);
        }

        /// <summary>
        /// Splits linear RGB into a color (brightest channel at full) and a brightness
        /// </summary>
        private static LightSetting ToLight(Vector3 linear, float minBrightness, float maxBrightness)
        {
            float peak = MathF.Max(linear.X, MathF.Max(linear.Y, linear.Z));
            if (peak <= 1e-6f)
            {
                return new LightSetting(System.Drawing.Color.White, minBrightness);
            }
            var hue = linear / peak;
            return new LightSetting(ToGamma(hue), Math.Clamp(peak, minBrightness, maxBrightness));
        }

        /// <summary>
        /// Linear RGB (0-1) to the sRGB color LightComponent.LightColor stores
        /// </summary>
        public static System.Drawing.Color ToGamma(Vector3 linear)
        {
            static int Channel(float value) => (int)Math.Round(Math.Pow(Math.Clamp(value, 0f, 1f), 1 / 2.2) * 255);
            return System.Drawing.Color.FromArgb(255, Channel(linear.X), Channel(linear.Y), Channel(linear.Z));
        }

        private static float Luminance(Vector3 color)
        {
            return color.X * 0.3f + color.Y * 0.59f + color.Z * 0.11f;
        }

        private enum LightKind
        {
            Point,
            Spot,
            Directional,
            Sky,
        }

        private sealed record LightInfo(LightKind Kind, Vector3 Location, Vector3 Forward, Vector3 Color, float Brightness, float Radius,
            float FalloffExponent, float InnerConeAngle, float OuterConeAngle, bool Enabled, bool LightsTheWorld);

        /// <summary>
        /// Every light component in a level in world space. Collection lights use their actor's transforms.
        /// </summary>
        private static IEnumerable<LightInfo> GetLights(IMEPackage level)
        {
            var transforms = new Dictionary<int, Matrix4x4>();
            foreach (var collection in level.Exports.Where(x => x.ClassName == "StaticLightCollectionActor"))
            {
                if (ObjectBinary.From(collection) is not StaticCollectionActor binary)
                {
                    continue;
                }
                var components = collection.GetProperty<ArrayProperty<ObjectProperty>>("LightComponents");
                for (int i = 0; components != null && i < components.Count && i < binary.LocalToWorldTransforms.Count; i++)
                {
                    transforms[components[i].Value] = binary.LocalToWorldTransforms[i];
                }
            }

            foreach (var component in level.Exports.Where(x => x.ClassName.EndsWith("LightComponent")))
            {
                LightKind kind;
                if (component.ClassName.Contains("Sky"))
                {
                    kind = LightKind.Sky;
                }
                else if (component.ClassName.Contains("Directional"))
                {
                    kind = LightKind.Directional;
                }
                else if (component.ClassName.Contains("Spot"))
                {
                    kind = LightKind.Spot;
                }
                else if (component.ClassName.Contains("Point"))
                {
                    kind = LightKind.Point;
                }
                else
                {
                    continue;
                }

                Vector3 location;
                Vector3 forward;
                if (transforms.TryGetValue(component.UIndex, out var matrix))
                {
                    location = new Vector3(matrix.M41, matrix.M42, matrix.M43);
                    forward = Vector3.Normalize(new Vector3(matrix.M11, matrix.M12, matrix.M13));
                }
                else if (component.Parent is ExportEntry owner && owner.GetProperty<ObjectProperty>("LightComponent")?.Value == component.UIndex)
                {
                    location = CommonStructs.GetVector3(owner, "location", Vector3.Zero);
                    forward = CommonStructs.GetRotator(owner, "Rotation", default).GetDirectionalVector();
                }
                else
                {
                    // Template, or a light no actor places
                    continue;
                }

                yield return new LightInfo(
                    kind,
                    location,
                    forward,
                    ReadColor(component.GetProperty<StructProperty>("LightColor")),
                    component.GetProperty<FloatProperty>("Brightness")?.Value ?? 1f,
                    component.GetProperty<FloatProperty>("Radius")?.Value ?? 1024f,
                    component.GetProperty<FloatProperty>("FalloffExponent")?.Value ?? 2f,
                    component.GetProperty<FloatProperty>("InnerConeAngle")?.Value ?? 0f,
                    component.GetProperty<FloatProperty>("OuterConeAngle")?.Value ?? 44f,
                    component.GetProperty<BoolProperty>("bEnabled")?.Value ?? true,
                    LightsTheWorld(component.GetProperty<StructProperty>("LightingChannels")));
            }
        }

        /// <summary>
        /// LightComponent's default channels
        /// </summary>
        private static readonly string[] DefaultLightChannels = ["BSP", "Static", "Dynamic", "CompositeDynamic"];

        /// <summary>
        /// Whether a light lights the world. Cooked lights only save channels that differ from the defaults, so an unlisted
        /// channel keeps its default.
        /// </summary>
        private static bool LightsTheWorld(StructProperty? channels)
        {
            var on = new HashSet<string>(DefaultLightChannels, StringComparer.OrdinalIgnoreCase);
            foreach (var channel in channels?.Properties.OfType<BoolProperty>() ?? [])
            {
                if (channel.Value)
                {
                    on.Add(channel.Name.Instanced);
                }
                else
                {
                    on.Remove(channel.Name.Instanced);
                }
            }
            return on.Overlaps(WorldChannels);
        }

        /// <summary>
        /// LightColor is an sRGB FColor; the engine lights in linear space
        /// </summary>
        private static Vector3 ReadColor(StructProperty? color)
        {
            if (color == null)
            {
                return Vector3.One;
            }
            static float Linear(ByteProperty? channel) => channel == null ? 1f : MathF.Pow(channel.Value / 255f, 2.2f);
            return new Vector3(Linear(color.GetProp<ByteProperty>("R")), Linear(color.GetProp<ByteProperty>("G")), Linear(color.GetProp<ByteProperty>("B")));
        }
    }
}
