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
	std::string LoadShaderSourceFile(std::string filename);

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
			const INT Length = MaterialHLSL.size() + 1;
			*Data = (LPCVOID)MaterialHLSL.c_str();
			*Bytes = Length;
		}
		else
		{
			std::string FileContents;
			if (strcmp(Name, "VertexFactory.usf") == 0)
			{
				// Load our shader factory
				FileContents = LoadShaderSourceFile(VertexFactoryFilename.c_str());
			}
			else
			{
				// Load the shader from disk
				FileContents = LoadShaderSourceFile(Name);
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
		// Delete given data.
		delete[] Data;
		return S_OK;
	}
};