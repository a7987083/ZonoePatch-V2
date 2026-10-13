#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
// Explicit, bounded diagnostics; disabled unless opted in. No automatic uploads.
NSDictionary<NSString *,id> *ZNPerformanceSnapshot(void);
void ZNPerformanceReset(void);
void ZNPerformanceEnable(BOOL enabled);
NS_ASSUME_NONNULL_END
