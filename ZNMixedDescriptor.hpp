#pragma once
#include "ZNTypedDescriptor.hpp"
#include <cstdint>
#include <string>
#include <vector>
namespace ZNMixedDescriptor {
constexpr uint32_t kMagic=0x324D4E5A; // ZNM2; not ZNT1
constexpr uint16_t kVersion=2;
struct Feature {
 std::string id,name;
 uint16_t start=0,count=0;
 ZNTypedDescriptor::FeatureKind kind=ZNTypedDescriptor::FeatureKind::Input;
 ZNValueCodec::Type type=ZNValueCodec::Type::Int32;
};
struct Package {
 std::vector<Feature> features;
 std::vector<ZNTypedDescriptor::Record> records;
};
bool encode(const Package &p,std::vector<uint8_t> &out,std::string &error);
bool decode(const uint8_t *bytes,size_t size,Package &out,std::string &error);
}
