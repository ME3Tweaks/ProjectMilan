#pragma once
#include "defines.h"
#include "D3DIncludes.h"

// Can't seem to make this not do overloaded C linkage
// LIBRARY_API int CompileShader(const char* materialHlsl, const char* vertexFactoryName, const wchar_t* includesDirectory);
int InternalCompileShader(MilanD3DInclude& includer, D3D_SHADER_MACRO* pDefines, std::string entryPoint, std::string shaderProfile /*, byte& outShaderBytes,*/, int& outErrorMsgLen, char& outErrorMsg);