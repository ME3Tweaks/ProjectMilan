#include <iostream>
#include <windows.h>
#include "Source.hpp"

#include <fstream>
#include <sstream>
#include "CShaderInclude.hpp"

int main()
{
	std::wcout << L"Project Milan - Shader Compiler\n";

	// Input file is "Material.usf" I think.
	std::string IncludesDirectory = "S:\\SteamLibrary\\steamapps\\common\\Mass Effect Legendary Edition\\Game\\ME3\\Engine\\Shaders";
	std::string ShaderType = "UberPostProcessBlendPixelShader.usf"; // This is the shader type .usf
	std::string EntryPoint = "FullResMergedUberMain";
	std::string CompileSource = LoadShaderTemplateFile(IncludesDirectory, ShaderType);


	std::string MaterialContentFile = "S:\\Milan\\UDK\\MilanHLSL\\PickUpSwipe_MM.hlsl"; // This is the shader type .usf
	ID3DBlob* OutBlob;
	ID3DBlob* OutErrorBlob;

	MilanD3DInclude shaderInclude;
	shaderInclude.ShaderHLSL = _ReadFile(MaterialContentFile);
	shaderInclude.ShaderSourcePath = IncludesDirectory;

	std::filesystem::path dir(IncludesDirectory);
	std::filesystem::path file(ShaderType);
	std::filesystem::path full_path = dir / file;

	D3D_SHADER_MACRO pDefines[9];
	pDefines[0].Name = "SM5_PROFILE";
	pDefines[0].Definition = "1";

	// Last entry
	pDefines[1].Name = nullptr;
	pDefines[1].Definition = nullptr;

	HRESULT Result = D3DCompileFromFile(
		full_path.c_str(),
		pDefines,
		&shaderInclude,
		EntryPoint.c_str(),
		"ps_5_0",
		0,
		0,
		&OutBlob,
		&OutErrorBlob
	);

	if (FAILED(Result))
	{
		if (OutErrorBlob)
		{
			auto error = (char*) OutErrorBlob->GetBufferPointer();
			std::cout << "D3DCompile Error: " << error << "\n";
		}
	}

	std::wcout << L"D3DCompile Result " << Result << L"\n";
}

std::string _ReadFile(std::string InFilePath)
{
	std::ifstream t(InFilePath);
	std::stringstream buffer;
	buffer << t.rdbuf();
	return buffer.str();
}

std::string LoadShaderTemplateFile(std::string sourceDir, std::string filename) {
	std::filesystem::path dir(sourceDir);
	std::filesystem::path file(filename);
	std::filesystem::path full_path = dir / file;

	// Read file.
	auto size = std::filesystem::file_size(full_path);
	std::string content(size, '\0');
	std::ifstream in(full_path);
	in.read(&content[0], size);
	return content;
}