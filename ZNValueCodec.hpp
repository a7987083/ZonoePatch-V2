#pragma once
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace ZNValueCodec {
// Persisted type IDs from numeric schema version 2.
enum class Type : uint8_t {
 Int8=0, UInt8=1, Int16=2, UInt16=3,
 Int32=4, UInt32=5, Int64=6, UInt64=7,
 Float32=8, Float64=9
};
size_t width(Type type);
bool encode(Type type, const std::string &decimal, std::vector<uint8_t> &bytes, std::string &error);
bool decode(Type type, const uint8_t *bytes, size_t length, std::string &decimal, std::string &error);
} // namespace ZNValueCodec
