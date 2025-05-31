// dllmain.cpp : Defines the entry point for the DLL application.
#include "dllmain.h"
#include "D3DIncludes.h"
#include <iostream>

int CompileShader(const char* baseShaderName, const char* materialHlsl, const char* vertexFactoryName, const wchar_t* includesDirectory, D3D_SHADER_MACRO* macros , const char* entryPoint, const char* shaderType) {
	MilanD3DInclude mIncludes;
	mIncludes.BaseShaderName = baseShaderName;
	mIncludes.MaterialHLSL = materialHlsl;
	mIncludes.VertexFactoryFilename = vertexFactoryName;
	mIncludes.ShaderSourcePath = includesDirectory;

	std::string shaderTypeStr = shaderType; //ps/vs
	shaderTypeStr = shaderTypeStr.append("_5_0"); //ps_5_0/vs_5_0

	InternalCompileShader(mIncludes, macros, entryPoint, shaderTypeStr);

	return 0;
}

void InternalCompileShader(MilanD3DInclude includer, D3D_SHADER_MACRO* pDefines, std::string entryPoint, std::string shaderProfile) {

	// Load base shader from disk.
	includer.LoadBaseShader();

	ID3DBlob* OutBlob;
	ID3DBlob* OutErrorBlob;

	HRESULT Result = D3DCompile(
		includer.BaseShader.c_str(),
		includer.BaseShader.size(),
		includer.BaseShaderName.c_str(),
		pDefines,
		&includer,
		entryPoint.c_str(),
		shaderProfile.c_str(),
		0,
		0,
		&OutBlob,
		&OutErrorBlob
	);

	if (FAILED(Result))
	{
		if (OutErrorBlob)
		{
			auto error = (char*)OutErrorBlob->GetBufferPointer();
			std::cout << "D3DCompile Error: " << error << "\n";
		}
	}
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

