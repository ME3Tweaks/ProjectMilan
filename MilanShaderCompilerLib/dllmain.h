#pragma once
#include "defines.h"
#include "D3DIncludes.h"

LIBRARY_API int CompileShader(const char* materialHlsl, const char* vertexFactoryName, const wchar_t* includesDirectory);
void InternalCompileShader(MilanD3DInclude includer, D3D_SHADER_MACRO* pDefines, std::string entryPoint, std::string shaderProfile);