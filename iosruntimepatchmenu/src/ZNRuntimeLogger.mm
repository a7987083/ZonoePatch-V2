#import "ZNPatchCore.h"
#include <time.h>
@implementation ZNRuntimeLogger {
    NSMutableArray<NSString *> *_lines;
    NSUInteger _nextLine;
}
+ (instancetype)sharedLogger {
    static ZNRuntimeLogger *s;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ s = [ZNRuntimeLogger new]; });
    return s;
}
- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    _lines = [NSMutableArray array];
    return self;
}
- (void)log:(NSString *)message {
    if (!message.length) return;
    time_t now=time(NULL);struct tm local={};localtime_r(&now,&local);
    char stamp[16]={};strftime(stamp,sizeof(stamp),"%H:%M:%S",&local);
    NSString *line=[NSString stringWithFormat:@"[%s] %@",stamp,message];
    @synchronized (self) {
        if(_lines.count<200)[_lines addObject:line];else _lines[_nextLine]=line;
        _nextLine=(_nextLine+1)%200;
    }
    NSLog(@"[ZonoePatch] %@", message);
}
- (NSArray<NSString *> *)recentLines:(NSUInteger)limit {
    @synchronized (self) {
        NSUInteger count=_lines.count;if(!count)return @[];
        NSUInteger wanted=limit?MIN(limit,count):count;
        NSUInteger oldest=count==200?_nextLine:0;
        NSMutableArray *ordered=[NSMutableArray arrayWithCapacity:wanted];
        for(NSUInteger i=count-wanted;i<count;i++)[ordered addObject:_lines[(oldest+i)%count]];
        return [ordered copy];
    }
}
- (void)clear {
    @synchronized (self) { [_lines removeAllObjects];_nextLine=0; }
}
@end
