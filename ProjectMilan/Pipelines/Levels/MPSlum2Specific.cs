using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;

namespace ProjectMilan.Pipelines.Levels;

public sealed class MPSlum2Specific : LevelSpecificFixesBase
{
    /// <summary>
    /// Fixes the car mesh using wrong material and being pink
    /// </summary>
    /// <param name="pipeline"></param>
    public override void PostCorrect(LevelSpecificPipeline pipeline)
    {
        foreach (var package in pipeline.LE3Packages.Values)
        {
            var car = package.FindExport("biot_humanslumACID.SLUM_ACID_CAR2");
            if (car == null)
            {
                // Not in this level
                continue;
            }

            // Use new Milan parameter that is baked into MIC
            var values = car.GetProperty<ArrayProperty<StructProperty>>("ScalarParameterValues") ?? new ArrayProperty<StructProperty>("ScalarParameterValues");
            var tint = values.FirstOrDefault(v => v.GetProp<NameProperty>("ParameterName")?.Value.Name == "Milan_KeepDiffuseTint");
            if (tint == null)
            {
                // Add tint
                values.Add(new StructProperty("ScalarParameterValue", new PropertyCollection
                {
                    new NameProperty("Milan_KeepDiffuseTint", "ParameterName"),
                    new FloatProperty(1f, "ParameterValue")
                }));
            }
            else
            {
                tint.Properties.AddOrReplaceProp(new FloatProperty(1f, "ParameterValue"));
            }
            car.WriteProperty(values);
        }
    }
}
