using System.Configuration;
using System.Data;
using System.Windows;
using LegendaryExplorerCore;

namespace MilanShaderResearchTool
{
    /// <summary>
    /// Interaction logic for App.xaml
    /// </summary>
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);
            try
            {
                LegendaryExplorerCoreLib.InitLib(TaskScheduler.FromCurrentSynchronizationContext(), objectDBsToLoad: []);
            }
            catch
            {
                // LEC initialization failed — game path detection may not work
            }
        }
    }

}
