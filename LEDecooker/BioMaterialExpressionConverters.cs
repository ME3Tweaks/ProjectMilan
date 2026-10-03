using System.Diagnostics;
using System.Globalization;
using System.Runtime.CompilerServices;
using System.Text;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;

namespace LEDecooker
{
    /// <summary>
    /// Replaces BioWare's BioMaterialExpression* nodes, which UDK doesn't have, with stock UDK expressions
    /// that produce the same HLSL.
    ///
    /// The reference for every converter is the expression's Compile() and the Bio* methods on
    /// FHLSLMaterialTranslator in the LE3 executable (they are identical in LE1, which lacks only Wound).
    /// The HLSL below follows the translator's format strings, and each input keeps the default
    /// Compile() substitutes when it is unconnected. Defaults have to be inlined: a UDK Custom node
    /// fails to compile on any named input left unconnected.
    /// </summary>
    public static class BioMaterialExpressionConverters
    {
        public static BioMaterialExpressionBase GetConverter(ExportEntry exp)
        {
            switch (exp.ClassName)
            {
                case "BioMaterialExpressionAnisoSpec":
                    return new BioMaterialExpressionAnisoSpec(exp);
                case "BioMaterialExpressionBlinnSpec":
                    return new BioMaterialExpressionBlinnSpec(exp);
                case "BioMaterialExpressionDirt":
                    return new BioMaterialExpressionDirt(exp);
                case "BioMaterialExpressionEffectMatBaseProperty":
                    return new BioMaterialExpressionEffectMatBaseProperty(exp);
                case "BioMaterialExpressionFresnel":
                    return new BioMaterialExpressionFresnel(exp);
                case "BioMaterialExpressionKeyedFlipbook":
                    return new BioMaterialExpressionKeyedFlipbook(exp);
                case "BioMaterialExpressionPhongSpec":
                    return new BioMaterialExpressionPhongSpec(exp);
                case "BioMaterialExpressionSpecPower":
                    return new BioMaterialExpressionSpecPower(exp);
                case "BioMaterialExpressionWound":
                    return new BioMaterialExpressionWound(exp);
                case "BioMaterialExpressionEffectMatFractionEnabled":
                    return new BioMaterialExpressionEffectMatFractionEnabled(exp);
                case "BioMaterialExpressionSineSubtend":
                    return new BioMaterialExpressionSineSubtend(exp);
                case "BioMaterialExpressionHalfAngle":
                    return new BioMaterialExpressionHalfAngle(exp);
                default:
                    if (exp.ClassName.StartsWith("Bio"))
                        Debugger.Break();
                    return null;
            }
        }

        /// <summary>
        /// Nodes a converter has already relinked itself (see <see cref="BioMaterialExpressionBase.RelinkNow"/>).
        /// Their references point into the destination package, so the relinker's later pass over them
        /// has to leave every reference alone.
        /// </summary>
        private static readonly ConditionalWeakTable<ExportEntry, object> PreRelinkedNodes = new();

        private static readonly object Marker = new();

        internal static void MarkPreRelinked(ExportEntry node) => PreRelinkedNodes.AddOrUpdate(node, Marker);

        /// <summary>True if <paramref name="relinkingExport"/>'s references are already destination references.</summary>
        public static bool IsPreRelinked(ExportEntry relinkingExport) => PreRelinkedNodes.TryGetValue(relinkingExport, out _);
    }

    /// <summary>
    /// Builds a UDK MaterialExpressionCustom's inputs while generating its code: a connected input
    /// becomes a Custom input, and an unconnected one is replaced by the default its LE3 Compile() uses.
    /// </summary>
    public sealed class CustomNodeBuilder(PropertyCollection sourceProps)
    {
        public ArrayProperty<StructProperty> Inputs { get; } = new("Inputs");

        public bool IsConnected(string propertyName) =>
            sourceProps.GetProp<StructProperty>(propertyName)?.GetProp<ObjectProperty>("Expression")?.Value is int v && v != 0;

        /// <summary>
        /// HLSL for the input: the Custom input cast to <paramref name="cast"/> (a UDK Custom input is
        /// declared with whatever width is connected to it), or <paramref name="defaultHlsl"/> when the
        /// input is unconnected. A null cast keeps the connected width.
        /// </summary>
        public string Input(string propertyName, string? cast, string defaultHlsl)
        {
            if (!IsConnected(propertyName))
                return defaultHlsl;

            AddInput(propertyName, sourceProps.GetProp<StructProperty>(propertyName));
            return cast == null ? propertyName : $"(({cast}){propertyName})";
        }

        /// <summary>
        /// An input LE3's Compile() requires. It is always added, so a source material missing it fails
        /// in UDK with "missing input", as it did in LE3.
        /// </summary>
        public string RequiredInput(string propertyName, string? cast)
        {
            AddInput(propertyName, sourceProps.GetProp<StructProperty>(propertyName));
            return cast == null ? propertyName : $"(({cast}){propertyName})";
        }

        /// <summary>Adds an input from a struct that isn't on the source expression under the same name.</summary>
        public string Input(string inputName, StructProperty expressionInput, string? cast)
        {
            AddInput(inputName, expressionInput);
            return cast == null ? inputName : $"(({cast}){inputName})";
        }

        /// <summary>
        /// Adds a custom input based on the original input. The reference copied over is from the
        /// original package; it is relinked with the node.
        /// </summary>
        private void AddInput(string inputName, StructProperty? originalStruct)
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

            Inputs.Add(new StructProperty("CustomInput", pc, "Inputs"));
        }
    }

    /// <summary>
    /// BlinnSpec/AnisoSpec's half vector - FHLSLMaterialTranslator::BioHalfAngle, which they call internally.
    /// </summary>
    internal static class BioHlsl
    {
        public const string HalfAngle = "normalize( Parameters.TangentLightVector + Parameters.TangentCameraVector )";

        // Compile() defaults: Constant3(0,0,1) for a missing normal/direction, Constant(1) for a missing
        // spec color/power. The translator coerces both to float3.
        public const string DefaultNormal = "float3(0.0, 0.0, 1.0)";
        public const string One3 = "float3(1.0, 1.0, 1.0)";

        public static string F(float value) => value.ToString("R", CultureInfo.InvariantCulture);
    }

    // FHLSLMaterialTranslator::BioFresnel: "max( 0.0, min( 1.0, dot( %s, %s ) ) )" of the normal and
    // CameraVector(), then "1.0 - %s" when Inverted, then "pow( %s, %f )" when |Power - 1| > 1e-4.
    public class BioMaterialExpressionFresnel(ExportEntry sourceExport) : BioMaterialExpressionBase(sourceExport)
    {
        protected override string GetHLSLCode(PropertyCollection originalProps, CustomNodeBuilder inputs)
        {
            var inverted = originalProps.GetProp<BoolProperty>("Inverted")?.Value ?? false;
            var power = originalProps.GetProp<FloatProperty>("Power")?.Value ?? 1f;
            var normal = inputs.Input("Normal", "float3", BioHlsl.DefaultNormal);

            var sb = new StringBuilder();
            sb.AppendLine($"float Fresnel = max( 0.0, min( 1.0, dot( {normal}, Parameters.TangentCameraVector ) ) );");
            if (inverted)
                sb.AppendLine("Fresnel = 1.0 - Fresnel;");
            if (Math.Abs(power - 1f) > 1e-4)
                sb.AppendLine($"Fresnel = pow( Fresnel, {power.ToString("F6", CultureInfo.InvariantCulture)} );");
            sb.AppendLine("return Fresnel;");
            return sb.ToString();
        }
    }

    // FHLSLMaterialTranslator::BioHalfAngle.
    public class BioMaterialExpressionHalfAngle(ExportEntry sourceExport) : BioMaterialExpressionBase(sourceExport)
    {
        protected override string GetReturnType() => "CMOT_Float3";

        protected override string GetHLSLCode(PropertyCollection originalProps, CustomNodeBuilder inputs) =>
            $"return {BioHlsl.HalfAngle};";
    }

    // FHLSLMaterialTranslator::BioBlinnSpec, every operand coerced to float3:
    // "%s * pow( max( 0.0, min( 1.0, dot( %s, %s ) ) ), max( 0.0001, %s ) )".
    public class BioMaterialExpressionBlinnSpec(ExportEntry sourceExport) : BioMaterialExpressionBase(sourceExport)
    {
        protected override string GetReturnType() => "CMOT_Float3";

        protected override string GetHLSLCode(PropertyCollection originalProps, CustomNodeBuilder inputs)
        {
            var normal = inputs.Input("Normal", "float3", BioHlsl.DefaultNormal);
            var specColor = inputs.Input("SpecColor", "float3", BioHlsl.One3);
            var specPower = inputs.Input("SpecPower", "float3", BioHlsl.One3);
            return $"return {specColor} * pow( max( 0.0, min( 1.0, dot( {normal}, {BioHlsl.HalfAngle} ) ) ), max( 0.0001, {specPower} ) );";
        }
    }

    // FHLSLMaterialTranslator::BioAnisoSpec, every operand coerced to float3:
    // "( %s * pow( max( 0.0, min( 1.0, sqrt( 1.0 - min(dot( %s, %s ) * dot( %s, %s ), 1.0) ) ) ), max( 0.0001, %s ) ) )".
    public class BioMaterialExpressionAnisoSpec(ExportEntry sourceExport) : BioMaterialExpressionBase(sourceExport)
    {
        protected override string GetReturnType() => "CMOT_Float3";

        protected override string GetHLSLCode(PropertyCollection originalProps, CustomNodeBuilder inputs)
        {
            var direction = inputs.Input("Direction", "float3", BioHlsl.DefaultNormal);
            var specColor = inputs.Input("SpecColor", "float3", BioHlsl.One3);
            var specPower = inputs.Input("SpecPower", "float3", BioHlsl.One3);

            var sb = new StringBuilder();
            sb.AppendLine($"float3 AnisoDirection = {direction};");
            sb.AppendLine($"float3 AnisoHalf = {BioHlsl.HalfAngle};");
            sb.AppendLine($"return ( {specColor} * pow( max( 0.0, min( 1.0, sqrt( 1.0 - min(dot( AnisoDirection, AnisoHalf ) * dot( AnisoDirection, AnisoHalf ), 1.0) ) ) ), max( 0.0001, {specPower} ) ) );");
            return sb.ToString();
        }
    }

    // FHLSLMaterialTranslator::BioPhongSpec, every operand coerced to float3:
    // "%s * pow( max( 0.0, min( 1.0, dot( Parameters.TangentCameraVector, normalize( ( 2 * %s * dot( Parameters.TangentLightVector, %s ) - Parameters.TangentLightVector ) ) ) ) ), max( 0.0001, %s ) )".
    public class BioMaterialExpressionPhongSpec(ExportEntry sourceExport) : BioMaterialExpressionBase(sourceExport)
    {
        protected override string GetReturnType() => "CMOT_Float3";

        protected override string GetHLSLCode(PropertyCollection originalProps, CustomNodeBuilder inputs)
        {
            var normal = inputs.Input("Normal", "float3", BioHlsl.DefaultNormal);
            var specColor = inputs.Input("SpecColor", "float3", BioHlsl.One3);
            var specPower = inputs.Input("SpecPower", "float3", BioHlsl.One3);

            var sb = new StringBuilder();
            sb.AppendLine($"float3 PhongNormal = {normal};");
            sb.AppendLine($"return {specColor} * pow( max( 0.0, min( 1.0, dot( Parameters.TangentCameraVector, normalize( ( 2 * PhongNormal * dot( Parameters.TangentLightVector, PhongNormal ) - Parameters.TangentLightVector ) ) ) ) ), max( 0.0001, {specPower} ) );");
            return sb.ToString();
        }
    }

    // FHLSLMaterialTranslator::BioSineSubtend, B coerced to A's type, result a scalar:
    // "sqrt( max( 0.0, min( 1.0, 1 - dot(%s,%s)*dot(%s,%s) ) ) )". Both inputs are required.
    public class BioMaterialExpressionSineSubtend(ExportEntry sourceExport) : BioMaterialExpressionBase(sourceExport)
    {
        protected override string GetHLSLCode(PropertyCollection originalProps, CustomNodeBuilder inputs)
        {
            var a = inputs.RequiredInput("A", null);
            var b = inputs.RequiredInput("B", null);
            return $"return sqrt( max( 0.0, min( 1.0, 1 - dot({a},{b})*dot({a},{b}) ) ) );";
        }
    }

    // FHLSLMaterialTranslator::BioWound: "GetWoundParameters%d(Parameters)", a float4 driven by the
    // game's wound system (NUM_WOUNDS). UDK has neither, so this is an unwounded surface. The zero
    // value is an assumption - LE3's GetWoundParameters itself isn't in the executable.
    public class BioMaterialExpressionWound(ExportEntry sourceExport) : BioMaterialExpressionBase(sourceExport)
    {
        protected override string GetReturnType() => "CMOT_Float4";

        protected override string GetHLSLCode(PropertyCollection originalProps, CustomNodeBuilder inputs) =>
            "return float4(0.0, 0.0, 0.0, 0.0);";
    }

    // Compile(): Lerp(Input.rgb, Input * TextureSample(GrimeTexParamName, TexCoord0), ScalarParameter(GrimeScaleParamName, 0)).
    // With the grime scale at its default of 0 that is Input.rgb. Nothing in UDK sets the scale, so
    // the grime texture sample is dropped.
    public class BioMaterialExpressionDirt(ExportEntry sourceExport) : BioMaterialExpressionBase(sourceExport)
    {
        protected override string GetReturnType() => "CMOT_Float3";

        protected override string GetHLSLCode(PropertyCollection originalProps, CustomNodeBuilder inputs) =>
            $"return {inputs.RequiredInput("Input", "float3")};";
    }

    // Compile(): ScalarParameter('FractionOfEffectEnabled', 0). The mesh component sets it at runtime
    // in game; in UDK it stays at its default.
    public class BioMaterialExpressionEffectMatFractionEnabled(ExportEntry sourceExport) : BioMaterialExpressionBase(sourceExport)
    {
        public override ExportEntry ConvertExpression(ExportEntry parent, RelinkerOptionsPackage rop)
        {
            var props = new PropertyCollection
            {
                new NameProperty("FractionOfEffectEnabled", "ParameterName"),
                new FloatProperty(0f, "DefaultValue"),
                CommonStructs.GuidProp(Guid.NewGuid(), "ExpressionGUID"),
            };
            return CreateNode(parent, "MaterialExpressionScalarParameter", props, rop);
        }
    }

    // Compile(): Mul(Input, Constant(100)). Built from native nodes rather than a Custom node so the
    // result keeps the input's width, as LE3's Mul does. Input is required.
    public class BioMaterialExpressionSpecPower(ExportEntry sourceExport) : BioMaterialExpressionBase(sourceExport)
    {
        public override ExportEntry ConvertExpression(ExportEntry parent, RelinkerOptionsPackage rop)
        {
            var constant = CreateNode(parent, "MaterialExpressionConstant", new PropertyCollection { new FloatProperty(100f, "R") }, rop);
            RelinkNow(constant, rop);

            var multiply = CreateNode(parent, "MaterialExpressionMultiply", new PropertyCollection
            {
                CopyInput(Export.GetProperties(), "Input", "A"),
                ExpressionInputTo(0, "B"),
            }, rop);
            RelinkNow(multiply, rop);
            SetInputExpression(multiply, "B", constant);
            return multiply;
        }
    }

    // Compile(): with Input set, CallExpression(Input) force-cast to the base property's type
    // (GetBasePropertyType). Without it, the property's default as a constant.
    public class BioMaterialExpressionEffectMatBaseProperty(ExportEntry sourceExport) : BioMaterialExpressionBase(sourceExport)
    {
        private string BaseProperty => Export.GetProperty<EnumProperty>("BaseProperty")?.Value.Name ?? "MP_EmissiveColor";

        protected override string GetReturnType() => BaseProperty switch
        {
            "MP_Opacity" or "MP_OpacityMask" or "MP_SpecularPower" or "MP_TMissionMask" => "CMOT_Float1",
            "MP_Distortion" => "CMOT_Float2",
            "MP_EmissiveColor" or "MP_TwoSidedLightingMask" or "MP_DiffuseColor" or "MP_SpecularColor"
                or "MP_Normal" or "MP_CustomLighting" or "MP_TMissionColor" => "CMOT_Float3",
            // LE3 has no type for these; with an input, its force-cast fails the compile. Without one
            // the default is a scalar 0.
            _ => Export.GetProperty<ObjectProperty>("Input")?.Value is int v && v != 0 ? "CMOT_Float3" : "CMOT_Float1",
        };

        protected override string GetHLSLCode(PropertyCollection originalProps, CustomNodeBuilder inputs)
        {
            var cast = GetReturnType() switch
            {
                "CMOT_Float1" => "float",
                "CMOT_Float2" => "float2",
                _ => "float3",
            };

            // Input is a bare expression pointer (output 0, no mask), not an ExpressionInput.
            var input = originalProps.GetProp<ObjectProperty>("Input");
            if (input != null && input.Value != 0)
                return $"return {inputs.Input("Input", ExpressionInputTo(input.Value, "Input"), cast)};";

            var constant = BaseProperty switch
            {
                "MP_EmissiveColor" or "MP_TwoSidedLightingMask" or "MP_DiffuseColor" or "MP_SpecularColor" or "MP_CustomLighting"
                    => "float3(0.0, 0.0, 0.0)",
                "MP_Opacity" or "MP_OpacityMask" => "1.0",
                "MP_Distortion" => "float2(0.0, 0.0)",
                "MP_SpecularPower" => "15.0",
                "MP_Normal" => "float3(0.0, 0.0, 1.0)",
                "MP_TMissionColor" => "float3(1.0, 1.0, 1.0)",
                _ => "0.0",
            };
            return $"return {constant};";
        }
    }

    // Compile(): TextureSample(FlipTex, Coord*Size + Size*float2(fmod(Frame, Cols), floor(Frame / Cols))),
    // with Size = (1/Cols, 1/Rows), Frame = floor(Cols*Rows*Time), and Coord defaulting to TexCoord 0.
    // Time and the texture are required. A Custom node can't sample the material's textures, so this
    // becomes a real TextureSample - which also has KeyedFlipbook's RGB/R/G/B/A outputs - fed by a
    // Custom node computing only the UV.
    public class BioMaterialExpressionKeyedFlipbook(ExportEntry sourceExport) : BioMaterialExpressionBase(sourceExport)
    {
        public override ExportEntry ConvertExpression(ExportEntry parent, RelinkerOptionsPackage rop)
        {
            var originalProps = Export.GetProperties();
            var rows = Math.Max(1, originalProps.GetProp<IntProperty>("FlipTexRows")?.Value ?? 1);
            var cols = Math.Max(1, originalProps.GetProp<IntProperty>("FlipTexCols")?.Value ?? 1);

            // An unconnected Coord is TexCoord 0. It has to come from a real TextureCoordinate node:
            // reading Parameters.TexCoords from a Custom node doesn't make UDK allocate texcoords for
            // the material, which then fails with "invalid subscript 'TexCoords'".
            var inputs = new CustomNodeBuilder(originalProps);
            ExportEntry? texCoord = null;
            if (!inputs.IsConnected("Coord"))
            {
                texCoord = CreateNode(parent, "MaterialExpressionTextureCoordinate", new PropertyCollection
                {
                    new IntProperty(0, "CoordinateIndex"),
                    new FloatProperty(1f, "UTiling"),
                    new FloatProperty(1f, "VTiling"),
                }, rop);
                RelinkNow(texCoord, rop);
            }
            var coord = inputs.RequiredInput("Coord", "float2");
            var time = inputs.RequiredInput("Time", "float");

            var sb = new StringBuilder();
            sb.AppendLine($"float2 FlipSize = float2({BioHlsl.F(1f / cols)}, {BioHlsl.F(1f / rows)});");
            sb.AppendLine($"float FlipFrame = floor( {cols * rows}.0 * {time} );");
            sb.AppendLine($"return {coord} * FlipSize + FlipSize * float2( fmod( FlipFrame, {cols}.0 ), floor( FlipFrame / {cols}.0 ) );");

            var uv = CreateCustomNode(parent, sb.ToString(), inputs.Inputs, "CMOT_Float2", rop);
            RelinkNow(uv, rop);
            if (texCoord != null)
                SetCustomInputExpression(uv, "Coord", texCoord);

            var sample = CreateNode(parent, "MaterialExpressionTextureSample", new PropertyCollection
            {
                new ObjectProperty(originalProps.GetProp<ObjectProperty>("FlipTex")?.Value ?? 0, "Texture"),
                ExpressionInputTo(0, "Coordinates"),
            }, rop);
            RelinkNow(sample, rop);
            SetInputExpression(sample, "Coordinates", uv);
            return sample;
        }
    }


    public abstract class BioMaterialExpressionBase(ExportEntry sourceExport)
    {
        protected ExportEntry Export { get; } = sourceExport;

        /// <summary>
        /// The Custom node's code. Add an input through <paramref name="inputs"/> for each operand.
        /// Only used by the default <see cref="ConvertExpression"/>.
        /// </summary>
        protected virtual string GetHLSLCode(PropertyCollection originalProps, CustomNodeBuilder inputs) =>
            throw new NotSupportedException($"{GetType().Name} does not convert to a Custom node");

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
        /// Creates the replacement for <see cref="Export"/> under <paramref name="parent"/>. Its references
        /// are source-package references; the relinker relinks it once it is mapped to the source node.
        /// </summary>
        public virtual ExportEntry ConvertExpression(ExportEntry parent, RelinkerOptionsPackage rop)
        {
            var originalProps = Export.GetProperties();
            var inputs = new CustomNodeBuilder(originalProps);
            var code = GetHLSLCode(originalProps, inputs);
            return CreateCustomNode(parent, code, inputs.Inputs, GetReturnType(), rop);
        }

        protected ExportEntry CreateCustomNode(ExportEntry parent, string code, ArrayProperty<StructProperty> inputs, string outputType, RelinkerOptionsPackage rop)
        {
            var props = new PropertyCollection
            {
                new StrProperty(code, "Code"),
                inputs,
                new EnumProperty(outputType, "ECustomMaterialOutputType", MEGame.UDK, "OutputType"),
                new StrProperty(GetDescription(), "Description"),
            };
            return CreateNode(parent, "MaterialExpressionCustom", props, rop);
        }

        protected static ExportEntry CreateNode(ExportEntry parent, string className, PropertyCollection props, RelinkerOptionsPackage rop)
        {
            var classObj = EntryImporter.EnsureClassIsInFile(parent.FileRef, className, rop);
            ExportEntry exp = new ExportEntry(parent.FileRef, parent, parent.FileRef.GetNextIndexedName(className), properties: props)
            {
                Class = classObj,
                Archetype = GetDefaults(classObj),
            };
            parent.FileRef.AddExport(exp);
            return exp;
        }

        /// <summary>
        /// Relinks a node's source-package references now, rather than in the relinker's pass, so the
        /// converter can then point it at other nodes it created (which only have destination indices).
        /// The relinker skips its references from then on.
        /// </summary>
        protected void RelinkNow(ExportEntry node, RelinkerOptionsPackage rop)
        {
            Relinker.Relink(Export, node, rop);
            BioMaterialExpressionConverters.MarkPreRelinked(node);
        }

        /// <summary>Points ExpressionInput <paramref name="inputName"/> of a relinked node at <paramref name="target"/>.</summary>
        protected static void SetInputExpression(ExportEntry node, string inputName, ExportEntry target)
        {
            var props = node.GetProperties();
            props.AddOrReplaceProp(ExpressionInputTo(target.UIndex, inputName));
            node.WriteProperties(props);
        }

        /// <summary>Points Custom input <paramref name="inputName"/> of a relinked Custom node at <paramref name="target"/>.</summary>
        protected static void SetCustomInputExpression(ExportEntry customNode, string inputName, ExportEntry target)
        {
            var props = customNode.GetProperties();
            var input = props.GetProp<ArrayProperty<StructProperty>>("Inputs")
                .First(i => i.GetProp<StrProperty>("InputName")?.Value == inputName);
            input.Properties.AddOrReplaceProp(ExpressionInputTo(target.UIndex, "Input"));
            customNode.WriteProperties(props);
        }

        protected static StructProperty ExpressionInputTo(int uIndex, string name) =>
            new("ExpressionInput", false, new ObjectProperty(uIndex, "Expression")) { Name = name };

        /// <summary>Source ExpressionInput <paramref name="sourceName"/>, renamed for the new node (unconnected if absent).</summary>
        protected static StructProperty CopyInput(PropertyCollection sourceProps, string sourceName, string newName)
        {
            var input = sourceProps.GetProp<StructProperty>(sourceName);
            if (input == null)
                return ExpressionInputTo(0, newName);
            input.Name = newName;
            return input;
        }

        /// <summary>
        /// Value used as output type
        /// </summary>
        protected virtual string GetReturnType() => "CMOT_Float1";

        private string GetDescription() => $"Original object: {Export.ObjectName.Instanced}";
    }
}
