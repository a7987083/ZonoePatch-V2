#import "V3ModuleResolver.h"
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
@implementation ZNV3ModuleInfo
- (instancetype)initWithName:(NSString *)name path:(NSString *)path base:(uintptr_t)base slide:(intptr_t)slide {
 if((self=[super init])){_name=[name copy];_path=[path copy];_imageBase=base;_slide=slide;}return self;
}
@end
@implementation ZNV3ModuleResolver
+ (ZNV3ModuleInfo *)resolveModule:(NSString *)module {
 BOOL main=[module isEqualToString:@"主程序"];
 if(!main && ![module isEqualToString:@"UnityFramework"])return nil;
 uint32_t count=_dyld_image_count();
 for(uint32_t i=0;i<count;i++){
  const struct mach_header *header=_dyld_get_image_header(i);
  const char *raw=_dyld_get_image_name(i);
  if(!header||!raw)continue;
  NSString *path=[NSString stringWithUTF8String:raw];if(!path)continue;
  BOOL match=main ? (i==0) : [path.lastPathComponent isEqualToString:@"UnityFramework"];
  if(!match)continue;
  if(header->magic!=MH_MAGIC_64||header->cputype!=CPU_TYPE_ARM64)continue;
  return [[ZNV3ModuleInfo alloc] initWithName:module path:path
    base:(uintptr_t)header slide:_dyld_get_image_vmaddr_slide(i)];
 }
 return nil;
}
@end
