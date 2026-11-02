#pragma warning disable CA1416

using ProjectMilanCore;
using ProjectMilanCore.Textures;
using System.Diagnostics;
using Microsoft.Win32;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using ProjectMilan.Utility;
using PixelFormat = LegendaryExplorerCore.Textures.PixelFormat;

namespace ProjectMilan.Pipelines.Scaleform;

public class ScaleformBuilder
{

    private const string LogCategory = @"MILAN-Scaleform";

    /// <summary>
    /// Directory that the output of the pipeline will be passed to <br/>
    /// e.g. for Startup the output will go to {OutputDir}/{PackageName}/PropertyUpdate/{PropertyName}
    /// </summary>
    private static readonly string OutputDir = Path.Combine(MilanShared.PipelineRoot, "Mod", "BaseDelta");
    private static readonly string DonorOutputDir = Path.Combine(MilanShared.PipelineRoot, "Shared", "GlobalDonors", "GUI");

    private const string FFDecUninstallKey = @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{E618D276-6596-41F4-8A98-447D442A77DB}_is1";

    /// <summary>
    /// Path of ffdec-cli.exe, resolved on first use so a machine without JPEXS installed only fails
    /// when there's actually Scaleform source to build.
    /// </summary>
    private static string? ffdecCliPath;

    /// <summary>
    /// Finds the installed JPEXS Decompiler folder, or null if it can't be found.
    /// </summary>
    private static string? FindFFDecInstallPath()
    {
        // Custom path takes priority
        if (!string.IsNullOrWhiteSpace(Program.Settings.CustomFFDecPath))
        {
            return Program.Settings.CustomFFDecPath;
        }

        // Try to get the post FFDec Nightly 3542 registry key
        using var ffdecKeyNew = Registry.CurrentUser.OpenSubKey(@"Software\JPEXS\FFDec");
        if (ffdecKeyNew?.GetValue("installDir") is string installDirNew)
        {
            return installDirNew;
        }

        // Try to get the pre FFDec Nightly 3542 registry key - per-machine installs register under HKLM, per-user under HKCU
        foreach (var hive in new[] { Registry.LocalMachine, Registry.CurrentUser })
        {
            using var ffdecKeyOld = hive.OpenSubKey(FFDecUninstallKey);
            if (ffdecKeyOld?.GetValue("InstallLocation") is string installDirOld)
            {
                return installDirOld;
            }
        }

        return null;
    }

    /// <summary>
    /// Returns the path of ffdec-cli.exe. Aborts the build if it can't be found.
    /// </summary>
    private static string GetFFDecCliPath()
    {
        if (ffdecCliPath != null)
            return ffdecCliPath;

        var installPath = FindFFDecInstallPath();
        var cliPath = installPath == null ? null : Path.Combine(installPath, "ffdec-cli.exe");
        if (cliPath == null || !File.Exists(cliPath))
        {
            MilanLog.Fatal($"""
                ffdec-cli.exe not found{(cliPath == null ? "" : $" at {cliPath}")}! Install the JPEXS Decompiler - it is required to build Scaleform UI.
                If the decompiler is installed and is not being detected, you can set CustomFFDecPath in your build settings. This is a fatal error.
                """, customPrefix: LogCategory);
            Environment.Exit(1);
        }

        ffdecCliPath = cliPath;
        return ffdecCliPath;
    }

    /// <summary>
    /// Compiles the Scaleform XML exports for a package into SWF, updates the scripts, and outputs into that package's BaseDelta PropertyUpdate folder
    /// </summary>
    /// <param name="packageName">Package whose Scaleform sources to build, e.g. Startup</param>
    public static void Build(string packageName)
    {
        var sourcePackageDir = Path.Combine(MilanShared.PipelineRoot, "Scaleform", "Packages", packageName);
        var builtSwfDir = new DirectoryInfo(Path.Combine(OutputDir, packageName, "PropertyUpdate"));

        // Built SWFs are generated (and gitignored) - clear them so one whose XML was removed or renamed doesn't keep shipping
        if (builtSwfDir.Exists)
        {
            foreach (var staleSwf in builtSwfDir.GetFiles("*.swf"))
            {
                staleSwf.Delete();
            }
        }

        if (!Directory.Exists(sourcePackageDir))
            return;

        foreach (var sourceXmlPath in Directory.GetFiles(sourcePackageDir, "*.xml", SearchOption.AllDirectories))
        {
            var swfName = Path.GetFileNameWithoutExtension(sourceXmlPath);
            var swfDir = Directory.GetParent(sourceXmlPath);
            builtSwfDir.Create();
            var builtSwfPath = Path.Combine(builtSwfDir.FullName, $"{swfName}.swf");
            Xml2Swf(sourceXmlPath, builtSwfPath);
            foreach (var scriptPath in swfDir.GetFiles("*.as"))
            {
                SwfReplaceScript(builtSwfPath, scriptPath.FullName);
            }
        }
    }

    /// <summary>
    /// Builds GUI donor packages
    /// </summary>
    public static void BuildDonors()
    {
        MilanLog.Information("Building GUI donors", customPrefix: LogCategory);
        var sourceDonorDir = Path.Combine(MilanShared.PipelineRoot, "Scaleform", "Donors");
        var builtSwfDir = new DirectoryInfo(Path.Combine(DonorOutputDir, "Scaleform"));
        builtSwfDir.Create();

        // Built SWFs are generated (and gitignored) - clear them so one whose XML was removed or renamed doesn't keep shipping
        if (builtSwfDir.Exists)
        {
            foreach (var staleSwf in builtSwfDir.GetFiles("*.swf"))
            {
                staleSwf.Delete();
            }
        }

        if (!Directory.Exists(sourceDonorDir))
        {
            MilanLog.Fatal($"{sourceDonorDir} does not exist...\nThis is a fatal error.", customPrefix: "UI-Donors");
            Environment.Exit(1);
        }

        foreach (var sourceXmlPath in Directory.GetFiles(sourceDonorDir, "*.xml", SearchOption.AllDirectories))
        {
            var swfName = Path.GetFileNameWithoutExtension(sourceXmlPath);
            var swfDir = Directory.GetParent(sourceXmlPath);
            var packageExportName = swfName.Split('.')[0];
            var movieName = swfName.Split('.')[1];
            var builtSwfPath = Path.Combine(builtSwfDir.FullName, $"{swfName}.swf");
            Xml2Swf(sourceXmlPath, builtSwfPath);
            foreach (var scriptPath in swfDir.GetFiles("*.as"))
            {
                SwfReplaceScript(builtSwfPath, scriptPath.FullName);
            }

            MEPackageHandler.CreateAndSavePackage(Path.Combine(DonorOutputDir, $"{swfName}.pcc"), MEGame.LE3);
            using var pkg = MEPackageHandler.OpenMEPackage(Path.Combine(DonorOutputDir, $"{swfName}.pcc"));
            var pkgExport = pkg.CreatePackageExport(packageExportName);
            pkgExport.PackageGUID = Utilities.GenerateNewPackageGuid(packageExportName);
            var movie = pkg.CreateExport(movieName, "GFxMovieInfo", pkgExport, indexed: false);
            var swfBytes = File.ReadAllBytes(builtSwfPath);
            var swfData = new ImmutableByteArrayProperty(swfBytes, "RawData");
            movie.WriteProperty(swfData);

            var references = new ArrayProperty<ObjectProperty>("References");
            foreach (var texPath in new DirectoryInfo(Path.Combine(swfDir.FullName, "Textures")).GetFiles("*.png").OrderBy(f => f.Name))
            {
                string texName;
                if (texPath.Name.Contains('-'))
                {
                    texName = Path.GetFileNameWithoutExtension(texPath.Name).Split('-')[1];
                }
                else
                {
                    texName = Path.GetFileNameWithoutExtension(texPath.Name);
                }

                var format = PixelFormat.ARGB;
                switch (Path.GetFileNameWithoutExtension((texPath.Name)).Split('-')[0].ToUpper())
                {
                    // Only a subset of formats is supported, can always expand if needed
                    case "UNKNOWN":
                    case "UNK":
                        format = PixelFormat.Unknown;
                        break;
                    case "ARGB":
                    case "A8R8G8B8":
                        format = PixelFormat.ARGB;
                        break;
                    case "DXT1":
                        format = PixelFormat.DXT1;
                        break;
                    case "DXT3":
                        format = PixelFormat.DXT3;
                        break;
                    case "DXT5":
                        format = PixelFormat.DXT5;
                        break;
                    case "BC5":
                        format = PixelFormat.BC5;
                        break;
                    case "BC7":
                        format = PixelFormat.BC7;
                        break;
                }
                var tex = GUITextureImporter.AddGUITexture(pkg, pkgExport, texName, texPath.FullName, format);
                references.Add(tex);
            }
            movie.WriteProperty(references);
            movie.WriteProperty(new BoolProperty(true, "bUsesFontlib"));
            pkg.Save();
        }
        // Cleanup build folder
        builtSwfDir.Delete(true);
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
        RunFFDec($"convert {Path.GetFileName(inputXmlPath)} to SWF", "-xml2swf", inputXmlPath, outputSwfPath);
    }

    /// <summary>
    /// Replaces script in SWF file
    /// </summary>
    /// <param name="swfPath"></param>
    /// <param name="scriptPath">Name of the script file has to match the internal path of the SWF</param>
    private static void SwfReplaceScript(string swfPath, string scriptPath)
    {
        MilanLog.Information($"Replacing {Path.GetFileNameWithoutExtension(scriptPath)} in {Path.GetFileName(swfPath)}", customPrefix: LogCategory);
        var internalScriptPath = '\\' + Path.GetFileNameWithoutExtension(scriptPath).Replace(".", @"\");
        RunFFDec($"replace {internalScriptPath} in {Path.GetFileName(swfPath)}", "-replace", swfPath, swfPath, internalScriptPath, scriptPath); // overriding same file
    }

    /// <summary>
    /// Runs ffdec-cli with the given arguments. A failure aborts the build - ffdec leaves the SWF without the
    /// change (e.g. the script compile error case), which would otherwise ship silently.
    /// </summary>
    /// <param name="description">What this call does, for the failure message</param>
    private static void RunFFDec(string description, params string[] arguments)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = GetFFDecCliPath(),
            CreateNoWindow = true,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            WindowStyle = ProcessWindowStyle.Hidden
        };
        foreach (var argument in arguments)
        {
            startInfo.ArgumentList.Add(argument);
        }

        using var exeProcess = Process.Start(startInfo);
        if (exeProcess == null)
        {
            MilanLog.Fatal($"Failed to start ffdec-cli to {description} - this is a fatal error.", customPrefix: LogCategory);
            Environment.Exit(1);
        }

        // Drain both pipes while it runs - waiting first can deadlock once ffdec fills a pipe buffer
        var stdout = exeProcess.StandardOutput.ReadToEndAsync();
        var stderr = exeProcess.StandardError.ReadToEndAsync();
        exeProcess.WaitForExit();
        var output = (stdout.Result + stderr.Result).Trim();

        if (exeProcess.ExitCode != 0)
        {
            MilanLog.Fatal($"ffdec-cli failed to {description} (exit code {exeProcess.ExitCode}) - this is a fatal error. Output:\n{output}", customPrefix: LogCategory);
            Environment.Exit(1);
        }
    }
}
