#import <Foundation/Foundation.h>
// Private compile-time contract only: the real class remains owned by the UI.
@interface ZNRuntimeMenuControllerV040 : NSObject
+ (instancetype)shared;
@property(nonatomic,assign) BOOL compactMode;
@property(nonatomic,assign) NSInteger selectedCategory;
@end

// UI_RELOCATED_BEGIN constants
static NSString * const kZNPublicCompactMigrationKey = @"zonoe.public-compact-ui.v1";
static NSString * const kZNCompactModeDefaultsKey = @"ZonoePatch.CompactMode";
static NSString * const kZNSelectedCategoryDefaultsKey = @"ZonoePatch.SelectedCategory";
static NSString * const kZNLegacyFeatureNameRegistryDefaultsKey = @"zonoe.feature-name-registry.v1";

// UI_RELOCATED_END constants

// UI_RELOCATED_BEGIN policy
extern "C" void ZNInstallPublicCompactDefaultsDeferred(void) {
    @autoreleasepool {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;

        // The old v0.5 Privacy UI registry linked target/RVA/patchID directly to
        // title/group. New ZNF1 outputs do not depend on it, so remove it on
        // every launch and never recreate it.
        [defaults removeObjectForKey:kZNLegacyFeatureNameRegistryDefaultsKey];

        BOOL migrated = [defaults boolForKey:kZNPublicCompactMigrationKey];
        if (!migrated) {
            [defaults setBool:YES forKey:kZNCompactModeDefaultsKey];
            [defaults setInteger:0 forKey:kZNSelectedCategoryDefaultsKey];
            [defaults setBool:YES forKey:kZNPublicCompactMigrationKey];

            Class cls = NSClassFromString(@"ZNRuntimeMenuControllerV040");
            if (cls && [cls respondsToSelector:@selector(shared)]) {
                ZNRuntimeMenuControllerV040 *controller = [cls shared];
                controller.compactMode = YES;
                controller.selectedCategory = 0;
            }
        }

        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kZNLegacyFeatureNameRegistryDefaultsKey];
        NSLog(@"[ZonoPatch] v0.5.6 public compact UI installed after first activation; legacy feature-name registry purged");
    }
}

// UI_RELOCATED_END policy
