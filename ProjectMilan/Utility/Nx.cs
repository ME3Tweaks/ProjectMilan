using System.Runtime.InteropServices;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;

namespace ProjectMilan.Utility
{

    internal class Nx
    {
        //[DllImport("AggGeomRecooker.dll")]
        //public static extern void RecookAggGeom();

        public static void InitNx()
        {
            // We probably need to use a wrapper
            MilanLog.Information("Loading PhysXCooking64.dll");
            NativeLibrary.Load(Path.Combine(LE3Directory.ExecutableFolder, "PhysXCooking64.dll"));
        }

        public static void RecookConvexMesh(ExportEntry brush, string logCategory)
        {
            MilanLog.Information($"  Recooking AggGeom for {brush.InstancedFullPath}", customPrefix: logCategory);
            var aggGeom = brush.GetProperty<StructProperty>("AggGeom");
     
            // Feed data to NxCooking and get the result
            byte[] newCachedData = new byte[0]; // Todo

            brush.WriteBinary(BrushComponent.Create());
        }
    }
}
