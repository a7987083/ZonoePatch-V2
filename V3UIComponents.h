#import <UIKit/UIKit.h>
static __attribute__((unused)) UIColor *ZNBlue(void) { return [UIColor colorWithRed:.10 green:.43 blue:.94 alpha:1]; }
static __attribute__((unused)) UILabel *ZNLabel(NSString *s,CGFloat size,BOOL bold) {
 UILabel *v=[UILabel new];v.text=s;v.font=bold?[UIFont boldSystemFontOfSize:size]:[UIFont systemFontOfSize:size];
 v.numberOfLines=0;return v;
}
static __attribute__((unused)) UIButton *ZNButton(NSString *s,id target,SEL sel) {
 UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];[b setTitle:s forState:UIControlStateNormal];
 b.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
 b.layer.cornerRadius=8;b.layer.borderColor=[UIColor colorWithWhite:.84 alpha:1].CGColor;b.layer.borderWidth=1;
 [b addTarget:target action:sel forControlEvents:UIControlEventTouchUpInside];return b;
}
