#include "D3DIncludes.h"

/// <summary>
/// Fetches a shader source file with the given filename from the source path
/// </summary>
/// <param name="filename"></param>
/// <returns></returns>
std::string MilanD3DInclude::LoadShaderSourceFile(std::string filename) {
	std::filesystem::path dir(ShaderSourcePath);
	std::filesystem::path file(filename);
	std::filesystem::path full_path = dir / file;

	// Read file.
	auto size = std::filesystem::file_size(full_path);
	std::string content(size, '\0');
	std::ifstream in(full_path);
	in.read(&content[0], size);
	return content;
}

/// <summary>
/// Load base shader from disk
/// </summary>
/// <param name="filename"></param>
/// <returns></returns>
void MilanD3DInclude::LoadBaseShader() {
	BaseShader = LoadShaderSourceFile(BaseShaderName);
}