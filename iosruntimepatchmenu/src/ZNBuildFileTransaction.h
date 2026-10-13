#pragma once
#import <Foundation/Foundation.h>
BOOL ZNEditBuildFileAtPath(NSString *path,BOOL (^edit)(NSString *workPath,NSString **error),NSString **error);
