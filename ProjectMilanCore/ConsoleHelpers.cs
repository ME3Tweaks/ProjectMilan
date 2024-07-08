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
    }
}
