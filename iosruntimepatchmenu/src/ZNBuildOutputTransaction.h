#pragma once
#import <Foundation/Foundation.h>
@interface ZNBuildOutputTransaction:NSObject
- (NSString *)createDirectoryAtRoot:(NSString *)root label:(NSString *)label error:(NSString **)error;
- (BOOL)publishOutputs:(NSArray<NSString *> *)outputs finalOutputs:(NSArray<NSString *> **)finalOutputs error:(NSString **)error;
- (void)rollback;
@end
