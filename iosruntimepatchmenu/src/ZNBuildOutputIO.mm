#import "ZNBuildSession.h"
#import "ZNBuildOutputIO.h"
NSString *ZNCreateBuildOutputDirectory(NSString *root, NSString *label, NSString **error) {
    NSString *name=[NSString stringWithFormat:@"%@-%@",label?:@"build",NSUUID.UUID.UUIDString];
    NSString *path=[root stringByAppendingPathComponent:name];NSError *e=nil;
    if(![NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&e]){
        if(error)*error=e.localizedDescription;return nil;
    }
    NSString *marker=[path stringByAppendingPathComponent:@".zn-build-owned"];
    if(![name writeToFile:marker atomically:YES encoding:NSUTF8StringEncoding error:&e]){
        // This directory was created by this invocation; never remove a prior build.
        [NSFileManager.defaultManager removeItemAtPath:path error:nil];
        if(error)*error=e.localizedDescription;return nil;
    }
    return path;
}
BOOL ZNDiscardOwnedBuildDirectory(NSString *path) {
    if(!path.length)return NO;
    NSString *owner=[NSString stringWithContentsOfFile:[path stringByAppendingPathComponent:@".zn-build-owned"] encoding:NSUTF8StringEncoding error:nil];
    if(![owner isEqualToString:path.lastPathComponent])return NO;
    return [NSFileManager.defaultManager removeItemAtPath:path error:nil];
}
BOOL ZNWriteBuildReport(id object, NSString *path, NSString **error) {
    ZNBuildSession *session=[ZNBuildSession currentSession];
    if(session && [object isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *tagged=[object mutableCopy];tagged[@"buildSessionID"]=session.identifier;object=tagged;
    }
    NSError *e=nil;NSData *data=[NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingPrettyPrinted error:&e];
    if(!data || ![data writeToFile:path options:NSDataWritingAtomic error:&e]){
        if(error)*error=e.localizedDescription?:@"Build report write failed";return NO;
    }
    return YES;
}
