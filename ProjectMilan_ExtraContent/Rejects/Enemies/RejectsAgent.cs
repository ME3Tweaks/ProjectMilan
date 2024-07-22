using LegendaryExplorerCore.Packages;
using ProjectMilanCore;

namespace ProjectMilan_ExtraContent.Rejects.Enemies
{
    // Changes:
    // - Change mesh for theming, because people hate this person.
    // - Remove plot armor bullshit
    // - Make sync attack only able to be used once
    internal class RejectsAgent
    {
        public static void PrePort(RejectsPipeline.RejectVars vars, IMEPackage package)
        {

            var archetype = package.FindExport("char_enemies.Archetypes.Cerberus.KaiLeng");
            var pawnClass = package.FindExport($"{MilanPackages.SFXGameContentMilan}.SFXPawn_Agent");
            RejectsShared.ChangeoverArchetype(archetype, pawnClass);
        }
    }
}
