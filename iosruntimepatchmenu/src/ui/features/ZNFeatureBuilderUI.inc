#pragma mark - BEGIN ZNFeatureBuilderUI.mm
#line 1 "ZNFeatureBuilderUI.mm"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "ZNBinaryPatchWorkspace.h"
#import "ZNFeatureControlModel.h"
#import "ZNRuntimeActionModel.h"
#import "ZNNativeHookAction.h"
#import "ZNTheme.h"
#import "ZNPatchCore.h"

// ZonoPatch v0.5 Feature/Patch Builder UI.
//
// `其他` is the developer authoring surface:
//   Feature -> one or more Patch rows -> validate -> temporary test -> build.
// JSON is only an optional import source. Once built, Feature metadata and
// Static Dispatch records are embedded in the generated Mach-O and runtime no
// longer needs the JSON file.

static const void *kZN50BExpandedFeatureKeys = &kZN50BExpandedFeatureKeys;
static const NSInteger kZN50BExpandTagBase = 460000;
static const NSInteger kZN50BAddPatchTagBase = 461000;
static const NSInteger kZN50BRenameTagBase = 462000;
static const NSInteger kZN50BDescriptionTagBase = 463000;
static const NSInteger kZN50BSliderMaxTagBase = 932000;
static NSString * const kZN50BSliderMaxDefaultsPrefix = @"zonoe.m5.8.5.static-slider-max.v1";

static NSString *ZN50BTrim(NSString *value) {
    return [value ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static NSString *ZN50BFeatureKey(NSString *name) {
    return ZN50BTrim(name).lowercaseString;
}

static NSString *ZN50BSliderMaxDefaultsKey(NSString *featureName) {
    return [NSString stringWithFormat:@"%@.%@", kZN50BSliderMaxDefaultsPrefix, ZN50BTrim(featureName).lowercaseString];
}

static double ZN50BStoredSliderMax(NSString *featureName) {
    id value=[NSUserDefaults.standardUserDefaults objectForKey:ZN50BSliderMaxDefaultsKey(featureName)];
    return [value isKindOfClass:NSNumber.class]?[value doubleValue]:0.0;
}

static void ZN50BStoreSliderMax(NSString *featureName,double value) {
    NSString *key=ZN50BSliderMaxDefaultsKey(featureName);
    if(isfinite(value)&&value>0.0)[NSUserDefaults.standardUserDefaults setDouble:MIN(value,16383.0) forKey:key];
    else [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
}

static void ZN50BNormalizeImportedGroups(ZNBinaryPatchWorkspace *workspace) {
    for (ZNBinaryPatchRow *row in workspace.rows) {
        NSString *group = ZN50BTrim(row.group);
        NSString *title = ZN50BTrim(row.title);
        if ((!group.length || [group caseInsensitiveCompare:@"Imported"] == NSOrderedSame) && title.length) {
            // Legacy/universal JSON often has only a feature/title field. Make
            // that title the durable group name so Builder writes it into the
            // Static Dispatch table and runtime can expose one Feature switch.
            row.group = title;
        }
    }
}

static BOOL ZN50BRowVisible(ZNBinaryPatchRow *row) {
    if (row.offsetText.length || row.enabledText.length) return YES;
    NSString *group = ZN50BTrim(row.group);
    NSString *title = ZN50BTrim(row.title);
    if (group.length && [group caseInsensitiveCompare:@"Imported"] != NSOrderedSame) return YES;
    return title.length > 0;
}

static NSArray<NSDictionary *> *ZN50BFeatureGroups(ZNBinaryPatchWorkspace *workspace) {
    ZN50BNormalizeImportedGroups(workspace);
    NSMutableArray<NSString *> *order = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSMutableArray<ZNBinaryPatchRow *> *> *rowsByKey = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSString *> *nameByKey = [NSMutableDictionary dictionary];

    for (ZNBinaryPatchRow *row in workspace.rows) {
        if (!ZN50BRowVisible(row)) continue;
        NSString *name = ZN50BTrim(row.group);
        if (!name.length || [name caseInsensitiveCompare:@"Imported"] == NSOrderedSame) {
            name = ZN50BTrim(row.title);
        }
        if (!name.length) name = @"未命名功能";
        NSString *key = ZN50BFeatureKey(name);
        if (!rowsByKey[key]) {
            rowsByKey[key] = [NSMutableArray array];
            nameByKey[key] = name;
            [order addObject:key];
        }
        [rowsByKey[key] addObject:row];
    }

    NSMutableArray<NSDictionary *> *out = [NSMutableArray arrayWithCapacity:order.count];
    for (NSString *key in order) {
        [out addObject:@{
            @"key": key,
            @"name": nameByKey[key] ?: @"Feature",
            @"rows": [rowsByKey[key] copy] ?: @[],
        }];
    }
    return out;
}

static NSMutableSet<NSString *> *ZN50BExpandedKeys(ZNRuntimeMenuControllerV040 *controller) {
    NSMutableSet<NSString *> *set = objc_getAssociatedObject(controller, kZN50BExpandedFeatureKeys);
    if (!set) {
        set = [NSMutableSet set];
        objc_setAssociatedObject(controller, kZN50BExpandedFeatureKeys, set, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return set;
}

@implementation ZNBinaryPatchWorkspace (ZNFeatureEditing)

- (NSString *)addFeature {
    if (self.hasAnyApplied || self.isBuilding) {
        self.lastStatus = @"当前状态不可增加功能，请先恢复 Runtime Patch 或等待生成结束";
        return @"";
    }

    NSMutableSet<NSString *> *used = [NSMutableSet set];
    for (ZNBinaryPatchRow *row in self.rows) {
        NSString *group = ZN50BTrim(row.group);
        if (group.length && [group caseInsensitiveCompare:@"Imported"] != NSOrderedSame) {
            [used addObject:group.lowercaseString];
        }
    }

    NSUInteger serial = 1;
    NSString *name = nil;
    do {
        name = [NSString stringWithFormat:@"新功能 %lu", (unsigned long)serial++];
    } while ([used containsObject:name.lowercaseString]);

    ZNBinaryPatchRow *row = [ZNBinaryPatchRow new];
    row.group = name;
    row.title = @"Patch #1";
    row.statusText = @"待填写";
    [self.rows addObject:row];
    self.lastStatus = [NSString stringWithFormat:@"已增加功能：%@", name];
    return name;
}

- (void)addPatchToFeature:(NSString *)featureName {
    if (self.hasAnyApplied || self.isBuilding) {
        self.lastStatus = @"当前状态不可增加 Patch，请先恢复 Runtime Patch 或等待生成结束";
        return;
    }
    NSString *name = ZN50BTrim(featureName);
    if (!name.length) return;

    NSUInteger count = 0;
    for (ZNBinaryPatchRow *row in self.rows) {
        if ([ZN50BTrim(row.group) caseInsensitiveCompare:name] == NSOrderedSame) count++;
    }

    NSString *existingDescription=@"";
    for (ZNBinaryPatchRow *existing in self.rows) {
        if ([ZN50BTrim(existing.group) caseInsensitiveCompare:name] == NSOrderedSame && existing.featureDescription.length) {
            existingDescription=existing.featureDescription;
            break;
        }
    }

    ZNBinaryPatchRow *row = [ZNBinaryPatchRow new];
    row.group = name;
    row.title = [NSString stringWithFormat:@"Patch #%lu", (unsigned long)count + 1];
    row.featureDescription = existingDescription;
    row.statusText = @"待填写";
    [self.rows addObject:row];
    self.lastStatus = [NSString stringWithFormat:@"%@：已增加 Patch #%lu", name, (unsigned long)count + 1];
}

- (BOOL)renameFeature:(NSString *)oldName to:(NSString *)newName error:(NSString **)error {
    if (self.hasAnyApplied || self.isBuilding) {
        if (error) *error = @"当前状态不可重命名功能";
        return NO;
    }
    NSString *oldValue = ZN50BTrim(oldName);
    NSString *newValue = ZN50BTrim(newName);
    if (!newValue.length) {
        if (error) *error = @"功能名称不能为空";
        return NO;
    }
    if ([oldValue caseInsensitiveCompare:newValue] == NSOrderedSame) return YES;

    for (ZNBinaryPatchRow *row in self.rows) {
        NSString *group = ZN50BTrim(row.group);
        if ([group caseInsensitiveCompare:newValue] == NSOrderedSame &&
            [group caseInsensitiveCompare:oldValue] != NSOrderedSame) {
            if (error) *error = @"已存在同名功能，避免意外合并";
            return NO;
        }
    }

    BOOL changed = NO;
    for (ZNBinaryPatchRow *row in self.rows) {
        if ([ZN50BTrim(row.group) caseInsensitiveCompare:oldValue] == NSOrderedSame) {
            row.group = newValue;
            changed = YES;
        }
    }
    if (!changed) {
        if (error) *error = @"找不到要重命名的功能";
        return NO;
    }
    self.lastStatus = [NSString stringWithFormat:@"功能已重命名：%@ → %@", oldValue, newValue];
    return YES;
}

- (BOOL)setDescription:(NSString *)description forFeature:(NSString *)featureName error:(NSString **)error {
    if (self.hasAnyApplied || self.isBuilding) {
        if (error) *error=@"当前状态不可修改功能说明";
        return NO;
    }
    NSString *name=ZN50BTrim(featureName);
    NSString *desc=ZN50BTrim(description);
    BOOL changed=NO;
    for (ZNBinaryPatchRow *row in self.rows) {
        if ([ZN50BTrim(row.group) caseInsensitiveCompare:name] == NSOrderedSame) {
            row.featureDescription=desc ?: @"";
            changed=YES;
        }
    }
    if(!changed){
        if(error)*error=@"找不到对应功能";
        return NO;
    }
    self.lastStatus=desc.length?[NSString stringWithFormat:@"%@：说明已更新",name]:[NSString stringWithFormat:@"%@：说明已清空",name];
    return YES;
}

@end

@interface ZNRuntimeMenuControllerV040 (ZNFeatureBuilderUI)
- (void)zn50b_renderOther;
- (void)zn50b_expandFeature:(UIButton *)sender;
- (void)zn50b_addFeature:(id)sender;
- (void)zn50b_addPatch:(UIButton *)sender;
- (void)zn50b_featureNameEnd:(UITextField *)field;
- (void)zn50b_featureDescriptionEnd:(UITextField *)field;
- (void)zn50b_sliderMaxChanged:(UITextField *)field;
- (void)zn50b_exportJSON:(id)sender;
@end

@implementation ZNRuntimeMenuControllerV040 (ZNFeatureBuilderUI)

- (void)zn50b_renderOther {
    [self.contentView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    CGFloat width = CGRectGetWidth(self.contentView.bounds);
    CGFloat y = 9.0;
    ZNBinaryPatchWorkspace *workspace = [ZNBinaryPatchWorkspace sharedWorkspace];
    [workspace ensureDefaultRows];
    ZN50BNormalizeImportedGroups(workspace);
    BOOL locked = workspace.hasAnyApplied || workspace.isBuilding;

    // One existing authoring toolbar: binary picker + import + export.
    // Tag 440000 is still transformed by ZNUX into the existing app-library picker.
    UIView *targetCard = [self cardAtY:y height:56 width:width compact:NO];
    CGFloat toolbarGap = 6.0;
    CGFloat sideW = 78.0;
    CGFloat pickerX = 13.0;
    CGFloat pickerW = MAX(96.0, targetCard.bounds.size.width - pickerX - 9.0 - sideW * 2.0 - toolbarGap * 2.0);
    UITextField *target = [self zn44_field:CGRectMake(pickerX, 11, pickerW, 32)
                                        text:workspace.defaultTarget
                                 placeholder:@"选择二进制"
                                         tag:440000
                                     enabled:!locked];
    [targetCard addSubview:target];
    CGFloat importX = CGRectGetMaxX(target.frame) + toolbarGap;
    UIButton *import = [self zn40_button:(workspace.showJSONFiles ? @"收起 JSON" : @"导入 JSON")
                                selector:@selector(zn44_importJSON:)
                                   frame:CGRectMake(importX, 11, sideW, 32)];
    import.enabled = !locked;
    [targetCard addSubview:import];
    UIButton *exportJSON = [self zn40_button:@"导出 JSON"
                                    selector:@selector(zn50b_exportJSON:)
                                       frame:CGRectMake(CGRectGetMaxX(import.frame) + toolbarGap, 11, sideW, 32)];
    exportJSON.enabled = !locked;
    [targetCard addSubview:exportJSON];
    [self.contentView addSubview:targetCard];
    y += 64;

    if (workspace.showJSONFiles) {
        NSUInteger shown = workspace.jsonFiles.count;
        CGFloat h = 32.0 + shown * 34.0;
        UIView *jsonCard = [self cardAtY:y height:h width:width compact:NO];
        UILabel *title = [self label:[NSString stringWithFormat:@"与 1 同目录 JSON · %lu", (unsigned long)shown]
                                  size:10.5
                                weight:UIFontWeightSemibold
                                 color:self.theme.primaryTextColor];
        title.frame = CGRectMake(13, 7, jsonCard.bounds.size.width - 26, 17);
        [jsonCard addSubview:title];
        for (NSUInteger i = 0; i < shown; i++) {
            NSString *path = workspace.jsonFiles[i];
            UIButton *button = [self zn40_button:path.lastPathComponent
                                        selector:@selector(zn44_jsonTapped:)
                                           frame:CGRectMake(13, 27 + i * 34, jsonCard.bounds.size.width - 26, 28)];
            button.tag = 446000 + (NSInteger)i;
            button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
            button.titleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
            [jsonCard addSubview:button];
        }
        [self.contentView addSubview:jsonCard];
        y += h + 8;
    }

    NSArray<NSDictionary *> *features = ZN50BFeatureGroups(workspace);
    NSMutableSet<NSString *> *expanded = ZN50BExpandedKeys(self);

    for (NSUInteger featureIndex = 0; featureIndex < features.count; featureIndex++) {
        NSDictionary *feature = features[featureIndex];
        NSString *key = feature[@"key"];
        NSString *name = feature[@"name"];
        NSArray<ZNBinaryPatchRow *> *rows = feature[@"rows"];
        BOOL isExpanded = [expanded containsObject:key];

        UIView *featureCard = [self cardAtY:y height:48 width:width compact:NO];
        UILabel *featureName = [self label:name size:11.2 weight:UIFontWeightSemibold color:self.theme.primaryTextColor];
        featureName.frame = CGRectMake(13, 8, featureCard.bounds.size.width - 142, 30);
        featureName.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [featureCard addSubview:featureName];

        NSString *countTitle = [NSString stringWithFormat:@"%lu Patch %@", (unsigned long)rows.count, isExpanded ? @"▲" : @"▼"];
        UIButton *expand = [self zn40_button:countTitle
                                    selector:@selector(zn50b_expandFeature:)
                                       frame:CGRectMake(featureCard.bounds.size.width - 124, 8, 112, 32)];
        expand.tag = kZN50BExpandTagBase + (NSInteger)featureIndex;
        [featureCard addSubview:expand];
        [self.contentView addSubview:featureCard];
        y += 54;

        if (!isExpanded) continue;

        // Feature name editor. Group name is what Builder persists for the
        // final runtime Feature switch.
        UIView *nameCard = [self cardAtY:y height:50 width:width compact:NO];
        UILabel *label = [self label:@"功能名" size:9.2 weight:UIFontWeightMedium color:self.theme.secondaryTextColor];
        label.frame = CGRectMake(18, 9, 45, 30);
        [nameCard addSubview:label];
        UITextField *nameField = [[UITextField alloc] initWithFrame:CGRectMake(63, 9, nameCard.bounds.size.width - 78, 31)];
        nameField.tag = kZN50BRenameTagBase + (NSInteger)featureIndex;
        nameField.text = name;
        nameField.enabled = !locked;
        nameField.textColor = self.theme.primaryTextColor;
        nameField.backgroundColor = self.theme.controlColor;
        nameField.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightMedium];
        nameField.autocorrectionType = UITextAutocorrectionTypeNo;
        nameField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        nameField.returnKeyType = UIReturnKeyDone;
        nameField.clearButtonMode = UITextFieldViewModeWhileEditing;
        nameField.layer.cornerRadius = 7;
        nameField.layer.borderWidth = 1;
        nameField.layer.borderColor = self.theme.borderColor.CGColor;
        UIView *pad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 1)];
        nameField.leftView = pad;
        nameField.leftViewMode = UITextFieldViewModeAlways;
        [nameField addTarget:self action:@selector(zn50b_featureNameEnd:) forControlEvents:UIControlEventEditingDidEndOnExit | UIControlEventEditingDidEnd];
        [nameCard addSubview:nameField];
        [self.contentView addSubview:nameCard];
        y += 56;

        UIView *descriptionCard=[self cardAtY:y height:50 width:width compact:NO];
        UILabel *descriptionLabel=[self label:@"功能说明" size:9.2 weight:UIFontWeightMedium color:self.theme.secondaryTextColor];
        descriptionLabel.frame=CGRectMake(18,9,52,30);
        [descriptionCard addSubview:descriptionLabel];
        UITextField *descriptionField=[[UITextField alloc] initWithFrame:CGRectMake(72,9,descriptionCard.bounds.size.width-87,31)];
        descriptionField.tag=kZN50BDescriptionTagBase+(NSInteger)featureIndex;
        NSString *featureDescription=rows.firstObject.featureDescription ?: @"";
        descriptionField.text=featureDescription;
        descriptionField.placeholder=@"例如：开启后保持体力不减少";
        descriptionField.enabled=!locked;
        descriptionField.textColor=self.theme.primaryTextColor;
        descriptionField.backgroundColor=self.theme.controlColor;
        descriptionField.font=[UIFont systemFontOfSize:9.8 weight:UIFontWeightRegular];
        descriptionField.autocorrectionType=UITextAutocorrectionTypeNo;
        descriptionField.returnKeyType=UIReturnKeyDone;
        descriptionField.clearButtonMode=UITextFieldViewModeWhileEditing;
        descriptionField.layer.cornerRadius=7;
        descriptionField.layer.borderWidth=1;
        descriptionField.layer.borderColor=self.theme.borderColor.CGColor;
        UIView *descriptionPad=[[UIView alloc] initWithFrame:CGRectMake(0,0,8,1)];
        descriptionField.leftView=descriptionPad;
        descriptionField.leftViewMode=UITextFieldViewModeAlways;
        [descriptionField addTarget:self action:@selector(zn50b_featureDescriptionEnd:) forControlEvents:UIControlEventEditingDidEndOnExit|UIControlEventEditingDidEnd];
        [descriptionCard addSubview:descriptionField];
        [self.contentView addSubview:descriptionCard];
        y += 56;

        for (NSUInteger patchIndex = 0; patchIndex < rows.count; patchIndex++) {
            ZNBinaryPatchRow *row = rows[patchIndex];
            NSUInteger globalIndex = [workspace.rows indexOfObjectIdenticalTo:row];
            if (globalIndex == NSNotFound) continue;
            UIView *patchCard = [self cardAtY:y height:94 width:width compact:NO];
            BOOL autoTarget=[workspace.defaultTarget caseInsensitiveCompare:@"自动"]==NSOrderedSame || [workspace.defaultTarget caseInsensitiveCompare:@"auto"]==NSOrderedSame;
            NSString *effectiveTarget = autoTarget ? ((row.explicitTarget&&row.target.length)?row.target:@"main") : workspace.defaultTarget;
            NSString *patchTitle = ZN50BTrim(row.title);
            if (!patchTitle.length || [patchTitle caseInsensitiveCompare:name] == NSOrderedSame) {
                patchTitle = [NSString stringWithFormat:@"Patch #%lu", (unsigned long)patchIndex + 1];
            }
            UILabel *head = [self label:[NSString stringWithFormat:@"#%lu · %@ · %@", (unsigned long)patchIndex + 1, effectiveTarget, patchTitle]
                                    size:9.8
                                  weight:UIFontWeightSemibold
                                   color:self.theme.primaryTextColor];
            head.frame = CGRectMake(18, 5, patchCard.bounds.size.width - 31, 16);
            head.lineBreakMode = NSLineBreakByTruncatingMiddle;
            [patchCard addSubview:head];

            UILabel *offsetLabel = [self label:@"Offset" size:9.0 weight:UIFontWeightMedium color:self.theme.secondaryTextColor];
            offsetLabel.frame = CGRectMake(18, 24, 45, 28);
            [patchCard addSubview:offsetLabel];
            UITextField *offset = [self zn44_field:CGRectMake(63, 23, patchCard.bounds.size.width - 78, 29)
                                               text:row.offsetText
                                        placeholder:@"0x..."
                                                tag:441000 + (NSInteger)globalIndex
                                            enabled:!locked];
            [patchCard addSubview:offset];

            ZNFeatureControlType controlType = [workspace controlTypeForFeature:name];
            BOOL isNumber = controlType == ZNFeatureControlTypeNumber;
            BOOL isSlider = controlType == ZNFeatureControlTypeSlider;
            BOOL isValueControl = isNumber || isSlider;

            if (!isSlider) {
                // M6.2 input contract:
                //   Button/Switch -> Offset + Patch
                //   Number        -> Offset + ValueType; this field is only an
                //                    ephemeral test value and is never emitted as Patch.
                NSString *valueLabel = isNumber ? @"测试值" : @"Patch";
                NSString *placeholder = isNumber ? @"例如 1000" : @"ARM64 HEX";
                UILabel *enabledLabel = [self label:valueLabel size:9.0 weight:UIFontWeightMedium color:self.theme.secondaryTextColor];
                enabledLabel.frame = CGRectMake(18, 54, 45, 28);
                [patchCard addSubview:enabledLabel];
                UITextField *enabled = [self zn44_field:CGRectMake(63, 53, patchCard.bounds.size.width - 78, 29)
                                                    text:row.enabledText
                                             placeholder:placeholder
                                                     tag:442000 + (NSInteger)globalIndex
                                                 enabled:!locked];
                if (isNumber) {
                    enabled.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
                    enabled.autocapitalizationType = UITextAutocapitalizationTypeNone;
                } else {
                    enabled.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
                }
                [patchCard addSubview:enabled];
            } else {
                UILabel *maxLabel=[self label:@"Max" size:9.0 weight:UIFontWeightMedium color:self.theme.secondaryTextColor];
                maxLabel.frame=CGRectMake(18,54,45,28);
                [patchCard addSubview:maxLabel];

                double sliderMax=ZN50BStoredSliderMax(name);
                UITextField *maxField=[self zn44_field:CGRectMake(63,53,patchCard.bounds.size.width-78,29)
                                                   text:(sliderMax>0.0?[NSString stringWithFormat:@"%.0f",sliderMax]:@"")
                                            placeholder:@"例如 100"
                                                    tag:kZN50BSliderMaxTagBase+(NSInteger)globalIndex
                                                enabled:!locked];
                maxField.keyboardType=UIKeyboardTypeNumberPad;
                maxField.autocorrectionType=UITextAutocorrectionTypeNo;
                maxField.accessibilityLabel=[NSString stringWithFormat:@"%@ Slider 最大值",name];
                [maxField addTarget:self action:@selector(zn50b_sliderMaxChanged:)
                   forControlEvents:UIControlEventEditingChanged|UIControlEventEditingDidEnd];
                [patchCard addSubview:maxField];
            }

            NSString *original = row.originalHex.length ? row.originalHex : @"-";
            NSString *status = row.statusText.length ? row.statusText : (isValueControl ? @"待应用" : @"待应用");
            UILabel *originalLine = [self label:[NSString stringWithFormat:@"Original  %@   %@", original, status]
                                            size:8.2
                                          weight:UIFontWeightRegular
                                           color:row.conflict ? UIColor.systemOrangeColor : self.theme.secondaryTextColor];
            originalLine.frame = CGRectMake(18, 82, patchCard.bounds.size.width - 31, 11);
            originalLine.lineBreakMode = NSLineBreakByTruncatingMiddle;
            [patchCard addSubview:originalLine];

            [self.contentView addSubview:patchCard];
            y += 100;
        }

        UIView *addPatchCard = [self cardAtY:y height:44 width:width compact:NO];
        UIButton *addPatch = [self zn40_button:@"＋ 增加 Patch"
                                      selector:@selector(zn50b_addPatch:)
                                         frame:CGRectMake(18, 6, addPatchCard.bounds.size.width - 36, 32)];
        addPatch.tag = kZN50BAddPatchTagBase + (NSInteger)featureIndex;
        addPatch.enabled = !locked;
        [addPatchCard addSubview:addPatch];
        [self.contentView addSubview:addPatchCard];
        y += 50;
    }

    UIView *addFeatureCard = [self cardAtY:y height:48 width:width compact:NO];
    UIButton *addFeature = [self zn40_button:@"＋ 增加功能"
                                    selector:@selector(zn50b_addFeature:)
                                       frame:CGRectMake(13, 7, addFeatureCard.bounds.size.width - 26, 34)];
    addFeature.enabled = !locked;
    [addFeatureCard addSubview:addFeature];
    [self.contentView addSubview:addFeatureCard];
    y += 56;

    CGFloat gap = 8.0;
    CGFloat inner = width - 26.0;
    CGFloat buttonW = (inner - gap) / 2.0;

    BOOL hasRawPatch=NO;
    for(ZNBinaryPatchRow *candidate in workspace.rows){
        if(!candidate.offsetText.length)continue;
        if(candidate.featureControlType==ZNFeatureControlTypeButton||candidate.featureControlType==ZNFeatureControlTypeSwitch){
            if(candidate.enabledText.length){hasRawPatch=YES;break;}
        }
    }

    // M6.3: Apply/Restore test raw Button/Switch only.
    // Number/Slider are configured here and exercised after binary generation.
    UIView *actions1 = [self cardAtY:y height:52 width:width compact:NO];
    UIButton *apply = [self zn40_button:@"应用" selector:@selector(zn44_applyAll:)
                                  frame:CGRectMake(13, 9, inner, 34)];
    apply.enabled = !workspace.isBuilding && !workspace.hasAnyApplied && hasRawPatch;
    [actions1 addSubview:apply];
    [self.contentView addSubview:actions1];
    y += 60;

    UIView *actions2 = [self cardAtY:y height:52 width:width compact:NO];
    UIButton *restore = [self zn40_button:@"恢复" selector:@selector(zn44_restoreAll:) frame:CGRectMake(13, 9, buttonW, 34)];
    UIButton *build = [self zn40_button:(workspace.isBuilding ? @"正在生成…" : @"生成新二进制")
                                   selector:@selector(zn44_buildBinary:)
                                      frame:CGRectMake(13 + buttonW + gap, 9, buttonW, 34)];
    restore.enabled = !workspace.isBuilding && workspace.hasAnyApplied;
    build.enabled = [ZNBinaryBuildCoordinator sharedCoordinator].canBuild;
    [actions2 addSubview:restore];
    [actions2 addSubview:build];
    [self.contentView addSubview:actions2];
    y += 60;

    if (workspace.lastStatus.length) {
        UIView *statusCard = [self cardAtY:y height:38 width:width compact:NO];
        UILabel *status = [self label:workspace.lastStatus size:8.6 weight:UIFontWeightRegular color:self.theme.secondaryTextColor];
        status.frame = CGRectMake(13, 8, statusCard.bounds.size.width - 26, 22);
        status.numberOfLines = 2;
        status.lineBreakMode = NSLineBreakByTruncatingTail;
        [statusCard addSubview:status];
        [self.contentView addSubview:statusCard];
        y += 46;
    }

    if (workspace.lastOutputPaths.count) {
        NSMutableArray<NSString *> *lines = [NSMutableArray array];
        for (NSUInteger i = 0; i < MIN((NSUInteger)4, workspace.lastOutputPaths.count); i++) {
            NSString *path = workspace.lastOutputPaths[i];
            [lines addObject:[path hasPrefix:NSHomeDirectory()] ? [path substringFromIndex:NSHomeDirectory().length] : path];
        }
        [self zn40_addInfoCard:@"最近输出" lines:lines y:&y width:width];
    }

    [self zn40_updateContentHeight:y];
}

- (void)zn50b_expandFeature:(UIButton *)sender {
    NSInteger index = sender.tag - kZN50BExpandTagBase;
    if (index < 0) return;
    ZNBinaryPatchWorkspace *workspace = [ZNBinaryPatchWorkspace sharedWorkspace];
    NSArray<NSDictionary *> *features = ZN50BFeatureGroups(workspace);
    if ((NSUInteger)index >= features.count) return;
    NSString *key = features[(NSUInteger)index][@"key"];
    NSMutableSet<NSString *> *expanded = ZN50BExpandedKeys(self);
    if ([expanded containsObject:key]) [expanded removeObject:key];
    else [expanded addObject:key];
    [self renderPage];
}

- (void)zn50b_addFeature:(id)sender {
    (void)sender;
    ZNBinaryPatchWorkspace *workspace = [ZNBinaryPatchWorkspace sharedWorkspace];
    NSString *name = [workspace addFeature];
    if (name.length) [ZN50BExpandedKeys(self) addObject:ZN50BFeatureKey(name)];
    [self renderPage];
}

- (void)zn50b_addPatch:(UIButton *)sender {
    NSInteger index = sender.tag - kZN50BAddPatchTagBase;
    if (index < 0) return;
    ZNBinaryPatchWorkspace *workspace = [ZNBinaryPatchWorkspace sharedWorkspace];
    NSArray<NSDictionary *> *features = ZN50BFeatureGroups(workspace);
    if ((NSUInteger)index >= features.count) return;
    NSString *name = features[(NSUInteger)index][@"name"];
    [workspace addPatchToFeature:name];
    [ZN50BExpandedKeys(self) addObject:ZN50BFeatureKey(name)];
    [self renderPage];
}

- (void)zn50b_featureNameEnd:(UITextField *)field {
    NSInteger index = field.tag - kZN50BRenameTagBase;
    if (index < 0) return;
    ZNBinaryPatchWorkspace *workspace = [ZNBinaryPatchWorkspace sharedWorkspace];
    NSArray<NSDictionary *> *features = ZN50BFeatureGroups(workspace);
    if ((NSUInteger)index >= features.count) return;
    NSString *oldName = features[(NSUInteger)index][@"name"];
    NSString *newName = ZN50BTrim(field.text);
    NSString *error = nil;
    if ([workspace renameFeature:oldName to:newName error:&error]) {
        NSMutableSet<NSString *> *expanded = ZN50BExpandedKeys(self);
        [expanded removeObject:ZN50BFeatureKey(oldName)];
        [expanded addObject:ZN50BFeatureKey(newName)];
    } else {
        workspace.lastStatus = [NSString stringWithFormat:@"重命名失败：%@", error ?: @"未知错误"];
        field.text = oldName;
    }
    [self.hostWindow endEditing:YES];
    [self renderPage];
}

- (void)zn50b_exportJSON:(id)sender {
    (void)sender;
    ZNBinaryPatchWorkspace *workspace=[ZNBinaryPatchWorkspace sharedWorkspace];
    if(workspace.isBuilding||workspace.hasAnyApplied)return;
    [self.hostWindow endEditing:YES];

    UIWindow *window=self.hostWindow ?: [self currentWindow];
    UIViewController *presenter=ZN48TopViewController(window.rootViewController);
    if(!presenter){workspace.lastStatus=@"导出失败：找不到可用于弹窗的 ViewController";[self renderPage];return;}

    NSString *appName=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if(!appName.length)appName=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleName"];
    if(!appName.length)appName=@"ZonoeConfig";

    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"导出 JSON"
                                                                 message:@"请输入文件名"
                                                          preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){
        field.text=appName;
        field.placeholder=@"例如：我的修仙梦";
        field.clearButtonMode=UITextFieldViewModeWhileEditing;
        field.returnKeyType=UIReturnKeyDone;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];

    __weak typeof(self) weakSelf=self;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action){
        typeof(self) selfRef=weakSelf;
        if(!selfRef)return;
        NSString *raw=[alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if(!raw.length)raw=appName;
        if([[raw.pathExtension lowercaseString] isEqualToString:@"json"])raw=[raw stringByDeletingPathExtension];
        NSCharacterSet *bad=[NSCharacterSet characterSetWithCharactersInString:@"/\\:?%*|\"<>\n\r\t"];
        NSString *base=[[raw componentsSeparatedByCharactersInSet:bad] componentsJoinedByString:@"_"];
        base=[base stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if(!base.length)base=@"ZonoeConfig";
        NSString *fileName=[base stringByAppendingPathExtension:@"json"];

        NSDictionary *project=[workspace projectExportDictionary];
        NSError *jsonError=nil;
        NSData *data=[NSJSONSerialization dataWithJSONObject:project
                                                     options:(NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys)
                                                       error:&jsonError];
        if(!data.length){
            workspace.lastStatus=[NSString stringWithFormat:@"导出失败：%@",jsonError.localizedDescription?:@"JSON 序列化失败"];
            [selfRef renderPage];
            return;
        }

        NSString *dir=[NSTemporaryDirectory() stringByAppendingPathComponent:@"zonoe-json-export"];
        NSError *mkdirError=nil;
        if(![NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&mkdirError]){
            workspace.lastStatus=[NSString stringWithFormat:@"导出失败：%@",mkdirError.localizedDescription?:@"无法创建临时目录"];
            [selfRef renderPage];
            return;
        }
        NSString *path=[dir stringByAppendingPathComponent:fileName];
        NSError *writeError=nil;
        if(![data writeToFile:path options:NSDataWritingAtomic error:&writeError]){
            workspace.lastStatus=[NSString stringWithFormat:@"导出失败：%@",writeError.localizedDescription?:@"无法写入临时 JSON"];
            [selfRef renderPage];
            return;
        }

        NSURL *url=[NSURL fileURLWithPath:path];
        UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc] initWithURL:url inMode:UIDocumentPickerModeExportToService];
        picker.delegate=(id<UIDocumentPickerDelegate>)selfRef;
        picker.restorationIdentifier=@"zonoe.project-json-export";
        picker.modalPresentationStyle=UIModalPresentationFormSheet;
        workspace.lastStatus=[NSString stringWithFormat:@"准备导出：%@ · Static %lu · Runtime %lu · Native Hook %lu",
                              fileName,
                              (unsigned long)[project[@"staticPatches"] count],
                              (unsigned long)[project[@"runtimeActions"] count],
                              (unsigned long)[project[@"nativeHooks"] count]];
        [selfRef renderPage];
        UIViewController *top=ZN48TopViewController((selfRef.hostWindow ?: [selfRef currentWindow]).rootViewController);
        if(top)[top presentViewController:picker animated:YES completion:nil];
    }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

- (void)zn50b_sliderMaxChanged:(UITextField *)field {
    NSInteger globalIndex=field.tag-kZN50BSliderMaxTagBase;
    if(globalIndex<0)return;
    ZNBinaryPatchWorkspace *workspace=[ZNBinaryPatchWorkspace sharedWorkspace];
    if((NSUInteger)globalIndex>=workspace.rows.count)return;
    ZNBinaryPatchRow *row=workspace.rows[(NSUInteger)globalIndex];
    if(row.featureControlType!=ZNFeatureControlTypeSlider)return;

    NSString *name=ZN50BTrim(row.group);
    if(!name.length||[name caseInsensitiveCompare:@"Imported"]==NSOrderedSame)name=ZN50BTrim(row.title);
    if(!name.length)name=@"未命名功能";

    NSString *text=ZN50BTrim(field.text);
    NSDecimalNumber *number=[NSDecimalNumber decimalNumberWithString:text locale:@{NSLocaleDecimalSeparator:@"."}];
    double value=(![number isEqualToNumber:NSDecimalNumber.notANumber])?number.doubleValue:0.0;
    if(!isfinite(value)||value<=0.0)value=0.0;
    if(value>16383.0){
        value=16383.0;
        field.text=@"16383";
    }
    ZN50BStoreSliderMax(name,value);
    row.validated=NO;
    row.validator=nil;
    row.originalHex=@"";
}

- (void)zn50b_featureDescriptionEnd:(UITextField *)field {
    NSInteger index=field.tag-kZN50BDescriptionTagBase;
    if(index<0)return;
    ZNBinaryPatchWorkspace *workspace=[ZNBinaryPatchWorkspace sharedWorkspace];
    NSArray<NSDictionary *> *features=ZN50BFeatureGroups(workspace);
    if((NSUInteger)index>=features.count)return;
    NSString *name=features[(NSUInteger)index][@"name"]?:@"";
    NSString *error=nil;
    if(![workspace setDescription:field.text?:@"" forFeature:name error:&error]){
        workspace.lastStatus=[NSString stringWithFormat:@"说明保存失败：%@",error?:@"未知错误"];
    }
    [self.hostWindow endEditing:YES];
    [self renderPage];
}

@end

static void ZN50BSwapInstanceMethod(Class cls, SEL original, SEL replacement) {
    Method a = class_getInstanceMethod(cls, original);
    Method b = class_getInstanceMethod(cls, replacement);
    if (a && b) method_exchangeImplementations(a, b);
}

extern "C" void ZNInstallFeatureBuilderUIDeferred(void) {
    @autoreleasepool {
        Class cls = NSClassFromString(@"ZNRuntimeMenuControllerV040");
        if (!cls) return;
        ZN50BSwapInstanceMethod(cls, @selector(zn44_renderOther), @selector(zn50b_renderOther));
        [[ZNRuntimeLogger sharedLogger] log:@"[bootstrap][main] v0.5 Feature Builder installed: Feature -> Patches -> validate/build; JSON optional"];
    }
}

#pragma mark - END ZNFeatureBuilderUI.mm
