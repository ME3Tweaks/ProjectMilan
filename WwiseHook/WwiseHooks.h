// WwiseHooks.h — MinHook + DbgHelp based method hooking for WwiseHook.exe
//
// Quick-start
// -----------
//  1.  Call WH_InitHooks() once, BEFORE InitWwise().
//  2.  Declare a typed trampoline variable with WH_DECLARE_TRAMPOLINE.
//  3.  Write your detour function with the same signature and calling convention.
//  4.  Register each hook with WH_INSTALL_HOOK (uses the symbol name from the PDB).
//  5.  Call WH_EnableAllHooks() — all hooks go live at once.
//  6.  Call WH_ShutdownHooks() on exit.
//
// Symbol names
// ------------
//  Pass the name exactly as it appears in the PDB.  Both decorated C++ names
//  (e.g. "?Init@SoundEngine@AK@@...") and plain C names are accepted.
//  You can confirm the spelling with:  dumpbin /SYMBOLS WwiseHook.pdb
//  or by examining the PDB in Visual Studio's Object Browser / in WinDbg.
//
// Example
// -------
//  // Declare the trampoline (one per hook, at file scope)
//  using LoadBank_t = AKRESULT(__cdecl*)(const wchar_t*, AkBankID&);
//  WH_DECLARE_TRAMPOLINE(LoadBank_t, LoadBank);
//
//  // Write the detour
//  AKRESULT My_LoadBank(const wchar_t* pszString, AkBankID& out_bankID)
//  {
//      printf("[HOOK] LoadBank called: %ls\n", pszString);
//      AKRESULT r = LoadBank_Original(pszString, out_bankID);
//      printf("[HOOK] LoadBank returned: %d\n", (int)r);
//      return r;
//  }
//
//  // In wmain, before InitWwise():
//  WH_InitHooks();
//  WH_INSTALL_HOOK("LoadBank", "?LoadBank@SoundEngine@AK@@...", My_LoadBank, &LoadBank_Original);
//  WH_EnableAllHooks();

#pragma once

#include <windows.h>

// ---------------------------------------------------------------------------
// API
// ---------------------------------------------------------------------------

// Initialise DbgHelp (PDB symbol loading) and MinHook.
// Must be called before any WH_INSTALL_HOOK / WH_EnableAllHooks call.
// Returns false and prints a diagnostic on failure.
bool WH_InitHooks();

// Look up 'symbol' in the current process's PDB, create a MinHook detour
// that redirects execution to 'hookFn', and stores the trampoline (so you
// can call the original) in *ppOriginal.
//
//  label     – human-readable name used in log messages
//  symbol    – symbol name as it appears in the PDB (decorated or plain)
//  hookFn    – pointer to your detour function
//  ppOriginal – receives the trampoline; cast from your typed fn-ptr with
//               reinterpret_cast<void**>(&MyFn_Original)
//
// Returns true on success; prints a diagnostic and returns false on failure.
bool WH_InstallHookBySymbol(const char* label, const char* symbol,
							 void* hookFn, void** ppOriginal);

// Enable every hook registered so far.  Call once after all WH_INSTALL_HOOK
// calls.  Returns false on failure.
bool WH_EnableAllHooks();

// Disable all hooks, uninitialise MinHook, and clean up DbgHelp.
void WH_ShutdownHooks();

// ---------------------------------------------------------------------------
// Convenience macros
// ---------------------------------------------------------------------------

// Declare a typed trampoline variable (file-scope, before using it in a hook).
//
//   fn_type – a function-pointer type alias  e.g.: using Foo_t = int(__cdecl*)(int)
//   name    – base name; produces  <name>_Original  of type fn_type, initialised to nullptr
//
// Example:
//   WH_DECLARE_TRAMPOLINE(LoadBank_t, LoadBank);
//   // → LoadBank_t LoadBank_Original = nullptr;
#define WH_DECLARE_TRAMPOLINE(fn_type, name) \
	fn_type name##_Original = nullptr

// Install a hook by PDB symbol name.
//
//   label    – string literal used in console diagnostics
//   symbol   – PDB symbol name string
//   hook_fn  – your detour function (bare function, no cast needed)
//   orig_ptr – address of your WH_DECLARE_TRAMPOLINE variable  (e.g. &LoadBank_Original)
//
// Example:
//   WH_INSTALL_HOOK("LoadBank", "?LoadBank@SoundEngine@AK@@...", My_LoadBank, &LoadBank_Original);
#define WH_INSTALL_HOOK(label, symbol, hook_fn, orig_ptr) \
	WH_InstallHookBySymbol((label), (symbol), \
		reinterpret_cast<void*>(hook_fn), \
		reinterpret_cast<void**>(orig_ptr))
