#import "ZNMenuSearchPolicy.h"
#define ZN_UI_LINKAGE

// UI_RELOCATED_BEGIN ZNM54StructCount
ZN_UI_LINKAGE NSUInteger ZNM54StructCount(NSString *type) {
    NSString *n = ZNM54Trim(type).lowercaseString;
    if ([n isEqualToString:@"unityengine.vector2"] || [n isEqualToString:@"vector2"]) return 2;
    if ([n isEqualToString:@"unityengine.vector3"] || [n isEqualToString:@"vector3"]) return 3;
    if ([n isEqualToString:@"unityengine.quaternion"] || [n isEqualToString:@"quaternion"] ||
        [n isEqualToString:@"unityengine.color"] || [n isEqualToString:@"color"]) return 4;
    return 0;
}// UI_RELOCATED_END ZNM54StructCount

// UI_RELOCATED_BEGIN ZNM54IsString
ZN_UI_LINKAGE BOOL ZNM54IsString(NSString *type) {
    NSString *n = ZNM54Trim(type).lowercaseString;
    return [n isEqualToString:@"system.string"] || [n isEqualToString:@"string"];
}// UI_RELOCATED_END ZNM54IsString

// UI_RELOCATED_BEGIN ZNM54ShortType
ZN_UI_LINKAGE NSString *ZNM54ShortType(NSString *type) {
    NSArray<NSString *> *parts = [(type ?: @"") componentsSeparatedByString:@"."];
    NSString *last = parts.lastObject;
    return last.length ? last : (type ?: @"?");
}// UI_RELOCATED_END ZNM54ShortType

// UI_RELOCATED_BEGIN ZNM54Trim
ZN_UI_LINKAGE NSString *ZNM54Trim(NSString *value) {
    return [value ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}// UI_RELOCATED_END ZNM54Trim

// UI_RELOCATED_BEGIN ZNM54AssemblyDisplay
ZN_UI_LINKAGE NSString *ZNM54AssemblyDisplay(NSString *assembly) {
    NSString *s = assembly ?: @"";
    return [s.lowercaseString hasSuffix:@".dll"] && s.length > 4 ? [s substringToIndex:s.length - 4] : s;
}// UI_RELOCATED_END ZNM54AssemblyDisplay

// UI_RELOCATED_BEGIN ZNM54UnsupportedReason
ZN_UI_LINKAGE NSString *ZNM54UnsupportedReason(NSDictionary *param) {
    if ([param[@"byRef"] boolValue]) return @"ref/out 暂不支持";
    if ([param[@"pointer"] boolValue]) return @"pointer 暂不支持";
    NSString *type = [param[@"name"] isKindOfClass:NSString.class] ? param[@"name"] : @"?";
    if (ZNM54IsString(type)) return nil;
    ZNIL2CPPABIValueKind kind = (ZNIL2CPPABIValueKind)[param[@"kind"] integerValue];
    switch (kind) {
        case ZNIL2CPPABIValueKindBool:
        case ZNIL2CPPABIValueKindSigned32:
        case ZNIL2CPPABIValueKindUnsigned32:
        case ZNIL2CPPABIValueKindSigned64:
        case ZNIL2CPPABIValueKindUnsigned64:
        case ZNIL2CPPABIValueKindFloat32:
        case ZNIL2CPPABIValueKindFloat64:
            return nil;
        case ZNIL2CPPABIValueKindComplexValueType:
            return ZNM54StructCount(type) ? nil : [NSString stringWithFormat:@"%@ 暂不支持", ZNM54ShortType(type)];
        case ZNIL2CPPABIValueKindObjectReference:
            return [NSString stringWithFormat:@"%@ 对象参数暂不支持", ZNM54ShortType(type)];
        default:
            return [NSString stringWithFormat:@"%@ 类型未识别", ZNM54ShortType(type)];
    }
}// UI_RELOCATED_END ZNM54UnsupportedReason

