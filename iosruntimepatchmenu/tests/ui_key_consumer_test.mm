#import "ZNMenuUIKeys.h"
#import <objc/runtime.h>
void ZNTestUIKeyStore(id owner){objc_setAssociatedObject(owner,kZNM54CandidateKey,@"candidate",OBJC_ASSOCIATION_RETAIN_NONATOMIC);objc_setAssociatedObject(owner,kZN51CandidateKey,@"chain",OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
