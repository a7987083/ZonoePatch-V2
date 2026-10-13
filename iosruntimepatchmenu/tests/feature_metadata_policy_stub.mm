#import "ZNFeatureControlModel.h"
// Codec tests inject neutral presentation policy; they do not claim UI policy integration.
ZNFeatureControlType ZNFeatureControlTypeForFeatureName(NSString *name){(void)name;return ZNFeatureControlTypeSwitch;}
NSString *ZNFeatureControlTypeName(ZNFeatureControlType type){(void)type;return @"switch";}
ZNValueType ZNFeatureValueTypeForFeatureName(NSString *name){(void)name;return ZNValueTypeAuto;}
extern "C" uint32_t ZNM585SliderMaximumFlagsForFeatureName(NSString *name){(void)name;return 0;}
