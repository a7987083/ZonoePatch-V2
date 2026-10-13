#import "ZNBuildOutputTransaction.h"
#import "ZNBuildSession.h"
#import "ZNBuildItem.h"
#import "ZNValueTypeModel.h"
#include "ZNPerformance.h"
static NSString *fixtureHome;
static NSString *FixtureHomeDirectory(){return fixtureHome;}
#define NSHomeDirectory FixtureHomeDirectory
@interface FixtureWorkspace:NSObject
@property(nonatomic,strong) NSArray<ZNBinaryPatchRow *> *rows;
@property(nonatomic,copy) NSString *defaultTarget;
@property(nonatomic,assign) BOOL hasAnyApplied;
@property(nonatomic,readonly) NSUInteger filledCount;
- (instancetype)buildSnapshotForRowIndexes:(NSArray *)indexes;
@end
@implementation ZNBinaryPatchRow (FixtureControls)
- (ZNFeatureControlType)featureControlType{return ZNFeatureControlTypeSwitch;}
- (void)setFeatureControlType:(ZNFeatureControlType)value{(void)value;}
- (ZNValueType)featureValueType{return ZNValueTypeAuto;}
- (void)setFeatureValueType:(ZNValueType)value{(void)value;}
@end
@implementation FixtureWorkspace
- (NSUInteger)filledCount{return self.rows.count;}
- (instancetype)buildSnapshotForRowIndexes:(NSArray *)indexes{FixtureWorkspace *w=[FixtureWorkspace new];NSMutableArray *rows=[NSMutableArray array];for(NSNumber *i in indexes)[rows addObject:[self.rows[i.unsignedIntegerValue] copy]];w.rows=rows;w.defaultTarget=self.defaultTarget;return w;}
@end
#define ZNBinaryPatchWorkspace FixtureWorkspace
@interface FixtureSession:NSObject
@property(nonatomic,strong) FixtureWorkspace *workspace;
@property(nonatomic,strong) ZNBuildOutputTransaction *outputTransaction;
@property(nonatomic,copy) NSString *identifier;
+ (instancetype)currentSession;
+ (instancetype)captureWorkspace:(FixtureWorkspace *)w;
- (BOOL)perform:(BOOL (^)(void))body;
@end
static FixtureSession *fixtureCurrentSession;
@implementation FixtureSession
+ (instancetype)currentSession{return fixtureCurrentSession;}
+ (instancetype)captureWorkspace:(FixtureWorkspace *)w{FixtureSession *s=[self new];NSMutableArray *indexes=[NSMutableArray array];for(NSUInteger i=0;i<w.rows.count;i++)[indexes addObject:@(i)];s.workspace=[w buildSnapshotForRowIndexes:indexes];s.outputTransaction=[ZNBuildOutputTransaction new];s.identifier=NSUUID.UUID.UUIDString;return s;}
- (BOOL)perform:(BOOL (^)(void))body{if(fixtureCurrentSession)return NO;fixtureCurrentSession=self;@try{return body();}@finally{fixtureCurrentSession=nil;}}
@end
#define ZNBuildSession FixtureSession
@interface FixtureLogger:NSObject
+ (instancetype)sharedLogger;
- (void)log:(NSString *)text;
@end
@implementation FixtureLogger
+ (instancetype)sharedLogger{return [self new];}
- (void)log:(NSString *)text{(void)text;}
@end
#define ZNRuntimeLogger FixtureLogger
@class ZNBuildManifest;
typedef BOOL (^ZNBuildProviderPrepare)(ZNBuildManifest *,FixtureWorkspace *,NSString **);
typedef BOOL (^ZNBuildProviderEmit)(ZNBuildManifest *,NSArray *,BOOL,NSString **,NSString **);
@interface ZNBuildProviderRecord:NSObject
@property(nonatomic,copy) NSString *emitGroup;
@property(nonatomic,copy) ZNBuildProviderPrepare prepare;
@property(nonatomic,copy) ZNBuildProviderEmit emit;
@end
@implementation ZNBuildProviderRecord @end
@interface ZNBuildManifest:NSObject
@property(nonatomic,copy) NSArray *items;
@property(nonatomic,copy) NSArray *activeProviderIdentifiers;
@property(nonatomic,copy) NSDictionary *providerSnapshot;
@property(nonatomic,copy) NSString *collectionError;
@property(nonatomic,readonly) BOOL hasStaticItems;
@property(nonatomic,readonly) NSUInteger itemCount,staticItemCount,runtimeItemCount;
+ (instancetype)manifestForWorkspace:(FixtureWorkspace *)w;
@end
static int fixtureMode;
