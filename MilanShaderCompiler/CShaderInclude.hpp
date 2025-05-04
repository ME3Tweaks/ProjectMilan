#pragma once
#include "D3Dcompiler.h"
#include <d3d11Shader.h>
#include <filesystem>
#include <fstream>

class MilanD3DInclude : public ID3DInclude
{
public:
	/// <summary>
	/// The material being compiled (replaces Material.usf in files)
	/// </summary>
	std::string ShaderHLSL;

	/// <summary>
	/// The name of the VertexFactory we are compiling (replaces Vertex.usf in files)
	/// </summary>
	std::string VertexFactoryFilename;

	/// <summary>
	/// The path to the Engine/Shaders folder
	/// </summary>
	std::string ShaderSourcePath;

	std::string LoadFile(const char* filename) {
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

	STDMETHOD(Open)(D3D_INCLUDE_TYPE Type, LPCSTR Name, LPCVOID ParentData, LPCVOID* Data, UINT* Bytes)
	{
		// Is this the material data we are compiling?
		if (strcmp(Name, "Material.usf") == 0)
		{
			// Set the USF data for this file.
			const INT Length = ShaderHLSL.size() + 1;
			*Data = (LPCVOID)ShaderHLSL.c_str();
			*Bytes = Length;
		}
		else
		{
			std::string FileContents;
			if (strcmp(Name, "VertexFactory.usf") == 0)
			{
				FileContents = LoadFile(VertexFactoryFilename.c_str());
			}
			else
			{
				FileContents = LoadFile(Name);
			}

			const std::string::size_type size = FileContents.size();
			char* buffer = new char[size + 1];   //we need extra char for NUL
			memcpy(buffer, FileContents.c_str(), size + 1);

			// Write the result to the output parameters.
			*Data = (LPCVOID)buffer;
			*Bytes = size + 1;
		}

		return S_OK;
	}

	STDMETHOD(Close)(LPCVOID Data)
	{
		delete[] Data;
		return S_OK;
	}
};