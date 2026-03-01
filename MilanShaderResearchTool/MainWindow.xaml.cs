using Microsoft.Win32;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.Marshalling;
using System.Text;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Shaders;
using SharpDX.Direct3D;
using SharpDX.Direct3D11;
using SharpDX.DXGI;
using D3D11Buffer = SharpDX.Direct3D11.Buffer;
using D3D11Device = SharpDX.Direct3D11.Device;
using MapFlags = SharpDX.Direct3D11.MapFlags;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal.BinaryConverters;

namespace MilanShaderResearchTool
{
    public class MacroEntry : INotifyPropertyChanged
    {
        private bool _isEnabled = true;
        private string _name = "";
        private string _value = "";

        public bool IsEnabled
        {
            get => _isEnabled;
            set { _isEnabled = value; OnPropertyChanged(); }
        }

        private bool _show = true;
        public bool Show
        {
            get => _show;
            set { _show = value; OnPropertyChanged(); }
        }

        public string Name
        {
            get => _name;
            set { _name = value; OnPropertyChanged(); }
        }

        public string Value
        {
            get => _value;
            set { _value = value; OnPropertyChanged(); }
        }

        public void UpdateDefaultSelection(string entryName, string vertexFactoryName)
        {
            switch (Name)
            {
                case "__ORBIS__":
                case "PS3":
                case "ORBIS":
                case "DINGO":
                case "XBOX":
                case "SM2_PROFILE":
                case "SM3_PROFILE":
                    Show = false;
                    IsEnabled = false;
                    break;

                    // These are undef/defined based on other flags
                case "NEEDS_LIGHTMAP_COORDINATE":
                case "NEEDS_SHADOWMAP_COORDINATE":
                case "NEEDS_VERTEX_LIGHTMAP":
                case "NEEDS_SIMPLE_VERTEX_LIGHTMAP":
                case "NEEDS_BASEPASS_FOGGING":
                    IsEnabled = false;
                    break;
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string? name = null) =>
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }

    public class ResourceBindingEntry
    {
        public string Name { get; set; } = "";
        public ushort BufferIndex { get; set; }
        public ushort BaseIndex { get; set; }
        public ushort Size { get; set; }
        public string SamplerIndex { get; set; } = "";
    }

    public class TextureInputEntry : INotifyPropertyChanged
    {
        private int _slot;
        private string _filePath = "";

        public int Slot
        {
            get => _slot;
            set { _slot = value; OnPropertyChanged(); }
        }

        public string FilePath
        {
            get => _filePath;
            set { _filePath = value; OnPropertyChanged(); }
        }

        public event PropertyChangedEventHandler? PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string? name = null) =>
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }

    [StructLayout(LayoutKind.Sequential)]
    struct FParameterAllocation
    {
        public ushort BufferIndex;
        public ushort BaseIndex;
        public ushort Size;
        public ushort SamplerIndex;
        public int Bound;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct NativeNamedParameterAllocation
    {
        public FParameterAllocation Allocation;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)]
        public string Name;
    }

    /// <summary>
    /// UE3 Shader Research Tool — compiles D3D11 shaders via MilanShaderCompilerLib
    /// and provides a flat-mesh preview with SharpDX.
    /// </summary>
    public partial class MainWindow : Window
    {
        #region P/Invoke

        [DllImport("MilanShaderCompilerLib.dll", EntryPoint = "CompileShader", ExactSpelling = true)]
        private static extern unsafe int CompileShader_Native(
            byte* baseShaderName, byte* materialHlsl, byte* vertexFactoryName,
            ushort* includesDirectory, void* macros, byte* entryPoint, byte* shaderType,
            int compileFlags,
            ref int outShaderBytesSize, byte[] outShaderBytes,
            ref int outErrorMsgSize, byte[] outErrorMsg);

        [DllImport("MilanShaderCompilerLib.dll", EntryPoint = "GetShaderInfo", ExactSpelling = true)]
        private static extern void GetShaderInfo_Native(
            int shaderBufferSize, byte[] shaderBuffer,
            ref int outInstructionCount, ref int outNumParameters,
            IntPtr allocationArray);

        #endregion

        private const int PreviewSize = 512;
        private readonly ObservableCollection<MacroEntry> _macros = new();
        private readonly ObservableCollection<ResourceBindingEntry> _resourceBindings = new();
        private readonly ObservableCollection<TextureInputEntry> _textureInputs = new();

        // SharpDX objects
        private D3D11Device? _device;
        private Texture2D? _renderTarget;
        private RenderTargetView? _renderTargetView;
        private Texture2D? _stagingTexture;
        private D3D11Buffer? _vertexBuffer;
        private InputLayout? _inputLayout;
        private VertexShader? _previewVS;
        private PixelShader? _compiledPS;
        private SamplerState? _samplerState;
        private WriteableBitmap? _previewBitmap;
        private readonly Dictionary<int, (Texture2D Texture, ShaderResourceView SRV)> _textureSRVs = new();

        private byte[]? _compiledShaderBytes;

        public MainWindow()
        {
            InitializeComponent();

            MacrosGrid.ItemsSource = _macros;
            ResourceBindingsGrid.ItemsSource = _resourceBindings;
            TextureInputsGrid.ItemsSource = _textureInputs;

            // Default macros for UE3 D3D11 compilation
            _macros.Add(new MacroEntry { Name = "COMPILER_HLSL", Value = "1" });
            _macros.Add(new MacroEntry { Name = "SM5_PROFILE", Value = "1" });

            // Try to resolve default include directory from LE3 game path
            try
            {
                var gamePath = LE3Directory.DefaultGamePath;
                if (!string.IsNullOrEmpty(gamePath))
                {
                    var shadersPath = Path.Combine(gamePath, "Engine", "Shaders");
                    if (Directory.Exists(shadersPath))
                    {
                        IncludeDirectoryBox.Text = shadersPath;
                        PopulateShaderFileDropdowns(shadersPath);
                        PopulateEntryPoints();
                    }
                }
            }
            catch { /* LE3 path not configured */ }

            Loaded += (_, _) => InitializeD3D();
        }

        protected override void OnClosed(EventArgs e)
        {
            CleanupD3D();
            base.OnClosed(e);
        }

        #region D3D11 Preview

        private void InitializeD3D()
        {
            try
            {
                _device = new D3D11Device(DriverType.Hardware, DeviceCreationFlags.None);

                _renderTarget = new Texture2D(_device, new Texture2DDescription
                {
                    Width = PreviewSize,
                    Height = PreviewSize,
                    MipLevels = 1,
                    ArraySize = 1,
                    Format = Format.B8G8R8A8_UNorm,
                    SampleDescription = new SampleDescription(1, 0),
                    Usage = ResourceUsage.Default,
                    BindFlags = BindFlags.RenderTarget,
                });
                _renderTargetView = new RenderTargetView(_device, _renderTarget);

                _stagingTexture = new Texture2D(_device, new Texture2DDescription
                {
                    Width = PreviewSize,
                    Height = PreviewSize,
                    MipLevels = 1,
                    ArraySize = 1,
                    Format = Format.B8G8R8A8_UNorm,
                    SampleDescription = new SampleDescription(1, 0),
                    Usage = ResourceUsage.Staging,
                    BindFlags = BindFlags.None,
                    CpuAccessFlags = CpuAccessFlags.Read,
                });

                // Preview vertex shader provides SV_POSITION, UV, and extra TEXCOORD slots
                // so UE3 pixel shaders that read common interpolants get reasonable defaults.
                var vsSource = @"
struct VS_OUT {
    float4 pos : SV_POSITION;
    float2 uv  : TEXCOORD0;
    float4 tc1 : TEXCOORD1;
    float4 tc2 : TEXCOORD2;
    float4 tc3 : TEXCOORD3;
    float4 tc4 : TEXCOORD4;
    float4 tc5 : TEXCOORD5;
    float4 tc6 : TEXCOORD6;
    float4 tc7 : TEXCOORD7;
};
VS_OUT main(float3 p : POSITION, float2 uv : TEXCOORD0) {
    VS_OUT o = (VS_OUT)0;
    o.pos = float4(p, 1.0);
    o.uv  = uv;
    o.tc1 = float4(uv, 0, 1);
    return o;
}";
                var vsCompileResult = SharpDX.D3DCompiler.ShaderBytecode.Compile(vsSource, "main", "vs_5_0");
                if (vsCompileResult.HasErrors)
                {
                    AppendConsole($"Preview VS compile error: {vsCompileResult.Message}");
                    vsCompileResult.Dispose();
                    return;
                }

                _previewVS = new VertexShader(_device, vsCompileResult.Bytecode);
                _inputLayout = new InputLayout(_device, vsCompileResult.Bytecode, new[]
                {
                    new InputElement("POSITION", 0, Format.R32G32B32_Float, 0, 0),
                    new InputElement("TEXCOORD", 0, Format.R32G32_Float, 12, 0),
                });
                vsCompileResult.Dispose();

                // Full-screen quad: 2 triangles, 20 bytes/vertex (float3 pos + float2 uv)
                var vertices = new float[]
                {
                    -1, -1, 0,  0, 1,
                    -1,  1, 0,  0, 0,
                     1,  1, 0,  1, 0,
                    -1, -1, 0,  0, 1,
                     1,  1, 0,  1, 0,
                     1, -1, 0,  1, 1,
                };
                var vertexHandle = GCHandle.Alloc(vertices, GCHandleType.Pinned);
                try
                {
                    _vertexBuffer = new D3D11Buffer(_device, vertexHandle.AddrOfPinnedObject(),
                        new BufferDescription
                        {
                            SizeInBytes = vertices.Length * sizeof(float),
                            BindFlags = BindFlags.VertexBuffer,
                            Usage = ResourceUsage.Default,
                        });
                }
                finally
                {
                    vertexHandle.Free();
                }

                _samplerState = new SamplerState(_device, new SamplerStateDescription
                {
                    Filter = Filter.MinMagMipLinear,
                    AddressU = TextureAddressMode.Wrap,
                    AddressV = TextureAddressMode.Wrap,
                    AddressW = TextureAddressMode.Wrap,
                    MaximumAnisotropy = 1,
                    ComparisonFunction = Comparison.Never,
                    MaximumLod = float.MaxValue,
                });

                _previewBitmap = new WriteableBitmap(PreviewSize, PreviewSize, 96, 96, PixelFormats.Bgra32, null);
                PreviewImage.Source = _previewBitmap;

                // Compile a placeholder pixel shader so we can verify the preview pipeline on startup.
                var placeholderSource = @"
float4 main(float4 pos : SV_POSITION, float2 uv : TEXCOORD0) : SV_TARGET {
    float2 grid  = floor(uv * 8.0);
    float checker = fmod(grid.x + grid.y, 2.0) * 0.15 + 0.85;
    return float4(uv.x * checker, uv.y * checker, 0.3 * checker, 1.0);
}";
                var psPlaceholder = SharpDX.D3DCompiler.ShaderBytecode.Compile(placeholderSource, "main", "ps_5_0");
                if (!psPlaceholder.HasErrors)
                {
                    _compiledShaderBytes = psPlaceholder.Bytecode.Data;
                    UpdatePreview();
                }
                psPlaceholder.Dispose();

                AppendConsole("D3D11 preview initialized.");
            }
            catch (Exception ex)
            {
                AppendConsole($"Failed to initialize D3D11 preview: {ex.Message}");
            }
        }

        private void UpdatePreview()
        {
            if (_compiledShaderBytes is null || _device is null || _previewBitmap is null)
                return;

            try
            {
                _compiledPS?.Dispose();
                _compiledPS = new PixelShader(_device, _compiledShaderBytes);

                var ctx = _device.ImmediateContext;
                ctx.ClearRenderTargetView(_renderTargetView,
                    new SharpDX.Mathematics.Interop.RawColor4(0.1f, 0.1f, 0.1f, 1.0f));
                ctx.OutputMerger.SetRenderTargets(_renderTargetView);
                ctx.Rasterizer.SetViewport(new SharpDX.Viewport(0, 0, PreviewSize, PreviewSize));
                ctx.InputAssembler.InputLayout = _inputLayout;
                ctx.InputAssembler.PrimitiveTopology = PrimitiveTopology.TriangleList;
                ctx.InputAssembler.SetVertexBuffers(0, new VertexBufferBinding(_vertexBuffer, 20, 0));
                ctx.VertexShader.Set(_previewVS);
                ctx.PixelShader.Set(_compiledPS);

                // Bind user-loaded textures
                foreach (var kvp in _textureSRVs)
                    ctx.PixelShader.SetShaderResource(kvp.Key, kvp.Value.SRV);

                // Set sampler on all slots
                for (int i = 0; i < 16; i++)
                    ctx.PixelShader.SetSampler(i, _samplerState);

                ctx.Draw(6, 0);

                // Read back to WriteableBitmap
                ctx.CopyResource(_renderTarget, _stagingTexture);
                var dataBox = ctx.MapSubresource(_stagingTexture, 0, MapMode.Read, MapFlags.None);

                _previewBitmap.Lock();
                try
                {
                    for (int row = 0; row < PreviewSize; row++)
                    {
                        IntPtr src = dataBox.DataPointer + row * dataBox.RowPitch;
                        IntPtr dst = _previewBitmap.BackBuffer + row * _previewBitmap.BackBufferStride;
                        SharpDX.Utilities.CopyMemory(dst, src, PreviewSize * 4);
                    }
                    _previewBitmap.AddDirtyRect(new Int32Rect(0, 0, PreviewSize, PreviewSize));
                }
                finally
                {
                    _previewBitmap.Unlock();
                }

                ctx.UnmapSubresource(_stagingTexture, 0);

                GetTextureResources();
                AppendConsole("Preview updated.");
            }
            catch (Exception ex)
            {
                AppendConsole($"Preview render error: {ex.Message}");
            }
        }

        private void GetTextureResources()
        {
            var filename = Path.GetFileName(MaterialHlslPathBox.Text.Trim());
            if (filename == "")
            {
                return; // Do nothing
            }
            var packageBasename = filename.Substring(0, filename.IndexOf('.'));
            var ifp = Path.GetFileNameWithoutExtension(MaterialHlslPathBox.Text.Trim());

            var packagePath = Path.Combine(@"E:\Decooked\LE3", $"{packageBasename}.pcc");
            using var package = MEPackageHandler.OpenMEPackage(packagePath);
            var material = package.FindExport(ifp);
            var matbin = ObjectBinary.From<Material>(material);

            var textures = matbin.SM3MaterialResource.UniformExpressionTextures;
            foreach(var texUIndex in textures)
            {

            }

        }

        private void LoadTextureForSlot(int slot, string filePath)
        {
            if (_device is null || !File.Exists(filePath)) return;

            try
            {
                // Dispose previous texture for this slot
                if (_textureSRVs.TryGetValue(slot, out var old))
                {
                    old.SRV.Dispose();
                    old.Texture.Dispose();
                    _textureSRVs.Remove(slot);
                }

                // Load via WPF imaging, convert to BGRA32
                var bmp = new BitmapImage();
                bmp.BeginInit();
                bmp.UriSource = new Uri(filePath, UriKind.Absolute);
                bmp.CacheOption = BitmapCacheOption.OnLoad;
                bmp.EndInit();

                var converted = new FormatConvertedBitmap(bmp, PixelFormats.Bgra32, null, 0);
                int w = converted.PixelWidth;
                int h = converted.PixelHeight;
                int stride = w * 4;
                var pixels = new byte[stride * h];
                converted.CopyPixels(pixels, stride, 0);

                var handle = GCHandle.Alloc(pixels, GCHandleType.Pinned);
                try
                {
                    var texDesc = new Texture2DDescription
                    {
                        Width = w,
                        Height = h,
                        MipLevels = 1,
                        ArraySize = 1,
                        Format = Format.B8G8R8A8_UNorm,
                        SampleDescription = new SampleDescription(1, 0),
                        Usage = ResourceUsage.Default,
                        BindFlags = BindFlags.ShaderResource,
                    };
                    var dataBox = new SharpDX.DataBox(handle.AddrOfPinnedObject(), stride, 0);
                    var tex = new Texture2D(_device, texDesc, new[] { dataBox });
                    var srv = new ShaderResourceView(_device, tex);
                    _textureSRVs[slot] = (tex, srv);
                }
                finally
                {
                    handle.Free();
                }

                AppendConsole($"Loaded texture for slot {slot}: {Path.GetFileName(filePath)}");
            }
            catch (Exception ex)
            {
                AppendConsole($"Failed to load texture for slot {slot}: {ex.Message}");
            }
        }

        private void CleanupD3D()
        {
            foreach (var kvp in _textureSRVs)
            {
                kvp.Value.SRV?.Dispose();
                kvp.Value.Texture?.Dispose();
            }
            _textureSRVs.Clear();

            _compiledPS?.Dispose();
            _samplerState?.Dispose();
            _vertexBuffer?.Dispose();
            _inputLayout?.Dispose();
            _previewVS?.Dispose();
            _stagingTexture?.Dispose();
            _renderTargetView?.Dispose();
            _renderTarget?.Dispose();
            _device?.Dispose();
        }

        #endregion

        #region Compilation

        private int GetCompileFlags()
        {
            int flags = 0;
            if (FlagDebug.IsChecked == true) flags |= (1 << 0);            // D3DCOMPILE_DEBUG
            if (FlagSkipValidation.IsChecked == true) flags |= (1 << 1);   // D3DCOMPILE_SKIP_VALIDATION
            if (FlagSkipOptimization.IsChecked == true) flags |= (1 << 2); // D3DCOMPILE_SKIP_OPTIMIZATION
            if (FlagAvoidFlowControl.IsChecked == true) flags |= (1 << 9); // D3DCOMPILE_AVOID_FLOW_CONTROL
            if (FlagPreferFlowControl.IsChecked == true) flags |= (1 << 10); // D3DCOMPILE_PREFER_FLOW_CONTROL
            if (FlagBackwardsCompat.IsChecked == true) flags |= (1 << 12); // D3DCOMPILE_ENABLE_BACKWARDS_COMPATIBILITY
            if (FlagOptLevel3.IsChecked == true) flags |= (1 << 15);       // D3DCOMPILE_OPTIMIZATION_LEVEL3
            return flags;
        }

        private unsafe (int Result, byte[] ShaderBytes, string ErrorMessage) DoCompileShader(
            string baseShaderName, string materialHlsl, string vertexFactoryName,
            string includesDirectory, (string Name, string Definition)[] macros,
            string entryPoint, string shaderType, int compileFlags)
        {
            string errorMessage = string.Empty;
            byte[] shaderBytes = Array.Empty<byte>();

            int shaderBufferSize = 4 * 1024 * 1024; // 4MiB
            int errorBufferSize = 8192;

            baseShaderName += ".usf";
            if (!string.IsNullOrEmpty(vertexFactoryName))
                vertexFactoryName += ".usf";

            scoped AnsiStringMarshaller.ManagedToUnmanagedIn baseShader_m = new();
            scoped AnsiStringMarshaller.ManagedToUnmanagedIn materialHlsl_m = new();
            scoped AnsiStringMarshaller.ManagedToUnmanagedIn vertexFactory_m = new();
            scoped AnsiStringMarshaller.ManagedToUnmanagedIn entryPoint_m = new();
            scoped AnsiStringMarshaller.ManagedToUnmanagedIn shaderType_m = new();

            byte** macroStrings = null;
            int numStrings = macros.Length * 2;

            try
            {
                // Two string pointers per macro, plus a null-terminator struct at the end
                macroStrings = (byte**)NativeMemory.AllocZeroed((nuint)(numStrings + 2), (nuint)IntPtr.Size);
                byte** it = macroStrings;
                foreach (var macro in macros)
                {
                    *it = AnsiStringMarshaller.ConvertToUnmanaged(macro.Name);
                    it++;
                    *it = AnsiStringMarshaller.ConvertToUnmanaged(macro.Definition);
                    it++;
                }

                int bufSize = AnsiStringMarshaller.ManagedToUnmanagedIn.BufferSize;
                baseShader_m.FromManaged(baseShaderName, stackalloc byte[bufSize]);
                materialHlsl_m.FromManaged(materialHlsl, stackalloc byte[bufSize]);
                vertexFactory_m.FromManaged(vertexFactoryName ?? "", stackalloc byte[bufSize]);
                entryPoint_m.FromManaged(entryPoint, stackalloc byte[bufSize]);
                shaderType_m.FromManaged(shaderType, stackalloc byte[bufSize]);

                fixed (void* includesDirPtr = &Utf16StringMarshaller.GetPinnableReference(includesDirectory))
                {
                    byte[] shaderBuffer = new byte[shaderBufferSize];
                    byte[] errorBuffer = new byte[errorBufferSize];

                    var result = CompileShader_Native(
                        baseShader_m.ToUnmanaged(),
                        materialHlsl_m.ToUnmanaged(),
                        vertexFactory_m.ToUnmanaged(),
                        (ushort*)includesDirPtr,
                        macroStrings,
                        entryPoint_m.ToUnmanaged(),
                        shaderType_m.ToUnmanaged(),
                        compileFlags,
                        ref shaderBufferSize, shaderBuffer,
                        ref errorBufferSize, errorBuffer);

                    if (result != 0)
                    {
                        if (errorBufferSize > 0)
                            errorMessage = Encoding.ASCII.GetString(errorBuffer, 0, errorBufferSize);
                    }
                    else
                    {
                        shaderBytes = new byte[shaderBufferSize];
                        if (shaderBufferSize > 0)
                            System.Buffer.BlockCopy(shaderBuffer, 0, shaderBytes, 0, shaderBufferSize);
                    }

                    return (result, shaderBytes, errorMessage);
                }
            }
            finally
            {
                if (macroStrings is not null)
                {
                    byte** freeIt = macroStrings;
                    for (int i = 0; i < numStrings; i++)
                    {
                        AnsiStringMarshaller.Free(*freeIt);
                        freeIt++;
                    }
                    NativeMemory.Free(macroStrings);
                }

                baseShader_m.Free();
                materialHlsl_m.Free();
                vertexFactory_m.Free();
                entryPoint_m.Free();
                shaderType_m.Free();
            }
        }

        private List<ResourceBindingEntry> DoGetShaderInfo(byte[] shaderBytes, out int instructionCount)
        {
            instructionCount = 0;
            var result = new List<ResourceBindingEntry>();

            const int maxParams = 256;
            int structSize = Marshal.SizeOf<NativeNamedParameterAllocation>();
            IntPtr allocPtr = Marshal.AllocHGlobal(structSize * maxParams);

            try
            {
                unsafe
                {
                    NativeMemory.Clear((void*)allocPtr, (nuint)(structSize * maxParams));
                }

                int numParams = 0;
                GetShaderInfo_Native(shaderBytes.Length, shaderBytes, ref instructionCount, ref numParams, allocPtr);

                for (int i = 0; i < numParams && i < maxParams; i++)
                {
                    var alloc = Marshal.PtrToStructure<NativeNamedParameterAllocation>(allocPtr + i * structSize);
                    result.Add(new ResourceBindingEntry
                    {
                        Name = alloc.Name ?? "",
                        BufferIndex = alloc.Allocation.BufferIndex,
                        BaseIndex = alloc.Allocation.BaseIndex,
                        Size = alloc.Allocation.Size,
                        SamplerIndex = alloc.Allocation.SamplerIndex == ushort.MaxValue
                            ? "N/A"
                            : alloc.Allocation.SamplerIndex.ToString(),
                    });
                }
            }
            finally
            {
                Marshal.FreeHGlobal(allocPtr);
            }

            return result;
        }

        #endregion

        #region UI Event Handlers

        private void BrowseMaterialHlsl_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new OpenFileDialog
            {
                Filter = "HLSL Files (*.hlsl;*.usf;*.fx)|*.hlsl;*.usf;*.fx|All Files|*.*",
                Title = "Select Material HLSL File"
            };
            if (dlg.ShowDialog() == true)
                MaterialHlslPathBox.Text = dlg.FileName;
        }

        private void BrowseIncludeDir_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new OpenFolderDialog { Title = "Select Shader Include Directory" };
            if (dlg.ShowDialog() == true)
            {
                IncludeDirectoryBox.Text = dlg.FolderName;
                PopulateShaderFileDropdowns(dlg.FolderName);
            }
        }

        private async void Compile_Click(object sender, RoutedEventArgs e)
        {
            var materialPath = MaterialHlslPathBox.Text.Trim();
            var baseShader = BaseShaderNameBox.Text.Trim();
            var vertexFactory = VertexFactoryBox.Text.Trim();
            var entryPoint = EntryPointBox.Text.Trim();
            var shaderType = ((ComboBoxItem)ShaderTypeCombo.SelectedItem).Content.ToString()!;
            var includeDir = IncludeDirectoryBox.Text.Trim();

            if (string.IsNullOrEmpty(materialPath) || !File.Exists(materialPath))
            {
                AppendConsole("ERROR: Material HLSL file not found.");
                return;
            }
            if (string.IsNullOrEmpty(baseShader))
            {
                AppendConsole("ERROR: Base shader name is required.");
                return;
            }
            if (string.IsNullOrEmpty(entryPoint))
            {
                AppendConsole("ERROR: Entry point is required.");
                return;
            }
            if (string.IsNullOrEmpty(includeDir) || !Directory.Exists(includeDir))
            {
                AppendConsole("ERROR: Include directory not found.");
                return;
            }

            int flags = GetCompileFlags();
            AppendConsole($"--- Compiling: {baseShader} | Entry: {entryPoint} | Type: {shaderType} | Flags: 0x{flags:X} ---");

            string materialHlsl = await Task.Run(() => File.ReadAllText(materialPath));
            var macros = _macros.Where(m => m.IsEnabled).Select(m => (m.Name, m.Value)).ToArray();

            try
            {
                var (result, shaderBytes, errorMessage) = await Task.Run(() =>
                    DoCompileShader(baseShader, materialHlsl, vertexFactory, includeDir,
                        macros, entryPoint, shaderType, flags));

                if (result != 0)
                {
                    AppendConsole($"FAILED (HRESULT: 0x{result:X8})");
                    if (!string.IsNullOrEmpty(errorMessage))
                        AppendConsole(errorMessage);
                    _compiledShaderBytes = null;
                    _resourceBindings.Clear();
                    DecompiledShaderBox.Text = string.Empty;
                    return;
                }

                AppendConsole($"SUCCESS — Bytecode: {shaderBytes.Length} bytes");
                _compiledShaderBytes = shaderBytes;

                // Retrieve reflection / resource bindings
                var bindings = DoGetShaderInfo(shaderBytes, out int instructionCount);
                AppendConsole($"Instructions: {instructionCount} | Bindings: {bindings.Count}");

                _resourceBindings.Clear();
                foreach (var b in bindings)
                    _resourceBindings.Add(b);

                var decompiledText = await Task.Run(() => HLSLDecompiler.DecompileShader(shaderBytes, false));
                DecompiledShaderBox.Text = decompiledText;

                UpdatePreview();
            }
            catch (Exception ex)
            {
                AppendConsole($"ERROR: {ex}");
            }
        }

        private async void ProbeDefines_Click(object sender, RoutedEventArgs e)
        {
            var includeDir = IncludeDirectoryBox.Text.Trim();
            var baseShader = BaseShaderNameBox.Text.Trim();
            var vertexFactory = VertexFactoryBox.Text.Trim();
            var materialPath = MaterialHlslPathBox.Text.Trim();

            if (string.IsNullOrEmpty(includeDir) || !Directory.Exists(includeDir))
            {
                AppendConsole("ERROR: Include directory not found.");
                return;
            }

            var startingFilePath = Path.Combine(includeDir, baseShader + ".usf");
            if (!File.Exists(startingFilePath))
            {
                AppendConsole($"ERROR: Base shader file not found: {startingFilePath}");
                return;
            }

            var materialUsfContent = "";
            if (!string.IsNullOrEmpty(materialPath) && File.Exists(materialPath))
            {
                materialUsfContent = await Task.Run(() => File.ReadAllText(materialPath));
            }

            var vertexFactoryUsfContent = "";
            if (!string.IsNullOrEmpty(vertexFactory))
            {
                var vertexFactoryPath = Path.Combine(includeDir, vertexFactory + ".usf");
                if (File.Exists(vertexFactoryPath))
                {
                    vertexFactoryUsfContent = await Task.Run(() => File.ReadAllText(vertexFactoryPath));
                }
            }

            try
            {
                var prober = await Task.Run(() =>
                    new HlslDefinedDirectiveProber(startingFilePath, includeDir, materialUsfContent, vertexFactoryUsfContent));

                var existingNames = new HashSet<string>(_macros.Select(m => m.Name));
                int added = 0;
                foreach (var directive in prober.DefinedDirectives.Order())
                {
                    if (existingNames.Add(directive))
                    {
                        var macro = new MacroEntry { Name = directive, Value = "1" };
                        macro.UpdateDefaultSelection(BaseShaderNameBox.Text, VertexFactoryBox.Text);
                        if (!macro.Show)
                        {
                            continue;
                        }
                        _macros.Add(macro);
                        added++;
                    }
                }

                AppendConsole($"Probe complete: {prober.DefinedDirectives.Count} directives found, {added} new macros added.");
            }
            catch (Exception ex)
            {
                AppendConsole($"ERROR probing defines: {ex.Message}");
            }
        }

        private void AddMacro_Click(object sender, RoutedEventArgs e) =>
            _macros.Add(new MacroEntry { Name = "NEW_MACRO", Value = "1" });

        private void RemoveMacro_Click(object sender, RoutedEventArgs e)
        {
            if (MacrosGrid.SelectedItem is MacroEntry selected)
                _macros.Remove(selected);
        }

        private void AddTextureSlot_Click(object sender, RoutedEventArgs e)
        {
            int nextSlot = _textureInputs.Count > 0 ? _textureInputs.Max(t => t.Slot) + 1 : 0;
            _textureInputs.Add(new TextureInputEntry { Slot = nextSlot });
        }

        private void RemoveTextureSlot_Click(object sender, RoutedEventArgs e)
        {
            if (TextureInputsGrid.SelectedItem is TextureInputEntry selected)
            {
                if (_textureSRVs.TryGetValue(selected.Slot, out var tex))
                {
                    tex.SRV.Dispose();
                    tex.Texture.Dispose();
                    _textureSRVs.Remove(selected.Slot);
                }
                _textureInputs.Remove(selected);
            }
        }

        private void BrowseTexture_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.DataContext is TextureInputEntry entry)
            {
                var dlg = new OpenFileDialog
                {
                    Filter = "Image Files (*.png;*.jpg;*.bmp;*.tga)|*.png;*.jpg;*.bmp;*.tga|All Files|*.*",
                    Title = "Select Texture Image"
                };
                if (dlg.ShowDialog() == true)
                {
                    entry.FilePath = dlg.FileName;
                    LoadTextureForSlot(entry.Slot, entry.FilePath);
                    if (_compiledShaderBytes != null)
                        UpdatePreview();
                }
            }
        }

        #endregion

        private void BaseShaderNameBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            Dispatcher.BeginInvoke(PopulateEntryPoints);
        }

        private void PopulateEntryPoints()
        {
            var includeDir = IncludeDirectoryBox.Text.Trim();
            var baseShader = BaseShaderNameBox.Text.Trim();
            if (string.IsNullOrEmpty(includeDir) || string.IsNullOrEmpty(baseShader))
                return;

            var filePath = Path.Combine(includeDir, baseShader + ".usf");
            if (!File.Exists(filePath))
                return;

            var previousEntry = EntryPointBox.Text;
            EntryPointBox.Items.Clear();

            var content = File.ReadAllText(filePath);
            var matches = Regex.Matches(content,
                @"^\s*(?:void|float[234]?|half[234]?|int|uint)\s+(\w+)\s*\(",
                RegexOptions.Multiline);

            var names = matches.Select(m => m.Groups[1].Value).Distinct().ToList();
            foreach (var name in names)
            {
                EntryPointBox.Items.Add(name);
            }

            if (names.Contains("Main"))
            {
                EntryPointBox.Text = "Main";
            }
            else if (names.Count > 0)
            {
                EntryPointBox.Text = names.Contains(previousEntry) ? previousEntry : names[0];
            }
            else
            {
                EntryPointBox.Text = previousEntry;
            }
        }

        private void PopulateShaderFileDropdowns(string includesDirectory)
        {
            var previousBase = BaseShaderNameBox.Text;
            var previousVF = VertexFactoryBox.Text;

            BaseShaderNameBox.Items.Clear();
            VertexFactoryBox.Items.Clear();

            if (Directory.Exists(includesDirectory))
            {
                var usfFiles = Directory.GetFiles(includesDirectory, "*.usf")
                    .Select(Path.GetFileNameWithoutExtension)
                    .Order()
                    .ToArray();

                foreach (var name in usfFiles)
                {
                    BaseShaderNameBox.Items.Add(name);
                    VertexFactoryBox.Items.Add(name);
                }
            }

            BaseShaderNameBox.Text = previousBase;
            VertexFactoryBox.Text = previousVF;
        }

        private void AppendConsole(string text)
        {
            ConsoleOutput.AppendText(text + Environment.NewLine);
            ConsoleOutput.ScrollToEnd();
        }
    }
}