#pragma once
#import "ZNMenuControllerInternal.h"
NS_ASSUME_NONNULL_BEGIN
// Narrow finder-family contract; implementations remain with their existing owners.
@interface ZNRuntimeMenuControllerV040 (ZNMethodFinderUIInternal)
- (void)znm43_startSearch:(id)sender;
- (void)znm43_renderSearchAtWidth:(CGFloat)width;
- (NSString *)znm43_selectedAssembly;
- (void)znm43_setSelectedAssembly:(NSString *)value;
- (void)zn60v3_setLimit:(NSUInteger)value;
- (nullable NSString *)zn61m2_activeToken;
- (void)zn61m2_cancelSearch:(nullable id)sender;
- (void)zn61m2_startSearch:(nullable id)sender;
- (nullable NSString *)zn60v3_status;
// UI_RELOCATED_BEGIN m2foreign
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

// UI_RELOCATED_END m2foreign
@end
NS_ASSUME_NONNULL_END
