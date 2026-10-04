#pragma warning disable CA1416

using LegendaryExplorerCore.Gammtek.Extensions;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Scaleform;
using System.Diagnostics;
using Microsoft.Win32;
public class ScaleformBuilder
{

    private const string LogCategory = @"MILAN-Scaleform";
    
    /// <summary>
    /// Directory that the output of the pipeline will be passed to <br/>
    /// e.g. for Startup the output will go to {OutputDir}/{PackageName}/Properties/{PropertyName}
    /// </summary>
    private static readonly string OutputDir = Path.Combine(MilanShared.PipelineRoot, "Mod", "BaseDelta");
    
    /// <summary>
    /// Path of installed JPEXS Decompiler
    /// </summary>
    private static DirectoryInfo? FFDecInstallPath
    {
        get
        {
            try
            {
                // Custom path takes priority
                if (!Program.Settings.CustomFFDecPath.IsNull())
                {
                    return new DirectoryInfo(Program.Settings.CustomFFDecPath);
                }
                
                // Try to get the post FFDec Nightly 3542 registry key
                using var ffdecKeyNew = Registry.CurrentUser.OpenSubKey(@"Software\JPEXS\FFDec");
                if (ffdecKeyNew?.GetValue("installDir") is string installDirNew)
                {
                    return new DirectoryInfo(installDirNew);
                }

                // Try to get the pre FFDec Nightly 3542 registry key
                using var ffdecKeyOld = Registry.CurrentUser.OpenSubKey(
                    @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{E618D276-6596-41F4-8A98-447D442A77DB}_is1");
                if (ffdecKeyOld?.GetValue("InstallLocation") is string installDirOld)
                {
                    return new DirectoryInfo(installDirOld);
                }

                // Install not found
                throw new Exception("""
                    ffdec-cli.exe path not found! Install the JPEXS Decompiler.
                    If the decompiler is installed and is not being detected, you can set a path in your build settings.
                """);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Caught exception when trying to get ffdec path:\n{ex}");
            }

            return null;
        }
    }
    
    /// <summary>
    /// Used as a basis for calling ffdec-cli
    /// </summary>
    private static readonly ProcessStartInfo FFDecProcessInfo = new()
    {
        FileName = Path.Combine(FFDecInstallPath?.FullName ?? throw new FileNotFoundException(), "ffdec-cli.exe"),
        CreateNoWindow = true,
        UseShellExecute = false,
        RedirectStandardOutput = true,
        RedirectStandardError = true,
        ArgumentList = { "--help" },
        WindowStyle = ProcessWindowStyle.Hidden
    };

    /// <summary>
    /// Compiles the Scaleform XML exports into SWF, updates the scripts, and outputs into BaseDelta 
    /// </summary>
    private static void Build()
    {
        var sourceDir = Path.Combine(MilanShared.PipelineRoot, "Scaleform", "Packages");
        var outputDir = Path.Combine(OutputDir, "Shared", "GUI", "Staging");
        Directory.CreateDirectory(outputDir);
        // var path = "Y:/WIP/Milan/experiments/SFWPipeline/SFWPipeline/Pipelines/Shared/GUI/Staging/Startup/Startup.pcc";
        foreach (var sourcePackageDir in Directory.GetDirectories(sourceDir))
        {
            var packageName = Directory.CreateDirectory(sourcePackageDir).Name;
            Directory.CreateDirectory(Path.Combine(outputDir, packageName));
            foreach (var sourceXmlPath in Directory.GetFiles(sourcePackageDir, "*.xml", SearchOption.AllDirectories))
            {
                var swfName = Path.GetFileNameWithoutExtension(sourceXmlPath);
                var swfDir = Directory.GetParent(sourceXmlPath);
                var builtSwfPath = Path.Combine(outputDir, packageName, $"{swfDir.Name}.swf");
                Xml2Swf(sourceXmlPath, builtSwfPath);
                foreach (var scriptPath in swfDir.GetFiles("*.as"))
                {
                    SwfReplaceScript(builtSwfPath, scriptPath.FullName);
                }
            }
        }
    }
    
    /// <summary>
    /// Converts an XML representation of a scaleform into SWF <br/>
    /// (The XML has to be exported via the JPEXS Decompiler)
    /// </summary>
    /// <param name="inputXmlPath"></param>
    /// <param name="outputSwfPath"></param>
    private static void Xml2Swf(string inputXmlPath, string outputSwfPath)
    {
        MilanLog.Information($"Creating {Path.GetFileName(outputSwfPath)}", customPrefix: LogCategory);
        var ffdec = FFDecProcessInfo;
        ffdec.ArgumentList.Clear();
        ffdec.ArgumentList.Add("-xml2swf");
        ffdec.ArgumentList.Add(inputXmlPath);
        ffdec.ArgumentList.Add(outputSwfPath);
        using var exeProcess = Process.Start(ffdec);
        exeProcess?.WaitForExit();
    }
    
    /// <summary>
    /// Replaces script in SWF file
    /// </summary>
    /// <param name="swfPath"></param>
    /// <param name="scriptPath">Name of the script file has to match the internal path of the SWF</param>
    private static void SwfReplaceScript(string swfPath, string scriptPath)
    {
        // __Packages.screens.options.Options
        MilanLog.Information($"Replacing {Path.GetFileNameWithoutExtension(scriptPath)} in {Path.GetFileName(swfPath)}", customPrefix: LogCategory);
        var internalScriptPath = '\\' + Path.GetFileNameWithoutExtension(scriptPath).Replace(".", @"\");
        var ffdec = FFDecProcessInfo;
        ffdec.ArgumentList.Clear();
        ffdec.ArgumentList.Add("-replace");
        ffdec.ArgumentList.Add(swfPath);
        ffdec.ArgumentList.Add(swfPath); // overriding same file
        ffdec.ArgumentList.Add(internalScriptPath);
        ffdec.ArgumentList.Add(scriptPath);
        // Console.WriteLine($"{ffdec.FileName} {string.Join(' ', ffdec.ArgumentList)}");
        // return;
        using var exeProcess = Process.Start(ffdec);
        // exeProcess?.WaitForExitAsync();
        exeProcess?.WaitForExit();
    }
}