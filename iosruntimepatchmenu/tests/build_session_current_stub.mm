#import "ZNBuildSession.h"
// Fixture supplies only +currentSession through runtime; this class deliberately
// has no production authoring Store/backend. Use a dedicated narrow facade.
#import <objc/runtime.h>
static id absentSession(id object,SEL selector){(void)object;(void)selector;return nil;}
__attribute__((constructor)) static void installSessionFacade(){Class cls=objc_allocateClassPair(NSObject.class,"ZNBuildSession",0);class_addMethod(object_getClass(cls),@selector(currentSession),(IMP)absentSession,"@@:");objc_registerClassPair(cls);}
