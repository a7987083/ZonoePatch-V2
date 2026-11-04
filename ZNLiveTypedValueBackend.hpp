#pragma once
#include "ZNTypedValueTransaction.hpp"
#include <cstdint>
#include <string>
#include <vector>

// iOS backing store. A Cell is never trusted solely on its raw address;
// every read/write revalidates the live dyld image, LC_UUID, RW segment, and VM protection.
namespace ZNLiveTypedValue {
struct Cell {
 uintptr_t imageHeader;
 std::string imageUUID; // standard UUID string
 uint64_t rva;
 ZNValueCodec::Type type;
};
class Backend final : public ZNTypedValue::Backend {
public:
 explicit Backend(std::vector<Cell> approved);
 bool read(uintptr_t address,uint8_t *dst,size_t n,std::string &error) override;
 bool write(uintptr_t address,const uint8_t *src,size_t n,std::string &error) override;
private:
 std::vector<Cell> approved_;
 bool validate(uintptr_t address,size_t width,bool writing,std::string &error) const;
};
} // namespace ZNLiveTypedValue
