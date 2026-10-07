using LegendaryExplorerCore;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilanCore.Shaders.OfflineCompiler;
using static LegendaryExplorerCore.Shaders.LE3MaterialShaderCompiler;

namespace ProjectMilanCore.Tests.OfflineCompiler;

[TestClass]
public static class TestSetup
{
    [AssemblyInitialize]
    public static void Initialize(TestContext _) => LegendaryExplorerCoreLib.InitLib(null, _ => { });
}

/// <summary>In-memory LE3 packages. No game installation is needed.</summary>
internal static class Fixtures
{
    public static IMEPackage Package(string name, MEGame game = MEGame.LE3)
        => MEPackageHandler.CreateMemoryEmptyPackage(name + ".pcc", game);

    public static ExportEntry Material(IMEPackage package, string name, Guid? resourceId = null, string className = "Material")
    {
        var material = package.CreateExport(name, className, indexed: false);
        var binary = LegendaryExplorerCore.Unreal.BinaryConverters.Material.Create();
        binary.SM3MaterialResource.ID = resourceId ?? Guid.NewGuid();
        material.WriteBinary(binary);
        return material;
    }

    /// <summary>A texture whose binary is junk, proving metadata reads never parse texture payloads.</summary>
    public static ExportEntry Texture(IMEPackage package, string name, string compression = "TC_Default",
        string className = "Texture2D", float? unpackMin = null)
    {
        var texture = package.CreateExport(name, className, indexed: false);
        texture.WriteProperty(new EnumProperty(compression, "TextureCompressionSettings", package.Game, "CompressionSettings"));
        if (unpackMin is { } min)
            for (int i = 0; i < 4; i++) texture.WriteProperty(new FloatProperty(min, "UnpackMin") { StaticArrayIndex = i });
        texture.WriteBinary(new byte[] { 0xDE, 0xAD, 0xBE, 0xEF, 0x01 });
        return texture;
    }

    public static ExportEntry Parameter(ExportEntry material, string parameterName, IEntry? texture,
        string className = "MaterialExpressionTextureSampleParameter2D", Guid? guid = null)
    {
        var expression = material.FileRef.CreateExport(parameterName + "Expression", className, material, indexed: false);
        expression.WriteProperty(new NameProperty(parameterName, "ParameterName"));
        expression.WriteProperty(StructProperty.FromGuid(guid ?? Guid.NewGuid(), "ExpressionGUID"));
        if (texture != null) expression.WriteProperty(new ObjectProperty(texture.UIndex, "Texture"));
        var expressions = material.GetProperty<ArrayProperty<ObjectProperty>>("Expressions") ?? new ArrayProperty<ObjectProperty>("Expressions");
        expressions.Add(new ObjectProperty(expression.UIndex));
        material.WriteProperty(expressions);
        return expression;
    }

    public static ExportEntry Instance(IMEPackage package, string name, IEntry parent, params (string Parameter, IEntry? Texture)[] overrides)
    {
        var instance = package.CreateExport(name, "MaterialInstanceConstant", indexed: false);
        instance.WriteProperty(new ObjectProperty(parent.UIndex, "Parent"));
        if (overrides.Length > 0)
        {
            instance.WriteProperty(new ArrayProperty<StructProperty>(overrides.Select(o => new StructProperty("TextureParameterValue",
                new PropertyCollection
                {
                    new NameProperty(o.Parameter, "ParameterName"),
                    new ObjectProperty(o.Texture?.UIndex ?? 0, "ParameterValue")
                }, "TextureParameterValue", false)).ToList(), "TextureParameterValues"));
        }
        instance.WriteBinary(MaterialInstance.Create());
        return instance;
    }

    public static void StaticNormal(ExportEntry instance, string parameterName, byte compression)
    {
        instance.WriteProperty(new BoolProperty(true, "bHasStaticPermutationResource"));
        var binary = MaterialInstance.Create();
        binary.SM3StaticParameterSet.NormalParameters =
        [
            new StaticParameterSet.NormalParameter { ParameterName = parameterName, CompressionSettings = compression, bOverride = true }
        ];
        instance.WriteBinary(binary);
    }

    public static byte CompressionIndex(string name)
        => (byte)LegendaryExplorerCore.Unreal.ObjectInfo.GlobalUnrealObjectInfo.GetEnumValues(MEGame.LE3, "TextureCompressionSettings")
            .FindIndex(n => n.Instanced == name);

    public static ShaderCompileTarget Target(string shaderType, string? vertexFactory = "FLocalVertexFactory")
        => new(shaderType, "BasePassPixelShader", "Main", ShaderStage.Pixel, 0, vertexFactory,
            vertexFactory == null ? null : "LocalVertexFactory");

    public static LE3ShaderSourceSnapshot Sources() => new(new Dictionary<string, string>
    {
        ["MaterialTemplate.usf"] = "/*\n%u\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n#line %u\n*/"
    });
}

/// <summary>Records what the service asks of it; never touches a real package source or compiler.</summary>
internal sealed class SpyMetadataProvider : ITextureCompilationMetadataProvider
{
    public int Calls;
    public TextureCompilationMetadata? GetMetadata(IEntry textureReference)
    {
        Calls++;
        return new TextureCompilationMetadata(TextureDimension.Texture2D);
    }
    public IReadOnlyList<TextureMetadataResolution> Resolutions => [];
}

internal sealed class FakeBackend : IMaterialShaderCompilerBackend
{
    public readonly List<MaterialShaderCompileSessionContext> Contexts = [];
    public Exception? CreateThrows;
    public Func<FakeSession> NewSession = () => new FakeSession();
    public FakeSession? LastSession;

    public IMaterialShaderCompileSession CreateSession(MaterialShaderCompileSessionContext context)
    {
        Contexts.Add(context);
        if (CreateThrows != null) throw CreateThrows;
        return LastSession = NewSession();
    }
}

internal sealed class FakeSession : IMaterialShaderCompileSession
{
    public static readonly ShaderCompileTarget First = Fixtures.Target("TBasePassPixelShaderA");
    public static readonly ShaderCompileTarget Second = Fixtures.Target("TBasePassPixelShaderB");

    public readonly List<string> Calls = [];
    public Func<TranslationPhaseResult> OnTranslate = () => new(true, []);
    public Func<PlanningPhaseResult> OnPlan = () => new(true, [], [First, Second],
        [new(First, ShaderCompileDisposition.Eligible, ShaderCompileGate.Registration, "ok"),
         new(Second, ShaderCompileDisposition.Eligible, ShaderCompileGate.Registration, "ok")]);
    public Func<int, ShaderJobOutcome> OnCompile = i => new(i == 0 ? First : Second, true, $"warning X{i}", 10 + i);
    public Func<AssemblyPhaseResult> OnAssemble = () => new(true, [], ShaderCache.Create(), [7, 3], false);

    public TranslationPhaseResult Translate() { Calls.Add("Translate"); return OnTranslate(); }
    public PlanningPhaseResult Plan() { Calls.Add("Plan"); return OnPlan(); }
    public ShaderJobOutcome Compile(int jobIndex) { Calls.Add($"Compile{jobIndex}"); return OnCompile(jobIndex); }
    public AssemblyPhaseResult Assemble() { Calls.Add("Assemble"); return OnAssemble(); }
    public LE3MaterialShaderCompilerArtifacts? Artifacts => null;
}

/// <summary>Reports synchronously, unlike Progress&lt;T&gt;, so tests see every report in order.</summary>
internal sealed class ListProgress<T>(Action<T>? onReport = null) : IProgress<T>
{
    public readonly List<T> Reports = [];
    public void Report(T value)
    {
        Reports.Add(value);
        onReport?.Invoke(value);
    }
}
