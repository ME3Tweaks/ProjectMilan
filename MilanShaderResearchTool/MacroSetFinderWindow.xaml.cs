using Microsoft.Win32;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Data;
using System.Windows.Media;
using System.Windows.Threading;

namespace MilanShaderResearchTool;

/// <summary>
/// Progress window for the automated macro set finder.
/// Shows per-shader progress, results grid, and log output.
/// </summary>
public partial class MacroSetFinderWindow : Window
{
    private DataGridCell? _rightClickedCell;
    private readonly MacroSetFinder.CompileShaderDelegate _compileShader;
    private readonly string _includesDirectory;
    private readonly MacroSetFinder.GetReferenceBytecodeDelegate _getReferenceBytecode;

    private CancellationTokenSource? _cts;
    private CancellationTokenSource? _extensiveSearchCts;
    private readonly ObservableCollection<ShaderMacroSearchResult> _results = [];
    private readonly Stopwatch _elapsed = new();
    private DispatcherTimer? _elapsedTimer;
    private bool _autoScrollResults = true;
    private bool _filterNoActions = false;
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

        DebugPackageFolderBox.Text = @"E:\Decooked\DebugPackages\LE3\EngineDebugMaterials";
        OutputJsonBox.Text = @"E:\Decooked\Autofind\macro_search_results.json";
    }

    private void ResultsGrid_PreviewMouseRightButtonDown(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        // Find the DataGridCell that was right-clicked and store it for the context menu actions
        var dep = (DependencyObject)e.OriginalSource;
        while (dep != null && dep is not DataGridCell && dep is not DataGridColumnHeader)
            dep = VisualTreeHelper.GetParent(dep);

        if (dep is DataGridCell cell)
        {
            _rightClickedCell = cell;

            // Select the row under the clicked cell
            var row = ItemsControl.ContainerFromElement(ResultsGrid, cell) as DataGridRow;
            if (row != null)
                ResultsGrid.SelectedItem = row.Item;
        }
        else
        {
            _rightClickedCell = null;
        }
    }

    private void CopyCell_Click(object sender, RoutedEventArgs e)
    {
        if (_rightClickedCell == null)
            return;

        // Try to obtain the row/item for the clicked cell
        var row = ItemsControl.ContainerFromElement(ResultsGrid, _rightClickedCell) as DataGridRow;
        string? text = null;

        if (row != null)
        {
            var column = _rightClickedCell.Column;

            // If it's a bound column, try to read the binding path and get the value from the data item
            if (column is DataGridBoundColumn boundCol && boundCol.Binding is System.Windows.Data.Binding binding && !string.IsNullOrEmpty(binding.Path?.Path))
            {
                var path = binding.Path.Path;
                var item = row.Item;
                try
                {
                    text = GetPropertyPathValueAsString(item, path);
                }
                catch
                {
                    text = null;
                }
            }

            // Fallback: try to get the visual content (TextBlock / TextBox)
            if (text == null)
            {
                var content = column.GetCellContent(row);
                if (content is TextBlock tb)
                    text = tb.Text;
                else if (content is TextBox tbox)
                    text = tbox.Text;
                else if (content != null)
                    text = content.ToString();
            }
        }

        if (!string.IsNullOrEmpty(text))
        {
            try
            {
                Clipboard.SetText(text);
            }
            catch
            {
                // ignore clipboard exceptions
            }
        }
    }

    private static string? GetPropertyPathValueAsString(object item, string path)
    {
        if (item == null || string.IsNullOrEmpty(path))
            return null;

        object? current = item;
        var parts = path.Split('.');
        foreach (var part in parts)
        {
            if (current == null) return null;
            var type = current.GetType();
            var prop = type.GetProperty(part);
            if (prop != null)
            {
                current = prop.GetValue(current);
                continue;
            }

            // Try indexer-like Count for collections
            var field = type.GetField(part);
            if (field != null)
            {
                current = field.GetValue(current);
                continue;
            }

            return null;
        }

        return current?.ToString();
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

        await RunSearchAsync([folder]);
    }

    private async void StartSearchPackage_Click(object sender, RoutedEventArgs e)
    {
        var packageFolder = DebugPackageFolderBox.Text.Trim();
        if (string.IsNullOrEmpty(packageFolder) || !Directory.Exists(packageFolder))
        {
            AppendLog("ERROR: Package folder not found.");
            return;
        }

        var materialFolders = Directory.GetDirectories(packageFolder);
        if (materialFolders.Length == 0)
        {
            AppendLog("ERROR: No material subfolders found in the selected folder.");
            return;
        }

        AppendLog($"Found {materialFolders.Length} material folder(s) to scan.");
        await RunSearchAsync(materialFolders);
    }

    private async Task RunSearchAsync(string[] materialFolders)
    {
        var outputPath = OutputJsonBox.Text.Trim();
        if (string.IsNullOrEmpty(outputPath))
        {
            outputPath = Path.Combine(materialFolders[0], "macro_search_results.json");
            OutputJsonBox.Text = outputPath;
        }

        var outputDir = Path.GetDirectoryName(outputPath);
        if (!string.IsNullOrEmpty(outputDir))
            Directory.CreateDirectory(outputDir);

        StartButton.IsEnabled = false;
        StartPackageButton.IsEnabled = false;
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
        var allResults = new List<ShaderMacroSearchResult>();

        try
        {
            var onlyFailed = OnlyFailedCompilationsCheckBox.IsChecked == true;

            for (int i = 0; i < materialFolders.Length; i++)
            {
                token.ThrowIfCancellationRequested();
                var folder = materialFolders[i];

                AppendLog(materialFolders.Length > 1
                    ? $"[{i + 1}/{materialFolders.Length}] Searching material: {Path.GetFileName(folder)}"
                    : $"Starting macro set search in: {folder}");

                var results = await finder.FindAllMacroSetsAsync(folder, _getReferenceBytecode, progress, token, onlyFailed);
                allResults.AddRange(results);
            }

            _elapsed.Stop();
            _elapsedTimer.Stop();

            int counted = allResults.Count(r => r.HasReferenceBytecode);
            int matched = allResults.Count(r => r.Found);
            int baseMatched = allResults.Count(r => r.Found && r.SearchPhase == "Phase 0 (Base)");
            int adjustedMatched = matched - baseMatched;
            SummaryText.Text = $"Complete: {matched}/{counted} shaders matched (Base: {baseMatched}, Adjusted: {adjustedMatched})";
            AppendLog($"Search complete. {matched}/{counted} matched (Base: {baseMatched}, Adjusted: {adjustedMatched}). Total time: {_elapsed.Elapsed:hh\\:mm\\:ss}");

            try
            {
                MacroSetFinder.SaveResultsToJson(allResults, outputPath);
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
            StartPackageButton.IsEnabled = true;
            CancelButton.IsEnabled = false;
            _cts?.Dispose();
            _cts = null;
        }
    }

    private void Cancel_Click(object sender, RoutedEventArgs e)
    {
        _cts?.Cancel();
        _extensiveSearchCts?.Cancel();
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
            if (p.Result.HasReferenceBytecode)
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
            }

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

    private void ToggleFilterNoActions_Click(object sender, RoutedEventArgs e)
    {
        _filterNoActions = !_filterNoActions;
        var button = (Button)sender;

        var view = System.Windows.Data.CollectionViewSource.GetDefaultView(_results);
        if (_filterNoActions)
        {
            view.Filter = o => o is ShaderMacroSearchResult r && r.HasReferenceBytecode && r.SearchPhase != "Phase 0 (Base)";
            button.Background = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(0x1E, 0x4D, 0x1E));
            button.Foreground = System.Windows.Media.Brushes.LightGreen;
        }
        else
        {
            view.Filter = null;
            button.ClearValue(Button.BackgroundProperty);
            button.ClearValue(Button.ForegroundProperty);
        }
    }

    private void ContextMenu_Opened(object sender, RoutedEventArgs e)
    {
        if (sender is not ContextMenu menu) return;
        bool canExtensive = ResultsGrid.SelectedItem is ShaderMacroSearchResult r
            && !r.Found
            && _cts == null
            && _extensiveSearchCts == null;

        foreach (var item in menu.Items.OfType<MenuItem>())
        {
            if (item.Header is string h && h == "Perform Extensive Search")
            {
                item.IsEnabled = canExtensive;
                break;
            }
        }
    }

    private async void PerformExtensiveSearch_Click(object sender, RoutedEventArgs e)
    {
        if (ResultsGrid.SelectedItem is not ShaderMacroSearchResult target || target.Found)
            return;

        if (_cts != null || _extensiveSearchCts != null)
        {
            AppendLog("Cannot start extensive search while another search is running.");
            return;
        }

        var timeout = TimeSpan.FromMinutes(5);
        _extensiveSearchCts = new CancellationTokenSource();
        var token = _extensiveSearchCts.Token;

        StartButton.IsEnabled = false;
        StartPackageButton.IsEnabled = false;
        CancelButton.IsEnabled = true;

        OverallProgressBar.Value = 0;
        OverallProgressText.Text = $"Extensive search: {target.VertexFactoryName}/{target.ShaderTypeName}";
        CurrentPhaseText.Text = "Starting extensive search...";

        var startTime = DateTime.UtcNow;
        _elapsedTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(250) };
        _elapsedTimer.Tick += (_, _) =>
        {
            var elapsed = (DateTime.UtcNow - startTime).TotalSeconds;
            OverallProgressBar.Value = Math.Min(elapsed / timeout.TotalSeconds * 100.0, 100.0);
            ElapsedTimeText.Text = $"Extensive: {TimeSpan.FromSeconds(elapsed):mm\\:ss} / {timeout.TotalMinutes:F0}m";
        };
        _elapsedTimer.Start();

        AppendLog($"Starting extensive search for {target.VertexFactoryName}/{target.ShaderTypeName} (5 min timeout, unlimited iterations)...");

        try
        {
            var progress = new Progress<MacroSetFinderProgress>(p =>
            {
                CurrentPhaseText.Text = $"{p.CurrentShader} — {p.CurrentPhase}";
                AppendLog(p.Message);
            });

            var finder = new MacroSetFinder(_compileShader, _includesDirectory);
            var result = await finder.FindMacroSetForSingleShaderAsync(
                target.JsonPath, target.VertexFactoryName, target.ShaderTypeName,
                _getReferenceBytecode, progress, token, timeout);

            if (!result.Found)
            {
                result.Status = result.SearchPhase == "Timeout"
                    ? "Extensive Search: Timed out (5 minute limit)"
                    : result.SearchPhase == "Cancelled"
                        ? "Extensive Search: Cancelled"
                        : "Extensive Search: No matching macro set found";
                result.SearchPhase = result.SearchPhase == "Cancelled" ? "Cancelled" : "Exhausted (Extensive)";
            }

            var idx = _results.IndexOf(target);
            if (idx >= 0)
                _results[idx] = result;

            AppendLog(result.Found
                ? $"Extensive search matched: {result.Status}"
                : $"Extensive search finished: {result.Status}");
        }
        catch (OperationCanceledException)
        {
            AppendLog("Extensive search cancelled.");
        }
        catch (Exception ex)
        {
            AppendLog($"Extensive search error: {ex.Message}");
        }
        finally
        {
            _elapsedTimer?.Stop();
            _elapsedTimer = null;
            OverallProgressBar.Value = 0;
            OverallProgressText.Text = "Ready";
            CurrentPhaseText.Text = "";
            ElapsedTimeText.Text = "";
            StartButton.IsEnabled = true;
            StartPackageButton.IsEnabled = true;
            CancelButton.IsEnabled = false;
            _extensiveSearchCts?.Dispose();
            _extensiveSearchCts = null;
        }
    }

    private void AppendLog(string text)
    {
        LogBox.AppendText(text + Environment.NewLine);
        LogBox.ScrollToEnd();
    }
}
