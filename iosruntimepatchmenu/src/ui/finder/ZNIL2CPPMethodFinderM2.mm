#import "ZNUIInstallationTrace.h" // UI_MODULE_IMPORT
#import "ZNMenuControllerInternal.h" // UI_MODULE_IMPORT
#import "ZNMethodFinderM2Engine.h" // UI_MODULE_IMPORT
#pragma mark - BEGIN ZNIL2CPPMethodFinderM2.mm
#line 1 "ZNIL2CPPMethodFinderM2.mm"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/vm_prot.h>
#import <dlfcn.h>
#import <errno.h>
#import <limits.h>
#import <stdint.h>
#import <stdlib.h>
#import <stdio.h>
#import <string.h>

#import "ZNIL2CPPHybridFinder.h"
#import "ZNIL2CPPMethodFinderSearchV3.h"
#import "ZNIL2CPPResolver.h"
#import "ZNPatchCore.h"
#import "ZNTheme.h"

// v0.5.8-dev Method Finder V3 Milestone 2.
//
// M1 remains frozen on its own branch. M2 adds:
//   - asynchronous search so class scanning never blocks the menu thread;
//   - cooperative cancellation and shard progress;
//   - broad bare-method search (exact > prefix > suffix > contains);
//   - a compact persistent IL2CPP metadata index keyed by UnityFramework UUID
//     + file size. Runtime VA / MethodInfo / Method Pointer are NEVER persisted.
//
// Structured expressions and Named Offset keep their exact semantics.

// UI_RELOCATED: ZNMethodFinderM2Engine.mm:engine
// ---------- UI integration ----------

static const void *kZN61M2TokenKey = &kZN61M2TokenKey;

@interface ZNRuntimeMenuControllerV040 (ZNMethodFinderM2UI)
- (UIView *)cardAtY:(CGFloat)y height:(CGFloat)h width:(CGFloat)w compact:(BOOL)compact;
- (UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight color:(UIColor *)color;
- (UIButton *)zn40_button:(NSString *)title selector:(SEL)selector frame:(CGRect)frame;
- (void)zn40_updateContentHeight:(CGFloat)y;
- (void)renderPage;
- (NSString *)zn57mf_query;
- (void)zn57mf_setQuery:(NSString *)value;

- (void)zn60v3_setCandidates:(NSArray<NSDictionary *> *)items;
- (void)zn60v3_setSelected:(NSDictionary * _Nullable)candidate;
- (void)zn60v3_setStatus:(NSString *)status;
- (void)zn60v3_setPage:(NSInteger)page;
- (NSUInteger)zn60v3_limit;
- (void)zn60v3_startSearch:(id)sender;
- (void)zn60v3_renderSearchAtWidth:(CGFloat)width;

- (void)zn61m2_startSearch:(id)sender;
- (void)zn61m2_renderSearchAtWidth:(CGFloat)width;
- (void)zn61m2_cancelSearch:(id)sender;
@end

@implementation ZNRuntimeMenuControllerV040 (ZNMethodFinderM2UI)

- (NSString *)zn61m2_activeToken {
    return objc_getAssociatedObject(self, kZN61M2TokenKey);
}

- (void)zn61m2_setActiveToken:(NSString *)token {
    objc_setAssociatedObject(self, kZN61M2TokenKey, token, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)zn61m2_renderSearchAtWidth:(CGFloat)width {
    // After swizzling this selector calls the original M1 renderer.
    [self zn61m2_renderSearchAtWidth:width];

    for (UIView *card in self.contentView.subviews) {
        for (UIView *child in card.subviews) {
            if (![child isKindOfClass:UILabel.class]) continue;
            UILabel *label = (UILabel *)child;
            if ([label.text containsString:@"忽略大小写（精确方法名）"]) {
                label.text = @"✓ 裸方法名宽泛搜索    ✓ exact > prefix > suffix > contains";
                label.adjustsFontSizeToFitWidth = YES;
                label.minimumScaleFactor = 0.68;
            } else if ([label.text containsString:@"阶段 1：多候选工作流"]) {
                label.text = @"阶段 2：异步分片 · 进度/取消 · UUID 绑定本地索引";
            }
        }
    }

    NSString *token = [self zn61m2_activeToken];
    if (!token.length) return;

    CGFloat maxY = 0;
    for (UIView *v in self.contentView.subviews) maxY = MAX(maxY, CGRectGetMaxY(v.frame));
    UIView *card = [self cardAtY:maxY + 8 height:48 width:width compact:NO];
    UILabel *label = [self label:@"后台搜索运行中，可随时取消；取消不会保存半成品索引。"
                             size:8.2
                           weight:UIFontWeightRegular
                            color:self.theme.secondaryTextColor];
    label.frame = CGRectMake(13, 8, card.bounds.size.width - 108, 32);
    label.numberOfLines = 2;
    [card addSubview:label];

    UIButton *cancel = [self zn40_button:@"取消"
                                selector:@selector(zn61m2_cancelSearch:)
                                   frame:CGRectMake(card.bounds.size.width - 86, 9, 73, 30)];
    cancel.backgroundColor = [self.theme.controlColor colorWithAlphaComponent:0.85];
    cancel.layer.borderColor = self.theme.borderColor.CGColor;
    [card addSubview:cancel];
    [self.contentView addSubview:card];
    [self zn40_updateContentHeight:CGRectGetMaxY(card.frame) + 8];
}

- (void)zn61m2_startSearch:(id)sender {
    [self.hostWindow endEditing:YES];

    NSString *query = [self zn57mf_query];
    if (!query.length) {
        UITextField *field = (UITextField *)[self.contentView viewWithTag:kZN61SearchFieldTag];
        query = field.text ?: @"";
        [self zn57mf_setQuery:query];
    }
    query = ZN61Trim(query);
    if (!query.length) {
        [self zn60v3_setStatus:@"请输入方法名、Class::Method 或 0xRVA"];
        [self zn60v3_setPage:0];
        [self renderPage];
        return;
    }

    NSString *old = [self zn61m2_activeToken];
    if (old.length) [[ZNMethodFinderM2Engine shared] cancel:old];

    [self zn60v3_setStatus:@"M2 异步搜索已启动…"];
    [self zn60v3_setPage:0];

    __weak typeof(self) weakSelf = self;
    __block NSString *issuedToken = nil;
    issuedToken = [[ZNMethodFinderM2Engine shared] startSearch:query
                                                       limit:[self zn60v3_limit]
                                                    progress:^(NSDictionary *progress) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || ![[self zn61m2_activeToken] isEqualToString:issuedToken]) return;
        NSString *message = progress[@"message"] ?: @"正在搜索…";
        [self zn60v3_setStatus:message];
        [self renderPage];
    } completion:^(NSArray<NSDictionary<NSString *,id> *> *results,
                   NSDictionary<NSString *,id> *stats,
                   NSString *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || ![[self zn61m2_activeToken] isEqualToString:issuedToken]) return;
        [self zn61m2_setActiveToken:nil];

        if (!results.count) {
            [self zn60v3_setStatus:error ?: @"没有搜索结果"];
            [[ZNRuntimeLogger sharedLogger] log:
             [NSString stringWithFormat:@"[method-finder-m2] %@ failed: %@",
              query, error ?: @"unknown"]];
            [self zn60v3_setPage:0];
            [self renderPage];
            return;
        }

        [self zn60v3_setCandidates:results];
        [self zn60v3_setSelected:nil];
        NSString *mode = stats[@"mode"] ?: @"m2";
        NSString *source = stats[@"indexSource"] ?: @"not-used";
        [self zn60v3_setStatus:
         [NSString stringWithFormat:@"%@：%lu 个候选 · %@ · index=%@ · %.1fms",
          query, (unsigned long)results.count, mode, source,
          [stats[@"elapsedMs"] doubleValue]]];
        [[ZNRuntimeLogger sharedLogger] log:
         [NSString stringWithFormat:@"[method-finder-m2] %@ -> %lu candidates (%@, index=%@, %.1fms)",
          query, (unsigned long)results.count, mode, source,
          [stats[@"elapsedMs"] doubleValue]]];
        [self zn60v3_setPage:1];
        [self renderPage];
    }];

    [self zn61m2_setActiveToken:issuedToken];
    [self renderPage];
}

- (void)zn61m2_cancelSearch:(id)sender {
    NSString *token = [self zn61m2_activeToken];
    if (!token.length) return;
    [[ZNMethodFinderM2Engine shared] cancel:token];
    [self zn60v3_setStatus:@"正在取消搜索…"];
    [self renderPage];
}

@end

extern "C" void ZNInstallIL2CPPMethodFinderM2Deferred(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = NSClassFromString(@"ZNRuntimeMenuControllerV040");
        if (!cls) return;

        Method searchOriginal = class_getInstanceMethod(cls, @selector(zn60v3_startSearch:));
        Method searchReplacement = class_getInstanceMethod(cls, @selector(zn61m2_startSearch:));
        if (searchOriginal && searchReplacement) {
            method_exchangeImplementations(searchOriginal, searchReplacement);
        }

        Method renderOriginal = class_getInstanceMethod(cls, @selector(zn60v3_renderSearchAtWidth:));
        Method renderReplacement = class_getInstanceMethod(cls, @selector(zn61m2_renderSearchAtWidth:));
        if (renderOriginal && renderReplacement) {
            method_exchangeImplementations(renderOriginal, renderReplacement);
        }
    });
}

#pragma mark - END ZNIL2CPPMethodFinderM2.mm
