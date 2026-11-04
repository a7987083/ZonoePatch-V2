#pragma once
#include "ZNArm64CodeSitePlan.hpp"
#include <cstddef>
#include <cstdint>
#include <string>
namespace ZNArm64ValueCellPostprocess {
struct Installed {
 uint64_t cellRVA=0;
 uint64_t onInstructionRVA=0;
 uint32_t ldrInstruction=0;
};
// Test-only / staging postprocess for P9-generated, UNSIGNED Mach-O.
// Requires a synthetic static entry whose ON payload contains NOPs and OFF
// payload contains exactly the original numeric instructions. Caller must
// re-sign and verify after this operation; no production exporter calls this.
bool install(const std::string &path,const ZNArm64CodeSitePlan::Prepared &site,
             size_t staticEntryIndex,size_t cellOrdinal,size_t totalCells,
             Installed &out,std::string &error);
}
