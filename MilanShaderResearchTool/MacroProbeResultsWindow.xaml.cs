namespace MilanShaderResearchTool
{
    public partial class MacroProbeResultsWindow : System.Windows.Window
    {
        public MacroProbeResultsWindow(string targetMd5, List<MacroProbeResult> results)
        {
            InitializeComponent();

            TargetHashText.Text = $"Target MD5: {targetMd5}";
            int matched = results.Count(r => r.Matched || r.MatchedPreferFlow);
            int failed = results.Count(r => !r.Compiled && !r.CompiledPreferFlow);
            int matchedPreferOnly = results.Count(r => !r.Matched && r.MatchedPreferFlow);
            SummaryText.Text = $"{results.Count} macros probed  |  {matched} matched  |  {matchedPreferOnly} matched only with PreferFlow |  {failed} compile errors";

            ResultsGrid.ItemsSource = results;
        }
    }
}
