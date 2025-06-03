#include "D3DIncludes.h"
#include <iostream>
#include <fstream>
#include <io.h>

/// <summary>
/// Fetches a shader source file with the given filename from the source path
/// </summary>
/// <param name="filename"></param>
/// <returns></returns>
std::string MilanD3DInclude::LoadShaderSourceFile(const std::string filename, std::string logFname) {

	if (logFname.size() != 0) {
		std::cout << "Loading shader source file: " << filename << " (for " << logFname << ")\n";
	}
	else {
		std::cout << "Loading shader source file: " << filename << "\n";
	}

	std::filesystem::path dir(ShaderSourcePath);
	std::filesystem::path file(filename);
	std::filesystem::path full_path = dir / file;

	// Read file.

	auto size = std::filesystem::file_size(full_path);
	std::string content(size, '\0');
	std::ifstream in(full_path);
	in.read(&content[0], size);
	return content;


	//FILE* IncludeFile = NULL;
	//errno_t ErrorCode = fopen_s(&IncludeFile, full_path.string().c_str(), "rb");
	//if (ErrorCode == 0)
	//{
	//	int FileId = _fileno(IncludeFile);
	//	long FileLength = _filelength(FileId);

	//	// Read the contents.
	//	BYTE* FileContents = new BYTE[FileLength + 1];
	//	size_t NumRead = fread(FileContents, sizeof(BYTE), FileLength, IncludeFile);
	//	fclose(IncludeFile);

	//	*outBytes = FileContents;
	//	*outNumBytes = (UINT)NumRead;
	//	return true;
	//}

	//return false;
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