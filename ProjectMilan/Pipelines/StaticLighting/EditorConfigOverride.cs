using System.Text;

namespace ProjectMilan.Pipelines.StaticLighting
{
    /// <summary>
    /// Applies temporary overrides to a UDK .ini for the lifetime of an automation run, then puts
    /// the file back exactly as it was.
    ///
    /// Some things that need suppressing during an automated bake aren't hookable. The Game Asset
    /// Database "asset checkpoint" prompt lives in UnrealEdCLR, which is C++/CLI - UDK.exe is a
    /// mixed-mode assembly, so that code is IL, JIT-compiled at runtime, with no stable RVA for
    /// UDKAgent to hook. Its only lever is a config flag read during editor startup, before
    /// injection can happen. So this sets it, the caller launches UDK, and it restores afterwards.
    ///
    /// The restore is deliberately whole-file rather than key-by-key: UDK rewrites this ini on
    /// clean exit, so putting back the original bytes is the only way to guarantee the user's own
    /// editor layout survives an automation run. For that reason, restore must happen *after* UDK
    /// has exited.
    /// </summary>
    public sealed class EditorConfigOverride : IDisposable
    {
        private const string LOG_CATEGORY = @"MILAN-EditorConfigOverride";

        readonly string _path;
        readonly string _originalText;
        readonly Encoding _encoding;
        bool _restored;

        /// <summary>Overrides applied while automating, as (section, key, value).</summary>
        public static readonly (string Section, string Key, string Value)[] AutomationProfile =
        [
            // Suppresses the "Unreal Editor hasn't updated the game's asset checkpoint file in a
            // while ... Is now a good time?" modal (Check Now / Next Run / Wait a Day / Wait a
            // Week). It's a raw WxChoiceDialog::ShowModal with no unattended-mode guard.
            // ForceJournalUpdate / JournalAlarmTime do NOT gate this dialog -- this key does, and
            // defaults to TRUE when absent, which is why editing the other two never stopped it.
            ("GameAssetDatabase", "UseJournalUpdateAlarm", "False"),

            // Browser panes that would otherwise be restored from the saved layout. They're
            // modeless, but wxSafeYield during a bake disables every top-level window except the
            // progress dialog, so anything on screen is frozen over the viewport for the whole
            // build.
            ("Docking", "ActorBrowser_Visible",  "False"),
            ("Docking", "LevelBrowser_Visible",  "False"),
            ("Docking", "SceneManager_Visible",  "False"),
            ("Docking", "LayerBrowser_Visible",  "False"),
            ("Docking", "Documentation_Visible", "False"),

            // The 10-minute autosave fires during long bakes. After a lighting build it also saves
            // content packages the build dirtied (material usage flags), and autosaving one of those
            // (BioT_GthMP) crashed UDK after a BioP_MPGeth bake. The pipeline saves explicitly, so
            // autosave only adds time and risk.
            ("UnrealEd.EditorUserSettings", "bAutoSaveEnable", "False"),
        ];

        public EditorConfigOverride(string iniPath, IEnumerable<(string Section, string Key, string Value)> overrides)
        {
            _path = iniPath ?? throw new ArgumentNullException(nameof(iniPath));
            if (!File.Exists(_path))
                throw new FileNotFoundException($"editor config not found: {_path}", _path);

            _encoding = DetectEncoding(_path);
            _originalText = File.ReadAllText(_path, _encoding);

            // Keep a copy on disk too, so a hard kill of this process is still recoverable by hand.
            File.WriteAllText(_path + ".milan-bak", _originalText, _encoding);

            var text = _originalText;
            foreach (var (section, key, value) in overrides)
                text = SetValue(text, section, key, value);

            File.WriteAllText(_path, text, _encoding);
            MilanLog.Information($"Applied {overrides.Count()} automation config override(s) to {_path}", customPrefix: LOG_CATEGORY);
        }

        /// <summary>Restores the original file contents. Safe to call more than once.</summary>
        public void Restore()
        {
            if (_restored) return;
            _restored = true;

            try
            {
                File.WriteAllText(_path, _originalText, _encoding);
                File.Delete(_path + ".milan-bak");
                MilanLog.Information($"Restored {_path}", customPrefix: LOG_CATEGORY);
            }
            catch (Exception ex)
            {
                // Never let a restore failure mask the real error from the run itself.
                MilanLog.Error($"Failed to restore {_path}: {ex.Message}. Original contents are at {_path}.milan-bak", customPrefix: LOG_CATEGORY);
            }
        }

        public void Dispose() => Restore();

        static Encoding DetectEncoding(string path)
        {
            Span<byte> bom = stackalloc byte[2];
            using (var fs = File.OpenRead(path))
            {
                if (fs.Read(bom) == 2 && bom[0] == 0xFF && bom[1] == 0xFE)
                    return Encoding.Unicode;
            }
            return new UTF8Encoding(encoderShouldEmitUTF8Identifier: false);
        }

        /// <summary>
        /// Sets section/key to value, replacing an existing key in that section, or appending the
        /// key (and the section, if needed). Preserves the file's existing line endings.
        /// </summary>
        static string SetValue(string text, string section, string key, string value)
        {
            var newline = text.Contains("\r\n") ? "\r\n" : "\n";
            var lines = text.Split(["\r\n", "\n"], StringSplitOptions.None).ToList();

            int sectionStart = lines.FindIndex(l =>
                l.Trim().Equals($"[{section}]", StringComparison.OrdinalIgnoreCase));

            if (sectionStart < 0)
            {
                if (lines.Count > 0 && lines[^1].Length > 0) lines.Add("");
                lines.Add($"[{section}]");
                lines.Add($"{key}={value}");
                return string.Join(newline, lines);
            }

            int sectionEnd = lines.FindIndex(sectionStart + 1, l => l.TrimStart().StartsWith('['));
            if (sectionEnd < 0) sectionEnd = lines.Count;

            for (int i = sectionStart + 1; i < sectionEnd; i++)
            {
                int eq = lines[i].IndexOf('=');
                if (eq > 0 && lines[i][..eq].Trim().Equals(key, StringComparison.OrdinalIgnoreCase))
                {
                    lines[i] = $"{key}={value}";
                    return string.Join(newline, lines);
                }
            }

            lines.Insert(sectionEnd, $"{key}={value}");
            return string.Join(newline, lines);
        }
    }
}
