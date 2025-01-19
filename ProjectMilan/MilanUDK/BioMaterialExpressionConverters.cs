using System.Globalization;
using System.Runtime.InteropServices;
using System.Text;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;

namespace ProjectMilan.MilanUDK
{
    public static class BioMaterialExpressionConverters
    {
        public static BioMaterialExpressionBase GetConverter(ExportEntry exp)
        {
            // May need to look at decomp to figure out default values. Some don't work without expressions, others do.
            switch (exp.ClassName)
            {
                case "BioMaterialExpressionAnsioSpec":
                    return new BioMaterialExpressionAnisoSpec(exp);
                case "BioMaterialExpressionBlinnSpec":
                    return new BioMaterialExpressionBlinnSpec(exp);
                case "BioMaterialExpressionEffectMatBase":
                    return null; //return new BioMaterialExpressionEffectMatBase(exp);
                case "BioMaterialExpressionFresnel":
                    return new BioMaterialExpressionFresnel(exp);
                case "BioMaterialExpressionKeyedFlipbook":
                    return new BioMaterialExpressionKeyedFlipbook(exp);
                case "BioMaterialExpressionPhongSpec":
                    return new BioMaterialExpressionPhongSpec(exp);
                case "BioMaterialExpressionSpecPower":
                    return new BioMaterialExpressionSpecPower(exp);
                case "BioMaterialExpressionWound":
                    return null; //new BioMaterialExpressionWound(exp);

                default:
                    return null;
            }
        }
    }

    // Only verified on LE3
    public class BioMaterialExpressionFresnel(ExportEntry sourceExport) : BioMaterialExpressionBase(sourceExport)
    {
        protected override string GetHLSLCode(PropertyCollection originalProps)
        {
            // Properties
            var inverted = originalProps.GetProp<BoolProperty>("Inverted")?.Value ?? false;
            var power = originalProps.GetProp<FloatProperty>("Power")?.Value ?? 1f;

            // HLSL
            StringBuilder sb = new StringBuilder();
            sb.AppendLine(@"float local = max( 0.0, min( 1.0, dot( float3(0.00000000,0.00000000,1.00000000), Normal ) ) );");
            if (inverted)
            {
                sb.AppendLine(@"local = 1-local;");
            }

            sb.AppendLine($@"local = pow(local, {power.ToString(CultureInfo.InvariantCulture)});");
            sb.AppendLine(@"return local;");

            // Result
            return sb.ToString();
        }
        protected override void AddCustomInputs(ArrayProperty<StructProperty> inputsArray, PropertyCollection originalProperties)
        {
            AddCustomInput(inputsArray, "Normal", originalProperties.GetProp<StructProperty>("Normal"));
        }
    }

    public class BioMaterialExpressionKeyedFlipbook(ExportEntry sourceExport) : BioMaterialExpressionBase(sourceExport)
    {
        protected override string GetHLSLCode(PropertyCollection originalProps)
        {
            // Properties
            var flipTexRows = originalProps.GetProp<IntProperty>("FlipTexRows")?.Value ?? 1;
            var flipTexCols = originalProps.GetProp<IntProperty>("FlipTexCols")?.Value ?? 1;

            var width = 1f / flipTexCols; // 0.333 for 3 cols
            var height = 1f / flipTexRows; // 0.500 for 2 rows
            var numCells = flipTexCols * flipTexRows;

            // HLSL
            StringBuilder sb = new StringBuilder();
            sb.AppendLine($@"float4 Local = tex2D(Texture2D_0,((float(Coord) * float2({width},{height})) + (float2({width},{height}) * float2(fmod(floor((float({numCells}) * float(Time))),float({flipTexCols})),floor((floor((float({numCells}) * float(Time))) / float({flipTexCols})))))));");
            sb.AppendLine(@"return local;");

            // Result
            return sb.ToString();
        }

        protected override void AddCustomInputs(ArrayProperty<StructProperty> inputsArray, PropertyCollection originalProps)
        {
            AddCustomInput(inputsArray, "Coord", originalProps.GetProp<StructProperty>("Coord"));
            AddCustomInput(inputsArray, "Time", originalProps.GetProp<StructProperty>("Time"));
        }
    }

    public class BioMaterialExpressionBlinnSpec(ExportEntry sourceExport) : BioMaterialExpressionBase(sourceExport)
    {
        protected override string GetHLSLCode(PropertyCollection originalProps)
        {
            // Properties

            // HLSL
            StringBuilder sb = new StringBuilder();

            // Unsure how masks are used in this.

            sb.AppendLine("float3 Local4 = normalize(Parameters.TangentLightVector + Parameters.TangentCameraVector);");
            sb.AppendLine("float3 Local5 = float3(float(SpecColor), float(SpecColor), float(SpecColor)) * pow(max(0.0, min(1.0, dot(float(Normal).rrr, Local4))), max(0.0001, float3(float(SpecPower), float(SpecPower), float(SpecPower))));");
            sb.AppendLine("float3 Local6 = (Local5 + UniformPixelVector_0.rgb);");
            sb.AppendLine("return Local6;");


            // Result
            return sb.ToString();
        }

        protected override void AddCustomInputs(ArrayProperty<StructProperty> inputsArray, PropertyCollection originalProps)
        {
            AddCustomInput(inputsArray, "Normal", originalProps.GetProp<StructProperty>("Normal"));
            AddCustomInput(inputsArray, "SpecColor", originalProps.GetProp<StructProperty>("SpecColor"));
            AddCustomInput(inputsArray, "SpecPower", originalProps.GetProp<StructProperty>("SpecPower"));
        }
    }

    public class BioMaterialExpressionAnisoSpec(ExportEntry sourceExport) : BioMaterialExpressionBase(sourceExport)
    {
        protected override string GetHLSLCode(PropertyCollection originalProps)
        {
            // Properties

            // HLSL
            StringBuilder sb = new StringBuilder();
            sb.AppendLine(@"float3 Local5 = (float(1.00000000) - UniformPixelVector_0.rgb)");
            sb.AppendLine(@"float3 Local6 = normalize(Parameters.TangentLightVector + Parameters.TangentCameraVector)");
            sb.AppendLine(@"float3 Local7 = (float3(float(SpecColor), float(SpecColor), float(SpecColor)) * pow(max(0.0, min(1.0, sqrt(1.0 - min(dot(float3(float(Direction), float(Direction), float(Direction)), Local6) * dot(float3(float(Direction), float(Direction), float(Direction)), Local6), 1.0)))), max(0.0001, float3(float(SpecPower), float(SpecPower), float(SpecPower)))));");
            sb.AppendLine(@"float3 Local8 = (Local7 * Local5);");
            sb.AppendLine(@"return Local8");

            // Result
            return sb.ToString();
        }

        protected override void AddCustomInputs(ArrayProperty<StructProperty> inputsArray, PropertyCollection originalProps)
        {
            AddCustomInput(inputsArray, "Direction", originalProps.GetProp<StructProperty>("Direction"));
            AddCustomInput(inputsArray, "SpecColor", originalProps.GetProp<StructProperty>("SpecColor"));
            AddCustomInput(inputsArray, "SpecPower", originalProps.GetProp<StructProperty>("SpecPower"));
        }
    }

    public class BioMaterialExpressionPhongSpec(ExportEntry sourceExport) : BioMaterialExpressionBase(sourceExport)
    {
        protected override string GetHLSLCode(PropertyCollection originalProps)
        {
            // Unsure how Masks affect this

            // Properties

            // HLSL
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("float3 Local17 = (float(1.00000000) - UniformPixelVector_0.rgb);");
            sb.AppendLine("float3 Local18 = float(SpecColor).rrr * pow(max(0.0, min(1.0, dot(Parameters.TangentCameraVector, normalize((2 * float(Normal).rrr * dot(Parameters.TangentLightVector, float(Normal).rrr) - Parameters.TangentLightVector))))), max(0.0001, float3(float(SpecPower), float(SpecPower), float(SpecPower))));");
            sb.AppendLine("float3 Local19 = (Local18 * Local17);");
            sb.AppendLine("return Local19;");

            // Result
            return sb.ToString();
        }

        protected override void AddCustomInputs(ArrayProperty<StructProperty> inputsArray, PropertyCollection originalProps)
        {
            AddCustomInput(inputsArray, "Normal", originalProps.GetProp<StructProperty>("Normal"));
            AddCustomInput(inputsArray, "SpecColor", originalProps.GetProp<StructProperty>("SpecColor"));
            AddCustomInput(inputsArray, "SpecPower", originalProps.GetProp<StructProperty>("SpecPower"));
        }
    }

    public class BioMaterialExpressionSpecPower(ExportEntry sourceExport) : BioMaterialExpressionBase(sourceExport)
    {
        protected override string GetHLSLCode(PropertyCollection originalProps)
        {
            // Unsure how Masks affect this
            // It might change the .r to others?


            // Properties

            // HLSL
            StringBuilder sb = new StringBuilder();
            sb.AppendLine("float Local19 = (float(Input).r * float(100.00000000));");
            sb.AppendLine("return Local19;");

            // Result
            return sb.ToString();
        }

        protected override void AddCustomInputs(ArrayProperty<StructProperty> inputsArray, PropertyCollection originalProps)
        {
            AddCustomInput(inputsArray, "Input", originalProps.GetProp<StructProperty>("Input"));
        }
    }


    public abstract class BioMaterialExpressionBase(ExportEntry sourceExport)
    {
        protected ExportEntry Export { get; } = sourceExport;
        protected abstract string GetHLSLCode(PropertyCollection originalProps);

        /// <summary>
        /// Generates the Default__ object for a class
        /// </summary>
        /// <param name="classEntry"></param>
        /// <returns></returns>
        private static IEntry GetDefaults(IEntry classEntry)
        {
            if (classEntry.Parent == null)
                return classEntry.FileRef.GetEntryOrAddImport($"Default__{classEntry.ObjectName.Instanced}", classEntry.ObjectName.Instanced, classEntry.FileRef.FileNameNoExtension);
            string parentPath = classEntry.ParentInstancedFullPath;
            return classEntry.FileRef.GetEntryOrAddImport($"{parentPath}.Default__{classEntry.ObjectName.Instanced}", classEntry.ObjectName.Instanced, classEntry.ParentName);
        }

        /// <summary>
        /// Override to provide custom inputs.
        /// </summary>
        /// <param name="inputArray"></param>
        protected virtual void AddCustomInputs(ArrayProperty<StructProperty> inputArray, PropertyCollection originalProperties) { }

        public ExportEntry ConvertExpression(ExportEntry parent, RelinkerOptionsPackage rop)
        {
            // Generate properties
            PropertyCollection generatingProps = new PropertyCollection();
            PropertyCollection originalProps = Export.GetProperties();

            // Add our code
            generatingProps.AddOrReplaceProp(new StrProperty(GetHLSLCode(originalProps), "Code"));

            // Inputs
            var inputsArray = new ArrayProperty<StructProperty>("Inputs");
            AddCustomInputs(inputsArray, originalProps);
            generatingProps.AddOrReplaceProp(inputsArray);

            // OutputType
            // NOT CHANGED.

            var classObj = EntryImporter.EnsureClassIsInFile(parent.FileRef, "MaterialExpressionCustom", rop);
            ExportEntry exp = new ExportEntry(parent.FileRef, parent, parent.FileRef.GetNextIndexedName("MaterialExpressionCustom"), properties: generatingProps)
            {
                Class = classObj,
                Archetype = GetDefaults(classObj),
            };

            parent.FileRef.AddExport(exp);

            return exp;
        }

        /// <summary>
        /// Adds a custom input based on the original input. The reference copied over is from the original package; it will be relinked later.
        /// </summary>
        /// <param name="inputsArray"></param>
        /// <param name="normal"></param>
        /// <param name="normalInput"></param>
        protected void AddCustomInput(ArrayProperty<StructProperty> inputsArray, string inputName, StructProperty originalStruct)
        {
            PropertyCollection pc = new PropertyCollection();
            pc.Add(new StrProperty(inputName, "InputName"));

            if (originalStruct != null)
            {
                // I don't think this will break anything... we don't use this later
                originalStruct.Name = "Input";
                pc.Add(originalStruct); // Add the original struct - the reference should work as it will relink
            }
            else
            {
                pc.Add(new StructProperty("ExpressionInput", false, new ObjectProperty(0, "Expression")) { Name = "Input" });
            }

            inputsArray.Add(new StructProperty("CustomInput", pc, "Inputs"));
        }
    }
}
