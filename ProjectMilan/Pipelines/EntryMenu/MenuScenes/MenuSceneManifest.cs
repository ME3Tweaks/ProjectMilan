using System.Numerics;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace ProjectMilan.Pipelines.EntryMenu.MenuScenes
{
    /// <summary>
    /// One main menu backdrop, read from Pipelines\EntryMenu\Scenes\[Map].json. Coordinates are world space in the map's
    /// levels, captured in game with the milanmenu.pos console command.
    /// </summary>
    internal sealed class MenuSceneManifest
    {
        /// <summary>
        /// The map's persistent level without its BioP_ prefix, e.g. MPDish. The menu persistent is EntryMenu_[Map].
        /// </summary>
        public string Map { get; set; } = "";

        /// <summary>
        /// Where the terminal stands. Its yaw is the direction the screen faces.
        /// </summary>
        public MenuSceneTransform TerminalAnchor { get; set; } = new();

        /// <summary>
        /// The splash view. The camera drifts from Start towards End while waiting for Press Start.
        /// </summary>
        public MenuSceneVista VistaCamera { get; set; } = new();

        /// <summary>
        /// Overrides the view the camera cuts to on Press Start. If unset, <see cref="MenuSceneFraming"/> is used.
        /// </summary>
        public MenuSceneCamera? TerminalCamera { get; set; }

        /// <summary>
        /// Overrides for the terminal's lights. Anything unset is worked out by <see cref="MenuSceneLighting"/> at build time.
        /// </summary>
        public MenuSceneTerminalLighting? TerminalLighting { get; set; }

        /// <summary>
        /// The view the camera cuts to on Press Start
        /// </summary>
        [JsonIgnore]
        public MenuSceneCamera TerminalView => TerminalCamera ?? MenuSceneFraming.GetTerminalCamera(TerminalAnchor);

        /// <summary>
        /// Tint of the terminal's hologram materials (Color parameter, linear; stock is 0.5, 1, 5). Null keeps stock. The
        /// hologram is unlit, so scene lights never change it.
        /// </summary>
        public MenuSceneColor? HologramTint { get; set; }

        /// <summary>
        /// Color multiplier for the menu movie on the terminal screen. Null keeps stock.
        /// </summary>
        public MenuSceneColor? UITint { get; set; }

        /// <summary>
        /// Art sublevels to show. Null shows every BioA_ level in the built BioP's default streaming state. BioD_ and BioSnd_
        /// levels are never taken from here; use <see cref="DesignLevels"/>.
        /// </summary>
        public List<string>? Sublevels { get; set; }

        /// <summary>
        /// Design levels whose Kismet drives dynamic art (flashing lights, moving parts), copied with only that Kismet kept
        /// </summary>
        public List<MenuSceneDesignLevel> DesignLevels { get; set; } = [];

        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            ReadCommentHandling = JsonCommentHandling.Skip,
            AllowTrailingCommas = true,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        };

        public static MenuSceneManifest Load(string path)
        {
            var manifest = JsonSerializer.Deserialize<MenuSceneManifest>(File.ReadAllText(path), JsonOptions)
                ?? throw new InvalidDataException($"{path} is empty.");
            if (string.IsNullOrWhiteSpace(manifest.Map))
            {
                throw new InvalidDataException($"{path} has no Map.");
            }

            // A trailing _<number> is read as the instance number, so EntryMenu_X_2 wouldn't be found
            if (Regex.IsMatch(manifest.Map, @"_\d+$"))
            {
                throw new InvalidDataException($"{path}: map name {manifest.Map} can't end in _<number>.");
            }

            return manifest;
        }
    }

    /// <summary>
    /// The terminal framing a scene gets unless it sets its own: the stock EntryMenu's terminal camera, at the same offset
    /// from the terminal, moved to the scene's anchor
    /// </summary>
    internal static class MenuSceneFraming
    {
        // Stock EntryMenu's SFXSkeletalMeshActor_0 (terminal) and CameraActor_1 (the camera its menu Matinee holds)
        private static readonly Vector3 StockTerminalLocation = new(32268.05f, -135.403f, 470.574f);
        private const int StockTerminalYaw = -32128;
        private static readonly Vector3 StockCameraLocation = new(31923.87f, -235.175f, 570.544f);
        private const int StockCameraPitch = -1425;
        private const int StockCameraYaw = 5179;
        private const int StockCameraRoll = -177;
        private const float StockCameraFOV = 46f;

        /// <summary>
        /// Height of the terminal's bounds centre above its anchor, where its lighting is worked out
        /// </summary>
        public const float TerminalCenterHeight = 58.5f;

        /// <summary>
        /// The stock terminal camera moved to the anchor. The anchor is taken as level; only its yaw turns the framing.
        /// </summary>
        public static MenuSceneCamera GetTerminalCamera(MenuSceneTransform anchor)
        {
            var offset = RotateYaw(StockCameraLocation - StockTerminalLocation, anchor.Rotation.Yaw - StockTerminalYaw);
            return new MenuSceneCamera
            {
                Location = new MenuSceneVector
                {
                    X = anchor.Location.X + offset.X,
                    Y = anchor.Location.Y + offset.Y,
                    Z = anchor.Location.Z + offset.Z,
                },
                Rotation = new MenuSceneRotator
                {
                    Pitch = StockCameraPitch,
                    Yaw = WrapRotation(anchor.Rotation.Yaw + StockCameraYaw - StockTerminalYaw),
                    Roll = StockCameraRoll,
                },
                FOV = StockCameraFOV,
            };
        }

        /// <summary>
        /// Turns a vector about Z by an Unreal yaw (65536 is a full turn)
        /// </summary>
        private static Vector3 RotateYaw(Vector3 vector, int yaw)
        {
            double angle = yaw * Math.PI * 2 / 65536;
            float cos = (float)Math.Cos(angle);
            float sin = (float)Math.Sin(angle);
            return new Vector3(vector.X * cos - vector.Y * sin, vector.X * sin + vector.Y * cos, vector.Z);
        }

        /// <summary>
        /// Wraps a rotation into -32768..32767 so camera blends take the short way round
        /// </summary>
        private static int WrapRotation(int value)
        {
            return (short)(value & 0xFFFF);
        }
    }

    internal sealed class MenuSceneTransform
    {
        public MenuSceneVector Location { get; set; } = new();
        public MenuSceneRotator Rotation { get; set; } = new();
    }

    internal sealed class MenuSceneCamera
    {
        public MenuSceneVector Location { get; set; } = new();
        public MenuSceneRotator Rotation { get; set; } = new();
        public float FOV { get; set; } = 70f;
    }

    internal sealed class MenuSceneVista
    {
        public MenuSceneCamera Start { get; set; } = new();

        /// <summary>
        /// Where the drift ends. Null holds the start view. Drift time is shared by all scenes, so distance sets the speed.
        /// </summary>
        public MenuSceneCamera? End { get; set; }
    }

    /// <summary>
    /// Overrides for the terminal's key light and ambient sky light. Colors are linear with the brightest channel at 1.
    /// </summary>
    internal sealed class MenuSceneTerminalLighting
    {
        public MenuSceneColor? KeyColor { get; set; }
        public float? KeyBrightness { get; set; }
        public MenuSceneColor? AmbientColor { get; set; }
        public float? AmbientBrightness { get; set; }
    }

    internal sealed class MenuSceneDesignLevel
    {
        /// <summary>
        /// The design level package, e.g. BioD_MPTowr2. Its menu copy is &lt;Package&gt;_Menu.
        /// </summary>
        public string Package { get; set; } = "";

        /// <summary>
        /// Paths relative to TheWorld.PersistentLevel.Main_Sequence of the Kismet objects to keep, usually the events that
        /// start the dynamic parts (e.g. SeqEvent_LevelLoaded_2). Everything they lead to is kept; a kept sequence keeps all
        /// its contents.
        /// </summary>
        public List<string> KeepKismet { get; set; } = [];

        /// <summary>
        /// Items to start on scene becoming ready
        /// </summary>
        public List<string> StartOnSceneReady { get; set; } = [];

        /// <summary>
        /// Objects that are targets as players and become the camera actor. Used for Slum2 rain triggers going under an overpass
        /// </summary>
        public List<string> PlayerTargets { get; set; } = [];

        /// <summary>
        /// Touch triggers for the camera
        /// </summary>
        public List<string> CameraTouches { get; set; } = [];

        /// <summary>
        /// Actors to drop by name in TheWorld.PersistentLevel, for art that only makes sense in a match (e.g. a parked
        /// shuttle). Actors based on them go too.
        /// </summary>
        public List<string> RemoveActors { get; set; } = [];
    }

    internal sealed class MenuSceneVector
    {
        public float X { get; set; }
        public float Y { get; set; }
        public float Z { get; set; }
    }

    /// <summary>
    /// Unreal rotation units: 65536 is a full turn
    /// </summary>
    internal sealed class MenuSceneRotator
    {
        public int Pitch { get; set; }
        public int Yaw { get; set; }
        public int Roll { get; set; }
    }

    /// <summary>
    /// Linear color. Values above 1 brighten.
    /// </summary>
    internal sealed class MenuSceneColor
    {
        public float R { get; set; }
        public float G { get; set; }
        public float B { get; set; }
        public float A { get; set; } = 1f;
    }
}
