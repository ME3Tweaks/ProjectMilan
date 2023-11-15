using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using CommandLine;

namespace ProjectMilan
{
    /// <summary>
    /// Defines command line options for ProjectMilan
    /// </summary>
    internal class CLIOptions
    {
        [Option('s', "settings-path", HelpText = "Indicates the path to the configuration json file for Project Milan. Specifying a file that does not exist will cause a blank one to be created that you can then fill out.", Required = true)]
        public string SettingsPath { get; set; }
    }
}
