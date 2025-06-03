#pragma once
#include "D3Dcompiler.h"
#include <d3d11Shader.h>
#include <filesystem>
#include <fstream>

class MilanD3DInclude : public ID3DInclude
{
public:
	/// <summary>
	/// The entrypoint usf filename being compiled 
	/// </summary>
	std::string BaseShaderName;

	/// <summary>
	/// The base shader, loaded from disk
	/// </summary>
	std::string BaseShader;

	/// <summary>
	/// Size of BaseShader
	/// </summary>
	UINT BaseShaderLen;

	/// <summary>
	/// The material being compiled (replaces Material.usf in files)
	/// </summary>
	std::string MaterialHLSL;

	/// <summary>
	/// The name of the VertexFactory we are compiling (replaces Vertex.usf in files)
	/// </summary>
	std::string VertexFactoryFilename;

	/// <summary>
	/// The path to the Engine/Shaders folder
	/// </summary>
	std::wstring ShaderSourcePath;

	/// <summary>
	/// Loads a shader source from disk
	/// </summary>
	/// <param name="filename"></param>
	/// <returns></returns>
	std::string LoadShaderSourceFile(const std::string filename, std::string logFname);

	/// <summary>
	/// Loads the base shader from disk
	/// </summary>
	void LoadBaseShader();

private:


	STDMETHOD(Open)(D3D_INCLUDE_TYPE Type, LPCSTR Name, LPCVOID ParentData, LPCVOID* Data, UINT* Bytes)
	{
		// Is this the material data we are compiling?
		if (strcmp(Name, "Material.usf") == 0)
		{
			// Set the USF data for this file.
			const std::string::size_type size = MaterialHLSL.size();
			char* buffer = new char[size + 1];   //we need extra char for NUL
			memcpy(buffer, MaterialHLSL.c_str(), size + 1);
			buffer[size] = '\0'; // Null-terminate the string

			*Data = buffer;
			*Bytes = size + 1;
		}
		else
		{
			std::string FileContents;
			if (strcmp(Name, "VertexFactory.usf") == 0)
			{
				// Load our shader factory
				FileContents = LoadShaderSourceFile(VertexFactoryFilename.c_str(), "VertexFactory.usf");
			}
			else
			{
				// Load the shader from disk
				FileContents = LoadShaderSourceFile(Name, "");
			}

			const std::string::size_type size = FileContents.size();
			char* buffer = new char[size + 1];   //we need extra char for NUL
			memcpy(buffer, FileContents.c_str(), size);
			buffer[size] = '\0'; // Null-terminate the string

			// Write the result to the output parameters.
			*Data = (LPCVOID)buffer;
			*Bytes = size + 1;


			/*
			BYTE* FileContents = NULL;
			UINT FileSize = 0;
			bool loaded = false;
			if (strcmp(Name, "VertexFactory.usf") == 0)
			{
				// Load our shader factory
				loaded = LoadShaderSourceFile(VertexFactoryFilename.c_str(), "VertexFactory.usf", &FileContents, &FileSize);
			}
			else
			{
				// Load the shader from disk
				loaded = LoadShaderSourceFile(Name, "", &FileContents, &FileSize);
			}


			if (loaded)
			{
				*Data = FileContents;
				*Bytes = FileSize;
			}
			else
			{
				// Failed to load the file.
				return E_FAIL;
			}*/
		}

		return S_OK;
	}

	STDMETHOD(Close)(LPCVOID Data)
	{
		// Delete given data.
		delete[] Data;
		return S_OK;
	}
};