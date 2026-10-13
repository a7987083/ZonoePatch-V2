#import "ZNImageGeneration.h"
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#include <atomic>
static std::atomic<uint64_t> generation{1};
static void ZNImageChanged(const struct mach_header *header,intptr_t slide) {
    (void)header;(void)slide;generation.fetch_add(1,std::memory_order_release);
}
uint64_t ZNCurrentImageGeneration(void) {
    static dispatch_once_t once;
    dispatch_once(&once,^{
        _dyld_register_func_for_add_image(ZNImageChanged);
        _dyld_register_func_for_remove_image(ZNImageChanged);
    });
    return generation.load(std::memory_order_acquire);
}
