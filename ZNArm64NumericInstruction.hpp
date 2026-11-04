#pragma once
#include <cstddef>
#include <cstdint>
#include <string>
namespace ZNArm64NumericInstruction {
// P10.7.1 read-only instruction decoder; NOT a patch encoder or runtime writer.
enum class ValueType : uint8_t { Int32, UInt32, Int64, UInt64, Float32, Float64 };
enum class Family : uint8_t { FmovImmediate, MovzWide, MovnWide };
struct Site {
 Family family=Family::MovzWide;
 ValueType type=ValueType::Int32;
 uint8_t destination=0;
 uint8_t wordCount=0;
 uint64_t originalBits=0;
};
// The caller must supply a validated, disk-backed executable instruction window.
// At most 5 contiguous ARM64 instructions; never mutates executable code.
bool analyze(const uint32_t *words,size_t available,ValueType requested,
             Site &result,std::string &reason);
} // namespace ZNArm64NumericInstruction
