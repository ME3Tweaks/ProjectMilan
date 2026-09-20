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
        /// Prints a numbered menu and returns the index of the option the user picked. Empty input
        /// takes <paramref name="defaultIndex"/>; anything unparseable or out of range re-prompts.
        /// <para/>
        /// Deliberately has no timeout, unlike <see cref="ConsoleReadLineWithTimeout"/> - a menu should
        /// only be shown once the user has already answered a timed prompt, so they are at the keyboard.
        /// </summary>
        /// <param name="prompt">Question shown above the options.</param>
        /// <param name="options">Option labels, in display order.</param>
        /// <param name="defaultIndex">Index into <paramref name="options"/> used when the user just presses enter.</param>
        public static int PromptForMenuSelection(string prompt, IReadOnlyList<string> options, int defaultIndex)
        {
            if (options == null || options.Count == 0)
                throw new ArgumentException("Cannot prompt with an empty option list.", nameof(options));

            if (defaultIndex < 0 || defaultIndex >= options.Count)
                defaultIndex = 0;

            while (true)
            {
                Console.WriteLine(prompt);
                for (int i = 0; i < options.Count; i++)
                {
                    Console.WriteLine($"  {i + 1}) {options[i]}");
                }
                Console.WriteLine($"Enter 1-{options.Count} (default: {defaultIndex + 1}, {options[defaultIndex]}):");

                var input = Console.ReadLine();
                if (string.IsNullOrWhiteSpace(input))
                    return defaultIndex;

                if (int.TryParse(input.Trim(), out var selection) && selection >= 1 && selection <= options.Count)
                    return selection - 1;

                Console.WriteLine($"'{input.Trim()}' is not one of the options.");
            }
        }

        /// <summary>
        /// Sets the console window title to "{prefix} - {status}", e.g. for showing the current
        /// pipeline at a glance. Swallows failures, as the title cannot be set when there is no
        /// console window (e.g. output is redirected) or on non-Windows platforms.
        /// </summary>
        public static void SetConsoleTitle(string postfix, string status)
        {
            try
            {
                Console.Title = string.IsNullOrEmpty(status) ? postfix : $"{status} - {postfix}";
            }
            catch
            {
                // No console window attached; nothing to do.
            }
        }
    }
}
