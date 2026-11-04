#pragma once
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>
// P10.7.5 independent, versioned logical linkage between ZNM2 numeric
// Feature IDs and dedicated P9 ON/OFF dispatch entries. This is not ZNM2.
// Consumers MUST validate exact image UUID, P9 entry table and ZNM2 record
// ownership before applying any runtime state changes.
namespace ZNCodeCellBinding {
constexpr uint32_t kMagic=0x3142435aU; // "ZCB1", little endian
constexpr uint16_t kVersion=1;
constexpr size_t kMaxBindings=128;
struct Binding {
 std::string featureID; // may repeat for multiple rules owned by one feature
 uint32_t patchID=0; // one-based P9 Static Entry patchID
 uint64_t sourceRVA=0;
 uint64_t cellRVA=0;
 uint8_t numericType=255; // ZNValueCodec::Type [0,9]
 uint8_t originalWords=0; // 1..4 original code instructions
};
struct Package {
 std::string imageUUID; // uppercase LC_UUID, 36 characters
 std::vector<Binding> bindings;
};
// Strict layout (little endian): magic4/version2/count2/UUID36/reserved4;
// entry: patchID4/sourceRVA8/cellRVA8/type1/wordCount1/idLen2/idBytes.
// Data-only validator; never activates P9 slots or writes executable pages.
bool encode(const Package &p,std::vector<uint8_t>&out,std::string &error);
bool decode(const uint8_t *bytes,size_t length,Package &out,std::string &error);
// Cross-check independently encoded ZCB1 against actual P9/ZNM2 catalog.
// p9 records carry one-based patch ID, source site RVA, and cell marker;
// numeric records carry persisted featureID, value type, cell RVA.
struct P9CodeEntry {uint32_t patchID;uint64_t siteRVA;bool valueCell;};
struct NumericCell {std::string featureID;uint8_t numericType;uint64_t cellRVA;};
bool validateOwnership(const Package &package,
 const std::vector<P9CodeEntry>&p9,
 const std::vector<NumericCell>&numerics,std::string&error);
}
