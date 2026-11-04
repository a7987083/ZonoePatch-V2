#pragma once
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace ZNUnifiedBuildPlan {
// P10.6.1 read-only preflight; NOT an executable descriptor.
// P9 Static Entry and ZNT1 Typed Descriptor ABIs remain unchanged.
constexpr uint32_t kSchemaVersion=1;
constexpr size_t kMaxFeatures=128;
constexpr size_t kMaxRules=128;
enum class Control : uint8_t { Toggle=0, Input=2, Slider=3 };
enum class RuleKind : uint8_t { PatchBytes=0, TypedValue=1 };
struct Rule {
 std::string ruleID;
 RuleKind kind;
 uint64_t rva, fileOffset, width;
};
struct Feature {
 std::string featureID; // persisted ID, independent from display name
 std::string name, group;
 Control control;
 std::string imageUUID, sourcePath;
 std::vector<Rule> rules;
};
struct Plan {
 uint32_t version=kSchemaVersion;
 std::vector<Feature> features;
};
bool validate(const Plan &plan,std::string &error);
} // namespace ZNUnifiedBuildPlan
