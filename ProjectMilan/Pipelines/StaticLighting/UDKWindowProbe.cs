using System.Runtime.InteropServices;
using System.Text;

namespace ProjectMilan.Pipelines.StaticLighting
{
    /// <summary>
    /// Lists a process's visible top-level windows with their text, for diagnosing a UDK that stopped
    /// responding: a modal dialog blocking the editor shows up here with its title and message.
    /// </summary>
    internal static class UDKWindowProbe
    {
        private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern bool EnumChildWindows(IntPtr parent, EnumWindowsProc callback, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

        [DllImport("user32.dll")]
        private static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int maxCount);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern int GetClassName(IntPtr hWnd, StringBuilder text, int maxCount);

        /// <summary>
        /// "'Title' (Class): static text | ..." for each visible window of <paramref name="processId"/>.
        /// Never throws: it's called while reporting another failure.
        /// </summary>
        public static string Describe(int processId)
        {
            try
            {
                var windows = new List<string>();
                EnumWindows((hWnd, _) =>
                {
                    GetWindowThreadProcessId(hWnd, out var owner);
                    if (owner != processId || !IsWindowVisible(hWnd))
                        return true;

                    // Dialog message text (MessageBox, wx dialogs) lives in Static child controls.
                    // GetWindowText reads another process's window text without sending it a
                    // message, so a hung UDK can't block this.
                    var text = new List<string>();
                    EnumChildWindows(hWnd, (child, _) =>
                    {
                        if (IsWindowVisible(child) && ClassOf(child) == "Static" && TextOf(child) is { Length: > 0 } t)
                            text.Add(t.ReplaceLineEndings(" "));
                        return true;
                    }, IntPtr.Zero);

                    windows.Add($"'{TextOf(hWnd)}' ({ClassOf(hWnd)})" + (text.Count > 0 ? ": " + string.Join(" | ", text) : ""));
                    return true;
                }, IntPtr.Zero);
                return windows.Count > 0 ? string.Join("; ", windows) : "none visible";
            }
            catch (Exception ex)
            {
                return $"could not list them ({ex.Message})";
            }
        }

        private static string TextOf(IntPtr hWnd)
        {
            var text = new StringBuilder(512);
            GetWindowText(hWnd, text, text.Capacity);
            return text.ToString();
        }

        private static string ClassOf(IntPtr hWnd)
        {
            var name = new StringBuilder(256);
            GetClassName(hWnd, name, name.Capacity);
            return name.ToString();
        }
    }
}
