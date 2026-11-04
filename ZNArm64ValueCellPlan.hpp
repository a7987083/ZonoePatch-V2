#pragma once
#include "ZNArm64NumericInstruction.hpp"
#include <array>
#include <cstdint>
#include <string>
namespace ZNArm64ValueCellPlan {
struct Replacement {
 std::array<uint32_t,4> instructions{};
 uint8_t instructionCount=0;
 std::array<uint8_t,8> originalCellBytes{};
 uint8_t cellWidth=0;
};
// Read-only encoder. Does not modify a Mach-O or authorize an executable patch.
// Caller must prove mapped RW cell ownership and that branch targets do not
// enter any instruction replaced with NOP.
bool plan(const ZNArm64NumericInstruction::Site &site,uint64_t codeRVA,
          uint64_t cellRVA,Replacement &out,std::string &error);
}
