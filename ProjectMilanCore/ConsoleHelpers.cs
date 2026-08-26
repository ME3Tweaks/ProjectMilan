using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ProjectMilanCore
{
    public static class ConsoleHelpers
    {
        // From https://stackoverflow.com/a/46226327
        public static string ConsoleReadLineWithTimeout(TimeSpan timeout)
        {
            Task<string> task = Task.Factory.StartNew(Console.ReadLine);

            string result = Task.WaitAny(new Task[] { task }, timeout) == 0
                ? task.Result
                : string.Empty;
            return result;
        }

        /// <summary>
        /// Sets the console window title to "{prefix} - {status}", e.g. for showing the current
        /// pipeline at a glance. Swallows failures, as the title cannot be set when there is no
        /// console window (e.g. output is redirected) or on non-Windows platforms.
        /// </summary>
        public static void SetConsoleTitle(string prefix, string status)
        {
            try
            {
                Console.Title = string.IsNullOrEmpty(status) ? prefix : $"{prefix} - {status}";
            }
            catch
            {
                // No console window attached; nothing to do.
            }
        }
    }
}
