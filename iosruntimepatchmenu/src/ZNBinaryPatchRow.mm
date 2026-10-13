#import "ZNBinaryPatchWorkspace.h"
#import "ZNFeatureControlModel.h"
@implementation ZNBinaryPatchRow
- (id)copyWithZone:(NSZone *)zone {
    ZNBinaryPatchRow *copy=[[[self class] allocWithZone:zone] init];
    copy.target=self.target;
    copy.explicitTarget=self.explicitTarget;
    copy.offsetText=self.offsetText;
    copy.enabledText=self.enabledText;
    copy.originalHex=self.originalHex;
    copy.title=self.title;
    copy.group=self.group;
    copy.sourcePath=self.sourcePath;
    copy.statusText=self.statusText;
    copy.featureDescription=self.featureDescription;
    copy.lowConfidence=self.lowConfidence;
    copy.conflict=self.conflict;
    copy.featureControlType=self.featureControlType;
    copy.featureValueType=self.featureValueType;
    // Validators own live temporary state; snapshots must revalidate independently.
    copy.validated=NO;copy.validator=nil;
    return copy;
}
- (instancetype)init {
    self=[super init]; if(!self) return nil;
    _target=@""; _offsetText=@""; _enabledText=@""; _originalHex=@"";
    _title=@""; _group=@"Imported"; _sourcePath=@""; _statusText=@""; _featureDescription=@"";
    return self;
}
@end
