// dllmain.cpp : Defines the entry point for the DLL application.
#include "dllmain.h"
#include "D3DIncludes.h"
#include "MilanCompilerShared.h"
#include <iostream>

LIBRARY_API int CompileShader(const char* baseShaderName, const char* materialHlsl, const char* vertexFactoryName, const wchar_t* includesDirectory, D3D_SHADER_MACRO* macros, const char* entryPoint, const char* shaderType,
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
	/*
	D3D_SHADER_MACRO* test = macros;
	while (test != nullptr && test->Name != nullptr && test->Definition != nullptr) {
		std::cout << "      " << test->Name << "=" << test->Definition << "\n";
		test++;
	}*/


	return InternalCompileShader(mIncludes, macros, entryPoint, shaderTypeStr, outShaderBytesSize, outShaderBytes, outErrorMsgSize, outErrorMsg);
}


LIBRARY_API void GetShaderInfo(int shaderBufferSize, void* shaderBuffer, int& outInstructionCount, int& outNumParameters, NamedParameterAllocation* allocationArray) {
	// Currently only gets shader instruction count.

	ID3D11ShaderReflection* d3dReflector = NULL;
	D3DReflect(shaderBuffer, shaderBufferSize, IID_ID3D11ShaderReflection, (void**)&d3dReflector);

	// Get Shader Info
	D3D11_SHADER_DESC d3dShaderInfo;
	d3dReflector->GetDesc(&d3dShaderInfo);

	// Set the number of instructions.
	outInstructionCount = d3dShaderInfo.InstructionCount;

	// Get Shader Parameters that are bound,
	// the game checks the allocations to see if they are bound,
	// and if they are, they set the proper data on the parameter.
	// if they are missing then it makes it black.

	// We put shader bindings on here
	std::vector<NamedParameterAllocation> ParameterMap{};

	// Add parameters for shader resources
	// This is ugly
	for (UINT resourceIndex = 0; resourceIndex < d3dShaderInfo.BoundResources; resourceIndex++)
	{
		D3D11_SHADER_INPUT_BIND_DESC bindDesc;
		d3dReflector->GetResourceBindingDesc(resourceIndex, &bindDesc);

		// There are 4 bind types
		// D3D_SIT_CBUFFER/TBUFFER
		// D3D_SIT_TEXTURE
		// D3D_SIT_UAV_RWTYPED
		// D3D_SIT_SAMLPER

		// Constant buffer / Texture Buffer
		if (bindDesc.Type == D3D_SIT_CBUFFER || bindDesc.Type == D3D_SIT_TBUFFER)
		{
			// Get the bind point
			const UINT constantBufferIndex = bindDesc.BindPoint;
			ID3D11ShaderReflectionConstantBuffer* constantBuffer = d3dReflector->GetConstantBufferByName(bindDesc.Name);
			D3D11_SHADER_BUFFER_DESC constantBufferDescription;
			constantBuffer->GetDesc(&constantBufferDescription);

			// Enumerate constant buffer
			for (UINT cIndex = 0; cIndex < constantBufferDescription.Variables; cIndex++)
			{
				// See if variable flag marks it as used
				ID3D11ShaderReflectionVariable* variable = constantBuffer->GetVariableByIndex(cIndex);
				D3D11_SHADER_VARIABLE_DESC variableDesc;
				variable->GetDesc(&variableDesc);
				if (variableDesc.uFlags & D3D_SVF_USED)
				{
					// Add parameter
					ParameterMap.push_back(CreateNamedParameterAllocation(variableDesc.Name,
						constantBufferIndex,
						variableDesc.StartOffset,
						variableDesc.Size,
						0));
				}
			}
		}
		// Texture Resource
		else if (bindDesc.Type == D3D_SIT_TEXTURE)
		{
			// Find matching 
			BOOL hasSampler = FALSE;
			for (UINT i = 0; i < d3dShaderInfo.BoundResources; i++)
			{
				D3D11_SHADER_INPUT_BIND_DESC textureDesc;
				d3dReflector->GetResourceBindingDesc(i, &textureDesc);
				if (textureDesc.Type == D3D_SIT_SAMPLER)
				{
					if (strcmp(textureDesc.Name, bindDesc.Name) == 0)
					{
						// Found the texture that is for this binding
						hasSampler = TRUE;
						break;
					}
				}
			}


			if (!hasSampler)
			{
				TCHAR name[1024];
				UINT numTimesBound = 1;
				wcscpy(name, s2ws(bindDesc.Name).c_str());

				// Get rid of []
				TCHAR* brackedLoc = wcschr(name, TEXT('['));
				if (brackedLoc)
				{
					*brackedLoc = 0;
					const INT preBracketPos = brackedLoc - name;
					while (resourceIndex + 1 < d3dShaderInfo.BoundResources)
					{
						D3D11_SHADER_INPUT_BIND_DESC BindDesc2;
						d3dReflector->GetResourceBindingDesc(resourceIndex + 1, &BindDesc2);

						if (BindDesc2.Type == D3D_SIT_TEXTURE && strncmp(BindDesc2.Name, bindDesc.Name, preBracketPos) == 0)
						{
							numTimesBound++;
							resourceIndex++;
						}
						else
						{
							break;
						}
					}
				}

				ParameterMap.push_back(
					CreateNamedParameterAllocationW(
						name,
						0,
						bindDesc.BindPoint,
						numTimesBound,
						USHRT_MAX
					));
			}
		}
		else if (bindDesc.Type == D3D_SIT_UAV_RWTYPED)
		{
			// Read write buffer.
			TCHAR name[1024];
			UINT numTimesBound = 1;
			wcscpy(name, s2ws(bindDesc.Name).c_str());

			ParameterMap.push_back(CreateNamedParameterAllocationW(
				name,
				0,
				bindDesc.BindPoint,
				numTimesBound,
				USHRT_MAX
			));
		}
		else if (bindDesc.Type == D3D_SIT_SAMPLER)
		{
			// Sampler.

			BOOL foundTexture = FALSE;
			// Find matching texture
			for (UINT i = 0; i < d3dShaderInfo.BoundResources; i++)
			{
				D3D11_SHADER_INPUT_BIND_DESC textureDesc;
				d3dReflector->GetResourceBindingDesc(i, &textureDesc);
				if (textureDesc.Type == D3D_SIT_TEXTURE)
				{
					if (strcmp(textureDesc.Name, bindDesc.Name) == 0)
					{
						foundTexture = TRUE;

						TCHAR name[1024];
						UINT samplerBindingPoint = bindDesc.BindPoint;
						UINT textureBindingPoint = textureDesc.BindPoint;
						UINT actualNumBinds = 0;


						wcscpy(name, s2ws(bindDesc.Name).c_str());

						// Strip []
						TCHAR* brackedLoc = wcschr(name, TEXT('['));
						if (brackedLoc)
						{
							*brackedLoc = 0;
						}

						UINT resourceOffset = 0;
						while (i + resourceOffset < d3dShaderInfo.BoundResources && resourceIndex + resourceOffset < d3dShaderInfo.BoundResources)
						{
							D3D11_SHADER_INPUT_BIND_DESC iterTextureDescription;
							D3D11_SHADER_INPUT_BIND_DESC iterSampleDescription;
							d3dReflector->GetResourceBindingDesc(i + resourceOffset, &iterTextureDescription);
							d3dReflector->GetResourceBindingDesc(resourceIndex + resourceOffset, &iterSampleDescription);

							TCHAR iterTextureName[1024];
							TCHAR iterSampleName[1024];

							wcscpy(iterTextureName, s2ws(iterTextureDescription.Name).c_str());
							wcscpy(iterSampleName, s2ws(iterSampleDescription.Name).c_str());

							brackedLoc = wcschr(iterSampleName, TEXT('['));
							if (brackedLoc)
							{
								*brackedLoc = 0;
							}

							brackedLoc = wcschr(iterTextureName, TEXT('['));
							if (brackedLoc)
							{
								*brackedLoc = 0;
							}

							// Are we still the same item?
							if (iterTextureDescription.Type != D3D_SIT_TEXTURE ||
								iterSampleDescription.Type != D3D_SIT_SAMPLER ||
								wcscmp(iterSampleName, name) != 0 ||
								wcscmp(iterSampleName, iterTextureName) != 0)
							{
								// No?
								break;
							}

							// Find first bind point
							textureBindingPoint = std::min<INT>(textureBindingPoint, iterTextureDescription.BindPoint);
							samplerBindingPoint = std::min<INT>(samplerBindingPoint, iterSampleDescription.BindPoint);
							actualNumBinds++;

							// try next 
							resourceOffset++;
						}


						// manually skip past the other samplers in this array as they are covered with BindCount
						resourceIndex += actualNumBinds - 1;

						ParameterMap.push_back(CreateNamedParameterAllocationW(
							name,
							0,
							textureBindingPoint,
							actualNumBinds,
							samplerBindingPoint
						));
						break;
					}
				}
			}

			if (!foundTexture)
			{
				// Add a parameter for the sampler only, the texture index will be invalid
				ParameterMap.push_back(CreateNamedParameterAllocation(
					bindDesc.Name,
					0,
					USHRT_MAX,
					bindDesc.BindCount,
					bindDesc.BindPoint
				));
			}
		}
	}

	outNumParameters = ParameterMap.size();

	// Set the parameter outputs.
	int paramNum = 0;
	for (auto& param : ParameterMap) {
		wcscpy(allocationArray[paramNum].Name, param.Name);
		allocationArray[paramNum].Allocation.BaseIndex = param.Allocation.BaseIndex;
		allocationArray[paramNum].Allocation.BufferIndex = param.Allocation.BufferIndex;
		allocationArray[paramNum].Allocation.Size = param.Allocation.Size;
		allocationArray[paramNum].Allocation.SamplerIndex = param.Allocation.SamplerIndex;
		paramNum++;
	}



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

BOOL APIENTRY DllMain(HMODULE hModule, DWORD  ul_reason_for_call, LPVOID lpReserved)
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

