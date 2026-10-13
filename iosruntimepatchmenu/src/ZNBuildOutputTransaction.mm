#import "ZNBuildOutputTransaction.h"
#import "ZNBuildOutputIO.h"
#include "ZNBuildFault.h"
@interface ZNBuildOutputTransaction ()
@property(nonatomic,copy) NSString *stage,*destination,*token;
@property(nonatomic,assign) BOOL published,moved;
@end
static id ZNRebaseOutputPaths(id value,NSString *old,NSString *replacement){
 if([value isKindOfClass:NSString.class]){NSString *prefix=[old stringByAppendingString:@"/"];return [value hasPrefix:prefix]?[replacement stringByAppendingString:[value substringFromIndex:old.length]]:value;}
 if([value isKindOfClass:NSArray.class]){NSMutableArray *a=[NSMutableArray array];for(id x in value)[a addObject:ZNRebaseOutputPaths(x,old,replacement)];return a;}
 if([value isKindOfClass:NSDictionary.class]){NSMutableDictionary *d=[NSMutableDictionary dictionary];for(id key in value)d[key]=ZNRebaseOutputPaths(value[key],old,replacement);return d;}
 return value;
}
@implementation ZNBuildOutputTransaction
- (NSString *)createDirectoryAtRoot:(NSString *)root label:(NSString *)label error:(NSString **)error {
 if(self.stage){if(error)*error=@"One build transaction must publish one owned directory; all target outputs belong inside it";return nil;}
 self.token=[NSString stringWithFormat:@"%@-%@",label?:@"build",NSUUID.UUID.UUIDString];self.destination=[root stringByAppendingPathComponent:self.token];self.stage=[root stringByAppendingPathComponent:[@".zn-staging-" stringByAppendingString:self.token]];
 NSError *e=nil;if(ZNBuildFail("file.write")||![NSFileManager.defaultManager createDirectoryAtPath:self.stage withIntermediateDirectories:YES attributes:nil error:&e]){if(error)*error=e.localizedDescription?:@"Staging creation failed";self.stage=nil;return nil;}
 NSString *marker=[self.stage stringByAppendingPathComponent:@".zn-build-owned"];if(![self.stage.lastPathComponent writeToFile:marker atomically:YES encoding:NSUTF8StringEncoding error:&e]){[NSFileManager.defaultManager removeItemAtPath:self.stage error:nil];self.stage=nil;if(error)*error=e.localizedDescription;return nil;}return self.stage;
}
- (BOOL)publishOutputs:(NSArray<NSString *> *)outputs finalOutputs:(NSArray<NSString *> **)finalOutputs error:(NSString **)error {
 if(self.published||!self.stage.length||!outputs.count){if(error)*error=@"No complete staged build to publish";return NO;}
 NSFileManager *fm=NSFileManager.defaultManager;NSString *prefix=[self.stage stringByAppendingString:@"/"];NSMutableArray *result=[NSMutableArray array];
 for(NSString *path in outputs){NSString *standard=path.stringByStandardizingPath;NSDictionary *attributes=[fm attributesOfItemAtPath:standard error:nil];if(![standard hasPrefix:prefix]||![attributes[NSFileType] isEqual:NSFileTypeRegular]){if(error)*error=@"Output escapes staging or is missing/not regular";return NO;}[result addObject:ZNRebaseOutputPaths(standard,self.stage,self.destination)];}
 for(NSString *relative in [fm subpathsAtPath:self.stage]){NSString *path=[self.stage stringByAppendingPathComponent:relative];if(![path.pathExtension.lowercaseString isEqualToString:@"json"])continue;NSData *bytes=[NSData dataWithContentsOfFile:path];NSError *e=nil;id object=bytes?[NSJSONSerialization JSONObjectWithData:bytes options:0 error:&e]:nil;if(!object||!ZNWriteBuildReport(ZNRebaseOutputPaths(object,self.stage,self.destination),path,error))return NO;}
 if([fm fileExistsAtPath:self.destination]||ZNBuildFail("output.publish")){if(error)*error=@"Final output exists or publication failed";return NO;}
 NSError *e=nil;if(![self.token writeToFile:[self.stage stringByAppendingPathComponent:@".zn-build-owned"] atomically:YES encoding:NSUTF8StringEncoding error:&e]){if(error)*error=e.localizedDescription;return NO;}
 if(![fm moveItemAtPath:self.stage toPath:self.destination error:&e]){if(error)*error=e.localizedDescription;return NO;}self.moved=YES;self.published=YES;if(finalOutputs)*finalOutputs=[result copy];return YES;
}
- (void)rollback {
 if(self.published)return;NSString *path=self.moved?self.destination:self.stage;if(!path.length)return;NSString *marker=[NSString stringWithContentsOfFile:[path stringByAppendingPathComponent:@".zn-build-owned"] encoding:NSUTF8StringEncoding error:nil];if([marker isEqualToString:self.token]||[marker isEqualToString:self.stage.lastPathComponent])[NSFileManager.defaultManager removeItemAtPath:path error:nil];
}
@end
