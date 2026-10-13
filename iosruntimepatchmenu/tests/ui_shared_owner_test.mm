#import "ZNMenuUIKeys.h"
#import "ZNMenuSearchPolicy.h"
#import <objc/runtime.h>
#include <cassert>
void ZNTestUIKeyStore(id);
int main(){@autoreleasepool{
 NSObject *owner=[NSObject new];ZNTestUIKeyStore(owner);
 assert([objc_getAssociatedObject(owner,kZNM54CandidateKey)isEqual:@"candidate"]);assert([objc_getAssociatedObject(owner,kZN51CandidateKey)isEqual:@"chain"]);assert(kZNM54CandidateKey!=kZNM54FilterKey&&kZN51CandidateKey!=kZNM47CaptureCandidateKey);
 assert(kZNM65LiveHookStatusTag==965501&&kZNNativeHookDeleteTagBase==676000);
 assert([ZNM54AssemblyDisplay(@"Assembly-CSharp.dll")isEqual:@"Assembly-CSharp"]);assert(ZNM54IsString(@" System.String "));assert(ZNM54StructCount(@"UnityEngine.Vector3")==3);
 assert(ZNM54UnsupportedReason(@{@"byRef":@YES}).length);assert(!ZNM54UnsupportedReason(@{@"name":@"System.String"}));
 assert(!ZNM54UnsupportedReason(@{@"kind":@(ZNIL2CPPABIValueKindSigned32)}));assert(ZNM54UnsupportedReason(@{@"kind":@(ZNIL2CPPABIValueKindObjectReference),@"name":@"Foo"}).length);
 NSLog(@"production UI key cross-TU identity / policy owner PASS");
}}
