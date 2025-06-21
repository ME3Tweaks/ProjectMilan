#pragma once
#include <cstdint>
#include <string>
#include <codecvt>

// This header file can be included in other projects for interop

// 4 byte boolean type
typedef int BOOL;

// Describes how to load data into a shader
struct FParameterAllocation
{
	uint16_t BufferIndex;
	uint16_t BaseIndex;
	uint16_t Size;
	uint16_t SamplerIndex;
	BOOL bBound;
};

// Wrapper for parameter that includes the name
// so we don't have to deal with TMap in this
// project.
class NamedParameterAllocation {
public:
	FParameterAllocation Allocation;
	wchar_t Name[256]; // Name of the binding.
};

#ifndef STRING_TYPE_CONVERTERS
#define STRING_TYPE_CONVERTERS
/// Converts a wide string to a string
/// </summary>
/// <param name="wstr"></param>
/// <returns></returns>
std::string ws2s(const std::wstring& wstr)
{
	using convert_typeX = std::codecvt_utf8<wchar_t>;
	std::wstring_convert<convert_typeX, wchar_t> converterX;
	return converterX.to_bytes(wstr);
}

/// <summary>
/// Converts a string to a wide string
/// </summary>
/// <param name="wstr"></param>
/// <returns></returns>
std::wstring s2ws(const std::string& str)
{
	using convert_typeX = std::codecvt_utf8<wchar_t>;
	std::wstring_convert<convert_typeX, wchar_t> converterX;

	return converterX.from_bytes(str);
}

#endif

NamedParameterAllocation CreateNamedParameterAllocationW(
	const wchar_t* name,
	uint16_t bufferIndex,
	uint16_t baseIndex,
	uint16_t size,
	uint16_t samplerIndex)
{
	NamedParameterAllocation param;
	param.Allocation.BufferIndex = bufferIndex;
	param.Allocation.BaseIndex = baseIndex;
	param.Allocation.Size = size;
	param.Allocation.SamplerIndex = samplerIndex;
	wcscpy(param.Name, name);
	return param;
}

NamedParameterAllocation CreateNamedParameterAllocation(
	const char* name,
	uint16_t bufferIndex,
	uint16_t baseIndex,
	uint16_t size,
	uint16_t samplerIndex)
{
	return CreateNamedParameterAllocationW(
		s2ws(std::string(name)).c_str(),
		bufferIndex,
		baseIndex,
		size,
		samplerIndex
	);
}

