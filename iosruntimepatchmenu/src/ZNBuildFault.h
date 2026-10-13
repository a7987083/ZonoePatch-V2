#pragma once
#include <cerrno>
#include <cstring>
#include <sys/mman.h>
#include <unistd.h>
#ifdef ZN_BUILD_FAULT_TESTING
#include <functional>
namespace znfault {inline thread_local std::function<bool(const char *)> fail;}
inline bool ZNBuildFail(const char *point){return znfault::fail&&znfault::fail(point);}
#else
inline bool ZNBuildFail(const char *){return false;}
#endif
inline int ZNBuildMSync(void *address,size_t size,int flags){if(ZNBuildFail("msync")){errno=EIO;return -1;}return msync(address,size,flags);}
inline ssize_t ZNBuildPWrite(int fd,const void *bytes,size_t size,off_t offset){if(ZNBuildFail("pwrite")){errno=EIO;return -1;}return pwrite(fd,bytes,size,offset);}
