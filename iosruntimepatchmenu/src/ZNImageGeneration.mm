#import "ZNImageGeneration.h"
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#include <atomic>
static std::atomic<uint64_t> generation{1};
static znimage::Lifetimes &lifetimes(){static znimage::Lifetimes value;return value;}
static void ZNImageAdded(const struct mach_header *header,intptr_t slide) {
    lifetimes().added((uintptr_t)header);(void)slide;generation.fetch_add(1,std::memory_order_release);
}
uint64_t ZNCurrentImageGeneration(void) {
    static dispatch_once_t once;
    dispatch_once(&once,^{
        _dyld_register_func_for_add_image(ZNImageAdded);
        _dyld_register_func_for_remove_image([](const struct mach_header *h,intptr_t slide){(void)slide;lifetimes().removed((uintptr_t)h);generation.fetch_add(1,std::memory_order_release);});
    });
    return generation.load(std::memory_order_acquire);
}

std::shared_ptr<znimage::Lifetime> ZNImageLifetimeForHeader(uintptr_t header){ZNCurrentImageGeneration();return lifetimes().get(header);}
