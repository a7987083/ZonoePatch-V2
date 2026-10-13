#import "ZNBuildFileTransaction.h"
#include "ZNBuildFault.h"
#include <fcntl.h>
#include <sys/stat.h>
#import <Foundation/Foundation.h>
BOOL ZNEditBuildFileAtPath(NSString *path,BOOL (^edit)(NSString *,NSString **),NSString **error){
 NSFileManager *fm=NSFileManager.defaultManager;NSDictionary *attrs=[fm attributesOfItemAtPath:path error:nil];NSData *original=[NSData dataWithContentsOfFile:path];if(!original||![attrs[NSFileType] isEqual:NSFileTypeRegular]){if(error)*error=@"File transaction requires a readable regular input";return NO;}
 NSString *directory=[path.stringByDeletingLastPathComponent stringByAppendingPathComponent:[@".zn-edit-" stringByAppendingString:NSUUID.UUID.UUIDString]],*work=[directory stringByAppendingPathComponent:path.lastPathComponent];NSError *io=nil;BOOL ok=NO;
 @try {do{
  if(![fm createDirectoryAtPath:directory withIntermediateDirectories:NO attributes:nil error:&io]||![fm copyItemAtPath:path toPath:work error:&io]){if(error)*error=io.localizedDescription;break;}
  if(!edit(work,error))break;
  NSData *prepared=[NSData dataWithContentsOfFile:work];if(!prepared||ZNBuildFail("file.write")){if(error)*error=@"Prepared file write failed";break;}
  int fd=open(work.fileSystemRepresentation,O_RDWR);if(fd<0){if(error)*error=@"Cannot open private commit file";break;}size_t written=0;while(written<prepared.length){ssize_t n=ZNBuildPWrite(fd,(const uint8_t *)prepared.bytes+written,prepared.length-written,(off_t)written);if(n<0&&errno==EINTR)continue;if(n<=0)break;written+=(size_t)n;}BOOL synced=written==prepared.length&&fsync(fd)==0;close(fd);if(!synced){if(error)*error=@"Private pwrite/fsync failed";break;}
  if(![original isEqual:[NSData dataWithContentsOfFile:path]]||ZNBuildFail("file.publish")){if(error)*error=@"Input changed concurrently or file publication failed";break;}
  if(rename(work.fileSystemRepresentation,path.fileSystemRepresentation)!=0){if(error)*error=@"Atomic file publication failed";break;}ok=YES;
 }while(0);} @catch(NSException *exception){if(error)*error=exception.reason;ok=NO;} @finally {[fm removeItemAtPath:directory error:nil];}
 return ok;
}
