using ICSharpCode.AvalonEdit.Highlighting;
using ICSharpCode.AvalonEdit.Highlighting.Xshd;
using ICSharpCode.AvalonEdit.Rendering;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.BinaryConverters.Shaders;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using Microsoft.Win32;
using MilanShaderHost;
using SharpDX.Direct3D;
using SharpDX.Direct3D11;
using SharpDX.DXGI;
using System.Collections.Concurrent;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.IO.Pipes;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.Marshalling;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Xml;
using D3D11Buffer = SharpDX.Direct3D11.Buffer;
using D3D11Device = SharpDX.Direct3D11.Device;
using MapFlags = SharpDX.Direct3D11.MapFlags;

namespace MilanShaderResearchTool
{
    public class MacroEntry : INotifyPropertyChanged
    {
        private bool _isEnabled = true;
        private string _name = "";
        private string _value = "";

        /// <summary>
        /// Macro is checked or not
        /// </summary>
        public bool IsEnabled
        {
            get => _isEnabled;
            set { _isEnabled = value; OnPropertyChanged(); }
        }

        private bool _show = true;
        /// <summary>
        /// Hidden, useless macros
        /// </summary>
        public bool Show
        {
            get => _show;
            set { _show = value; OnPropertyChanged(); }
        }

        /// <summary>
        /// Name of the macro
        /// </summary>
        public string Name
        {
            get => _name;
            set { _name = value; OnPropertyChanged(); }
        }

        /// <summary>
        /// String value of the Macro, typically 1
        /// </summary>
        public string Value
        {
            get => _value;
            set { _value = value; OnPropertyChanged(); }
        }

        /// <summary>
        /// Disables and possibly hides this macro - never enables.
        /// </summary>
        /// <param name="entryName"></param>
        /// <param name="vertexFactoryName"></param>
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

    public class MacroProbeResult
    {
        public string MacroName { get; init; } = "";
        public string MacroValue { get; init; } = "";
        public bool Compiled { get; init; }
        public bool CompiledPreferFlow { get; init; }
        public bool Matched { get; init; }
        public bool MatchedPreferFlow { get; init; }
        public string ComputedMd5 { get; init; } = "";
        public string ComputedMd5Prefer { get; init; } = "";
        // True if this result came from a removal test (we removed this macro from the base set)
        public bool IsRemoval { get; init; }
        public string Status => Matched || MatchedPreferFlow ? "✓ Match" : (Compiled || CompiledPreferFlow) ? "No Match" : "Compile Failed";

        // Which compilation produced the match: "Normal", "PreferFlow", "Both", or "None"
        public string MatchedBy
        {
            get
            {
                string which;
                if (Matched && MatchedPreferFlow) which = "Both";
                else if (Matched) which = "Normal";
                else if (MatchedPreferFlow) which = "PreferFlow";
                else which = "None";

                if (IsRemoval && which != "None")
                    return $"Removed:{which}";

                return which;
            }
        }
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
        private CancellationTokenSource? _pipeCts;

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

        #region Named Pipe Listener

        private void StartNamedPipeListener(CancellationToken token)
        {
            _ = Task.Run(async () =>
            {
                const string pipeName = "shaderresearchtool";
                _ = Dispatcher.InvokeAsync(() => AppendConsole($"Named pipe listener starting on '{pipeName}'..."));
                while (!token.IsCancellationRequested)
                {
                    try
                    {
                        using var pipe = new NamedPipeServerStream(pipeName, PipeDirection.In, 1, PipeTransmissionMode.Byte, PipeOptions.Asynchronous);
                        await pipe.WaitForConnectionAsync(token).ConfigureAwait(false);
                        _ = Dispatcher.InvokeAsync(() => AppendConsole("Client connected to named pipe."));

                        using var sr = new StreamReader(pipe, Encoding.UTF8);
                        var text = await sr.ReadToEndAsync().ConfigureAwait(false);
                        if (!string.IsNullOrWhiteSpace(text))
                        {
                            var pipeCommand = text.Trim();
                            _ = Dispatcher.InvokeAsync(() => AppendConsole($"Received pipe message: {pipeCommand}"));
                            HandlePipeCommand(pipeCommand);
                        }
                    }
                    catch (OperationCanceledException)
                    {
                        break;
                    }
                    catch (Exception ex)
                    {
                        _ = Dispatcher.InvokeAsync(() => AppendConsole($"Pipe listener error: {ex.Message}"));
                        try { await Task.Delay(1000, token).ConfigureAwait(false); } catch { }
                    }
                }

                _ = Dispatcher.InvokeAsync(() => AppendConsole("Named pipe listener stopped."));
            }, token);
        }

        private void HandlePipeCommand(string pipeCommand)
        {
            var parts = pipeCommand.Split("|");

            var command = parts[0];
            switch (command)
            {
                case "DEBUGPACKAGE":
                    {
                        var expectedHash = parts[1];
                        var realPath = Path.Combine(@"E:\Decooked\DebugPackages\LE3", parts[2], parts[3], parts[4], parts[5] + ".json");
                        if (File.Exists(realPath))
                        {
                            // Load debug package on UI thread
                            _ = Dispatcher.InvokeAsync(async () =>
                            {
                                await LoadDebugPackage(realPath);
                                ProbeHashBox.Text = expectedHash;
                                this.Activate();
                            });
                        }
                        else
                        {
                            _ = Dispatcher.InvokeAsync(() => AppendConsole($"File not found: {realPath}"));
                        }
                    }
                    break;
            }

        }

        #endregion

        private const int PreviewSize = 512;
        private readonly ObservableCollection<MacroEntry> _macros = new();

        private static readonly string SettingsPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "MilanShaderResearchTool", "settings.json");

        private class ToolSettings
        {
            public string? LastDebugPackagePath { get; set; }
        }

        private ToolSettings LoadSettings()
        {
            try
            {
                if (File.Exists(SettingsPath))
                {
                    var json = File.ReadAllText(SettingsPath);
                    return JsonSerializer.Deserialize<ToolSettings>(json,
                        new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? new ToolSettings();
                }
            }
            catch { }
            return new ToolSettings();
        }

        private void SaveSettings(ToolSettings settings)
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(SettingsPath)!);
                File.WriteAllText(SettingsPath, JsonSerializer.Serialize(settings,
                    new JsonSerializerOptions { WriteIndented = true }));
            }
            catch { }
        }

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
        private bool _compiledShaderIsVertexShader;
        private string? _materialHlslContent;

        // VS preview resources
        private PixelShader? _placeholderPS;
        private VertexShader? _compiledVS;
        private InputLayout? _compiledVSInputLayout;
        private D3D11Buffer? _compiledVSVertexBuffer;
        private int _compiledVSVertexStride;

        // Editor / diff state
        private double _savedExpectedWidth = 500;
        private DiffLineRenderer? _decompDiffRenderer;
        private DiffLineRenderer? _expectedDiffRenderer;
        private static IHighlightingDefinition? _hlslHighlighting;
        private string? _cachedDecompText;
        private string? _cachedExpectedText;
        private ObjectInstanceDB gameObjectDb;

        public MainWindow()
        {
            InitializeComponent();

            // Restore last debug package path (populate only, do not load)
            var savedSettings = LoadSettings();
            if (!string.IsNullOrEmpty(savedSettings.LastDebugPackagePath))
                MaterialHlslPathBox.Text = savedSettings.LastDebugPackagePath;

            // Start named pipe listener for external open requests
            _pipeCts = new CancellationTokenSource();
            StartNamedPipeListener(_pipeCts.Token);

            MacrosGrid.ItemsSource = _macros;

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

            Loaded += (_, _) => { SetupEditors(); };
        }

        protected override void OnClosed(EventArgs e)
        {
            // Stop pipe listener
            try
            {
                _pipeCts?.Cancel();
                _pipeCts?.Dispose();
            }
            catch { }

            base.OnClosed(e);
        }


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

        private async void BrowseMaterialHlsl_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new OpenFileDialog
            {
                Filter = "Shader Debug Package (*.json)|*.json|All Files|*.*",
                Title = "Select Shader Debug Package"
            };
            if (dlg.ShowDialog() == true)
                await LoadDebugPackage(dlg.FileName);
        }

        private async void ReloadDebugPackage_Click(object sender, RoutedEventArgs e)
        {
            var path = MaterialHlslPathBox.Text.Trim();
            if (string.IsNullOrEmpty(path) || !File.Exists(path))
            {
                AppendConsole("ERROR: No debug package path set or file not found.");
                return;
            }
            await LoadDebugPackage(path);
        }

        private async Task LoadDebugPackage(string jsonPath)
        {
            MaterialHlslPathBox.Text = jsonPath;
            SaveSettings(new ToolSettings { LastDebugPackagePath = jsonPath });

            ShaderClientDebugPackage package;
            try
            {
                var json = await Task.Run(() => File.ReadAllText(jsonPath));
                package = JsonSerializer.Deserialize<ShaderClientDebugPackage>(
                    json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;
            }
            catch (Exception ex)
            {
                AppendConsole($"ERROR loading debug package: {ex.Message}");
                return;
            }

            _materialHlslContent = package.materialHlsl;
            MaterialHlslEditor.Text = _materialHlslContent ?? string.Empty;

            BaseShaderNameBox.Text = package.sourceFilename ?? "";
            if (package.vertexFactoryShaderFilename != null)
            {
                // Game sends us name like FLocalVertexFactory, but we just want LocalVertexFactory
                VertexFactoryBox.Text = package.vertexFactoryShaderFilename;
            }
            else
            {
                VertexFactoryBox.Text = "";
            }
            EntryPointBox.Text = package.functionName ?? "";

            if (!string.IsNullOrEmpty(package.profile))
            {
                foreach (ComboBoxItem item in ShaderTypeCombo.Items)
                {
                    if (item.Content?.ToString() == package.profile)
                    {
                        ShaderTypeCombo.SelectedItem = item;
                        break;
                    }
                }
            }

            _macros.Clear();
            if (package.macros != null)
            {
                foreach (var macro in package.macros)
                    _macros.Add(new MacroEntry { Name = macro.name ?? "", Value = macro.definition ?? "" });
            }

            if (package.possibleMacros != null)
            {
                foreach (var macro in package.possibleMacros.OrderBy(x => x))
                {
                    if (!_macros.Any(m => m.Name == macro))
                    {
                        var entry = new MacroEntry { Name = macro, Value = "1", IsEnabled = false };
                        entry.UpdateDefaultSelection(BaseShaderNameBox.Text, VertexFactoryBox.Text);
                        if (entry.Show)
                        {
                            _macros.Add(entry);
                        }
                    }
                }
            }

            // Ensure there are no duplicate macro names (keep first occurrence)
            int beforeCount = _macros.Count;
            var deduped = _macros.GroupBy(m => m.Name).Select(g => g.First()).ToList();
            if (deduped.Count != beforeCount)
            {
                _macros.Clear();
                foreach (var m in deduped)
                    _macros.Add(m);
                AppendConsole($"Removed {beforeCount - deduped.Count} duplicate macros.");
            }

            AppendConsole($"Loaded debug package: {Path.GetFileName(jsonPath)}");
            Compile_Click(this, new RoutedEventArgs());
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
            var baseShader = BaseShaderNameBox.Text.Trim();
            var vertexFactory = VertexFactoryBox.Text.Trim();
            var entryPoint = EntryPointBox.Text.Trim();
            var shaderType = ((ComboBoxItem)ShaderTypeCombo.SelectedItem).Content.ToString()!;
            var includeDir = IncludeDirectoryBox.Text.Trim();

            if (string.IsNullOrEmpty(_materialHlslContent))
            {
                AppendConsole("ERROR: No debug package loaded. Please select a shader debug package JSON.");
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

            string materialHlsl = _materialHlslContent;
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
                    DecompiledShaderEditor.Text = string.Empty;
                    return;
                }

                AppendConsole($"SUCCESS — Bytecode: {shaderBytes.Length} bytes");
                _compiledShaderBytes = shaderBytes;
                _compiledShaderIsVertexShader = shaderType == "vs";

                var decompiledText = await Task.Run(() => HLSLDecompiler.DecompileShader(shaderBytes, false));
                DecompiledShaderEditor.Text = decompiledText ?? string.Empty;
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

        private async void OpenGameVersion_Click(object sender, RoutedEventArgs e)
        {
            var jsonPath = MaterialHlslPathBox.Text.Trim();
            if (string.IsNullOrEmpty(jsonPath) || !File.Exists(jsonPath))
            {
                AppendConsole("ERROR: No debug package loaded.");
                return;
            }

            var shaderTypeName = Path.GetFileNameWithoutExtension(jsonPath);
            var vf = Path.GetFileName(Path.GetDirectoryName(jsonPath)!);

            AppendConsole($"Looking up game version for {shaderTypeName}...");

            byte[]? referenceBytecode;
            try
            {
                referenceBytecode = await Task.Run(() => GetReferenceBytecode(jsonPath, shaderTypeName, vf));
            }
            catch (Exception ex)
            {
                AppendConsole($"ERROR looking up game version: {ex.Message}");
                return;
            }

            if (referenceBytecode == null || referenceBytecode.Length == 0)
            {
                AppendConsole("ERROR: Could not find reference bytecode in game files.");
                return;
            }

            var decompiled = await Task.Run(() => HLSLDecompiler.DecompileShader(referenceBytecode, false));
            if (string.IsNullOrEmpty(decompiled))
            {
                AppendConsole("ERROR: Failed to decompile game shader bytecode.");
                return;
            }

            ExpectedDecompiledEditor.Text = decompiled;
            ProbeHashBox.Text = ComputeShaderBytecodeMd5(referenceBytecode);
            ShowExpectedPanel();
            UpdateMaterialInfoPanel();
            AppendConsole("Game version loaded in expected panel.");
        }

        private void OpenBaseShaderUsf_Click(object sender, RoutedEventArgs e)
        {
            var game = MEGame.LE3;
            var baseShader = BaseShaderNameBox.Text.Trim();
            if (string.IsNullOrEmpty(baseShader))
            {
                AppendConsole("ERROR: No base shader name specified.");
                return;
            }

            var shadersDir = Path.Combine(MEDirectories.GetDefaultGamePath(game), "Engine", "Shaders");
            var usfPath = Path.Combine(shadersDir, baseShader + ".usf");
            if (!File.Exists(usfPath))
            {
                AppendConsole($"ERROR: File not found: {usfPath}");
                return;
            }

            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(usfPath) { UseShellExecute = true });
        }

        private void OpenVertexFactoryUsf_Click(object sender, RoutedEventArgs e)
        {
            var game = MEGame.LE3;
            var vertexFactory = VertexFactoryBox.Text.Trim();
            if (string.IsNullOrEmpty(vertexFactory))
            {
                AppendConsole("ERROR: No vertex factory name specified.");
                return;
            }

            var shadersDir = Path.Combine(MEDirectories.GetDefaultGamePath(game), "Engine", "Shaders");
            var usfPath = Path.Combine(shadersDir, vertexFactory + ".usf");
            if (!File.Exists(usfPath))
            {
                AppendConsole($"ERROR: File not found: {usfPath}");
                return;
            }

            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(usfPath) { UseShellExecute = true });
        }

        private void OpenMaterialUsf_Click(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrEmpty(_materialHlslContent))
            {
                AppendConsole("ERROR: No material HLSL loaded.");
                return;
            }

            var tempPath = Path.Combine(Path.GetTempPath(), "MaterialTemplate.usf");
            File.WriteAllText(tempPath, _materialHlslContent, Encoding.UTF8);
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(tempPath) { UseShellExecute = true });
        }

        private void AddMacro_Click(object sender, RoutedEventArgs e) =>
            _macros.Add(new MacroEntry { Name = "NEW_MACRO", Value = "1" });

        private void RemoveMacro_Click(object sender, RoutedEventArgs e)
        {
            if (MacrosGrid.SelectedItem is MacroEntry selected)
                _macros.Remove(selected);
        }

        private async void ProbeHash_Click(object sender, RoutedEventArgs e)
        {
            var hash = ProbeHashBox.Text.Trim();
            if (string.IsNullOrEmpty(hash))
            {
                AppendConsole("ERROR: Enter an MD5 hash in the probe hash box.");
                return;
            }
            await ProbeHashMatch(hash);
        }

        private async Task ProbeHashMatch(string targetMd5)
        {
            var baseShader = BaseShaderNameBox.Text.Trim();
            var vertexFactory = VertexFactoryBox.Text.Trim();
            var entryPoint = EntryPointBox.Text.Trim();
            var shaderType = ((ComboBoxItem)ShaderTypeCombo.SelectedItem).Content.ToString()!;
            var includeDir = IncludeDirectoryBox.Text.Trim();
            var materialHlsl = _materialHlslContent;

            if (string.IsNullOrEmpty(materialHlsl))
            {
                AppendConsole("ERROR: No debug package loaded.");
                return;
            }
            if (string.IsNullOrEmpty(baseShader) || string.IsNullOrEmpty(entryPoint) ||
                string.IsNullOrEmpty(includeDir) || !Directory.Exists(includeDir))
            {
                AppendConsole("ERROR: Shader configuration is incomplete.");
                return;
            }

            var flags = GetCompileFlags();
            var baseMacros = _macros.Where(m => m.IsEnabled).Select(m => (m.Name, m.Value)).ToArray();
            var probeMacros = _macros.Where(m => m.Show && !m.IsEnabled).ToList();

            if (probeMacros.Count == 0)
            {
                AppendConsole("No visible unchecked macros to probe.");
                return;
            }

            AppendConsole($"Probing {probeMacros.Count} unchecked macros against MD5 {targetMd5}...");

            var results = new ConcurrentBag<MacroProbeResult>();
            int maxConc = Math.Max(1, Environment.ProcessorCount / 2);
            var semaphore = new SemaphoreSlim(maxConc);
            int completed = 0;

            var tasks = probeMacros.Select(async macro =>
            {
                await semaphore.WaitAsync().ConfigureAwait(false);
                try
                {
                    var testMacros = baseMacros.Append((macro.Name, macro.Value)).ToArray();

                    bool compiled = false;
                    bool matched = false;
                    string md5Result = "";
                    bool compiledPrefer = false;
                    bool matchedPrefer = false;
                    string md5ResultPrefer = "";

                    try
                    {
                        var (result, shaderBytes, _) = DoCompileShader(
                            baseShader, materialHlsl, vertexFactory, includeDir,
                            testMacros, entryPoint, shaderType, flags);

                        compiled = result == 0 && shaderBytes.Length > 0;
                        if (compiled)
                        {
                            md5Result = ComputeShaderBytecodeMd5(shaderBytes);
                            matched = string.Equals(md5Result, targetMd5, StringComparison.OrdinalIgnoreCase);
                        }

                        // Also try with Prefer Flow Control forced on
                        int preferFlag = (1 << 10);
                        var preferFlags = flags | preferFlag;
                        var (result2, shaderBytes2, _) = DoCompileShader(
                            baseShader, materialHlsl, vertexFactory, includeDir,
                            testMacros, entryPoint, shaderType, preferFlags);

                        compiledPrefer = result2 == 0 && shaderBytes2.Length > 0;
                        if (compiledPrefer)
                        {
                            md5ResultPrefer = ComputeShaderBytecodeMd5(shaderBytes2);
                            matchedPrefer = string.Equals(md5ResultPrefer, targetMd5, StringComparison.OrdinalIgnoreCase);
                        }
                    }
                    catch { /* compile failure recorded via compiled flags */ }

                    results.Add(new MacroProbeResult
                    {
                        MacroName = macro.Name,
                        MacroValue = macro.Value,
                        Compiled = compiled,
                        CompiledPreferFlow = compiledPrefer,
                        Matched = matched,
                        MatchedPreferFlow = matchedPrefer,
                        ComputedMd5 = md5Result,
                        ComputedMd5Prefer = md5ResultPrefer,
                    });

                    int done = Interlocked.Increment(ref completed);
                    if (done % 10 == 0 || done == probeMacros.Count)
                        _ = Dispatcher.InvokeAsync(() => AppendConsole($"  [{done}/{probeMacros.Count}] probed..."));
                }
                finally
                {
                    semaphore.Release();
                }
            });

            await Task.WhenAll(tasks);

            var sorted = results.OrderByDescending(r => (r.Matched || r.MatchedPreferFlow)).ThenBy(r => r.MacroName).ToList();
            int matchCount = sorted.Count(r => r.Matched || r.MatchedPreferFlow);
            AppendConsole($"Hash probe complete: {matchCount}/{sorted.Count} macros matched.");

            var window = new MacroProbeResultsWindow(targetMd5, sorted) { Owner = this };
            window.Show();

            // If nothing matched when adding a single macro (including prefer-flow),
            // try the inverse: remove a single base macro and see if that produces a match.
            if (matchCount == 0)
            {
                var enabledMacros = _macros.Where(m => m.IsEnabled).ToList();
                if (enabledMacros.Count > 0)
                {
                    AppendConsole($"No matches found. Probing by removing one of {enabledMacros.Count} base macros...");

                    var removalResults = new ConcurrentBag<MacroProbeResult>();
                    var remSemaphore = new SemaphoreSlim(Math.Max(1, Environment.ProcessorCount / 2));
                    int remCompleted = 0;

                    var remTasks = enabledMacros.Select(async remMacro =>
                    {
                        await remSemaphore.WaitAsync().ConfigureAwait(false);
                        try
                        {
                            // Build macros without this one
                            var testMacros = baseMacros.Where(b => b.Name != remMacro.Name).ToArray();

                            bool compiled = false;
                            bool matched = false;
                            string md5Result = "";
                            bool compiledPrefer = false;
                            bool matchedPrefer = false;
                            string md5ResultPrefer = "";

                            try
                            {
                                var (result, shaderBytes, _) = DoCompileShader(
                                    baseShader, materialHlsl, vertexFactory, includeDir,
                                    testMacros, entryPoint, shaderType, flags);

                                compiled = result == 0 && shaderBytes.Length > 0;
                                if (compiled)
                                {
                                    md5Result = ComputeShaderBytecodeMd5(shaderBytes);
                                    matched = string.Equals(md5Result, targetMd5, StringComparison.OrdinalIgnoreCase);
                                }

                                // Also try with Prefer Flow Control forced on
                                int preferFlag = (1 << 10);
                                var preferFlags = flags | preferFlag;
                                var (result2, shaderBytes2, _) = DoCompileShader(
                                    baseShader, materialHlsl, vertexFactory, includeDir,
                                    testMacros, entryPoint, shaderType, preferFlags);

                                compiledPrefer = result2 == 0 && shaderBytes2.Length > 0;
                                if (compiledPrefer)
                                {
                                    md5ResultPrefer = ComputeShaderBytecodeMd5(shaderBytes2);
                                    matchedPrefer = string.Equals(md5ResultPrefer, targetMd5, StringComparison.OrdinalIgnoreCase);
                                }
                            }
                            catch { }

                            removalResults.Add(new MacroProbeResult
                            {
                                MacroName = remMacro.Name,
                                MacroValue = remMacro.Value,
                                Compiled = compiled,
                                CompiledPreferFlow = compiledPrefer,
                                Matched = matched,
                                MatchedPreferFlow = matchedPrefer,
                                ComputedMd5 = md5Result,
                                ComputedMd5Prefer = md5ResultPrefer,
                                IsRemoval = true,
                            });

                            int done = Interlocked.Increment(ref remCompleted);
                            if (done % 10 == 0 || done == enabledMacros.Count)
                                _ = Dispatcher.InvokeAsync(() => AppendConsole($"  [removal {done}/{enabledMacros.Count}] probed..."));
                        }
                        finally
                        {
                            remSemaphore.Release();
                        }
                    });

                    await Task.WhenAll(remTasks);

                    var remSorted = removalResults.OrderByDescending(r => (r.Matched || r.MatchedPreferFlow)).ThenBy(r => r.MacroName).ToList();
                    int remMatches = remSorted.Count(r => r.Matched || r.MatchedPreferFlow);
                    AppendConsole($"Removal probe complete: {remMatches}/{remSorted.Count} macros matched when removed.");

                    var remWindow = new MacroProbeResultsWindow(targetMd5, remSorted) { Owner = this };
                    remWindow.Title = "Macro Removal Probe Results";
                    remWindow.Show();
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

        private static string ComputeShaderBytecodeMd5(byte[] bytecode)
        {
            var hash = MD5.HashData(bytecode);
            return Convert.ToHexString(hash).ToLowerInvariant();
        }

        private void AppendConsole(string text)
        {
            ConsoleOutput.AppendText(text + Environment.NewLine);
            ConsoleOutput.ScrollToEnd();
        }

        /// <summary>
        /// The material that is the entrypoint for finding the shader. We also get other properties off it
        /// </summary>
        private ExportEntry ReferenceMaterialExport;

        private void UpdateMaterialInfoPanel()
        {
            MaterialInfoOutput.Text = GetReferenceMaterialInformation();
        }

        private string GetReferenceMaterialInformation()
        {
            StringBuilder sb = new StringBuilder();

            if (ReferenceMaterialExport != null)
            {
                sb.AppendLine(ReferenceMaterialExport.MemoryFullPath);
                sb.AppendLine(ReferenceMaterialExport.FileRef.FileNameNoExtension + ".pcc");

                var props = ReferenceMaterialExport.GetProperties();
                foreach(var prop in props)
                {
                    if (prop is BoolProperty bp)
                    {
                        sb.AppendLine($"{bp.Name}:\t{bp.Value}");
                    }
                }

                var blendMode = props.GetProp<EnumProperty>("BlendMode");
                if (blendMode != null)
                {
                    sb.AppendLine($"{blendMode.Name}:\t{blendMode.Value}");
                }

                var lightingModel = props.GetProp<EnumProperty>("LightingModel");
                if (lightingModel != null)
                {
                    sb.AppendLine($"{lightingModel.Name}:\t{lightingModel.Value}");
                }

                var nNumWounds = props.GetProp<IntProperty>("nNumWounds");
                if (nNumWounds != null)
                {
                    sb.AppendLine($"{nNumWounds.Name}:\t{nNumWounds.Value}");
                }

            }
            else
            {
                sb.Append("No reference material loaded");
            }

            return sb.ToString();
        }

        private byte[]? GetReferenceBytecode(string jsonPath, string shaderType, string? vf)
        {
            const MEGame game = MEGame.LE3;

            ReferenceMaterialExport = null;
            if (gameObjectDb == null)
            {
                var dbPath = $@"B:\UserProfile\source\repos\ME3Tweaks\ProjectMilan\LEDecooker\supportfiles\{game}.bin";
                using var fs = File.OpenRead(dbPath);
                gameObjectDb = ObjectInstanceDB.Deserialize(game, fs);
            }

            // Parse: .../<PACKAGENAME>/<MATERIALNAME>/<VERTEXFACTORY>/<SHADERTYPE>.json
            var matDir = Directory.GetParent(Directory.GetParent(jsonPath)!.FullName)!;
            var ifp = $"{matDir.Parent!.Name}.{matDir.Name}";

            var containingPackages = gameObjectDb.GetFilesContainingObject(ifp);
            if (containingPackages == null || containingPackages.Count == 0)
                return null;

            var packagePath = Path.Combine(MEDirectories.GetDefaultGamePath(game), containingPackages[0]);
            using var pkg = MEPackageHandler.OpenMEPackage(packagePath);
            var material = pkg.FindExport(ifp);
            if (material == null || !material.IsA("Material"))
                return null;
            ReferenceMaterialExport = material;

            var matBin = ObjectBinary.From<Material>(material);
            var sps = (StaticParameterSet)matBin.SM3MaterialResource.ID;

            var sc = ShaderCacheManipulator.GetAllShadersForMaterials([material]);
            if (sc == null)
                return null;

            if (!sc.MaterialShaderMaps.TryGetValue(sps, out var materialMap))
                return null;

            // JSON filenames use [ ] in place of < > due to filesystem restrictions.
            var testName = shaderType.Replace("[", "<").Replace("]", ">");
            if (vf == null)
            {
                if (materialMap.Shaders.TryGetValue(testName, out var shaderRef) &&
                    sc.Shaders.TryGetValue(shaderRef.Id, out var shader))
                    return shader.ShaderByteCode;
            }
            else
            {
                var msm = materialMap.MeshShaderMaps.FirstOrDefault(x => x.VertexFactoryType.Name == vf);
                if (msm != null && msm.Shaders.TryGetValue(testName, out var shaderRef) &&
                    sc.Shaders.TryGetValue(shaderRef.Id, out var shader))
                    return shader.ShaderByteCode;
            }

            return null;
        }

        private void Autosearch_Click(object sender, RoutedEventArgs e)
        {
            // Extract data by parsing enum of path:
            // .../<GAME>/<PACKAGENAME>/<MATERIALNAME>/<VERTEXFACTORY>/<SHADERTYPE>.json
            // Build IFP from PACKAGENAME.MATERIALNAME

            var game = MEGame.LE3;

            if (gameObjectDb == null)
            {
                var path = $@"B:\UserProfile\source\repos\ME3Tweaks\ProjectMilan\LEDecooker\supportfiles\{game}.bin";
                using var fs = File.OpenRead(path);
                gameObjectDb = ObjectInstanceDB.Deserialize(game, fs);
            }

            // Shader cache state, cached per material IFP to avoid reloading the package for every shader.
            ShaderCache? cachedSc = null;
            MaterialShaderMap? cachedMaterialMap = null;
            string? cachedIFP = null;

            var window = new MacroSetFinderWindow(
                compileShader: DoCompileShader,
                includesDirectory: Path.Combine(MEDirectories.GetDefaultGamePath(game), "Engine", "Shaders"),
                getReferenceBytecode: (jsonPath, shaderType, vf) =>
                {
                    // Parse: .../<PACKAGENAME>/<MATERIALNAME>/<VERTEXFACTORY>/<SHADERTYPE>.json
                    var matDir = Directory.GetParent(Directory.GetParent(jsonPath)!.FullName)!;
                    var ifp = $"{matDir.Parent!.Name}.{matDir.Name}";

                    if (ifp != cachedIFP)
                    {
                        cachedSc = null;
                        cachedMaterialMap = null;

                        var containingPackages = gameObjectDb.GetFilesContainingObject(ifp);
                        if (containingPackages == null || containingPackages.Count == 0)
                            return null;

                        var packagePath = Path.Combine(MEDirectories.GetDefaultGamePath(game), containingPackages[0]);
                        using var pkg = MEPackageHandler.OpenMEPackage(packagePath);
                        var material = pkg.FindExport(ifp);
                        if (material == null || !material.IsA("Material"))
                            return null;

                        var matBin = ObjectBinary.From<Material>(material);
                        var sps = (StaticParameterSet)matBin.SM3MaterialResource.ID;

                        cachedSc = ShaderCacheManipulator.GetAllShadersForMaterials([material]);
                        if (cachedSc == null)
                            return null;

                        if (!cachedSc.MaterialShaderMaps.TryGetValue(sps, out cachedMaterialMap))
                            return null;

                        cachedIFP = ifp;
                    }

                    if (cachedSc == null || cachedMaterialMap == null)
                        return null;

                    // JSON filenames use [ ] in place of < > due to filesystem restrictions.
                    var testName = shaderType.Replace("[", "<").Replace("]", ">");
                    if (vf == null)
                    {
                        if (cachedMaterialMap.Shaders.TryGetValue(testName, out var shaderRef) &&
                            cachedSc.Shaders.TryGetValue(shaderRef.Id, out var shader))
                            return shader.ShaderByteCode;
                    }
                    else
                    {
                        var msm = cachedMaterialMap.MeshShaderMaps.FirstOrDefault(x => x.VertexFactoryType.Name == vf);
                        if (msm != null && msm.Shaders.TryGetValue(testName, out var shaderRef) &&
                            cachedSc.Shaders.TryGetValue(shaderRef.Id, out var shader))
                            return shader.ShaderByteCode;
                    }

                    return null;
                }
            );
            window.Owner = this;
            window.Show();
        }

        /// <summary>
        /// Opens a debug package and optionally shows expected decompilation in the side panel.
        /// </summary>
        public async Task OpenDebugPackageWithExpected(string jsonPath, string? expectedDecompilation, string? probeHash = null)
        {
            await LoadDebugPackage(jsonPath);

            if (!string.IsNullOrEmpty(expectedDecompilation))
            {
                ExpectedDecompiledEditor.Text = expectedDecompilation;
                ShowExpectedPanel();
            }

            if (!string.IsNullOrEmpty(probeHash))
                ProbeHashBox.Text = probeHash;

            Activate();
        }

        #region Editor setup, HLSL highlighting, and diff

        private void SetupEditors()
        {
            _hlslHighlighting ??= LoadHlslHighlighting();
            DecompiledShaderEditor.SyntaxHighlighting = _hlslHighlighting;
            ExpectedDecompiledEditor.SyntaxHighlighting = _hlslHighlighting;
            MaterialHlslEditor.SyntaxHighlighting = _hlslHighlighting;

            _decompDiffRenderer = new DiffLineRenderer();
            _expectedDiffRenderer = new DiffLineRenderer();
            DecompiledShaderEditor.TextArea.TextView.BackgroundRenderers.Add(_decompDiffRenderer);
            ExpectedDecompiledEditor.TextArea.TextView.BackgroundRenderers.Add(_expectedDiffRenderer);

            DecompiledShaderEditor.TextChanged += (_, _) => UpdateDiff();
            ExpectedDecompiledEditor.TextChanged += (_, _) => UpdateDiff();
        }

        private static IHighlightingDefinition? LoadHlslHighlighting()
        {
            var assembly = System.Reflection.Assembly.GetExecutingAssembly();
            using var stream = assembly.GetManifestResourceStream("MilanShaderResearchTool.Syntax.Hlsl.xshd");
            if (stream is null) return null;
            using var reader = XmlReader.Create(stream);
            return HighlightingLoader.Load(reader, HighlightingManager.Instance);
        }

        private void UpdateDiff()
        {
            if (_decompDiffRenderer is null || _expectedDiffRenderer is null) return;

            var decompText = DecompiledShaderEditor.Text;
            var expectedText = ExpectedDecompiledEditor.Text;

            if (decompText == _cachedDecompText && expectedText == _cachedExpectedText) return;
            _cachedDecompText = decompText;
            _cachedExpectedText = expectedText;

            if (string.IsNullOrEmpty(decompText) || string.IsNullOrEmpty(expectedText))
            {
                _decompDiffRenderer.SetDiffLines([]);
                _expectedDiffRenderer.SetDiffLines([]);
            }
            else
            {
                var decompLines = decompText.Split('\n');
                var expectedLines = expectedText.Split('\n');
                int maxLen = Math.Max(decompLines.Length, expectedLines.Length);
                var diffLines = new List<int>(maxLen);
                for (int i = 0; i < maxLen; i++)
                {
                    var dl = i < decompLines.Length ? decompLines[i].TrimEnd('\r') : null;
                    var el = i < expectedLines.Length ? expectedLines[i].TrimEnd('\r') : null;
                    if (dl != el) diffLines.Add(i + 1);
                }
                _decompDiffRenderer.SetDiffLines(diffLines);
                _expectedDiffRenderer.SetDiffLines(diffLines);
            }

            DecompiledShaderEditor.TextArea.TextView.InvalidateLayer(KnownLayer.Background);
            ExpectedDecompiledEditor.TextArea.TextView.InvalidateLayer(KnownLayer.Background);
        }

        private void ShowExpectedPanel()
        {
            ExpectedPanel.Visibility = Visibility.Visible;
            CompareSplitter.Visibility = Visibility.Visible;
            SplitterColumn.Width = new GridLength(5);
            ExpectedColumn.Width = new GridLength(_savedExpectedWidth);
        }

        private void HideExpectedPanel()
        {
            var w = ExpectedColumn.ActualWidth;
            if (w > 0) _savedExpectedWidth = w;
            ExpectedPanel.Visibility = Visibility.Collapsed;
            CompareSplitter.Visibility = Visibility.Collapsed;
            SplitterColumn.Width = new GridLength(0);
            ExpectedColumn.Width = new GridLength(0);
        }

        private void CloseExpected_Click(object sender, RoutedEventArgs e) => HideExpectedPanel();

        private sealed class DiffLineRenderer : IBackgroundRenderer
        {
            private SortedSet<int> _diffLines = new();
            private static readonly Brush DiffBrush;

            static DiffLineRenderer()
            {
                DiffBrush = new SolidColorBrush(Color.FromArgb(70, 220, 60, 60));
                DiffBrush.Freeze();
            }

            public KnownLayer Layer => KnownLayer.Background;

            public void SetDiffLines(IEnumerable<int> lines)
            {
                _diffLines = new SortedSet<int>(lines);
            }

            public void Draw(TextView textView, DrawingContext drawingContext)
            {
                if (_diffLines.Count == 0 || textView.Document is null) return;
                var visualLines = textView.VisualLines;
                if (visualLines.Count == 0) return;
                double scrollY = textView.ScrollOffset.Y;
                foreach (var vl in visualLines)
                {
                    if (_diffLines.Contains(vl.FirstDocumentLine.LineNumber))
                        drawingContext.DrawRectangle(DiffBrush, null,
                            new Rect(0, vl.VisualTop - scrollY, textView.ActualWidth, vl.Height));
                }
            }
        }

        #endregion
    }
}