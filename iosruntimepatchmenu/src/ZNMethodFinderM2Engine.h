#pragma once
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSString *ZN61Trim(NSString * _Nullable value);
FOUNDATION_EXPORT const NSInteger kZN61SearchFieldTag;
// UI_RELOCATED_BEGIN blocks
typedef void (^ZN61ProgressBlock)(NSDictionary<NSString *, id> *progress);
typedef void (^ZN61CompletionBlock)(NSArray<NSDictionary<NSString *, id> *> * _Nullable results,
                                    NSDictionary<NSString *, id> * _Nullable stats,
                                    NSString * _Nullable error);
// UI_RELOCATED_END blocks
// UI_RELOCATED_BEGIN interface
@interface ZNMethodFinderM2Engine : NSObject
@property(nonatomic,copy) NSString *indexStatusText;
+ (instancetype)shared;
- (NSString *)startSearch:(NSString *)query
                    limit:(NSUInteger)limit
                 progress:(ZN61ProgressBlock _Nullable)progress
               completion:(ZN61CompletionBlock _Nullable)completion;
- (void)cancel:(NSString *)token;
@end
// UI_RELOCATED_END interface
NS_ASSUME_NONNULL_END
