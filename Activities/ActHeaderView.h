// -*- c-style: gnu -*-

#import <AppKit/AppKit.h>

@class ActHeaderViewController;

@interface ActHeaderView : NSView
{
  IBOutlet ActHeaderViewController *_controller;

  IBOutlet NSButton *_addFieldButton;
}

@property(nonatomic, copy) NSArray *displayedFields;

- (void)viewDidLoad;

- (BOOL)displaysField:(NSString *)name;
- (void)addDisplayedField:(NSString *)name;
- (void)removeDisplayedField:(NSString *)name;

- (CGFloat)heightForWidth:(CGFloat)width;
- (void)layoutSubviews;

- (IBAction)controlAction:(id)sender;

@end
