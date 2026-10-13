#include "ZNLoadedImageApple.h"
#include "ZNStaticValueCellAccess.h"
#import <Foundation/Foundation.h>

@interface ZNM56StaticValueCellBinder : NSObject
@property(nonatomic,strong) NSMutableDictionary<NSString *,NSNumber *> *sliderGenerations;
+ (instancetype)shared;
- (void)numberChanged:(NSNotification *)note;
- (void)sliderChanged:(NSNotification *)note;
- (void)actionRequested:(NSNotification *)note;
- (BOOL)applyText:(NSString *)text info:(NSDictionary *)info error:(NSString **)error;
@end

#pragma mark - BEGIN ZNM56StaticValueCellBinding.mm
#line 1 "ZNM56StaticValueCellBinding.mm"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach-o/loader.h>
#include <math.h>
#include <string.h>

#import "ZNFeatureControlModel.h"
#import "ZNFeatureMetadataCodec.h"
#import "ZNStaticDispatchRuntime.h"
#import "ZNStaticPatchFormat.h"
#import "ZNValueTypeModel.h"
#import "ZNPatchCore.h"

@interface ZNStaticPatchRecord (ZNM56Private)
@property(nonatomic,assign) uintptr_t imageBase;
@property(nonatomic,assign) ZN44StaticEntry *entry;
@end

static UIViewController *ZNM56TopController(void){UIWindow *window=nil;for(UIScene *scene in UIApplication.sharedApplication.connectedScenes){if(![scene isKindOfClass:UIWindowScene.class]||scene.activationState!=UISceneActivationStateForegroundActive)continue;for(UIWindow *candidate in ((UIWindowScene *)scene).windows){if(candidate.isKeyWindow){window=candidate;break;}}if(window)break;}if(!window)window=UIApplication.sharedApplication.windows.firstObject;UIViewController *vc=window.rootViewController;while(vc.presentedViewController&&!vc.presentedViewController.isBeingDismissed)vc=vc.presentedViewController;return vc;}
static void ZNM56ShowFailure(NSString *message){dispatch_async(dispatch_get_main_queue(),^{UIViewController *top=ZNM56TopController();if(!top||[top isKindOfClass:UIAlertController.class])return;UIAlertController *a=[UIAlertController alertControllerWithTitle:@"执行失败" message:message.length?message:@"执行失败" preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];[top presentViewController:a animated:YES completion:nil];});}

static BOOL ZNM56RecordMatches(ZNStaticPatchRecord *record,NSDictionary *info){uint64_t wantedID=[info[@"featureID"] unsignedLongLongValue];NSDictionary *meta=record.entry?ZNFeatureMetadataDecodeEntry(record.entry):nil;uint64_t recordID=[meta[@"featureID"] unsignedLongLongValue];if(wantedID&&recordID)return wantedID==recordID;NSString *wanted=[info[@"title"] isKindOfClass:NSString.class]?info[@"title"]:@"";NSString *recordName=[meta[@"title"] isKindOfClass:NSString.class]?meta[@"title"]:(record.group.length?record.group:record.title);return wanted.length&&[wanted caseInsensitiveCompare:recordName?:@""]==NSOrderedSame;}

static uintptr_t ZNM56ValueCellAddress(ZNStaticPatchRecord *record,ZNValueType *resolvedType,NSString **error){
    auto lease=record?ZNLeaseForHeader(record.imageBase,record.imageIncarnation):nullptr;
    if(!lease){if(error)*error=@"value-cell image unloaded or incarnation changed";return 0;}
    return ZNStaticValueCellAddressForRecord(record,*lease,resolvedType,error);
}

static BOOL ZNM56ScanSigned(NSString *text,long long *out){NSScanner *s=[NSScanner scannerWithString:text?:@""];long long v=0;if(![s scanLongLong:&v]||!s.isAtEnd)return NO;if(out)*out=v;return YES;}
static BOOL ZNM56ScanUnsigned(NSString *text,unsigned long long *out){NSString *t=[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(!t.length||[t hasPrefix:@"-"])return NO;NSScanner *s=[NSScanner scannerWithString:t];unsigned long long v=0;if(![s scanUnsignedLongLong:&v]||!s.isAtEnd)return NO;if(out)*out=v;return YES;}

static BOOL ZNM56WriteTextToCell(NSString *text,ZNValueType type,uintptr_t cell,NSString **error){
    if(type==ZNValueTypeI32){long long v=0;if(!ZNM56ScanSigned(text,&v)||v<INT32_MIN||v>INT32_MAX){if(error)*error=@"不是有效 I32";return NO;}uint32_t raw=(uint32_t)(int32_t)v;__atomic_store_n((uint32_t *)cell,raw,__ATOMIC_RELEASE);return YES;}
    if(type==ZNValueTypeU32){unsigned long long v=0;if(!ZNM56ScanUnsigned(text,&v)||v>UINT32_MAX){if(error)*error=@"不是有效 U32";return NO;}__atomic_store_n((uint32_t *)cell,(uint32_t)v,__ATOMIC_RELEASE);return YES;}
    if(type==ZNValueTypeI64){long long v=0;if(!ZNM56ScanSigned(text,&v)){if(error)*error=@"不是有效 I64";return NO;}__atomic_store_n((uint64_t *)cell,(uint64_t)v,__ATOMIC_RELEASE);return YES;}
    if(type==ZNValueTypeU64){unsigned long long v=0;if(!ZNM56ScanUnsigned(text,&v)){if(error)*error=@"不是有效 U64";return NO;}__atomic_store_n((uint64_t *)cell,(uint64_t)v,__ATOMIC_RELEASE);return YES;}
    if(type==ZNValueTypeF32){NSScanner *s=[NSScanner scannerWithString:text?:@""];double d=0;if(![s scanDouble:&d]||!s.isAtEnd||!isfinite(d)){if(error)*error=@"不是有效 F32";return NO;}float f=(float)d;uint32_t raw=0;memcpy(&raw,&f,4);__atomic_store_n((uint32_t *)cell,raw,__ATOMIC_RELEASE);return YES;}
    if(type==ZNValueTypeF64){NSScanner *s=[NSScanner scannerWithString:text?:@""];double d=0;if(![s scanDouble:&d]||!s.isAtEnd||!isfinite(d)){if(error)*error=@"不是有效 F64";return NO;}uint64_t raw=0;memcpy(&raw,&d,8);__atomic_store_n((uint64_t *)cell,raw,__ATOMIC_RELEASE);return YES;}
    if(error)*error=@"Value Cell 不支持 Auto/未知类型";return NO;
}

@implementation ZNM56StaticValueCellBinder
+ (instancetype)shared{static ZNM56StaticValueCellBinder *s;static dispatch_once_t once;dispatch_once(&once,^{s=[ZNM56StaticValueCellBinder new];s.sliderGenerations=[NSMutableDictionary dictionary];});return s;}
- (NSArray<ZNStaticPatchRecord *> *)recordsForInfo:(NSDictionary *)info{ZNStaticDispatchRuntime *runtime=[ZNStaticDispatchRuntime sharedRuntime];[runtime refresh];NSMutableArray *out=[NSMutableArray array];for(ZNStaticPatchRecord *r in runtime.records)if(ZNM56RecordMatches(r,info))[out addObject:r];return out;}
- (BOOL)applyText:(NSString *)text info:(NSDictionary *)info error:(NSString **)error{NSArray<ZNStaticPatchRecord *> *records=[self recordsForInfo:info];if(!records.count){if(error)*error=@"找不到 Static Feature 记录";return NO;}ZNStaticDispatchRuntime *runtime=[ZNStaticDispatchRuntime sharedRuntime];for(ZNStaticPatchRecord *r in records){auto writeLease=ZNLeaseForHeader(r.imageBase,r.imageIncarnation);if(!writeLease){if(error)*error=@"value-cell write lease revoked";return NO;}ZNValueType resolved=ZNValueTypeAuto;NSString *local=nil;uintptr_t cell=ZNM56ValueCellAddress(r,&resolved,&local);if(!cell){if(error)*error=local;return NO;}if(!ZNM56WriteTextToCell(text,resolved,cell,&local)){if(error)*error=local;return NO;}if(!r.isEnabled&&![runtime setEnabled:YES forRecord:r error:&local]){if(error)*error=local?:@"启用 Static value-cell variant 失败";return NO;}}[[ZNRuntimeLogger sharedLogger]log:[NSString stringWithFormat:@"[m5.6-value-cell] wrote value=%@ records=%lu RW-only",text?:@"",(unsigned long)records.count]];return YES;}
- (void)numberChanged:(NSNotification *)note{NSString *text=[note.userInfo[@"valueText"] isKindOfClass:NSString.class]?note.userInfo[@"valueText"]:[note.userInfo[@"value"] description];NSString *error=nil;if(![self applyText:text info:note.userInfo?:@{} error:&error])ZNM56ShowFailure(error);}
- (void)sliderChanged:(NSNotification *)note{NSString *text=[note.userInfo[@"valueText"] isKindOfClass:NSString.class]?note.userInfo[@"valueText"]:[note.userInfo[@"value"] description];NSString *key=[note.userInfo[@"key"] isKindOfClass:NSString.class]?note.userInfo[@"key"]:(note.userInfo[@"title"]?:@"feature");NSUInteger generation=[self.sliderGenerations[key] unsignedIntegerValue]+1;self.sliderGenerations[key]=@(generation);NSDictionary *info=[note.userInfo copy]?:@{};dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.10*NSEC_PER_SEC)),dispatch_get_main_queue(),^{if([self.sliderGenerations[key] unsignedIntegerValue]!=generation)return;NSString *error=nil;if(![self applyText:text info:info error:&error])ZNM56ShowFailure(error);});}
- (void)actionRequested:(NSNotification *)note{NSArray *records=[self recordsForInfo:note.userInfo?:@{}];if(!records.count){ZNM56ShowFailure(@"找不到 Static Feature 记录");return;}ZNStaticDispatchRuntime *runtime=[ZNStaticDispatchRuntime sharedRuntime];for(ZNStaticPatchRecord *r in records){NSString *error=nil;if(![runtime setEnabled:YES forRecord:r error:&error]){ZNM56ShowFailure(error);return;}}}
@end

extern "C" void ZNInstallM56StaticValueCellBindingDeferred(void){static dispatch_once_t once;dispatch_once(&once,^{
    Class oldClass=NSClassFromString(@"ZNM55StaticTypedBinder");if(oldClass&&[oldClass respondsToSelector:NSSelectorFromString(@"shared")]){id oldBinder=((id(*)(id,SEL))objc_msgSend)((id)oldClass,NSSelectorFromString(@"shared"));if(oldBinder)[NSNotificationCenter.defaultCenter removeObserver:oldBinder];}
    ZNM56StaticValueCellBinder *binder=[ZNM56StaticValueCellBinder shared];[NSNotificationCenter.defaultCenter addObserver:binder selector:@selector(numberChanged:) name:ZNFeatureNumberValueDidChangeNotification object:nil];[NSNotificationCenter.defaultCenter addObserver:binder selector:@selector(sliderChanged:) name:ZNFeatureSliderValueDidChangeNotification object:nil];[NSNotificationCenter.defaultCenter addObserver:binder selector:@selector(actionRequested:) name:ZNFeatureActionRequestedNotification object:nil];[[ZNRuntimeLogger sharedLogger]log:@"[m5.6-value-cell] Static Number/Slider RW-only binder installed"];
});}

#pragma mark - END ZNM56StaticValueCellBinding.mm
