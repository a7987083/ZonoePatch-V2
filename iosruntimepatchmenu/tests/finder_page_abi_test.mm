#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <cassert>
typedef NS_ENUM(NSInteger, FixturePage){FixturePageSearch=0,FixturePageDetail=1};
@interface FixturePageABI:NSObject
@property(nonatomic,assign) NSInteger page;
- (void)oldPage:(FixturePage)value;
- (void)newPage:(NSInteger)value;
@end
@implementation FixturePageABI
- (void)oldPage:(FixturePage)value{self.page=value;}
- (void)newPage:(NSInteger)value{self.page=value;}
@end
int main(){@autoreleasepool{
 assert(strcmp(@encode(FixturePage),@encode(NSInteger))==0);Method old=class_getInstanceMethod(FixturePageABI.class,@selector(oldPage:)),current=class_getInstanceMethod(FixturePageABI.class,@selector(newPage:));assert(strcmp(method_getTypeEncoding(old),method_getTypeEncoding(current))==0);FixturePageABI *fixture=[FixturePageABI new];[fixture oldPage:FixturePageDetail];assert(fixture.page==1);[fixture newPage:0];assert(fixture.page==0);puts("NS_ENUM NSInteger / private setPage selector parameter encoding and values ABI PASS");
}}
