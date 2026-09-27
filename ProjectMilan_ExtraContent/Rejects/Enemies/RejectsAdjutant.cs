using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Packages;
using ProjectMilanCore;

namespace ProjectMilan_ExtraContent.Rejects.Enemies
{
    internal class RejectsAdjutant
    {
        // Make less annoying.
        // Fix off-host issues.
        public static void PrePort(RejectsPipeline.RejectVars vars, IMEPackage package)
        {
            //var archetype = package.FindExport("Char_Omega_Enemies.Archetypes.Adjutant_Combat");
            //var pawnClass = package.FindExport($"{MilanPackages.SFXGameContentMilan}.SFXPawn_AdjutantMP");
            //RejectsShared.ChangeoverArchetype(archetype, pawnClass);
        }
    }
}
