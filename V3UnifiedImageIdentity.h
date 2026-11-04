#pragma once
#import <Foundation/Foundation.h>

// Compare persisted Mach-O identity by value, not NSString object pointer.
// Reject missing values, including missing loaded LC_UUID or source file path.
static inline BOOL ZNV3SameImageIdentity(NSString *uuidA, NSString *pathA,
                                          NSString *uuidB, NSString *pathB) {
 return uuidA.length && pathA.length && uuidB.length && pathB.length &&
        [uuidA isEqualToString:uuidB] && [pathA isEqualToString:pathB];
}
