#pragma once
#import <Foundation/Foundation.h>
// One ordered activation owner; existing selector/IMP compatibility layers remain intact.
FOUNDATION_EXPORT void ZNRunActivationStage(NSString *name, void (^block)(void));
