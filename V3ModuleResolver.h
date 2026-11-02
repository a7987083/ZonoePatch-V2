#import <Foundation/Foundation.h>
@interface ZNV3ModuleInfo : NSObject
@property(nonatomic,copy,readonly) NSString *name;
@property(nonatomic,copy,readonly) NSString *path;
@property(nonatomic,assign,readonly) uintptr_t imageBase;
@property(nonatomic,assign,readonly) intptr_t slide;
- (instancetype)initWithName:(NSString *)name path:(NSString *)path base:(uintptr_t)base slide:(intptr_t)slide;
@end
@interface ZNV3ModuleResolver : NSObject
+ (ZNV3ModuleInfo *)resolveModule:(NSString *)module;
@end
