using System;
using System.Diagnostics;
using System.IO.Compression;
using System.Xml;
using System.Xml.Linq;
using CliWrap;
using LegendaryExplorerCore.Packages;
using ProjectMilan.Utility;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Audio.Extension;

public static class WwiseCliHandler
{

    public static string GetWwiseTemplateProject(MEGame game) => Path.Combine(MilanShared.PipelineRoot, "Audio", "Template", "ConvertTemplate.zip");

    /// <summary>
    /// Converts a file or folder of wav files and converts them to Wwise encoded ogg for the specified game
    /// </summary>
    /// <param name="game">Game to convert for - Wwise path for game must be configured</param>
    /// <param name="fileOrFolderPath">Path of file or folder to convert</param>
    /// <param name="conversionSettings">Settings to place into the templated project that will be used when CLI runs</param>
    /// <returns></returns>
    public static async Task<string> RunWwiseConversion(MEGame game, string fileOrFolderPath, int targetSampleRate)
    {
        /* The process for converting is going to be pretty in depth but will make converting files much easier and faster.
                        * 1. User chooses a folder of .wav (or this method is passed a .wav and we will return that)
                        * 2. Conversion takes place
                        * 
                        * Program steps when conversion starts:
                        * 1. Extract the Wwise TemplateProject as it is required for command line. This is extracted to the root of %Temp%.
                        * 2. Generate the external sources file that points to the folder and each item to convert within it
                        * 3. Run the generate command
                        * 4. Move files from OutputFiles directory in the project
                        * 5. Delete the project
                        * */

        string wwiseCLIPath = Path.Combine(Environment.GetEnvironmentVariable("WWISEROOT"), """Authoring\x64\Release\bin\WwiseCLI.exe""");

        if (string.IsNullOrEmpty(wwiseCLIPath) || !File.Exists(wwiseCLIPath)) throw new ArgumentException("Wwise CLI path not configured");

        //Extract the template project to temp
        string templateproject = GetWwiseTemplateProject(game);
        string templatefolder = Path.Combine(Path.GetTempPath(), "TemplateProject"); // Same template as in LEX

        using (StreamReader stream = new StreamReader(templateproject))
        {
            await TryDeleteDirectory(templatefolder);
            ZipArchive archive = new ZipArchive(stream.BaseStream);
            archive.ExtractToDirectory(Path.GetTempPath());
        }

        //Generate the external sources document
        string[] filesToConvert = null;
        string exportParentFolder = ""; // folder to put "Converted" subfolder in - I CHANGED THIS FOR MILAN - HenBagle 8/21/24
        string convertFolder = ""; // actual folder the .wav file(s) are in
        bool isSingleFile = false;
        if (Directory.Exists(fileOrFolderPath))
        {
            //it's a directory
            filesToConvert = Directory.GetFiles(fileOrFolderPath, "*.wav");
            convertFolder = fileOrFolderPath;
        }
        else
        {
            //it's a single file
            isSingleFile = true;
            filesToConvert = new[] { fileOrFolderPath };
            convertFolder = Directory.GetParent(fileOrFolderPath).FullName;
        }
        exportParentFolder = Directory.GetParent(fileOrFolderPath).FullName;

        XElement externalSourcesList = new XElement("ExternalSourcesList", new XAttribute("SchemaVersion", 1.ToString()), new XAttribute("Root", convertFolder));
        foreach (string file in filesToConvert)
        {
            XElement source = new XElement("Source", new XAttribute("Path", Path.GetFileName(file)), new XAttribute("Conversion", "Vorbis"));
            externalSourcesList.Add(source);
        }

        //Write ExternalSources.wsources
        string wsourcesFile = Path.Combine(templatefolder, "ExternalSources.wsources");

        File.WriteAllText(wsourcesFile, externalSourcesList.ToString());
        Debug.WriteLine(externalSourcesList.ToString());

        string conversionSettingsFile = Path.Combine(templatefolder, "Conversion Settings", "Default Work Unit.wwu");
        XmlDocument conversionDoc = new XmlDocument();
        conversionDoc.Load(conversionSettingsFile);

        //Samplerate
        string XmlConversion3773 =
            "/WwiseDocument/Conversions/Conversion/PropertyList/Property[@Name='SampleRate']/ValueList/Value[@Platform='Windows']";
        string XmlConversion7110 =
            "/WwiseDocument/Conversions/WorkUnit/ChildrenList/Conversion/PropertyList/Property[@Name='SampleRate']/ValueList/Value[@Platform='Windows']";
        XmlNode node = conversionDoc.DocumentElement.SelectSingleNode(game is MEGame.ME3 ? XmlConversion3773 : XmlConversion7110);
        node.InnerText = targetSampleRate.ToString();
        conversionDoc.Save(conversionSettingsFile);
        //Run Conversion

        //Files generates
        string projFile = Path.Combine(templatefolder, "TemplateProject.wproj");
        string outputDirectory = Path.Combine(Path.GetTempPath(), "TemplateProject", "OutputFiles");
        string copyToDirectory = Path.Combine(exportParentFolder, "Converted");
        Directory.CreateDirectory(copyToDirectory);


        // Uncomment the two calls to route Wwise log to Milan log
        var result = await Cli.Wrap(wwiseCLIPath)
                 .WithArguments([projFile, "-ConvertExternalSources", "Windows"])
                 //.WithStandardOutputPipe(PipeTarget.ToDelegate(s => MilanLog.Information(s, customPrefix: "WWISE")))
                 .WithStandardErrorPipe(PipeTarget.ToDelegate(s => MilanLog.Error(s, customPrefix: "WWISE")))
                 .WithValidation(CommandResultValidation.None)
                 .ExecuteAsync().ConfigureAwait(false);

        if(result.ExitCode != 0)
        {
            MilanLog.Warning($"WwiseCLI.exe returned non-zero exit code {result.ExitCode}. Retrying", customPrefix: "WWISE");
            Utilities.DeleteFilesAndFoldersRecursively(outputDirectory, quiet: true);
            await Cli.Wrap(wwiseCLIPath)
                 .WithArguments([projFile, "-ConvertExternalSources", "Windows"])
                 //.WithStandardOutputPipe(PipeTarget.ToDelegate(s => MilanLog.Information(s, customPrefix: "WWISE")))
                 .WithStandardErrorPipe(PipeTarget.ToDelegate(s => MilanLog.Error(s, customPrefix: "WWISE")))
                 .WithValidation(CommandResultValidation.None)
                 .ExecuteAsync().ConfigureAwait(false);
        }

        var extension = game is MEGame.ME3 ? ".ogg" : ".wem";

        foreach (string file in filesToConvert)
        {
            string fileName = Path.GetFileName(Path.ChangeExtension(file, extension));
            if (fileName is null) break;
            File.Copy(Path.Combine(outputDirectory, fileName), Path.Combine(copyToDirectory, fileName), true);
        }

        var deleteResult = await TryDeleteDirectory(templatefolder);
        Debug.WriteLine("Deleted templatedproject: " + deleteResult);

        if (isSingleFile)
        {
            return Path.Combine(copyToDirectory, Path.GetFileNameWithoutExtension(fileOrFolderPath) + extension);
        }

        return copyToDirectory;
    }

    public static async Task<bool> TryDeleteDirectory(string directoryPath, int maxRetries = 10, int millisecondsDelay = 30)
    {
        if (directoryPath == null)
            throw new ArgumentNullException(nameof(directoryPath));
        if (maxRetries < 1)
            throw new ArgumentOutOfRangeException(nameof(maxRetries));
        if (millisecondsDelay < 1)
            throw new ArgumentOutOfRangeException(nameof(millisecondsDelay));

        for (int i = 0; i < maxRetries; ++i)
        {
            try
            {
                if (Directory.Exists(directoryPath))
                {
                    Directory.Delete(directoryPath, true);
                }

                return true;
            }
            catch (IOException)
            {
                await Task.Delay(millisecondsDelay);
            }
            catch (UnauthorizedAccessException)
            {
                await Task.Delay(millisecondsDelay);
            }
        }

        return false;
    }

    internal static async void DeleteTemplateProjectDirectory()
    {
        var templateDirectory = Path.Combine(Path.GetTempPath(), "TemplateProject");
        if (Directory.Exists(templateDirectory))
        {
            await TryDeleteDirectory(templateDirectory);
        }
    }

    public static string CreateNewProjectForBank(ExportEntry export, string projectOutputDirectory)
    {
        return "";
        //WwiseIO.ExportBankToProject(export, projectOutputDirectory);
    }

    /// <summary>
    /// LE ONLY - Generates a new WwiseProject with 7110 Wwise at the specified path
    /// </summary>
    /// <param name="projectDir"></param>
    public static string CreateNewProject(string projectDir)
    {
        Utilities.DeleteFilesAndFoldersRecursively(projectDir);

        var wwiseCLIPath = Path.Combine(Environment.GetEnvironmentVariable("WWISEROOT"), """Authoring\x64\Release\bin\WwiseCLI.exe""");
        var projFile = Path.GetFileNameWithoutExtension(projectDir) + ".wproj";
        var projPath = Path.Combine(projectDir, projFile);
        Process process = new Process
        {
            StartInfo =
            {
                FileName = wwiseCLIPath,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                Arguments = $"\"{projPath}\" -CreateNewProject -Platform Windows",
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardInput = true
            }
        };
        process.Start();
        process.WaitForExit();

        // Read output.

        return projPath;
    }
}
