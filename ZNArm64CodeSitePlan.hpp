#pragma once
#include "ZNArm64NumericInstruction.hpp"
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>
namespace ZNArm64CodeSitePlan {
// All instruction sections from the identical disk Mach-O must be provided.
// This scanner detects direct ARM64 B/BL, B.cond, CBZ/CBNZ, TBZ/TBNZ branches.
struct CodeRegion {
 uint64_t rva=0;
 const uint8_t *bytes=nullptr;
 size_t length=0;
};
struct Candidate {
 std::string featureID,ruleID,imageUUID,sourcePath;
 uint64_t rva=0,fileOffset=0;
 ZNArm64NumericInstruction::ValueType type=ZNArm64NumericInstruction::ValueType::Int32;
 const uint32_t *words=nullptr;
 size_t availableWords=0; // read from validated original executable section
};
struct Prepared {
 std::string featureID,ruleID,imageUUID,sourcePath;
 uint64_t rva=0,fileOffset=0;
 ZNArm64NumericInstruction::Site instruction;
 std::vector<uint8_t> originalBytes,stagingNopBytes;
};
// Read-only and fail-closed. The NOPs are staging placeholders for later
// P9 relocation; they MUST NOT be exported as an executable numeric patch.
bool prepare(const Candidate &candidate,const std::vector<CodeRegion> &allCodeRegions,
             Prepared &out,std::string &error);
bool validateDisjoint(const std::vector<Prepared> &codeSites,
                      const std::vector<std::pair<uint64_t,uint64_t>> &otherRvaSpans,
                      std::string &error);
}
