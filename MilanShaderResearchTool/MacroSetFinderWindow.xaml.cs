using Microsoft.Win32;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Threading;

namespace MilanShaderResearchTool;

/// <summary>
/// Progress window for the automated macro set finder.
/// Shows per-shader progress, results grid, and log output.
/// </summary>
public partial class MacroSetFinderWindow : Window
{
    private readonly MacroSetFinder.CompileShaderDelegate _compileShader;
    private readonly string _includesDirectory;
    private readonly MacroSetFinder.GetReferenceBytecodeDelegate _getReferenceBytecode;

    private CancellationTokenSource? _cts;
    private readonly ObservableCollection<ShaderMacroSearchResult> _results = [];
    private readonly Stopwatch _elapsed = new();
    private DispatcherTimer? _elapsedTimer;
    private bool _autoScrollResults = true;
    private int _attemptedCount;
    private int _matchedCount;
    private int _baseMatchCount;
    private int _adjustedMatchCount;

    /// <summary>
    /// Creates the macro set finder window.
    /// </summary>
    /// <param name="compileShader">Delegate to compile a shader (wraps the P/Invoke call).</param>
    /// <param name="includesDirectory">Path to the shader includes directory.</param>
    /// <param name="getReferenceBytecode">Delegate that returns reference bytecode for comparison.</param>
    public MacroSetFinderWindow(
        MacroSetFinder.CompileShaderDelegate compileShader,
        string includesDirectory,
        MacroSetFinder.GetReferenceBytecodeDelegate getReferenceBytecode)
    {
        InitializeComponent();

        _compileShader = compileShader;
        _includesDirectory = includesDirectory;
        _getReferenceBytecode = getReferenceBytecode;

        ResultsGrid.ItemsSource = _results;
        ResultsGrid.AddHandler(ScrollViewer.ScrollChangedEvent, new ScrollChangedEventHandler(OnResultsGridScrollChanged));

        DebugPackageFolderBox.Text = @"E:\Decooked\DebugPackages\LE3\EngineDebugMaterials\ShadedLevelColorationLitMaterial";
        OutputJsonBox.Text = @"E:\Decooked\Autofind\macro_search_results.json";
    }

    private void BrowseFolder_Click(object sender, RoutedEventArgs e)
    {
        var dlg = new OpenFolderDialog { Title = "Select Debug Package Folder" };
        if (dlg.ShowDialog() == true)
            DebugPackageFolderBox.Text = dlg.FolderName;
    }

    private void BrowseOutput_Click(object sender, RoutedEventArgs e)
    {
        var dlg = new SaveFileDialog
        {
            Filter = "JSON Files (*.json)|*.json|All Files|*.*",
            Title = "Save Results JSON",
            FileName = "macro_search_results.json"
        };
        if (dlg.ShowDialog() == true)
            OutputJsonBox.Text = dlg.FileName;
    }

    private async void Start_Click(object sender, RoutedEventArgs e)
    {
        var folder = DebugPackageFolderBox.Text.Trim();
        if (string.IsNullOrEmpty(folder) || !Directory.Exists(folder))
        {
            AppendLog("ERROR: Debug package folder not found.");
            return;
        }

        var outputPath = OutputJsonBox.Text.Trim();
        if (string.IsNullOrEmpty(outputPath))
        {
            outputPath = Path.Combine(folder, "macro_search_results.json");
            OutputJsonBox.Text = outputPath;
        }

        var outputDir = Path.GetDirectoryName(outputPath);
        if (!string.IsNullOrEmpty(outputDir))
            Directory.CreateDirectory(outputDir);

        StartButton.IsEnabled = false;
        CancelButton.IsEnabled = true;
        _results.Clear();
        _attemptedCount = 0;
        _matchedCount = 0;
        _baseMatchCount = 0;
        _adjustedMatchCount = 0;
        MatchRateText.Text = "";
        AdjustedStatsText.Text = "";

        _cts = new CancellationTokenSource();
        var token = _cts.Token;

        _elapsed.Restart();
        _elapsedTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(500) };
        _elapsedTimer.Tick += (_, _) => ElapsedTimeText.Text = $"Elapsed: {_elapsed.Elapsed:hh\\:mm\\:ss}";
        _elapsedTimer.Start();

        var progress = new Progress<MacroSetFinderProgress>(OnProgress);
        var finder = new MacroSetFinder(_compileShader, _includesDirectory);

        try
        {
            AppendLog($"Starting macro set search in: {folder}");
            var onlyFailed = OnlyFailedCompilationsCheckBox.IsChecked == true;
            var results = await finder.FindAllMacroSetsAsync(folder, _getReferenceBytecode, progress, token, onlyFailed);

            _elapsed.Stop();
            _elapsedTimer.Stop();

            int matched = results.Count(r => r.Found);
            int baseMatched = results.Count(r => r.Found && r.SearchPhase == "Phase 0 (Base)");
            int adjustedMatched = matched - baseMatched;
            SummaryText.Text = $"Complete: {matched}/{results.Count} shaders matched (Base: {baseMatched}, Adjusted: {adjustedMatched})";
            AppendLog($"Search complete. {matched}/{results.Count} matched (Base: {baseMatched}, Adjusted: {adjustedMatched}). Total time: {_elapsed.Elapsed:hh\\:mm\\:ss}");

            // Save results
            try
            {
                MacroSetFinder.SaveResultsToJson(results, outputPath);
                AppendLog($"Results saved to: {outputPath}");
            }
            catch (Exception ex)
            {
                AppendLog($"ERROR saving results: {ex.Message}");
            }
        }
        catch (OperationCanceledException)
        {
            AppendLog("Search cancelled by user.");
            SummaryText.Text = "Cancelled";
        }
        catch (Exception ex)
        {
            AppendLog($"ERROR: {ex.Message}");
            SummaryText.Text = "Error";
        }
        finally
        {
            _elapsed.Stop();
            _elapsedTimer?.Stop();
            ElapsedTimeText.Text = $"Elapsed: {_elapsed.Elapsed:hh\\:mm\\:ss}";
            StartButton.IsEnabled = true;
            CancelButton.IsEnabled = false;
            _cts?.Dispose();
            _cts = null;
        }
    }

    private void Cancel_Click(object sender, RoutedEventArgs e)
    {
        _cts?.Cancel();
        CancelButton.IsEnabled = false;
        AppendLog("Cancellation requested...");
    }

    private void OnProgress(MacroSetFinderProgress p)
    {
        OverallProgressText.Text = $"{p.CompletedShaders}/{p.TotalShaders} shaders processed";
        if (p.TotalShaders > 0)
            OverallProgressBar.Value = (double)p.CompletedShaders / p.TotalShaders * 100;
        CurrentPhaseText.Text = $"{p.CurrentShader} — {p.CurrentPhase}";

        AppendLog(p.Message);

        if (p.Result != null)
        {
            _attemptedCount++;
            if (p.Result.Found)
            {
                _matchedCount++;
                if (p.Result.SearchPhase == "Phase 0 (Base)")
                {
                    _baseMatchCount++;
                }
                else
                {
                    _adjustedMatchCount++;
                }
            }

            MatchRateText.Text = $"Matched: {_matchedCount}/{_attemptedCount} ({(double)_matchedCount / _attemptedCount:P0})";
            AdjustedStatsText.Text = $"(Base: {_baseMatchCount}, Adjusted: {_adjustedMatchCount})";

            _results.Add(p.Result);
            if (_autoScrollResults)
                ResultsGrid.ScrollIntoView(_results[^1]);
        }
    }

    private void OnResultsGridScrollChanged(object sender, ScrollChangedEventArgs e)
    {
        // ExtentHeightChange == 0 means the content size didn't change — this is a user-initiated scroll
        if (e.ExtentHeightChange == 0 && e.OriginalSource is ScrollViewer sv)
            _autoScrollResults = sv.VerticalOffset >= sv.ScrollableHeight;
    }

    private void OpenInResearchTool_Click(object sender, RoutedEventArgs e)
    {
        OpenSelectedResultInMainWindow();
    }

    private void ResultsGrid_MouseDoubleClick(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        OpenSelectedResultInMainWindow();
    }

    private void OpenSelectedResultInMainWindow()
    {
        if (ResultsGrid.SelectedItem is not ShaderMacroSearchResult result)
            return;

        if (string.IsNullOrEmpty(result.JsonPath) || !File.Exists(result.JsonPath))
        {
            AppendLog($"Debug package not found: {result.JsonPath}");
            return;
        }

        if (Owner is MainWindow mainWindow)
        {
            _ = mainWindow.OpenDebugPackageWithExpected(
                result.JsonPath,
                string.IsNullOrEmpty(result.ReferenceDecompilation) ? null : result.ReferenceDecompilation,
                string.IsNullOrEmpty(result.ReferenceHash) ? null : result.ReferenceHash);
        }
    }

    private void AppendLog(string text)
    {
        LogBox.AppendText(text + Environment.NewLine);
        LogBox.ScrollToEnd();
    }
}
