// WwiseHook.cpp : Loads a Wwise SoundBank (.bnk) using the Wwise 2019.1.6 SDK
// and prints the AKRESULT status plus basic bank information.

#include <algorithm>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>
#include <windows.h>

// Wwise SDK headers
#include <AK/SoundEngine/Common/AkMemoryMgr.h>
#include <AK/SoundEngine/Common/AkModule.h>
#include <AK/SoundEngine/Common/IAkStreamMgr.h>
#include <AK/SoundEngine/Common/AkStreamMgrModule.h>
#include <AK/SoundEngine/Common/AkSoundEngine.h>
#include <AK/MusicEngine/Common/AkMusicEngine.h>
#include <AK/SoundEngine/Common/AkTypes.h>

// Low-level I/O hook from SDK samples (blocking variant)
#include <AkDefaultIOHookBlocking.h>

// Hooking layer (MinHook + DbgHelp)
#include "WwiseHooks.h"
#include <DbgHelp.h>

// For dumping stack traces
#include <windows.h>
#include <dbghelp.h>
#include <iostream>

#pragma comment(lib, "dbghelp.lib") // Link with dbghelp.lib (MSVC)

#include <windows.h>
#include <dbghelp.h>
#include <iostream>
#include <string_view>

// Vectored exception handler: prints the fault address/code and a symbolized stack trace walked from
// the actual faulting CONTEXT (not just "the last hooked call we happened to log"), then lets the
// exception continue so the process still crashes/exits normally afterward.
LONG WINAPI CrashDiagnosticsHandler(EXCEPTION_POINTERS* info)
{
    DWORD code = info->ExceptionRecord->ExceptionCode;
    // Only handle actual crashes; ignore benign first-chance exceptions (e.g. C++ EH, debug breaks).
    if (code != EXCEPTION_ACCESS_VIOLATION && code != EXCEPTION_STACK_OVERFLOW &&
        code != EXCEPTION_ILLEGAL_INSTRUCTION && code != EXCEPTION_INT_DIVIDE_BY_ZERO)
    {
        return EXCEPTION_CONTINUE_SEARCH;
    }

    std::cout.setf(std::ios::unitbuf);
    std::cout << "\n=== CRASH DETECTED ===\n";
    std::cout << "ExceptionCode: 0x" << std::hex << code << std::dec << "\n";
    std::cout << "ExceptionAddress: 0x" << std::hex << (uintptr_t)info->ExceptionRecord->ExceptionAddress << std::dec << "\n";
    if (code == EXCEPTION_ACCESS_VIOLATION && info->ExceptionRecord->NumberParameters >= 2)
    {
        std::cout << "Access violation " << (info->ExceptionRecord->ExceptionInformation[0] ? "writing" : "reading")
            << " address 0x" << std::hex << info->ExceptionRecord->ExceptionInformation[1] << std::dec << "\n";
    }

    HANDLE process = GetCurrentProcess();
    HANDLE thread = GetCurrentThread();
    CONTEXT ctx = *info->ContextRecord;

    STACKFRAME64 frame = {};
    DWORD machineType;
#ifdef _M_X64
    machineType = IMAGE_FILE_MACHINE_AMD64;
    frame.AddrPC.Offset = ctx.Rip;
    frame.AddrPC.Mode = AddrModeFlat;
    frame.AddrFrame.Offset = ctx.Rbp;
    frame.AddrFrame.Mode = AddrModeFlat;
    frame.AddrStack.Offset = ctx.Rsp;
    frame.AddrStack.Mode = AddrModeFlat;
#else
    machineType = IMAGE_FILE_MACHINE_I386;
    frame.AddrPC.Offset = ctx.Eip;
    frame.AddrPC.Mode = AddrModeFlat;
    frame.AddrFrame.Offset = ctx.Ebp;
    frame.AddrFrame.Mode = AddrModeFlat;
    frame.AddrStack.Offset = ctx.Esp;
    frame.AddrStack.Mode = AddrModeFlat;
#endif

    char symbolBuffer[sizeof(SYMBOL_INFO) + MAX_SYM_NAME * sizeof(TCHAR)];
    PSYMBOL_INFO symbol = (PSYMBOL_INFO)symbolBuffer;
    symbol->SizeOfStruct = sizeof(SYMBOL_INFO);
    symbol->MaxNameLen = MAX_SYM_NAME;

    std::cout << "--- Crash Stack Trace (walked from fault context) ---\n";
    for (int i = 0; i < 40; i++)
    {
        if (!StackWalk64(machineType, process, thread, &frame, &ctx, nullptr,
            SymFunctionTableAccess64, SymGetModuleBase64, nullptr))
        {
            break;
        }
        if (frame.AddrPC.Offset == 0) break;

        DWORD64 displacement = 0;
        if (SymFromAddr(process, frame.AddrPC.Offset, &displacement, symbol))
        {
            std::cout << "[" << i << "] " << symbol->Name << " +0x" << std::hex << displacement
                << " - 0x" << frame.AddrPC.Offset << std::dec << "\n";
        }
        else
        {
            HMODULE mod = nullptr;
            GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS,
                (LPCSTR)frame.AddrPC.Offset, &mod);
            char modName[MAX_PATH] = "?";
            if (mod) GetModuleFileNameA(mod, modName, MAX_PATH);
            std::cout << "[" << i << "] [Unknown Symbol] - 0x" << std::hex << frame.AddrPC.Offset
                << std::dec << " (module: " << modName << ")\n";
        }
    }
    std::cout << "=== END CRASH DIAGNOSTICS ===\n";

    return EXCEPTION_CONTINUE_SEARCH;
}

void dumpStackTrace() {
    HANDLE process = GetCurrentProcess();

    void* stack[62];
    WORD frames = CaptureStackBackTrace(1, 62, stack, NULL);

    char symbolBuffer[sizeof(SYMBOL_INFO) + MAX_SYM_NAME * sizeof(TCHAR)];
    PSYMBOL_INFO symbol = (PSYMBOL_INFO)symbolBuffer;
    symbol->SizeOfStruct = sizeof(SYMBOL_INFO);
    symbol->MaxNameLen = MAX_SYM_NAME;

    std::cout << "--- Stack Trace ---\n";

    for (WORD i = 0; i < frames; i++) {
        DWORD64 address = (DWORD64)(stack[i]);

        if (SymFromAddr(process, address, 0, symbol)) {
            std::cout << "[" << i << "] " << symbol->Name
                << " - 0x" << std::hex << symbol->Address << std::dec << '\n';

            // Stop printing after we display CAkBankMgr::LoadBank
            if (std::string_view(symbol->Name).rfind("CAkBankMgr::LoadBank", 0) == 0) {
                break;
            }
        }
        else {
            std::cout << "[" << i << "] [Unknown Symbol] - 0x"
                << std::hex << address << std::dec << '\n';
        }
    }
}

// -----------------------------------------------------------------
// Required memory allocation hooks (Wwise delegates these to the app)
// -----------------------------------------------------------------
namespace AK
{
    void* AllocHook(size_t in_size)            { return malloc(in_size); }
    void  FreeHook(void* in_ptr)               { free(in_ptr); }
    void* VirtualAllocHook(void* in_pMemAddress, size_t in_size,
                            DWORD in_dwAllocationType, DWORD in_dwProtect)
    {
        return VirtualAlloc(in_pMemAddress, in_size, in_dwAllocationType, in_dwProtect);
    }
    void  VirtualFreeHook(void* in_pMemAddress, size_t in_size, DWORD in_dwFreeType)
    {
        VirtualFree(in_pMemAddress, in_size, in_dwFreeType);
    }
}

// -----------------------------------------------------------------
// CLI arguments
// -----------------------------------------------------------------
static bool TryGetBankFileFromArgs(int argc, wchar_t* argv[], std::wstring& outPath)
{
    for (int i = 1; i < argc; i++)
    {
        if ((wcscmp(argv[i], L"--file") == 0 || wcscmp(argv[i], L"-f") == 0) && i + 1 < argc)
        {
            outPath = argv[i + 1];
            return true;
        }
    }

    return false;
}

static bool IsTracingEnabled(int argc, wchar_t* argv[])
{
    for (int i = 1; i < argc; i++)
    {
        if ((wcscmp(argv[i], L"--trace") == 0 || wcscmp(argv[i], L"-t") == 0) && i + 1 < argc)
        {
            return true;
        }
    }

    return false;
}

// -----------------------------------------------------------------
// Helper: convert AKRESULT to a human-readable string
// (only values present in Wwise 2019.1 SDK)
// -----------------------------------------------------------------
static const char* AkResultToString(AKRESULT result)
{
    switch (result)
    {
    case AK_NotImplemented:             return "AK_NotImplemented";
    case AK_Success:                    return "AK_Success";
    case AK_Fail:                       return "AK_Fail";
    case AK_PartialSuccess:             return "AK_PartialSuccess";
    case AK_NotCompatible:              return "AK_NotCompatible";
    case AK_AlreadyConnected:           return "AK_AlreadyConnected";
    case AK_InvalidFile:                return "AK_InvalidFile";
    case AK_AudioFileHeaderTooLarge:    return "AK_AudioFileHeaderTooLarge";
    case AK_MaxReached:                 return "AK_MaxReached";
    case AK_InvalidID:                  return "AK_InvalidID";
    case AK_IDNotFound:                 return "AK_IDNotFound";
    case AK_InvalidInstanceID:          return "AK_InvalidInstanceID";
    case AK_NoMoreData:                 return "AK_NoMoreData";
    case AK_InvalidStateGroup:          return "AK_InvalidStateGroup";
    case AK_ChildAlreadyHasAParent:     return "AK_ChildAlreadyHasAParent";
    case AK_InvalidLanguage:            return "AK_InvalidLanguage";
    case AK_CannotAddItseflAsAChild:    return "AK_CannotAddItseflAsAChild";
    case AK_InvalidParameter:           return "AK_InvalidParameter";
    case AK_ElementAlreadyInList:       return "AK_ElementAlreadyInList";
    case AK_PathNotFound:               return "AK_PathNotFound";
    case AK_PathNoVertices:             return "AK_PathNoVertices";
    case AK_PathNotRunning:             return "AK_PathNotRunning";
    case AK_PathNotPaused:              return "AK_PathNotPaused";
    case AK_PathNodeAlreadyInList:      return "AK_PathNodeAlreadyInList";
    case AK_PathNodeNotInList:          return "AK_PathNodeNotInList";
    case AK_DataNeeded:                 return "AK_DataNeeded";
    case AK_NoDataNeeded:               return "AK_NoDataNeeded";
    case AK_DataReady:                  return "AK_DataReady";
    case AK_NoDataReady:                return "AK_NoDataReady";
    case AK_InsufficientMemory:         return "AK_InsufficientMemory";
    case AK_Cancelled:                  return "AK_Cancelled";
    case AK_UnknownBankID:              return "AK_UnknownBankID";
    case AK_BankReadError:              return "AK_BankReadError";
    case AK_InvalidSwitchType:          return "AK_InvalidSwitchType";
    case AK_FormatNotReady:             return "AK_FormatNotReady";
    case AK_WrongBankVersion:           return "AK_WrongBankVersion";
    case AK_FileNotFound:               return "AK_FileNotFound";
    case AK_DeviceNotReady:             return "AK_DeviceNotReady";
    case AK_BankAlreadyLoaded:          return "AK_BankAlreadyLoaded";
    case AK_RenderedFX:                 return "AK_RenderedFX";
    case AK_ProcessNeeded:              return "AK_ProcessNeeded";
    case AK_ProcessDone:                return "AK_ProcessDone";
    case AK_MemManagerNotInitialized:   return "AK_MemManagerNotInitialized";
    case AK_StreamMgrNotInitialized:    return "AK_StreamMgrNotInitialized";
    case AK_SSEInstructionsNotSupported:return "AK_SSEInstructionsNotSupported";
    case AK_Busy:                       return "AK_Busy";
    case AK_UnsupportedChannelConfig:   return "AK_UnsupportedChannelConfig";
    case AK_PluginMediaNotAvailable:    return "AK_PluginMediaNotAvailable";
    case AK_MustBeVirtualized:          return "AK_MustBeVirtualized";
    case AK_CommandTooLarge:            return "AK_CommandTooLarge";
    case AK_RejectedByFilter:           return "AK_RejectedByFilter";
    case AK_InvalidCustomPlatformName:  return "AK_InvalidCustomPlatformName";
    case AK_DLLCannotLoad:              return "AK_DLLCannotLoad";
    case AK_DLLPathNotFound:            return "AK_DLLPathNotFound";
    case AK_NoJavaVM:                   return "AK_NoJavaVM";
    case AK_OpenSLError:                return "AK_OpenSLError";
    case AK_PluginNotRegistered:        return "AK_PluginNotRegistered";
    case AK_DataAlignmentError:         return "AK_DataAlignmentError";
    case AK_DeviceNotCompatible:        return "AK_DeviceNotCompatible";
    case AK_DuplicateUniqueID:          return "AK_DuplicateUniqueID";
    case AK_InitBankNotLoaded:          return "AK_InitBankNotLoaded";
    case AK_DeviceNotFound:             return "AK_DeviceNotFound";
    default:                            return "AK_Unknown";
    }
}

// Define the custom assert callback function
void MyCustomAssertHook(const char* in_pszExpression, const char* in_pszFileName, int in_lineNumber)
{
    // Print detailed error information to your console or log file
    std::fprintf(stderr, "[Wwise Assert Failed] %s (%s:%d)\n",
        in_pszExpression, in_pszFileName, in_lineNumber);

    // Trigger a debug break or abort execution if desired
    // std::abort();
}

// -----------------------------------------------------------------
// Example hooks — copy this pattern for each Wwise method you want to intercept.
//
// HOW TO FIND A SYMBOL NAME
//   In the output directory, run:
//     dumpbin /SYMBOLS WwiseHook.pdb | findstr "FunctionName"
//   or browse WwiseHook.pdb in Visual Studio's Object Browser.
//   Pass the decorated name (starts with '?') for C++ methods.
//
// PATTERN
//   using MyFn_t = <ReturnType>(<CallingConv>*)(<Params>);
//   WH_DECLARE_TRAMPOLINE(MyFn_t, MyFn);   // produces: MyFn_Original
//
//   <ReturnType> My_MyFn(<Params>)
//   {
//       // inspect inputs ...
//       <ReturnType> r = MyFn_Original(<args>);
//       // inspect result ...
//       return r;
//   }
//
//   Then in wmain, after WH_InitHooks():
//   WH_INSTALL_HOOK("MyFn", "?MyFn@...", My_MyFn, &MyFn_Original);
// -----------------------------------------------------------------

using MonitorPostString_t = void(__cdecl*)(wchar_t* param_1, int param_2, unsigned int param_3, void* param_4, void* param_5, bool param_6);
WH_DECLARE_TRAMPOLINE(MonitorPostString_t, MonitorPostString);

void MonitorPostString(wchar_t* param_1, int param_2, unsigned int param_3, void* param_4, void* param_5, bool param_6)
{
    auto msg = std::wstring(param_1);
    if (msg.starts_with(L"Master bus")) {
        printf("FF");
    }
    printf("[HOOK] Monitor_PostString called: %ls\n", param_1);
    MonitorPostString_Original(param_1, param_2, param_3, param_4, param_5, param_6);
}

using GetData_t = void(__cdecl*)(void* cAkBankReaderSelf, unsigned long param1);
GetData_t GetData_Original = nullptr;

void GetData(void* cAkBankReaderSelf, unsigned long param1)
{
    std::cout << "Reading size: " << param1 << std::endl;
    dumpStackTrace();
    GetData_Original(cAkBankReaderSelf, param1);
}

using GetNodePtrAndAddRef_t = void*(*)(void*, unsigned long param1, AkNodeType param2);
GetNodePtrAndAddRef_t GetNodePtrAndAddRef_Original = nullptr;

void* GetNodePtrAndAddRef(void* self, unsigned long param1, AkNodeType param2)
{
    std::cout << "Looking up type " << param2 << " with id " << /*std::hex <<*/ param1 << std::endl;
    auto res = GetNodePtrAndAddRef_Original(self, param1, param2);
    return res;
}

// -----------------------------------------------------------------
// Low-level IO hook instance (blocking, simple, no file packages)
static CAkDefaultIOHookBlocking g_lowLevelIO;

// -----------------------------------------------------------------
// DynamoRIO tracing setup
// -----------------------------------------------------------------
using dr_app_setup_fn = int(__cdecl*)(void);
using dr_app_start_fn = void(__cdecl*)(void);
using dr_app_stop_fn = void(__cdecl*)(void);
using dr_app_cleanup_fn = int(__cdecl*)(void);

struct DynamoRioApi
{
    HMODULE module = nullptr;
    dr_app_setup_fn setup = nullptr;
    dr_app_start_fn start = nullptr;
    dr_app_stop_fn stop = nullptr;
    dr_app_cleanup_fn cleanup = nullptr;
};

static DynamoRioApi g_dynamoRioApi;

static bool InitExecutionTracing(std::wstring& outLogDir)
{
    namespace fs = std::filesystem;

    const fs::path dynamoRioRoot = LR"(B:\UserProfile\Downloads\DynamoRIO-Windows-11.3.0-1)";
    const fs::path dynamoRioDllPath = dynamoRioRoot / LR"(lib64\release\dynamorio.dll)";
    const fs::path drcovClientPath = dynamoRioRoot / LR"(tools\lib64\release\drcov.dll)";

    if (!fs::exists(dynamoRioDllPath))
    {
        std::wcerr << L"[ERROR] DynamoRIO runtime not found: " << dynamoRioDllPath.wstring() << L"\n";
        return false;
    }

    if (!fs::exists(drcovClientPath))
    {
        std::wcerr << L"[ERROR] DynamoRIO drcov client not found: " << drcovClientPath.wstring() << L"\n";
        return false;
    }

    std::error_code dirError;
    const fs::path traceLogDir = fs::current_path() / L"dynamorio-trace";
    fs::create_directories(traceLogDir, dirError);
    if (dirError)
    {
        std::wcerr << L"[ERROR] Could not create trace output directory: " << traceLogDir.wstring() << L"\n";
        return false;
    }
    // Convert paths to generic wstring (uses forward slashes '/')
    const std::wstring clientPathStr = drcovClientPath.generic_wstring();
    const std::wstring logDirStr = traceLogDir.generic_wstring();

    // Format: -code_api -client_lib "path/to/drcov.dll;0;-logdir path/to/trace"
    const std::wstring options =
        L"-code_api -client_lib \"" + clientPathStr + L";0;-logdir " + logDirStr + L"\"";

    if (_wputenv_s(L"DYNAMORIO_HOME", dynamoRioRoot.c_str()) != 0)
    {
        std::cerr << "[ERROR] Failed to set DYNAMORIO_HOME.\n";
        return false;
    }

    if (_wputenv_s(L"DYNAMORIO_OPTIONS", options.c_str()) != 0)
    {
        std::cerr << "[ERROR] Failed to set DYNAMORIO_OPTIONS.\n";
        return false;
    }

    g_dynamoRioApi.module = LoadLibraryW(dynamoRioDllPath.c_str());
    if (!g_dynamoRioApi.module)
    {
        std::wcerr << L"[ERROR] Failed to load DynamoRIO runtime: " << dynamoRioDllPath.wstring() << L"\n";
        return false;
    }

    g_dynamoRioApi.setup = reinterpret_cast<dr_app_setup_fn>(GetProcAddress(g_dynamoRioApi.module, "dr_app_setup"));
    g_dynamoRioApi.start = reinterpret_cast<dr_app_start_fn>(GetProcAddress(g_dynamoRioApi.module, "dr_app_start"));
    g_dynamoRioApi.stop = reinterpret_cast<dr_app_stop_fn>(GetProcAddress(g_dynamoRioApi.module, "dr_app_stop"));
    g_dynamoRioApi.cleanup = reinterpret_cast<dr_app_cleanup_fn>(GetProcAddress(g_dynamoRioApi.module, "dr_app_cleanup"));

    if (!g_dynamoRioApi.setup || !g_dynamoRioApi.start || !g_dynamoRioApi.stop || !g_dynamoRioApi.cleanup)
    {
        std::cerr << "[ERROR] Failed to resolve one or more DynamoRIO app API exports.\n";
        FreeLibrary(g_dynamoRioApi.module);
        g_dynamoRioApi = {};
        return false;
    }

    const int setupResult = g_dynamoRioApi.setup();
    if (setupResult != 0)
    {
        std::cerr << "[ERROR] dr_app_setup failed with code " << setupResult << ".\n";
        FreeLibrary(g_dynamoRioApi.module);
        g_dynamoRioApi = {};
        return false;
    }

    outLogDir = traceLogDir.wstring();
    return true;
}

static void StartExecutionTracing()
{
    if (g_dynamoRioApi.start)
        g_dynamoRioApi.start();
}

static void StopExecutionTracing()
{
    if (g_dynamoRioApi.stop)
        g_dynamoRioApi.stop();

    if (g_dynamoRioApi.cleanup)
        g_dynamoRioApi.cleanup();

    if (g_dynamoRioApi.module)
        FreeLibrary(g_dynamoRioApi.module);

    g_dynamoRioApi = {};
}

// -----------------------------------------------------------------
// Wwise initialisation
// -----------------------------------------------------------------
static bool InitWwise()
{
    // 1. Memory Manager — AkMemSettings default ctor sets sensible defaults
    AkMemSettings memSettings;
    if (AK::MemoryMgr::Init(&memSettings) != AK_Success)
    {
        std::cerr << "[ERROR] Could not initialise the Memory Manager.\n";
        return false;
    }

    // 2. Streaming Manager
    AkStreamMgrSettings stmSettings;
    AK::StreamMgr::GetDefaultSettings(stmSettings);
    if (!AK::StreamMgr::Create(stmSettings))
    {
        std::cerr << "[ERROR] Could not create the Streaming Manager.\n";
        return false;
    }

    // 3. Default low-level I/O hook (blocking)
    AkDeviceSettings deviceSettings;
    AK::StreamMgr::GetDefaultDeviceSettings(deviceSettings);
    if (g_lowLevelIO.Init(deviceSettings) != AK_Success)
    {
        std::cerr << "[ERROR] Could not initialise the low-level IO hook.\n";
        return false;
    }

    // 4. Sound Engine
    AkInitSettings     initSettings;
    AkPlatformInitSettings platSettings;
    AK::SoundEngine::GetDefaultInitSettings(initSettings);
    AK::SoundEngine::GetDefaultPlatformInitSettings(platSettings);
	initSettings.pfnAssertHook = MyCustomAssertHook; // Set custom assert hook
    if (AK::SoundEngine::Init(&initSettings, &platSettings) != AK_Success)
    {
        std::cerr << "[ERROR] Could not initialise the Sound Engine.\n";
        return false;
    }

    // 5. Music Engine
    AkMusicSettings musicSettings;
    AK::MusicEngine::GetDefaultInitSettings(musicSettings);
    if (AK::MusicEngine::Init(&musicSettings) != AK_Success)
    {
        std::cerr << "[ERROR] Could not initialise the Music Engine.\n";
        return false;
    }

    // 6. Default listener. Every real game registers at least one (typically the camera) before doing
    // anything else with 3D audio - without it, the SDK's internal default listener-association set is
    // never allocated, and any later call that touches per-object listener overrides (AddListener,
    // SetGameObjectOutputBusVolume, etc.) dereferences a null pointer and crashes
    // (CAkConnectedListeners::CloneAndOverrideUserDefault -> GetUserAssocs). This was a real gap in this
    // tool, not a Wwise SDK bug: a real game's engine integration always sets this up during startup.
    constexpr AkGameObjectID kDefaultListenerObject = 1;
    AKRESULT listenerRegResult = AK::SoundEngine::RegisterGameObj(kDefaultListenerObject, "DefaultListener");
    if (listenerRegResult != AK_Success)
    {
        std::cerr << "[ERROR] Could not register the default listener game object.\n";
        return false;
    }
    if (AK::SoundEngine::AddDefaultListener(kDefaultListenerObject) != AK_Success)
    {
        std::cerr << "[ERROR] Could not add the default listener.\n";
        return false;
    }

    return true;
}

// -----------------------------------------------------------------
// Wwise termination (reverse order)
// -----------------------------------------------------------------
static void TermWwise()
{
    AK::MusicEngine::Term();

    if (AK::SoundEngine::IsInitialized())
        AK::SoundEngine::Term();

    if (AK::IAkStreamMgr::Get())
    {
        g_lowLevelIO.Term();
        AK::IAkStreamMgr::Get()->Destroy();
    }

    if (AK::MemoryMgr::IsInitialized())
        AK::MemoryMgr::Term();
}

// -----------------------------------------------------------------
// Extract directory and filename from a full path
// -----------------------------------------------------------------
static std::wstring GetDirectory(const std::wstring& path)
{
    size_t pos = path.find_last_of(L"\\/");
    return (pos != std::wstring::npos) ? path.substr(0, pos + 1) : L".\\";
}

static std::wstring GetFilename(const std::wstring& path)
{
    size_t pos = path.find_last_of(L"\\/");
    return (pos != std::wstring::npos) ? path.substr(pos + 1) : path;
}

// -----------------------------------------------------------------
// Load a bank by filename (sets base path first).
// The IO hook combines basePath + filename to open the file.
// -----------------------------------------------------------------
static AKRESULT LoadBankByPath(const wchar_t* fullPath, AkBankID& out_bankID)
{
    std::wstring dir = GetDirectory(fullPath);
    std::wstring filename = GetFilename(fullPath);

    g_lowLevelIO.SetBasePath(dir.c_str());

    // Wwise 2019.1 LoadBank signature:
    //   LoadBank(const wchar_t* name, AkMemPoolId memPoolId, AkBankID& out_id)
    return AK::SoundEngine::LoadBank(filename.c_str(), AK_DEFAULT_POOL_ID, out_bankID);
}

static void PrintAkActionResult(const char* action, AKRESULT result)
{
    std::cout << action << ": " << AkResultToString(result)
              << " (" << static_cast<int>(result) << ")\n";
}

static bool TryReadU32(const std::vector<uint8_t>& bytes, size_t offset, uint32_t& outValue)
{
    if (offset + sizeof(uint32_t) > bytes.size())
        return false;

    outValue = static_cast<uint32_t>(bytes[offset]) |
        (static_cast<uint32_t>(bytes[offset + 1]) << 8) |
        (static_cast<uint32_t>(bytes[offset + 2]) << 16) |
        (static_cast<uint32_t>(bytes[offset + 3]) << 24);

    return true;
}

static bool ExtractEventIdsFromBank(const std::wstring& bankPath, std::vector<AkUniqueID>& outEventIds, std::string& outError)
{
    std::ifstream stream(bankPath, std::ios::binary | std::ios::ate);
    if (!stream)
    {
        outError = "failed to open bank file";
        return false;
    }

    const std::streamoff size = stream.tellg();
    if (size <= 0)
    {
        outError = "bank file is empty";
        return false;
    }

    std::vector<uint8_t> bytes(static_cast<size_t>(size));
    stream.seekg(0, std::ios::beg);
    if (!stream.read(reinterpret_cast<char*>(bytes.data()), size))
    {
        outError = "failed to read bank file bytes";
        return false;
    }

    bool foundHirc = false;
    size_t chunkOffset = 0;

    while (chunkOffset + 8 <= bytes.size())
    {
        const char c0 = static_cast<char>(bytes[chunkOffset]);
        const char c1 = static_cast<char>(bytes[chunkOffset + 1]);
        const char c2 = static_cast<char>(bytes[chunkOffset + 2]);
        const char c3 = static_cast<char>(bytes[chunkOffset + 3]);

        uint32_t chunkSize = 0;
        if (!TryReadU32(bytes, chunkOffset + 4, chunkSize))
        {
            outError = "failed to read chunk size";
            return false;
        }

        const size_t payloadOffset = chunkOffset + 8;
        const size_t chunkEnd = payloadOffset + static_cast<size_t>(chunkSize);
        if (chunkEnd > bytes.size())
        {
            outError = "invalid chunk bounds in bank file";
            return false;
        }

        if (c0 == 'H' && c1 == 'I' && c2 == 'R' && c3 == 'C')
        {
            foundHirc = true;

            uint32_t objectCount = 0;
            if (payloadOffset + sizeof(uint32_t) > chunkEnd || !TryReadU32(bytes, payloadOffset, objectCount))
            {
                outError = "invalid HIRC header";
                return false;
            }

            size_t objectOffset = payloadOffset + sizeof(uint32_t);
            for (uint32_t i = 0; i < objectCount; ++i)
            {
                if (objectOffset + 5 > chunkEnd)
                {
                    outError = "invalid HIRC object bounds";
                    return false;
                }

                const uint8_t objectType = bytes[objectOffset];
                uint32_t objectLength = 0;
                if (!TryReadU32(bytes, objectOffset + 1, objectLength))
                {
                    outError = "invalid HIRC object length";
                    return false;
                }

                const size_t objectDataOffset = objectOffset + 5;
                const size_t objectEnd = objectDataOffset + static_cast<size_t>(objectLength);
                if (objectEnd > chunkEnd)
                {
                    outError = "HIRC object exceeds chunk size";
                    return false;
                }

                if (objectType == 4 && objectLength >= sizeof(uint32_t))
                {
                    uint32_t eventId = 0;
                    if (!TryReadU32(bytes, objectDataOffset, eventId))
                    {
                        outError = "failed to read event ID";
                        return false;
                    }

                    if (std::find(outEventIds.begin(), outEventIds.end(), static_cast<AkUniqueID>(eventId)) == outEventIds.end())
                        outEventIds.push_back(static_cast<AkUniqueID>(eventId));
                }

                objectOffset = objectEnd;
            }

            break;
        }

        chunkOffset = chunkEnd;
    }

    if (!foundHirc)
    {
        outError = "no HIRC chunk found in bank";
        return false;
    }

    return true;
}

static void PumpAudioForMs(DWORD milliseconds)
{
    constexpr DWORD frameMs = 16;
    DWORD elapsed = 0;

    while (elapsed < milliseconds)
    {
        AK::SoundEngine::RenderAudio();
        Sleep(frameMs);
        elapsed += frameMs;
    }
}

static AKRESULT ValidateBankEventsAtZeroVolume(const std::vector<AkUniqueID>& eventIds)
{
    if (eventIds.empty())
    {
        std::cout << "[INFO] No event objects found in HIRC; nothing to post.\n";
        return AK_Success;
    }

    constexpr AkGameObjectID validationGameObject = 0xC0FFEE;
    // NOTE: this function's name is legacy; it no longer mutes. SetGameObjectOutputBusVolume takes a
    // linear multiplier (0 = silent, 1 = unchanged) applied at the listener connection - AFTER decode -
    // but a 0.0 value can still cause Wwise's voice virtualization to treat the voice as inaudible and
    // skip decode entirely (via AdvSettings eBelowThresholdBehavior), which would silently skip the
    // exact Vorbis-decode code path we need this validation to exercise. Use 1.0 (no attenuation) so
    // decode is never skipped for that reason.

    AKRESULT registerResult = AK::SoundEngine::RegisterGameObj(validationGameObject, "SilentValidation");
    PrintAkActionResult("[ACTION] RegisterGameObj", registerResult);
    if (registerResult != AK_Success)
        return registerResult;

    // SetGameObjectOutputBusVolume needs at least one associated listener to clone/override gain onto -
    // without one, CAkConnectedListeners::CloneAndOverrideUserDefault dereferences a null default
    // listener set and crashes (this is a WwiseHook test-harness gap, not the game's own setup: a real
    // game always has a listener registered on the camera/player). Register + attach one here.
    constexpr AkGameObjectID validationListenerObject = 0xC0FFEE1;
    AKRESULT listenerRegisterResult = AK::SoundEngine::RegisterGameObj(validationListenerObject, "SilentValidationListener");
    PrintAkActionResult("[ACTION] RegisterGameObj(listener)", listenerRegisterResult);

    AKRESULT addListenerResult = AK::SoundEngine::AddListener(validationGameObject, validationListenerObject);
    PrintAkActionResult("[ACTION] AddListener", addListenerResult);

    AKRESULT volumeResult = AK::SoundEngine::SetGameObjectOutputBusVolume(validationGameObject, AK_INVALID_GAME_OBJECT, 1.0f);
    PrintAkActionResult("[ACTION] SetGameObjectOutputBusVolume(1.0, forces real decode)", volumeResult);

    AKRESULT finalResult = (volumeResult == AK_Success) ? AK_Success : volumeResult;

    for (AkUniqueID eventId : eventIds)
    {
        const AkPlayingID playingId = AK::SoundEngine::PostEvent(eventId, validationGameObject);
        std::cout << "[ACTION] PostEvent(" << eventId << ") => PlayingID " << playingId << "\n";

        if (playingId == AK_INVALID_PLAYING_ID)
        {
            if (finalResult == AK_Success)
                finalResult = AK_Fail;
            continue;
        }

        PumpAudioForMs(150);

        AKRESULT stopResult = AK::SoundEngine::ExecuteActionOnEvent(
            eventId,
            AK::SoundEngine::AkActionOnEventType_Stop,
            validationGameObject,
            0,
            AkCurveInterpolation_Linear);

        std::cout << "[ACTION] ExecuteActionOnEvent(Stop, " << eventId << "): "
                  << AkResultToString(stopResult)
                  << " (" << static_cast<int>(stopResult) << ")\n";

        if (stopResult != AK_Success && finalResult == AK_Success)
            finalResult = stopResult;

        PumpAudioForMs(50);
    }

    AKRESULT unregisterResult = AK::SoundEngine::UnregisterGameObj(validationGameObject);
    PrintAkActionResult("[ACTION] UnregisterGameObj", unregisterResult);
    AK::SoundEngine::UnregisterGameObj(validationListenerObject);

    if (unregisterResult != AK_Success && finalResult == AK_Success)
        finalResult = unregisterResult;

    return finalResult;
}

struct EnumCtx { const char* target; };

BOOL CALLBACK EnumCallback(PSYMBOL_INFO pSymInfo, ULONG SymbolSize, PVOID UserContext)
{
    printf("[found] tag=%lu  %p  %s\n",
        pSymInfo->Tag, (void*)(uintptr_t)pSymInfo->Address, pSymInfo->Name);
    return TRUE;
}

EXTERN_C IMAGE_DOS_HEADER __ImageBase;

// -----------------------------------------------------------------
// main
// -----------------------------------------------------------------
int wmain(int argc, wchar_t* argv[])
{
    // Force every std::cout/std::wcout insertion to flush immediately. Without this, output is fully
    // buffered when redirected to a file/pipe, so a crash (segfault) can silently discard everything
    // written since the last flush - making it look like the crash happened much earlier than it did.
    std::cout.setf(std::ios::unitbuf);
    std::wcout.setf(std::ios::unitbuf);
    std::cerr.setf(std::ios::unitbuf);

    SymInitialize(GetCurrentProcess(), nullptr, TRUE);
    AddVectoredExceptionHandler(1, CrashDiagnosticsHandler);

    std::wstring bankFilePath;
    if (!TryGetBankFileFromArgs(argc, argv, bankFilePath))
    {
        std::cerr << "[ERROR] Missing required --file parameter.\n";
        std::cerr << "Usage: WwiseHook.exe --file <path-to-bank.bnk>\n";
        return 2;
    }

	auto isTracing = IsTracingEnabled(argc, argv);

    std::wcout << L"WwiseHook - Bank Loader (Wwise 2019.1.6)\n";
    std::wcout << L"Bank file : " << bankFilePath << L"\n\n";


    if (!InitWwise())
    {
        std::cerr << "[ERROR] Wwise initialisation failed. Exiting.\n";
        return 1;
    }
    std::cout << "[INFO] Wwise initialised successfully.\n\n";

    // Wwise requires Init.bnk to be loaded before any content bank.
    // Try to load it from the same directory as the target bank.
    {
        std::wstring dir = GetDirectory(bankFilePath);
        std::wstring initBankPath = dir + L"Init.bnk";
        AkBankID initBankID = AK_INVALID_BANK_ID;
        AKRESULT initResult = LoadBankByPath(initBankPath.c_str(), initBankID);
        std::wcout << L"[INFO] Init.bnk load: ";
        std::cout << AkResultToString(initResult)
                  << " (" << static_cast<int>(initResult) << ")\n";
        if (initResult != AK_Success && initResult != AK_BankAlreadyLoaded)
        {
            std::cout << "[WARN] Init.bnk failed to load — the content bank may fail too.\n";
        }
    }

    std::wstring traceLogDir;
    if (isTracing && !InitExecutionTracing(traceLogDir))
    {
        TermWwise();
        return 3;
    }

    if (isTracing) {
        std::wcout << L"[INFO] DynamoRIO drcov tracing configured. Logs dir: " << traceLogDir << L"\n";
    }

    // ---- Hook setup -------------------------------------------------------
   // Hooks must be installed and enabled BEFORE InitWwise so they are active
   // for every Wwise SDK call made during initialisation and bank loading.
    if (WH_InitHooks())
    {
        // Register hooks here.  Symbol names must match the PDB exactly.
        // Use: dumpbin /SYMBOLS WwiseHook.pdb | findstr "FunctionName"
        //
        WH_INSTALL_HOOK("Monitor_PostString",
            "?Monitor_PostString@AkMonitor@@SAXPEB_WW4ErrorLevel@Monitor@AK@@K_KK_N@Z",
            MonitorPostString, &MonitorPostString_Original);

        WH_INSTALL_HOOK("BankReaderGetData",
            "?GetData@CAkBankReader@@QEAAPEBXK@Z",
            GetData, &GetData_Original);

		WH_INSTALL_HOOK("GetNodePtrAndAddRef",
			"?GetNodePtrAndAddRef@CAkAudioLibIndex@@QEAAPEAVCAkParameterNodeBase@@KW4AkNodeType@@@Z",
			GetNodePtrAndAddRef, &GetNodePtrAndAddRef_Original);

        //IMAGEHLP_MODULE64 modInfo = { sizeof(IMAGEHLP_MODULE64) };
        //SymGetModuleInfo64(GetCurrentProcess(), reinterpret_cast<uintptr_t>(&__ImageBase), &modInfo);
        //printf("SymType = %d\n", modInfo.SymType); // want SymPdb (== 6), not SymExport/SymDeferred

        //// after SymInitialize(...)
        //SymEnumSymbols(GetCurrentProcess(), 0, "*", EnumCallback, nullptr);

        WH_EnableAllHooks();
    }
    // -----------------------------------------------------------------------

    // Load the target bank
    if (isTracing) {
        StartExecutionTracing();
    }

    AkBankID bankID = AK_INVALID_BANK_ID;
    AKRESULT result = LoadBankByPath(bankFilePath.c_str(), bankID);

    if (isTracing) {
        StopExecutionTracing();
    }

    std::cout << "\n--- Bank Load Result ---\n";
    PrintAkActionResult("[ACTION] LoadBank", result);
    std::cout << "RESULT_TOKEN:" << AkResultToString(result) << "\n";

    AKRESULT finalResult = result;

    if (result == AK_Success)
    {
        std::cout << "Bank ID  : " << bankID << "\n";
        std::wcout << L"File     : " << bankFilePath << L"\n";
        std::cout << "\n[INFO] Bank loaded successfully.\n";

        std::vector<AkUniqueID> eventIds;
        std::string parseError;
        if (!ExtractEventIdsFromBank(bankFilePath, eventIds, parseError))
        {
            std::cerr << "[ERROR] Failed to parse event IDs from bank: " << parseError << "\n";
            finalResult = AK_Fail;
        }
        else
        {
            std::cout << "[INFO] Parsed " << eventIds.size() << " event(s) from bank HIRC.\n";
            AKRESULT eventValidationResult = ValidateBankEventsAtZeroVolume(eventIds);
            PrintAkActionResult("[ACTION] ValidateBankEventsAtZeroVolume", eventValidationResult);
            if (eventValidationResult != AK_Success)
                finalResult = eventValidationResult;
        }

        AKRESULT unloadResult = AK::SoundEngine::UnloadBank(bankID, nullptr);
        PrintAkActionResult("[ACTION] UnloadBank", unloadResult);
        if (unloadResult != AK_Success && finalResult == AK_Success)
            finalResult = unloadResult;
    }
    else
    {
        std::cerr << "[ERROR] Bank load failed: " << AkResultToString(result) << "\n";
    }

    TermWwise();
    std::cout << "\n[INFO] Wwise terminated.\n";

    WH_ShutdownHooks();

    // Returns the final action status code.
    return finalResult;
}

