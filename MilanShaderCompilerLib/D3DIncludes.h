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
		// d00t: I think the Data / Bytes pair doesn't need null-termination,
		//  so I commented out the extra null character. Also basic_string::c_str
		//  always returns a null-terminated string anyway, so you can copy (size + 1)
		//  characters and then avoid setting the null-terminator separately.

		// Is this the material data we are compiling?
		if (strcmp(Name, "Material.usf") == 0)
		{
			// Set the USF data for this file.
			auto const size = MaterialHLSL.size();
			char* const buffer = new char[size];   //we need extra char for NUL
			memcpy(buffer, MaterialHLSL.c_str(), size);
			//buffer[size] = '\0'; // Null-terminate the string

			*Data = buffer;
			*Bytes = size;
		}
		else
		{
			std::string FileContents;
			if (strcmp(Name, "VertexFactory.usf") == 0)
			{
				// Load our shader factory
				FileContents = LoadShaderSourceFile(VertexFactoryFilename.c_str(), Name);
			}
			else
			{
				// Load the shader from disk
				FileContents = LoadShaderSourceFile(Name, "");
			}

			auto const size = FileContents.size();
			char* const buffer = new char[size];   //we need extra char for NUL
			memcpy(buffer, FileContents.c_str(), size);
			//buffer[size] = '\0'; // Null-terminate the string

			// Write the result to the output parameters.
			*Data = (LPCVOID)buffer;
			*Bytes = size;


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
		delete[] (char*)Data;
		return S_OK;
	}
};