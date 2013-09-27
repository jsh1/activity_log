// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

@interface ActHeaderView : NSView
{
  IBOutlet NSButton *_addFieldButton;
}

@property(nonatomic, copy) NSArray *displayedFields;

- (void)viewDidLoad;

- (BOOL)displaysField:(NSString *)name;
- (void)addDisplayedField:(NSString *)name;
- (void)removeDisplayedField:(NSString *)name;

- (CGFloat)preferredHeight;
- (void)layoutSubviews;
- (void)layoutAndResize;

- (IBAction)controlAction:(id)sender;

@end
