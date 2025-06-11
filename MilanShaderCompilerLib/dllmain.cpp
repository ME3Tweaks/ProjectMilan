// dllmain.cpp : Defines the entry point for the DLL application.
#include "dllmain.h"
#include "D3DIncludes.h"
#include <iostream>

LIBRARY_API int CompileShader(const char* baseShaderName, const char* materialHlsl, const char* vertexFactoryName, const wchar_t* includesDirectory, D3D_SHADER_MACRO* macros , const char* entryPoint, const char* shaderType, 
	int& outShaderBytesSize,
	byte& outShaderBytes, 
	int& outErrorMsgSize,
	char& outErrorMsg) {
	MilanD3DInclude mIncludes;
	mIncludes.BaseShaderName = baseShaderName;
	mIncludes.MaterialHLSL = materialHlsl;
	mIncludes.VertexFactoryFilename = vertexFactoryName;
	mIncludes.ShaderSourcePath = includesDirectory;

	//cstd::cout << "----------------- MILAN SHADER COMPILER LIB -------------------------------\n";
	std::string shaderTypeStr = shaderType; //ps/vs
	shaderTypeStr = shaderTypeStr.append("_5_0"); //ps_5_0/vs_5_0

	//D3D_SHADER_MACRO* test = macros;
	//while (test != nullptr && test->Name != nullptr && test->Definition != nullptr) {
	//	std::cout << "new D3D_SHADER_MACRO(\"" << test->Name << "\", \"" << test->Definition << "\"),\n";
	//	test++;
	//}

	// Print the macros used for compile.
	D3D_SHADER_MACRO* test = macros;
	while (test != nullptr && test->Name != nullptr && test->Definition != nullptr) {
		std::cout << "      " << test->Name << "=" << test->Definition << "\n";
		test++;
	}


	return InternalCompileShader(mIncludes, macros, entryPoint, shaderTypeStr, outShaderBytesSize, outShaderBytes, outErrorMsgSize, outErrorMsg);
}


LIBRARY_API void GetShaderInfo(int shaderBufferSize, void* shaderBuffer, int& outInstructionCount) {
	// Currently only gets shader instruction count.

	ID3D11ShaderReflection* d3dReflector = NULL;
	D3DReflect(shaderBuffer, shaderBufferSize, IID_ID3D11ShaderReflection, (void**)&d3dReflector);

	// Get Shader Info
	D3D11_SHADER_DESC ShaderDesc;
	d3dReflector->GetDesc(&ShaderDesc);

	// Set the number of instructions.
	outInstructionCount = ShaderDesc.InstructionCount;

	// Dump the object.
	d3dReflector->Release();
}

int InternalCompileShader(MilanD3DInclude& includer, D3D_SHADER_MACRO* pDefines, std::string entryPoint, std::string shaderProfile, 
	int& outShaderLen,
	byte& outShaderBytes, 
	int& outErrorMsgLen, 
	char& outErrorMsg) {

	// Load base shader from disk.
	includer.LoadBaseShader();
	ID3DBlob* OutBlob = NULL;
	ID3DBlob* OutErrorBlob = NULL;

	// Some flags might be set by shader type, we probably need to pass this through
	auto flags = 36864; // BACKCOMPAT, OPTIMIZATION LEVEL 3

	/*
	std::cout << "SourceFileName: " << includer.BaseShaderName.c_str() << "\n";
	std::cout << "SrcLen: " << includer.BaseShaderLen << "\n";
	std::cout << "FunctionName: " << entryPoint.c_str() << "\n";
	std::cout << "Profile: " << shaderProfile.c_str() << "\n";
	std::cout << "Flags: " << flags << "\n";
	std::cout << includer.BaseShader << "\n";*/

	// D3D Modern
	HRESULT Result = D3DCompile(
		includer.BaseShader.c_str(),
		includer.BaseShader.size(),
		includer.BaseShaderName.c_str(),
		pDefines,
		&includer,
		entryPoint.c_str(),
		shaderProfile.c_str(),
		flags,
		0, // We don't use these.
		&OutBlob,
		&OutErrorBlob
	);

	if (FAILED(Result))
	{
		if (OutErrorBlob)
		{
			auto error = (char*)OutErrorBlob->GetBufferPointer();
			outErrorMsgLen = strlen(error);
			memcpy(&outErrorMsg, error, outErrorMsgLen);
		}
	}
	else {
		if (OutBlob)
		{
			outShaderLen = OutBlob->GetBufferSize();
			memcpy(&outShaderBytes, OutBlob->GetBufferPointer(), outShaderLen);

			// Also get number of instructions
			// https://learn.microsoft.com/en-us/windows/win32/api/d3d11shader/nn-d3d11shader-id3d11shaderreflection
			// Todo
		}
		else
		{
			outShaderLen = 0;
		}
	}
	return Result;
}

BOOL APIENTRY DllMain(HMODULE hModule,	DWORD  ul_reason_for_call,	LPVOID lpReserved)
{
	switch (ul_reason_for_call)
	{
	case DLL_PROCESS_ATTACH:
	case DLL_THREAD_ATTACH:
	case DLL_THREAD_DETACH:
	case DLL_PROCESS_DETACH:
		break;
	}
	return TRUE;
}

