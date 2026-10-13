#pragma once
#include "ZNRuntimeExecutionScope.h"
#import <Foundation/Foundation.h>
#import <dlfcn.h>

NS_ASSUME_NONNULL_BEGIN

static inline NSString *ZNIL2CPPTrim(NSString * _Nullable value) {
    return [value ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static inline NSString *ZNIL2CPPNormalizedAssembly(NSString * _Nullable value) {
    NSString *s = ZNIL2CPPTrim(value).lowercaseString;
    return [s hasSuffix:@".dll"] && s.length >= 4 ? [s substringToIndex:s.length - 4] : s;
}

static inline NSString *ZNIL2CPPInstanceKey(NSString * _Nullable assembly,
                                            NSString * _Nullable namespaceName,
                                            NSString * _Nullable className) {
    return [NSString stringWithFormat:@"%@|%@|%@",
            ZNIL2CPPNormalizedAssembly(assembly),
            ZNIL2CPPTrim(namespaceName),
            ZNIL2CPPTrim(className)];
}

static inline NSString *ZNIL2CPPConservativeNormalizedAssembly(NSString * _Nullable value) {
    NSString *s = ZNIL2CPPTrim(value).lowercaseString;
    return [s hasSuffix:@".dll"] && s.length > 4 ? [s substringToIndex:s.length - 4] : s;
}

static inline NSString *ZNIL2CPPConservativeInstanceKey(NSString * _Nullable assembly,
                                                        NSString * _Nullable namespaceName,
                                                        NSString * _Nullable className) {
    return [NSString stringWithFormat:@"%@|%@|%@",
            ZNIL2CPPConservativeNormalizedAssembly(assembly),
            ZNIL2CPPTrim(namespaceName),
            ZNIL2CPPTrim(className)];
}

static inline void * _Nullable ZNIL2CPPResolveSymbol(NSString * _Nullable imagePath,
                                                      const char * _Nullable name) {
    return ZNResolveExecutionSymbol(imagePath.length?imagePath.fileSystemRepresentation:nullptr,name);
}

NS_ASSUME_NONNULL_END
