#pragma once
#include "ZNValueCodec.hpp"
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace ZNTypedDescriptor {
// Separate P10.3 format: never reinterpret old 128-byte ZN44StaticEntry flags.
static constexpr uint32_t kMagic=0x31544E5A; // "ZNT1" little endian
static constexpr uint16_t kVersion=1;
static constexpr size_t kMaxRecords=128;
enum class FeatureKind : uint8_t { Input=2, Slider=3 };
struct Record {
 FeatureKind kind;
 ZNValueCodec::Type type;
 uint64_t rva;
 bool requiresEnableSwitch;
 std::string minimum;
 std::string maximum;
 std::string step;         // Slider only
 std::string defaultValue; // Slider only
};
bool encode(const std::vector<Record> &records,std::vector<uint8_t> &out,std::string &error);
bool decode(const uint8_t *bytes,size_t length,std::vector<Record> &out,std::string &error);
} // namespace ZNTypedDescriptor
