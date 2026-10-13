#pragma once
#import <Foundation/Foundation.h>
FOUNDATION_EXPORT NSString *ZNCreateBuildOutputDirectory(NSString *root, NSString *label, NSString **error);
FOUNDATION_EXPORT BOOL ZNWriteBuildReport(id object, NSString *path, NSString **error);
FOUNDATION_EXPORT BOOL ZNDiscardOwnedBuildDirectory(NSString *path);
