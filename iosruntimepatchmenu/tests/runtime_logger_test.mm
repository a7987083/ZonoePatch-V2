#import <Foundation/Foundation.h>
#import "ZNPatchCore.h"
#include <cassert>
int main(){@autoreleasepool{ZNRuntimeLogger *l=[ZNRuntimeLogger new];
 for(unsigned i=0;i<205;i++)[l log:[NSString stringWithFormat:@"entry-%u",i]];
 NSArray *all=[l recentLines:0];assert(all.count==200);
 assert([all[0] hasSuffix:@"entry-5"]);assert([all.lastObject hasSuffix:@"entry-204"]);
 NSArray *last=[l recentLines:3];assert(last.count==3&&[last[0] hasSuffix:@"entry-202"]);
 [l clear];assert([l recentLines:0].count==0);[l log:@"new"];assert([[l recentLines:1][0] hasSuffix:@"new"]);
 puts("production logger ring ordering/wrap/clear PASS");
}}
