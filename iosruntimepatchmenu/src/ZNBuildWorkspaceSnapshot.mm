#import "ZNBinaryPatchWorkspace.h"
@interface ZNBinaryPatchWorkspace (ZNBuildSnapshotInternal)
@property(nonatomic,strong,readwrite) NSMutableArray<ZNBinaryPatchRow *> *rows;
@end
@implementation ZNBinaryPatchWorkspace (ZNBuildSnapshot)
- (ZNBinaryPatchWorkspace *)buildSnapshotForRowIndexes:(NSArray<NSNumber *> *)rowIndexes {
    ZNBinaryPatchWorkspace *snapshot=[ZNBinaryPatchWorkspace new];
    NSMutableArray<ZNBinaryPatchRow *> *selected=[NSMutableArray array];
    for(NSNumber *number in rowIndexes ?: @[]) {
        NSUInteger index=number.unsignedIntegerValue;
        if(index<self.rows.count)[selected addObject:[self.rows[index] copy]];
    }
    snapshot.rows=selected;
    snapshot.defaultTarget=self.defaultTarget ?: @"自动";
    snapshot.showJSONFiles=NO;
    snapshot.lastStatus=@"BuildManifest snapshot";
    return snapshot;
}

@end
