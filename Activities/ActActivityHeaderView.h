// -*- c-style: gnu -*-

#import "ActActivitySubview.h"

@interface ActActivityHeaderView : ActActivitySubview
{
  IBOutlet NSButton *_addFieldButton;
}

@property(nonatomic, copy) NSArray *displayedFields;

- (BOOL)displaysField:(NSString *)name;
- (void)addDisplayedField:(NSString *)name;
- (void)removeDisplayedField:(NSString *)name;

- (CGFloat)preferredHeight;
- (void)layoutSubviews;
- (void)layoutAndResize;

- (IBAction)controlAction:(id)sender;

@end
