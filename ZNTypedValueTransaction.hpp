#pragma once
#include "ZNTypedDescriptor.hpp"
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

// P10.4 transactional scalar data backend. This core is deliberately independent
// from Mach and dyld: platform adapters must prove image identity and RW mapping.
namespace ZNTypedValue {
struct Target {
 uintptr_t address;
 ZNTypedDescriptor::Record descriptor;
};
class Backend {
public:
 virtual ~Backend()=default;
 virtual bool read(uintptr_t address,uint8_t *dst,size_t n,std::string &error)=0;
 virtual bool write(uintptr_t address,const uint8_t *src,size_t n,std::string &error)=0;
};
class Transaction {
public:
 explicit Transaction(Backend &backend);
 bool commit(const std::vector<Target> &targets,const std::string &decimal,std::string &error);
 bool update(const std::vector<Target> &targets,const std::string &decimal,std::string &error);
 bool restore(std::string &error);
 bool active() const {return enabled_;}
 bool recoveryFailed() const {return locked_;}
 const std::string &diagnostic() const {return lastDiagnostic_;}
private:
 struct Snapshot {
  uintptr_t address;
  std::vector<uint8_t> original;
  std::vector<uint8_t> applied;
 };
 Backend &backend_;
 bool enabled_=false,locked_=false;
 std::vector<Snapshot> snapshots_;
 std::vector<Target> activeTargets_;
 std::string lastDiagnostic_;
 bool rollback(const std::vector<Snapshot> &rows,const std::vector<size_t> &indices,
               bool undoToOriginal,std::string &error);
};
} // namespace ZNTypedValue
