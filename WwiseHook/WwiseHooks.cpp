// WwiseHooks.cpp — Implementation of the MinHook + DbgHelp hooking layer.

#include "WwiseHooks.h"

#include <MinHook.h>
#include <dbghelp.h>
#include <cstdio>
#include <cstring>

#pragma comment(lib, "dbghelp.lib")

// ---------------------------------------------------------------------------
// Internal state
// ---------------------------------------------------------------------------
static bool g_dbgHelpInitialised = false;
static bool g_minHookInitialised = false;

// ---------------------------------------------------------------------------
// WH_InitHooks
// ---------------------------------------------------------------------------
bool WH_InitHooks()
{
	// DbgHelp — load symbols for every module already in the process
	// (includes the statically linked Wwise libs).
	SymSetOptions(SYMOPT_DEFERRED_LOADS | SYMOPT_LOAD_LINES);

	if (!SymInitialize(GetCurrentProcess(), nullptr, TRUE))
	{
		fprintf(stderr, "[WH] SymInitialize failed (error %lu). "
						"Hook symbol lookups will not work.\n",
				GetLastError());
		return false;
	}
	g_dbgHelpInitialised = true;

	// MinHook
	MH_STATUS mhStatus = MH_Initialize();
	if (mhStatus != MH_OK)
	{
		fprintf(stderr, "[WH] MH_Initialize failed: %s\n", MH_StatusToString(mhStatus));
		SymCleanup(GetCurrentProcess());
		g_dbgHelpInitialised = false;
		return false;
	}
	g_minHookInitialised = true;

	printf("[WH] Hook system initialised (DbgHelp + MinHook).\n");
	return true;
}

// ---------------------------------------------------------------------------
// WH_InstallHookBySymbol
// ---------------------------------------------------------------------------
bool WH_InstallHookBySymbol(const char* label, const char* symbol,
							  void* hookFn, void** ppOriginal)
{
	if (!g_dbgHelpInitialised || !g_minHookInitialised)
	{
		fprintf(stderr, "[WH] (%s) WH_InitHooks() must be called first.\n", label);
		return false;
	}

	// --- Step 1: resolve symbol address via DbgHelp ---
	// SYMBOL_INFO requires a trailing name buffer.
	constexpr DWORD kMaxNameLen = 512;
	char buffer[sizeof(SYMBOL_INFO) + kMaxNameLen * sizeof(char)] = {};
	SYMBOL_INFO* pSym = reinterpret_cast<SYMBOL_INFO*>(buffer);
	pSym->SizeOfStruct = sizeof(SYMBOL_INFO);
	pSym->MaxNameLen   = kMaxNameLen;

	if (!SymFromName(GetCurrentProcess(), symbol, pSym))
	{
		fprintf(stderr, "[WH] (%s) SymFromName(\"%s\") failed (error %lu). "
						"Check that the symbol name matches the PDB exactly.\n",
				label, symbol, GetLastError());
		return false;
	}

	void* targetAddr = reinterpret_cast<void*>(static_cast<uintptr_t>(pSym->Address));
	printf("[WH] (%s) Symbol resolved: %s  →  %p\n", label, symbol, targetAddr);

	// --- Step 2: create the MinHook detour ---
	MH_STATUS mhStatus = MH_CreateHook(targetAddr, hookFn, ppOriginal);
	if (mhStatus != MH_OK)
	{
		fprintf(stderr, "[WH] (%s) MH_CreateHook failed: %s\n",
				label, MH_StatusToString(mhStatus));
		return false;
	}

	printf("[WH] (%s) Hook registered (trampoline at %p).\n", label, *ppOriginal);
	return true;
}

// ---------------------------------------------------------------------------
// WH_EnableAllHooks
// ---------------------------------------------------------------------------
bool WH_EnableAllHooks()
{
	if (!g_minHookInitialised)
	{
		fprintf(stderr, "[WH] WH_EnableAllHooks: MinHook not initialised.\n");
		return false;
	}

	MH_STATUS mhStatus = MH_EnableHook(MH_ALL_HOOKS);
	if (mhStatus != MH_OK)
	{
		fprintf(stderr, "[WH] MH_EnableHook(ALL) failed: %s\n",
				MH_StatusToString(mhStatus));
		return false;
	}

	printf("[WH] All hooks enabled.\n");
	return true;
}

// ---------------------------------------------------------------------------
// WH_ShutdownHooks
// ---------------------------------------------------------------------------
void WH_ShutdownHooks()
{
	if (g_minHookInitialised)
	{
		MH_DisableHook(MH_ALL_HOOKS);
		MH_Uninitialize();
		g_minHookInitialised = false;
	}

	if (g_dbgHelpInitialised)
	{
		SymCleanup(GetCurrentProcess());
		g_dbgHelpInitialised = false;
	}

	printf("[WH] Hook system shut down.\n");
}
