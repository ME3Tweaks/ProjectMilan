#pragma once
#include <D3D11.h>
#include <D3Dcompiler.h>

#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "D3DCompiler.lib")

std::string _ReadFile(std::string InFilePath);
std::string LoadShaderTemplateFile(std::string sourceDir, std::string filename);