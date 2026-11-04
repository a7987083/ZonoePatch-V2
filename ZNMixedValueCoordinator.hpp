#pragma once
#include "ZNTypedValueTransaction.hpp"
#include <memory>
#include <string>
#include <vector>

namespace ZNMixedValue {
// P10.6.3: independently-owned scalar transactions. Each Backend validates
// its target image on *every* read/write. Coordinator is not a memory backend.
class Coordinator {
public:
 bool apply(const std::string &imageID,const std::string &featureID,
            std::unique_ptr<ZNTypedValue::Backend> backend,
            const std::vector<ZNTypedValue::Target> &targets,
            const std::string &decimal,std::string &error);
 bool restore(const std::string &imageID,const std::string &featureID,std::string &error);
 bool active(const std::string &imageID,const std::string &featureID) const;
 bool recoveryFailed() const;
 size_t sessionCount() const;
private:
 struct Span {uintptr_t start;size_t size;};
 struct Session {
  std::string image,feature;
  std::vector<Span> spans;
  std::unique_ptr<ZNTypedValue::Backend> backend;
  std::unique_ptr<ZNTypedValue::Transaction> transaction;
 };
 std::vector<Session> sessions_;
 bool locked_=false;
};
} // namespace ZNMixedValue
