#include "D3DIncludes.h"
#include <iostream>
#include <fstream>
#include <io.h>

/// <summary>
/// Changes the extension on a given string
/// </summary>
/// <param name="file"></param>
/// <param name="extension">Extension including the dot</param>
void SetExtension(std::string& file, std::string extension) {
	// Do not use auto or you will get an unsigned number
	int dotPos = file.rfind('.'); // Find the final .
	if (dotPos >= 0)
	{
		// Replace the extension
		file = file.replace(dotPos, file.size(), extension);
	}
	else
	{
		// Add the extension
		file += extension;
	}
}

/// <summary>
/// Fetches a shader source file with the given filename from the source path
/// </summary>
/// <param name="filename"></param>
/// <returns></returns>
std::string MilanD3DInclude::LoadShaderSourceFile(std::string filename, std::string logFname) {

	/*if (!logFname.empty()) {
		std::cout << "Loading shader source file: " << filename << " (for " << logFname << ")\n";
	}
	else {
		std::cout << "Loading shader source file: " << filename << "\n";
	}*/

	// Set the file extension to match LE - passed in may or may not have .usf extensions
	SetExtension(filename, ".usf");

	std::filesystem::path dir(ShaderSourcePath);
	std::filesystem::path file(filename);
	std::filesystem::path full_path = dir / file;

	// Read file.

	std::string content{};
	{
		// TODO: Log I/O errors.

		auto const handle = _wfopen(full_path.c_str(), L"rb");
		if (handle == nullptr) return {};
		if (fseek(handle, 0, SEEK_END) != 0) return {};
		
		auto const length = ftell(handle);
		if (length == -1) return {};
		if (fseek(handle, 0, SEEK_SET) != 0) return {};

		content.resize(static_cast<std::size_t>(length), '\0');
		if (fread(content.data(), sizeof(char), content.size(), handle) != content.size()) return {};

		fclose(handle);
	}
	return content;
}

/// <summary>
/// Load base shader from disk
/// </summary>
/// <param name="filename"></param>
/// <returns></returns>
void MilanD3DInclude::LoadBaseShader() {
	BaseShaderLen = 0;
	BaseShader = LoadShaderSourceFile(BaseShaderName, "Base Shader");
	if (BaseShader.size() == 0) 
	{
		std::cerr << "Failed to load base shader: " << BaseShaderName << "\n";
		return;
	}
}