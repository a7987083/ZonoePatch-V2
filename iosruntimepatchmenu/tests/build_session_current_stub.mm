#import "ZNBuildSession.h"
// Narrow linkage fixture. Real BuildSession isolation is separately executed.
@implementation ZNBuildSession
@dynamic identifier,staticDefaults,workspace,runtimeStore,hookStore,outputTransaction;
+ (instancetype)currentSession{return nil;}
+ (instancetype)captureWorkspace:(ZNBinaryPatchWorkspace *)workspace{(void)workspace;[NSException raise:@"UnexpectedFixtureCall" format:@"captureWorkspace belongs to the production session test"];return [self new];}
- (BOOL)perform:(BOOL (^)(void))body{(void)body;[NSException raise:@"UnexpectedFixtureCall" format:@"perform belongs to the production session test"];return NO;}
@end
