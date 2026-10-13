#pragma once
#import <Foundation/Foundation.h>
#import "ZNIL2CPPABIMetadata.h"

NSString *ZNM54AssemblyDisplay(NSString *assembly);
NSString *ZNM54UnsupportedReason(NSDictionary *param);
NSString *ZNM54Trim(NSString *value);
NSString *ZNM54ShortType(NSString *type);
BOOL ZNM54IsString(NSString *type);
NSUInteger ZNM54StructCount(NSString *type);
